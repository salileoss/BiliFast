import 'package:flutter/material.dart';

/// App-owned surfaces and foregrounds. Media and equipped artwork keep their own colors.
@immutable
class BiliPalette extends ThemeExtension<BiliPalette> {
  const BiliPalette(this.brightness);

  final Brightness brightness;
  bool get isDark => brightness == Brightness.dark;

  static BiliPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<BiliPalette>() ?? BiliPalette(theme.brightness);
  }

  Color get page => isDark ? const Color(0xFF18191B) : const Color(0xFFF1F2F3);
  Color get surface => isDark ? const Color(0xFF18191B) : const Color(0xFFFFFFFF);
  Color get raised => isDark ? const Color(0xFF242628) : const Color(0xFFF6F7F8);
  Color get text => isDark ? const Color(0xFFE3E5E7) : const Color(0xFF18191C);
  Color get secondary => isDark ? const Color(0xFF9499A0) : const Color(0xFF9499A0);
  Color get icon => isDark ? const Color(0xFFA2A7AE) : const Color(0xFF61666D);
  Color get disabled => isDark ? const Color(0xFF6F747C) : const Color(0xFFC9CCCF);
  Color get divider => isDark ? const Color(0xFF303235) : const Color(0xFFE3E5E7);
  Color get accent => isDark ? const Color(0xFFD04A79) : const Color(0xFFFF6699);
  Color get accentTint => isDark ? const Color(0x33D04A79) : const Color(0x1FFF6699);
  Color get link => isDark ? const Color(0xFF69B7E5) : const Color(0xFF00699D);
  Color get pressed => isDark ? const Color(0x14FFFFFF) : const Color(0x14000000);
  Color get glass => isDark ? const Color(0xEB242628) : const Color(0xB8FFFFFF);
  Color get glassBorder => isDark ? const Color(0xFF45484D) : const Color(0x99FFFFFF);
  Color get shimmerBase => isDark ? const Color(0xFF242628) : const Color(0xFFEDEEF0);
  Color get shimmerHighlight => isDark ? const Color(0xFF303235) : const Color(0xFFF8F9FA);

  Color choose(Color light, Color dark) => isDark ? dark : light;

  @override
  BiliPalette copyWith({Brightness? brightness}) => BiliPalette(brightness ?? this.brightness);

  @override
  BiliPalette lerp(covariant BiliPalette? other, double t) => other == null || t < 0.5 ? this : other;
}
