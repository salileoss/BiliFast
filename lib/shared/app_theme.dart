import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

ThemeData biliTheme(Brightness brightness) {
  final palette = BiliPalette(brightness);
  return ThemeData(
    brightness: brightness,
    fontFamily: BiliFonts.family,
    fontFamilyFallback: BiliFonts.fallback,
    textTheme: BiliFonts.untracked,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
      primary: palette.accent,
      onPrimary: BiliColors.onPink,
      surface: palette.surface,
      onSurface: palette.text,
      onSurfaceVariant: palette.secondary,
      outline: palette.icon,
      outlineVariant: palette.divider,
    ),
    extensions: [palette],
    scaffoldBackgroundColor: palette.page,
    canvasColor: palette.surface,
    dividerColor: palette.divider,
    disabledColor: palette.disabled,
    iconTheme: IconThemeData(color: palette.icon),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: palette.accent,
      scaffoldBackgroundColor: palette.page,
      barBackgroundColor: palette.surface,
      textTheme: CupertinoTextThemeData(primaryColor: palette.accent),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: palette.accent,
      selectionColor: palette.accentTint,
      selectionHandleColor: palette.accent,
    ),
    // Rows draw their own iOS-style press feedback.
    splashFactory: NoSplash.splashFactory,
  );
}
