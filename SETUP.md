# Setup Guide

## Prerequisites

- macOS with Xcode 15.4+ installed
- iOS 17.0+ simulator or device
- Swift 5.9+

## Building

1. Clone the repository:
   ```bash
   git clone git@github.com:kdiggety/spartans_playcaller.git
   cd spartans_playcaller
   ```

2. Open the project in Xcode:
   ```bash
   open SpartansPlaycaller.xcodeproj
   ```

3. Select a simulator or device target and build (Cmd+B).

No external dependencies or package managers required.

## Running

Select an iOS simulator (iPhone recommended) and press Cmd+R. The app launches to the main Play Caller screen where you can:

- Pick a formation from the segmented control
- Select a concept and tap "Generate" to see the play
- Enter route digits manually and tap "Parse" to interpret them

## Development with Claude Code

This project uses Claude Code subagents for orchestrated development. Start Claude Code from the repo root:

```bash
claude
```

The orchestrator reads `CLAUDE.md` for role delegation and `PROJECT_CONTEXT.md` for domain context.
