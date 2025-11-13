//
//  SessionModels.swift
//  Codex Session Viewer
//
//  Created by Codex Agent on 15/10/2025.
//

import Foundation

struct SessionMonth: Identifiable, Hashable {
    let id: String
    let displayName: String
    var sessions: [SessionSummary]
}

struct SessionSummary: Identifiable, Hashable {
    let id: String
    let fileURL: URL
    let timestamp: Date
    let updatedAt: Date?
    let title: String
    let subtitle: String?
}

struct SessionDetail {
    let summary: SessionSummary
    let metadata: SessionMetadata?
    let events: [SessionEvent]
}

struct SessionSearchResult: Identifiable {
    let id: SessionSummary.ID
    let summary: SessionSummary
    let matchTitle: String
    let snippet: String
    let matchTimestamp: Date?
}

struct SessionMetadata {
    let sessionID: String?
    let workingDirectory: String?
    let originator: String?
    let cliVersion: String?
    let instructions: String?
    let repositoryURL: String?
    let branch: String?
    let commitHash: String?
}

struct SessionEvent: Identifiable {
    enum Role {
        case user
        case assistant
        case system
        case event
        case other(String)
    }

    let id = UUID()
    let role: Role
    let timestamp: Date?
    let title: String
    let text: String?
}
