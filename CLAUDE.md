# BiliFast (Flutter)

KaiC's Bilibili client for iPhone and iPad, in Flutter: public `KaiC5504/BiliFast`, branch `main`. It ships as the
BiliFast app (bundle id `com.kaichuan.bilifast`, App Store Connect Apple ID `6823476667`). It replaced the Swift app
(`D:\Repos\Apps\BiliNative`, retired 2026-11-02; its GitHub repo is deleted, the folder is the only copy) under the same record and reads the keychain
login the Swift app left.

## Read before working

1. `docs/flutter-move-spec.md`: decisions and why, architecture, rules, and the lessons that must survive. Start with
   its section 0.
2. `docs/milestone-3-spec.md`: milestone 3's decisions (搜索, UP主空间, 我的收藏, 稍后再看, the official login) and the
   system-font method; finished.
3. `docs/closing-checklist.md`: what the app does, step by step (the Swift app's M1 and M2 checklists carried over,
   then every feature since); passed by KaiC's daily use on 2026-11-01.
4. `docs/reference/`:
   - `bilicore-inventory.md` and `app-inventory.md`: what the Swift app had, with paths.
   - `piliplus-map.md`: where PiliPlus keeps what; GPL, so read only.
   - `testflight-flutter.md`: how this repo ships to TestFlight.
   - `turn-log.md`: the drawn turn's log lines on both sides, which `tools/phone_report.py --turns` times; `tools/turn_video.py` grades a recording.
5. `D:\Repos\Apps\BiliNative\CLAUDE.md` only for how the Swift app behaved. This file wins wherever they differ.

Every slice runs through `.claude/skills/running-a-slice`: a one-screen plan, KaiC's go, then parallel agents straight
through to TestFlight. Finish with what was built, how it works, numbered phone steps and the build number.

## Status

Shipped and passed on KaiC's phone, newest last; the last build is **1.3.0 (6)**. The detail of each is in git
history, and the rules they added are under "Rules that bite".

- The move from Swift (slices 0-9, 1.0.0 (4)-(12)): `packages/bili_core` ported tests-first; AVPlayer in a native view
  fed by the Dart engine's local HLS (4K, 8K, 真彩 HDR, 杜比视界, PiP); the engine past Swift's speed (each speed-up a
  `RipperConfig` switch, the app's choice in `lib/playback/playback_setup.dart`; KaiC: no more tuning rounds); 推荐,
  the avatar page, 最近打开; player gestures, HUD, panels and rotation; the page body (简介, actions, coins,
  favourites, 合集, related); comments and the composer; danmaku (settings, 屏蔽词, 当前弹幕列表, sending); login,
  历史记录, 设置; a player per page on one shared engine with `PipKeeper`; the drawn turn (开发者 → 旋转动画).
- The system font, 1.0.0 (15)-(17): SF with PingFang SC, its fallback settled at launch (the font rule below).
- Milestone 3, find and follow, 1.0.0 (17)-(22): 搜索 and the bottom bar (17), the loading TV from the APK (18),
  UP主空间 on the official app's calls (19), 我的收藏, 稍后再看 and the official login's app token, confirmed in the
  official app (20)-(22).
- 1.0.0 (23)-(39), from KaiC's use and clips: the seek bar's hold and the seek preview; the comment picture viewer's
  swipe; 我的 and the bottom bar's 首页 / 我的; the own space and 装扮 (skins, our SVGA player, the status bar over
  a dressed header); pictures kept on the phone and asked as the official app's CDN presets (AVIF through ImageIO);
  推荐's refresh (held 1.5 s, batches under 刚刚看到这里), the folding header and the big inline-playing card; a
  video opened from a video page replacing it; danmaku pacing at 2×; panels closing to the bare video; 竖屏; upright
  videos' tall player box.
- 动态, 1.1.0 (1): the bottom bar's 关注 on the website's polymer calls, post cards, the post page, 我的关注, the
  space's 动态 tab, video cards playing muted.
- The iPad, 1.2.0 (1): universal app, `FormFactor` the one switch; 首页, the video page and full screen in their
  own iPad layouts, the other screens the iPhone's at the iPad's width.
- 离线缓存, 1.3.0 (1)-(4): downloads through the engine, kept for good with their danmaku; a cached video's own page
  on `PlaybackMode.local`; watch progress queued in `HistoryOutbox`; background downloading chosen on the device by
  `BackgroundTrials` (iOS 26's continued processing or a background URLSession hand-off).
- The closing build, 1.3.0 (5)-(6): 速度测试's built-in plan `builtin-4` (BTR against 直连, a plan's `codec`); the
  hand-off asks fresh stream addresses unless they have 100 min left; 首页's tap opens the folded header at once.
  Milestone 3's closing check passed by KaiC's daily use (2026-11-01); M1 became the README's 实测 chart
  (`docs/speed/seek.svg`: six videos where both modes passed cleanly, 72 jumps each; passes spoiled by a trip out of
  the app, or by a video the CDN hadn't fetched yet, left out). The Swift app retired (2026-11-02).

Update this section when a build ships: one short entry, and any rule it adds goes under "Rules that bite".

## Next

KaiC's pick. Candidates: 番剧, 直播, 人像防挡 (the mask file from `/x/v2/dm/web/view`; its switch is drawn off and
toasts), the iPad's other screens. Each new screen waits for KaiC's official screenshots. For checks, see "Daily use"
in Rules that bite.

## Backlog

Not built, by area. Most wait for a screenshot of the official app; KaiC decides what comes in.
- Player: 17's ♪ (听) and the 听/投屏 top icons; what 竖屏's screen-mode button does for an upright video (ours turns to
  landscape); an edge swipe starting on 竖屏's ‹; the landscape title marquee with 章节; 竖屏's 联合创作 and 合集
  prefix; 弹幕设置's 查看更多 for the small player; the picture viewer's 查看原图, ⋮ sheet and comment bar (103, 104);
  竖屏 search, 充电鸣谢, a 16:10 video's box height. Left out by KaiC: 举报 on danmaku, 互动弹幕列表.
- 首页: the tab row's other tabs; the official UP badge icon; reason-tag cards (2万点赞) hiding the uploader; uploader
  names on 推荐 cards, 历史记录, 搜索 and related rows opening the space.
- 搜索: 番剧/直播/影视/图文, keyword chips, comment snippets, 相关搜索, 筛选's 音画质量/范围/date range, 大会员 names,
  用户's sort menus.
- Spaces and 我的: 主页/小店/收藏 tabs (toast), default tabs other than 投稿 and 动态, 你可能感兴趣 after 关注, medals and
  找我官方合作, 图文, the own space's verification line, skins that only tint the stock icons (`tail_icon_mode`
  color), 我的游戏, 我的服务, 发布你的第一个视频.
- 我的收藏 and 稍后再看: 追更, folder search, 批量 in folders, folder rows' progress line, 卡片/列表 remembered.
- 动态: 赞和转发's list, writing a 转发 or a post, the face's digital-collectible badge, 138's own share panel, the 视频
  tab's 番剧 posters opening.
- 离线缓存: cellular rules, danmaku refreshed after the download, 自动上滑 / 单双击手势 / 后台听视频 / 字幕 (toast),
  waiting parts handed to iOS (only running ones are), our HUD for the hardware buttons inline.
- iPad: 投屏, the chapter list, its own panel contents, its own layouts for 搜索, 我的, 动态, spaces and 设置.
- Slice 10's leftovers (KaiC set them aside, 2026-10-21; `docs/milestone-3-spec.md`): the stand-in sweep's findings.

## Known limits

- Long background trips outlive the stream addresses: they are signed for ~2 h, so ranges iOS starts after that fail
  (403); nothing can renew them while the app is away.
- 速度测试 doesn't log the app leaving the screen: a pass run while it is away, or on a video the CDN hasn't fetched
  yet, times out on the first frame like a real failure. Read the log's timing before trusting a failed pass.
- Flutter rounds a line to whole points (comments 24 pt against 24.33; 动态's post text 29 against 29.33), and doesn't
  squeeze a line-initial 「 as iOS does.
- Folded over a 装扮 header, the status bar keeps the style measured for the open header; a 推荐 refresh whose page is
  short enough to show the divider shows its old top cards twice for 180 ms.
- The normal page's 点我发弹幕 capsule border is 0.7 pt where the official one is a crisp 1/3.
- Apple deprecates `UIRequiresFullScreen` from iPadOS 26: a window narrower than 700 pt would draw the iPhone layouts.
- Logging out and back in has never been tried on the phone (KaiC keeps his one login); Windows and widget tests cover
  the logged-out paths.
- Windows only: 分享 opens an invisible share window that freezes the app (share_plus; checks skip it), and
  ghosthand's Enter doesn't reach 搜索's keyboard key.

## Layout

- `lib/`: the Flutter app.
  - `lib/app/`: routes (the plain swipe back, and `zoom_back_route.dart` for 推荐 cards), `AppScope` (the services every page reaches: `AppPlayback`, which hands each page a player, `PageApi`, the
    `PipKeeper` and the navigator key), the
    page-route observer (a page counts as covered only when a page route is pushed over it), Reduce Motion, and
    `phone_frame.dart` (Windows only: the window as KaiC's iPhone, or his iPad with `--pad`), and `form_factor.dart`
    (`FormFactor`: the iPhone or the iPad).
  - `lib/account/`: the encrypted saved-account vault and legacy login migration, account switcher, keychain and
    cookie persistence, the login page and `LoginGate`, the web view's cookies.
  - `lib/home/`: `main_shell.dart` (the bottom bar's places), home, the feed, the bottom bar (`home_tab_bar.dart`,
    its glyphs in `tab_bar_icons.dart`), the avatar page (49), the shared shortcut glyphs and 最近打开.
  - `lib/me/`: 我的: `MeModel` over `MeApi` (`fake_me_api.dart` for tests and `--fake-account`), the page and header,
    its glyphs, and `official_link.dart` (a page opened in the official app).
  - `lib/skin/`: 装扮: `SkinModel` (`AppServices.skin`) over `SkinApi` (`fake_skin_api.dart`'s drawn demo for tests and
    `--fake-account`), the package's download, check and unpack (`skin_package.dart`), `Skin` (its files by role),
    `svga/` and `SvgaView` (our SVGA player), and `SkinVideo` over `SkinVideoView.swift`.
  - `lib/search/`: 搜索: the page, the empty page and suggestions, `SearchModel` over `SearchApi` (`fake_search_api.dart`
    for tests and `--fake-account`), the history store, `search_glyphs.dart`, and `results/` (tabs, rows, 筛选, the ⋮
    sheet). `lib/video/link_opener.dart` opens a pasted link's video for 搜索 and `--play=`.
  - `lib/history/`: 历史记录, its model and the row's ⋮ sheet.
  - `lib/space/`: UP主空间: `SpaceApi` (the official app's calls; `fake_space_api.dart` for tests and `--fake-account`),
    the route and `UploaderTap` / `openUploader` (the video page's sheet, else the space), `SpaceFollow` and
    `FollowBook` (关注 in step across pages), the uploader sheet, the space page (header, bar, tabs, the 取消关注 sheet)
    and 投稿's list (`space_videos.dart`). `own/`: the account's own space (the page, header, bar, the tab bodies and
    `OwnPager`, one per tab, kept by the page).
  - `lib/favourites/`: 我的收藏 (folders, a folder, 视频, the 创建 page `new_folder_page.dart` that 稍后再看 shares).
  - `lib/watch_later/`: 稍后再看 (the list, its sheets and 批量管理).
  - `lib/offline/`: 离线缓存: `OfflineLibrary` (`offline_library.dart`: `DiskOfflineLibrary`, the support folder's
    `offline/<cid>/` with `entry.json`, `v.m4s`, `a.m4s`, `cover.jpg`, `face.jpg`, `dm/<n>.so`; `disk/` its pieces;
    `fake_offline_library.dart` for tests and `--fake-account`), `OfflineHost` (`ios/` over `OfflineHost.swift`), the
    缓存 sheet (`download_sheet.dart`, `sheet/`), the pages (`pages/`), a cached video's page (`page/`,
    `offline_route.dart`) and `offline_size.dart`.
  - `lib/dynamic/`: 动态: `DynamicApi` (`fake_dynamic_api.dart` for tests and `--fake-account`), `DynamicLikeBook`,
    `card/` (the post card and its parts, the picture viewer route, ⋮'s sheet), `follow_tab/` (the bottom bar's 关注,
    its model, header and the face sheet), `post/` (a post's page) and `following/` (我的关注).
  - `lib/account/app_auth*.dart`: the official login's token, its confirm, and the hand-off of Bilibili's confirm page
    to the official app (`app_auth_client.dart`).
  - `lib/player/`: the `BiliPlayer` interface and its iOS and Windows players. `lib/playback/`: the engine's setup,
    the shared engine (`shared_engine.dart`: one isolate, a lease per controller), the playback controller, codec
    memory, the danmaku feed.
  - `lib/danmaku/`: the danmaku layer, scene and painter; `DanmakuSession` (one per page, on `PlayerUi`), the
    settings and block-rule stores, 添加屏蔽词, 当前弹幕列表, and `send/` (the send bar and style panel) with
    `danmaku_overlays.dart`, the send layer in the page's Stack. The 弹幕设置 panel is in `lib/player_ui/panels/`.
  - `lib/player_ui/`: the player's controls for each presentation, gestures, the HUD, the end screens, `panels/`;
    `pad/`: the iPad's page controls, full screen and their end screens.
  - `lib/device/`: rotation (`orientation.dart`, the rules) and brightness/volume, over `DeviceChannel.swift`.
  - `lib/video/`: the video page, its playback (`page_playback.dart`: the controller, session and watch reporter, which
    outlive the page for the small window), `pip_keeper.dart`, its player session (`page_session.dart`,
    `player_prefs.dart`), the tab row
    (`page_tabs.dart`), the page body's model (`page_details_model.dart` over `page_api.dart`; `fake_page_api.dart`
    for tests and `--fake-account`), the watch-progress reporter and `collapsing_player.dart`.
    - `lib/video/pad/`: the iPad's page frame (`pad_page_layout.dart`) and body (`pad_body.dart`).
    - `lib/video/intro/`: 简介's pieces. `lib/video/actions/`: the actions model, the coin dialog, the favourites
      sheet, the unfollow confirm and their overlays.
  - `lib/comments/`: 评论, 评论详情, the composer with its emote panel, @ picker and pictures, and
    `comment_overlays.dart`, the in-page layers the page's Stack holds.
  - `lib/settings/`: 设置, 字体, CDN 节点 and the confirm alert, and the font store.
  - `lib/devtools/`: crash log, the phone's log files, log forwarding and discovery of the PC's log server.
  - `lib/speedtest/`: the speed test (dev builds only).
  - `lib/shared/remote_image.dart` and `image_disk_cache.dart`: every network picture, kept on the phone; on iOS
    downloaded through `PictureSession` (one URLSession).
  - `lib/shared/theme.dart`: the colour and size tokens (never hardcode colours). `lib/shared/loading_tv.dart`: the
    loading TV every list and page uses (`lib/player_ui/player_loading.dart` is the player's).
  - Settings and stores are JSON files in the app's support folder (`player_prefs.json`, `recents.json`,
    `font.json`, `emotes_recent.json`, `search_history.json`, `node_memory.json`, `danmaku_settings.json`,
    `codec_memory.json`, `log_server.json`, `me.json`, `history_outbox.json`; 离线缓存's `library.json`, `trials.json` and
    `trip.json` in `offline/`); the log and the pictures (`images`) are in the caches folder.
- `packages/bili_core/`: pure Dart, no Flutter import, the port of the Swift package `BiliCore`: `shared`, `devlog`,
  `danmaku`, `api`, `logic`, `dash_hls`, `local_http`, `engine`, and `bin/ripper_bench.dart`.
- `ios/Runner/`: native Swift (player registry and host view, keychain, the login web view's cookies, device
  controls, frame capture, paste control, log-server discovery, the one-time carry-over of the Swift app's 最近打开). Pigeon definitions are in
  `pigeons/`. New Swift files must be added to `ios/Runner.xcodeproj/project.pbxproj` by hand (four entries, see
  `KeychainChannel.swift`'s).
- `assets/`: MiSans, assets taken from PiliPlus, and the loading TV's from the official APK (`assets/README.md`).
- `design/icon-options/`: the app icon's five candidates and `make_icons.py`; A is the app's.
- `test_ci/`: static tests of the workflow (pins, secrets only in step env, nothing leaks into the public log).
- `tools/`: the PC side of dev builds: `logserver.py` receives the phone's logs into `logs/` and serves the speed
  test plan; `phone_report.py` reads a session; `turn_video.py` measures the turns in a screen recording;
  `screen_diff.py` measures our screenshot against the official one (milestone 3, slice 10); `make_standin_fonts.py`
  makes the system font's stand-ins in `test/fonts`; `apk_asset.py` finds and extracts the official APK's art (the
  Art rule). Run `uv run tools/logserver.py` in the background before KaiC tests.

## How to test

- Flutter 3.47.7 through fvm: `fvm flutter …` / `fvm dart …` (`flutter` is not on PATH). Pinned in `.fvmrc`, the
  pubspec and the workflow; `test_ci` checks they agree.
- Everything at once: `python scripts/gate.py`. Lanes in parallel: bili_core, the app, `test_ci`, a Swift syntax check
  of `ios/Runner` (`swiftc -parse`; no iOS SDK on the PC), and the Windows release build plus the Windows
  integration tests (real mpv). `--quick` skips the Windows lane and records nothing.
- Core: `fvm dart test` in `packages/bili_core`. App: `fvm flutter analyze` and `fvm flutter test` at the root.
- Workflow: `uv run --no-project --with pyyaml==6.0.3 python -m unittest discover -s test_ci`.
- Windows app: `fvm flutter build windows --release`, then `build\windows\x64\runner\Release\bilifast.exe`.
  - The window is KaiC's iPhone: 440×956 with its safe areas and a drawn status bar, turned to 956×440 for landscape
    full screen. It runs logged out; there is no keychain on Windows.
  - Every button answers accessibility presses, so ghosthand can drive it (`视频画面` toggles the controls).
  - Flags: `--mute` (always), `--play=<BV>`, `--fake-account` (a made-up account with the page's calls answered
    by `FakePageApi`: actions and a demo comment section, no account traffic), and `--real-account` (KaiC's PC
    login, only with his OK each time: Rules that bite).
  - Launched from the Claude desktop app (ghosthand), Windows redirects `%APPDATA%`: that run's support folder and
    log are under `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\bilifast\`.
  - ghosthand can't scroll or drag, and the 956 pt window is taller than this PC's screen (the bottom ~10 pt of a
    capture is stale). Scrolls, drags and swipes are covered by widget tests at ~1500 px/s instead.
- Look-alike checks render our screens in widget tests at 440×956 (or 956×440), 3×, against KaiC's official
  screenshots in `local/official-app-reference/iphone/` (gitignored: look only, never copy or commit), and measure the pair
  with `tools/screen_diff.py`. They render the system font, as the phone does: `BiliFonts.family = BiliFonts.system` with
  `test/support/stand_in_fonts.dart` loaded; `test/support/look_alike.dart` sizes the view as the phone and saves the
  3× PNG.
- GitHub runs nothing on push. `testflight.yml` is the only workflow; don't add one without asking (`test_ci` fails if
  one appears).

## Shipping

The `ios-testflight` skill is the playbook; load it before touching any workflow, signing or Info.plist.
- `python scripts/gate.py` on the committed tree (it records the commit), push, then `python scripts/testflight.py
  start` (6 GitHub calls). `start` refuses a commit the gate didn't pass. Run `start --dry-run` only after a workflow
  or script change.
- Check the run directly when its state matters, no fixed wait (KaiC, 2026-10-30: "get the latest information"):
  `python scripts/testflight.py status` (1 call) or `gh run view <id>`; when KaiC says it failed, or `status` shows a
  failure, read `gh run view <id> --log-failed` at once. A failure in the first minutes (signing, toolchain) shows
  without waiting for the build. Still never `gh run watch` or a polling loop: KaiC gets rate-limited.
- Version 1.3.0 (from 1.3.0 (1), KaiC: 离线缓存), set in both `pubspec.yaml` and the workflow's `BUILD_NAME` (`test_ci` checks they agree). Build
  numbers count from 1 within each version (App Store Connect's latest of that version plus one); the last shipped is
  in Status.
- Every upload also publishes an unsigned IPA for sideloading as the GitHub release `v<version>-<build>` (the
  workflow's `sideload` and `release` jobs: no environment, no secrets, so no profile or legal name in it).
- Secrets are in this repo's `testflight` environment (limited to `main`).
- Commit, push and Actions runs (signed builds included) are authorised on `main`.

## Rules that bite

- Public repo. Never commit, print or log secrets, cookies, tokens, signed playurl responses, or anything in `local/`
  or `logs/` (both gitignored). The build log and artifacts are public too.
- KaiC's Bilibili account: no second login (the exceptions, KaiC's calls: the app token in slice 13, confirmed once with
  the web login; and one Windows login, 2026-10-22, below), few live calls, no loops against the API. Tests never
  touch the network.
- The Windows login (KaiC: "make sure you won't do anything that could get it restricted"): the last fallback for
  checking APIs, never for everyday development or tests. Ask KaiC before every `--real-account` launch, each time;
  his OK covers that one run. The PC also holds an app token (KaiC, 2026-10-24: one TV QR login confirmed in the official
  app, kept DPAPI-encrypted in `local/pc-app-token.bin`), only for scripts KaiC runs himself to read the official API's
  answer shapes (card types, field names and types, never values); the Windows app never loads it. Without the flag (every other run, checks and `--fake-account` included) the PC loads
  no login and its 登录 says 请在手机上登录. With it: the website's QR login,
  scanned in the official app, kept DPAPI-encrypted in the support folder's `login.bin`. Every call the Windows
  `BiliClient` makes passes `GuardedTransport`: writes refused unsent (only passport's `/login/exit/v2`; 不感兴趣's
  GETs count as writes), reads paced (8 at once, then one a second), 200 a run at most (the QR login's calls aside),
  and the first 412 or -352/-412 stops every call until a restart. Never loosen the guard to test something: a write
  is checked under `--fake-account`, which never loads the login. On Windows, 退出登录 ends the session on
  Bilibili's side first and keeps the login if Bilibili doesn't confirm. No app token on the PC. Logged in, a
  Windows check opens at most 3 videos and reads only.
- No Mac: iOS checks run in GitHub Actions and on his phone.
- Layout comes only from the official app's screenshots (`local/official-app-reference/iphone/`, his iPhone 17 Pro Max,
  440×956 pt). When a screen or state isn't in them, ask KaiC to screenshot it; never fill the gap from PiliPlus or
  the Swift app. The iPad's layout comes only from `local/official-app-reference/ipad/` (the official HD app on
  KaiC's iPad Pro 11" 3rd gen, 834×1194 pt at 2×, full screen only: no Split View or Stage Manager), numbered from 01
  on its own; never stretch an iPhone screen to fill an iPad one. His iPad shows the HD app partly in English
  (Follow, Danmu Settings, Buffering...); ours keeps the iPhone screenshots' Chinese wording everywhere (KaiC). The iPad has no 竖屏: an
  upright video plays in the ordinary full screen, pillarboxed, its danmaku across the whole screen (25).
- Art (icons, placeholders, loading pictures, Lottie) comes first from the official Android APK in `local/`
  (`iBiliPlayer-bili.apk`, 8.43.0) through `uv run tools/apk_asset.py` (`find`, `show`, `extract`; vectors drawn white
  at 3× for tinting; everything is already dumped by real name in `local/apk-assets/`, with `index.csv` to search and
  vectors drawn as PNGs to browse), then PiliPlus's assets, and only then our own drawing. The APK holds the app's own art only:
  skins, emotes, frames, medals and banners come from the server, and the iPhone app sometimes draws differently
  (its cover placeholder is the APK's `bili_default_image_tv_2023`, not `bili_default_image_tv`), so every piece is
  checked against KaiC's iPhone screenshots or recordings and sized from them. Note each in `assets/README.md`.
- PiliPlus (`D:\Repos\Apps\PiliPlus`) is a reference for functions only: the APIs and how a feature behaves, plus its
  asset files of the official app's art (`assets/README.md`, never its logos). Never its layout or design. Read it
  before building (`docs/reference/piliplus-map.md`). It and ATV-Bilibili-demo are GPL: write our own code, never
  copy theirs. Keep BTR's MIT notice with the engine port.
- Swipe back starts only from the left edge; a sideways drag elsewhere belongs to the page.
- Nothing ships until every control the change touched has been pressed on Windows and its effect confirmed.
- Text scaling is off at the app's root (`main.dart`), so sizes are the official pt whatever iOS's Text Size says.
  Don't add per-widget clamps.
- The theme's `BiliFonts.untracked` keeps Material's 0.1-0.5 pt letter spacing out of every style: tracked Chinese at
  3× lands between pixels and draws some glyphs thin. Keep it in both `ThemeData`s.
- The phone draws the system font by default: SF, with PingFang SC for Chinese. Both are Apple's and can't be on the
  PC, so tests of the system path load open stand-ins (`test/fonts`, made by `tools/make_standin_fonts.py`: Noto Sans
  SC and Inter given PingFang's and SF's line metrics, glyph places and widths, measured off the phone); without
  them that path draws Flutter's square test font. On settings (09) they land within a pixel of the phone, but
  stroke weight and Latin shapes still differ, so system-font values are still settled from KaiC's phone screenshots
  (ours beside the official), measured in px / 3. New Chinese in code or tests needs the script run again (the tools
  lane fails until it is).
- Fonts: styles read `BiliFonts.family` where they're built, never in a const, so a 字体 change rebuilds in place. The
  MiSans nudges in `BiliMetrics` apply only while MiSans is on. The system font is `BiliFonts.system`
  (`CupertinoSystemText`). iOS's engine registers no family by that name (only `CupertinoSystemDisplay`), so on the
  phone it matches nothing and the default, SF, draws. So in a fallback list the first family the phone has becomes
  every run's font (1.0.0 (15) listed Apple Color Emoji and drew digits and spaces emoji-wide). With no list, the first
  character SF lacks has iOS pick a font, which the engine keeps for the rest of the line (a katakana name drew its
  whole reply in a Japanese font). So at launch `BiliFonts.settleSystemFallback` names SF by UIKit's family name
  (`.AppleSystemUIFont`), then PingFang SC, but only if that name draws Latin exactly as the default does; otherwise
  nothing, and it logs which (`system font fallback`). Nothing else sets `BiliFonts.systemFallback`;
  `test/flutter_test_config.dart` sets the PingFang stand-in, because tests register the SF stand-in under the name
  the phone doesn't have. A test that passes under the stand-ins can still be wrong on the phone wherever font
  resolution differs.
- 搜索 keeps one search call out at a time, suggestions included, with a gap between result pages; a load round
  that adds no row (a 筛选 cut them all) stalls until the user asks again, so nothing loops against the account.
  The keyword is the user's text: never log it, nor an error's `toString` (cupertino_http's carries the URL).
- Every pull to refresh changes nothing on screen until the finger lets go (KaiC, 2026-10-22: all of the official app
  works so; 107). A list may start its refresh's work once the pull is held past the trigger (`ReleaseRefreshControl`'s
  `onArmed`/`onDisarmed`; KaiC saw the official 推荐 load while held, 2026-10-23): 推荐 fetches page 1 then, at most
  one call per arming, keeps it unseen and shows it the moment the finger lets go. Pushed back until the TV is gone
  and let go there, nothing refreshes (`feed pull cancelled`); the unseen answer may serve another pull within 10 s.
  Lists use `ReleaseRefreshControl`, never `CupertinoSliverRefreshControl`. 推荐's refresh with cards on screen holds
  its TV at least `FeedModel.minimumRefresh` (1.5 s, KaiC), a held pull's counted from its arming.
- A video opened from a video page replaces it (`replaceVideoPage`, KaiC: never stack); the replaced page leaves on its
  route's `popped` future exactly as a popped one (release or PipKeeper, last heartbeat, orientation). Pages opened
  from lists (首页, 搜索, 历史记录, a space) push.
- Pictures: every address passes `secureImageUrl` (https, and i0/i2.hdslb.com asked from i1, so one connection serves
  them all and a precache and its draw share one address). i1 is another CDN (Wangsu; i0 and i2 are Baidu's), the one
  the official app asks, about twice as fast here. Video covers (`RemoteImage(cover: true)`) ask the official iPhone
  app's preset addresses (`CoverPreset`: a site names its official screen's, others take `forBox`'s), which the CDN
  keeps made because every official user asks them; AVIF presets are decoded by ImageIO (`PictureDecoder.swift`) to
  the box, and fall back per address to the box's exact size as `@{w}w_{h}h_1c_90q.jpg` (`coverImageUrl`), as on the
  PC and in tests. A size only we ask is made on demand (~0.3 s against ~0.15 s). The box's size is given fixed
  wherever the box moves, or every frame would be a new address. Other pictures keep webp in 60 px steps. On iOS
  downloads go through `PictureSession`'s one ephemeral URLSession (no cookies, no URL cache: `ImageDiskCache` is the
  cache); Windows and tests keep dart:io. A transport error's text carries the URL (cupertino_http's): log
  `PictureDownloadException`'s reason, never the text.
- The status bar over a dressed header goes by the picture behind the clock and the icons (`skin_status_bar.dart`):
  the geometric mean of L + 0.05 less 0.05, white icons under 0.1791 (white's and black's contrast equal), measured
  after the skin shows and kept per version in `.status.json`; 我的 has a height with its 会员 card and one without;
  关注's 88 pt header has its own crop (`StatusBarPlacement.follow`);
  a video header goes by the skin's text colour. Pages without their own `AnnotatedRegion` get `DefaultStatusBar`'s
  dark (above the Navigator); a page drawn over a light one (设置 over 我的) sets its own.
- Loading shows the official TV (`LoadingTv`, `LoadingTvState`, `loadingTvRefreshIndicator`; the player's
  `PlayerLoading`), never a spinning circle, except for loading more under a list and inside buttons, where the
  official app keeps the small system spinner too.
- 装扮: the skin call needs the app token (none on the PC: `--fake-account` draws a stand-in skin into `skins_fake`).
  Its package comes only from Bilibili's CDN hosts, and its URL never reaches a log or a file. A dressed screen waits
  until its pictures decode and drops back to stock on any failure; an answer in an unknown shape keeps what is shown
  (only an explicit "nothing equipped" clears it). The official art (skins, the own banner) is KaiC's, on his phone:
  never in a fixture or a commit; tests draw stand-ins.
- Two logins, split by host as PiliPlus does: a call to `app.bilibili.com` carries the app token (`access_key`) and
  the Android signature, never cookies (`bili_client_official.dart`); every other call carries the web login's cookies.
  The token never reaches a log, a fixture or an error message; an official account call without it throws
  `BiliError.noAppToken` and its feature asks `AppAuth.request` instead. 推荐 is never fetched from the official feed
  without the token (that feed is generic). The token is confirmed only in the official app: Bilibili's confirm call
  answers the web login -101, and its page refuses any web view.
- Saved accounts use one encrypted vault and one active uid. Switches replace the full cookie map and matching
  optional app token together, without server logout. Old requests keep their initiating session; history reports
  and unfinished downloads keep their owner. The legacy single login migrates one-way after verified storage.
- UP主空间's calls are the official app's (`app.bilibili.com`), signed with `AppSigner.android` (a public pair, the
  same for everyone; KaiC allowed it in the repo) and sent with no cookies. An archive item's `uri` carries a signed
  play link: never keep, log or put it in a fixture. 关注 stays on the web card and `/x/relation/modify`.
- A control wrapped in `Semantics(excludeSemantics: true)` needs its own `onTap:` on the Semantics (`ChromeTap`'s
  pattern): excluding drops the GestureDetector's tap action, and VoiceOver and ghosthand then press nothing (slice
  12's space shipped that way to its first Windows check).
- 离线缓存 in the background is chosen on the device from its own trials (`BackgroundTrials`), not by a build per
  guess: a new way to try is a new arm, and the phone log's `offline trip` / `offline trials` lines say which wins.
  Continued processing is asked for only around a user's action or a return with downloads left, never in a loop.
- 离线缓存's files are KaiC's for good (KaiC: they outlive the video on Bilibili): only his delete removes a part, or
  launch removing a folder with no readable `entry.json`. Nothing kept names a signed address (streams are
  `withoutAddresses()`; addresses live in memory), and paths are kept relative, since every TestFlight update moves
  the container. A download's failures back off and stop (`maxStrikes`); risk control holds the queue, never retried.
- Panels, sheets, dialogs and the comment layers are in-page overlays in the page's Stack, not routes; back closes
  them first.
- A logged-out action goes through `AppScope`'s `loginGate` (on the video page, its `_requestLogin`, which turns the
  phone upright first), never a 请先登录 toast. The login replays nothing; the gate always shows the page, since a
  -101 can come while the app still thinks it is logged in.
- The video page lays out by the screen's shape, not the orientation's presentation: Flutter's iOS engine keeps the
  old size for the first half of a turn, so landscape is laid out only once the size is wide (`_laidOut`, which
  `PlayerUi`'s panels and gestures follow). Code that acts on what the user asked for reads the presentation.
- The drawn turn (旋转动画 自绘): `TurnTakeover.swift` holds UIView animations off from before the rotation is
  requested until the turn completes, the only way found to keep iOS's out-of-process rotation out (turning them off
  inside viewWillTransition is too late: iOS still spun the window in 1.0.0 (12) and (13)). The window then turns at
  once with a zero duration, Flutter gets the turned size at once under a still picture, and the video page draws the
  turn from −angle to 0 over 300 ms and calls `turnDrawn(id)`, or the picture lifts after 0.5 s. The turn can reach
  Dart before the build that follows the change of presentation, so `_turnStarted` follows it first. It is armed only while a video page owns
  the orientation; a page that is covered or leaves gives it up first. While the page draws a turn, its geometry is
  the official 01 clip's (300 ms ease-in-out, the body hanging from the box's bottom-left, cut at the turning
  window's edge); grows it doesn't draw (系统, Windows) keep the centred body.
- One player per page (BiliNative's one AVPlayer per page), all on one engine isolate. A covered page pauses, stops
  its small window, drops its prefetch and gives up auto PiP; its loads start paused while covered. It resumes when
  shown only if it was playing, and not while another page's video is in the small window. A page popped while its
  small window plays goes to `PipKeeper` (`PagePlayback` lives on); any other popped page releases its player.
  The restored page is pushed without a slide, or AVKit flies the window off screen.
- 弹幕设置 is one set for every presentation. 添加屏蔽词 and 当前弹幕列表 are landscape only (the portrait sheet, 40
  and 41, has no rows for them); turning to portrait with either open goes back to 弹幕设置.
- Danmaku block-word regexes run on Dart's (ECMAScript) `RegExp`, not ICU as in Swift: `(?i)`, possessive and atomic
  groups throw (the rule is skipped), and `\p{Han}` or `\A` mean something else.
- ghosthand first for screen and browser work; always `--mute`. Flutter windows often have a thin accessibility tree;
  use `screenshot`.
- BiliNative is retired (2026-11-02): read the local folder for how the Swift app behaved and change nothing there.
  Never build or ship it again: it shares the bundle id, so a Swift build would replace this app on the phone.
- Daily use: KaiC uses the app every day and passes broad sign-offs that way. Ask him only for checks daily use can't
  reach (a new feature's states, a measurement, a log to read), as numbered phone steps.
