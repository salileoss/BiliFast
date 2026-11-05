# Official-style phone feed tiles

The phone recommendation feed now uses one column of 16:9 video tiles with a 16 pt inset, circular uploader avatar,
title, uploader and upload date, like count and menu. All playable cards can autoplay while focused, regardless of
whether the server labels them as large cards. The existing tablet grid remains unchanged.

The inline host checks visibility during scrolling but starts no passing tiles. After scrolling ends, a 300 ms
idle wait selects the most visible video, choosing the upper tile when visibility is tied. Another swipe cancels
the wait. A video needs at least half its area visible to gain focus; during scrolling the current video can
continue only while more than one third remains visible. It also pauses for routes, other tabs,
backgrounding and picture in picture. Opening a tile hands its playback to the detail
page. Cards that omit an avatar or upload date resolve those fields from video details; the host caches the result
when scrolling back. Missing or failed metadata never produces an invented upload date.

## Validation

Used the pinned checkout SDK directly (`.fvm/flutter_sdk`, Flutter 3.47.7 / Dart 3.13.5).

| Check | Result |
|---|---|
| App analysis, fatal infos | Passed, no issues |
| Full Flutter unit/widget suite | Passed: 4,517 tests |
| Core suite | Passed: 1,202 tests, one existing skip |
| Workflow suite | Passed: 36 tests |
| Windows release build | Passed |
| Windows native integration | Appearance: 1 passed; player: 11 passed |
| Layout renders | Light and dark phone renders inspected, including upload time |
| Whitespace | Passed |

Regression coverage includes ordinary-card autoplay, single-player focus, scrolling, pause/resume and page handoff;
feed and detail-derived upload dates; refresh batches, pagination, watch later, dislike/undo, accessibility and text
scaling. The initial combined Windows integration run could not attach to the player debug process; the isolated
player run passed all 11 tests, matching the previously documented launcher behavior.

## Build

Application source: `48566ad`. Build-only branch: `build/ipa-feed-tiles` in `salileoss/BiliFast`.
Build commit: `9a1813ecb0c08739c6b4c397aa7384cc99ce9fc4`.
[macOS pipeline](https://github.com/salileoss/BiliFast/actions/runs/41963651855).

The pipeline passed and the unsigned IPA was downloaded and verified locally:
`build/ipa/BiliFast-1.3.0-9-feed-tiles.ipa` (18.2 MB), with its JSON manifest beside it.
Bundle ID `com.kaichuan.bilifast`, version `1.3.0`, build `9`, minimum iOS `26.0`.
Local checks passed for manifest source commit, SHA-256, ZIP integrity, ARM64 Mach-O executable, app framework,
version/bundle identity and absence of a provisioning profile. This IPA requires signing for sideloading.

SHA-256: `74b0c5ba99fa05230aae0d391f3aa987cae610d327a18e68869363044ac50a70`.

## Phone checks

1. Open recommendations and scroll through several formerly small cards: each spans the feed width, with the
   uploader avatar, name and upload time below it.
2. Drag a playing tile out of view without lifting your finger: it pauses by the time two thirds is hidden. Scroll
   past several tiles: none should start during dragging or coasting. Stop for 300 ms: only the focused tile starts.
   Scroll back without refreshing: it resumes from the previous position, including after a 30 second absence or after
   scrolling several tiles away. One plays at a time; sound and danmaku choices persist between tiles.
3. Open a playing tile and return: playback continues from the same position. A sheet, another tab, backgrounding
   and picture in picture pause the feed as appropriate.
4. Refresh, reach the previous-batch divider, load more cards, and use watch later or dislike/undo.

Native iOS playback and touch behavior still require an actual phone; local widget renders and Windows playback
checks do not substitute for that acceptance.

## Scroll focus correction

Visibility is now evaluated during dragging and flinging, using the video rectangle's intersection with the feed
viewport. Focus pauses by one third visible, requires half visible to resume, and picks the upper tile when two
videos are equally visible. Existing position storage resumes playback after a short pause, the 30 second player
release, and lazy-list disposal/recreation without refreshing the feed.

Validation after this correction: all 4,520 Flutter tests passed, including 30 focused inline playback tests;
fatal-info analysis and whitespace checks passed. Regression tests verify the one-third boundary in both vertical
directions, horizontal clipping, pausing before gesture release, deterministic focus, and resuming from 37 seconds.

Updated application source: `92409b1`. Build commit: `312f50ed145bba31771c9a5b0703a667cceedbef`.
The [updated macOS pipeline](https://github.com/salileoss/BiliFast/actions/runs/41968056207) passed.
IPA version 1.3.0 (10) is saved at `build/ipa/BiliFast-1.3.0-10-feed-focus.ipa`, with its JSON manifest beside it.
Local manifest source, SHA-256, ZIP integrity, ARM64 binary, app framework, bundle identity and version checks passed.
It remains unsigned and requires signing for sideloading. The 36 workflow tests also passed.

SHA-256: `9da62589f5bec4d5715fd508c03bbd8dba7e90667339fb295fa7e335a74b42b8`.

## Autoplay after scrolling rests

Dragging and ballistic scrolling now block both new players and paused-player resumes. The existing player may
continue through small movements but pauses at one third visible. After ScrollEnd, a cancellable 300 ms wait
allows one eligible tile to start; later movement cancels the wait. Registration, pagination and rebuild callbacks
cannot bypass this gate. Recommendations, the follow list, uploader sheet and post page share the rule. Initial
feed playback remains immediate, and the existing 30 second release and saved-position behavior are preserved.

Validation: the full Flutter suite passed 4,524 tests; the final six host tests also passed, including an additional
resume/nested-scroll regression added after the full run began. The 34-test focused run passed before that last
regression. Analysis with fatal infos, 36 workflow tests and whitespace checks passed. The fling test verifies zero
new player allocations throughout ballistic motion, then exactly one start after idle. No physical-phone battery
measurement was performed.
