# Architecture

## Goal

A lightweight, click-through macOS overlay that displays Spawning Tool build orders in real time, synchronized to in-game supply count via the SC2 Client API.

## Tech Stack: Swift + SwiftUI

**Rationale:**
- `NSWindow.ignoresMouseEvents = true` — fully click-through, never steals keyboard or mouse input from SC2
- No secondary runtime (no Chromium, no Python interpreter, no Node.js) — lowest possible CPU/RAM overhead
- Native macOS transparent window compositing
- SwiftUI async/await for non-blocking API polling

## Data Flow

```
User loads build order
  (paste Spawning Tool URL or import JSON)
         │
         ▼
BuildOrderLoader
  parses steps → [BuildStep(supply: Int, action: String)]
         │
         ▼
SC2PollingService          (runs every 500ms on background thread)
  GET /ui   → is game active?
  GET /score → scoreValueFoodUsed (current supply)
         │
         ▼
BuildOrderTracker
  currentStep = last step where step.supply <= currentSupply
  nextStep    = first step where step.supply > currentSupply
         │
         ▼
OverlayView (SwiftUI, transparent NSWindow)
  shows: currentStep (dimmed) + nextStep (highlighted)
  compact: ~300×80px, corner of screen, fully click-through
```

## Window Setup

```swift
// NSWindow configuration for overlay
window.level = .floating          // always on top
window.isOpaque = false
window.backgroundColor = .clear
window.hasShadow = false
window.ignoresMouseEvents = true  // click-through — SC2 gets all input
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
```

## Build Order Format

Spawning Tool steps are supply-based. Internal representation:

```swift
struct BuildStep: Identifiable {
    let id: UUID
    let supply: Int       // supply count that triggers this step
    let action: String    // e.g. "Supply Depot", "Barracks"
    let note: String?     // optional note
}
```

## Spawning Tool Integration

Spawning Tool build orders can be:
1. **Imported by URL** — scrape/parse the build order page
2. **Pasted as text** — parse line-by-line (e.g. `14 - Supply Depot`)
3. **Loaded from JSON export** — if Spawning Tool provides an export format

## Performance Budget

| Component | Target |
|---|---|
| CPU overhead | < 0.5% average |
| RAM usage | < 30 MB |
| SC2 API poll interval | 500ms |
| UI frame rate | 30 fps (no animation needed) |
| Input latency impact | 0ms (click-through window) |

## Project Structure

```
sc2-overlay/
├── SC2Overlay.xcodeproj
└── src/
    ├── App/
    │   ├── SC2OverlayApp.swift       # @main, AppDelegate
    │   └── OverlayWindowManager.swift # NSWindow setup (click-through, floating)
    ├── API/
    │   └── SC2APIClient.swift        # Polls /ui and /score endpoints
    ├── BuildOrder/
    │   ├── BuildStep.swift           # Data model
    │   ├── BuildOrderParser.swift    # Parses text/URL input
    │   └── BuildOrderTracker.swift   # Tracks current position by supply
    └── UI/
        ├── OverlayView.swift         # Main SwiftUI overlay (compact, transparent)
        └── SettingsView.swift        # Port config, opacity, position
```
