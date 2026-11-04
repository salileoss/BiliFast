# Account switching validation

Implemented locally on 2026-11-03, on the existing `west-coast/btr-auto` branch. No live Bilibili account calls or
new logins were used during development. The supplied screenshot informed the layout; fixtures use made-up accounts.

## Implemented behavior

- 设置 → 切换账号 lists remembered accounts with avatars, the current marker, 管理 and 添加账号.
- Each account retains its own encrypted cookies, optional app token and authorization-declined preference.
- A target is validated separately and saved before publication. Failed validation or storage keeps the working
  identity. The login can be canceled during validation; its close control is disabled during the durable commit.
- Existing single-account credentials migrate after uid verification and vault read-back. Unreadable storage is
  preserved, and a later retry can restore it. Migration retains credential updates that arrive during its save.
- Session generations reject stale requests and results, including A→B→A, signing, risk-cookie retries, token
  renewal, authorization, comment uploads and playback URL requests.
- Saved-account replacements refresh personalized tabs and open 我的. Ordinary guest login/logout preserves the
  current tab. Navigation does not dismiss the new account's authorization prompt.
- Watch reports retain their owner across switches. Old unowned disk reports are discarded, as agreed in the plan.
  Unfinished downloads retain their owner, pause on switching and cannot resume under another account. Native
  background-transfer cancellation is awaited before saving the new active identity.

## Checks

The pinned checkout SDK (`.fvm/flutter_sdk`, Flutter 3.47.7 / Dart 3.13.5) was used directly because FVM is absent
from PATH. Test transports and media fixtures remain local.

| Check | Result |
|---|---|
| App `lib` and `test` analysis, fatal infos | Passed |
| Full Flutter unit/widget suite | Passed: 4,513 tests on the final implementation |
| Core analysis and tests | Passed: 1,202 tests, one existing skip |
| Workflow checks | Passed: 36 tests |
| PC tools checks | Passed: 86 tests |
| Windows release build | Passed after the final implementation changes |
| Windows native integration | Passed per file: appearance (1 test), player (11 tests) |
| Whitespace checks | Passed |
| Native iOS compile / real-device checks | Pending: this machine has no Swift compiler or iOS SDK |

`python scripts/gate.py` cannot start here because `fvm` is not on PATH; no release-gate stamp or TestFlight release
was claimed. Available checks were run directly. The existing unrelated `.vscode/` and `LOCAL_SECURITY_REVIEW.md`
files were left untouched.

The first combined Windows integration attempt and a concurrent player attempt could not attach to the debug
process. The final player run, with other Flutter jobs finished, passed all 11 tests. The appearance check passed
in the combined attempt. No native player implementation changes were made for this feature.

## Phone acceptance still required

1. Upgrade with the existing login: it remains active without another scan or unexpected authorization prompt.
2. Add B, switch A→B→A, then relaunch. Profile, recommendations, following, favourites, watch later, skin and official
   authorization follow the selected account.
3. Cancel an addition or retry an expired/offline target: the working account remains selected. Confirming the wrong
   account in the official app reports the mismatch.
4. Switch during playback/PiP and a background download: old playback stops and the download pauses. A's progress
   does not enter B's server history; A's download resumes only when A is selected.
5. Remove an inactive account, then log out the active one: guest mode appears and other remembered accounts remain.
