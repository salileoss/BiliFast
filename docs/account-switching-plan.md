# Account switching: design and implementation plan

Approved and implemented locally, 2026-11-03. The current-design investigation below describes the starting code at
`e7e97d8`; the implementation sections record the agreed behavior. The user supplied the account-list reference and
approved using the existing Settings style. Native iOS build and phone acceptance remain release checks.

## Current design

There is no separate BiliFast authentication server. The backend side is the pure-Dart `bili_core` API client calling Bilibili, with Flutter coordinating identity and native code providing secure storage and WebKit access.

| Area | Current behavior | Main source |
|---|---|---|
| Login entry | 我的's logged-out header, 设置's 登录 / 重新登录, and protected actions open a shared, deduplicated `LoginGate`. An action is not replayed after login. | `lib/account/login_gate.dart`, `lib/me/me_page.dart`, `lib/settings/settings_page.dart` |
| iOS login | A fullscreen login page embeds Bilibili's website. `LoginFlow` clears old WebKit Bilibili cookies, watches for `SESSDATA`, and passes the collected cookies to `didLogin`. Network failure permits retrying the captured session. | `lib/account/login_page.dart`, `ios/Runner/WebCookies.swift` |
| Windows login | Normal runs load no credentials. An explicitly enabled `--real-account` run offers web QR login; fake runs use fixtures. | `lib/main.dart`, `lib/account/qr_login.dart` |
| Web identity | One `AppEnvironment`, one mutable `CookieJar`, one shared `BiliClient`. State is unknown, logged out, logged in, or expired; `mid`, face and recent nav result are separate fields. Startup restores cookies and checks `/x/web-interface/nav`. Network/storage failure is distinct from expiration. | `lib/app/app_environment.dart:40` |
| Login completion | `didLogin` merges incoming cookies into the active jar, starts saving immediately, and checks identity up to three times. Its epoch rejects stale account-check results. Successful login increments `logins`, including replacement of an already logged-in account. | `lib/app/app_environment.dart:176` |
| Secure persistence | iOS has two fixed Keychain items: cookies and app token, both under account `bilibili`. Cookie changes use a serialized, coalescing writer. Failed cookie reads block writes to protect an existing login. Windows stores only cookies in a DPAPI-encrypted `login.bin`. | `lib/account/keychain_store.dart`, `lib/account/cookie_persistence.dart`, `ios/Runner/KeychainChannel.swift:9`, `lib/account/dpapi_keychain_store.dart` |
| Official API identity | `TokenAppAuth` separately loads an access/refresh token with `mid` and expiry. Authorization opens a confirmation in the official app, then polls. Tokens nearing expiry renew once. A token belonging to another web account is deleted, rather than retained for later. | `lib/account/app_auth.dart:87` |
| Request credentials | Official account calls use the app token and Android signature without cookies. Web calls use cookies and CSRF. Web calls can await WBI signing and retry once after HTTP 412. | `packages/bili_core/lib/src/api/bili_client_official.dart`, `packages/bili_core/lib/src/api/bili_client.dart:405` |
| Logout | Deletes the active cookies/token and WebKit data. Windows first requires server logout to succeed. 设置 returns to the root on success. | `lib/app/app_environment.dart:214`, `lib/settings/settings_page.dart:162` |
| Account-dependent UI | `AppServices` clears follows, dynamic likes and synced block rules on relevant account events. 我的 and skin have some identity checks and generation guards. Root tabs stay mounted in an `IndexedStack`. | `lib/app/app_scope.dart:228`, `lib/me/me_model.dart`, `lib/skin/skin_model.dart`, `lib/home/main_shell.dart` |

### Gaps that a switch button alone would leave

- No saved-account collection or per-account credential storage exists. Calling logout before switching would destroy the session we want to retain.
- Login merges cookie maps. A new account can inherit cookies absent from its own login response; a switch must replace the account's entire credential set.
- Home checks a signed-in boolean and an authorized boolean. Switching between two logged-in accounts with tokens can leave the old recommendations visible (`home_page.dart:175`). Favourites and watch-later pages also do not generally reset on a successful A-to-B replacement.
- `PendingReport` has no account owner. The history flusher clears only on logged out; replacing an expired login with a different account can send the previous account's waiting reports (`history_outbox.dart:24`, `:382`; also documented in `CLAUDE.md`). Queued heartbeat closures call the shared mutable client when their turn arrives.
- The environment epoch protects nav state, not all API work. A request can read CSRF before awaiting WBI and cookies afterward; a late 412 can retry using a later account's jar. Token renewal only checks that some token remains authorized before accepting its result (`app_auth.dart:252`).
- `me.json`, the selected skin and app-authorization decline state are effectively single-account stores. An old profile or skin must not appear while another account is loading.
- PiP can outlive its page, and downloads obtain fresh stream URLs through the shared client. Both need explicit behavior at an account boundary.

## Proposed user behavior

Assumption: account switching means several remembered Bilibili accounts on this device, with exactly one active account. Each account keeps both its web session and its own optional app token. Different accounts for different API features remain outside this feature.

1. Add 设置 → 切换账号, available even when the current session is expired. The page lists saved avatars/names, the current-account marker and known expiration state, plus 添加账号. Listing accounts makes no network calls.
2. Tapping another saved account shows a busy state and checks that account's saved cookies once. On success, switch and return to 我的 with fresh account-dependent content. Switching creates no login session and never calls logout. Tapping the current account is a no-op.
3. If the target session is expired, show 重新登录 for that account. If validation cannot reach Bilibili, keep the current account and offer retry. Cold launch can still restore the last active account offline as unknown; offline switching is deferred for the first version.
4. 添加账号 reuses the existing web/QR login presentation with a staged completion callback. Cancel or failed validation preserves the active account. A verified duplicate `mid` updates the saved account instead of adding a second row. Reauthentication of a specific account rejects a different `mid` and explains the mismatch.
5. A saved valid app token restores with its account. Missing/expired app authorization uses the existing web fallback and confirmation flow. A confirmation from the wrong account in the official app reports the mismatch and preserves the saved sessions.
6. 退出登录 removes the active saved credentials and enters guest mode; other saved accounts remain available. Removing an inactive account targets only that record. Preserve existing platform logout semantics, including Windows server confirmation before deleting that session. Switching itself performs neither removal nor revocation.
7. A successful switch stops playback/PiP, closes old detail routes and rebuilds account-dependent root content. In-progress downloads pause; completed local downloads remain on the device. A failed switch keeps the previous identity and restores any temporarily paused UI work.

The UI follows the supplied account-switching reference and reuses the existing routes, theme tokens, loading
states and confirmation components. Fixture renders cover light/dark phone and iPad layouts.

## Backend and state design

### 1. One secure account vault

Add a small `AccountVaultStore` interface and versioned model, using a single new Keychain item on iOS. One document contains `version`, nullable `activeMid`, and saved accounts keyed by verified `mid`. Each saved account contains its cookie map, optional `AppToken`, display summary and authorization-declined preference. A single document avoids coordinating a separate account index with multiple credential writes.

- Preserve the existing Keychain accessibility level. Tokens and cookies never go into ordinary JSON settings, logs, test fixtures with real values, or screenshots.
- Route all mutations through one serialized writer. Cookie/token updates capture their owner and session generation before awaiting; they cannot resolve their destination from whatever account is active later. Flush the outgoing account before committing a switch, and prevent older snapshots from overwriting a newer active-account choice.
- Distinguish absent, unreadable and unsupported-version storage. Unreadable storage blocks vault writes; logging into one new account must not erase other accounts whose vault could not be read.
- Migrate the existing cookie/token slots after nav verifies the legacy identity. Associate a token only when its `mid` matches. Keep the old records intact until the new vault write and read-back succeed; a failed/offline migration remains usable through the existing session without prompting for another login.
- Once present, the new vault is authoritative, including an empty vault with no active account. Never fall back to legacy credentials after logout or a failed new-vault read. Remove legacy records after successful migration so an older build cannot resurrect a forgotten session.
- Use a DPAPI-protected vault for explicitly enabled Windows real-account runs, migrating its old cookie file. Windows continues to hold no app token. Normal/fake runs use empty/in-memory stores and never read the real vault.
- Keep the official API device `buvid` device-wide. Move `authDeclined` to the account record; it currently lives beside the device id.

Storage migration is one-way, as approved with the implementation go. Older builds do not understand the new saved accounts.

### 2. Serialize account transitions

Put add, reauthenticate, switch and logout behind one transition coordinator owned by `AppEnvironment`. Expose active saved identity, a monotonically increasing session generation, and a dedicated session-change notification. An ordinary nav refresh does not count as a new session; a new login for the same `mid` does.

For a saved-account switch:

1. Serialize/deduplicate the request. Load and validate the target in an isolated candidate jar/client; no candidate cookie or identity update reaches the active environment. Require nav's verified `mid` to match the saved record.
2. After validation, suspend new account mutations and history flushing, pause downloads and playback (including inline feed playback and PiP), and suspend reporters. Capture any final history report for its outgoing owner. Keep old routes/controllers until persistence succeeds so a failed commit can resume A.
3. Flush outgoing credential updates and persist the vault with the target as active. If persistence fails, keep the outgoing identity and report that switching could not be saved. Do not claim success for an in-memory-only switch.
4. In one synchronous publication, advance the generation and replace the whole active cookie map, token, `mid`, face, nav and account state. Publish no intermediate mixture of A's web login and B's app token.
5. Notify dependent services once, reset account data, dispose old players/reporters, close old routes and return to 我的. Teardown callbacks remain bound to A and cannot report as B. Resume network work only under the new session. A crash after the durable selection but before UI publication restores the target on next launch.

Fresh login uses the same staged validation and durable commit. Refactor `LoginFlow` and QR login to submit cookies through that path instead of mutating the active environment immediately. Closing the login invalidates its pending operation, including late validation results.

### 3. Guard requests and token work across the boundary

Keep the shared client identity so existing API adapters do not all need rebinding, but introduce a request session context in `bili_core`:

- Capture generation and a consistent credential snapshot at the start of each logical operation. After signing, delay, queueing or another prerequisite, check the generation before sending. A stale operation exits without a new request.
- A 412 recovery stays within its original session and stops if that session changes. Late risk-cookie results cannot mutate the current jar. Requests already sent can finish for their original account; their results cannot update the new UI or persistence.
- Cover multi-call operations and fallback paths as well as `_send`; an upload-then-comment flow or a queued history report cannot silently start its next step under another account.
- Token confirmation, decline, renewal, rejection and deletion all capture owner/generation/token identity. A late A renewal cannot replace or delete B's token, including A→B→A transitions. Reuse existing single-flight authorization behavior within a session.
- Restoring another account's token does not delete the outgoing account's saved token. Renew only the active account, using the existing expiry policy; no background roster-wide polling or renewal.

### 4. Give account data explicit ownership

| Data/work | Behavior at a switch |
|---|---|
| Recommendations, 关注 feed, follows, dynamic likes, synced block rules | Invalidate on session generation, including logged-in → logged-in. Clear old cards before fetching new ones. |
| 我的 and skin/loading animation | Load only a cache keyed to the selected `mid`, or show the normal loading/stock state. Guard late disk/API completions. Keep reusable skin package files shared. |
| Pushed favourites, watch later, history, spaces, actions and composers | Close old routes/overlays; reset surviving models. Pending actions cannot replay after the switch. |
| Watch history outbox | Persist `ownerMid`, key reports by owner and video, and flush only the active owner's reports through a generation-bound sender. Switching retains A's queue for A. Removing A deletes A's queue. Queued sends check ownership immediately before transmission. |
| Legacy history reports with no owner | Discard during migration: the current format cannot prove their owner, and the known account-replacement gap makes assigning them to whoever is logged in unsafe. This trades a small amount of queued progress for correct account attribution. |
| Playback/PiP/reporters | Stop before credential publication. Late teardown cannot create a B report for A's playback. Explicitly cover PiP still attached to a live page, not only the keeper's detached playback. |
| In-progress/queued downloads | Persist their owner, pause at the switch and prevent background handoff, retry or URL renewal under another owner. Resume only when the owner is active and the user resumes. Completed files stay device-wide. |
| Appearance, fonts, player settings, search history, local recents, image/codec/node caches, completed downloads | Remain device preferences/data for this first version. Server history, personal feeds and credentials remain account-specific. |

## Implementation order and ownership

Implementation used the repository's slice workflow: shared contracts first, then separate storage, session and UI
worktrees, followed by data/lifecycle work and integration reviews. No live account calls were used.

| Order / owner | Builds and owns | Verification |
|---|---|---|
| 0. Coordinator | Shared models/interfaces; `app_environment.dart`, `app_scope.dart`, `main.dart`, shared theme additions and any native registration/project entries | Transition ordering and integration contracts |
| 1. Storage agent | New vault model/implementations, legacy storage adapters, `cookie_persistence.dart`, `KeychainChannel.swift`; corresponding storage tests | Migration, read/write/delete failure, serialized writes, DPAPI round trips |
| 2. Session agent | `bili_core` client/session changes, `app_auth.dart`, token/request tests | Deferred signing, 412, renewal, rejection, confirmation and A→B→A races |
| 3. UI agent | Account-switch page/model, login gate/page/QR adaptation, settings entry; corresponding widget tests | Add/cancel/duplicate/reauth, busy/error states, accessibility, light/dark/iPad renders |
| 4. Data/lifecycle agent | Root/home refresh, profile/skin ownership, history outbox/reporters, playback/PiP and offline work; corresponding model/lifecycle tests | No old account content, reports, mutations or URL renewals after the boundary |
| 5. Coordinator | Seam fixes in shared files; repository docs/checklist and release integration | Full gate, integrated fake-account run, phone checklist |

Storage, session, UI and data owners can work after the contracts step; the phases describe dependencies, not separate releases. Existing files outside an owner's area go back to the coordinator. Tests follow the same ownership as their production files.

## Acceptance and checks

Automated checks use made-up accounts and held fake transports, with no real login or account traffic:

- Restore the existing legacy login without a new scan. Test absent/unreadable/unsupported vault, interrupted migration, failed cleanup, failed commit, and restart after each durable transition point.
- Add B while A is active; cancel before and during validation; reject a wrong-account reauthentication; deduplicate a second login as A. A remains active until a successful commit.
- Switch A→B→A with both tokens present, with no tokens, and with mixed authorization. Verify the actual cookie, CSRF and token used for each host and that switching calls no login/logout endpoint.
- Hold A's nav, signing, 412, token renewal, confirmation, persistence and data fetches across a switch; release them in both orders. Also test A→B→A so checking only `mid` cannot pass.
- Queue A's heartbeat before switching and release its lane afterward. It never sends as B, removes B's report, or appears in B's history. Repeat across process restart and same-video reports in both accounts.
- Both accounts logged in and authorized: recommendations, follows, profile, skin, favourites and watch later show only the selected account. Logout/removal affects only its target and never silently selects another account.
- Switch with inline video, a pushed player, attached/detached PiP, an active download and native background handoff. Assert players stop and old-owner authenticated work remains paused.
- Run focused core/app suites first, then analyze and the full `python scripts/gate.py` before shipping. Add Swift parsing and native bridge coverage for the changed Keychain contract. Widget/render checks use fixtures, system-font stand-ins and official screenshot measurements.

Phone acceptance, using accounts KaiC chooses for the check:

1. Upgrade: the existing account still opens without another login or authorization prompt.
2. 设置 → 切换账号 shows the current account. Add another account, then switch both ways; names, avatar, feed, following, favourites, watch later and skin follow the selection.
3. Cancel 添加账号 and retry a failed/expired target: the original account remains usable. Returning from official-app authorization for the wrong account gives a clear failure.
4. Force-quit after a switch and reopen: the selected account returns with its own authorization. Test a target without app authorization and the web fallback.
5. Switch while a video/PiP and download are active: playback stops, downloads pause, and A's queued progress never enters B's server history.
6. Remove an inactive account, then log out the active one: guest mode appears, remaining saved accounts are intact, and removed credentials do not return after relaunch.

Only the phone can establish real WebKit cookie isolation, Keychain upgrade behavior, official-app handoff, native PiP teardown and background-download cancellation. Existing tests cover parts of login/logout, but `CLAUDE.md` records that logout/relogin has not yet been exercised on the phone.

## Decisions and reference inputs for implementation

- **Approved product defaults:** save several accounts; validate online before switching; enter guest mode on logout; stop playback and pause downloads; share device preferences and completed local files.
- **Storage compatibility:** one-way migration replaces legacy-format downgrade compatibility. Legacy items are removed only after the new vault is saved and read back.
- **UI reference:** the user supplied the dark account-switching screenshot during implementation and approved the existing Settings components for the other states. The list uses its avatar rows, current-account check, 管理 action and separate 添加账号 row; light/dark phone/iPad fixture renders were inspected without copying personal account details.
- **Live checks:** selecting accounts and allowing new logins/official-app confirmations for phone testing is a separate implementation-time decision. Drafting this plan has used no live account calls.
- **Release:** the last shipped build documented in `CLAUDE.md` is 1.3.0 (6); tentatively target the next build, 1.3.0 (7), after checking release state at implementation time.
