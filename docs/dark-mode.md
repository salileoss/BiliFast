# Dark mode

On My (`我的`), tap the existing moon action to switch between light and dark. The action announces `日间模式` when dark is selected. The choice belongs to the device and survives restart; new installations start in light mode.

The supplied screenshots guide the charcoal surfaces, soft white text, grey metadata and rose accent. BiliFast retains its existing layout, navigation, fonts and artwork. Videos, thumbnails, danmaku content colors and white lettering over media or colored badges retain their colors. Equipped skins keep their artwork and foreground colors within the regions they dress.

## Implementation

- `settings/appearance_store.dart` stores `light` or `dark` in `appearance.json` in the application support folder. Changes notify immediately, writes run in order, and unreadable preferences fall back to light. Persistence failures are logged without reverting the visible choice.
- `main.dart` loads appearance before the first normal frame and uses stable app services and Navigator identities across changes.
- `shared/app_theme.dart` builds the Material and Cupertino themes. `shared/bili_palette.dart` supplies the semantic palette through a `ThemeExtension` and `Theme.of(context)` dependencies.
- `shared/theme.dart` retains the measured light constants and constant geometry. Its `colorsOf(context)` views resolve adaptive feature colors without global mutable state. Widgets subscribe through those views; painters and helpers receive resolved colors explicitly.
- Platform chrome follows the current page surface. Artwork and video can override the default status style. Ordinary inputs use the selected keyboard appearance.
- Skin header contrast is measured against the actual backing surface. Appearance changes invalidate pending measurements; light and dark measurements have separate cache files.

When adding UI, use the appropriate context-resolved color view for adaptive surfaces and text. Keep fixed media, badge lettering, shadows and content colors explicit. Resolve colors before passing them into a painter, include them in repaint decisions, and avoid caching theme-dependent styles across dependency changes.

The implementation is local development work on `feat/dark-mode`. No TestFlight release or remote publication is part of this change. Device checks for native keyboards, WebView, HDR and PiP remain separate from local Flutter and Windows verification.
