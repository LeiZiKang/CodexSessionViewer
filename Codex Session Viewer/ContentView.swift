//
//  ContentView.swift
//  Codex Session Viewer
//
//  Created by Lei Levi on 15/10/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SessionViewModel()

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
        } content: {
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
        } detail: {
            SessionDetailContainer(viewModel: viewModel)
        }
        .task {
            viewModel.load()
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
        .alert("Unable to load sessions", isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    ContentView()
}
