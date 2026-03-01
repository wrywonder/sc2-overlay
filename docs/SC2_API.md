# SC2 Client API Reference

StarCraft 2 ships with a built-in local HTTP server that exposes game state during matches. No mods or third-party tools required.

## Setup

### Option 1 — Variables.txt (persistent)

Edit `~/Library/Application Support/Blizzard/StarCraft II/Variables.txt` and add:

```
gameClientRequestPort=6119
```

### Option 2 — Launch flag (one-time)

```
/Applications/StarCraft\ II/SC2.app/Contents/MacOS/SC2 -gameClientRequestPort 6119
```

## Endpoints

Base URL: `http://localhost:6119`

### `GET /ui`

Current UI state. Tells you whether the game is in a menu, loading, or active.

```json
{
  "activeScreens": []
}
```

When `activeScreens` is empty → game is running (not in a menu).

---

### `GET /game`

Active game metadata.

```json
{
  "isReplay": false,
  "displayTime": 42.5,
  "players": [
    {
      "id": 1,
      "name": "wrywonder",
      "type": "user",
      "race": "Terr",
      "result": "Undecided"
    },
    {
      "id": 2,
      "name": "Opponent",
      "type": "user",
      "race": "Zerg",
      "result": "Undecided"
    }
  ]
}
```

Key fields:
- `displayTime` — elapsed game time in seconds
- `players[].race` — `"Terr"`, `"Zerg"`, `"Prot"`, `"Random"`
- `players[].result` — `"Undecided"`, `"Victory"`, `"Defeat"`, `"Tie"`

---

### `GET /score`

Score screen stats (available in-game and post-game).

```json
{
  "player": [
    {
      "id": 1,
      "scoreValueMineralsCollectionRate": 1200,
      "scoreValueVespenCollectionRate": 300,
      "scoreValueWorkersActiveCount": 22,
      "scoreValueMineralsCurrent": 450,
      "scoreValueVespenCurrent": 150,
      "scoreValueFoodUsed": 48,
      "scoreValueFoodMade": 54,
      "scoreValueArmyValueMinerals": 800,
      "scoreValueArmyValueVespen": 200,
      "scoreValueKillsMapUnit": 4,
      "scoreValueLostMinerals": 200
    }
  ]
}
```

Key fields for overlay:
| Field | Meaning |
|---|---|
| `scoreValueMineralsCurrent` | Current mineral count |
| `scoreValueVespenCurrent` | Current gas count |
| `scoreValueWorkersActiveCount` | Active worker count |
| `scoreValueMineralsCollectionRate` | Mineral income per minute |
| `scoreValueFoodUsed` / `scoreValueFoodMade` | Supply used / cap |

---

### `GET /game/minimap`

Returns a PNG image of the current minimap.

---

## Polling Strategy

The API does not push events — you must poll.

Recommended intervals:
- `/ui` — 1 second (just need to know if game is active)
- `/game` — 5 seconds (player/race info doesn't change mid-game)
- `/score` — 0.5–1 second (resources update frequently)
- `/game/minimap` — 2–5 seconds (expensive to render)

## Known Limitations

- Only available during an active match or replay
- Returns `{"error":"Not in game"}` when not playing
- No push/WebSocket support — polling only
- Does not expose unit positions or full game state (use [s2client-proto](https://github.com/Blizzard/s2client-proto) for that, but requires a different setup)
