//
//  SessionDetailView.swift
//  Codex Session Viewer
//
//  Created by Codex Agent on 15/10/2025.
//

import SwiftUI

struct SessionDetailContainer: View {
    @ObservedObject var viewModel: SessionViewModel

    var body: some View {
        if let detail = viewModel.selectedDetail {
            SessionDetailView(detail: detail)
        } else if viewModel.selectedSessionID != nil {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading session…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.months.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.largeTitle)
                Text("No sessions found")
                    .font(.headline)
                Text("Codex session files were not detected in ~/.codex/session or ~/.codex/sessions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "text.bubble")
                    .font(.largeTitle)
                Text("Select a session")
                    .font(.headline)
                Text("Choose a session on the left to view the full conversation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct SessionDetailView: View {
    let detail: SessionDetail
    private let headerFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sessionHeader
                if let metadata = detail.metadata {
                    metadataSection(metadata)
                }
                Divider()
                eventsSection
            }
            .padding()
        }
        .navigationTitle(detail.summary.title)
    }

    private var sessionHeader: some View {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.summary.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(headerFormatter.string(from: detail.summary.timestamp))
                        .font(.callout)
                .foregroundStyle(.secondary)
            if let subtitle = detail.summary.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metadataSection(_ metadata: SessionMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metadata")
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                metadataRow(label: "Session ID", value: metadata.sessionID)
                metadataRow(label: "CLI Version", value: metadata.cliVersion)
                metadataRow(label: "Originator", value: metadata.originator)
                metadataRow(label: "Working Directory", value: metadata.workingDirectory)
                metadataRow(label: "Repository", value: metadata.repositoryURL)
                metadataRow(label: "Branch", value: metadata.branch)
                metadataRow(label: "Commit", value: metadata.commitHash)
            }
            if let instructions = metadata.instructions, !instructions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Initial Instructions")
                        .font(.headline)
                    Text(instructions)
                        .font(.body)
                        .monospaced()
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func metadataRow(label: String, value: String?) -> some View {
        Group {
            if let value, !value.isEmpty {
                GridRow {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversation")
                .font(.headline)
            ForEach(detail.events) { event in
                SessionEventView(event: event)
                    .padding(12)
                    .background(background(for: event.role))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.quaternary)
                    )
            }
        }
    }

    private func background(for role: SessionEvent.Role) -> Color {
        switch role {
        case .user:
            Color.blue.opacity(0.08)
        case .assistant:
            Color.green.opacity(0.08)
        case .system:
            Color.gray.opacity(0.08)
        case .event:
            Color.orange.opacity(0.06)
        case .other:
            Color.secondary.opacity(0.05)
        }
    }
}

private struct SessionEventView: View {
    let event: SessionEvent
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.title)
                    .font(.headline)
                Spacer()
                if let timestamp = event.timestamp {
                    Text(timeFormatter.string(from: timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let text = event.text {
                Text(text)
                    .font(.body)
                    .monospaced()
                    .textSelection(.enabled)
            }
        }
    }
}
