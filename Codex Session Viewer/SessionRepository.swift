//
//  SessionRepository.swift
//  Codex Session Viewer
//
//  Created by Codex Agent on 15/10/2025.
//

import Foundation

final class SessionRepository {
    private let fileManager: FileManager
    private let sessionDirectories: [URL]
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let fileTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private let displayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
    private let displayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(fileManager: FileManager = .default, directories: [URL]? = nil) {
        self.fileManager = fileManager
        if let directories, !directories.isEmpty {
            sessionDirectories = directories
        } else {
            let home = fileManager.homeDirectoryForCurrentUser
            let base = home.appendingPathComponent(".codex")
            let primary = base.appendingPathComponent("session")
            let fallback = base.appendingPathComponent("sessions")
            sessionDirectories = [primary, fallback]
        }
    }

    func loadMonths() throws -> [SessionMonth] {
        let summaries = try loadSessionSummaries()
        let grouped = Dictionary(grouping: summaries) { summary -> String in
            monthFormatter.string(from: summary.timestamp)
        }
        return grouped
            .map { key, value in
                let sortedSessions = value.sorted { $0.timestamp > $1.timestamp }
                let display = displayMonthName(for: sortedSessions.first?.timestamp)
                return SessionMonth(id: key, displayName: display, sessions: sortedSessions)
            }
            .sorted { $0.id > $1.id }
    }

    func loadDetail(for summary: SessionSummary) throws -> SessionDetail {
        let lines = try readLines(from: summary.fileURL)
        var metadata: SessionMetadata?
        var events: [SessionEvent] = []

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String
            else { continue }

            let timestamp = (json["timestamp"] as? String).flatMap { isoFormatter.date(from: $0) }

            if type == "session_meta",
               let payload = json["payload"] as? [String: Any] {
                metadata = parseMetadata(payload: payload)
                continue
            }

            if let event = parseEvent(type: type, json: json, timestamp: timestamp) {
                events.append(event)
            }
        }

        return SessionDetail(summary: summary, metadata: metadata, events: events)
    }

    // MARK: - Helpers

    private func loadSessionSummaries() throws -> [SessionSummary] {
        guard !sessionDirectories.isEmpty else { return [] }
        var summaries: [SessionSummary] = []
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .creationDateKey, .contentModificationDateKey]

        for directory in sessionDirectories {
            guard let enumerator = fileManager.enumerator(at: directory,
                                                          includingPropertiesForKeys: resourceKeys,
                                                          options: [.skipsHiddenFiles]) else { continue }
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension.lowercased() == "jsonl" else { continue }
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                      resourceValues.isRegularFile == true
                else { continue }

                let timestamp = parseTimestamp(for: fileURL, resourceValues: resourceValues)
                let firstLine = try? readFirstLine(from: fileURL)
                let metadataLine = firstLine.flatMap(parseMetadataLine)
                let title = metadataLine?.title ?? displayTimeFormatter.string(from: timestamp)
                let subtitle = metadataLine?.subtitle
                let summary = SessionSummary(id: fileURL.path,
                                             fileURL: fileURL,
                                             timestamp: timestamp,
                                             title: title,
                                             subtitle: subtitle)
                summaries.append(summary)
            }
        }
        return summaries.sorted { $0.timestamp > $1.timestamp }
    }

    private func parseTimestamp(for url: URL, resourceValues: URLResourceValues) -> Date {
        if let filenameDate = parseDateFromFilename(url.lastPathComponent) {
            return filenameDate
        }
        if let creationDate = resourceValues.creationDate {
            return creationDate
        }
        if let modificationDate = resourceValues.contentModificationDate {
            return modificationDate
        }
        return Date.distantPast
    }

    private func parseDateFromFilename(_ name: String) -> Date? {
        let trimmed = name.replacingOccurrences(of: ".jsonl", with: "")
        if let range = trimmed.range(of: #"(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2})"#, options: .regularExpression) {
            let match = String(trimmed[range])
            return fileTimestampFormatter.date(from: match)
        }
        return nil
    }

    private func displayMonthName(for date: Date?) -> String {
        guard let date else { return "Unknown Month" }
        return displayMonthFormatter.string(from: date)
    }

    private func readLines(from url: URL) throws -> [String] {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            return []
        }
        return content.split(whereSeparator: \.isNewline)
            .map(String.init)
    }

    private func readFirstLine(from url: URL) throws -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var buffer = Data()
        while true {
            let chunk = handle.readData(ofLength: 1)
            if chunk.isEmpty {
                return buffer.isEmpty ? nil : String(data: buffer, encoding: .utf8)
            }
            if let byte = chunk.first, byte == 10 {
                return String(data: buffer, encoding: .utf8)
            } else {
                buffer.append(chunk)
            }
        }
    }

    private func parseMetadataLine(_ line: String) -> (title: String, subtitle: String?)? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String,
              type == "session_meta",
              let payload = json["payload"] as? [String: Any] else {
            return nil
        }
        let cwd = payload["cwd"] as? String
        let instructions = payload["instructions"] as? String
        let instructionFirstLine = instructions?
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = instructionFirstLine?.isEmpty == false ? instructionFirstLine! : (cwd?.components(separatedBy: "/").last ?? "Codex Session")
        let subtitle = cwd
        return (title, subtitle)
    }

    private func parseMetadata(payload: [String: Any]) -> SessionMetadata {
        let git = payload["git"] as? [String: Any]
        return SessionMetadata(
            sessionID: payload["id"] as? String,
            workingDirectory: payload["cwd"] as? String,
            originator: payload["originator"] as? String,
            cliVersion: payload["cli_version"] as? String,
            instructions: payload["instructions"] as? String,
            repositoryURL: git?["repository_url"] as? String,
            branch: git?["branch"] as? String,
            commitHash: git?["commit_hash"] as? String
        )
    }

    private func parseEvent(type: String, json: [String: Any], timestamp: Date?) -> SessionEvent? {
        switch type {
        case "response_item":
            guard
                let payload = json["payload"] as? [String: Any],
                let roleString = payload["role"] as? String
            else { return nil }
            let role = parseRole(roleString)
            let content = payload["content"] as? [[String: Any]] ?? []
            let textBlocks = content.compactMap { $0["text"] as? String }.filter { !$0.isEmpty }
            guard !textBlocks.isEmpty else { return nil }
            let text = textBlocks.joined(separator: "\n\n")
            return SessionEvent(role: role,
                                timestamp: timestamp,
                                title: roleDisplayName(role),
                                text: text)

        case "event_msg":
            guard let payload = json["payload"] as? [String: Any] else { return nil }
            if let message = payload["message"] as? String, !message.isEmpty {
                return SessionEvent(role: .event,
                                    timestamp: timestamp,
                                    title: payload["type"] as? String ?? "Event",
                                    text: message)
            }
            return nil

        case "command_output", "tool_output":
            guard let payload = json["payload"] as? [String: Any],
                  let text = payload["output"] as? String ?? payload["message"] as? String,
                  !text.isEmpty else { return nil }
            return SessionEvent(role: .event,
                                timestamp: timestamp,
                                title: type,
                                text: text)

        default:
            guard let payload = json["payload"] else { return nil }
            let text = String(describing: payload)
            guard !text.isEmpty else { return nil }
            return SessionEvent(role: .other(type),
                                timestamp: timestamp,
                                title: type,
                                text: text)
        }
    }

    private func parseRole(_ value: String) -> SessionEvent.Role {
        switch value {
        case "user": return .user
        case "assistant": return .assistant
        case "system": return .system
        default: return .other(value)
        }
    }

    private func roleDisplayName(_ role: SessionEvent.Role) -> String {
        switch role {
        case .user: return "User"
        case .assistant: return "Assistant"
        case .system: return "System"
        case .event: return "Event"
        case .other(let value): return value.capitalized
        }
    }
}
