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

## Phone checks

1. Let the focused home-feed tile play. Swipe right, hold at the target, reverse left, then release. Check the HUD,
   the resulting position, continued playback and that the detail page did not open.
2. Hold the playing tile without moving: check 2× playback and restoration of the original speed on release.
3. Swipe vertically starting on the tile: the feed scrolls. Tap the video or title: the detail page opens as before.
4. During a seek or hold, switch tabs or background the app. Return: there is no stuck HUD, seek or temporary speed.
5. Check the sound and danmaku buttons, then repeat in dark mode.

Native AVPlayer playback and iPhone touch behavior require a physical device; automated Flutter tests and desktop
playback do not replace that acceptance check.
