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

    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let bookmarkKey = "codex.session.viewer.bookmark"
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
        var directories: [URL] = []

        if let bookmarkData = defaults.data(forKey: bookmarkKey) {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: bookmarkData,
                                  options: [.withSecurityScope, .withoutUI],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale)
                if isStale {
                    defaults.removeObject(forKey: bookmarkKey)
                } else {
                    startAccessingSecurityScope(for: url)
                    directories.append(contentsOf: collectSessionDirectories(from: url))
                }
            } catch {
                defaults.removeObject(forKey: bookmarkKey)
            }
        }

        let homeBase = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        directories.append(contentsOf: collectSessionDirectories(from: homeBase))

        let uniqueDirectories = uniqueURLs(directories)
        if !uniqueDirectories.isEmpty {
            return .ready(uniqueDirectories)
        }

        return .needsPermission(suggested: homeBase)
    }

    func storeBookmark(for url: URL) throws {
        let data = try url.bookmarkData(options: [.withSecurityScope],
                                        includingResourceValuesForKeys: nil,
                                        relativeTo: nil)
        defaults.set(data, forKey: bookmarkKey)
        defaults.synchronize()
        startAccessingSecurityScope(for: url)
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
            if !seen.contains(standardized) {
                unique.append(standardized)
                seen.insert(standardized)
            }
        }
        return unique
    }
}
