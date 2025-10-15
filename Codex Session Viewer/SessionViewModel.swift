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

    private let repository: SessionRepository

    init(repository: SessionRepository = SessionRepository()) {
        self.repository = repository
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let months = try await loadMonths()
                self.months = months
                if selectedMonthID == nil {
                    selectedMonthID = months.first?.id
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
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

    private func loadMonths() async throws -> [SessionMonth] {
        try repository.loadMonths()
    }

    private func loadDetail(for summary: SessionSummary) async {
        do {
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
