# Official-style phone feed tiles

The phone recommendation feed now uses one column of 16:9 video tiles with a 16 pt inset, circular uploader avatar,
title, uploader and upload date, like count and menu. All playable cards can autoplay while focused, regardless of
whether the server labels them as large cards. The existing tablet grid remains unchanged.

The inline host selects one visible video after scrolling settles. It retains the current video during a drag and
pauses for routes, other tabs, backgrounding and picture in picture. Opening a tile hands its playback to the detail
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
2. Stop on different tiles: one plays at a time; sound and danmaku choices persist between tiles.
3. Open a playing tile and return: playback continues from the same position. A sheet, another tab, backgrounding
   and picture in picture pause the feed as appropriate.
4. Refresh, reach the previous-batch divider, load more cards, and use watch later or dislike/undo.

Native iOS playback and touch behavior still require an actual phone; local widget renders and Windows playback
checks do not substitute for that acceptance.
