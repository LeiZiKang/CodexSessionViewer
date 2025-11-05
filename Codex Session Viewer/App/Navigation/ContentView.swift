//
//  ContentView.swift
//  Codex Session Viewer
//
//  Created by Lei Levi on 15/10/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel = SessionViewModel()
    @State private var isFolderImporterPresented = false

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationSplitView(columnVisibility: .constant(.all)) {
            MonthsSidebarView(
                months: viewModel.months,
                selection: $viewModel.selectedMonthID,
                needsFolderAccess: viewModel.needsFolderAccess,
                suggestedPath: suggestedPath,
                requestFolderAccess: presentFolderImporter
            )
        } content: {
            SessionsNavigationColumn(
                needsFolderAccess: viewModel.needsFolderAccess,
                suggestedPath: suggestedPath,
                isShowingSearchResults: viewModel.isShowingSearchResults,
                searchResults: viewModel.searchResults,
                isSearching: viewModel.isSearching,
                searchQuery: viewModel.searchQuery,
                selectedSessionID: viewModel.selectedSessionID,
                sessions: sessionsForSelectedMonth,
                onSelectSession: { viewModel.selectSession(id: $0) },
                onSelectSearchResult: { viewModel.selectSearchResult($0) },
                requestFolderAccess: presentFolderImporter
            )
        } detail: {
            if viewModel.needsFolderAccess {
                FolderAccessPromptView(
                    suggestedPath: suggestedPath,
                    action: presentFolderImporter
                )
            } else {
                SessionDetailContainer(viewModel: viewModel)
            }
        }
        .task {
            viewModel.load()
        }
        
        .onChange(of: viewModel.needsFolderAccess) { needsAccess in
            handleNeedsFolderAccessChange(needsAccess: needsAccess)
        }
        .onChange(of: viewModel.selectedMonthID) { newValue in
            handleMonthSelectionChange(newValue, viewModel: viewModel)
        }
        
        .onChange(of: viewModel.searchQuery) { newValue in
            viewModel.updateSearch(query: newValue)
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

            Button {
                buttonReloadTab()
            } label: {
                Label("Reload", systemImage: "arrow.trianglehead.clockwise")
            }
            
        }
        
        .searchable(text: $viewModel.searchQuery, placement: .toolbar, prompt: "Search sessions")
    }

    private var sessionsForSelectedMonth: [SessionSummary] {
        guard let id = viewModel.selectedMonthID else { return [] }
        return viewModel.months.first(where: { $0.id == id })?.sessions ?? []
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
    
    private func buttonReloadTab() {
        Task {
            viewModel.load()
        }
    }

    private func presentFolderImporter() {
        isFolderImporterPresented = true
    }

    private func handleNeedsFolderAccessChange(needsAccess: Bool) {
        isFolderImporterPresented = needsAccess
    }

    private func handleMonthSelectionChange(_ newValue: SessionMonth.ID?, viewModel: SessionViewModel) {
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
    
}

#Preview {
    ContentView()
}
