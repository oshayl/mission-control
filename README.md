# 🛰️ Mission Control

Native macOS menu bar HUD for client + project awareness. Lives in your menu bar — one click (or ⌥⌘C) and you see every active client, what they need, and when you last touched them. iCloud Drive sync across Mac Pro + MacBook Pro.

**Repo:** https://github.com/oshayl/mission-control
**Built:** 2026-06-09
**Stack:** SwiftUI + AppKit + EventKit + UserNotifications + Network.framework, SwiftPM, zero dependencies

---

## Features (v2.0)

### Always-on
- **Menu bar icon** with scope SF Symbol, badge for stale clients
- **⌥⌘C** global hotkey to summon the popover from anywhere
- **⌘K** Spotlight-style command palette
- **⌥⌘Space** quick capture (tag a client, log an activity, hit ⏎)
- **iMessage, GitHub, Calendar** activity auto-flows in
- **iCloud Drive sync** across all your Macs via `~/Library/Mobile Documents`
- **Stale client notifications** (daily summary, configurable threshold)
- **Launch at login** (SMAppService)
- **Status icon pulse** when new activity arrives
- **Webhook server** on `127.0.0.1:8787` for CRM lead capture (`POST /lead`)
- **Deep link** via `missioncontrol://client/<id>`, `/add`, `/show`, `/settings`

### The popover
- Time-of-day greeting header with live stats (active / stale / due this week)
- Search + timeframe chips (All / Today / This Week / Due Soon / Stale) + tag filter chips
- **Today hero card** highlighting what needs attention
- 50px-tall rows with hover state, bulk selection, initials avatar
- Right-click for quick actions (mark contacted, snooze, archive, call, message, email)
- ⌘-click to multi-select → floating bulk action bar (mark contacted / tag / archive)
- Apple-clean empty state when nothing matches

### Client detail (single-flow layout)
- Big identity header (initials + name + company)
- Action chips (Message / Call / Email / GitHub) tinted by status
- Next-action block with due date + 9 AM follow-up reminder
- **30-day activity bar chart** (interleaves iMessage + GitHub + manual + calendar)
- Unified activity stream (iMessage / GitHub / manual entries / calendar events)
- Contact row (Phone / Email / iMessage / GitHub)
- Tag chips with inline add/remove
- Notes
- Danger zone (archive / delete)

### Settings
- Launch at login toggle
- Notifications permission + status
- Stale threshold slider (3-60 days)
- Webhook live status indicator
- Local + iCloud file paths
- Force save / reload / open in Finder

### Keyboard
- ⌥⌘C — toggle popover
- ⌘K — command palette
- ⌥⌘Space — quick capture
- ⌘N — new client
- ⌘, — settings
- esc — back / close
- ↑↓ — navigate in palette
- ⏎ — run selection

### Webhook API (CRM integration)
```
POST http://127.0.0.1:8787/lead
Content-Type: application/json

{
  "name": "Jane Smith",
  "company": "Smith LLC",
  "phone": "+15551234567",
  "email": "jane@smith.co",
  "imessage": "+15551234567",
  "github": "janesmith",
  "notes": "Met at the conference",
  "source": "Web form",
  "status": "lead"
}
```

Returns `{"id": "<uuid>", "name": "Jane Smith"}`. Client is created, icon pulses, and if it was a status=lead, it shows up in the lead filter.

### Deep links
- `missioncontrol://client/<uuid>` — open a specific client
- `missioncontrol://add?name=X&phone=Y&...` — create + open
- `missioncontrol://show` — show popover
- `missioncontrol://settings` — show settings

---

## Build & Run

```bash
cd ~/Projects/mission-control
./build-app.sh release
open build/MissionControl.app
```

For development iteration:
```bash
swift run MissionControl    # raw executable, some features need the .app bundle
```

To install into `/Applications`:
```bash
cp -R build/MissionControl.app /Applications/
```

---

## Architecture

```
Sources/MissionControl/
├── MissionControlApp.swift   # entry, status item, popover host, hotkeys
├── DataStore.swift           # @MainActor ObservableObject, iCloud sync, bulk ops, CSV
├── Models.swift              # Client, Project, ActivityEntry, MissionData
├── DesignTokens.swift        # MC.* colors, spacing, sizes
├── RootView.swift            # popover root + Header + Filter
├── FilterChips.swift         # timeframe + tag chips
├── TodayHero.swift           # due-this-week + stale cards
├── ClientList.swift          # searchable, multi-select rows
├── ClientDetail.swift        # single-flow detail with chips, charts, tags
├── AddClientSheet.swift      # new-client form (Apple-clean, no Form chrome)
├── CommandPalette.swift      # ⌘K Spotlight-style
├── SettingsView.swift        # preferences
├── OnboardingSheet.swift     # first-launch tour
├── QuickCapture.swift        # ⌥⌘Space global capture
├── ActivityStream.swift      # unified interleaved feed
├── ActivityChart.swift       # 30-day bar chart
├── TodayHero.swift           # due/stale hero
├── FilterChips.swift         # chips bar
├── BulkActionBar.swift       # floating bulk bar
├── IMessageReader.swift      # chat.db reader
├── GitHubClient.swift        # GitHub events API
├── GitHubActivityView.swift  # per-client GitHub feed
├── CalendarReader.swift      # EventKit next-meeting
├── CalendarEventView.swift   # next-meeting card
├── NotificationsManager.swift # stale + follow-up notifications
├── ICloudWatcher.swift       # NSMetadataQuery cross-device sync
├── WebhookServer.swift       # localhost HTTP server
├── DeepLinkHandler.swift     # URL scheme handler
└── Resources/Info.plist      # bundle manifest, TCC usage strings
```

### Data
- **Local:** `~/Library/Application Support/MissionControl/mission.json`
- **iCloud:** `~/Library/Mobile Documents/com~apple~CloudDocs/MissionControl/mission.json`
- **Schema:** versioned (`version: 1`); `Codable` with ISO8601 dates

### Sync model
- Writes: every 2s to local + iCloud (atomic write)
- Reads on launch: prefer iCloud copy
- External changes (other Mac edits): `NSMetadataQueryDidUpdate` notification → debounced reload
- Conflict resolution: last-write-wins (acceptable for single-user across 2 devices)

---

## Permissions requested
- **Calendar** (NSCalendarsFullAccessUsageDescription) — to show next meeting per client
- **iMessage / chat.db** (file read access) — to surface recent messages per client (no permission prompt, just file access)
- **Notifications** — for stale nudges and scheduled follow-ups
- **Network** (NSLocalNetworkUsageDescription would be needed for broader; localhost-only here) — webhook + GitHub API

---

## Roadmap
- [ ] TestFlight-friendly build (signed .pkg installer)
- [ ] Export/import individual client history
- [ ] Notion API integration (back-up to Notion DB)
- [ ] Quick capture: voice memo support
- [ ] Multi-window mode (drag client out into its own window)
- [ ] Watch + iOS companion app
- [ ] Menubar mini-stats: total revenue this month, avg days-to-contact

---

## License
Private.
