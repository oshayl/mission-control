# 🛰️ Mission Control

Native macOS menu bar HUD for client + project awareness. Lives in your menu bar, one click to see every active client, what they need, and when you last touched them. iCloud Drive sync across Mac Pro + MacBook Pro.

## Why
Your CRM (`track.noira.us`) is heavy. This is the heads-up display. You open it 20× a day without thinking. Click the scope icon, scan the list, move on.

## Stack
- SwiftUI + AppKit (NSPopover menu bar)
- Swift Package Manager (build/run from terminal, no Xcode required)
- iCloud Drive for sync (ubiquity container `Documents/mission.json`)
- GitHub: `oshayl/mission-control`

## Build & Run
```bash
cd ~/Projects/mission-control
swift run MissionControl
```

The status bar icon (scope) appears top-right. Click it.

## Features (v0.1 — MVP)
- [x] Menu bar status item with SF Symbol
- [x] Popover (420×560, frosted)
- [x] Client list with search, status filter, stale filter
- [x] Client detail with editable fields, activity log, quick actions (iMessage / Call / Email / GitHub)
- [x] Add / delete clients
- [x] Auto-save to `~/Library/Application Support/MissionControl/mission.json` + iCloud Drive
- [x] Seeded with 5 real clients from the workspace
- [x] Status colors, avatar gradients, days-since-contact indicator
- [x] Stats pills (active / stale counts)

## Roadmap
- [ ] Real Carbon global hotkey (⌥⌘C)
- [ ] iMessage chat.db integration (read recent messages per client)
- [ ] GitHub API integration (per-client commit + PR activity)
- [ ] Calendar integration (next meeting per client)
- [ ] Quick-note capture (global hotkey + clipboard)
- [ ] Notifications (stale client nudges)
- [ ] Menu bar badge (count of stale clients)
- [ ] Sparkline / activity feed in list
- [ ] Notion-style command bar (⌘K)
- [ ] Inline quick invoice (generate from next action)
- [ ] Activity pulse animation on icon
- [ ] Cross-machine last-seen indicator

## File Layout
```
Sources/MissionControl/
├── MissionControlApp.swift   # entry, status item, popover host
├── DataStore.swift          # @MainActor ObservableObject, iCloud sync
├── Models.swift             # Client, Project, ActivityEntry, MissionData
├── RootView.swift           # popover root
├── ClientList.swift         # searchable list + rows
├── ClientDetail.swift       # detail + activity + actions
└── AddClientSheet.swift     # new-client form
```

## Synced Data
- Local: `~/Library/Application Support/MissionControl/mission.json`
- iCloud: `~/Library/Mobile Documents/com~apple~CloudDocs/MissionControl/mission.json` (or wherever ubiquity container resolves)
- Schema versioned (`version: 1`).
