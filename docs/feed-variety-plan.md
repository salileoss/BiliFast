# Recommendation variety

Keep Bilibili's personalized feed as the candidate source. Local, account-scoped exposure and meaningful viewing
memory exclude repeats, spread creators, and allow bounded lookahead for fresh candidates. No related-video
discovery mix or new server-side watch reporting.

Implementation ownership:
- Shared services and bootstrap: main agent (`app_scope.dart`, `main.dart`).
- Preference persistence and selection: store agent (`feed_preferences.dart` and its tests).
- Refresh selection, paging, metrics and home integration: feed agent (`feed_model.dart`, `home_page.dart` and tests).
- Visible exposure and meaningful viewing: playback agent (inline playback, tile and local tracker files and tests).

Phone checks:
1. Watch a tile for at least 35 seconds without opening its detail page. Refresh; it must not appear in the new
   batch or the retained previous batch when fresh results are available.
2. Watch 18 seconds, leave the tile until its player releases, return and watch another 17 seconds. Refresh after
   restarting and after several days; the combined viewing still excludes it. Seeking alone must not count.
3. Restart the app and refresh. Recently seen memory survives.
4. Switch accounts and return. Each account keeps its own preferences and old requests cannot alter the new feed.
5. Cancel an armed pull, retry a failed refresh, and scroll beyond the previous-batch divider. No recently seen
   videos should enter a new batch. If no fresh results are available, preserve the current feed and show the
   existing empty-result message; do not label a batch of repeats as fresh.

Only phone use can establish whether the relevance/variety balance feels better with the live candidate pool.

## Selection and local memory

The app still requests Bilibili's personalized official feed when authorized, and the existing web fallback otherwise.
New batches exclude tiles visible in the last seven days. Videos with at least 30 seconds of accumulated actual
viewing, or completion of a short video, are excluded for 30 days, even when viewing was split across released
inline players. Existing version-one saved viewing totals immediately qualify; upgrading does not reset memory.
The same viewing gives that uploader a small affinity boost capped at two positions. Creator spreading aims for
at most two appearances in a rolling ten. All choices remain within the server's personalized candidate pool.

A refresh with fewer fresh candidates than its original batch size can request up to three additional pages from
the same source. All optional requests share a two-second time budget, with no retry or extra source fallback.
Successive refreshes continue searching beyond the prefix already consumed in the same account session, while
each initial pull still requests page zero (official) or one (web). Empty, failed or timed-out optional pages stop
the scan. Short fresh batches remain short rather than being padded with repeats. Surplus candidates are retained
for load more and rechecked against current viewing memory. Publication rechecks exposure after a held pull without
applying uploader affinity twice. Canceled pulls and stale requests cannot advance accepted search state.

Exposure requires at least half the tile to remain visible for one second while home is foreground and uncovered.
Lazy builds, cover prefetches, hidden tabs and cached rows do not count. Account changes disable exposure and
playback of the previous account's cards until a replacement batch is accepted.

Local viewing records unique watched media intervals and actual elapsed viewing time, rather than seek position.
Seeking, scrubbing, buffering, background time and repeat loops contribute no fabricated progress. Completion
requires 90% unique content coverage. Updates are batched every 15 seconds and on pause/close; backgrounding
flushes the final batch to disk. Inline playback still sends no new server history reports.

`feed_preferences.json` stores only video/uploader identifiers, account ownership, timestamps and viewing totals,
on this device. Guest and saved-account records are separate. Records expire after 30 days and are bounded to
2,000 videos per account and ten accounts; heavy browsing can evict older records before their cooldown ends.
Writes are serialized and atomic; malformed/expired/excess rows are
removed on load. Failures leave the in-memory feed usable. Logs contain counts and error types, not saved data.

## Initial build validation

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

## Initial local IPA

Application source: `11cc4c739fc7b0a6c4afb079e5d5eed2f6603fb0`.
Build commit: `f5e30db4230ca5f0b8b4a9d59972dd695528d82c` on the fork's build-only branch `build/ipa-feed-tiles`.
All files outside the fork's unsigned build workflow match the tested application source exactly.
The [macOS build](https://github.com/salileoss/BiliFast/actions/runs/42278566905) passed on attempt 2; the first
attempt compiled and packaged successfully but its artifact upload failed with a runner DNS error.

IPA 1.3.0 (13) is saved at `build/ipa/BiliFast-1.3.0-13-feed-variety.ipa` (19,104,382 bytes), with its JSON manifest
beside it. Local checks passed for manifest source commit, size, SHA-256, ZIP integrity, ARM64 runner and app
framework, iPhoneOS platform, bundle identity, version and minimum iOS 26.0, required purpose strings and absence of
a provisioning profile. The app framework contains a valid ARM64 slice inside a universal Mach-O container.

SHA-256: `2ada755ca8ad62d78fa76c21a7b0262a4051034270ed5bb02112ecd5cc12b5dd`.

This IPA is unsigned and requires signing for sideloading. It has not been installed on the phone; live
recommendation relevance remains a phone acceptance check using the numbered steps above.

## Freshness correction after daily use

On 2026-11-12 the user reported watched inline tiles resurfacing after days. The initial rules only demoted
noncompleted viewing for 48 hours, permitted repeat candidates to fill a batch, and searched the same first two
pages on refresh. Completion coverage also lives within one player lifetime, so resumed viewing across releases
could not qualify for the longer completion cooldown. The policy above now uses persisted meaningful viewing
totals independently of session completion, filters repeats, and advances bounded recommendation lookahead.

Validation of the correction:
- Full Flutter suite: 4,604 passed.
- Static analysis of `lib`, `test`, and `integration_test` with fatal infos: clean.
- Windows release build: passed.
- Native Windows playback integration: all 11 passed, using muted players and loopback fixtures.
- Regression tests cover actual inline viewing split across released players, persistence and legacy saved totals,
  seven-day exposure and 30-day watched boundaries, account isolation, fresh-only paging, bounded lookahead,
  advancing refresh searches, canceled/stale requests, held-result revalidation, and unchanged refresh transitions.
- Whitespace checks: passed. No new server history reporting or live account tests.

The correction still depends on Bilibili supplying unseen personalized candidates. Automated tests establish
filtering and persistence behavior; live freshness remains a phone check.
