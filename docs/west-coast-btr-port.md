# West Coast BTR engine port

This branch adapts the performance work in
[BTR West Coast 2026.11.2.1](https://github.com/salileoss/Bilibili-thread-ripper/tree/2026.11.2.1)
to BiliFast's Dart engine. BiliFast feeds local HLS to AVPlayer through URLSession on iOS;
it does not execute the Tampermonkey script. Changing the userscript's update URL therefore
does not update this app.

## What changed

| Area | BiliFast behavior |
| --- | --- |
| Auto CDN selection | `NodeMode.auto` keeps exact ordinary API addresses and combines overseas and mainland candidates. The signed path/query and relay-only fallback remain intact. Regional and custom modes remain available. |
| Route ranking | Auto compares estimated completion time for the actual range size, using first-body latency, body rate and current load. Small metadata responses establish latency, not bandwidth. |
| Bounded exploration | A cold media range considers at most four candidates. Later ranges use measured nodes and at most one unmeasured explorer. Existing urgent-read protections suppress exploration when enough working routes are known. |
| Shared observations | Both track resolvers receive the session's existing `NodeStats`. Existing network-specific `NodeMemory` shares timing/rate with later sessions; it does not share file validity, damage or bans. |
| Connection warm-up | Auto warms at most three distinct hosts, preferring estimates for the current network. It sends one warm-up per host, including Akamai. Regional/custom behavior is retained. |
| Concurrency | An upward trial needs at least 10% useful-throughput improvement under sustained demand. After 30 seconds with at least 20 playable seconds ahead, the engine can try fewer connections. Low buffer or a stall restores the previous level immediately; a sustained speed loss also restores it. Server pushback still takes precedence. |
| Playback speed | Buffer reports are converted from media seconds into wall seconds once, in `RipperSession`. At 2x, 10 media seconds mean five seconds remaining. Existing rate-aware prefetch, peak-bandwidth budgets and memory-warning trimming are reused. |
| Timing diagnostics | First-byte timing now records the first nonempty body chunk after valid range headers. Debug piece events also report `headersMs`, so early headers cannot disguise a delayed body. |

The app already has native codec fallback and remembered decoder failures. AVPlayer remains
responsible for decoding, HDR, PiP and presentation. Browser `MediaCapabilities` and MSE buffer
settings do not apply here. The port retains BiliFast's existing ordered local-HLS streaming,
range validation, seek cancellation, memory limits and offline-download behavior. It adds no
browser-style progressive append switch or automatic quality downgrade.

## Settings and upgrades

Fresh installs start on **Settings / CDN nodes / Auto** (`自动优选`). Existing preference files
retain their previous choice, including the old overseas default that was omitted from JSON.
New writes always save the node choice explicitly, so an Auto choice survives the next launch.
An existing installation must select Auto to use the mixed pool; it applies to the next video.

## Local validation

The pinned Flutter 3.47.7 / Dart 3.13.5 SDK is under `.fvm/flutter_sdk` in this checkout.
The core and app suites use simulated or loopback responses; this port did not access an account
or run live CDN traffic. Checks cover Auto candidate bounds and ordering, original URL retention,
relay handling, shared measurements and reset, tiny metadata, first-body timing, useful-throughput
trials, rate-adjusted pressure, settings migration, persistence and all three settings controls.

- Full core suite: 1,196 passed; one existing test skipped.
- Full Flutter app suite: 4,432 passed.
- Full app analysis: no issues.
- Preference/settings integration tests: 59 passed before the full app run.
- Stand-in font coverage: six tests passed; the new Chinese strings need no font regeneration.
- A recording warmable transport checks the three actual host warm-ups without network access.
- Windows release build: passed (`build/windows/x64/runner/Release/bilifast.exe`).
- Light/dark phone-size settings previews: rendered and inspected; all three choices were exercised.

See `.fvm/west-coast-*.log` for local analysis, suite and Windows release-build output. Those
logs and build products are ignored and are not part of the patch.

## Installing on iPhone or iPad

These are source changes. They must be included in a rebuilt and signed BiliFast IPA and installed
on the device. This branch does not publish an IPA, upload a TestFlight build, modify signing,
or change the original project's release channel. Updating Tampermonkey or installing a release
from the unmodified original BiliFast repository will not include this port.

On the rebuilt app:

1. Open Settings, CDN nodes, and select Auto. Open a new video so the new mode takes effect.
2. Check startup, forward/backward seeking, and a quality change with BTR enabled.
3. Repeat at 2x; watch sustained playback rather than only the first frame.
4. Switch between Wi-Fi and cellular and verify playback recovers without keeping old-path bans.
5. Compare the same videos using Overseas, Mainland and Auto, in rotated order. Use the existing
   development speed test and stats for startup, seek latency, stalls, useful rate and duplicate bytes.
6. Repeat with authenticated 4K/4K60, evening congestion, a longer session, and background/PiP use.

Windows and simulated tests cannot establish iOS URLSession performance, AVPlayer behavior,
thermal/memory performance, or a West Coast ISP's routing. The browser fork's measurements are
motivation for this port, not an iPhone performance claim.
