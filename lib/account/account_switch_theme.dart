import 'package:flutter/widgets.dart';

import '../shared/theme.dart';

/// The supplied account-switch reference: an instruction band, 80 pt rows and round 48 pt faces.
abstract final class AccountSwitchTheme {
  static const barHeight = 44.0;
  static const titleSize = 17.0;
  static const actionSize = 16.0;
  static const hintSize = 12.0;
  static const hintHeight = 33.0;
  static const rowHeight = 80.0;
  static const inset = 12.0;
  static const avatar = 48.0;
  static const avatarGap = 12.0;
  static const nameSize = 15.0;
  static const noteSize = 12.0;
  static const noteGap = 4.0;
  static const sectionGap = 12.0;
  static const check = 22.0;
  static const checkGlyph = 17.0;
  static const plus = 26.0;
  static const actionWidth = 64.0;
  static const rule = 1 / 3;

  static Color page(BuildContext context) =>
      BiliPalette.of(context)
          .choose(BiliColors.pageGrey, const Color(0xFF101010));
  static Color surface(BuildContext context) =>
      BiliPalette.of(context).choose(BiliColors.card, const Color(0xFF17181A));
  static Color addFill(BuildContext context) =>
      BiliPalette.of(context)
          .choose(BiliColors.softGrey, const Color(0xFF242628));
  static Color ruleColor(BuildContext context) =>
      BiliPalette.of(context)
          .choose(BiliColors.divider, const Color(0xFF242628));
  static Color checkInk(BuildContext context) =>
      BiliPalette.of(context).choose(BiliColors.card, const Color(0xFF17181A));
}
