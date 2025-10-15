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
        var path: String { url.path }
    }

    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let bookmarkKey = "codex.session.viewer.bookmarks"
    private var startedSecurityScopedURLs: Set<URL> = []

    init(fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.defaults = defaults
    }

    deinit {
        for url in startedSecurityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func prepareAccess() -> AccessState {
        let bookmarkItems = resolveBookmarks(startAccess: true)
        var directories = bookmarkItems.flatMap { collectSessionDirectories(from: $0.url) }

        let homeBase = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        directories.append(contentsOf: collectSessionDirectories(from: homeBase))

        let uniqueDirectories = uniqueURLs(directories)
        if !uniqueDirectories.isEmpty {
            return .ready(uniqueDirectories)
        }

        return .needsPermission(suggested: homeBase)
    }

    func storeBookmark(for url: URL) throws {
        try storeBookmarks(for: [url])
    }

    func storeBookmarks(for urls: [URL]) throws {
        let sanitized = urls.map { $0.standardizedFileURL }
        guard !sanitized.isEmpty else { return }

        var existing = resolveBookmarks(startAccess: true)
        var existingPaths = Set(existing.map { $0.path })
        var bookmarkDatas = existing.map { $0.data }

        for url in sanitized {
            let path = url.path
            if existingPaths.contains(path) {
                startAccessingSecurityScope(for: url)
                continue
            }
            let data = try url.bookmarkData(options: [.withSecurityScope],
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
            bookmarkDatas.append(data)
            existingPaths.insert(path)
            startAccessingSecurityScope(for: url)
        }

        defaults.set(bookmarkDatas, forKey: bookmarkKey)
        defaults.synchronize()
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
                let standardized = url.standardizedFileURL
                if startAccess {
                    startAccessingSecurityScope(for: standardized)
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
            if seen.contains(item.path) { continue }
            unique.append(item)
            seen.insert(item.path)
        }
        return unique
    }

    private func startAccessingSecurityScope(for url: URL) {
        let standardized = url.standardizedFileURL
        if startedSecurityScopedURLs.contains(standardized) {
            return
        }
        if standardized.startAccessingSecurityScopedResource() {
            startedSecurityScopedURLs.insert(standardized)
        }
    }

    private func collectSessionDirectories(from base: URL) -> [URL] {
        var directories: [URL] = []
        let standardized = base.standardizedFileURL

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
        var seen = Set<URL>()
        for url in urls {
            let standardized = url.standardizedFileURL
            if seen.contains(standardized) { continue }
            unique.append(standardized)
            seen.insert(standardized)
        }
        return unique
    }
}
