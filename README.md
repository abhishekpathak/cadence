# Cadence

A small macOS focus timer built around a three-step cycle instead of a bare countdown:

**Focus (25) → Review (5) → Restful wakefulness (5)**

A pomodoro counts once you've focused for at least 10 minutes (paused time doesn't count); review and rest are encouraged but optional. Shorter focus sessions aren't recorded. Durations are configurable.

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

The start screen asks what the session is for; type it and press Return (or click Start) to start. Click **Done** to move on through each step.

Click the 🍅 menu bar icon for **Settings…** (phase lengths in whole minutes, start at login), **Show / Hide** and **Quit**.

Finished sessions are appended, one JSON object per line, to `~/Library/Application Support/Cadence/sessions.jsonl`. History is never rewritten, so a crash or an unreadable line can't wipe it.

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

Personal project, early. Not built yet: a "gentle dislodge" nudge when focus ends (there is a no-op `DislodgeAction` hook for it) and screensaver-style review/rest overlays.

## License

[MIT](LICENSE)
