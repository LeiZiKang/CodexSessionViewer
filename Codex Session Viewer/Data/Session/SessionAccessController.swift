//
//  SessionAccessController.swift
//  Codex Session Viewer
//
//  Created by Codex Agent on 15/10/2025.
//

import Foundation

final class SessionAccessController {
    enum AccessState {
        case ready([URL])
        case needsPermission(suggested: URL?)
    }

    private struct BookmarkItem {
        let url: URL
        let data: Data
        var normalizedPath: String { Self.normalize(url).path }

        private static func normalize(_ url: URL) -> URL {
            url.standardizedFileURL.resolvingSymlinksInPath()
        }
    }

    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let bookmarkKey = "codex.session.viewer.bookmarks"
    private var startedSecurityScopedURLs: [String: URL] = [:]

    init(fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.defaults = defaults
    }

    deinit {
        for (_, url) in startedSecurityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func prepareAccess() -> AccessState {
        let bookmarkItems = resolveBookmarks(startAccess: true)
        var directories = bookmarkItems.flatMap { collectSessionDirectories(from: $0.url) }

        let defaults = defaultSessionDirectories()
        directories.append(contentsOf: defaults)

        let uniqueDirectories = uniqueURLs(directories)
        if !uniqueDirectories.isEmpty {
            return .ready(uniqueDirectories)
        }

        return .needsPermission(suggested: defaultSuggestedFolder())
    }

    func storeBookmark(for url: URL) throws {
        try storeBookmarks(for: [url])
    }

    func storeBookmarks(for urls: [URL]) throws {
        guard !urls.isEmpty else { return }

        let existing = resolveBookmarks(startAccess: true)
        var existingPaths = Set(existing.map { $0.normalizedPath })
        var bookmarkDatas = existing.map { $0.data }

        for originalURL in urls {
            let normalizedPath = normalize(originalURL).path
            if existingPaths.contains(normalizedPath) {
                startAccessingSecurityScope(for: originalURL)
                continue
            }
            startAccessingSecurityScope(for: originalURL)
            let data = try originalURL.bookmarkData(options: [.withSecurityScope],
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil)
            bookmarkDatas.append(data)
            existingPaths.insert(normalizedPath)
        }

        defaults.set(bookmarkDatas, forKey: bookmarkKey)
        defaults.synchronize()
    }

    func defaultSuggestedFolder() -> URL {
        let base = codexBaseDirectory()
        let sessions = base.appendingPathComponent("sessions", isDirectory: true)
        if isReadableDirectory(at: sessions) || fileManager.fileExists(atPath: sessions.path) {
            return sessions
        }
        return base.appendingPathComponent("session", isDirectory: true)
    }

    // MARK: - Helpers

    private func resolveBookmarks(startAccess: Bool) -> [BookmarkItem] {
        let bookmarkDatas = defaults.array(forKey: bookmarkKey) as? [Data] ?? []
        var resolved: [BookmarkItem] = []
        var updatedDatas: [Data] = []
        var hasChanges = false

        for data in bookmarkDatas {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: data,
                                  options: [.withSecurityScope, .withoutUI],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale)
                if isStale {
                    hasChanges = true
                    continue
                }
                let standardized = normalize(url)
                if startAccess {
                    startAccessingSecurityScope(for: url)
                }
                resolved.append(BookmarkItem(url: standardized, data: data))
                updatedDatas.append(data)
            } catch {
                hasChanges = true
            }
        }

        if hasChanges {
            defaults.set(updatedDatas, forKey: bookmarkKey)
        }

        var unique: [BookmarkItem] = []
        var seen = Set<String>()
        for item in resolved {
            if seen.contains(item.normalizedPath) { continue }
            unique.append(item)
            seen.insert(item.normalizedPath)
        }
        return unique
    }

    private func defaultSessionDirectories() -> [URL] {
        let base = codexBaseDirectory()
        return ["session", "sessions"].compactMap { component in
            let directory = base.appendingPathComponent(component, isDirectory: true)
            return isReadableDirectory(at: directory) ? directory : nil
        }
    }

    private func codexBaseDirectory() -> URL {
        let homePath = NSHomeDirectoryForUser(NSUserName()) ?? NSHomeDirectory()
        return URL(fileURLWithPath: homePath, isDirectory: true)
            .appendingPathComponent(".codex", isDirectory: true)
    }

    private func startAccessingSecurityScope(for url: URL) {
        let normalized = normalize(url)
        let key = normalized.path
        if startedSecurityScopedURLs[key] != nil { return }
        if url.startAccessingSecurityScopedResource() {
            startedSecurityScopedURLs[key] = url
        }
    }

    private func collectSessionDirectories(from base: URL) -> [URL] {
        var directories: [URL] = []
        let standardized = normalize(base)

        if isReadableDirectory(at: standardized) {
            if standardized.lastPathComponent == "session" || standardized.lastPathComponent == "sessions" {
                directories.append(standardized)
            } else {
                let session = standardized.appendingPathComponent("session", isDirectory: true)
                let sessions = standardized.appendingPathComponent("sessions", isDirectory: true)
                if isReadableDirectory(at: session) {
                    directories.append(session)
                }
                if isReadableDirectory(at: sessions) {
                    directories.append(sessions)
                }
                if directories.isEmpty {
                    directories.append(standardized)
                }
            }
        }

        return directories
    }

    private func isReadableDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }
        return fileManager.isReadableFile(atPath: url.path)
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var unique: [URL] = []
        var seen = Set<String>()
        for url in urls {
            let normalized = normalize(url)
            let key = normalized.path
            if seen.contains(key) { continue }
            unique.append(normalized)
            seen.insert(key)
        }
        return unique
    }

    private func normalize(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
