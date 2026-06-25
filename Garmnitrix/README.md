# Garmnitrix 🟢

**Ben 10 Alien Force Omnitrix Watch App for the Garmin Forerunner 165**

> *"It's Hero Time."*

A fully vector-rendered Garmin Connect IQ **Watch App** (Device App) that transforms your Forerunner 165 into a working Omnitrix replica. Pure black and neon green only. No bitmaps. Under 90KB.

---

## Features

| Feature | Detail |
|---|---|
| **Idle Dial** | Black face + neon green hourglass symbol (two inward-pointing triangles) |
| **Battery Gradient** | Hourglass color shifts green → red as battery depletes (linear interpolation) |
| **AOD / Burn-In Protection** | Outline-only hourglass on sleep; <10% pixel budget; ±2–4px auto-shift every 60s |
| **START → Transformation Flash** | Full-screen white flash → selection mode |
| **UP / DOWN → Alien Cycle** | 10 alien silhouettes: Swampfire, Chromastone, Humungousaur, Jetray, Big Chill, Goop, Echo Echo, Alien X, Brainstorm, Spidermonkey |
| **START on Alien → Confirm Flash** | White flash → returns to Idle Dial |
| **BACK / LAP → Cancel** | Exits selection mode without selecting |
| **Invisible Clock** | Mandatory Garmin time rendered in `#3BFF00` on `#3BFF00` background — legally present, user-invisible |

---

## Color Palette

| Role | Hex | RGB |
|---|---|---|
| Background | `#000000` | (0, 0, 0) |
| Neon Green (full battery) | `#3BFF00` | (59, 255, 0) |
| Warning Red (empty battery) | `#FF0000` | (255, 0, 0) |

### Battery Color Formula

```
R = integer( 59 + ((255 − 59) × (100 − BatteryLevel) / 100) )
G = integer( 255 × (BatteryLevel / 100) )
B = 0
```

---

## Project Structure

```
Garmnitrix/
├── manifest.xml                        ← App manifest (Watch App type, fr165 target)
├── Garmnitrix.jungle                   ← Build config
├── README.md
├── source/
│   ├── Ben10OmnitrixApp.mc             ← App entry point, wires view + delegate
│   ├── Ben10OmnitrixView.mc            ← All drawing logic (idle, selection, AOD)
│   ├── Ben10InputDelegate.mc           ← Button capture (START/UP/DOWN/BACK)
│   └── MathHelper.mc                   ← Utility trig/clamp helpers
└── resources/
    ├── layouts/                        ← (empty — fully vector, no XML layout needed)
    ├── strings/
    │   └── strings.xml                 ← App name string
    └── drawables/
        └── drawables.xml               ← Launcher icon declaration
```

---

## Building

### Prerequisites

- [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) 7.x or newer
- Device definition: `fr165`

### Compile & run in simulator

```bash
# From the Garmnitrix/ directory
monkeyc -o Garmnitrix.prg \
        -f Garmnitrix.jungle \
        -y developer_key.der \
        -d fr165 \
        -w

# Launch simulator
connectiq &
monkeydo Garmnitrix.prg fr165
```

### Sideload to device

```bash
monkeyc -o Garmnitrix.prg \
        -f Garmnitrix.jungle \
        -y developer_key.der \
        -d fr165 \
        -r

# Then copy Garmnitrix.prg to the device via USB:
# /GARMIN/APPS/Garmnitrix.prg
```

> **Note:** A developer key (`developer_key.der`) is required. Generate one free via the Connect IQ Developer program at https://developer.garmin.com/connect-iq/

---

## Architecture Notes

### Why a Watch App instead of a Watch Face?

Standard `WatchFace` apps **cannot capture raw button presses** — Garmin's OS reserves all physical buttons for system navigation in watch face mode. To unlock the START/UP/DOWN button matrix for alien selection, this project uses a **Watch App (Device App)** container with a `WatchUi.BehaviorDelegate`, which gives full keypress ownership.

### AOD Burn-In Strategy

On AMOLED panels, static bright pixels cause permanent burn-in. The AOD mode:
1. Strips all solid fills (green face circle removed)
2. Renders only 1px outline strokes of the hourglass + outer ring
3. Shifts the entire rendered shape by a value from a 10-point offset cycle table (±2–4px in X and Y) on every `onUpdate` call in sleep mode

This keeps illuminated pixel count well below the 10% threshold (~15,210 pixels out of 119,716 total for a 390×390 display).

### Memory Budget

All rendering is done via native `dc.fillCircle()`, `dc.fillPolygon()`, `dc.drawLine()`, and `dc.drawCircle()` vector calls. No PNG bitmaps are loaded at runtime. Alien silhouettes are stored as lightweight `Lang.Array` of coordinate pairs — the 10 alien polygon arrays total ~2KB of static data. Total estimated memory footprint: **~18–25KB**.

---

## Alien Roster

| Index | Alien | Notes |
|---|---|---|
| 0 | Swampfire | Stocky, wide-shouldered flame alien |
| 1 | Chromastone | Angular crystal octagon body |
| 2 | Humungousaur | Massive, extra-wide silhouette |
| 3 | Jetray | Manta-ray wing spread |
| 4 | Big Chill | Ghost moth swept-wing form |
| 5 | Goop | Amorphous blob outline |
| 6 | Echo Echo | Small boxy rectangular body |
| 7 | Alien X | Tall cosmic, star-burst head |
| 8 | Brainstorm | Wide crab-like with arc pincers |
| 9 | Spidermonkey | Lanky with sprawling limbs |

---

## License

Personal hobby project. Ben 10 / Omnitrix are trademarks of Cartoon Network / Turner Broadcasting. Not affiliated with or endorsed by Garmin Ltd.
