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
