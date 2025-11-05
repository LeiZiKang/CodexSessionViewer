//
//  FolderAccessPromptView.swift
//  Codex Session Viewer
//
//  Created by Codex Agent on 05/11/2025.
//

import SwiftUI

struct FolderAccessPromptView: View {
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
