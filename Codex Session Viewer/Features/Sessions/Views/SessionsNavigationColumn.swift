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
    let onSelectSession: (SessionSummary.ID?) -> Void
    let onSelectSearchResult: (SessionSearchResult) -> Void
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
}
