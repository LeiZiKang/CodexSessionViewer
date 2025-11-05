//
//  SessionViewModel.swift
//  Codex Session Viewer
//
//  Created by Codex Agent on 15/10/2025.
//

import Foundation

@MainActor
@Observable
final class SessionViewModel {
    
    public var months: [SessionMonth] = []
    public var selectedMonthID: SessionMonth.ID? {
        didSet {
            if selectedMonthID != oldValue {
                selectedSessionID = nil
            }
        }
    }
    
    public var selectedSessionID: SessionSummary.ID?
    public var selectedDetail: SessionDetail?
    public var isLoading = false
    public var isSearching = false
    public var searchQuery = ""
    public var searchResults: [SessionSearchResult] = []
    public var errorMessage: String?
    public var needsFolderAccess = false
    public var suggestedFolder: URL?
    public var isShowingSearchResults: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let accessController = SessionAccessController()
    private var repository: SessionRepository?
    private var pendingReload = false
    private var searchTask: Task<Void, Never>?

    func load() {
        if isLoading {
            pendingReload = true
            return
        }
        pendingReload = false
        errorMessage = nil
        prepareAccessAndLoad()
    }

    func selectSession(id: SessionSummary.ID?) {
        selectedSessionID = id
        selectedDetail = nil

        guard
            let id,
            let summary = months.flatMap({ $0.sessions }).first(where: { $0.id == id })
        else { return }

        Task {
            await loadDetail(for: summary)
        }
    }

    func updateSearch(query: String) {
        searchTask?.cancel()
        if searchQuery != query {
            searchQuery = query
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            isSearching = false
            searchResults = []
            searchTask = nil
            return
        }

        guard let repository else {
            isSearching = false
            searchResults = []
            searchTask = nil
            return
        }

        isSearching = true
        let summaries = months.flatMap { $0.sessions }

        searchTask = Task { [weak self, repository] in
            guard let self else { return }
            do {
                let results = try await self.performSearch(query: trimmed,
                                                           repository: repository,
                                                           summaries: summaries)
                if Task.isCancelled { return }
                self.searchResults = results
                self.isSearching = false
                self.searchTask = nil
            } catch {
                if Task.isCancelled { return }
                self.searchResults = []
                self.isSearching = false
                self.errorMessage = error.localizedDescription
                self.searchTask = nil
            }
        }
    }

    func selectSearchResult(_ result: SessionSearchResult) {
        if let month = months.first(where: { month in
            month.sessions.contains(result.summary)
        }) {
            selectedMonthID = month.id
        }
        selectSession(id: result.summary.id)
    }

    func handleFolderImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let sanitized = urls.map { $0.standardizedFileURL }
            guard !sanitized.isEmpty else { return }
            do {
                try accessController.storeBookmarks(for: sanitized)
                needsFolderAccess = false
                suggestedFolder = nil
                load()
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            let nsError = error as NSError
            if nsError.code == NSUserCancelledError {
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    private func prepareAccessAndLoad() {
        switch accessController.prepareAccess() {
        case .ready(let directories):
            needsFolderAccess = false
            suggestedFolder = nil
            repository = SessionRepository(directories: directories)
            fetchMonths()
        case .needsPermission(let suggested):
            needsFolderAccess = true
            suggestedFolder = suggested
            months = []
            selectedMonthID = nil
            selectedSessionID = nil
            selectedDetail = nil
            searchResults = []
            searchQuery = ""
            isSearching = false
            searchTask?.cancel()
            searchTask = nil
        }
    }

    private func fetchMonths() {
        guard let repository else { return }
        guard !isLoading else { return }
        isLoading = true

        Task {
            do {
                let months = try repository.loadMonths()
                await MainActor.run {
                    self.months = months
                    if selectedMonthID == nil {
                        selectedMonthID = months.first?.id
                    }
                    if !self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.updateSearch(query: self.searchQuery)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                self.isLoading = false
                if self.pendingReload {
                    self.pendingReload = false
                    self.prepareAccessAndLoad()
                }
            }
        }
    }

    private func loadDetail(for summary: SessionSummary) async {
        do {
            guard let repository else { return }
            let detail = try repository.loadDetail(for: summary)
            await MainActor.run {
                selectedDetail = detail
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func performSearch(query: String,
                               repository: SessionRepository,
                               summaries: [SessionSummary]) async throws -> [SessionSearchResult] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let results = try repository.searchSessions(query: query, in: summaries)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    deinit {
        Task { @MainActor in
            searchTask?.cancel()
        }
    }
}
