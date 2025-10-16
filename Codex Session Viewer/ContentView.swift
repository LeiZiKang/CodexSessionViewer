//
//  ContentView.swift
//  Codex Session Viewer
//
//  Created by Lei Levi on 15/10/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = SessionViewModel()
    @State private var isFolderImporterPresented = false

    private var sessionsForSelectedMonth: [SessionSummary] {
        guard let id = viewModel.selectedMonthID else { return [] }
        return viewModel.months.first(where: { $0.id == id })?.sessions ?? []
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(viewModel.months, selection: $viewModel.selectedMonthID) { month in
                Text(month.displayName)
                    .tag(month.id)
            }
            .navigationTitle("Months")
            .listStyle(.sidebar)
            .overlay {
                if viewModel.needsFolderAccess {
                    FolderAccessPromptView(
                        suggestedPath: suggestedPath,
                        action: { isFolderImporterPresented = true }
                    )
                    .padding()
                }
            }
        } content: {
            if viewModel.needsFolderAccess {
                FolderAccessPromptView(
                    suggestedPath: suggestedPath,
                    action: { isFolderImporterPresented = true }
                )
            } else {
                let selectionBinding = Binding<SessionSummary.ID?>(
                    get: { viewModel.selectedSessionID },
                    set: { newValue in viewModel.selectSession(id: newValue) }
                )
                List(sessionsForSelectedMonth, selection: selectionBinding) { session in
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
                .navigationTitle("Sessions")
                .listStyle(.inset)
            }
        } detail: {
            if viewModel.needsFolderAccess {
                FolderAccessPromptView(
                    suggestedPath: suggestedPath,
                    action: { isFolderImporterPresented = true }
                )
            } else {
                SessionDetailContainer(viewModel: viewModel)
            }
        }
        .task {
            viewModel.load()
        }
        .onChange(of: viewModel.needsFolderAccess) { needsAccess in
            if needsAccess {
                isFolderImporterPresented = true
            } else {
                isFolderImporterPresented = false
            }
        }
        .onChange(of: viewModel.selectedMonthID) { newValue in
            guard let id = newValue else {
                viewModel.selectSession(id: nil)
                return
            }
            guard
                viewModel.selectedSessionID == nil,
                let first = viewModel.months.first(where: { $0.id == id })?.sessions.first
            else { return }
            viewModel.selectSession(id: first.id)
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            }
        }
        .fileImporter(isPresented: $isFolderImporterPresented,
                      allowedContentTypes: [.folder],
                      allowsMultipleSelection: true) { result in
            viewModel.handleFolderImporterResult(result)
        }
        .alert("Unable to load sessions", isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .toolbar {
            if !viewModel.needsFolderAccess {
                Button {
                    isFolderImporterPresented = true
                } label: {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
            }
        }
    }

    private var suggestedPath: String {
        let url = viewModel.suggestedFolder ?? defaultSuggestedFolderURL()
        return displayPath(for: url)
    }

    private func defaultSuggestedFolderURL() -> URL {
        let homePath = NSHomeDirectoryForUser(NSUserName()) ?? NSHomeDirectory()
        let base = URL(fileURLWithPath: homePath, isDirectory: true)
            .appendingPathComponent(".codex", isDirectory: true)
        let sessions = base.appendingPathComponent("sessions", isDirectory: true)
        if FileManager.default.fileExists(atPath: sessions.path) {
            return sessions
        }
        return base.appendingPathComponent("session", isDirectory: true)
    }

    private func displayPath(for url: URL) -> String {
        let path = url.path
        if let home = NSHomeDirectoryForUser(NSUserName()) {
            if path.hasPrefix(home) {
                let relative = path.dropFirst(home.count)
                if relative.isEmpty {
                    return "~"
                }
                if relative.hasPrefix("/") {
                    return "~" + relative
                }
                return "~/" + relative
            }
        }
        return path
    }
}

#Preview {
    ContentView()
}

private struct FolderAccessPromptView: View {
    let suggestedPath: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.largeTitle)
            Text("Grant Access to Sessions")
                .font(.headline)
            Text("Allow the app to read Codex session archives located at \(suggestedPath).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
            Button("Grant Access") {
                action()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
