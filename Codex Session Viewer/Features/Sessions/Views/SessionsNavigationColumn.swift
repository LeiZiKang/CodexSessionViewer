//
//  SessionsNavigationColumn.swift
//  Codex Session Viewer
//
//  Created by Codex Agent on 05/11/2025.
//

import SwiftUI

struct SessionsNavigationColumn: View {
    let needsFolderAccess: Bool
    let suggestedPath: String
    let isShowingSearchResults: Bool
    let searchResults: [SessionSearchResult]
    let isSearching: Bool
    let searchQuery: String
    let selectedSessionID: SessionSummary.ID?
    let sessions: [SessionSummary]
    let sortOrder: SessionSortOrder
    let onSelectSession: (SessionSummary.ID?) -> Void
    let onSelectSearchResult: (SessionSearchResult) -> Void
    let onChangeSortOrder: (SessionSortOrder) -> Void
    let requestFolderAccess: () -> Void

    var body: some View {
        Group {
            if needsFolderAccess {
                FolderAccessPromptView(
                    suggestedPath: suggestedPath,
                    action: requestFolderAccess
                )
            } else if isShowingSearchResults {
                SearchResultsView(
                    results: searchResults,
                    isSearching: isSearching,
                    query: searchQuery,
                    selection: searchSelectionBinding
                )
            } else {
                SessionListView(
                    sessions: sessions,
                    selectedSessionID: selectedSessionID,
                    onSelect: onSelectSession
                )
                .navigationTitle("Sessions")
                .listStyle(.inset)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Picker("Sort", selection: sortOrderBinding) {
                            ForEach(SessionSortOrder.allCases) { order in
                                Label(order.title, systemImage: order.systemImage)
                                    .tag(order)
                            }
                        }
                        .pickerStyle(.menu)
                        .help("Change session order")
                    }
                }
            }
        }
    }

    private var searchSelectionBinding: Binding<SessionSummary.ID?> {
        Binding(
            get: { selectedSessionID },
            set: { newValue in
                guard let newValue else {
                    onSelectSession(nil)
                    return
                }
                if let match = searchResults.first(where: { $0.summary.id == newValue }) {
                    onSelectSearchResult(match)
                } else {
                    onSelectSession(newValue)
                }
            }
        )
    }

    private var sortOrderBinding: Binding<SessionSortOrder> {
        Binding(
            get: { sortOrder },
            set: { newValue in onChangeSortOrder(newValue) }
        )
    }
}

private struct SessionListView: View {
    let sessions: [SessionSummary]
    let selectedSessionID: SessionSummary.ID?
    let onSelect: (SessionSummary.ID?) -> Void

    var body: some View {
        List(sessions, selection: selectionBinding) { session in
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                if let subtitle = session.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(updatedText(for: session))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .tag(session.id)
        }
    }

    private var selectionBinding: Binding<SessionSummary.ID?> {
        Binding(
            get: { selectedSessionID },
            set: { newValue in onSelect(newValue) }
        )
    }

    private func updatedText(for session: SessionSummary) -> String {
        let displayDate = session.updatedAt ?? session.timestamp
        return "Updated \(displayDate.formatted(date: .abbreviated, time: .shortened))"
    }
}
