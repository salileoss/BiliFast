# BiliFast in Flutter: the spec for the move

Written 2026-10-17 as the handover from the spike, kept current since. The app lives at this repo's root
(`D:\Repos\Apps\BiliFast`, public `KaiC5504/BiliFast`); BiliNative stays the Swift reference. What has shipped is in
`CLAUDE.md`, "Status".

Reference documents next to this one:

| File | What it holds |
|---|---|
| `docs/reference/bilicore-inventory.md` | BiliNative's Swift package `BiliCore`, module by module: every endpoint with its signing, the engine's rules with their numbers, the HLS bridge, DevLog, and all 546 tests. |
| `docs/reference/app-inventory.md` | BiliNative's SwiftUI app, feature by feature: files, settings keys, keychain format, tests, and every hard-won rule with `file:line`. |
| `docs/reference/piliplus-map.md` | Where PiliPlus keeps what, which of its packages are licence-safe, and what never to take from it. |
| `docs/reference/testflight-flutter.md` | How this repo ships to TestFlight (workflow, build numbers, Info.plist). |

## 0. If you are a new session, start here

1. Read `CLAUDE.md`, then this file to the end. Open the inventories and the PiliPlus map where a slice points you.
2. KaiC's global instructions (decision profile, ghosthand, ios-testflight skill) load by themselves. Two hard floors:
   - never commit secrets;
   - shipped products never surveil users.
3. Load the `ios-testflight` skill before touching any workflow, signing or Info.plist.
4. Every slice runs through `.claude/skills/running-a-slice`: plan, KaiC's go, then straight through to TestFlight.
5. Don't re-open the decisions in section 2. Push back only with new evidence. KaiC wants a collaborator who
   challenges, not one who obeys, but he also hates re-litigating.

## 1. Goal

BiliFast (KaiC's iOS Bilibili client, Swift/SwiftUI in `D:\Repos\Apps\BiliNative`) moves to Flutter:
- **Everything milestone 1 and milestone 2 did in Swift keeps working:** BTR multi-node playback, picture quality, PiP,
  the official-style player and video page, danmaku, comments, actions, history.
- **The UI looks like the official Bilibili app.** KaiC: "if Flutter can make it look exactly like Official app why
  not." The layout comes only from his screenshots in `local/official-app-reference/iphone/` (gitignored; look only). When
  a screen or state isn't in them, ask KaiC to screenshot it from the official app. PiliPlus gives functions (APIs,
  behaviour) and assets, never layout.
- **One codebase can also become an Android app** later.

**Done** = the Flutter build passes `BiliNative/docs/m1-phone-checklist.md` and `m2-phone-checklist.md` on KaiC's
iPhone 17 Pro Max. Then the Swift app retires and milestone 3 continues in Flutter.

## 2. Decisions already made (KaiC's calls)

| Decision | Why |
|---|---|
| **Flutter for every screen.** | KaiC dropped PiliPlus for its *design*, not for Flutter's feel. The official app's look is custom-drawn, which suits Flutter. |
| **The iPhone keeps Apple's player.** An `AVPlayerLayer` in a native view shows the video; Flutter draws everything around and on top of it. | Every Flutter video path copies frames into an 8-bit texture (flutter/flutter#91241, #127520; media_kit's iOS build forces 8-bit and has no PiP). A native view keeps HDR, 杜比视界, AV1 hardware decoding, PiP and AirPlay. Proven on the phone in slice 1. |
| **One Dart BTR engine for every platform**, with each platform's own player: AVPlayer on iOS, ExoPlayer (Media3) on Android, media_kit on Windows for development. | Android stays possible without a third engine, and Windows runs the real engine. |
| **Same app, its own repo.** | Same bundle id `com.kaichuan.bilifast` and App Store record (`ASC_APP_ID` 6823476667), so builds replace the Swift app and read its keychain login. The Swift builds stay under TestFlight → BiliFast → Previous Builds. |
| **No new Bilibili login.** | KaiC: "I would only do it once to prevent bili from suspecting multiple logins." The keychain login is reused (section 4.6). On the PC, the ghosthand test Chrome holds the only other session. |
| **Light testing on KaiC's account.** | "no need for very detailed or bad testing that could cause my acc issues." Engine work runs against the simulated CDN; live checks use a handful of calls. |
| **No Mac.** | iOS checks run in GitHub Actions (`macos-26`) and on the phone. |
| **No new Swift features in BiliNative.** | Fix Swift only if something blocks daily use until cutover. |

## 3. Where everything is

| Path | What | Use it for |
|---|---|---|
| `D:\Repos\Apps\BiliNative` | The Swift app (public `KaiC5504/BiliNative`). Sources `ios/Sources/App/`, package `ios/Packages/BiliCore/`, docs `docs/`. | A second reference for behaviour, after PiliPlus; never for layout. |
| `D:\Repos\Apps\BiliNative\docs\background.md` | Real CDN behaviour, deviations from BTR, hurry mode. | Read before touching the engine. |
| `D:\Repos\Apps\BiliNative\docs\superpowers\specs\` | M1 and M2 designs. | The *why* behind each Swift screen. |
| `D:\Repos\Apps\PiliPlus` (GPL-3.0, `bb2d86ca`) | A mature Flutter Bilibili client. | APIs, how features behave, and assets; never its layout. Read, never copy (`piliplus-map.md`). |
| `D:\Repos\Apps\Kazumi` | KaiC's Flutter fork, shipped to TestFlight by GitHub Actions. | The model for the signed Flutter build. |
| `D:\Repos\Apps\Bilibili-thread-ripper` | BTR, the JS engine the Swift engine was ported from (MIT). | Read at tag `2026.10.8.1` only. Port from the Swift version, which carries the phone fixes. |
| `D:\Tools\Swift` | Swift 6.4.1 for Windows. | The Swift reference tests and `ripper-bench`: `swift test --package-path ios/Packages/BiliCore` in BiliNative. |

## 4. Target architecture

### 4.1 Layers

| Layer | iPhone | Android (later) | Windows (development) |
|---|---|---|---|
| Screens, gestures, chrome, panels, danmaku, comments | Flutter | Flutter | Flutter (same code) |
| Video view | `AVPlayerLayer` in a native view (Swift, `ios/Runner/`) | ExoPlayer in a native view (Kotlin) | media_kit |
| What the player reads | HLS from the Dart local server (`master.m3u8` → byte-range segments of the DASH files) | DASH (an MPD built in Dart) from the same server | the same local server |
| Download engine | Dart BTR engine in a background isolate | the same | the same |
| HTTP under the engine | `cupertino_http` (URLSession, HTTP/2) | `cronet_http` | dart:io |
| API client | Dart port of `BiliAPI` (`packages/bili_core`) | the same | the same |

Folders are listed in `CLAUDE.md`, "Layout". `packages/bili_core` is pure Dart with no Flutter import, so its ported
tests run fast with `fvm dart test`.

### 4.2 Engine, transport and the local server

- **The engine keeps the Swift structure:** `RipperSession.read(track, range)` takes one byte-range per player
  request (AVPlayer asks for whole SIDX segments).
- **`RangeTransport`:** `fetch(url, range)` returns status, lowercased headers and a body stream once headers arrive;
  cancelling or dropping the body cancels the request at once, so a losing hedge copy gives its connection back.
- **Background isolate:** the engine and its `HttpServer` (bound to `127.0.0.1`, port 0) run off the UI isolate, so
  piece handling never touches the thread that draws danmaku.
- **The local server follows `LocalServer.swift` and `PlaybackRouter.swift`:** paths `/<token>/master.m3u8`,
  `v.m3u8`, `a.m3u8`, `v.mp4`, `a.mp4` with a 128-bit random token; GET and HEAD only; 206 with `Content-Range`, 416
  with `bytes */total`; a client disconnect cancels the engine read.
- **iOS can silently take a suspended app's listening socket.** Before every load and after returning from the
  background, probe the server over loopback; if it doesn't answer, rebind and give the player the new URLs.
- **直连 on iOS:** the playlists still come from the local server, with segment URIs pointing at the CDN and the
  headers passed through `AVURLAssetHTTPHeaderFieldsKey`.
- **Signed media URLs expire.** Refresh them 300 s before their `deadline` through `session.replaceURLs`.

### 4.3 The player

One Dart interface (`BiliPlayer`) with iOS and Windows implementations, over Pigeon channels (`pigeons/`).

- Danmaku extrapolates the position each frame from the last reading and the rate, so it moves smoothly at 120 Hz.
- A native `PlayerRegistry` owns each `AVPlayer`, its host view, its PiP controller and an `AVPlayerItemVideoOutput`
  for screenshots. The platform view only **attaches** an existing host view:
  - a player can outlive its widget (PiP keeps playing after the page closes; a restored page reattaches it);
  - one AVPlayer per page, kept across parts;
  - disposal is explicit: a closed page that PiP doesn't hold calls `dispose`.
- The native view takes no touches; Flutter's gesture layer above it handles everything.
- The audio session is set natively at launch to `.playback` / `.moviePlayback`.

### 4.4 Orientation, brightness, volume

- Orientation is a native channel following `OrientationController.swift`'s rules; the rules live in Dart
  (`lib/device/orientation.dart`). Don't rely on `SystemChrome.setPreferredOrientations` alone.
- **Full screen is the same page rotated** (a layout switch), never a new route.
- Volume goes through a hidden `MPVolumeView` slider that exists only in full screen (it also stops the system HUD).
  A brightness set in full screen is kept after leaving it and after leaving the app (KaiC, 2026-10-23).

### 4.5 Login, keychain and storage

- **Cookies:** the keychain generic password with service `com.kaichuan.bilinative.cookies`, account `bilibili`,
  accessibility `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, no access group; the value is a JSON object of
  cookie name → value. Writing the same format means going back to a Swift build keeps the login.
- **Account switching (2026-11-03):** the versioned `com.kaichuan.bilifast.accounts` Keychain item supersedes these
  legacy slots. It contains saved accounts and one active uid, with web cookies and the matching optional app token
  together. Migration verifies the uid and reads the new vault back before deleting the legacy items. This is
  one-way: an older Swift/Flutter build cannot read the new account collection. The original carry-over format above
  remains the migration input, rather than an ongoing downgrade guarantee.
- **TV token (不喜欢):** service `com.kaichuan.bilinative.apptoken`, account `bilibili`, raw UTF-8.
- **Never log a cookie or token.** Every log line goes through `Redactor`.
- **After a failed keychain read, block writes** until a read succeeds or the user logs in or out, so a transient
  failure can't wipe the login.
- **Settings and stores:** JSON files in the app's support folder (`CLAUDE.md`, "Layout"). Keys and defaults follow
  `AppSettings.swift` (`app-inventory.md`, "Settings"). Swift's `UserDefaults` values are carried over once through
  `LegacyDefaults.swift` where worth it (最近打开; KaiC had no Swift danmaku settings worth carrying).
- **Fresh install / logged out (slice 8):** a web view on `https://passport.bilibili.com/login`. Clear stale bilibili
  cookies first; once a non-empty `SESSDATA` appears, take every bilibili-domain cookie into the jar. Built on
  `webview_flutter` (the Flutter team's) with `WebCookies.swift` reading and clearing `WKWebsiteDataStore.default()`.
  The TV token is only ever deleted (on logout); KaiC left the TV login out.
- **On the PC, no account.** The Windows app runs logged out, or with `--fake-account` against `FakePageApi`.

### 4.6 Logs and crash reports

- DevLog events `{t, seq, session, level, cat, msg, f}`, categories app, api, engine, server, player, ui; a 20 MB
  file sink; a network sink posting NDJSON to `tools/logserver.py` with ack and replay.
- The phone finds the PC through Bonjour `_bilinative-log._tcp` or a manual `IP:port`.
- Dart errors and native crashes and hangs go out as `app` events (`crash` / `hang`).
- The network sink, the 开发者 page and the speed test are compiled in only for dev builds.

### 4.7 Packages

- Default to the Flutter SDK and the Dart team's packages; the pubspec is the list. Check each licence at the version
  you pin (`piliplus-map.md` lists licence-safe ones).
- **No GetX, no Hive, no GPL.** State is plain `ChangeNotifier` / `ValueNotifier` models. Add a state library only if
  one is clearly needed.
- Lints: `flutter_lints` plus `strict-casts`, `strict-inference` and `strict-raw-types`.

## 5. Rules

- **Secrets:** never commit, print or log cookies, tokens, `BILI_APP_KEYS`, signed playurl responses, or anything under
  `logs/` or `local/`. Delete imported cookie files at once. This repo is public, and so is its build log.
- **KaiC's account:** no second login anywhere; few live calls; no loops against the API (no stress tests, no
  automated feed crawling).
- **Saving a playurl for PC benches:** in the ghosthand test Chrome (KaiC is logged in there), call `browser_evaluate`
  with a `filename` so the JSON goes to disk without passing through the conversation; keep it in `local/` and delete
  it after the bench.
- **Licences:** PiliPlus (GPL-3.0) and ATV-Bilibili-demo (GPL-2.0): read only, never copy code. PiliPlus's asset files
  may be taken when they help match the official look, never its logos (`assets/README.md`). BTR (MIT): keep its
  notice with the engine port.
- **UI:** Simplified Chinese text. Layout and colours follow the official screenshots, but no Bilibili logo or
  wordmark. Colours and sizes come from `lib/shared/theme.dart`.
- **Tools:** ghosthand first for any screen or browser work. Ask KaiC before any `keys` call with `allow_focus=true`.
- **GitHub:** never `gh run watch`, never poll; one `scripts/testflight.py status` per run (`CLAUDE.md`, "Shipping").
- **Repo:** work on `main`; commit, push and Actions runs are authorised. Never start a signed build before
  `scripts/gate.py` passed on that commit. In BiliNative only the docs change.
- **Speed first** (KaiC's call): ship to his phone once the gate is green, let him report, fix in the next build.

## 6. The slices

The rule: the riskiest unknown first, then the path a user walks (home → video page → player → page body). Each slice
is usable on its own and ends with a phone check.

The tables name what to port from BiliNative (`App/` = `ios/Sources/App/`), what to look up in PiliPlus, the
reference screens, and the phone checklist items (numbers in `BiliNative/docs/m2-phone-checklist.md`; "M1" means
`m1-phone-checklist.md`).

### Done

| Slice | Shipped |
|---|---|
| 0 Foundations | `bili_core` ported tests-first, keychain channel, gate, TestFlight workflow |
| 1 Player core (the kill switch) | passed: HDR, 杜比视界, PiP, danmaku at 120 Hz, touches over the native view |
| 2 Engine parity | level with Swift on the bench, then faster |
| 3 Home and the page shell | 1.0.0 (4) |
| 4 Player interaction | 1.0.0 (5) |
| 6 The page body | 1.0.0 (6), (7) |
| 7 Comments | 1.0.0 (8) |
| 5 Danmaku | 1.0.0 (9); 人像防挡 is a follow-up, 举报 and 互动弹幕列表 left out (KaiC) |
| 8 The rest of the app | 1.0.0 (10); the avatar page (49) replaced the menu; history without 🔍, ⋮ and the type tabs; the TV login and 不喜欢 left out (KaiC) |

### Slice 8: the rest of the app

| | |
|---|---|
| Port | `App/History/` (cursor paging, 今天/昨天/date groups, 已看完, resume from progress), `App/Settings/SettingsView.swift` (加速: node, BTR; 数据: reset codec memory, clear recents, clear logs; 开发者 in dev builds: 发送日志到电脑, the Bonjour list or manual IP, export logs, 测试崩溃), the login web view and logout (clears the jar, the keychain items, the token and the web view data), logged-out actions opening the login page. The TV login for 不喜欢 was left out (KaiC). |
| Reference | Screens 28 and 45-48 (history), 49 (the avatar page), 50-51 (设置, 退出登录). |
| Phone check | Items 44, 46, 59. Logging out and back in is the one extra login this allows; skip it unless KaiC wants it tested. |

### Slice 9: page lifecycle and cutover

| | |
|---|---|
| Port | Stacked pages (a covered page pauses and resumes without reloading; `lib/app/route_observer.dart` exists), `PiPKeeper` (a closed page stays alive while PiP plays it; restore pushes it back; another video releases it), background rules (without PiP the sound stops; autoplay is skipped in the background without PiP), network change → `networkChanged`, memory warnings → `dropCache`, closed pages freeing everything (a leak test in widget tests, and a native player count back to zero after pops). |
| Phone check | Items 32-42, 67, 70, 71, 75, 77, and the whole M1 checklist (BTR vs 直连 timings on 4 videos). |
| Cutover | Both checklists pass in full → update BiliNative `CLAUDE.md` (the Flutter app is the app; `ios/` is archived reference), and milestone 3 continues in Flutter. |

### Android (later)

- ExoPlayer (Media3, Apache-2.0) in a native view, reading DASH from an MPD built in Dart (no HLS bridge, no `hev1`
  rewrite). HDR through a `SurfaceView`; PiP is Android's own mode. Transport `cronet_http`.
- Login needs the web view (no keychain to reuse), which means one more Bilibili login: ask KaiC first.
- A sideloaded APK; the signing keystore stays out of the repo.

## 7. Lessons that must survive the move

All of these come from phone logs or phone bugs. Sources are in the two inventories.

**Network and engine**
- Bilibili refuses non-browser clients. Send a Safari User-Agent, `Referer: https://www.bilibili.com/`, and
  `buvid3`/`buvid4` from `/x/frontend/finger/spi`. On HTTP 412, drop the buvids, fetch new ones and retry once.
- The unsigned `/x/web-interface/view` got 412 from dart:io, while the WBI-signed `/x/web-interface/wbi/view` worked.
  Logged out, the web playurl stops at 480P even with `try_look=1`.
- Akamai speaks HTTP/1.1 only and the mirrors speak HTTP/2: Akamai is full at 8 in flight from the start; full nodes
  are skipped outside a hurry too; a copy picks its node only once it holds a connection.
- On dart:io, Akamai closes idle keep-alive sockets (`HttpException` before headers). Treat it as a connection loss,
  not a node failure.
- Ban rules (all in `bilicore-inventory.md`, section 4): only 0-byte replies are strikes; losses within 250 ms are one
  strike; a success heals blip strikes; a 4xx from a node that never delivered drops only that node+address pair; a
  busy node's first-byte timeout is no strike; damaged spans are avoided, not struck.
- Hurry mode: a startup or seek read, or a segment less than 10 s ahead; 64 KiB pieces; placement by expected finish;
  copies after 250-600 ms; up to 3 copies.
- Adopted prefetches survive the player's cancel; AVPlayer gives up on requests after about 5 s.
- Bilibili's CDN caches a file within a minute or two of its first play, so only a video's first pass shows cold
  numbers; compare variants on rotated orders.
- Refresh signed URLs 5 minutes before `deadline`. A network change resets bans, health and damage.

**AVPlayer**
- AVPlayer can't play `hev1`-tagged HEVC from HLS. Rewrite the init segment to `hvc1` when its `hvcC` carries
  VPS/SPS/PPS; otherwise mark it unplayable and fall back to another codec (codec memory).
- Dolby Vision needs the codec mapping to `hvc1…` plus `SUPPLEMENTAL-CODECS`.
- Screenshots come from `AVPlayerItemVideoOutput`; `AVAssetImageGenerator` can't read the local HLS.
- The PiP restore handler must be called within 3 s, or AVKit waits.

**UI on iOS**
- UIKit refuses a rotation during a push animation. From full screen, go inline first and wait 450 ms before pushing.
- After the full-screen button, portrait exits only after the phone has really been landscape: lifting it off a table
  reports portrait.
- Orientation ownership: the latest `begin` wins, and a covered page's late `end` must not reset the top page.
- Panels, the coin dialog, the 合集 and favourites sheets, the picture viewer and the comment layers are in-page
  overlays in the page's `Stack`, not modal routes.
- The hidden `MPVolumeView` exists only in full screen. A freshly attached slider ignores a value set in the same run
  loop turn, and volume KVO fires on an audio thread.
- One video at a time. A covered page stops PiP. In the background without PiP, autoplay is skipped, because the next
  part would play as audio only.
- Closed pages must free everything. Models must not hold closures over the page.
- The danmaku send bar and the comment composer follow the keyboard by hand (the page's Scaffold doesn't resize).
- Swipe back starts only from the left edge (KaiC, 2026-10-19: the swipe from the middle went back by accident). A
  sideways drag in the middle belongs to the page: the player's seek, the 简介/评论 pager, scrollers. An edge swipe
  closes 评论详情 first.
- Swift builds 6 and 7 passed gesture tests that only asked delegates, while the swipe never began. Gesture tests drive
  real pointer events at about 1500 pt/s.
- KaiC's phone has a larger Text Size, which the official app ignores: text scaling is off at the app's root.

## 8. How to test

| Where | What | How |
|---|---|---|
| PC | `bili_core` (ported Swift tests, SimCDN) | `fvm dart test` in `packages/bili_core` |
| PC | Widget tests: chrome, panels, gestures, pages, look-alike renders | `fvm flutter test` at the root |
| PC | The Windows app, logged out or `--fake-account` | `fvm flutter build windows --release`, then the exe; ghosthand |
| PC | Engine bench vs Swift | `fvm dart run bin/ripper_bench.dart` in `bili_core` against Swift's `ripper-bench` on one saved playurl |
| PC | Everything above in parallel, before every ship | `python scripts/gate.py` |
| CI (`macos-26`) | The signed iOS build; a dry run doubles as the compile check | `scripts/testflight.py start [--dry-run]` |
| Phone | Each slice's checklist items, with logs streaming to the PC | `uv run tools/logserver.py`; 设置 → 开发者 → 发送日志到电脑; read `logs/<date>/*.jsonl` before guessing |

There are no simulator or XCUITest runs: they would need a new workflow, and KaiC approves workflows first.

## 9. Risks and open questions

| Risk | Mitigation |
|---|---|
| UI jank from the engine. | A background isolate. |
| Each player asks for bytes differently (AVPlayer whole segments, mpv open ranges, ExoPlayer chunks). | Seek detection and prefetch are tuned per player; expect one tuning round per new player. |
| Debugging blind on the phone. | DevLog and the log sink to the PC. |
| PiliPlus code leaking in. | Read only; write our own. |

**Open:** Android: when, and whether one more Bilibili login there is acceptable.
