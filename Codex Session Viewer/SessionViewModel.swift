//
//  SessionViewModel.swift
//  Codex Session Viewer
//
//  Created by Codex Agent on 15/10/2025.
//

import Foundation
import Combine

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var months: [SessionMonth] = []
    @Published var selectedMonthID: SessionMonth.ID? {
        didSet {
            if selectedMonthID != oldValue {
                selectedSessionID = nil
            }
        }
    }
    @Published var selectedSessionID: SessionSummary.ID?
    @Published var selectedDetail: SessionDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var needsFolderAccess = false
    @Published var suggestedFolder: URL?

    private let accessController = SessionAccessController()
    private var repository: SessionRepository?

    func load() {
        guard !isLoading else { return }
        errorMessage = nil

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
        }
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

    func handleFolderImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                try accessController.storeBookmark(for: url)
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
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                self.isLoading = false
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
}
