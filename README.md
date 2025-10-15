# Codex Session Viewer

Codex Session Viewer is a native macOS SwiftUI application that helps you browse and inspect Codex CLI sessions stored locally on your machine.

## Features
- Automatically discovers session archives under `~/.codex/session` and `~/.codex/sessions`
- Groups sessions by month and shows metadata such as working directory, CLI version, and Git details
- Renders the full conversation timeline with syntax-friendly, selectable text
- Highlights user, assistant, system, and event messages to make long sessions easier to scan
- Prompts for folder access on first launch so you can authorize the Codex session directory once

## Getting Started
1. Open `Codex Session Viewer.xcodeproj` in Xcode 16 (or later).
2. Select the **Codex Session Viewer** target and choose *My Mac* as the run destination.
3. Build & run (`⌘R`). The app will enumerate sessions on launch; if nothing is found you'll see a helpful placeholder message.

To build from the command line:
```bash
xcodebuild -scheme "Codex Session Viewer" -destination 'platform=macOS' build
```

## Project Structure
- `Codex Session Viewer/SessionRepository.swift` – File discovery and JSONL parsing logic
- `Codex Session Viewer/SessionViewModel.swift` – Observable state that powers the SwiftUI views
- `Codex Session Viewer/ContentView.swift` & `SessionDetailView.swift` – Main navigation and detail UI
- `Codex Session Viewer/SessionModels.swift` – Shared data models for summaries, metadata, and events
- `AGENTS.md` – Persistent notes about collaborator preferences

## Notes
- Session files remain on disk; the app only reads them for display.
- If both `~/.codex/session` and `~/.codex/sessions` are present, the viewer combines them into a single timeline.
- Large sessions are read into memory when opened; for extremely big archives consider archiving old sessions to keep the app responsive.
- The first time you run the app you may need to point it at the Codex session folder; the app stores a security-scoped bookmark to avoid repeat prompts.
