# Cadence

A small macOS focus timer built around a three-step cycle instead of a bare countdown:

**Focus (25) → Active recall (5) → Restful wakefulness (5)**

A pomodoro counts as successful once you've gone through all three steps. A separate 15-minute break is available between pomodoros. Durations are configurable.

The timer lives in a small, borderless, always-on-top window. Hover the clock to pause or resume.

## Install

Requires macOS 13+ and the Swift toolchain (Command Line Tools are enough; Xcode is not needed).

```sh
git clone git@github.com:abhishekpathak/cadence.git
cd cadence
./build.sh install   # builds Cadence.app and copies it to /Applications
```

The app is ad-hoc signed, not notarised, so on first launch macOS may block it. Right-click the app and choose **Open**.

## Use

Starting a focus session asks what it's for. Move through the steps from the window, or with global hotkeys:

| Hotkey | Action |
|---|---|
| ⌃⌥P | Start focus |
| ⌃⌥R | Start recall |
| ⌃⌥E | Start rest |
| ⌃⌥B | Start break |
| ⌃⌥Space | Pause / resume |
| ⌃⌥X | End the current phase |

Click the 🍅 menu bar icon for **Settings…** (phase lengths in whole minutes, start at login), **Show / Hide** and **Quit**.

Finished sessions are stored as JSON in `~/Library/Application Support/Cadence/sessions.json`.

## Develop

```sh
swift build
.build/debug/Cadence --snapshot .snap   # render every UI state to PNGs, no screen-recording permission needed
CADENCE_SCALE=60 .build/debug/Cadence   # run 60x faster (a "minute" lasts one second)
```

Tests (Swift Testing). With only the Command Line Tools installed, the testing macro plugin has to be passed explicitly:

```sh
swift test -Xswiftc -load-plugin-library -Xswiftc \
  /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib
```

The timer logic lives in `Sources/CadenceCore` and is unit-tested; the app is in `Sources/Cadence`.

## Status

Personal project, early. Not built yet: a "gentle dislodge" nudge when focus ends (there is a no-op `DislodgeAction` hook for it) and screensaver-style recall/rest overlays.

## License

[MIT](LICENSE)
