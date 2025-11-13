//
//  SearchView.swift
//  CodexSessionViewer
//
//  Created by Lei Levi on 30/10/2025.
//

import SwiftUI

struct SearchResultsView: View {
    let results: [SessionSearchResult]
    let isSearching: Bool
    let query: String
    @Binding var selection: SessionSummary.ID?

    var body: some View {
        Group {
            if results.isEmpty {
                SearchEmptyState(isSearching: isSearching, query: query)
            } else {
                resultsList
                    .overlay(alignment: .topTrailing) {
                        if isSearching {
                            ProgressView()
                                .controlSize(.small)
                                .padding()
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var resultsList: some View {
        List(results, selection: $selection) { result in
            SearchResultRow(result: result, query: query)
                .tag(result.summary.id)
        }
        .listStyle(.inset)
    }
}

private struct SearchEmptyState: View {
    let isSearching: Bool
    let query: String

    var body: some View {
        VStack(spacing: 12) {
            if isSearching {
                ProgressView()
                Text("Searching…")
                    .foregroundStyle(.secondary)
            } else if query.isEmpty {
                Text("Start typing to search across every session.")
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("No matches for “\(query)”")
                    .font(.headline)
                Text("Try different keywords or broaden your search.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct SearchResultRow: View {
    let result: SessionSearchResult
    let query: String
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(result.summary.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let subtitle = result.summary.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Label {
                Text(result.matchTitle)
            } icon: {
                Image(systemName: "quote.bubble")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            highlightedSnippet
                .font(.callout)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 6)
    }

    private var formattedDate: String {
        Self.dateFormatter.string(from: result.matchTimestamp ?? result.summary.timestamp)
    }

    private var highlightedSnippet: Text {
        guard !query.isEmpty else { return Text(result.snippet) }
        var attributed = AttributedString(result.snippet)
        if let range = attributed.range(of: query,
                                        options: [.caseInsensitive, .diacriticInsensitive]) {
            var attributes = AttributeContainer()
            attributes.font = .system(.body, design: .default).weight(.semibold)
            attributes.foregroundColor = .accentColor
            attributed[range].setAttributes(attributes)
        }
        return Text(attributed)
    }
}

#Preview {
    let summary = SessionSummary(id: "sample",
                                 fileURL: URL(fileURLWithPath: "/tmp/sample.jsonl"),
                                 timestamp: Date(),
                                 updatedAt: Date().addingTimeInterval(-3600),
                                 title: "Sample Session",
                                 subtitle: "/Users/example/project")
    let result = SessionSearchResult(id: summary.id,
                                     summary: summary,
                                     matchTitle: "Assistant",
                                     snippet: "…build succeeded. Consider rerunning the tests to verify coverage…",
                                     matchTimestamp: Date())
    return SearchResultsView(
        results: [result],
        isSearching: false,
        query: "tests",
        selection: .constant(nil)
    )
}
