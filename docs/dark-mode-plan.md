# Dark mode implementation plan

Prepared 2026-11-02 and approved for local implementation on `feat/dark-mode`. This document records the design; see `dark-mode.md` for implementation notes.

## Codebase map

- `lib/main.dart` loads local preferences and services, then builds `BiliFastApp`. It currently supplies one light `ThemeData`; `DefaultStatusBar` supplies dark status icons when a page has no override.
- `lib/app/app_scope.dart` owns `AppServices` and exposes them through `AppScope`. Preferences such as `FontStore` are injected here, with in-memory defaults for tests.
- `lib/home/main_shell.dart` keeps Home, Following and My pages alive in an `IndexedStack`. Routes use the existing swipe-back/zoom navigation. Theme changes must preserve these states and the Navigator.
- Feature directories contain custom widgets, models, API adapters and fake adapters. `lib/shared/theme.dart` centralizes colors and geometry across those features: roughly 7,700 lines and 861 direct color declarations or `BiliColors` aliases. Many colors appear in constant widget trees, painter defaults and gradients.
- `lib/settings/font_store.dart` provides the existing local JSON persistence pattern: tolerant reads, immediate notification, ordered writes and temporary-file replacement. `FollowFont` rebuilds existing elements in place because font selection uses global values; dark mode should instead use context dependencies.
- `lib/me/me_page.dart` already renders the moon action with key `me-night` and label `夜间模式`. `_TopRow` currently sends every action to `_soon()`. `lib/me/me_glyphs.dart` already draws the moon; reuse it.
- `lib/skin/` manages equipped artwork, foreground colors and status-bar contrast. `SkinModel` caches header measurements in `.status.json`; those measurements currently assume fixed light backdrops.
- `lib/video/`, `lib/player_ui/`, `lib/comments/` and `lib/danmaku/` draw the video page and controls. The player already has intentional dark fullscreen surfaces and separate portrait/light variants.
- `packages/bili_core/` contains the pure Dart APIs, download engine and business logic. iOS uses native AVPlayer; Windows uses media_kit. Theme work belongs in the Flutter UI and local preferences.
- `test/` has feature widget, behavior and visual comparison coverage with fake APIs. `scripts/gate.py` runs the full local verification, including Windows and core checks.

## Proposed behavior

1. Tap the existing moon on My to switch immediately between light and dark. Keep its position, hit target and artwork; expose the selected state and change its accessibility action to `日间模式` while dark.
2. Save the choice on this device and restore it before the first normal app frame. New installations retain the current light default. A corrupt or missing preference falls back to light without preventing launch.
3. Apply the appearance to every app-owned screen, navigation bar, list, sheet, dialog, menu, input, placeholder and loading state, including iPad layouts and developer screens.
4. Keep BiliFast's current geometry, typography, icons and navigation. Use the supplied examples for dark colors and contrast, including a softer pink accent in dark mode. Preserve media, photos, user-selected danmaku colors and deliberately dark video overlays.
5. Preserve navigation, list positions, drafts, selected tabs, downloads, player instances and PiP across a switch. Appearance changes must not trigger API reloads or recreate services.

This proposal uses a manual light/dark choice. Following the OS or adding a new appearance settings page would expand the product scope and can be added separately.

## Visual direction from the supplied examples

The user supplied two dark-mode screenshots after the initial plan: a feed/list screen and a video introduction with related videos. The user explicitly said their UI differs and they are references. They guide color, surface treatment and contrast; retain BiliFast's existing layouts, component sizes, feed arrangement, tabs, icon artwork and navigation.

Observed direction:

- Use a near-black charcoal canvas for ordinary pages and navigation, with subtly lighter fields/surfaces where separation is needed. Reserve pure black for the existing video background rather than making every UI surface black.
- Use soft off-white for titles and primary content, a middle grey for inactive icons/tabs, and a darker grey for metadata. Keep the hierarchy readable without making all text white.
- Use thin, low-contrast separators. Lists can share the page surface; do not add raised cards or shadows where the existing layout has none.
- Use a muted rose pink for selected tabs, underlines and filled primary actions in dark mode, with white text on those filled actions. Keep light-mode values unchanged.
- Keep thumbnail/video colors intact. White status icons belong over the charcoal page and black player surround; existing skin/artwork contrast rules still apply.

Provisional palette targets, estimated visually from the displayed references rather than sampled from original image files:

| Role | Starting value |
| --- | --- |
| Ordinary page/navigation surface | `#18191B` |
| Subtle raised surface/input | `#202123` |
| Primary text | `#E3E5E7` |
| Inactive icon/tab | `#A2A7AE` |
| Secondary metadata | `#7B8087` |
| Hairline/border | `#303235` |
| Dark-mode accent | `#D04A79` |

Treat these as implementation starting points, not measured official tokens. Check text/background contrast and rendered screens before settling them; small text may need a brighter value than metadata in the examples. Extrapolate unshown dialogs, settings, loading and empty states from the same semantic palette.

## Implementation sequence

### 1. Establish the theme and preference contracts

- Add `lib/settings/appearance_store.dart`: a `ChangeNotifier` with light/dark selection, `memory()`, `load(path)`, `toggle()`, ordered persistence and a test wait hook. Use `appearance.json` in the support folder and follow `FontStore`'s logging/error conventions without changing font behavior.
- Inject the store through `AppServices`, load it in `main()` and keep its identity stable. Resolve it before measuring/loading skins and before `runApp`.
- Add `lib/shared/app_theme.dart` to build light and dark `ThemeData`, including an explicit semantic `ColorScheme`, Cupertino appearance, input/selection styling, switches and dialogs. Preserve `BiliFonts.untracked`, font selection, localization and ripple behavior.
- Add an immutable `BiliPalette` as a `ThemeExtension`, with `of(context)`. Define page, surface, raised surface, primary/secondary/disabled text, divider, field, pressed fill, link, placeholder, shimmer, glass and accent/on-accent roles. Preserve the existing pink in light mode and use the reference's softer rose direction in dark mode. Keep dark-specific feature colors centralized alongside the existing tokens.
- Make `BiliFastApp` listen to appearance changes and supply `theme`, `darkTheme` and `themeMode`. Keep the Navigator key and widget/service identities stable. Use an immediate change initially so the custom colors and platform chrome switch together; honor Reduce Motion if a transition is later introduced.
- Keep launch failure presentation usable when preferences cannot load; use the resolved choice if available and a safe light fallback otherwise.

### 2. Migrate custom color consumers

- Inventory each color as adaptive UI, fixed brand/content, video overlay or skin-provided. Use semantic roles, rather than replacing colors according to their hex value: white on a pink badge must stay white even when the ordinary white surface changes.
- Keep numeric dimensions, timing, font metrics and paths constant. Resolve adaptive color groups through context, for example `MeTheme.colorsOf(context)` backed by `BiliPalette.of(context)`. Existing light measurements become the light values unchanged.
- Remove `const` only from expressions that now depend on appearance, including transitive theme aliases, decorations, gradients, default arguments and widgets. Constructors can remain const when their colors are passed at runtime.
- Pass resolved colors into custom painters and compare them in `shouldRepaint`. Audit painters returning `false`, cached styles, `late final` decorations and functions that draw without a `BuildContext`.
- Let every adaptive widget register a theme dependency, including hidden tabs, overlays and route contents. Do not rely on a mutable global palette or a forced recursive rebuild.
- Start with shared placeholders, loading, press feedback, images, toast and menus; then migrate shell/Home/My, search/dynamic/space, library/settings/login, and finally video-page content/comments/portrait panels. This order prevents shared light surfaces from leaking into migrated features.
- Wire only `me-night` to the appearance store; retain the other top-row actions' existing behavior. Update tests that currently expect the moon to show the placeholder toast.

### 3. Handle platform chrome, media and skins

- Make `DefaultStatusBar` follow effective page brightness. Audit explicit annotations in Home/My/Following, search, history, favorites, watch later, settings, spaces, offline pages and post pages so a hardcoded light-page choice cannot override dark mode.
- Preserve status contrast decisions over artwork, cover images and video. Check pushed pages, returning/back gestures and the Windows simulated status bar.
- Remove the forced light keyboard in `comments/composer.dart`; make other ordinary inputs follow the active theme. Keep fullscreen danmaku input's intentional dark appearance and adapt its portrait variant where appropriate.
- Separate app appearance from the player's layout choice. Portrait sheets and the video page body become adaptive; fullscreen/vertical chrome, black video backgrounds, media pixels and danmaku outlines retain their intended colors. Include offline video pages and iPad inline controls in this audit.
- Proposed skin rule: retain equipped artwork and package foreground colors within the regions they dress; apply app appearance to ordinary content and fallback regions. Adapt fades and translucent fills to the actual adjoining surface.
- Include appearance/backdrop in skin status-measurement cache identity, or store both variants. Remeasure transparent artwork when its backing surface changes; reject stale asynchronous results from a previous appearance. Preserve the existing crop, VIP-card-height and video-header rules. Do not refetch the skin or unequip it to switch appearance.
- Theme the app-owned login frame and loading states. Inspect WebView background/host behavior on iOS; the remote official login page controls its own content.

### 4. Verify behavior and appearance

- Store tests: missing/malformed/unknown values, save/reload, repeated toggles with ordered writes, and write failure without losing the live choice.
- App tests: the moon changes the visible UI and semantics; hidden tabs, existing routes and already-open overlays update; navigation and page state survive; an existing player/controller remains identical; changing appearance does not reload feature data.
- Repaint tests for representative custom icons and placeholders. Regression coverage for fixed white badge/video text and preserved danmaku colors.
- Status tests extend `test/app/default_status_bar_test.dart` with both appearances, push/pop transitions and artwork overrides. Cover theme-specific skin measurements and a rapid toggle while measurement is pending.
- Render representative light and dark states with fake data: Home, My, Following, search, settings, a library list, space, video intro/comments, composer, portrait sheets, fullscreen and offline playback. Include loading/error/empty/disabled/pressed states, plain and dressed headers, and iPad Home/video layouts. Use existing system-font stand-ins and image comparison helpers; keep reference images and generated screenshots out of commits.
- During implementation run focused feature tests, then `fvm flutter analyze` and `fvm flutter test`. Run `python scripts/gate.py` for release validation and operate every changed control on Windows with fake account data and muted playback. This planning pass does not claim those checks passed.

## Implementation ownership

The repository's running-a-slice workflow calls for shared contracts first and independent builders afterward. Keep one owner per file, especially the central theme file.

| Owner | Files/area | Validation |
| --- | --- | --- |
| Coordinator | `main.dart`, `app/app_scope.dart`, new appearance/palette/theme files, all changes in `shared/theme.dart`, theme contracts | Store, root theme, status fallback and state-preservation tests |
| Builder A | `home/`, `me/`, `dynamic/`, `search/`, `space/`, matching feature tests | Moon behavior, retained tabs, feed/navigation visuals |
| Builder B | `shared/` consumers excluding theme contract files, `settings/` excluding appearance store, `account/`, `history/`, `favourites/`, `watch_later/`, `offline/` excluding playback-page UI, `devtools/`, `screens/`, matching tests | Shared feedback, inputs, lists, settings/login/library visuals |
| Builder C | `video/`, `player_ui/`, `player/`, `playback/` UI consumers, `comments/`, `danmaku/`, `skin/`, offline playback-page UI and matching tests | Player identity, portrait/fullscreen, skins/status measurement and media visuals |

The local implementation followed this division, with central token additions handled by the coordinator. The feature work is integrated on `feat/dark-mode`.

## Reference requirements and decisions

`local/official-app-reference/iphone/` is absent in this checkout, but the user has supplied two screenshots in the conversation and explicitly limited them to visual reference because their UI differs. This instruction takes precedence over interpreting the repository's screenshot rule as a requirement to reproduce their layout or obtain a screenshot for every dark state. The examples establish sufficient color direction for implementation; apply it consistently to BiliFast's existing screens and extrapolate uncovered states. Reuse the existing moon artwork.

The proposed manual toggle, light default and skin precedence above remain the working product choices. Validate layout against BiliFast's current light UI and contrast/color relationships against the supplied examples. Pixel matching the references' geometry is outside this change.

The user approved implementation on a local branch after reviewing this plan and supplying the color references. Publishing and release work are outside that approval. The local status records 1.3.0 (6) as last shipped, making (7) the tentative next build only if no newer build exists when release work begins.

## Phone acceptance steps

1. Open My, tap the existing moon, and confirm the header, ordinary content and bottom bar change together. Switch back and confirm the existing light layout returns.
2. Leave dark selected, fully restart the app, and verify the first app frame uses it.
3. Visit Home, Following, search, settings, history, favorites, watch later, offline downloads and a space. Scroll lists and check empty/loading/error states, text, icons and dividers.
4. Return through pushed pages and edge-back gestures; verify status icons remain readable. Repeat with an equipped skin, including a transparent header and a My page with/without the VIP card.
5. Open a video, comments, a reply thread, composer and portrait panels; inspect keyboard appearance, hints, selection and disabled actions. Switch appearance with playback/PiP active through an available navigation path and confirm it continues without restart.
6. Enter fullscreen and vertical playback, inspect controls and danmaku, then return to the page. Repeat offline playback; media brightness and content colors should remain consistent.
7. On iPad, check Home and video inline/fullscreen layouts in both orientations. Check the remaining screens at their existing layouts.
8. Repeat a toggle while lists and a skin are loading, and with Reduce Motion enabled. Confirm no stale light panel, lost draft, moved list position or delayed status-bar reversal.

Only device checks can establish the native keyboard, WebView, HDR/PiP and real iOS status-bar behavior; Windows renders and widget tests cover the shared Flutter UI.
