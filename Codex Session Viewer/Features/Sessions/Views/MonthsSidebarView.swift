//
//  MonthsSidebarView.swift
//  Codex Session Viewer
//
//  Created by Codex Agent on 05/11/2025.
//

import SwiftUI

struct MonthsSidebarView: View {
    let months: [SessionMonth]
    @Binding var selection: SessionMonth.ID?
    let needsFolderAccess: Bool
    let suggestedPath: String
    let requestFolderAccess: () -> Void

    var body: some View {
        List(months, selection: $selection) { month in
            Text(month.displayName)
                .tag(month.id)
        }
        .navigationTitle("Months")
        .listStyle(.sidebar)
        .overlay {
            if needsFolderAccess {
                FolderAccessPromptView(
                    suggestedPath: suggestedPath,
                    action: requestFolderAccess
                )
                .padding()
            }
        }
    }
}
