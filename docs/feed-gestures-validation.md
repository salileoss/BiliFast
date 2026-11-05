# Focused feed tile playback gestures

## Plan and behavior

1. Reuse the video player's seek math, target preloading, temporary 2× speed and HUD in the focused feed tile.
2. Let horizontal drags seek while vertical drags continue scrolling. Preserve taps, sound, danmaku and page handoff.
3. Cancel the gesture when focus, playback, the route or app visibility changes. Verify behavior and build a local IPA.

While a tile is focused and playing, dragging horizontally previews a position: right moves forward and left moves
backward, at 90 seconds per tile width, clamped to the video's duration. Holding still during a drag for 150 ms
preloads the target. Lifting commits one keyframe seek; cancelling discards it and clears the preload hint.
A stationary 350 ms long press temporarily plays at 2× and restores the chosen speed on release or cancellation.
Vertical swipes scroll the feed. A tap still opens the detail page on the existing playback.

The inline playback owns gesture cleanup so tab changes, backgrounding, native pause, player release and page
handoff restore the speed and cancel a pending scrub before the session is transferred or disposed.

## Validation

- 115 focused feed/host/player gesture/HUD tests passed, including 14 new behavioral regressions.
- Six phone render tests passed, including new light/dark seek and speed HUD renders; rendered PNGs inspected locally.
- Analysis with fatal infos passed.
- All 36 workflow checks passed.
- The full Flutter suite passed: 4,541 tests.
- Windows release build passed; all 11 native Windows playback integration tests passed.

## Local IPA

Application source: `b435cf585d255eb5f02851362347e0c2e8d08743`.
Build commit: `850caf44f8fa485b69cad8f60256954b12b796e8` on the fork's build-only branch `build/ipa-feed-tiles`.
The [macOS pipeline](https://github.com/salileoss/BiliFast/actions/runs/42087741900) passed.

IPA 1.3.0 (12) is saved at `build/ipa/BiliFast-1.3.0-12-feed-gestures.ipa` (19,074,440 bytes), with its JSON manifest.
Local checks passed for the source commit, SHA-256, ZIP integrity, ARM64 executable, app framework, bundle identity,
version and absence of a provisioning profile. The application files in the build commit match the tested source.
The IPA is unsigned and requires signing for sideloading; minimum iOS is 26.0.

SHA-256: `5a3cfe161b5f52cf31c38bc0070837efe8103068f791a54c33d36698221475f1`.

## Phone checks

1. Let the focused home-feed tile play. Swipe right, hold at the target, reverse left, then release. Check the HUD,
   the resulting position, continued playback and that the detail page did not open.
2. Hold the playing tile without moving: check 2× playback and restoration of the original speed on release.
3. Swipe vertically starting on the tile: the feed scrolls. Tap the video or title: the detail page opens as before.
4. During a seek or hold, switch tabs or background the app. Return: there is no stuck HUD, seek or temporary speed.
5. Check the sound and danmaku buttons, then repeat in dark mode.

Native AVPlayer playback and iPhone touch behavior require a physical device; automated Flutter tests and desktop
playback do not replace that acceptance check.
