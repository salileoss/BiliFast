# Recommendation variety

Keep Bilibili's personalized feed as the candidate source. Add local, account-scoped exposure and meaningful
viewing memory, favor unseen videos, spread creators, and fetch at most one extra page when a refresh is mostly
repeats. No related-video discovery mix in this step and no new server-side watch reporting.

Implementation ownership:
- Shared services and bootstrap: main agent (`app_scope.dart`, `main.dart`).
- Preference persistence and selection: store agent (`feed_preferences.dart` and its tests).
- Refresh selection, paging, metrics and home integration: feed agent (`feed_model.dart`, `home_page.dart` and tests).
- Visible exposure and meaningful viewing: playback agent (inline playback, tile and local tracker files and tests).

Phone checks:
1. Browse several tiles, then refresh repeatedly. Prefer videos not recently visible while spreading uploaders.
2. Watch a tile for a while, seek and replay it. Only actual viewing contributes; no new Bilibili history entry is
   created by inline autoplay.
3. Restart the app and refresh. Recently seen memory survives.
4. Switch accounts and return. Each account keeps its own preferences and old requests cannot alter the new feed.
5. Cancel an armed pull, retry a failed refresh, and scroll beyond the previous-batch divider. Existing behavior
   remains intact; a lack of alternatives must never blank the feed.

Only phone use can establish whether the relevance/variety balance feels better with the live candidate pool.

## Selection and local memory

The app still requests Bilibili's personalized official feed when authorized, and the existing web fallback otherwise.
Each batch first favors videos not seen in the last 48 hours, then recently seen videos, then videos completed in
the last 14 days. Creator spreading aims for at most two appearances in a rolling ten within each novelty tier;
a narrow pool still fills the batch. At least 30 seconds of actual viewing, or completion of a short video, gives
that uploader a small affinity boost capped at two positions. Novelty and creator spreading take priority.

A refresh whose first batch is less than half unseen can request one additional sequential page from the same
source. That optional request waits at most two seconds, with no retry or extra source fallback. The selected
batch keeps its original size; unused candidates are retained for load more before another network call. A failed
optional request preserves the successful first batch. Canceled early pulls never publish a batch or record exposure.

Exposure requires at least half the tile to remain visible for one second while home is foreground and uncovered.
Lazy builds, cover prefetches, hidden tabs and cached rows do not count. Account changes disable exposure and
playback of the previous account's cards until a replacement batch is accepted.

Local viewing records unique watched media intervals and actual elapsed viewing time, rather than seek position.
Seeking, scrubbing, buffering, background time and repeat loops contribute no fabricated progress. Completion
requires 90% unique content coverage. Updates are batched every 15 seconds and on pause/close; backgrounding
flushes the final batch to disk. Inline playback still sends no new server history reports.

`feed_preferences.json` stores only video/uploader identifiers, account ownership, timestamps and viewing totals,
on this device. Guest and saved-account records are separate. Records expire after 30 days and are bounded to
2,000 videos per account and ten accounts. Writes are serialized and atomic; malformed/expired/excess rows are
removed on load. Failures leave the in-memory feed usable. Logs contain counts and error types, not saved data.

## Validation

- Full Flutter suite: 4,591 tests passed on the final implementation.
- Core suite: 1,202 passed, with one existing skip.
- Static analysis of `lib`, `test` and `integration_test` with fatal infos: clean.
- Workflow checks: 36 passed.
- Native Windows appearance/navigation integration: one passed.
- Native Windows playback integration: all 11 passed.
- Windows release build: passed.
- Whitespace checks: passed.

Review regressions cover startup uid resolution, stale requests and optional-page timeouts, pending candidate
paging, canceled armed pulls, old-account cards awaiting replacement, same-video tiles across account boundaries,
and focus regained while native player creation is pending. Existing tile seek, hold-speed and page-handoff tests
remain passing. Tests use fake account/API data or the local fixture server; no live account traffic was used.

The source and Windows build are local. This change has not been shipped to the phone. Live recommendation
relevance remains a phone acceptance check using the numbered steps above.
