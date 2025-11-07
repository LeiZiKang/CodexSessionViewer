# Codex Session Viewer

Codex Session Viewer is a native macOS SwiftUI application that helps you browse and inspect Codex CLI sessions stored locally on your machine.

## Features
- Automatically discovers session archives under `~/.codex/session` and `~/.codex/sessions`
- Groups sessions by month and shows metadata such as working directory, CLI version, and Git details
- Renders the full conversation timeline with syntax-friendly, selectable text
- Highlights user, assistant, system, and event messages to make long sessions easier to scan
- Prompts for folder access on first launch and lets you authorize extra session folders later

## Getting Started
1. Open `CodexSessionViewer.xcodeproj` in Xcode 16 (or later).
2. Select the **CodexSessionViewer** target and choose *My Mac* as the run destination.
3. Build & run (`⌘R`). The app will enumerate sessions on launch; if nothing is found you'll see a helpful placeholder message.

To build from the command line:
```bash
xcodebuild -scheme CodexSessionViewer -destination 'platform=macOS' build
```

## Project Structure
- `Codex Session Viewer/SessionRepository.swift` – File discovery and JSONL parsing logic
- `Codex Session Viewer/SessionViewModel.swift` – Observable state that powers the SwiftUI views
- `Codex Session Viewer/ContentView.swift` & `SessionDetailView.swift` – Main navigation and detail UI
- `Codex Session Viewer/SessionModels.swift` – Shared data models for summaries, metadata, and events

## Notes
- Session files remain on disk; the app only reads them for display.
- If both `~/.codex/session` and `~/.codex/sessions` are present, the viewer combines them into a single timeline.
- Large sessions are read into memory when opened; for extremely big archives consider archiving old sessions to keep the app responsive.
- The first time you run the app you may need to point it at the Codex session folder; you can add additional locations later via the toolbar, and the app stores security-scoped bookmarks to avoid repeat prompts.

## Overview
<img width="3024" height="1896" alt="21308" src="https://github.com/user-attachments/assets/4dc2efd0-db6b-4711-9a95-81ea107eb171" />
<img width="3024" height="1896" alt="48879" src="https://github.com/user-attachments/assets/f1ccbb42-70a1-4b20-89e8-d290ca2b9ebb" />


