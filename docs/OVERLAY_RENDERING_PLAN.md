# Overlay Rendering Plan

## Status: All approaches below are candidates for iteration

The current Swift/SwiftUI native overlay approach has not successfully rendered over SC2 in practice, despite using high window levels and keep-on-top timers. This document catalogs every viable approach we can try, ordered roughly by feasibility and effort.

---

## Problem Statement

We need to display real-time game state information (build order, supply, resources) on top of StarCraft 2 while it is running. SC2 exposes a local HTTP API on `localhost:6119` that provides game state. The challenge is **rendering visual output on top of the game** in a way that:

1. Is visible over SC2 in all display modes (windowed, fullscreen, borderless)
2. Does not steal input (click-through)
3. Does not violate macOS security policies (SIP, notarization)
4. Has minimal performance impact

---

## What We Have Tried

### Attempt 1: Native SwiftUI Overlay Window (`OverlayWindowManager.swift`)

**What it does:**
- Creates a borderless `NSWindow` with `backgroundColor = .clear`, `isOpaque = false`
- Sets `ignoresMouseEvents = true` for click-through
- Uses `CGWindowLevelForKey(.screenSaverWindow)` (level 1000) to sit above fullscreen
- Collection behavior: `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`, `.ignoresCycle`
- Timer calls `orderFrontRegardless()` every 1 second

**Why it hasn't worked:**
- macOS fullscreen spaces may composit game windows in a separate layer that sits above even screenSaver-level windows
- SC2's Metal/OpenGL rendering in exclusive fullscreen can bypass the macOS window server entirely
- Game Mode on macOS Sonoma+ may further restrict overlay visibility
- `orderFrontRegardless()` may not survive SC2's rendering pipeline reclaiming the display

---

## Approaches to Try

### Approach 1: Windowed / Borderless Windowed SC2 Mode

**Difficulty: Trivial | Reliability: High | Invasiveness: None**

The simplest fix: run SC2 in **Windowed (Fullscreen)** mode instead of exclusive fullscreen.

**How:**
- In SC2 Settings > Graphics > Display Mode, choose "Windowed (Fullscreen)" or "Windowed"
- The macOS window server retains full compositing control
- Our existing `NSWindow` overlay should render correctly above a windowed app

**Why this might work:**
- Exclusive fullscreen bypasses the window server. Windowed fullscreen does not.
- This is how most modern overlays (Discord, Steam) work on macOS — they require windowed or borderless fullscreen.

**Trade-offs:**
- Slight input latency increase vs. exclusive fullscreen (typically <1ms, negligible for SC2)
- Possible minor FPS reduction from window compositing
- User must change their SC2 display settings

**Action items:**
- [ ] Test with SC2 in "Windowed (Fullscreen)" mode
- [ ] Test with SC2 in "Windowed" mode
- [ ] Verify overlay appears and is click-through
- [ ] Measure FPS impact if any

---

### Approach 2: OBS Browser Source Overlay (Stream-Based)

**Difficulty: Low | Reliability: High | Invasiveness: None**

Use OBS Studio's browser source to render an overlay that composites on top of SC2 capture.

**How:**
1. Build a simple HTML/JS page that polls `localhost:6119` and displays game state
2. In OBS, capture SC2 as a Game/Window source
3. Add a Browser Source layer on top pointing to our HTML page
4. Use OBS "Fullscreen Projector" on the monitor to display the composited result

**Why this might work:**
- OBS does its own compositing — it captures SC2's framebuffer and draws the HTML overlay on top
- No dependency on macOS window layering at all
- Battle-tested approach used by every SC2 streamer

**Trade-offs:**
- Requires OBS running (extra ~2-5% CPU)
- Adds one frame of latency from capture pipeline
- User sees the OBS projector, not the actual SC2 window
- Only works on the monitor running the OBS projector
- Great for streaming, slightly awkward for personal use

**Action items:**
- [ ] Create a standalone `overlay.html` that polls the SC2 API and renders build order
- [ ] Test as OBS browser source
- [ ] Document OBS setup steps

---

### Approach 3: Electron / Tauri Transparent Window

**Difficulty: Medium | Reliability: Medium | Invasiveness: Low**

Use Electron or Tauri to create a transparent, always-on-top, click-through window. These frameworks have cross-platform fullscreen overlay support that may handle macOS edge cases better than raw AppKit.

**How (Electron):**
```js
const win = new BrowserWindow({
  transparent: true,
  frame: false,
  alwaysOnTop: true,
  skipTaskbar: true,
  focusable: false,
  hasShadow: false,
  webPreferences: { nodeIntegration: true }
});
win.setAlwaysOnTop(true, 'screen-saver');
win.setIgnoreMouseEvents(true);
win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
```

**How (Tauri):**
- Uses `tauri::window::WindowBuilder` with `.transparent(true)`, `.always_on_top(true)`, `.decorations(false)`
- Tauri v2 supports `set_ignore_cursor_events(true)`

**Why this might work:**
- Electron's `setAlwaysOnTop(true, 'screen-saver')` maps to the same window level but may handle fullscreen spaces differently
- Electron's `setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true })` explicitly enables fullscreen visibility
- These frameworks are battle-tested for overlay use cases (Discord, Overwolf)
- Tauri has much lower resource footprint than Electron

**Trade-offs:**
- Electron: ~80-150MB RAM overhead from Chromium
- Tauri: ~15-30MB RAM overhead (uses system WebView)
- Adds a runtime dependency
- May still not work over exclusive fullscreen — same macOS compositing limitations

**Action items:**
- [ ] Prototype with Electron using `setAlwaysOnTop('screen-saver')` + `setVisibleOnAllWorkspaces`
- [ ] Test over SC2 fullscreen, windowed fullscreen, windowed
- [ ] If Electron works, consider Tauri port for lower overhead

---

### Approach 4: Second Monitor / External Display

**Difficulty: Trivial | Reliability: Guaranteed | Invasiveness: None**

Display the overlay on a second monitor instead of on top of SC2.

**How:**
- Render the overlay as a normal window on a secondary display
- SC2 runs fullscreen on the primary monitor
- Overlay polls the API and shows game state on monitor 2

**Why this works:**
- No compositing conflicts — completely separate display
- Works with any SC2 display mode
- Zero FPS impact on the game

**Trade-offs:**
- Requires a second monitor (or phone/tablet as second display)
- Player must look away from the game to see the overlay
- Not ideal for competitive play where eyes must stay on the game

**Action items:**
- [ ] Add display selector to Settings (choose which NSScreen to place the overlay on)
- [ ] Test with SC2 fullscreen on primary, overlay on secondary

---

### Approach 5: macOS Accessibility Overlay (CGS Private APIs)

**Difficulty: High | Reliability: Unknown | Invasiveness: High**

Use private macOS CoreGraphics Server (CGS) APIs to create windows in the "overlay" layer that sits above all other windows, including fullscreen spaces.

**How:**
```swift
// Private CGS APIs (undocumented, may break between macOS versions)
typealias CGSConnectionID = UInt32
@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> CGSConnectionID
@_silgen_name("CGSSetWindowLevel") func CGSSetWindowLevel(_ cid: CGSConnectionID, _ wid: UInt32, _ level: Int32) -> CGError

// Set window to kCGOverlayWindowLevel (102) or higher
let cid = CGSMainConnectionID()
let wid = UInt32(window.windowNumber)
CGSSetWindowLevel(cid, wid, 102) // overlay level
```

**Why this might work:**
- CGS overlay windows are composited by the window server at a layer above fullscreen spaces
- This is how some system UI (e.g., Force Quit dialog) appears over fullscreen apps

**Trade-offs:**
- Uses **private, undocumented APIs** — can break with any macOS update
- App Store rejection guaranteed (if we ever want to distribute there)
- May require disabling SIP to use some CGS functions
- Notarization issues possible
- Fragile and hard to debug

**Action items:**
- [ ] Research current CGS API signatures for macOS Sonoma/Sequoia
- [ ] Prototype window level manipulation via CGS
- [ ] Test over SC2 fullscreen

---

### Approach 6: Touch Bar / Menu Bar Display (Minimal Overlay)

**Difficulty: Low | Reliability: High | Invasiveness: None**

Instead of overlaying the game, display build order information in the macOS menu bar or Touch Bar (on MacBooks that have it).

**How:**
- Use `NSStatusItem` with a variable-length display
- Show the next build step, current supply, and game time in the menu bar text
- Example: `▶ 22: Factory | 18/22 | 3:45`

**Why this works:**
- Menu bar is always visible, even over fullscreen apps (unless auto-hidden)
- No window layering issues at all
- Extremely lightweight

**Trade-offs:**
- Very limited display space
- May not be visible if menu bar is set to auto-hide in fullscreen
- Not a true overlay — information is in the periphery

**Action items:**
- [ ] Add live build order display to the existing `NSStatusItem`
- [ ] Test visibility with SC2 in fullscreen (check menu bar auto-hide behavior)

---

### Approach 7: Text-to-Speech / Audio Cues

**Difficulty: Low | Reliability: High | Invasiveness: None**

Instead of visual overlay, use audio cues to prompt the player about upcoming build steps.

**How:**
- Use `NSSpeechSynthesizer` or `AVSpeechSynthesizer` to announce build steps
- Play a subtle chime when supply threshold is reached
- Optionally speak the action: "Supply Depot at 14"

**Why this works:**
- No rendering issues at all — pure audio
- Works with any display mode, any OS version
- Player doesn't need to look away from the game

**Trade-offs:**
- Can be distracting or annoying
- Competes with in-game audio cues
- Less information density than visual overlay
- Not suitable for all build order styles (rapid sequences)

**Action items:**
- [ ] Add TTS option for build step announcements
- [ ] Add configurable audio chime for step triggers
- [ ] Add volume/voice controls

---

### Approach 8: Notification Center Alerts

**Difficulty: Low | Reliability: Medium | Invasiveness: None**

Use macOS `UNUserNotificationCenter` to display build order steps as system notifications.

**How:**
- When a build step threshold is reached, fire a notification
- Notifications appear as banners at the top-right, even over fullscreen apps (if user has notifications enabled)

**Why this might work:**
- macOS notification banners render above fullscreen spaces
- Built-in system compositing — no custom window management

**Trade-offs:**
- Notifications can be delayed or batched by macOS
- User may have Do Not Disturb / Focus mode enabled during gaming
- Limited styling options
- May feel spammy for rapid build steps
- Notifications disappear after a few seconds

**Action items:**
- [ ] Prototype notification-based build step alerts
- [ ] Test banner visibility over SC2 fullscreen
- [ ] Check behavior with Focus modes

---

### Approach 9: Web Dashboard (Companion App)

**Difficulty: Low | Reliability: High | Invasiveness: None**

Run a local web server that serves a dashboard accessible from any device (phone, tablet, second computer).

**How:**
1. Embed a lightweight HTTP server (e.g., Swift Vapor, or a simple Python/Node server)
2. Serve an HTML dashboard that polls the SC2 API and displays game state
3. Access from `http://<mac-ip>:8080` on any device on the local network

**Why this works:**
- Completely decoupled from SC2's rendering
- Works on any device — phone on desk, tablet as second screen, etc.
- Can display much richer information than an overlay

**Trade-offs:**
- Requires a secondary device for viewing
- Player must glance at another device
- Adds network/server overhead (minimal)

**Action items:**
- [ ] Add embedded HTTP server to the app
- [ ] Create responsive web dashboard
- [ ] Display build order, supply, resources, game time

---

### Approach 10: Metal/OpenGL Injection (DYLIB Injection)

**Difficulty: Very High | Reliability: Medium | Invasiveness: Very High**

Inject a dynamic library into SC2's process to hook Metal or OpenGL rendering calls and draw overlay content in the game's own render pipeline.

**How:**
- Create a `.dylib` that hooks `MTLCommandBuffer.present()` or `glSwapBuffers()`
- Use `DYLD_INSERT_LIBRARIES` to load the dylib into SC2's process
- Draw overlay geometry/text before the frame is presented

**Why this might work:**
- Renders directly in the game's framebuffer — guaranteed visibility
- This is how Steam Overlay and many game hacking tools work on other platforms

**Trade-offs:**
- **SIP must be disabled** to use `DYLD_INSERT_LIBRARIES` on system-protected apps
- SC2 may be code-signed — injection breaks the signature and may trigger anti-cheat
- Extremely fragile — must match SC2's rendering API version exactly
- Could be considered cheating by Blizzard (violation of ToS)
- Very high development effort
- Different code paths for Metal vs. OpenGL
- Could crash SC2

**Action items:**
- [ ] Research whether SC2 uses Metal or OpenGL on current macOS
- [ ] Prototype dylib injection on a non-protected app first
- [ ] Assess anti-cheat/ToS risk

---

### Approach 11: Screen Capture + Composite (Virtual Display)

**Difficulty: High | Reliability: Medium | Invasiveness: Medium**

Capture SC2's screen output, composite the overlay in real-time, and display the result.

**How:**
- Use `ScreenCaptureKit` (macOS 12.3+) to capture SC2's window
- Composite overlay content onto each captured frame using Core Image/Metal
- Display the composited result in a fullscreen window

**Why this might work:**
- ScreenCaptureKit can capture exclusive fullscreen content
- We control the final composited output

**Trade-offs:**
- Adds significant latency (capture + composite + display pipeline)
- High CPU/GPU overhead from real-time video processing
- Input routing becomes complex (need to forward input to SC2)
- Poor player experience due to latency
- Basically building a mini-OBS

**Action items:**
- [ ] Prototype ScreenCaptureKit capture of SC2
- [ ] Measure latency and overhead

---

### Approach 12: SC2 Custom UI Mod / Extension

**Difficulty: High | Reliability: High | Invasiveness: Medium**

Create an SC2 custom mod or extension that renders overlay information using SC2's own UI system.

**How:**
- SC2 supports custom UI through the Galaxy Map Editor
- Create a mod/extension that reads from a local file or connects to a local server for build order data
- The mod renders UI elements within SC2's own rendering pipeline

**Why this might work:**
- Renders using SC2's own engine — guaranteed visibility and proper compositing
- No macOS window layering issues
- Officially supported by Blizzard's modding tools

**Trade-offs:**
- Requires learning SC2's Galaxy scripting language
- Mod must be loaded for each game
- Cannot be used in ranked/ladder games (only custom games and vs AI)
- Limited to what SC2's UI system supports
- Development in Galaxy editor is cumbersome

**Action items:**
- [ ] Research SC2 custom UI capabilities and limitations
- [ ] Determine if mods can read from localhost HTTP endpoints
- [ ] Check if UI extensions work in ladder games

---

## Recommended Iteration Order

Based on effort vs. likelihood of success:

| Priority | Approach | Why |
|----------|----------|-----|
| **1** | **Windowed Fullscreen** (Approach 1) | Zero code changes, just a settings change. Test this first. |
| **2** | **Menu Bar Display** (Approach 6) | Minimal code, always visible, already have status bar item. |
| **3** | **Audio Cues / TTS** (Approach 7) | No rendering at all, works everywhere, low effort. |
| **4** | **Web Dashboard** (Approach 9) | Works on any device, rich display, moderate effort. |
| **5** | **OBS Browser Source** (Approach 2) | Great for streamers, proven approach, needs HTML page. |
| **6** | **Electron/Tauri Window** (Approach 3) | Different framework may handle macOS quirks better. |
| **7** | **Second Monitor** (Approach 4) | Guaranteed to work, needs hardware. |
| **8** | **Notification Center** (Approach 8) | May work over fullscreen, low effort to test. |
| **9** | **CGS Private APIs** (Approach 5) | Risky but may solve the core problem. |
| **10** | **SC2 Custom Mod** (Approach 12) | Works in-engine but restricted to custom games. |
| **11** | **Screen Capture** (Approach 11) | High overhead, latency concerns. |
| **12** | **Metal/OpenGL Injection** (Approach 10) | Last resort, very high risk and effort. |

---

## Key Insight

The most likely reason our current overlay doesn't appear is that **SC2 is running in exclusive fullscreen mode**, which bypasses the macOS window server compositing pipeline entirely. In exclusive fullscreen, the game takes direct control of the display — no other windows (regardless of level) can appear above it.

The fix is either:
- **Don't fight the display pipeline** — use windowed fullscreen, audio, menu bar, or a second screen
- **Work within SC2's pipeline** — mods/extensions that render inside the game
- **Capture and recomposite** — OBS or ScreenCaptureKit approaches that rebuild the frame

Fighting the macOS window server with higher window levels will not work if the game is in true exclusive fullscreen.
