# SC2 Overlay — macOS

A real-time overlay for StarCraft 2 on macOS, powered by the [SC2 Client API](https://github.com/Blizzard/s2client-api).

## Overview

Displays live in-game information (resources, APM, unit compositions, build orders, alerts, etc.) in a transparent always-on-top window while you play.

## How It Works

StarCraft 2 exposes a local HTTP Game Client API during matches:

| Endpoint | Description |
|---|---|
| `http://localhost:6119/ui` | Current UI state (menus, game active) |
| `http://localhost:6119/game` | Active game info (map, players, game loop) |
| `http://localhost:6119/score` | Score/stats screen data |
| `http://localhost:6119/game/minimap` | Minimap image (PNG) |

The overlay polls these endpoints and renders the data in a transparent, click-through window on top of SC2.

## Enabling the SC2 Client API

Add the following to your SC2 `Variables.txt` file (located in `~/Library/Application Support/Blizzard/StarCraft II/`):

```
gameClientRequestPort=6119
```

Or launch SC2 with the flag: `-gameClientRequestPort 6119`

## Project Structure

```
sc2-overlay/
├── docs/               # Architecture decisions and API notes
├── SC2Overlay/         # Swift source code
└── SC2Overlay.xcodeproj
```

## Planned Features

- [ ] Resource tracker (minerals, gas, supply)
- [ ] APM / EAPM display
- [ ] Build order recorder
- [ ] Army value indicator
- [ ] Custom alert triggers
- [ ] Configurable layout (drag-and-drop widgets)
- [ ] Replay support

## Development

Native Swift + SwiftUI macOS app.

Build-order parser supports standard supply/time formats and SALT-encoded lines such as:

```
SALT:14|1:10|Supply Depot
```

## License

MIT
