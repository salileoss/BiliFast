import 'package:flutter/material.dart' show TextTheme;
import 'package:flutter/widgets.dart';

import 'bili_palette.dart';
export 'bili_palette.dart';

/// Colours and sizes sampled from the official app's screenshots (BiliNative `Shared/Theme.swift`), so widgets
/// never carry literals.
abstract final class BiliColors {
  static BiliColorsColors colorsOf(BuildContext context) => BiliColorsColors(BiliPalette.of(context));

  static const pink = Color(0xFFFF6699);
  static const pinkTint = Color(0x1FFF6699);
  static const text = Color(0xFF18191C);
  static const secondaryText = Color(0xFF9499A0);
  static const pageGrey = Color(0xFFF1F2F3);

  /// The fill behind the collection row, tag chips and reply previews on the video page.
  static const softGrey = Color(0xFFF6F7F8);
  static const divider = Color(0xFFE3E5E7);
  static const link = Color(0xFF00699D);
  static const card = Color(0xFFFFFFFF);

  /// The feed's 推荐 reason and 竖屏 tag (01) are orange-red, not the pink accent.
  static const reason = Color(0xFFFF6633);
  static const reasonTint = Color(0xFFFFF1ED);

  /// Counts, durations and progress drawn over covers.
  static const onCover = Color(0xFFFFFFFF);
  static const coverShade = Color(0x80000000);
  static const scrim = Color(0x33000000);
  static const toastFill = Color(0xEB000000);

  /// How dark the layer behind a panel is once it is fully in, as a share of black.
  static const panelShadeOpacity = 0.86;
  static const panelShade = Color(0xDB000000);

  /// Share of black at 0, 35, 70 and 100 per cent of the ramp that leads into a panel; the official app's frames
  /// give a slow start and about 0.74 where the cards begin.
  static const panelFade = <(double, double)>[(0, 0), (0.35, 0.2), (0.7, 0.55), (1, 0.74)];

  /// Over black this lands on the official #212327; over a bright video it lifts a few levels, as theirs does.
  static const panelCard = Color(0xCC2B2C30);
  static const panelText = Color(0xFFFFFFFF);
  static const panelSecondary = Color(0xFF9499A0);

  /// Inside the player's panels, measured on the official app's 05, 06, 20 and 21: hairlines, the off switch track,
  /// the dark sheet's grabber, the switch knob and the highlight under a pressed row.
  static const panelHairline = Color(0xFF484C52);
  static const panelTrackOff = Color(0x0FFFFFFF);
  static const panelGrabber = Color(0x4DFFFFFF);
  static const panelKnob = Color(0xFFFFFFFF);
  static const panelPressed = Color(0x14FFFFFF);

  /// The light 选集 sheet in portrait (19): its grabber, the cross in the grey close circle, and 内容到底啦.
  static const sheetGrabber = Color(0xFFC9CCCF);
  static const sheetCloseGlyph = Color(0xFF61666D);
  static const sheetHint = Color(0xFFC9CCCF);

  /// 19 dims the page below the player behind the 选集 sheet; the player stays undimmed.
  static const sheetDim = Color(0x80000000);

  /// Behind and over the video.
  static const videoBackground = Color(0xFF000000);
  static const onVideo = Color(0xFFFFFFFF);
  static const statsFill = Color(0x8C000000);
  static const statsBorder = Color(0x1FFFFFFF);

  /// The gesture HUD's pills, sampled on 25: a dark grey at 62%, the 倍速中 arrows white at 91% (front) and 59%.
  static const hudFill = Color(0x9E1D1D1D);
  static const hudArrowFront = Color(0xE8FFFFFF);
  static const hudArrowBack = Color(0x96FFFFFF);

  /// The test screen (slice 1): text on the pink button, and what went wrong.
  static const onPink = Color(0xFFFFFFFF);
  static const failure = Color(0xFFF2453D);

  /// The player's controls (BiliNative `ChromeTheme.swift`); the played part is [pink].
  static const chromeTrack = Color(0x33FFFFFF);
  static const chromeBuffered = Color(0x66FFFFFF);
  static const chromeShade = Color(0x73000000);
  static const chromeShadeClear = Color(0x00000000);

  /// The seek bar's plain round handle, in the TV's place while its Lotties aren't there.
  static const thumbHandle = Color(0xFFFFFFFF);

  /// The small player's controls and end screen, and the bar's chapter ticks and 竖屏 style, measured on the official
  /// app's 03, 09, 15 and 26.
  static const chromeTick = Color(0xB3000000);
  static const verticalTrack = Color(0x26FFFFFF);
  static const verticalPlayed = Color(0x99FFFFFF);
  static const verticalThumb = Color(0xFFFFFFFF);

  /// 竖屏's played part, paused and held (118, 19 and 20), is Bilibili's #FB7299, not [pink].
  static const verticalPink = Color(0xFFFB7299);
  static const chapterFill = Color(0x8C000000);
  static const badgeFill = Color(0x40000000);
  static const badgeBorder = Color(0x80FFFFFF);
  static const badgeText = Color(0xFFFFFFFF);

  /// 26's video never gets brighter than 41 of 255 under its dim.
  static const endDim = Color(0xD6000000);

  /// 立即播放 over 26's dimmed frame (about 10 of 255) comes out #535353.
  static const endButton = Color(0x4DFFFFFF);
  static const endCaption = Color(0x99FFFFFF);
  static const endMeta = Color(0x99FFFFFF);
  static const endPlayGlyph = Color(0xF2FFFFFF);
  static const endCoverShade = Color(0x8C000000);

  /// Danmaku outlines: very dark text gets the light one, or it would vanish inside it. 44, at 不透明度 70%, has
  /// its white text at 70% over black and its outlines at 70% black over light pictures: both are drawn opaque and
  /// the layer's opacity fades them together.
  static const danmakuOutline = Color(0xFF000000);
  static const danmakuOutlineLight = Color(0xFFFFFFFF);
  static const danmakuOwnBox = Color(0xFFFFFFFF);

  /// The full-screen controls and end screen (BiliNative `ChromeTheme.swift`, sampled on 04, 09 and 27).
  static const chromeFaint = Color(0x80FFFFFF);
  static const chromeViews = Color(0xD9FFFFFF);
  static const chromeDivider = Color(0x26FFFFFF);
  static const chromeDarkField = Color(0xFF262626);
  static const landscapeEndDim = Color(0x9E000000);
  static const landscapeEndRule = Color(0x12FFFFFF);
  static const landscapeEndPlaceholder = Color(0x38FFFFFF);

  /// The speed test's comparison with the first variant.
  static const faster = Color(0xFF34C759);
  static const slower = Color(0xFFF2453D);

  /// The loading cards' sweep.
  static const shimmerBase = Color(0xFFEDEEF0);
  static const shimmerHighlight = Color(0xFFF8F9FA);

  /// The menus' frosted glass, and the highlight under a pressed row.
  static const glassFill = Color(0xB8FFFFFF);
  static const glassBorder = Color(0x99FFFFFF);
  static const glassShadow = Color(0x26000000);
  static const pressedFill = Color(0x14000000);

  /// The 最近打开 tile runs from this down to [pink], one hue as Swift's `Theme.pink.gradient`.
  static const recentsTileTop = Color(0xFFFF8AB2);

  /// The stats overlay's node dots (iOS system green, orange, red and grey).
  static const nodeHealthy = Color(0xFF34C759);
  static const nodeBlocked = Color(0xFFFF9500);
  static const nodeBanned = Color(0xFFFF3B30);
  static const nodeOther = Color(0xFF8E8E93);
}

/// The app's font, picked in 设置 → 字体 and applied at launch by `FontStore`. MiSans (Xiaomi, free for apps that credit
/// it; see README) is bundled: one font draws all the Chinese, where the Windows fallback mixes Japanese and Chinese
/// fonts. The zh-Hans locale makes any character a font lacks fall back to a Chinese font.
abstract final class BiliFonts {
  static const miSans = 'MiSans';

  /// The system font: SF, with PingFang SC for Chinese, as the official app draws. iOS's engine registers no family by
  /// this name (only CupertinoSystemDisplay, SF's large face), so on the phone it matches nothing and the engine's
  /// default, SF, draws; tests load the SF stand-in under it. Named rather than left null so tests never draw it in the
  /// square test font.
  static const system = 'CupertinoSystemText';

  /// The family every style names.
  static String? family = miSans;

  /// The layout nudges that line MiSans up with the official app's PingFang apply only while MiSans is on.
  static bool get nudged => family == miSans;

  static const locale = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN');

  /// What the system font names after [system]: set only by [settleSystemFallback] at launch, and by tests
  /// (test/flutter_test_config.dart, the PingFang stand-in).
  static List<String>? systemFallback;

  static List<String>? get fallback => family == system ? systemFallback : null;

  /// SF by the family name UIKit gives the system font, which the engine also looks up for the font it draws when a
  /// style's families match nothing.
  static const appleSystem = '.AppleSystemUIFont';

  static const _sfThenPingFang = [appleSystem, 'PingFang SC'];

  /// On iOS, names SF and then PingFang SC after [system]. With no list, the first character SF lacks has iOS pick a
  /// font, and the engine keeps that font for the rest of the line: a reply opening with a katakana name drew the
  /// whole line in a Japanese font, its commas and Chinese included. Since [system] itself matches nothing on iOS, the
  /// first listed family the phone has becomes every run's font, so the list is taken only when [appleSystem] draws
  /// Latin exactly as the unnamed default does; otherwise PingFang SC would draw it all (as Apple Color Emoji drew 1.0.0
  /// (15)'s digits and spaces) and the system font names nothing, as before. Returns whether the list was taken.
  static bool settleSystemFallback() {
    systemFallback = chooseSystemFallback(_latinWidth);
    return systemFallback != null;
  }

  /// SF then PingFang SC when the system font draws Latin as wide with them named as with nothing named, else null.
  @visibleForTesting
  static List<String>? chooseSystemFallback(double Function(List<String>? fallback) latinWidth) =>
      latinWidth(_sfThenPingFang) == latinWidth(null) ? _sfThenPingFang : null;

  static double _latinWidth(List<String>? fallback) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Wi-Fi 1080P 0.5x',
        style: TextStyle(fontFamily: system, fontFamilyFallback: fallback, fontSize: 17),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// Under the system font, the strut a wrapping text whose lines can mix Latin and Chinese needs: each run splits its
  /// line height by its own font's ascent and descent, and SF's split differs from PingFang's, so a line holding both
  /// is a point taller than a Chinese one and its baseline a point lower. PingFang's line for every line keeps the
  /// official app's pitch. Null under MiSans, which draws both scripts.
  static StrutStyle? strut(TextStyle style) => family == system && style.height != null
      ? StrutStyle(
          fontFamily: 'PingFang SC',
          fontSize: style.fontSize,
          height: style.height,
          leadingDistribution: style.leadingDistribution,
          forceStrutHeight: true,
        )
      : null;

  /// [strut] for [style] as a Text under [context] draws it, the inherited default style merged in (most text takes
  /// its height from the Material's body style).
  static StrutStyle? strutOf(BuildContext context, [TextStyle? style]) =>
      strut(DefaultTextStyle.of(context).style.merge(style));

  /// Material's type scale tracks its text 0.1 to 0.5 pt, and every style that doesn't set its own spacing took that
  /// from the page's Material. iOS text isn't tracked; at 3 px per pt the extra 0.75 px leaves Chinese glyphs between
  /// pixels, some drawn crisp and the next blurred thinner, and widens every line.
  static const untracked = TextTheme(
    displayLarge: TextStyle(letterSpacing: 0),
    displayMedium: TextStyle(letterSpacing: 0),
    displaySmall: TextStyle(letterSpacing: 0),
    headlineLarge: TextStyle(letterSpacing: 0),
    headlineMedium: TextStyle(letterSpacing: 0),
    headlineSmall: TextStyle(letterSpacing: 0),
    titleLarge: TextStyle(letterSpacing: 0),
    titleMedium: TextStyle(letterSpacing: 0),
    titleSmall: TextStyle(letterSpacing: 0),
    bodyLarge: TextStyle(letterSpacing: 0),
    bodyMedium: TextStyle(letterSpacing: 0),
    bodySmall: TextStyle(letterSpacing: 0),
    labelLarge: TextStyle(letterSpacing: 0),
    labelMedium: TextStyle(letterSpacing: 0),
    labelSmall: TextStyle(letterSpacing: 0),
  );
}

abstract final class BiliMetrics {
  static const gutter = 12.0;
  static const cardRadius = 6.0;
  static const pillHeight = 30.0;

  /// The test screen (slice 1).
  static const titleText = 17.0;
  static const bodyText = 15.0;
  static const smallText = 12.0;
  static const rowGap = 8.0;
  static const sectionGap = 16.0;
  static const avatarSize = 32.0;
  static const fieldHeight = 40.0;
  static const tagPadding = 6.0;
  static const tagVerticalPadding = 2.0;
  static const iconSize = 18.0;

  /// The video page's player box and its back arrow.
  static const videoAspect = 16 / 9;
  static const videoBackIcon = 20.0;
  static const videoBackShadow = 6.0;

  /// The gesture HUD's pills, measured on 25 (px / 3): 倍速中 is 92 × 44, 10 below the top, centred, with its icon 14
  /// in, and its two overlapping arrows are 28/3 × 12 each before rounding, the second 23/3 right of the first.
  static const hudHeight = 44.0;
  static const hudMinWidth = 92.0;
  static const hudRadius = 8.0;
  static const hudTop = 10.0;
  static const hudPadding = 13.0;
  static const hudSpeedPaddingLeft = 14.0;
  static const hudSpeedPaddingRight = 12.0;
  static const hudGap = 19 / 3;
  static const hudFont = 14.0;

  /// MiSans sits higher in its line than the official app's PingFang; this brings the labels level with 25's.
  static double get hudLabelDrop => BiliFonts.nudged ? 4 / 3 : 0;
  static const hudArrowWidth = 31 / 3;
  static const hudArrowHeight = 41 / 3;
  static const hudArrowStep = 22 / 3;
  static const hudArrowCorner = 3.0;
  static const hudIcon = 18.0;
  static const hudBarWidth = 100.0;
  static const hudBarHeight = 3.0;
  static const hudSeekGap = 4.0;

  /// The small player draws the level pill at its box's height over this, up to full size: 0.8× in the iPhone's
  /// 247.5 pt box, clear of its top and bottom rows; full size in the iPad's and an upright video's taller boxes.
  static const hudInlineLevelFullHeight = 440 / videoAspect / 0.8;

  /// Flutter's Cupertino back swipe starts within this many points of the left edge (its private
  /// `_kBackGestureWidth`), or the left safe-area inset when that is wider.
  static const swipeBackEdge = 20.0;

  /// The player's controls (BiliNative `ChromeTheme.swift`).
  static const chromeButton = 44.0;
  static const chromeIcon = 28.0;
  static const chromeShadeHeight = 70.0;
  static const chromeTimeFont = 12.0;
  static const chromeTimeLeading = 9.0;
  static const chromeTimeTrailing = 10.0;
  static const barHeight = 2.0;
  static const barTouchHeight = 24.0;

  /// The official TV's Lottie box, centred on the bar and on the played part's end (04, 15 and 102: its 15 pt ink and
  /// 12 pt screen land there in each). Without its Lotties, a plain round handle as wide as that screen.
  static const thumbWidth = 18.0;
  static const thumbHeight = 18.0;
  static const thumbHandle = 12.0;
  static const hiddenLine = 2.0;

  /// The small player's controls and end screen, and the bar's chapter title and 竖屏 dot, measured on the official
  /// app's 03, 09, 15 and 26. While dragged, the bar thickens: the TV style's to 4 pt (102), 竖屏's to 6 pt (19 and
  /// 20), where the TV's box grows to 22 pt (its screen 15 × 11.33 pt): from nothing while playing, from [thumbWidth]
  /// while paused.
  static const verticalDot = 4.0;
  static const tvBarDragHeight = 4.0;
  static const verticalBarDragHeight = 6.0;
  static const verticalThumbHeld = 22.0;
  static const chapterTitleFont = 13.0;
  static const chapterTitleHeight = 24.0;
  static const chapterTitlePadding = 8.0;
  static const chapterTitleRadius = 4.0;
  static const chapterTitleGap = 6.0;
  static const chromeEdge = 1.0;

  /// How far the rows slide as they fade, as a share of their height.
  static const chromeRise = 0.3;
  static const chromePressedScale = 0.86;
  static const chromeGlyphStroke = 1.7;
  static const backGlyphWidth = 8.7;
  static const backGlyphHeight = 18.0;
  static const backGlyphStroke = 1.6;
  static const playGlyphWidth = 14.7;
  static const playGlyphHeight = 16.0;
  static const pauseBarWidth = 4.6;
  static const pauseBarGap = 4.4;
  static const playGlyphRounding = 1.4;
  static const fullScreenGap = 2.0;
  static const moreDot = 3.3;
  static const moreDotGap = 3.2;
  static const fullScreenGlyph = 14.0;
  static const cornersGlyphWidth = 13.0;
  static const cornersGlyphHeight = 15.5;
  static const badgeFont = 8.0;
  static const badgeHeight = 11.5;
  static const badgePadding = 2.2;
  static const badgeBorderWidth = 0.7;
  static const badgeOffsetX = 12.0;
  static const badgeOffsetY = -16.0;

  /// An upright video's row ends at 竖屏, with no 全屏 (17): the pill then sits only this far right of the corners,
  /// 6 pt clear of the player's edge.
  static const badgeEdgeOffsetX = 6.0;
  static const endInset = 12.0;
  static const endCaptionFont = 12.0;
  static const endCaptionGap = 3.8;

  /// MiSans draws 推荐视频 higher in its line than PingFang; this brings it level with 26's.
  static double get endCaptionDrop => BiliFonts.nudged ? 0.5 : 0;
  static const endCoverWidth = 128.0;
  static const endCoverHeight = 72.0;
  static const endCoverRadius = 5.0;
  static const endCoverGap = 11.0;
  static const endCoverShadeHeight = 30.0;
  static const endCoverTextInset = 8.7;
  static const endCoverTextBottom = 4.0;
  static const endCoverTimeFont = 10.0;
  static const endPlayGlyphWidth = 18.7;
  static const endPlayGlyphHeight = 22.0;
  static const endTitleFont = 14.0;

  /// The uploader and counts rows sit at fixed heights inside the cover's 72.
  static const endUploaderTop = 40.0;
  static const endCountsTop = 58.0;
  static const endMetaRow = 12.0;
  static const endMetaFont = 10.0;
  static const endCountIconWidth = 13.3;
  static const endCountIconHeight = 11.3;
  static const endMetaGap = 5.0;
  static const endMetaSpacing = 12.3;
  static const endUpWidth = 13.3;
  static const endUpHeight = 11.3;
  static const endUpFont = 7.5;
  static const endUpRadius = 2.5;
  static const endUpBorder = 1.0;
  static const endButtonFont = 14.0;
  static const endButtonWidth = 78.0;
  static const endButtonHeight = 30.0;

  /// MiSans sits higher in its line than the official app's PingFang; this centres 立即播放 in its pill as on 26.
  static double get endButtonTextDrop => BiliFonts.nudged ? 2 : 0;
  static const endButtonTrailing = 12.0;
  static const endActionsLeading = 13.7;
  static const endActionFont = 14.0;
  static const endActionGap = 8.0;
  static const endActionSpacing = 12.0;
  static const replayGlyphWidth = 21.0;
  static const replayGlyphHeight = 18.0;
  static const shareGlyphWidth = 20.0;
  static const shareGlyphHeight = 17.0;

  /// How far the end screen's parts rise as they come in.
  static const endRise = 14.0;

  /// The stats overlay.
  static const statsFont = 10.0;
  static const statsPadding = 6.0;
  static const statsRadius = 6.0;
  static const statsLineGap = 2.0;
  static const statsDot = 5.0;
  static const statsDotGap = 4.0;

  /// The full-screen controls, measured on 04 (landscape, 956 × 440 pt) and 09 (竖屏, 440 × 956 pt) at 3 px per pt.
  static const chromeTopShade = 120.0;
  static const chromeBottomShade = 140.0;
  static const landscapeEdge = 5.0;
  static const chromeTitleText = 16.0;
  static const chromeMoreTop = 20.0;

  /// 点赞 评论 收藏 投币 充电 分享: six 44 pt buttons, each followed by 8 (the last by the 8 before ⋮), and 24 pt
  /// clear of the title: 6 × 52 + 24.
  static const chromeActionsRoom = 336.0;
  static const chromeLineStroke = 1.4;
  static const chromeSideGap = 9.0;
  static const chromeSideLift = 15.0;
  static const chromeCameraWidth = 20.0;
  static const chromeCameraHeight = 17.0;
  static const chromeLockWidth = 21.0;
  static const chromeLockHeight = 20.5;
  static const chromeLockKey = 1.7;
  static const chromeTimeBox = 16.0;
  static const chromeTimeInset = 1.0;
  static const chromeBarTop = 15.0;
  static const chromeRowTop = 3.0;
  static const chromeRowBottom = 1.0;
  static const chromeRowTrailing = 15.0;
  static const chromePlayWidth = 21.5;
  static const chromePlayHeight = 25.0;

  /// 04's triangle sits right of its button's centre by this much.
  static const chromePlayShift = 2.2;
  static const chromePlayCorner = 2.5;
  static const chromePauseBar = 6.0;
  static const chromePauseGap = 5.0;
  static const chromePauseShare = 0.8;
  static const chromeDanmakuWidth = 21.0;
  static const chromeDanmakuHeight = 20.0;
  static const chromeDanmakuText = 10.5;

  /// 04 sets the TV 1 pt further from play than [landscapeEdge]; 09's 竖屏 row has it where it is.
  static const landscapeDanmakuLead = 6.0;

  /// The gaps either side of 弹幕设置's 44 pt button, between the 弹 toggle and the field (04).
  static const chromeSettingsGap = 4.0;
  static const chromeFieldGap = 4.0;

  /// 04's 发个友善的弹幕见证当下: an 80% white capsule over the video, its text a 60% black.
  static const chromeFieldHeight = 30.0;
  static const chromeFieldInset = 8.0;
  static const chromeFieldText = 12.0;
  static const chromeFieldFill = Color(0xCCFFFFFF);
  static const chromeFieldInk = Color(0x99000000);

  /// MiSans sits higher in its line than PingFang; this brings the field's text level with 04's.
  static double get chromeFieldDrop => BiliFonts.nudged ? 2 : 0;
  static const chromeSpeedGap = 14.0;
  static const chromeQualityGap = 23.0;
  static const chromeTextPad = 8.0;
  static const chromeLabelText = 14.0;

  /// The 60帧 or 高码率 tag over 1080P (KaiC's landscape screenshots, 2026-10-23): 11 pt high with 8 pt text, its
  /// middle 15.2 pt above the name's and its right 8.8 pt past it. A tagged name keeps only 2.67 pt each side, so 倍速
  /// sits 15 pt further left than beside 4K.
  static const chromeTaggedPad = 2.67;
  static const chromeTagHeight = 11.0;
  static const chromeTagText = 8.0;
  static const chromeTagPad = 3.5;
  static const chromeTagBorder = 1 / 3;
  static const chromeTagLine = Color(0xCCFFFFFF);
  static const chromeTagTop = chromeButton / 2 - 15.2 - chromeTagHeight / 2;
  static const chromeTagOverhang = 8.8 - chromeTaggedPad;

  /// How far a bar slides in, as a share of its own size.
  static const chromeSlide = 0.4;
  static const verticalTopLift = 8.0;
  static const verticalBackWidth = 9.0;
  static const verticalBackHeight = 16.0;
  static const verticalInfoInset = 12.0;

  /// The action column: 44 pt wide, 6 from the edge, 12 from the title.
  static const verticalColumnRoom = 62.0;
  static const verticalTitleText = 14.0;
  static const verticalTitleLeading = 1.6;
  static const verticalViewsText = 12.0;
  static const verticalViewsGap = 4.0;
  static const verticalChevronGap = 2.0;
  static const verticalChevronWidth = 9.7;
  static const verticalChevronHeight = 5.0;
  static const verticalChevronStroke = 1.0;
  static const verticalChevronTop = 4.4;

  /// The uploader above the title; 粉丝 goes under the name.
  static const verticalAvatar = 36.0;
  static const verticalAvatarRing = 1.0;
  static const verticalAvatarInset = 13.0;
  static const verticalAvatarGap = 10.0;
  static const verticalNameText = 15.0;
  static const verticalUploaderGap = 9.7;

  /// The search suggestion row between the title and the bar.
  static const verticalSearchRoom = 37.0;

  /// 09's bottom row reaches this far into the home indicator's inset.
  static const verticalBottomDrop = 1.0;
  static const verticalRowLift = 4.5;

  /// 118 and 19 draw the bar this much above where the rows put it, at rest and held.
  static const verticalBarLift = 0.5;
  static const verticalFieldHeight = 32.0;
  static const verticalToggleWidth = 50.0;
  static const verticalDividerWidth = 1.0;
  static const verticalDividerHeight = 18.0;
  static const verticalDetailGap = 3.0;
  static const verticalLandscapeGap = 1.0;
  static const verticalCornersWidth = 13.5;
  static const verticalCornersHeight = 15.0;
  static const verticalBadgeX = 9.0;
  static const verticalBadgeY = -18.0;

  /// 竖屏's danmaku start this far under the top row: 118's first lane is centred at 331.5 px.
  static const verticalDanmakuDrop = 1.0;

  /// The full-screen end screen, measured on 27.
  static const landscapeEndRule = 1.0;
  static const landscapeEndRow = 96.0;

  /// The actions' column ends this far into the right safe area.
  static const landscapeEndActionsOutset = 2.0;
  static const landscapeEndActionWidth = 59.0;
  static const landscapeEndActionIcon = 22.0;
  static const landscapeEndActionText = 12.0;
  static const landscapeEndActionTop = 24.4;
  static const landscapeEndActionGap = 11.2;
  static const landscapeEndDividerHeight = 48.0;
  static const landscapeEndDividerGap = 12.5;
  static const landscapeEndAvatar = 60.0;
  static const landscapeEndAvatarRing = 2.0;
  static const landscapeEndAvatarInset = 12.0;
  static const landscapeEndAvatarGap = 12.0;
  static const landscapeEndNameText = 16.0;
  static const landscapeEndInset = 12.0;
  static const landscapeEndHeaderText = 14.0;
  static const landscapeEndHeaderTop = 19.7;
  static const landscapeEndRowTop = 12.0;
  static const landscapeEndCardWidth = 201.0;
  static const landscapeEndCoverHeight = 113.0;
  static const landscapeEndCardGap = 13.0;
  static const landscapeEndCardTitle = 12.0;
  static const landscapeEndCardTitleTop = 8.1;
  static const landscapeEndCardTitleLeading = 1.125;
  static const landscapeEndUploaderText = 10.0;
  static const landscapeEndUploaderTop = 7.4;
  static const landscapeEndCoverInset = 7.0;
  static const landscapeEndCoverBottom = 3.3;
  static const landscapeEndCountText = 11.0;
  static const landscapeEndCountIconWidth = 11.3;
  static const landscapeEndCountIconHeight = 9.1;
  static const landscapeEndCountIconLead = 2.0;
  static const landscapeEndCountIconGap = 1.0;
  static const landscapeEndCountIconRise = 0.8;
  static const landscapeEndCountGap = 3.0;
  static const landscapeEndCountSpacing = 7.0;

  /// How far a related card rises as it fades in.
  static const landscapeEndRise = 24.0;

  /// 首页's feed cards (BiliNative FeedMetrics, measured on 01 at 3 px per point).
  static const feedSpacing = 6.0;

  /// 633 × 475 px on 01, so 4:3, not the 16:10 the spec guessed.
  static const coverAspect = 4 / 3;
  static const cardInset = 8.0;

  /// 01's title lines are 20 pt apart. With the footer the card is 242 pt tall on a 211 pt column, its covers 248 pt
  /// apart.
  static const cardTitleTop = 9.75;
  static const cardTitleLine = 20.0;
  static const cardFooterInset = 9.0;
  static const cardTitleText = 14.0;
  static const cardFooterText = 12.0;
  static const cardTagText = 11.0;
  static const cardTagHeight = 16.0;

  /// The counts over the cover (01, 14), in proportional figures: digits 7.33 pt tall, "94.7万" 28.67 and "405" 16.67
  /// wide, as the system font draws them at 9.67 pt. The play and danmaku icons start [cardStatLead] from the
  /// cover's left edge; a count's ink starts 5.67 after its icon and the next icon 15 after the count's ink, the
  /// digits' side bearings taken off the gaps. Icons and digits are centred [cardStatCentre] above the cover's bottom;
  /// a line centred there draws its digits [cardStatTextDrop] high.
  static const cardStatText = 29 / 3;
  static const cardStatIconWidth = 40 / 3;
  static const cardStatIconHeight = 34 / 3;
  static const cardStatLead = 31 / 3;
  static const cardStatIconGap = 16 / 3;
  static const cardStatGap = 44 / 3;
  static const cardStatTrail = 8.0;
  static const cardStatCentre = 13.0;
  static const cardStatTextDrop = 0.5;
  static const coverShadeHeight = 36.0;
  static const upBadgeHeight = 12.0;
  static const upBadgeText = 8.0;
  static const cardMoreTarget = 24.0;

  /// 01's ⋮ sits this far under the footer's middle, where the tag and the name are.
  static const cardMoreDrop = 1.0;
  static const cardMenuWidth = 168.0;
  static const cardMenuGap = 4.0;
  static const feedSpinnerRadius = 10.0;

  /// The player's panels, measured on the official app's 05, 06, 20 and 21 (956 pt wide, 62 pt safe area at the
  /// right). Fractions are of the screen: widths in landscape, heights of the portrait sheet; the cards end
  /// [panelTrailing] before the safe area.
  static const panelWidth = 0.4;
  static const panelQualityWidth = 0.3;
  static const panelMoreWidth = 0.416;
  static const panelSpeedWidth = 270 / 956;
  static const panelSheetHeight = 0.62;
  static const panelSpeedSheetHeight = 0.32;

  /// Where the dark layer starts to fade in before the cards: a share of the screen width in landscape, points above
  /// the portrait sheet.
  static const panelFadeFraction = 0.18;
  static const panelFadeHeight = 90.0;
  static const panelTop = 16.0;
  static const panelTrailing = 16.0;

  /// Over 21's 21 pt home-indicator inset, so ⋮'s last card ends 28.3 above the bottom.
  static const panelBottom = 7.3;
  static const panelHeaderHeight = 28.0;

  /// The touch box of the small things a finger aims at (back, 高级设置, the sheet's cross); their drawings keep
  /// their own size. A page whose header has one starts [panelHeaderTop] down, so the title stays where it was.
  static const panelHitBox = 44.0;
  static const panelHeaderTop = panelTop - (panelHitBox - panelHeaderHeight) / 2;
  static const panelGap = 8.0;
  static const panelRowRadius = 8.0;
  static const panelGroupRadius = 10.0;
  static const panelCardHeight = 54.0;
  static const panelCardPadX = 16.0;
  static const panelCardPadY = 8.0;
  static const panelSubtitleGap = 1.5;

  /// 05's two-line HDR card sits its text this far above the card's middle.
  static const panelSubtitleLift = 3.2;
  static const panelTitleText = 14.0;
  static const panelDetailText = 12.0;
  static const panelSubtitleText = 10.0;
  static const panelBadgeHeight = 14.0;
  static const panelBadgePad = 4.0;
  static const panelBadgeGap = 10.0;
  static const panelInfoIcon = 16.0;
  static const panelInfoInset = 12.0;
  static const panelChevronWidth = 5.0;
  static const panelChevronHeight = 10.0;
  static const panelChevronGap = 4.7;
  static const panelChevronTrailing = 4.7;

  /// ⋮'s rows: 51 tall, the icon centred 26 in, the label 44 in and the hairline from there.
  static const panelRowHeight = 51.0;
  static const panelRowLead = 16.0;
  static const panelRowIcon = 20.0;
  static const panelRowTrailing = 15.0;
  static const panelLabelInset = 44.0;
  static const panelHairline = 1 / 3;
  static const panelSegmentDivider = 20.0;
  static const panelSegmentPad = 13.0;
  static const panelSwitchWidth = 33.0;
  static const panelSwitchHeight = 20.0;
  static const panelSwitchKnob = 17.5;
  static const panelAutoplayGlyphWidth = 12.6;
  static const panelAutoplayGlyphHeight = 14.0;
  static const panelLoopGlyphWidth = 18.0;
  static const panelLoopGlyphHeight = 16.0;
  static const panelFitGlyph = 13.0;
  static const panelMirrorGlyphWidth = 16.4;
  static const panelMirrorGlyphHeight = 14.0;

  /// ⋮'s top: the squares, their labels, then 定时关闭's title.
  static const panelActionSize = 48.0;
  static const panelActionIcon = 24.0;
  static const panelActionText = 11.0;
  static const panelActionLabel = 14.0;
  static const panelActionGap = 36.0;
  static const panelActionLead = 6.0;

  /// 小窗播放 where picture in picture isn't available.
  static const panelDisabledOpacity = 0.4;
  static const panelSectionGap = 36.0;
  static const panelSectionTitle = 20.0;
  static const panelTitleGap = 12.0;
  static const panelCardGap = 16.0;
  static const panelSpeedRow = 50.0;

  /// 倍速's strip starts 16.5 before its column, which stays centred at 06's x 790.
  static const panelSpeedLead = 16.5;
  static const panelSpeedCell = 40.0;
  static const panelWheelHeight = 150.0;
  static const panelWheelItem = 32.0;
  static const panelButtonHeight = 40.0;

  /// The dark portrait sheet's grabber, and how far (or how fast, in points a second) a drag on it must go before
  /// the sheet lets go.
  static const panelGrabberWidth = 36.0;
  static const panelGrabberHeight = 4.0;
  static const panelGrabberPad = 8.0;
  static const panelDismissDrag = 40.0;
  static const panelDismissVelocity = 700.0;

  /// How far a row slides while it fades in as the panel opens.
  static const panelRevealShift = 18.0;

  /// The light 选集 sheet in portrait (19), whose top meets the player's bottom.
  static const sheetRadius = 12.0;
  static const sheetGrabberWidth = 30.0;
  static const sheetGrabberHeight = 3.0;
  static const sheetGrabberTop = 8.0;
  static const sheetHeaderHeight = 52.0;
  static const sheetTitleText = 16.0;
  static const sheetClose = 24.0;
  static const sheetCloseGlyph = 17.0;
  static const sheetRowHeight = 52.0;

  /// 19's 合集 header and rows, measured from the sheet's top: the intro line, 选集 with 正序, then rows 100.3 apart
  /// (12 above and below a 134.7 × 76 cover, and the hairline) with their text lines placed from the cover's top.
  static const sheetLineHeight = 1.2;
  static const sheetIntroText = 12.0;
  static const sheetIntroTop = 1.8;
  static const sheetIntroTrailing = 146.0;
  static const sheetSectionText = 14.0;
  static const sheetSectionLead = 14.0;
  static const sheetSectionTop = 21.2;
  static const sheetSectionHeight = 29.0;
  static const sheetOrderTrailing = 13.0;
  static const sheetOrderGap = 6.3;
  static const sheetOrderGlyphWidth = 12.5;
  static const sheetOrderGlyphHeight = 11.0;
  static const sheetListTop = 1.0;
  static const sheetRowPad = 12.0;
  static const sheetCoverWidth = 134.7;
  static const sheetCoverHeight = 76.0;
  static const sheetCoverGap = 8.3;
  static const sheetBadgeText = 10.0;
  static const sheetBadgeHeight = 13.6;
  static const sheetBadgePad = 3.8;
  static const sheetBadgeRadius = 1.7;
  static const sheetBadgeInsetX = 3.8;
  static const sheetBadgeInsetY = 4.4;
  static const sheetEpisodeTitleText = 14.0;
  static const sheetEpisodeTitleLine = 20.0;
  static const sheetEpisodeTitleTop = -1.0;
  static const sheetPlayingGlyphWidth = 12.0;
  static const sheetPlayingLead = 1.7;
  static const sheetPlayingDrop = 1.4;
  static const sheetPlayingGlyphHeight = 14.0;
  static const sheetPlayingBar = 2.4;
  static const sheetPlayingGap = 6.5;
  static const sheetMetaText = 12.0;

  /// MiSans digits are narrower than the official PingFang's.
  static double get sheetMetaSpacing => BiliFonts.nudged ? 0.6 : 0;
  static const sheetMetaLine = 16.0;
  static const sheetDateCentre = 51.1;
  static const sheetCountsCentre = 69.7;

  /// MiSans digits sit higher in their line than PingFang's, which centre on the count glyphs.
  static double get sheetCountTextDrop => BiliFonts.nudged ? 1 : 0;
  static const sheetCountGlyphWidth = 13.4;
  static const sheetCountLead = 1.0;
  static const sheetCountGlyphHeight = 11.4;
  static const sheetCountGap = 4.0;
  static const sheetCountSpacing = 12.0;
  static const sheetFooterText = 12.0;
  static const sheetFooterTop = 21.9;
  static const sheetFooterGap = 32.6;

  /// How far a pressed card shrinks.
  static const pressedScale = 0.97;

  /// How far a new card rises while it fades in, as a share of its height.
  static const cardRise = 0.06;

  /// 首页's top row, the menus and the toast.
  static const topRowHeight = 44.0;
  static const topRowMargin = 15.0;
  static const homeAvatar = 38.0;
  static const linkFieldHeight = 34.0;

  /// The system paste control inside the link field, with a little of the field showing above and below it.
  /// The room UIPasteControl asks for at its smallest text size on iOS 27 (logged from KaiC's phone): squeezed
  /// below it, it drops its glyph and turns itself off, a pale empty square in the 34 pt field.
  static const pasteControlWidth = 38.0;
  static const pasteControlHeight = 31.0;
  static const linkFieldIcon = 17.0;
  static const linkClearIcon = 18.0;
  static const tabText = 16.0;
  static const tabIndicatorWidth = 18.0;
  static const tabIndicatorHeight = 3.0;

  /// 首页's tab row (01, 14): from the field row to 推荐's line box, from that line box to the pink bar, and from the bar
  /// to the hairline at 141.67 pt.
  static const tabRowTop = 19 / 3;
  static const tabIndicatorGap = 2 / 3;
  static const tabRowBottom = 8 / 3;
  static const menuRowHeight = 46.0;
  static const menuRadius = 12.0;
  static const menuIconBox = 24.0;
  static const menuIcon = 20.0;
  static const vipBadgeHeight = 16.0;
  static const vipBadgeText = 10.0;
  static const toastRadius = 16.0;
  static const openingPadding = 28.0;
  static const openingSpinner = 32.0;
  static const recentsTile = 40.0;
  static const recentsTileRadius = 10.0;
  static const recentsTileIcon = 26.0;

  /// 设置 and its pages (50): a row with the hairline under it is 130 or 131 px, kept at 130 so every hairline lands on a
  /// whole pixel; the grey between sections is 41 px and the grey values 14 pt. [SettingsTheme] has the rest.
  static const settingsRowHeight = 43 + 1 / 3;
  static const settingsSectionGap = 41 / 3;
  static const settingsValueText = 14.0;
  static const settingsValueWidth = 240.0;
  static const fontRowPadding = 12.0;
  static const fontSampleGap = 4.0;
  static const fontCheck = 20.0;

  /// 竖屏 full screen centres a landscape video at this fraction of the screen's height (screen 09).
  static const verticalVideoCentre = 0.415;

  /// And an upright video here: 16's 3:4 one spans 169.67-756.33 pt, its bottom meeting the uploader row.
  static const verticalUprightCentre = 463 / 956;

  /// The menus' frosted glass.
  static const glassBlur = 24.0;
  static const glassHairline = 0.5;
  static const glassShadowBlur = 24.0;
  static const glassShadowDrop = 8.0;

  /// Danmaku text at an elem's normal fontSize of 25, which other sizes scale. 44's full screen is 22 pt, as in Swift;
  /// the small player's, read off 10 (CJK advances of 37–38 px), is 12.5 pt where Swift had 17: the official app
  /// sizes them about by the player's height (22 × 247.5 / 440).
  static const danmakuFont = 12.5;
  static const danmakuFontFullScreen = 22.0;

  /// 竖屏's danmaku are smaller than landscape's (118: CJK advances of 45.25 px, identical lines 69 px apart), and
  /// run from under the top row over the black above the video, down to the video's bottom.
  static const danmakuFontVertical = 15.0;
  static const danmakuLaneVertical = 23.0;
  static const danmakuOutline = 1.0;
  static const danmakuPad = 1.0;
  static const danmakuOwnPadX = 5.0;
  static const danmakuOwnPadY = 1.5;
  static const danmakuOwnRadius = 3.0;

  /// Lane spacing per point of the font size: 44's lanes are about 95 px apart at 22 pt, as Swift's 1.2 line
  /// heights of the system font are.
  static const danmakuLaneHeight = 1.44;
}

/// The tab row under the player (简介 / 评论 N, the 弹 toggle and 点我发弹幕) and the 简介 page's spacing (03, 18).
abstract final class PageTheme {
  static PageThemeColors colorsOf(BuildContext context) => PageThemeColors(BiliPalette.of(context));

  /// 40 pt from the player's bottom to the hairline's, which the underline covers.
  static const tabRowHeight = 40.0;
  static const hairline = 0.5;
  static const tabText = Color(0xFF61666D);

  /// 简介 and 评论 in 61666D or pink, 评论's count smaller on their baseline (03, 10, 18). The official app's
  /// glyphs are 35 px tall to the system font's 37 at 13.5 (font-check 02).
  static double get tabLabelText => BiliFonts.nudged ? 13.5 : 12.75;
  static const tabCountText = 10.5;
  static const tabCountGap = 3.5;

  /// Off the shared baseline the count sat ⅔ pt low; on 10 its middle is level with 评论's.
  static const tabCountRise = 2 / 3;

  /// Where 简介's label starts, and the room between the labels; each tab's touch area takes half that room.
  static const tabFirstLabel = 33.2;
  static const tabSpacing = 48.6;

  /// The underline: as wide as the tab's label and count, flush with the row's bottom.
  static const underlineHeight = 2.0;
  static const underlineRadius = 1.0;

  /// 点我发弹幕 joined to the 弹 toggle (18), or the toggle alone in a 44 pt capsule (03), 12 pt from the edge.
  static const capsuleHeight = 30.0;
  static const capsuleBorder = 0.7;
  static const danmakuFieldWidth = 97.0;
  static double get danmakuFieldText => BiliFonts.nudged ? 13.5 : 12.75;
  static const danmakuToggleOn = 40.0;
  static const danmakuToggleOff = 44.0;

  /// The 弹 glyph sits 22 pt from the capsule's right end, on or off.
  static const danmakuMarkBox = 44.0;
  static const danmakuMark = 23.0;

  /// The on glyph's tick, in the official pink: everything right of half the glyph and below 58.8% of it.
  static const danmakuTickLeft = 0.5;
  static const danmakuTickTop = 0.588;

  /// Below the related list, above the home indicator.
  static const introBottom = 12.0;

  /// How far the 简介 column rises while it fades in for a new video.
  static const introRise = 8.0;
}

/// The uploader row and the title block, measured on the official app's 03, 18 and 26 at 3 px per point. Each part
/// owns the gap above it and its gutters.
abstract final class IntroTheme {
  static IntroThemeColors colorsOf(BuildContext context) => IntroThemeColors(BiliPalette.of(context));

  /// The avatar starts this far below the tab row's hairline.
  static const uploaderTop = 12.0;
  static const avatar = 30.0;
  static const avatarGap = 12.0;

  /// 大会员 names are [BiliColors.pink]; everyone else's is this grey, lighter than the title (18).
  static const name = Color(0xFF484C52);
  static const nameText = 13.0;
  static const fansText = 10.0;

  /// The extra room PingFang leaves where the counts' digits meet 粉丝 and 视频 (03).
  static const fansHanGap = 1.8;

  /// Where the name's and the counts' lines centre, down from the avatar's top.
  static const nameCentre = 7.8;
  static const fansCentre = 24.8;
  static const nameLine = 16.0;
  static const fansLine = 13.0;

  /// 03's bolt disc sits flush with the avatar's lower right inside a ring of the page's white.
  static const badge = 10.0;
  static const badgeRing = 1.0;
  static const badgePerson = Color(0xFFFFCC00);
  static const badgeOrganisation = Color(0xFF3EA2F4);
  static const badgeBolt = Color(0xFFFFFFFF);

  static const followWidth = 72.0;
  static const followHeight = 24.0;
  static const followText = 13.0;
  static const followPlus = 9.0;
  static const followPlusStroke = 1.2;
  static const followPlusGap = 4.0;
  static const followedFill = BiliColors.pageGrey;
  static const followedText = BiliColors.secondaryText;
  static const followPressedScale = 0.94;

  /// 联合投稿: each member's avatar with the name and the role under it, in a row that scrolls sideways.
  static const staffAvatar = 30.0;
  static const staffWidth = 60.0;
  static const staffSpacing = 16.0;
  static const staffNameText = 11.0;
  static const staffRoleText = 10.0;
  static const staffNameTop = 3.0;
  static const staffLine = 14.0;
  static const staffRoleLine = 13.0;

  /// The title row starts this far below the avatar; its first line centres in [titleRow].
  static const titleTop = 18.0;
  static const titleRow = 22.0;

  /// Under the system font 15.25: the official title's glyphs are 43 px tall to our 45 at 16 (font-check 02).
  static double get titleText => BiliFonts.nudged ? 16 : 15.25;
  static const titleLine = 22.0;
  static const honorText = 12.0;
  static const honorPadding = 8.0;
  static const honorGap = 4.0;
  static const chevronWidth = 12.0;
  static const chevronHeight = 6.0;
  static const chevronStroke = 1.0;
  static const chevronGap = 8.0;

  /// The ⌄'s centre sits this far in from the right edge.
  static const chevronTrailing = 14.0 + chevronWidth / 2;

  /// 03's meta line centres 24.8 below the title row's centre.
  static const metaGap = 5.8;

  /// 03's ▶ starts this far in from the gutter.
  static const metaLead = 1.3;
  static const metaLine = 16.0;
  static const metaText = 12.0;
  static const metaIconGap = 3.8;
  static const metaGroupGap = 8.0;
  static const metaIconWidth = 13.3;
  static const metaIconHeight = 11.3;
  static const onlineIconHeight = 11.7;
  static const metaStroke = 1.0;

  /// Expanded (18): the BV line 18 below the meta line, the description's first line 19.2 below that, 17 between
  /// its lines, and the tags 20.3 below the last line's centre.
  static const bvGap = 2.0;
  static const forbiddenIcon = 12.0;
  static const forbiddenGap = 9.0;
  static const forbiddenTextGap = 4.5;
  static const forbidden = Color(0xFFF85A54);
  static const descGap = 2.7;
  static const descText = 12.0;
  static const descLine = 17.0;
  static const tagsGap = 11.8;
  static const tagHeight = 26.0;
  static const tagText = 12.0;
  static const tagPadding = 13.0;
  static const tagSpacing = 8.0;
  static const tagInk = Color(0xFF61666D);

  /// 18 sets the action icons 30 below the plain tags, more than the action row's own top gap leaves; the tags keep
  /// the rest under them.
  static const tagsBottom = 23 / 3;

  static const expandDuration = Duration(milliseconds: 280);

  /// MiSans's Chinese is about 2% wider than the official PingFang, which in turn spaces digits and Latin letters
  /// away from Chinese; these bring each line to the official width, so the description wraps where 18's does. The
  /// title's two differences cancel out.
  static double get nameSpacing => BiliFonts.nudged ? -0.4 : 0;
  static double get fansSpacing => BiliFonts.nudged ? 0.2 : 0;
  static double get metaSpacing => BiliFonts.nudged ? 0.3 : 0;
  static double get proseSpacing => BiliFonts.nudged ? -0.2 : 0;

  /// MiSans sets the counts half a point higher in their line than PingFang.
  static double get fansDrop => BiliFonts.nudged ? 0.5 : 0;

  /// 个人观点，仅供参考 (font-check 02 and 03): a 16 pt line 2 under the meta line, its ⓘ (a ring 13.33 across) where the
  /// meta line's ▶ is and the text 3.2 after it. Collapsed, the actions sit only 16 lower for it, so the line's last
  /// [noticeHang] hangs below the block; expanded, the BV line keeps its usual gap under the line.
  static const noticeGap = 2.0;
  static const noticeLine = 16.0;
  static const noticeHang = 2.0;
  static const noticeText = 12.0;
  static const noticeIcon = 40 / 3;
  static const noticeIconGap = 3.2;

  /// 03 and font-check 02 draw the action row's coin 7/6 lower than the thumbs, star and arrow beside it; its 三连
  /// ring follows it.
  static const actionCoinDrop = 7 / 6;

  /// iOS sets a tab on its default stops, 28 pt apart, so a description paragraph that opens with one is indented by
  /// 28 (font-check 03).
  static const descTabStop = 28.0;
}

/// 合集, the part strip, the topic and BGM chips and the related rows (03, 18).
abstract final class IntroListTheme {
  static IntroListThemeColors colorsOf(BuildContext context) => IntroListThemeColors(BiliPalette.of(context));

  /// 03 and 18 put the 合集 card, the chips and the related list's first hairline 18 apart, so each section owns
  /// [sectionTop] above it and [sectionBottom] below.
  static const sectionTop = 46 / 3;
  static const sectionBottom = 8 / 3;

  /// The action row ends this far below its count line, which puts the first section's top 45.17 under the icons'
  /// centre, as on 03 and font-check 02 (18 under 不喜欢's ink).
  static const actionsBottom = 0.5;

  /// 合集 (03): a 36 pt card inside the gutters, its title 12 in, then the playing bars, the place and the ›, which
  /// ends 15.7 before the card's edge.
  static const collectionHeight = 36.0;
  static const collectionLead = 12.0;
  static const collectionTrailing = 47 / 3;
  static const collectionTitleText = 14.0;

  /// The official digits are taller and narrower than MiSans's; 13 matches their width.
  static const collectionPlaceText = 13.0;
  static const collectionBarsGap = 7.0;
  static const collectionChevronGap = 6.5;
  static const collectionChevronWidth = 20 / 3;
  static const collectionChevronHeight = 12.0;
  static const chevronStroke = 1.3;

  /// Three round-ended bars 1.72 wide and 4.2 apart, centred on the line: tall, short, tall, as font-check 02 draws
  /// them (11.75, 5.67 and 11). The official mark moves; 03 caught it tall, short, short.
  static const barWidth = 31 / 18;
  static const barStep = 4.2;
  static const barsWidth = barWidth + 2 * barStep;
  static const barsHeight = 11.75;
  static const barShares = <double>[1, 17 / 35.25, 33 / 35.25];

  /// The part strip (no screenshot; the official app's style): 选集 N/M › over 140 × 52 chips with two lines.
  static const partHeaderHeight = 36.0;
  static const partChipWidth = 140.0;
  static const partChipHeight = 52.0;
  static const partChipPad = 10.0;
  static const partChipGap = 8.0;
  static const partChipText = 13.0;
  static const partChipLine = 17.0;
  static const partChipBorder = 1.0;
  static const partPlayingGap = 5.0;

  /// The topic and BGM capsules (03, 18): 26 tall, 8 apart. One takes up to half the row (208 on 18); three share it,
  /// so 03's long two are 133.3 wide, as three long ones would fill it.
  static const chipHeight = 26.0;
  static const chipLead = 10.0;
  static const chipTrailing = 32 / 3;
  static const chipGap = 8.0;
  static const chipText = 12.0;
  static const chipIconGap = 5.5;
  static const chipChevronGap = 4.5;
  static const chipFade = 12.0;
  static const chipChevronWidth = 16 / 3;
  static const chipChevronHeight = 28 / 3;
  static const chipChevronStroke = 1.2;
  static const musicGlyphWidth = 12.1;
  static const musicGlyphHeight = 12.8;
  static const topicGlyphWidth = 13.2;
  static const topicGlyphHeight = 12.9;
  static const topicGlyphStroke = 1.1;

  /// Points a second the name scrolls, the rest before it starts, and the gap before it comes round again.
  static const marqueeSpeed = 30.0;
  static const marqueeRest = Duration(milliseconds: 1500);
  static const marqueeGap = 24.0;

  static const chipTextColor = Color(0xFF61666D);
  static const chipGlyphColor = Color(0xFF656668);

  /// A related row (03, 18): 92 apart, a 128 × 72 cover 10.33 below the hairline, the text 8 right of it.
  static const relatedRowHeight = 92.0;
  static const relatedCoverTop = 31 / 3;
  static const relatedCoverWidth = 128.0;
  static const relatedCoverHeight = 72.0;
  static const relatedCoverRadius = 4.0;
  static const relatedTextGap = 8.0;
  static const relatedTitleText = 14.0;
  static const relatedTitleLine = 17.0;

  /// The title's line box starts this far above the cover's top, which puts its ink 1 pt below it.
  static const relatedTitleLift = 1.0;

  /// The UP line's and the counts' centres, below the cover's top.
  static const relatedUploaderCentre = 46.5;
  static const relatedCountsCentre = 191 / 3;
  static const relatedMetaText = 12.0;
  static const relatedMetaLine = 16.0;
  static const relatedMetaGap = 3.5;

  /// The UP badge and the count icons start 2.33 right of the title.
  static const relatedMetaLead = 7 / 3;
  static const relatedCountSpacing = 12.0;

  /// Between rows the hairline starts 10 in; the first runs the full width.
  static const relatedDividerInset = 10.0;

  /// The duration's dark tag, 4 in from the cover's corner.
  static const durationHeight = 16.0;
  static const durationPad = 4.0;
  static const durationRadius = 1.8;
  static const durationInset = 4.0;
  static const durationText = 10.5;
  static const durationFill = Color(0x8C000000);

  /// ⋮: three 2.67 dots 1.33 apart, their column centred 20 from the right edge on the counts' line.
  static const moreDot = 8 / 3;
  static const moreDotGap = 4 / 3;
  static const moreCentreFromRight = 20.0;
  static const moreTarget = 36.0;

  /// The rows that are there when the list arrives come in one after another.
  static const revealStagger = Duration(milliseconds: 35);
  static const revealDuration = Duration(milliseconds: 320);
  static const revealRows = 8;
  static const revealRise = 8.0;
}

/// The action row under the title, the 三连 rings and the coin dialog (03, 15).
abstract final class ActionTheme {
  static ActionThemeColors colorsOf(BuildContext context) => ActionThemeColors(BiliPalette.of(context));

  /// The solid glyphs' cut-out lines (投币's 币): 4.5 px on font-check 02, as landscape's outlines.
  static const cutStroke = 1.5;

  /// 03's icons are #61666D and their counts the page's grey; on, both turn [BiliColors.pink], except 不喜欢's name,
  /// which stays grey under its pink thumb (88, 89).
  static const icon = Color(0xFF61666D);
  static const count = BiliColors.secondaryText;

  /// From 03 (px / 3): the icons' ink starts 23.7 pt under the meta line's and spans 20 pt (a 24 pt icon), the counts'
  /// digits are centred 22.7 pt under the icons'. [rowHeight] ends at the bottom of the count line; 简介 adds
  /// [IntroListTheme.actionsBottom] under it.
  static const topGap = 19.0;
  static const iconSize = 24.0;
  static const countGap = 10 / 3;
  static const countLine = 14.0;

  /// The official app's 10 pt; MiSans draws its digits taller, so they come out about half a point over 03's.
  static const countFont = 10.0;
  static const rowHeight = topGap + iconSize + countGap + countLine;
  static const popScale = 1.24;

  /// The 三连 ring round 点赞, 投币 and 收藏, clear of the counts, and the burst of eight dots when it fires.
  static const ring = 32.0;
  static const ringWidth = 2.0;
  static const burstDot = 4.0;
  static const burstSpread = 1.6;

  /// The coin dialog (15): white over the page dimmed to 40%, the hint and the ✕ at 60% and 50%.
  static const coinDim = Color(0x99000000);
  static const coinText = Color(0xFFFFFFFF);
  static const coinHint = Color(0x99FFFFFF);
  static const coinClose = Color(0x80FFFFFF);
  static const coinUnaffordable = Color(0x66000000);

  /// The crate art has a shadow round it: drawn 84 and 100 pt, its boxes show 72 and 86 pt, 114 pt apart and centred
  /// at 49.8% of the height. The coin art is 56% of the crate art and sits a little low. The arrows' centres are 22 pt
  /// in from the edges.
  static const crate = 84.0;
  static const selectedCrate = 100.0;
  static const crateSpacing = 114.0;
  static const coinArt = 0.56;
  static const coinArtDrop = 0.017;
  static const cratesCentre = 0.498;
  static const arrowWidth = 15.6;
  static const arrowHeight = 30.0;
  static const arrowCentreInset = 22.0;

  /// 22娘's art is 150 pt tall, 34 pt under the crate art; the two lines under her are 18 pt apart, the first centred
  /// 17 pt under her art.
  static const mascotGap = 34.0;
  static const mascotHeight = 150.0;
  static const mascotAspect = 321 / 447;
  static const hintGap = 8.0;
  static const hintLine = 18.0;
  static const hintFont = 13.0;

  /// The bottom row is centred 30 pt above the safe area: ☐ 同时点赞内容 17 pt in, ✕ 30 pt, 如何获取硬币？ 13 pt in.
  static const bottomLift = 30.0;
  static const bottomRow = 44.0;
  static const bottomInset = 17.0;
  static const bottomEndInset = 13.0;
  static const bottomFont = 12.0;
  static const checkbox = 14.0;
  static const checkboxLine = 1.0;
  static const checkboxTick = 1.4;
  static const checkboxRadius = 2.0;
  static const checkboxGap = 5.0;
  static const close = 30.0;
  static const closeRing = 1.0;
  static const closeCross = 1.3;
  static const closeCrossHalf = 4.3;

  /// Landscape lays the portrait column out 440 pt wide, scaled down to fit the height.
  static const landscapeColumn = 440.0;

  /// The lightning frames are 1080 px wide round a 225 px crate; the first one's crate is 27.5 px below its centre.
  static const thunderWidth = 1080 / 225;
  static const thunderFirstDrop = 27.5 / 225;
}

/// The favourites sheet and panel, and the unfollow confirm.
abstract final class FavouriteTheme {
  static FavouriteThemeColors colorsOf(BuildContext context) => FavouriteThemeColors(BiliPalette.of(context));

  /// Over the whole page, player included (BiliNative `Theme.Favourites.dim`).
  static const dim = Color(0x66000000);
  static const rowHeight = 56.0;
  static const newRowHeight = 48.0;
  static const titleText = 15.0;
  static const countText = 12.0;
  static const countGap = 3.0;
  static const lockIcon = 12.0;
  static const plusIcon = 18.0;
  static const plusGap = 6.0;

  /// The tick circle: an empty ring, or pink with a white tick drawn in.
  static const check = 21.0;
  static const checkStroke = 1.2;
  static const tickStroke = 1.8;
  static const ringLight = Color(0xFFC9CCCF);
  static const ringDark = Color(0x66FFFFFF);
  static const tick = Color(0xFFFFFFFF);
  static const doneHeight = 40.0;
  static const doneText = 15.0;
  static const doneTop = 12.0;

  /// 新建收藏夹's form; Bilibili refuses names longer than [maxTitle].
  static const maxTitle = 20;
  static const fieldHeight = 38.0;
  static const fieldPad = 12.0;
  static const formGap = 10.0;
  static const formButtonHeight = 32.0;
  static const formButtonPad = 10.0;
  static const formSpinnerRadius = 7.0;
  static const darkField = Color(0x1AFFFFFF);
  static const switchOffLight = Color(0xFFE3E5E7);
  static const knobShadow = Color(0x33000000);
  static const knobShadowBlur = 2.0;

  /// Loading and failure inside the list, and 重试.
  static const statePad = 32.0;
  static const stateText = 13.0;
  static const spinnerRadius = 10.0;
  static const retryHeight = 30.0;
  static const retryPad = 18.0;
  static const retryBorder = 0.8;

  /// The unfollow confirm, an iOS-sized alert in the official app's light style.
  static const alertWidth = 280.0;
  static const alertRadius = 12.0;
  static const alertTitleText = 16.0;
  static const alertTitlePadTop = 26.0;
  static const alertTitlePadBottom = 22.0;
  static const alertButtonHeight = 48.0;
  static const alertButtonText = 16.0;
  static const alertDim = Color(0x80000000);

  /// The alert settles from this, slightly large, to its size as it fades in.
  static const alertStartScale = 1.08;
}

/// Landscape's top actions, uploader and 关注 (04, 05), the bgm row, ⏭ and 选集 on the bottom row (05), and its end
/// screen's actions (27), measured at 3 px per pt.
abstract final class LandscapeActionTheme {
  /// The glyphs' ink is 20 pt on both screens, 0.84 of the icon's box.
  static const iconSize = 24.0;

  /// After each 44 pt button, the last one's before ⋮.
  static const buttonGap = 8.0;

  /// 04 and 05 draw the outlines and the 币 4.5 px (1.5 pt) wide, as 简介 cuts its 币 ([ActionTheme.cutStroke]).
  static const outline = 1.5;

  /// 05's 👍, 💬 and ⭐ are shorter than the outlines 简介 shares (19.7, 19.4 and 18.7 pt of ink against 20.2, 19.9
  /// and 19.7), their widths the same, and 👍 and ⭐ sit higher: each is squeezed upright about its button's centre,
  /// then lifted.
  static const likeSquash = 0.975;
  static const likeLift = 1.14;
  static const commentSquash = 0.973;
  static const favouriteSquash = 0.945;
  static const favouriteLift = 0.8;

  /// The title starts where N人正在看's icon under it does (04, 05), clear of back's 44 pt target.
  static const titleInset = onlineInset;

  /// The superscript count: its left edge this far right of its button's centre, its digits standing on a baseline
  /// 12 pt into the button (32 pt down on 04 and 05, in either font), in proportional figures as 05's 1127 is.
  static const countText = 9.5;
  static const countLead = 6.7;
  static const countBaseline = 12.0;

  /// N人正在看 under the title, centred 64.8 pt down: the icon 4.7 pt right of the back button.
  static const onlineTop = 56.8;
  static const onlineHeight = 16.0;
  static const onlineInset = 4.7;
  static const onlineIconWidth = 13.0;
  static const onlineIconHeight = 11.0;
  static const onlineIconStroke = 0.85;
  static const onlineGap = 5.5;
  static const onlineText = 12.0;
  static const online = Color(0x99FFFFFF);

  /// 25's faint N人正在看 at the bottom left while the controls are hidden (27 keeps it under the end screen's dim):
  /// the glyph 33.3 pt past the left inset, the line centred 9.7 pt above the screen's edge, inside the home
  /// indicator's band rather than above it.
  static const cornerInset = 33.3;
  static const cornerCentre = 9.7;
  static const cornerHeight = 12.0;
  static const cornerIconWidth = 9.0;
  static const cornerIconHeight = 7.6;
  static const cornerIconStroke = 0.7;
  static const cornerGap = 4.9;
  static const cornerText = 9.0;
  static const corner = Color(0x59FFFFFF);

  /// Under the end screen's dim 27 shows the corner at about 22% white where the dim alone leaves 38%.
  static const cornerUnderEndOpacity = 0.58;

  /// The uploader's avatar and + 关注 on the line below, centred 93 pt down.
  static const uploaderHeight = 40.4;
  static const avatar = 24.0;
  static const avatarInset = 12.0;
  static const avatarGap = 7.7;
  static const plus = 10.7;
  static const plusStroke = 0.8;
  static const plusGap = 4.7;
  static const followText = 12.5;
  static const followed = Color(0x99FFFFFF);

  /// 05's uploader chip: a 15% black capsule 26 pt tall on the uploader's line, its left end 1 pt outside the avatar,
  /// holding the avatar, the name 8 pt on (12.5 pt, as 关注), a 0.67 × 12 pt half-white divider 8.6 pt either side,
  /// then + 关注, which ends 16 pt before the capsule does (05 and 34 alike). Text stands on a baseline 4.67 pt below
  /// the capsule's centre, which 'der' and 'Takes' share.
  static const chipHeight = 26.0;
  static const chipFill = Color(0x26000000);
  static const chipInset = 1.0;
  static const chipBaselineDrop = 4.67;
  static const nameGap = 8.0;
  static const dividerGap = 8.6;
  static const dividerWidth = 0.67;
  static const dividerHeight = 12.0;
  static const divider = Color(0x80FFFFFF);
  static const followTrailing = 16.0;

  /// 05's bgm row, 发现《…》 in its own chip 8 pt under the uploader's (centred 127 pt down): two beamed quavers 6.67
  /// pt in, the name 8.75 pt after them and the chip's end 9 pt after the name. Its left end is over the black bar
  /// beside the video on 05, so it is taken to line up with the uploader's chip.
  static const chipGap = 8.0;
  static const musicLead = 6.67;
  static const musicGlyphWidth = 13.67;
  static const musicGlyphHeight = 14.33;
  static const musicGap = 8.75;
  static const musicTrailing = 9.0;

  /// 05's ⏭: a rounded triangle against a bar in a 16.9 × 16.67 box, centred 1 pt right of its 44 pt button, which
  /// follows ▶ with the 6 pt the 弹 toggle keeps, the toggle 6 pt after it in turn. 34 greys it to half white when
  /// nothing plays next.
  static const nextWidth = 16.9;
  static const nextHeight = 16.67;
  static const nextShift = 1.0;
  static const nextTip = 14.67;
  static const nextBar = 4.2;
  static const nextCorner = 1.5;
  static const nextOffOpacity = 0.5;

  /// 选集 before 倍速 (05, 34): their labels' centres 62 pt apart, so 17.67 pt between their buttons.
  static const episodesGap = 17.67;

  /// 27's 充电 and 关注 pills under the uploader's name, level with the avatar's bottom.
  static const pillWidth = 88.0;
  static const pillHeight = 30.0;
  static const pillGap = 8.0;
  static const pillBorder = 1.0;
  static const pillText = 14.0;
  static const boltWidth = 7.2;
  static const boltHeight = 11.6;
  static const boltGap = 7.6;

  /// Padding before the bolt and 充电, which 27 sets half this right of its pill's centre.
  static const chargeShift = 4.0;
  static const pillPlus = 9.0;
  static const pillPlusStroke = 1.2;
  static const pillPlusGap = 5.0;

  /// 已关注's pill, as BiliNative's end screen draws it.
  static const followedPill = Color(0x38FFFFFF);

  /// How far an action's icon swells as it turns on.
  static const pop = 1.28;
}

/// The status bar landscape full screen draws while iOS's is hidden (04, 05, 34), from the screen's top edge. Text is
/// placed by its baseline, where digits and capitals stand in any font.
abstract final class LandscapeStatusTheme {
  /// The clock: 12 pt regular, centred on the screen, on a baseline 14.33 pt down.
  static const timeText = 12.0;
  static const timeBaseline = 14.33;

  /// WIFI and the percentage: 10 pt regular on a baseline 13.67 pt down.
  static const smallText = 10.0;
  static const smallBaseline = 13.67;

  /// Everything on the right is centred 10 pt down; the battery's cap ends 11 pt inside the right safe inset.
  static const centre = 10.0;
  static const trailing = 11.0;

  /// WIFI's 33 × 14 capsule, outlined 1 pt in 30% white, 8 pt before the percentage.
  static const capsuleWidth = 33.0;
  static const capsuleHeight = 14.0;
  static const capsuleStroke = 1.0;
  static const capsuleOutline = Color(0x4DFFFFFF);
  static const capsuleGap = 8.0;

  /// The percentage ends this far before the battery.
  static const batteryGap = 3.75;

  /// The battery: a 19 × 10 body outlined 0.45 pt in white with 2 pt corners, and a 1 × 4 cap. The level fills it
  /// 1.5 pt inside the outline, 16 pt when full, with 1 pt corners: white (04), or 05's green under a white bolt
  /// while charging.
  static const batteryWidth = 19.0;
  static const batteryHeight = 10.0;
  static const batteryStroke = 0.45;
  static const batteryCorner = 2.0;
  static const capWidth = 1.0;
  static const capHeight = 4.0;
  static const fillInset = 1.5;
  static const fillCorner = 1.0;
  static const charging = Color(0xFF9EDEA2);
}

/// 竖屏's action column, uploader, 粉丝, 关注 and 发弹幕 (09), and the 选集 sheet's share circle and 收藏 (19).
abstract final class VerticalActionTheme {
  /// 发弹幕, 已关闭弹幕 (35) or UP主已关闭弹幕 in the bottom row's dark field (09).
  static const fieldInset = 14.6;
  static const fieldText = 12.0;
  static const fieldInk = Color(0xFF939393);
  static double get fieldDrop => BiliFonts.nudged ? 1.8 : 0;

  /// 09's column: 44 wide, centred 27 in from the right edge, items 69 apart with the icon centre 27.5 above its
  /// count's; the last count's line ends 62.5 above the bottom row's bottom, about where the bar's touch starts.
  static const columnWidth = 44.0;
  static const columnTrailing = 5.0;
  static const columnLift = 62.5;
  static const itemSpacing = 17.5;
  static const iconBox = 32.0;
  static const countGap = 3.5;
  static const countLine = 16.0;
  static const countText = 13.0;

  /// [ActionIcon] sizes that draw 09's glyphs at their measured size (30, 30, 32, 29.3 and 30 × 24.3).
  static const likeIcon = 36.0;
  static const commentIcon = 35.0;
  static const coinIcon = 38.0;
  static const favouriteIcon = 32.0;
  static const shareIcon = 34.0;

  /// The icons are a 90% white; the counts full white.
  static const icon = Color(0xE6FFFFFF);
  static const count = Color(0xFFFFFFFF);

  /// How far a glyph swells as it turns pink.
  static const popScale = 1.3;

  /// The name's and 粉丝's lines beside the 36 pt avatar, centred 10.5 and 28.5 below its top.
  static const nameLine = 21.0;
  static const fansLine = 15.0;
  static const fansText = 11.5;
  static const fans = Color(0xE6FFFFFF);

  /// MiSans sits higher in its line than the official app's PingFang; these bring the name and 粉丝 level with 09's.
  static double get nameDrop => BiliFonts.nudged ? 1.7 : 0;
  static double get fansDrop => BiliFonts.nudged ? 1 : 0;

  /// + 关注: 60 × 24 on 09, 8.7 after the name.
  static const followGap = 8.7;
  static const followHeight = 24.0;
  static const followLead = 11.5;
  static const followTrailing = 10.0;
  static const followText = 13.0;
  static double get followTextDrop => BiliFonts.nudged ? 1 : 0;
  static const followPlus = 9.0;
  static const followPlusStroke = 1.3;
  static const followPlusGap = 5.0;
  static const followingFill = Color(0x33FFFFFF);
  static const followingText = Color(0xB3FFFFFF);

  /// The viewers mark and 479人正在看 after the back arrow, a 40% white.
  static const online = Color(0x66FFFFFF);
  static const onlineLead = 8.3;
  static const onlineIconWidth = 11.3;
  static const onlineIconHeight = 10.0;
  static const onlineIconStroke = 1.1;
  static const onlineGap = 5.6;
  static const onlineText = 12.0;

  /// 19's share circle and 收藏 at the right of the 合集 description, centred 5 above its first line: a 24 pt grey
  /// circle, 12 before a 71 × 24 pill, 12 from the edge. The list starts [sheetLift] into the header's empty bottom,
  /// so the two clear its clip, which cuts their tops on 19.
  static const sheetLift = 8.0;
  static const sheetShare = 24.0;
  static const sheetShareGlyph = 15.0;
  static const sheetGap = 12.0;
  static const sheetPillHeight = 24.0;
  static const sheetPillPad = 15.0;
  static const sheetStar = 13.0;
  static const sheetStarGap = 2.5;
  static const sheetPillText = 13.0;

  /// MiSans sits higher in its line than PingFang; this centres 收藏 in its pill as on 19.
  static double get sheetPillTextDrop => BiliFonts.nudged ? 1.5 : 0;
  static const sheetPill = Color(0xFFED7098);
  static const sheetPillLabel = Color(0xFFFFFFFF);
  static const sheetSubscribedFill = BiliColors.pageGrey;
  static const sheetSubscribedLabel = BiliColors.secondaryText;

  /// The playing episode's title and bars in the light 选集 sheet: 19 draws them in 收藏's pink, not the app's.
  static const sheetPlaying = sheetPill;

  /// Paused, 118's ▶ (the APK's `bili_player_play`, drawn at its file's 3× size) hangs from
  /// [BiliMetrics.verticalVideoCentre] whatever the video's shape (16), at a quarter of its white, with the time
  /// [pausedTimeTop] below the picture's top in 16 pt white over a shade.
  static const pausedPlayAsset = 'assets/images/player/paused_play.png';
  static const pausedPlayWidth = 80.0;
  static const pausedPlayHeight = 77.0;
  static const pausedPlayOpacity = 0.25;
  static const pausedTimeText = 16.0;
  static const pausedTimeTop = 272 / 3;
  static const pausedTimeShadowBlur = 3.0;

  /// An upright video's last bottom button (16): the APK's `bili_story_ctrl_normal`, an upright phone beside half a
  /// landscape screen, at its own 24 pt in place of 横屏全屏's corners.
  static const screenModeAsset = 'assets/images/player/screen_mode_normal.png';
  static const screenModeGlyph = 24.0;

  /// 118's 合集 line in place of the plain title: the layers glyph, 合集 · 第N集 in semibold, a 1 × 10 pt bar, then
  /// the title. The glyph's 12 pt box starts 2.3 into the title's inset; its three layers are 1.3 pt lines. The dot
  /// is a 2 pt one centred in 50 px between 合集 and 第N集.
  static const collectionGlyph = 12.0;
  static const collectionGlyphLead = 2.3;
  static const collectionGlyphGap = 6.33;
  static const collectionGlyphStroke = 1.3;
  static const collectionDotRoom = 50 / 3;
  static const collectionDot = 2.0;
  static const collectionBarWidth = 1.0;
  static const collectionBarHeight = 10.0;
  static const collectionBarLead = 25 / 3;
  static const collectionBarTrail = 20 / 3;
}

/// A comment row and its badges (10, 12, 13), measured at 3× on KaiC's phone. Heights count down from the row's top,
/// which is the hairline above it.
abstract final class CommentRowTheme {
  static CommentRowThemeColors colorsOf(BuildContext context) => CommentRowThemeColors(BiliPalette.of(context));

  static const gutter = BiliMetrics.gutter;

  /// The name and the text start here; the avatar sits in the gutter before it.
  static const textLeading = 56.0;
  static const avatarTop = 62 / 3;
  static const avatar = 30.0;

  /// Under a pendant the face shrinks to 24 and the frame is 1.75 times that, centred on the same point.
  static const pendantAvatar = 24.0;
  static const pendantScale = 1.75;

  /// 大会员's pink 大: 10 across, 5/3 in from the avatar's right and 2 up from its bottom, in a ring of white.
  static const vipMark = 10.0;
  static const vipMarkRing = 1.0;
  static const vipMarkRight = 5 / 3;
  static const vipMarkBottom = 2.0;
  static const vipMarkText = 7.0;
  static const vipMarkFill = BiliColors.pink;
  static const vipMarkInk = Color(0xFFFFFFFF);
  static const vipMarkRim = Color(0xFFFFFFFF);

  /// The name and the LV badge centre 28.8-30 down on 10 and 13, lower in the first row under a header than in the
  /// rows after it; 29.5 is within 0.7 of each.
  static const nameCentre = 29.5;

  /// Short enough to end above the text's line at [textTop].
  static const nameLine = 16.0;
  static const nameText = 13.0;
  static const name = BiliColors.secondaryText;
  static const vipName = Color(0xFFFB7299);
  static const badgeGap = 5.0;
  static const upGap = 4.0;

  /// LV0 to LV6, 56 × 28 px: the LV block 1 pt shorter than the digit's. LV5 and LV6 are the fills' mode on 10 and
  /// 13, the rest follow Bilibili's level colours.
  static const levelWidth = 56 / 3;
  static const levelHeight = 28 / 3;
  static const levels = [
    Color(0xFFC0C4CC),
    Color(0xFFC0C4CC),
    Color(0xFF8BD29B),
    Color(0xFF7BCDEF),
    Color(0xFFFEBB8B),
    Color(0xFFDF6729),
    Color(0xFFE3524E),
  ];
  static const levelInk = Color(0xFFFFFFFF);
  static const upFill = BiliColors.pink;
  static const upInk = Color(0xFFFFFFFF);
  static const upText = 8.0;
  static const upPadding = 3.0;
  static const upRadius = 2.0;

  /// 置顶 before a pinned comment's text.
  static const pinnedText = 11.0;
  static const pinnedInk = BiliColors.pink;
  static const pinnedBorder = 0.8;
  static const pinnedRadius = 3.0;
  static const pinnedPadding = 4.0;

  /// The text's first line is centred 50.2 down. 12 sets lines 24.3 apart, but Flutter rounds a line's height to
  /// whole points, so ours are 24, which leaves 13's three-line reply within a point of its meta line. A single
  /// line still leaves the pictures or the meta line [textMinBottom] down, as 13's 没人看的 does; longer text pushes
  /// them on without a gap.
  static const textFirstCentre = 50.2;
  static const textLine = 24.0;
  static const textText = 15.0;
  static const textMinBottom = 200 / 3;
  static const text = BiliColors.text;

  /// Under the system font PingFang's glyphs sit higher in their line than MiSans's, so the text starts 1.8 lower:
  /// the official app centres it 22 below the name in the list (differences 12) and 21.1-21.3 in a thread
  /// (font-check 04), where ours sat 20.2; 1.4 lower lands within half a point of both.
  static double get textTop => textFirstCentre - textLine / 2 + (BiliFonts.nudged ? 0 : 1.4);

  /// One picture: a tall one 162 wide, cut at 3:4, a wide one 240; 135 and 200 in 评论详情 (13). Long pictures show
  /// their top.
  static const pictureTall = 162.0;
  static const pictureWide = 240.0;
  static const threadPictureTall = 135.0;
  static const threadPictureWide = 200.0;
  static const tallestRatio = 4 / 3;
  static const flattestRatio = 9 / 16;
  static const pictureRadius = 4.0;
  static const pictureSpacing = 4.0;
  static const picturePlaceholder = BiliColors.pageGrey;

  /// The meta line centres 16 below a picture's bottom: ⋮'s middle dot does on font-check 04, 10 and 13.
  static const pictureGap = 4.0;

  /// The meta line: time and place, 回复 8 after them, 👍 N with the count's box ending 73 from the right edge (its ink
  /// 73.7, as on 10), 👎 centred 49 from it and ⋮ 17.
  static const metaHeight = 24.0;
  static const metaText = 12.0;
  static const meta = Color(0xFFC9CCD0);
  static const action = Color(0xFF61666D);
  static const liked = BiliColors.pink;
  static const replyGap = 8.0;
  static const replyTrailing = 10.0;
  static const likeTrailing = 73.0;
  static const thumbInk = 14.0;

  /// 👍 is drawn above the line's centre: its ink centres 2 px above ⋮'s middle dot and the count on font-check 04,
  /// 10 and 13 (15.2 below a picture's bottom).
  static const thumbLift = 2 / 3;

  /// 👎 sits 4 px lower than 👍.
  static const dislikeDrop = 4 / 3;
  static const thumbCountGap = 17 / 3;

  /// The widest count, 999.9万.
  static const countRoom = 48.0;
  static const dislikeCentre = 49.0;
  static const moreCentre = 17.0;

  /// ⋮'s dots are 6.4 px across (each one's ink area on font-check 04 and 13) and 13 px apart.
  static const moreDot = 6.4 / 3;
  static const morePitch = 13 / 3;
  static const likeTarget = 6.0;
  static const dislikeTarget = 32.0;
  static const moreTarget = 30.0;
  static const likePop = 1.3;
  static const likePopDuration = Duration(milliseconds: 320);

  /// UP主觉得很赞 under the meta line.
  static const upLikedHeight = 18.0;
  static const upLikedIcon = 12.0;
  static const upLikedGap = 3.0;
  static const upLiked = BiliColors.secondaryText;

  /// 评论详情 draws UP主觉得很赞 as a box instead (font-check 04, under the root and under a reply): no thumb, #757575
  /// in #F4F4F4, 16 tall and 2 round, its top 22 below the meta text's centre and its bottom 8 above the band or the
  /// reply's hairline. The glyphs are 10 pt tall but 31.25 px apart, wider than PingFang's em as iOS tracks small
  /// text, which makes the box 75 wide.
  static double get upChipTop => 22 - metaTextRise - metaHeight / 2;
  static const upChipHeight = 16.0;
  static const upChipBottom = 8.0;
  static const upChipText = 10.0;
  static const upChipSpacing = 0.4;
  static const upChipPadding = 13 / 3;
  static const upChipRadius = 2.0;
  static const upChipFill = Color(0xFFF4F4F4);
  static const upChipInk = Color(0xFF757575);

  static TextStyle get upChipStyle => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: upChipText,
    height: upChipHeight / upChipText,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: upChipSpacing,
    color: upChipInk,
  );

  /// The replies box: 19.8 below the meta text's centre on 10, which is 21.2 below the meta line's (1.75 less under
  /// the system font, whose meta text sits higher); 54 from the left and 12 from the right, 8 round.
  static double get boxGap => 127 / 6 - metaHeight / 2 - (BiliFonts.nudged ? 0 : 1.75);
  static const boxLeading = 54.0;
  static const boxRadius = 8.0;
  static const box = BiliColors.softGrey;
  static const boxPadding = 10.0;

  /// A preview's lines are 23.33 apart on 12 and the thread shot, which Flutter rounds to 23; the first is centred
  /// 16.67 down. Previews follow each other with no gap, so the next one's first line is 18.75 below the last one's
  /// last line, closer than two lines of one preview.
  static const previewTop = 16.67 - previewLine / 2;
  static const previewLine = 23.0;
  static const previewText = 13.0;
  static const previewOverlap = previewLine - 18.75;

  /// A preview cut short with "…" stands 7 taller below its last line (12), one that ends on its own doesn't (the
  /// thread shot).
  static const previewCutGrowth = 7.0;
  static const preview = Color(0xFF2F3238);
  static const previewName = BiliColors.secondaryText;
  static const previewRuleGap = 7.0;
  static const previewRuleWidth = 1.0;
  static const previewRuleHeight = 10.0;
  /// 共N条回复 centres in a 36 pt slot at the bottom, 26 below a preview's last line that ends on its own.
  static const moreSlot = 36.0;
  static const moreSlotOverlap = previewLine / 2 + moreSlot / 2 - 26;
  static const moreText = 12.0;
  static const moreLink = BiliColors.link;
  static const chevronGap = 7.0;
  static const chevronWidth = 14 / 3;
  static const chevronHeight = 28 / 3;
  static const chevronStroke = 1.0;

  /// The hairline under a row, 2 px of [BiliColors.divider] from 54 to the edge, 20.3 below the meta line's centre or
  /// 12 below the replies box. Under the system font it is 20 below the meta text's centre (font-check 04), which
  /// sits [metaTextRise] above the line's.
  static const dividerLeading = 54.0;
  static const divider = 2 / 3;
  static const dividerColour = BiliColors.divider;
  static double get bottom => BiliFonts.nudged ? 61 / 3 - metaHeight / 2 : 20 - metaTextRise - metaHeight / 2;

  /// How far the meta text's centre sits above the meta line's: 0.5 under the system font (font-check 04), MiSans's
  /// 1.2 below it. The hairline, the thread's band and its UP主觉得很赞 box are placed from the text.
  static double get metaTextRise => BiliFonts.nudged ? -1.2 : 0.5;
  static const boxBottom = 12.0;

  /// The fan card's art 36.3 tall, 0.7 down, its left 81 from the right edge; the two lines of its number start 31
  /// into it, the first 13 down.
  static const fanCardTop = 2 / 3;
  static const fanCardHeight = 109 / 3;
  static const fanCardLeft = 81.0;
  static const fanNumberLead = 31.0;
  static const fanNumberTop = 13.0 - fanCardTop;
  static const fanGlyphWidth = 4.5;
  static const fanGlyphHeight = 5.1;
  static const fanGlyphWeight = 1.15;
  static const fanGlyphGap = 1.0;
  static const fanLineGap = 2.05;

  /// A card whose colour the server left out.
  static const fanNumber = Color(0xFF998245);

  /// The name stops this far before the card's art.
  static const fanCardClearance = 4.0;

  static TextStyle get textStyle => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: textText,
    height: textLine / textText,
    leadingDistribution: TextLeadingDistribution.even,
    color: text,
  );

  static TextStyle get previewStyle => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: previewText,
    height: previewLine / previewText,
    leadingDistribution: TextLeadingDistribution.even,
    color: preview,
  );

  static TextStyle metaStyle(Color color) => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: metaText,
    height: metaHeight / metaText,
    leadingDistribution: TextLeadingDistribution.even,
    color: color,
  );

  /// MiSans sets the meta line's text a point higher in its line than PingFang does on 13.
  static double get metaDrop => BiliFonts.nudged ? 1 : 0;
}

/// 评论's list, its sort header, footers and 发条评论 bar, and 评论详情's header and band (10-13), measured at 3 px per
/// pt.
abstract final class CommentListTheme {
  static CommentListThemeColors colorsOf(BuildContext context) => CommentListThemeColors(BiliPalette.of(context));

  static const gutter = BiliMetrics.gutter;

  /// Always white, as the official page.
  static const background = BiliColors.card;

  /// The hairlines over the 发条评论 bar and under 评论详情's header.
  static const rule = BiliColors.divider;

  /// 热门评论 and ≡ 按热度 centre 16.5 below the list's top in a 28 pt header, so the first row's fan card starts 31
  /// below it (10). 评论详情's 相关回复共N条 sits lower in 35 pt under the band (13). The official app sets them in
  /// PingFang at 12 and 11 pt (their glyphs 31 and 29 px tall on 10); MiSans matched at 13 and 12.
  static const sortHeight = 28.0;
  static const sortCentre = 16.5;
  static const threadSortHeight = 35.0;
  static const threadSortCentre = 55 / 3;
  static const sortLine = 18.0;
  static double get sortTitleText => BiliFonts.nudged ? 13 : 12;
  static double get sortText => BiliFonts.nudged ? 12 : 11;
  static const sortInk = BiliColors.secondaryText;

  /// ≡: three bars 1 pt thick and 4 apart, 35/3 wide, 4 before 按热度.
  static const sortIconWidth = 35 / 3;
  static const sortIconBar = 1.0;
  static const sortIconPitch = 4.0;
  static const sortIconGap = 4.0;

  /// The sort button's touch reaches this far left of ≡.
  static const sortTouchLead = 16.0;

  /// The footer under a list: 没有更多了 and the empty and failed lines, more room when the list is empty.
  static const footerText = 12.0;
  static const footerLine = 17.0;
  static const footerInk = Color(0xFFC9CCD0);
  static const footerPadding = 20.0;
  static const emptyPadding = 48.0;
  static const retryInk = BiliColors.secondaryText;
  static const retryAction = BiliColors.link;

  /// The server's reason over 加载失败，点击重试, as the Swift app showed it.
  static const retryGap = 6.0;
  static const spinnerRadius = 10.0;

  /// The section the uploader closed: a bubble over the server's words.
  static const closedTop = 80.0;
  static const closedIcon = 34.0;
  static const closedGap = 10.0;
  static const closedText = 14.0;
  static const closedInk = BiliColors.secondaryText;

  /// The 发条评论 bar (10, 13): a hairline over it, the 34 pt pill 17/3 below the hairline and 5 above the home
  /// indicator, 12 in from the left and 44 short of the right, where the 20 pt emote face centres 22 in.
  static const barHairline = 0.5;
  static const barTop = 17 / 3;
  static const barBottom = 5.0;
  static const fieldHeight = 34.0;
  static const fieldFill = BiliColors.pageGrey;
  static const fieldPadding = 13.0;
  static const fieldText = 15.0;
  static const fieldInk = BiliColors.secondaryText;
  static const faceBox = 44.0;
  static const face = 20.0;
  static const faceStroke = 1.28;
  static const faceInk = BiliColors.secondaryText;

  /// 评论详情's header over the thread: 40 as the tab row it covers, then its 1 pt hairline (3 px at 239.7 on 13).
  static const threadHeaderHeight = 41.0;
  static const threadHairline = 1.0;
  /// Under the system font 13.75: the official 评论详情's glyphs are 38 px tall to our 41.5 at 15 (font-check 04).
  static double get threadTitleText => BiliFonts.nudged ? 15 : 13.75;
  static const threadTitleInk = BiliColors.text;

  /// ✕: 38/3 pt square, 1.2 pt strokes, centred 26 in from the right edge in a 44 pt button.
  static const close = 38 / 3;
  static const closeStroke = 1.2;
  static const closeBox = 44.0;
  static const closeTrailing = 4.0;
  static const closeInk = BiliColors.secondaryText;

  /// The grey band between the thread's root and its replies, straight under the root's meta line.
  static const bandHeight = 10.0;
  static const band = BiliColors.pageGrey;

  /// The band starts 20 below the root's meta text's centre, where a reply's hairline does (13 and font-check 04).
  /// MiSans keeps the hairline's room.
  static double get bandGap => BiliFonts.nudged
      ? CommentRowTheme.bottom + CommentRowTheme.divider
      : 20 - CommentRowTheme.metaTextRise - CommentRowTheme.metaHeight / 2;

  /// MiSans sets Chinese wider than the official PingFang (热门评论 37.3 px a character on 10, MiSans 38.7; 按热度 33
  /// against 36); these close most of it without crowding the glyphs.
  static double get sortTitleSpacing => BiliFonts.nudged ? -0.4 : 0;
  static double get sortSpacing => BiliFonts.nudged ? -0.6 : 0;
  static double get fieldSpacing => BiliFonts.nudged ? -0.6 : 0;
  static double get threadTitleSpacing => BiliFonts.nudged ? -0.4 : 0;
}

/// A comment's rich text and the picture viewer.
abstract final class CommentTextTheme {
  static CommentTextThemeColors colorsOf(BuildContext context) => CommentTextThemeColors(BiliPalette.of(context));

  /// The only blue the official comments show (12's 共N条回复) is the app's link blue.
  static const link = BiliColors.link;

  /// A reply's "回复 名字: " lead names whom it answers in grey, #9499A0 on font-check 04, without the @.
  static const replyTarget = BiliColors.secondaryText;

  /// An emote's side per step of its `size`, as a share of the text's size: 12's 😑 is 20 pt beside 15 pt text.
  static const emoteScale = 4 / 3;

  /// Two emotes in a row stand apart by this share of the text's size: the thread shot's (differences 12) are 24 pt
  /// apart beside 15 pt text, 4 more than their side. One after text gets no gap.
  static const emoteGap = 4 / 15;

  /// How far an emote's middle sits above the baseline, as a share of the text's size: on the middle of the Chinese
  /// glyphs beside it, as on 12.
  static const emoteRise = 0.35;

  /// A line holding an emote reaches this much further below its text than a plain line: on 12 the meta under a line
  /// ending in 😑 sits 2 pt lower than under plain text.
  static const emoteLineGrowth = 2.0;

  static const viewerBackground = Color(0xFF000000);
  static const viewerText = Color(0xFFFFFFFF);
  static const viewerCountText = 15.0;

  /// The "2/5" count, below the safe area.
  static const viewerCountTop = 12.0;

  /// The invisible 关闭 target in the top corner, for VoiceOver; a tap anywhere closes the viewer anyway.
  static const viewerCloseTarget = 44.0;
  static const viewerFadeIn = Duration(milliseconds: 200);
  static const viewerZoomDuration = Duration(milliseconds: 250);
  static const viewerDoubleTapScale = 2.5;
  static const viewerMaxScale = 4.0;

  /// While a picture loads, the list's thumbnail under a spinner; a failed one shows a picture glyph at half white.
  static const viewerSpinnerRadius = 14.0;
  static const viewerFailedGlyph = 48.0;
  static const viewerFailedGlyphStroke = 2.0;
  static const viewerFailedGlyphColor = Color(0x80FFFFFF);
  static const viewerCrossFade = Duration(milliseconds: 200);

  /// A vertical swipe throws the picture back to the comments, as 105 shows: it follows the finger, shrinking to 60%
  /// while the black fades out over a third of the screen's height. Let go past [viewerThrowCommit] or flicked
  /// faster than [viewerThrowFlick], it flies on off the screen; otherwise it settles back.
  static const viewerThrownScale = 0.6;
  static const viewerThrowFade = 1 / 3;
  static const viewerThrowCommit = 100.0;
  static const viewerThrowFlick = 700.0;
  static const viewerThrowAway = Duration(milliseconds: 220);
  static const viewerThrowBack = Duration(milliseconds: 250);
}

/// Landscape's seek preview while the bar is dragged, measured on KaiC's recording 102 (956 × 440): the frame in a
/// 1 pt white border with 6 pt corners, 184 pt from the top of the screen, and the time 15 pt under it, centred.
abstract final class SeekPreviewTheme {
  static const frameWidth = 168.0;
  static const frameHeight = 93.0;
  static const border = 1.0;
  static const radius = 6.0;
  static const borderColor = Color(0xFFFFFFFF);

  /// The frame's top above the screen's middle.
  static const aboveMiddle = 36.0;
  static const timeGap = 15.0;
  static const timeFont = 15.0;
  static const time = Color(0xFFFFFFFF);

  /// Reads #999999 over 19's black.
  static const duration = Color(0x99FFFFFF);
  static const fade = Duration(milliseconds: 200);

  /// 竖屏's (19 and 20, 440 × 956): the frame 81 × 144 pt for an upright video and 144 × 81 for a wide one, border
  /// included, centred with its bottom at 788 pt, and the time's digits at 802-814 pt under it. Both are placed from
  /// 竖屏's bottom rows (33 pt above the screen's bottom there), so they keep their distance from its bar.
  static const uprightLong = 144.0;
  static const uprightShort = 81.0;
  static const uprightTimeFont = 16.0;
  static const uprightTimeGap = 12.57;
  static const uprightTimeLift = 106.43;
}

/// The composer and its emote panel (14), measured at 3 px per pt.
abstract final class ComposerTheme {
  static ComposerThemeColors colorsOf(BuildContext context) => ComposerThemeColors(BiliPalette.of(context));

  static const gutter = BiliMetrics.gutter;

  /// 14's page shows through at 80%: its white reads #CCCCCC.
  static const dim = BiliColors.scrim;
  static const sheet = BiliColors.card;

  /// The keyboard toggle and 发布 are a deeper pink than [BiliColors.pink]; 发布 with nothing to post is it at about
  /// 30% on white.
  static const accent = Color(0xFFED7098);
  static const accentFaded = Color(0xFFF8D3DF);
  static const publishText = Color(0xFFFFFFFF);
  static const text = BiliColors.text;
  static const placeholder = Color(0xFFC9CCCF);

  /// @, ⊕, ⤢ and the emote face.
  static const tool = Color(0xFF95999F);
  static const syncText = Color(0xFF62666C);
  static const syncRing = placeholder;
  static const panel = BiliColors.pageGrey;
  static const tabBar = BiliColors.card;
  static const tabSelected = BiliColors.pageGrey;
  static const sectionTitle = syncText;
  static const kaomoji = BiliColors.text;
  static const kaomojiTab = Color(0xFFA7A7A7);

  /// The sheet rises as the page dims, and falls when it closes itself; ⤢ grows the field.
  static const rise = Duration(milliseconds: 250);
  static const fall = Duration(milliseconds: 200);
  static const expand = Duration(milliseconds: 250);

  /// How long the emote panel waits for the keyboard it gave way to before going anyway: a hardware keyboard shows no
  /// software one.
  static const keyboardWait = Duration(milliseconds: 600);

  /// The sheet is 115 pt over the emote panel's top: the field, then the toolbar. The first line's ink is centred
  /// 24.7 pt under the sheet's top and 13 pt in; ⤢'s 10.7 pt arrows are centred 24 pt down and 20 pt from the right.
  static const sheetRadius = 4.0;
  static const editorHeight = 67.0;
  static const expandedEditorHeight = 260.0;
  static const editorTop = 13.5;
  static const editorLeading = 12.0;
  static const editorTrailing = 40.0;
  static const editorFont = 15.0;
  static const expandCellHeight = 48.0;
  static const expandIcon = 32 / 3;
  static const expandStroke = 4 / 3;

  /// The toolbar's row, everything on its middle: ○ 11 pt in with 转到动态 5 pt after it, the keyboard toggle, @ and
  /// ⊕ in 44 pt cells centred at 96, 140 and 184 pt, and 发布 12 pt from the right.
  static const toolbarHeight = 48.0;
  static const syncLeading = 11.0;
  static const syncRingSize = 10.0;
  static const syncRingStroke = 1.0;
  static const syncGap = 5.0;
  static const syncWidth = 74.0;
  static const syncFont = 10.0;
  static const toolCell = 44.0;
  static const toolIcon = 20.0;
  static const keyboardIconHeight = 52 / 3;
  static const toolStroke = 1.5;
  static const publishWidth = 56.0;
  static const publishHeight = 24.0;
  static const publishTrailing = 12.0;
  static const publishFont = 13.0;
  static const publishSpinnerRadius = 7.0;

  /// The emote panel takes the keyboard's place at its height; before the keyboard has been seen, the grid is 14's
  /// 226 pt over its 44 pt tab bar (878-922) and the home indicator's strip.
  static const panelHeight = 226.0;
  static const tabHeight = 44.0;
  static const tabWidth = 50.0;
  static const tabIcon = 28.0;

  /// 14's section titles sit 1.5 pt under the middle of their band. A row's emote is centred 31 pt down; 最近使用's
  /// row is cut short under it.
  static const sectionHeight = 34.0;
  static const sectionTitleTop = 3.0;
  static const sectionFont = 12.0;
  static const gridSide = 3.0;
  static const columns = 7;
  static const emote = 28.0;
  static const row = 62.0;
  static const recentRow = 53.0;
  static const largeColumns = 4;
  static const largeEmote = 52.0;
  static const largeRow = 80.0;
  static const textColumns = 3;
  static const textRow = 44.0;
  static const kaomojiFont = 13.0;
  static const kaomojiPad = 4.0;
  static const kaomojiTabFont = 9.0;
  static const kaomojiTabPad = 3.0;
  static const spinnerRadius = 10.0;
}

/// The comment overlays: the rising thread and the delete confirm.
abstract final class CommentOverlayTheme {
  static CommentOverlayThemeColors colorsOf(BuildContext context) => CommentOverlayThemeColors(BiliPalette.of(context));

  static const threadRise = Duration(milliseconds: 300);

  /// ✕, back or a released swipe slide 评论详情 off the bottom; part of the way takes its share of this.
  static const threadFall = Duration(milliseconds: 300);

  /// Behind 评论详情, so the list under it never shows through and touches stop there.
  static const threadFill = BiliColors.card;

  /// A released swipe closes 评论详情 once it is this share of its height down, or when the finger moves right faster
  /// than [threadFlingWidths] screen widths a second (Flutter's Cupertino back swipe's `_kMinFlingVelocity`).
  static const threadCloseShare = 1 / 3;
  static const threadFlingWidths = 1.0;

  /// The picture viewer fades in and out (BiliNative's 0.2 s ease out).
  static const viewerFade = Duration(milliseconds: 200);

  /// The delete confirm comes and goes as the unfollow confirm does, in the same alert with a message under the
  /// title (Swift's 删除评论 alert).
  static const confirmIn = Duration(milliseconds: 300);
  static const confirmOut = Duration(milliseconds: 220);
  static const alertWidth = FavouriteTheme.alertWidth;
  static const alertRadius = FavouriteTheme.alertRadius;
  static const alertTitleText = FavouriteTheme.alertTitleText;
  static const alertButtonHeight = FavouriteTheme.alertButtonHeight;
  static const alertButtonText = FavouriteTheme.alertButtonText;
  static const alertDim = FavouriteTheme.alertDim;
  static const alertStartScale = FavouriteTheme.alertStartScale;
  static const alertTitlePadTop = 22.0;
  static const alertMessageText = 14.0;
  static const alertMessageGap = 6.0;
  static const alertMessagePadBottom = 20.0;
  static const alertTitle = BiliColors.text;
  static const alertMessage = BiliColors.secondaryText;
  static const alertCancel = BiliColors.secondaryText;
  static const alertDelete = BiliColors.pink;
}

/// The paused player shrinking to the 继续播放 bar (11, 12).
abstract final class CollapseTheme {
  /// 12's bar is 202 px tall; BiliNative's 56 pt was short of it.
  static const barHeight = 202 / 3;

  /// Over the bar at 12's darkness (its danmaku keep 11% of their white); it deepens with the shrink, as on 11.
  static const shade = Color(0xE3000000);

  /// ▶ 继续播放 is fully in once the player has gone this share of the way, then its opacity holds.
  static const labelFade = 1.6;

  /// 12 centres the bar's row 2.5 px above the bar's middle.
  static const rowLift = 2.5 / 3;
  static const playGlyphWidth = 40 / 3;
  static const playGlyphHeight = 44 / 3;

  /// 12 sets ▶ 17.4 pt before 继续播放 and the pair 1.5 pt right of the bar's middle.
  static const labelGap = 3.3;
  static const labelShift = 1.5;
  static const labelText = 16.0;
  static const label = BiliColors.onVideo;

  /// The chevron's left edge and the dots' right edge from the screen's sides.
  static const backLeft = 17.0;
  static const backGlyphWidth = 9.0;
  static const backGlyphHeight = 16.0;
  static const moreRight = 61 / 3;

  /// ‹ and ⋮ joining the label once it is the bar.
  static const controlsFade = Duration(milliseconds: 150);

  /// 继续播放's scroll back to the top, and the player growing back to full once it plays.
  static const resume = Duration(milliseconds: 300);

  /// An upright video's box is at most this many widths tall. A guess: 17's 3:4 is the only sample, so a 9:16 sits in
  /// the 3:4 box with bars.
  static const uprightLimit = 4 / 3;

  /// The box taking a new shape: 18's shrink to 16:9 at the end and 重播's grow back (60 fps frames 89-98, 209-217).
  static const reshape = Duration(milliseconds: 150);
  static const reshapeCurve = Curves.easeInOut;
}

/// The composer's @ picker and attached pictures.
abstract final class MentionTheme {
  static MentionThemeColors colorsOf(BuildContext context) => MentionThemeColors(BiliPalette.of(context));

  static const gutter = BiliMetrics.gutter;

  /// How long typing must rest before the picker searches.
  static const debounce = Duration(milliseconds: 300);

  /// The search pill under the header, filled as 14's emote panel.
  static const fieldHeight = 36.0;
  static const fieldFill = BiliColors.pageGrey;
  static const fieldText = 15.0;
  static const fieldIcon = 18.0;
  static const fieldIconGap = 6.0;
  static const fieldPadX = 12.0;
  static const fieldBottom = 4.0;
  static const fieldSpinnerRadius = 7.0;
  static const clearSize = 16.0;
  static const clearGlyph = 11.0;
  static const clearFill = BiliColors.sheetHint;
  static const clearGlyphColor = BiliColors.card;

  /// 最近关注 over the list, in 14's 最近使用 grey.
  static const sectionHeight = 36.0;
  static const sectionText = 13.0;
  static const sectionColour = BiliColors.sheetCloseGlyph;

  static const rowHeight = 60.0;
  static const avatar = 40.0;
  static const avatarGap = 12.0;
  static const nameText = 15.0;

  /// The part of a name that matches the search.
  static const match = BiliColors.pink;

  /// Loading, no matches and 加载失败.
  static const statePad = 40.0;
  static const stateText = 14.0;
  static const spinnerRadius = 10.0;

  /// The attached pictures: square thumbnails under the field, each with a ✕ in its top right corner.
  static const thumb = 72.0;
  static const thumbGap = 8.0;
  static const thumbRadius = BiliMetrics.cardRadius;
  static const thumbBottom = 8.0;
  static const thumbBorder = BiliColors.divider;
  static const thumbBorderWidth = 0.5;
  static const removeHitBox = 28.0;
  static const removeSize = 18.0;
  static const removeGlyph = 11.0;
  static const removeInset = 4.0;
  static const removeFill = Color(0x8C000000);
  static const removeGlyphColor = Color(0xFFFFFFFF);
}

/// The avatar's page (49), measured from the safe area's top: the bar, the four shortcuts, then the white card of
/// 最近在看的视频 whose rows are [rowExtent] apart with the cover [rowCoverTop] into each.
abstract final class AvatarPageTheme {
  static AvatarPageThemeColors colorsOf(BuildContext context) => AvatarPageThemeColors(BiliPalette.of(context));

  static const background = BiliColors.softGrey;
  static const barHeight = 44.0;
  static const barIcon = Color(0xFF61666D);
  static const backLeft = 19.5;
  static const tabCentreX = 132.3;
  static const tabText = 16.0;
  static const tabWeight = FontWeight.w600;
  static const tabUnderlineTop = 34.0;
  static const tabUnderlineWidth = 12.0;
  static const tabUnderlineHeight = 2.0;
  static const gearCentreX = 416.0;
  static const gearBox = 22.0;
  static const gearRadius = 9.4;
  static const gearCorner = 2.0;
  static const gearHole = 3.1;
  static const gearStroke = 1.5;
  static const tapTarget = 44.0;

  /// The shortcuts: a quarter of the width each, their 32 pt icon box centred [shortcutIconCentre] below the bar and
  /// the label's middle [shortcutLabelCentre] below it.
  static const shortcutsHeight = 96.0;
  static const shortcutIconBox = 32.0;
  static const shortcutIconCentre = 37.0;
  static const shortcutLabelCentre = 61.6;
  static const shortcutStroke = 5 / 3;
  static const shortcutText = 12.0;

  static const cardRadius = 20.0;
  static const headerHeight = 36.0;
  static const headerCentre = 26.0;
  static const headerText = 14.0;
  static const headerWeight = FontWeight.w500;
  static const allText = 12.0;
  static const allChevronWidth = 4.7;
  static const allChevronHeight = 9.0;
  static const allChevronGap = 7.6;
  static const allChevronStroke = 1.2;
  static const allRight = 15.0;

  static const rowExtent = 104.0;
  static const rowCoverTop = 14.0;
  static const coverWidth = 136.0;
  static const coverHeight = 76.0;
  static const coverRadius = 5.0;
  static const progressHeight = 2.0;
  static const durationHeight = IntroListTheme.durationHeight;
  static const durationPad = 3.0;
  static const durationRadius = IntroListTheme.durationRadius;
  static const durationInset = IntroListTheme.durationInset;
  static const durationText = IntroListTheme.durationText;
  static const durationFill = IntroListTheme.durationFill;
  static const textLeft = 156.0;
  static const titleText = 14.0;
  static const titleLine = 50 / 3;

  /// How far the title's line box starts above the cover, so its ink lines up with the cover's top.
  static const titleLift = 2.0;
  static const timeText = 12.0;

  /// How far the time's line box ends below the cover, so its ink ends a point above the cover's bottom.
  static const timeDrop = 2.2;
  static const removeCentreFromRight = 20.0;
  static const removeCentreBelowCover = 70.0;
  static const removeGlyph = 8.6;
  static const removeStroke = 1.0;
  static const remove = Color(0xFFC9CCD0);
  static const shown = 5;
}

/// 我的 (87, 106, 107). The fixed part (the top icons, the header, the counts and the 会员 card) is measured from the
/// safe area's top; the list that scrolls under the card from the card's bottom, its viewport's top.
abstract final class MeTheme {
  static MeThemeColors colorsOf(BuildContext context) => MeThemeColors(BiliPalette.of(context));

  static const background = BiliColors.card;

  /// The top row: four glyphs 40.67 apart, the last centred 24.67 from the right edge, all 22 below the safe area.
  static const topCentre = 22.0;
  static const topLastFromRight = 24.67;
  static const topPitch = 40.67;
  static const topGlyphBox = 24.0;
  static const topGlyphStroke = 1.5;
  static const topGlyph = Color(0xFF61666D);
  static const castDot = 1.1;
  static const topTapHeight = 44.0;

  /// The avatar: 64 across without a frame; under a frame the face shrinks to 49 about the same middle and the frame
  /// is 评论's 1.75 times the face.
  static const avatarLeft = 15.0;
  static const avatarTop = 64.0;
  static const avatar = 64.0;
  static const pendantFace = 49.0;
  static const pendantScale = CommentRowTheme.pendantScale;

  /// With no profile (logged out, loading, failed), 首页's grey head: a person glyph at this share of the circle.
  static const blankHead = 0.55;

  /// The 大 disc on its corner, in a white ring: flush with the avatar's box, 3 in from it under a frame.
  static const vipDisc = 16.0;
  static const vipRing = 2.0;
  static const vipPendantInset = 3.0;
  static const vipDiscFill = BiliColors.pink;
  static const vipDiscInk = Color(0xFFFFFFFF);
  static const vipRingInk = Color(0xFFFFFFFF);
  static const vipDiscStroke = 1.6;

  /// The column right of the avatar starts 2 further right under a frame.
  static const textLeft = 94.33;
  static const pendantTextShift = 2.0;

  /// A line of text sits centred in a box this tall at its middle.
  static const lineBox = 30.0;

  /// The name's middle below the safe area.
  static const nameCentre = 74.0;
  static const nameText = 16.0;
  static const nameWeight = FontWeight.w500;
  static const name = BiliColors.text;
  static const vipName = BiliColors.pink;
  static const loggedOutText = 16.0;

  /// ✏️ and the LV badge after the name, the gaps between their inks.
  static const pencilGap = 8.3;
  static const pencilBox = 20.8;
  static const pencilInk = 13.7;
  static const pencilStroke = 1.4;
  static const pencil = BiliColors.secondaryText;
  static const levelGap = 9.5;
  static const levelWidth = 20.0;
  static const levelHeight = 10.0;
  static const levels = [
    Color(0xFFC0C4CC),
    Color(0xFFC0C4CC),
    Color(0xFF8BD29B),
    Color(0xFF7BCDEF),
    Color(0xFFFEBB8B),
    Color(0xFFED672A),
    Color(0xFFE3524E),
  ];
  static const levelInk = Color(0xFFFFFFFF);

  static const vipLabelTop = 90.0;
  static const vipLabelHeight = 14.0;
  static const vipLabelPad = 6.3;
  static const vipLabelText = 11.0;
  static const vipLabelWeight = FontWeight.w600;

  /// The pill after the level (年度大会员), a darker pink than the accent.
  static const vipLabelFill = Color(0xFFFF548C);
  static const vipLabelInk = Color(0xFFFFFFFF);

  /// The B币 line's middle below the safe area.
  static const coinsCentre = 121.2;
  static const coinsText = 12.0;
  static const coins = BiliColors.secondaryText;
  static const coinsGap = 20.5;

  /// 空间 ›, its middle within a point of the avatar's.
  static const spaceCentre = 95.2;
  static const spaceText = 12.0;
  static const space = BiliColors.secondaryText;
  static const spaceChevronGap = 7.3;
  static const spaceRight = 16.67;
  static const chevronWidth = 20 / 3;
  static const chevronHeight = 12.0;
  static const chevronStroke = 1.0;

  /// 动态, 关注 and 粉丝 in thirds of the width, a 1 pt rule 20 tall at each third.
  static const countCentre = 167.5;
  static const countText = 15.0;
  static const countWeight = FontWeight.w500;
  static const count = BiliColors.text;
  static const countLabelCentre = 186.0;
  static const countLabelText = 12.0;
  static const countLabel = BiliColors.secondaryText;
  static const countRuleTop = 166.0;
  static const countRuleHeight = 20.0;
  static const countRuleWidth = 1.0;
  static const countRule = BiliColors.divider;
  static const countTap = 44.0;

  /// The 会员 card, 12 in from each side.
  static const cardTop = 204.0;
  static const cardHeight = 54.0;
  static const cardInset = 12.0;
  static const cardRadius = 8.0;
  static const card = Color(0xFFFFECF1);
  static const cardLineCentre = 18.0;
  static const cardTitleGap = 4.0;
  static const cardTitleText = 14.0;
  static const cardTitleWeight = FontWeight.w400;
  static const cardTitle = BiliColors.pink;
  static const cardMoreCentre = 38.5;
  static const cardMoreText = 12.0;
  static const cardMore = Color(0x9918191C);
  static const cardMoreChevronGap = 3.0;
  static const cardMoreChevronWidth = 16 / 3;
  static const cardMoreChevronHeight = 28 / 3;
  static const cardMoreChevronStroke = 0.8;
  static const cardButtonWidth = 80.0;
  static const cardButtonHeight = 30.0;
  static const cardButtonText = 14.0;
  static const cardButtonFill = BiliColors.pink;
  static const cardButtonInk = Color(0xFFFFFFFF);

  /// A 大会员's card coming in once the profile answers; the header's height follows at the same pace.
  static const cardFade = Duration(milliseconds: 250);
  static const cardFadeCurve = Curves.easeOut;

  /// The list's viewport starts this far under the header, leaving 106's white band under the card; what it holds
  /// keeps the rest positions below, measured from the card's bottom.
  static const listCut = 8.0;

  /// The four shortcuts: a quarter of the width each, in 87's blue, their icon box and label centred below the card.
  static const shortcutIconCentre = 26.0;
  static const shortcutLabelCentre = 51.4;
  static const shortcutHeight = 72.0;
  static const shortcutGlyph = Color(0xFF2CA1DD);
  static const shortcutText = 12.0;
  static const shortcutLabel = BiliColors.text;

  /// 更多服务: its title 48 below the shortcuts' labels, as 87's is below 我的服务's last labels, then 106's rows.
  static const servicesTitleCentre = 99.5;
  static const servicesTitleText = 14.0;
  static const servicesTitleWeight = FontWeight.w500;
  static const servicesTitle = BiliColors.text;
  static const serviceFirstCentre = 141.2;
  static const serviceRow = 48.0;
  static const serviceGlyphCentre = 37.0;
  static const serviceGlyphBox = 30.0;
  static const serviceGlyphStroke = 1.5;
  /// 106's glyphs differ a little (sRGB): 听视频's is pinker than 联系客服's and 设置's.
  static const serviceGlyph = Color(0xFFF9739D);
  static const listenGlyph = Color(0xFFFD679D);
  static const serviceTextLeft = 60.5;
  static const serviceText = 14.0;
  static const serviceLabel = BiliColors.text;
  static const serviceChevron = Color(0xFF999999);
  static const bottomPad = 24.0;

  /// The equipped 装扮 (109): its picture fills the width from the screen's top to the list's, and its last
  /// [skinFade] (the card and the band under it) whitens into the list. The stops are the white's measured over the
  /// picture's dark edges, which give the same curve at every column.
  static const skinFade = 62.0;
  static const skinFadeStops = [0.0, 0.086, 0.333, 0.538, 0.634, 1.0];
  static const skinFadeColors = [
    Color(0x00FFFFFF),
    Color(0x1CFFFFFF),
    Color(0x4DFFFFFF),
    Color(0xCCFFFFFF),
    Color(0xE6FFFFFF),
    Color(0xFFFFFFFF),
  ];

  /// The text and icons over the picture when the skin asks for light text but names no colour. 109's are this
  /// white, at 87's places and sizes; the counts' rules go.
  static const skinLightInk = Color(0xFFFFFFFF);
}

/// The swipe back from a 推荐 card (03, 04 in local/differences, measured frame by frame): the page shrinks into a
/// floating card over the dimmed home and flies into the card it came from.
abstract final class ZoomBackTheme {
  /// Over home while the page is still full size, lightening to [dimShrunk] as it reaches [minScale].
  static const dim = Color(0x8C000000);
  static const dimShrunk = Color(0x57000000);

  /// Shares of the screen's width the finger has moved right. The page shrinks slowly to [kneeScale] by
  /// [kneeTravel], then quickly to [minScale] by [minScaleTravel] while its centre holds still, then only moves.
  static const kneeTravel = 0.366;
  static const kneeScale = 0.8;
  static const minScaleTravel = 0.477;
  static const minScale = 0.6;

  /// In the page's own points, so it shrinks with the page (6.6 pt on screen at 0.6).
  static const cornerRadius = 11.0;

  /// Let go past this share of the width, or flung right at [flingSpeed] widths a second or more, and the page goes;
  /// otherwise it springs back over [settle].
  static const completeTravel = 0.24;
  static const flingSpeed = 1.0;
  static const settle = Duration(milliseconds: 350);

  /// Let go, the page flies into its card in about ten frames, the dim lifting with it. The card's picture is in by
  /// [pictureIn] of the way, from the first frame; under it the page drops at once to [pageUnder] and fades out by
  /// [pageOut], so it is the card that flies.
  static const fly = Duration(milliseconds: 170);
  static const flyCurve = Curves.easeOut;
  static const pictureIn = 0.05;
  static const pageUnder = 0.3;
  static const pageOut = 0.7;

  /// With no picture of the card to turn into, the page fades onto the card itself from this share of the way.
  static const fadeOntoCard = 0.35;

  /// The 〈 button and system back fly the full page into its card.
  static const flyFromFull = Duration(milliseconds: 350);

  /// With its card off screen or gone, the page shrinks this much more towards the middle as it fades.
  static const lostScale = 0.5;

  /// Reduce Motion: let go, the page fades where it is.
  static const fade = Duration(milliseconds: 150);
}

/// Turning to landscape full screen and back (01 in local/differences): the video grows from its small spot to full
/// screen over the whole turn, starting as the presentation changes, or as the system's turn starts when the page draws
/// it. The official turn moves visibly for 16 to 17 frames at 60 fps either way, its ease-in-out's ends barely moving.
abstract final class RotationTheme {
  /// The official turn's length both ways, fitted with [curve] to 298.5 and 300.1 ms: UIKit's 0.3 s. A turn the page
  /// draws takes it too, since iOS reports no length for a turn asked for with its animations off.
  static const grow = Duration(milliseconds: 300);

  /// The official page's angle, measured frame by frame both ways, fits this to within 0.2° rms (0.9° at worst), and
  /// its box grows in step. A turn the page draws itself (旋转动画) turns and grows on it too.
  static const curve = Curves.easeInOut;

  /// While the page draws the turns, how long a change of presentation waits for the system's turn before the player
  /// grows without one, as a refused or lost turn would leave it.
  static const takeoverWait = Duration(milliseconds: 250);
}

/// 弹幕设置 (07, 08, 24, 29, 33, 40, 41). Landscape is a hard-edged dark strip at the right, portrait the light
/// sheet; both lay out the same, measured from the top of the scrolling content and the left of the cards.
abstract final class DanmakuPanelTheme {
  static DanmakuPanelThemeColors colorsOf(BuildContext context) => DanmakuPanelThemeColors(BiliPalette.of(context));

  /// The strip's share of the screen's width (382 of 956 pt) and the portrait sheet's height when it isn't hung
  /// from the small player (497 of 956).
  static const width = 382 / 956;
  static const sheetHeight = 497 / 956;

  /// No ramp into the video in front of it, unlike the other panels: 07, 24 and 29 cut straight to this.
  static const shade = Color(0xE1000000);

  /// The cards lie [inset] in from the strip's left and the safe area's edge, and their rows another [inset].
  static const inset = 16.0;
  static const cardRadius = 8.0;

  /// From the top of the content to the first card; the title and 查看更多 are centred [headerCentre] down.
  static const headerHeight = 48.0;
  static const headerCentre = 26.2;
  static const titleText = 14.0;
  static const detailText = 12.0;

  /// The box a line of text is centred in.
  static const labelBox = 20.0;
  static const moreGap = 5.5;
  static const moreTrailing = 2.0;

  /// A slider row: label and value centred [sliderLabelCentre] down, the track centred [sliderTrackCentre] down,
  /// [sliderTrackInset] in from the card, the thumb's centre travelling to [sliderThumbInset] from the track's
  /// ends and the stop dots [sliderDotInset].
  static const sliderRow = 68.0;
  static const sliderLabelCentre = 22.0;
  static const sliderTrackCentre = 46.3;
  static const sliderTrackInset = 14.0;
  static const sliderTrack = 6.0;
  static const sliderThumb = 14.0;
  static const sliderThumbInset = 4.0;
  static const sliderDot = 3.7;
  static const sliderDotInset = 5.6;

  /// Section titles sit between cards [sectionHeight] apart, centred [sectionCentre] below the card above.
  static const sectionHeight = 56.0;
  static const sectionCentre = 34.2;

  /// 按弹幕类型屏蔽: its label, the row of squares and their labels, then the hairline at the block's foot.
  static const typeBlock = 140.0;
  static const typeLabelCentre = 26.2;
  static const squareTop = 52.0;
  static const squareHeight = 48.0;
  static const squareGap = 6.0;
  static const squareRadius = 12.0;
  static const squareLabelCentre = 13.2;

  /// The type glyphs' box, and the ⊘ on a blocked type: its centre in the box, its radius to the stroke's middle,
  /// and how far round it the screen's outline is cut away.
  static const glyphWidth = 26.0;
  static const glyphHeight = 22.2;
  static const glyphStroke = 1.5;
  static const markStroke = 1.5;
  static const badgeCentre = Offset(21.8, 17.5);
  static const badgeRadius = 5.4;
  static const badgeClear = 8.3;

  /// A row with a switch: its title and subtitle centred [toggleTitleCentre] and [toggleSubtitleCentre] down.
  static const toggleRow = 72.0;
  static const toggleTitleCentre = 27.7;
  static const toggleSubtitleCentre = 48.8;

  /// 添加屏蔽词's button under 弹幕观看屏蔽词, then the gap to 当前弹幕列表's hairline.
  static const buttonHeight = 36.0;
  static const buttonRadius = 8.0;
  static const buttonTextInset = 16.0;
  static const buttonChevronTrailing = 20.3;
  static const buttonGap = 15.0;
  static const listRow = 51.0;
  static const listChevronTrailing = 21.0;

  /// ↻ 重置弹幕设置 under the last card: centred [resetCentre] below it, its text ending [resetTrailing] short of
  /// the cards' right edge, and the content ending [endGap] below its row (portrait adds the safe area).
  static const resetCentre = 24.0;
  static const resetHeight = 20.0;
  static const resetGap = 3.0;
  static const resetTrailing = 1.0;

  /// MiSans sets 重置弹幕设置 a point wider than 08's PingFang, which would push ↻ left of where 08 has it.
  static double get resetSpacing => BiliFonts.nudged ? -0.2 : 0;
  static const endGap = 6.0;

  /// The portrait sheet's content starts this far under its grabber.
  static const sheetTop = 8.0;

  static const chevronDownWidth = 11.3;
  static const chevronDownHeight = 6.0;
  static const buttonChevronWidth = 6.7;
  static const buttonChevronHeight = 11.3;
  static const listChevronWidth = 5.7;
  static const listChevronHeight = 11.7;
  static const chevronStroke = 1.1;
  static const resetGlyphWidth = 13.3;
  static const resetGlyphHeight = 12.3;
  static const resetStroke = 1.0;

  /// The reset confirm (33): over the whole screen, dimming everything, the panel included.
  static const dialogWidth = 280.0;
  static const dialogTitleHeight = 67.3;
  static const dialogButtonHeight = 44.0;
  static const dialogRadius = 8.0;
  static const dialogTitleText = 16.0;
  static const dialogButtonText = 14.0;

  /// 我再想想 and 确定 are centred this far either side of the dialog's middle.
  static const dialogButtonSpread = 66.0;
  static const dialogDim = BiliColors.sheetDim;
  static const dialog = Color(0xFF242628);
  static const dialogText = Color(0xFFE7E9EB);
  static const dialogConfirm = Color(0xFFD44E7D);
  static const dialogDivider = Color(0xFF2F3134);

  /// Landscape, over the video: the cards and squares let a little of it through.
  static const card = Color(0xB32F3238);
  static const square = Color(0x0DFFFFFF);
  static const track = Color(0x26FFFFFF);
  static const hairline = BiliColors.panelHairline;
  static const text = BiliColors.panelText;
  static const value = Color(0xFFC9CCD0);
  static const secondary = BiliColors.panelSecondary;
  static const reset = Color(0xFFC9CCD0);

  /// Portrait's light sheet (40, 41): the fill left of the thumb is half pink, the thumb and dots pink.
  static const lightBackground = Color(0xFFF6F7F8);
  static const lightCard = BiliColors.card;
  static const lightSquare = Color(0xFFF6F7F8);
  static const lightTrack = Color(0xFFE3E5E7);
  static const lightFill = Color(0xFFFFB3CA);
  static const lightHairline = Color(0xFFE3E5E7);
  static const lightText = BiliColors.text;
  static const lightSecondary = BiliColors.secondaryText;
  static const lightReset = Color(0xFF61666D);
  static const lightSwitchOff = Color(0xFFE9E9EA);
  static const lightKnobShadow = Color(0x29000000);
  static const lightKnobShadowBlur = 1.5;
  static const lightKnobShadowOffset = Offset(0, 0.5);
}

/// 添加屏蔽词 (30). Across, sizes count from the safe area's left edge (62 pt on the Pro Max); the top row ends at its
/// right edge.
abstract final class BlockWordsTheme {
  static BlockWordsThemeColors colorsOf(BuildContext context) => BlockWordsThemeColors(BiliPalette.of(context));

  /// 30's white slide comes out at about 40 of 255.
  static const dim = Color(0xD6000000);

  /// The selected tab and its underline are Bilibili's #FB7299, not the app's [BiliColors.pink].
  static const pink = Color(0xFFFB7299);
  static const text = Color(0xFFFFFFFF);
  static const grey = Color(0xFF999999);

  static const closeCentreX = 27.0;
  static const closeHitBox = 44.0;

  /// From the ✕'s centre to the end of each stroke, along each axis.
  static const closeArm = 5.8;
  static const closeStroke = 2.1;

  static const rowTop = 7.0;
  static const rowHeight = 30.0;
  static const fieldLeft = 54.17;
  static const fieldFill = Color(0xFFFFFFFF);
  static const fieldInk = BiliColors.text;
  static const fieldRadius = 3.5;
  static const fieldPadX = 10.0;
  static const fieldText = 12.0;

  /// MiSans's Chinese is about 5% wider than 30's PingFang at 12 pt; this brings the placeholder and the tabs to its
  /// widths.
  static double get smallSpacing => BiliFonts.nudged ? -0.35 : 0;

  /// 添加 and 同步: white at 20% over the dim.
  static const buttonFill = Color(0x33FFFFFF);
  static const buttonGap = 12.33;
  static const buttonWidth = 77.67;
  static const buttonText = 14.0;
  static const addIcon = 17.0;
  static const addIconLeft = 13.6;
  static const addIconGap = 6.67;

  /// The pencil sits a point above the row's centre in 30.
  static const addIconLift = 1.0;
  static const addStroke = 1.33;
  static const syncIcon = 19.0;
  static const syncIconLeft = 8.17;
  static const syncIconGap = 5.0;
  static const syncStroke = 1.5;

  /// 关键词 / 正则 / 举报屏蔽用户 sit 4 pt in, their row from the top row's bottom to the list.
  static const tabsLeft = 4.0;
  static const tabsTop = 44.0;
  static const tabsHeight = 30.0;
  static const tabText = 12.0;
  static const tabGap = 22.33;
  static const underline = 2.0;

  /// The two columns split at the screen's centre by a third-of-a-point line down to the safe area's bottom.
  static const dividerWidth = 1 / 3;
  static const divider = Color(0x1AFFFFFF);
  static const listPad = 20.0;

  /// 30 has a single row; the gap between rows is the top row's button gap.
  static const rowGap = 12.0;

  static const chipHeight = 32.0;
  static const chipRadius = 4.0;
  static const chipFill = Color(0x0DFFFFFF);
  static const chipText = 14.0;
  static const chipPadLeft = 12.0;
  static const chipGlyphGap = 13.0;
  static const chipPadRight = 11.0;
  static const chipGlyph = 14.0;
  static const chipGlyphInset = 0.6;
  static const chipStroke = 1.65;
}

/// The send bar and the style panel (22, 23, 36-39).
abstract final class DanmakuSendTheme {
  static DanmakuSendThemeColors colorsOf(BuildContext context) => DanmakuSendThemeColors(BiliPalette.of(context));

  /// Landscape's dark bar over its darker area (22, 23); portrait's white bar with a hairline over a grey panel (36-39).
  static const darkBar = Color(0xFF242627);
  static const darkArea = Color(0xFF1A1B1C);
  static const lightBar = BiliColors.card;
  static const lightArea = BiliColors.pageGrey;
  static const hairline = Color(0xFFE3E5E7);
  static const hairlineWidth = 1 / 3;

  /// Landscape's pink is deeper than the light pages'; 竖屏's send arrow turns it too (37), while A and the options
  /// take the page pink there (38).
  static const darkAccent = Color(0xFFED7098);
  static const lightAccent = BiliColors.pink;
  static const sendReady = darkAccent;
  static const darkGlyph = Color(0xFFFFFFFF);
  static const lightGlyph = Color(0xFF62666C);
  static const hintDot = Color(0xFFD04B44);

  /// 39's empty arrow is the dark glyph grey, 36's the placeholder grey.
  static const verticalSendIdle = Color(0xFFC9CCCF);

  /// The page under the small player (39).
  static const dim = BiliColors.scrim;

  /// The bar is 42 pt: on the small player and in landscape A is centred 21 pt in, the field runs from 42 pt to 42 pt
  /// short of the far edge and the arrow is centred 21 pt from it, inside the safe areas (22, 39). 竖屏 sets them
  /// wider: A at 24, the field from 48 to 58 short, a larger arrow centred 30.5 pt from the edge (36).
  static const barHeight = 42.0;
  static const aCell = 42.0;
  static const sendCell = 42.0;
  static const verticalACell = 48.0;
  static const verticalSendCell = 55.0;
  static const verticalSendTrailing = 3.0;

  /// 竖屏's bar is a sheet with rounded top corners (36).
  static const verticalBarRadius = 8.5;

  /// The A glyph and its red dot, 9 pt up and right of its middle until A is first pressed (22).
  static const aWidth = 14.6;
  static const aHeight = 17.75;
  static const aStroke = 1.4;
  static const hintDotSize = 5.5;
  static const hintDotOffset = 9.0;

  /// The paper plane, outlined at 1.5 pt; 竖屏's is 18% larger and filled once there is text (36, 37).
  static const sendWidth = 18.0;
  static const sendHeight = 17.5;
  static const sendStroke = 1.5;
  static const verticalSendScale = 1.18;
  static const sendSpinnerRadius = 7.0;

  /// The 30 pt pill: white in landscape, grey on the light bar, with a hairline in 竖屏. Text starts 8 pt in (12 in
  /// 竖屏) behind a 20 pt pink cursor.
  static const fieldHeight = 30.0;
  static const darkField = Color(0xFFFFFFFF);
  static const lightField = BiliColors.pageGrey;
  static const fieldText = BiliColors.text;
  static const fieldFont = 15.0;
  static const fieldPad = 8.0;
  static const verticalFieldPad = 12.0;
  static const placeholder = Color(0xFFC9CCCF);

  /// MiSans sets Chinese a touch wider than the official PingFang: this ends the placeholder where 22's and 36's do.
  static double get placeholderSpacing => BiliFonts.nudged ? -0.15 : 0;

  /// 竖屏's placeholder is smaller and darker than the text it gives way to (36, 37).
  static const verticalPlaceholder = Color(0xFF95999F);
  static const verticalPlaceholderFont = 13.0;
  static const cursorHeight = 20.0;
  static const cursorWidth = 2.0;

  /// The clear ⓧ, centred 15 pt in from the field's end (37).
  static const clearSize = 14.0;
  static const clearCell = 30.0;
  static const clearFill = Color(0xFFC9CCCF);
  static const clearGlyph = Color(0xFFFFFFFF);
  static const clearArm = 2.2;
  static const clearStroke = 1.1;

  /// The keyboard's height in the official shots, which the style panel takes until a keyboard has been seen: 22's
  /// landscape one and 36's portrait one with the home indicator's strip.
  static const landscapePanelHeight = 224.0;
  static const portraitPanelHeight = 347.0;

  /// How long the panel waits for the keyboard it gave way to before going anyway: a hardware keyboard shows none.
  static const keyboardWait = Duration(milliseconds: 600);

  /// The panel: a 64 pt label column 12 pt in, then rows 54 pt apart from 7 pt down in landscape (23) and 12 pt in
  /// portrait (38). Options are 94 pt apart in landscape and 121 pt in portrait.
  static const panelGutter = BiliMetrics.gutter;
  static const panelTop = 7.0;
  static const portraitPanelTop = 12.0;
  static const rowHeight = 54.0;
  static const labelWidth = 64.0;
  static const labelFont = 12.0;
  static double get labelSpacing => BiliFonts.nudged ? -0.4 : 0;
  static const darkSecondary = Color(0xFF95999F);
  static const lightSecondary = Color(0xFF9499A0);
  static const option = 94.0;
  static const portraitOption = 121.0;
  static const optionHeight = 44.0;
  static const optionFont = 13.0;
  static const optionIconLead = 1.5;
  static const optionIconWidth = 21.1;
  static const optionIconHeight = 17.1;
  static const optionIconRadius = 5.5;
  static const optionIconStroke = 1.6;
  static const optionGap = 6.8;
  static const sizeGlyphStroke = 1.6;
  static const smallSizeGlyphStroke = 1.4;
  static const modeDot = 0.9;
  static const modeStroke = 1.5;

  /// 弹幕颜色: 26×22 swatches in a ring, one row of 46 pt cells in landscape starting 13 pt into the label column; two
  /// rows 44 pt apart of 49.67 pt cells in portrait, seven then six, starting 14.8 pt into it (23, 38).
  static const swatchCell = 46.0;
  static const swatchLead = -13.0;
  static const portraitSwatchCell = 49.67;
  static const portraitSwatchLead = -14.83;
  static const portraitSwatchesPerRow = 7;
  static const secondSwatchRow = 34.0;
  static const swatchWidth = 26.0;
  static const swatchHeight = 22.0;
  static const swatchRadius = 7.0;
  static const swatchFillRadius = 5.0;
  static const swatchFillInset = 2.2;
  static const swatchRingWidth = 1.4;
  static const lightSwatchRingWidth = 1.1;
  static const darkSwatchRing = Color(0xFF46494C);
  static const lightSwatchRing = Color(0xFFC9CCD0);

  /// The dark picker shows the colours dimmed, in the same order as `DanmakuStyle.colors` (23 against 38).
  static const darkSwatches = [
    Color(0xFFFFFFFF), Color(0xFFD42D25), Color(0xFFFCF150), Color(0xFF42954C), Color(0xFF469DE4), //
    Color(0xFFCF2C7D), Color(0xFF9AC143), Color(0xFF102859), Color(0xFFE6AE48), Color(0xFF613C77), //
    Color(0xFF91BEC9), Color(0xFF8E7A43),
  ];

  /// The 会员 chip: the gradient ring around a white middle, with its pink 会员 pill over the top right corner.
  static const darkVipLeading = Color(0xFFD896D5);
  static const darkVipTrailing = Color(0xFF7AB2E6);
  static const lightVipLeading = Color(0xFFE492D9);
  static const lightVipTrailing = Color(0xFF71B2EA);
  static const vipInsetX = 5.0;
  static const vipInsetY = 4.5;
  static const vipInnerRadius = 4.0;
  static const vipWidth = 24.6;
  static const vipHeight = 20.7;
  static const vipShift = 1.0;
  static const vipBadgeWidth = 22.7;
  static const vipBadgeHeight = 10.3;
  static const vipBadgeFont = 7.0;
  static const vipBadgeX = 8.7;
  static const vipBadgeY = -9.2;
  static const vipBadgeBorder = Color(0xD9FFFFFF);
  static const vipBadgeBorderWidth = 0.5;

  /// The tick on the chosen swatch: a pink 11 pt disc in a white ring over its bottom right corner.
  static const tickSize = 11.0;
  static const tickRing = 1.0;
  static const tickOffset = 0.5;
  static const tickStroke = 1.1;
  static const tickColour = Color(0xFFFFFFFF);
}

/// 当前弹幕列表 (31, 32). Positions across the row count from the panel's content edge, [BiliMetrics.panelTrailing]
/// before the safe area.
abstract final class DanmakuListTheme {
  static DanmakuListThemeColors colorsOf(BuildContext context) => DanmakuListThemeColors(BiliPalette.of(context));

  /// A one-line row is 49 tall; longer text grows it by whole lines, the same 16.3 above and below.
  static const rowPadY = 49 / 3;
  static const rowMinHeight = 49.0;
  static const text = 14.0;
  static const textLine = 49 / 3;
  static const textColor = Color(0xFFFFFFFF);

  /// Between the text's widest and the 👍's box: 31's long danmaku wraps after 15 characters.
  static const textGap = 12.0;

  /// The 👍's ink is 16.5 square (an action icon's ink spans 0.84 of its box), centred 54 in from the
  /// content's edge.
  static const thumbIcon = 16.5 / 0.84;
  static const thumbCentre = 54.0;
  static const thumbTarget = 40.0;

  /// 31's 👍 sits 2 px above the row's middle.
  static const thumbRise = 2 / 3;
  static const thumb = Color(0xFFFFFFFF);
  static const liked = BiliColors.pink;

  /// The count sits off the 👍's top right: its left 1.5 past the ink, its middle 9 above the row's.
  static const countText = 10.0;
  static const countGap = 1.5;
  static const countRise = 9.0;

  static const dividerCentre = 28.8;
  static const dividerWidth = 2 / 3;
  static const dividerHeight = 16.0;
  static const divider = Color(0xFF2F3237);

  /// ⋮: three 8 px dots 16 px apart, centred 3.8 in from the content's edge.
  static const moreCentre = 3.8;
  static const moreDot = 8.6 / 3;
  static const morePitch = 16 / 3;
  static const more = Color(0xFFFFFFFF);

  /// While the popover is up, the other rows fade (32's white text reads 140).
  static const dimmed = 0.53;

  /// 32's popover, one 60.3 wide cell (we offer no 举报): its right edge on the safe area, the arrow under ⋮.
  static const popoverCell = 60.3;
  static const popoverPadX = 7.5;
  static const popoverHeight = 67.3;
  static const popoverRadius = 9.0;
  static const popoverFill = Color(0xF72C2F33);
  static const popoverArrowWidth = 12.0;
  static const popoverArrowHeight = 7.7;

  /// The arrow's tip rises this far into the row above it.
  static const popoverOverlap = 4.0;
  static const popoverIconWidth = 22.0;
  static const popoverIconHeight = 17.8;
  static const popoverIconStroke = 1.3;
  static const popoverIconCentre = 26.0;
  static const popoverLabelCentre = 49.0;
  static const popoverText = 10.0;
  static const popoverInk = Color(0xFFFFFFFF);

  static const emptyColor = BiliColors.panelSecondary;

  static TextStyle get textStyle => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: text,
    height: textLine / text,
    color: textColor,
    decoration: TextDecoration.none,
  );

  static TextStyle countStyle(Color color) => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: countText,
    height: 1,
    color: color,
    decoration: TextDecoration.none,
  );

  static TextStyle get popoverStyle => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: popoverText,
    height: 1,
    color: popoverInk,
    decoration: TextDecoration.none,
  );
}

/// 开发者's log tools, in the dev page's own style (no official screen shows it).
abstract final class DevToolsTheme {
  static const crashInk = BiliColors.failure;

  /// Between the log card and the note under it.
  static const footnoteGap = BiliMetrics.rowGap;
}

/// 历史记录 (28).
abstract final class HistoryTheme {
  static HistoryThemeColors colorsOf(BuildContext context) => HistoryThemeColors(BiliPalette.of(context));

  /// The title bar under the status bar, measured on 45 at 3 px per pt: ‹ is #484C52, 7 × 15 with 1.5 strokes, its
  /// tip 26.7 in; 历史记录 is bold and centred. The 🔍, ⋮ and the tab row are left out, so the hairline that ends the
  /// tab row ends the bar.
  static const barHeight = 44.0;
  static const barHairline = 1 / 3;
  static const backTarget = 44.0;
  static const backTipX = 27.0;
  static const backWidth = 7.0;
  static const backHalfHeight = 7.35;
  static const backStroke = 1.4;
  static const backDrop = -0.33;
  static const back = Color(0xFF484C52);
  static const titleText = 20.0;
  static const titleWeight = FontWeight.w600;

  /// Every other word on the page and its sheet is regular (45, 47, 48).
  static const textWeight = FontWeight.w400;

  /// MiSans sets 历史记录 1 pt lower in the bar than 45's.
  static double get titleDrop => BiliFonts.nudged ? -1 : 0;

  /// 今天, 昨天 and 更早: 46 tall, pinned while their rows scroll under them.
  static const headerHeight = 46.0;
  static const headerText = 16.0;
  static const headerInset = 12.0;

  /// Where the title's box starts, which puts its ink 21.3 below the header's top as on 45.
  static const headerTextTop = 20.5;

  /// A row is 100: the 136 × 76 cover 12 down, then a hairline (none after a section's last row) from the gutter
  /// to the right edge.
  static const rowHeight = 100.0;
  static const rowPadTop = 12.0;
  static const gutter = 12.0;
  static const coverWidth = 136.0;
  static const coverHeight = 76.0;
  static const coverRadius = 14 / 3;
  static const textGap = 9.0;
  static const hairline = 1 / 3;
  static const divider = BiliColors.divider;

  /// The title: two lines 19.3 apart.
  static const rowTitleText = 14.0;
  static const rowTitleLine = 58 / 3;
  static const rowTitleTop = -1.27;

  /// Where a title wraps: 45's lines end past 420.4 but never reach 422.
  static const titleRight = 18.0;
  static const rowTitle = BiliColors.text;

  /// The UP and device lines, their ink ending level with the cover's bottom.
  static const metaText = 12.0;
  static const metaLine = 16.0;
  static const metaGap = 2.3;
  static const metaBottom = 1.6;

  /// MiSans digits are narrower than PingFang's, so the time would end 9 pt short of 45's.
  static double get timeSpacing => BiliFonts.nudged ? 0.55 : 0;
  static const meta = BiliColors.secondaryText;
  static const glyphBox = 41 / 3;
  static const glyphGap = 3.3;
  static const glyphStroke = 1.0;

  /// The UP glyph's frame and letters.
  static const upWidth = 13.0;
  static const upHeight = 11.2;
  static const upRadius = 2.7;
  static const upLetterWidth = 3.5;
  static const upLetterHeight = 5.0;
  static const upDrop = 0.5;

  /// The PC's screen and stand, and the phone with its notch and bar.
  static const pcWidth = 13.2;
  static const pcHeight = 9.5;
  static const pcRadius = 2.3;
  static const pcBaseWidth = 5.8;
  static const pcStand = 2.0;
  static const phoneWidth = 8.7;
  static const phoneHeight = 12.0;
  static const phoneRadius = 2.3;
  static const phoneNotch = 3.0;
  static const phoneBar = 2.0;
  static const phoneMark = 1.2;
  static const pcStandStroke = 1.6;

  /// ⋮: three 2 pt dots 4.3 apart, centred 20 from the right and on the device line.
  static const moreDot = 2.0;
  static const morePitch = 13 / 3;
  static const moreCentreRight = 20.0;
  static const moreTarget = 44.0;
  static const more = Color(0xFFC9CCCF);

  /// The time on the cover: a 14 tall pill of half black, 3.7 from the right and 4 from the bottom.
  static const pillText = 11.0;

  /// MiSans digits stand taller and wider than the official app's; this size matches 45's ink.
  static double get pillFont => BiliFonts.nudged ? 10.5 : pillText;
  static const pillHeight = 14.0;
  static const pillPadX = 14 / 3;
  static const pillRight = 11 / 3;
  static const pillBottom = 4.0;
  static const pillRadius = 2.0;
  static const pillFill = BiliColors.coverShade;
  static const pillInk = BiliColors.onCover;

  /// The pink line along the cover's bottom; a few seconds in still shows this much of it.
  static const progressHeight = 2.0;
  static const progressMin = 23 / 3;
  static const progress = Color(0xFFEA6E96);

  /// The page's own states: logged out, empty, failed.
  static const stateText = 15.0;
  static const stateGap = 16.0;
  static const stateInk = BiliColors.secondaryText;
  static const loginText = 15.0;
  static const loginHeight = 36.0;
  static const loginPadX = 36.0;
  static const retryText = 14.0;
  static const retryPadX = 20.0;
  static const retryHeight = 30.0;
  static const buttonWeight = FontWeight.w500;
  static const footerText = 12.0;
  static const footerPad = 16.0;
  static const footerInk = Color(0xFFC9CCD0);
  static const spinnerRadius = 10.0;

  /// ⋮'s sheet (48): the page dimmed to 30 %, a white sheet 291 tall over the home indicator's inset.
  static const sheetDim = Color(0xB3000000);
  static const sheetIn = Duration(milliseconds: 280);
  static const sheetOut = Duration(milliseconds: 220);
  static const sheetFill = BiliColors.card;
  static const sheetHeaderHeight = 44.0;
  static const sheetHeaderText = 14.0;
  static const sheetHeaderInset = 12.7;
  static const sheetHeaderInk = Color(0xFF505050);
  static const sheetItemCentre = 33.0;
  static const sheetCircle = 44.0;
  static const sheetCircleFill = BiliColors.pink;
  static const sheetCircleGlyph = BiliColors.onPink;
  static const sheetShareGlyphWidth = 17.0;
  static const sheetShareGlyphHeight = 20.0;
  static const sheetShareStroke = 1.6;
  static const sheetLabelText = 12.0;
  static const sheetLabelGap = 6.0;
  static const sheetLabelInk = Color(0xFF999999);
  static const sheetItemWidth = 66.0;
  static const sheetShareBottom = 127.0;
  static const sheetDivider = 1.0;
  static const sheetDividerInk = BiliColors.divider;

  /// 删除: the trash glyph centred 42 below the divider, its label under it.
  static const sheetDeleteHeight = 102.7;
  static const sheetTrashWidth = 30.0;
  static const sheetTrashHeight = 28.0;
  static const sheetTrashTop = 28.0;
  static const sheetTrashStroke = 1.5;
  static const sheetDeleteLabelGap = 14.2;
  static const sheetDeleteInk = Color(0xFF61666D);
  static const sheetBand = 16 / 3;
  static const sheetBandFill = Color(0xFFF4F4F4);
  static const sheetCancelHeight = 55.0;
  static const sheetCancelText = 16.0;
  static const sheetCancelInk = Color(0xFF505050);

  /// MiSans sets its text higher in the line than PingFang; this brings the sheet's words level with 48's.
  static double get sheetTextDrop => BiliFonts.nudged ? 1.5 : 0;
}

/// The login page and its bar.
abstract final class LoginTheme {
  static LoginThemeColors colorsOf(BuildContext context) => LoginThemeColors(BiliPalette.of(context));

  /// No official screenshot shows this frame: it keeps 设置's white bar, and Bilibili's own page fills the rest.
  static const bar = BiliColors.card;
  static const page = BiliColors.card;
  static const title = BiliColors.text;
  static const titleText = BiliMetrics.titleText;

  /// The ✕ that closes the page, in a 44 pt target.
  static const close = BiliColors.text;
  static const closeIcon = 24.0;
  static const closeTarget = 44.0;

  static const spinnerRadius = 14.0;

  /// 请在手机上登录, a load error or a login that didn't take, with 重试 under the last two; the QR login's messages
  /// too.
  static const message = BiliColors.secondaryText;
  static const messageText = BiliMetrics.bodyText;
  static const inset = BiliMetrics.sectionGap;
  static const gap = BiliMetrics.rowGap;
  static const retry = BiliColors.pink;
  static const retryHeight = BiliMetrics.pillHeight;
  static const retryPadX = BiliMetrics.sectionGap;

  static TextStyle get titleStyle => TextStyle(fontFamily: BiliFonts.family, fontSize: titleText, color: title);

  static TextStyle get messageStyle => TextStyle(fontFamily: BiliFonts.family, fontSize: messageText, color: message);

  static TextStyle get retryStyle => TextStyle(fontFamily: BiliFonts.family, fontSize: messageText, color: retry);

  /// The PC's QR login (`qr_login.dart`), which the official app has no screen for: the code centred on the white
  /// page with a quiet zone of about 4 modules, the message [qrGap] under it.
  static const qrSize = 200.0;
  static const qrQuietZone = 16.0;
  static const qrModule = BiliColors.text;
  static const qrBackground = BiliColors.card;
  static const qrGap = BiliMetrics.sectionGap;

  /// Once scanned, the code steps back while 确认 is waited for on the phone.
  static const qrScannedOpacity = 0.3;
  static const qrFade = Duration(milliseconds: 200);
}

/// 设置's sections beyond 字体, and its confirms: 50 and 51, measured at 3 px per pt.
abstract final class SettingsTheme {
  static SettingsThemeColors colorsOf(BuildContext context) => SettingsThemeColors(BiliPalette.of(context));

  /// The white bar under the status bar, its bold title and the ‹ whose ink starts 79 px in.
  static const bar = BiliColors.card;
  static const barHeight = 44.0;
  static const barTitleText = 20.0;
  static const barTitleWeight = FontWeight.w600;
  static const barTitle = BiliColors.text;

  /// MiSans sits lower than 50's PingFang: the bar's title rides up 1.5 px and the rows' titles 2.5 px.
  static double get barTitleDrop => BiliFonts.nudged ? -1.5 / 3 : 0;
  static double get rowTitleDrop => BiliFonts.nudged ? -2.5 / 3 : 0;
  static const backLeft = 79 / 3;
  static const backGlyphWidth = 25 / 3;
  static const backGlyphHeight = 47 / 3;
  static const backStroke = 1.6;
  static const backGlyph = Color(0xFF484C53);
  static const backTarget = 44.0;

  static const page = BiliColors.pageGrey;
  static const row = BiliColors.card;
  static const rowTitleText = 16.0;
  static const rowTitle = BiliColors.text;
  static const rowDisabled = BiliColors.secondaryText;
  static const value = BiliColors.secondaryText;

  /// The titles and the hairlines under every row, the last included, start 15 pt in; a full-width one tops each
  /// section.
  static const rowInset = 15.0;
  static const hairline = 1 / 3;
  static const hairlineColor = BiliColors.divider;

  /// The grey ›'s ink ends 48 px from the right, the value's 24 px before it.
  static const chevronWidth = 20 / 3;
  static const chevronHeight = 12.0;
  static const chevronStroke = 2.5 / 3;
  static const chevronRight = 47 / 3;
  static const chevron = BiliColors.secondaryText;
  static const valueGap = 7.0;

  /// The BTR 加速 switch, the light sheets' shape.
  static const switchRight = 16.0;
  static const switchOn = BiliColors.pink;
  static const switchOnWeight = FontWeight.w500;
  static const switchOff = FavouriteTheme.switchOffLight;
  static const switchKnob = BiliColors.panelKnob;
  static const switchKnobShadow = FavouriteTheme.knobShadow;
  static const switchKnobShadowBlur = FavouriteTheme.knobShadowBlur;
  static const switchMotion = Duration(milliseconds: 200);

  /// Grey notes under a section: CDN 节点's and the BTR licence.
  static const footerText = 12.0;
  static const footer = BiliColors.secondaryText;
  static const footerTop = 8.0;
  static const footerBottom = 4.0;

  /// 51's alert: 280 pt wide with 8 pt corners over a 70% dim, the title's middle 35.8 pt down, the grey line's
  /// 74.4 pt, a 2 px rule 28 pt below that, and two 44 pt buttons with no rule between them.
  static const confirmWidth = 280.0;
  static const confirmRadius = 8.0;
  static const confirmDim = Color(0xB3000000);
  static const confirm = BiliColors.card;
  static const confirmTitleText = 16.0;
  static const confirmTitleLine = 22.0;
  static const confirmTitleWeight = FontWeight.w500;
  static const confirmTitle = BiliColors.text;
  static const confirmTitleTop = 35.8 - confirmTitleLine / 2;
  static const confirmMessageText = 13.0;
  static const confirmMessageLine = 18.0;
  static const confirmMessage = BiliColors.secondaryText;
  static const confirmMessageGap = 74.4 - 35.8 - (confirmTitleLine + confirmMessageLine) / 2;
  static const confirmMessageBottom = 28.0 - confirmMessageLine / 2;
  static const confirmSide = 20.0;
  static const confirmRule = 2 / 3;
  static const confirmRuleColor = BiliColors.divider;
  static const confirmButtonHeight = 44.0;
  static const confirmButtonText = 16.0;
  static const confirmCancel = BiliColors.text;
  static const confirmAction = BiliColors.pink;
  static const confirmPressed = BiliColors.pressedFill;
  static const confirmPressMotion = Duration(milliseconds: 120);

  /// It comes and goes as the other alerts do, settling from slightly large.
  static const confirmIn = CommentOverlayTheme.confirmIn;
  static const confirmOut = CommentOverlayTheme.confirmOut;
  static const confirmStartScale = FavouriteTheme.alertStartScale;

  /// 大会员 on the 账号 row: the name in pink and the avatar menu's pink pill after it.
  static const vipName = BiliColors.pink;
  static const vipBadge = BiliColors.pink;
  static const vipBadgeLabel = BiliColors.card;
  static const vipBadgePadding = 6.0;
  static const vipBadgeGap = 6.0;
}

/// 首页's bottom bar (01, 02): its height over the home indicator, the hairline above it, the labels.
abstract final class HomeTabBarTheme {
  static HomeTabBarThemeColors colorsOf(BuildContext context) => HomeTabBarThemeColors(BiliPalette.of(context));

  static const bar = BiliColors.card;

  /// 49 pt from the hairline's top to the home indicator's safe area, in five slots of a fifth of the width each.
  static const height = 49.0;
  static const hairline = BiliColors.divider;

  /// One pixel, as 01's: this bar's and the one under the tab row.
  static const hairlineWidth = 1 / 3;

  /// Below the bar's top: a glyph's centre, the pink +'s (centred under the hairline) and a label's line box top.
  static const iconCentre = 18.0;
  static const postCentre = 74 / 3;
  static const labelTop = 94 / 3;
  static const labelText = 11.0;
  static const label = Color(0xFF61666D);
  static const selected = BiliColors.pink;

  /// 首页's search entry beside the avatar (01): 300 pt of the row, ending 76 pt short of the screen's edge, in a
  /// 2 px grey outline; the magnifier's centre and the word's start from the outline's left edge, the word cut
  /// short of the right one.
  static const fieldGap = 11.0;
  static const fieldWidth = 300.0;
  static const fieldOutline = BiliColors.secondaryText;
  static const fieldOutlineWidth = 2 / 3;
  static const fieldGlyph = SearchGlyphTheme.magnifierSize;
  static const fieldGlyphCentre = 18.0;
  static const fieldGlyphRise = 1 / 3;
  static const fieldTextStart = 89 / 3;
  static const fieldTextEnd = 14.0;
  static const fieldText = 15.0;
  static const fieldInk = Color(0xFF61666D);

  /// The 推荐 refresh 首页's tap runs: the scroll back to the top, then the pull-to-refresh TV's room opening.
  static const reloadScroll = Duration(milliseconds: 300);
  static const reloadHeader = Duration(milliseconds: 200);

  /// Once a refresh's cards come (14), from the same frame: [reloadCollapse] closes the room 首页's tap opened for its
  /// TV (a pull's room closes by the scroll's own spring), and over [handOff] the cards on screen fade out over the new
  /// ones, which stand in place at full opacity, with no rise. Fitted to the recording's frames.
  static const reloadCollapse = Duration(milliseconds: 100);
  static const reloadCollapseCurve = Curves.easeInOut;
  static const handOff = Duration(milliseconds: 180);
  static const handOffCurve = Curves.easeOutQuad;

  /// 首页's top dressed by the equipped 装扮 (110): `head_bg` reaches from the screen's top to the top row's bottom
  /// (318 px, where 110's picture meets the tab strip's), `head_tab_bg` fills the tab strip to its hairline, which
  /// takes the page's grey (110's grey starts at 142 pt). The field is filled white with no rim; the avatar, the
  /// field's ink and 推荐's place are 01's.
  static const headDivider = BiliColors.pageGrey;
  static const headField = BiliColors.card;

  /// The bar dressed by the 装扮 (109, 110), its labels where 01's are, in the skin's colours. On both shots every
  /// icon's ink is 41 pt tall (859-900 pt) and centred 19/3 pt under the bar's top, so its 60 × 45 box (fit centre,
  /// as Android's) rises 16 pt over the bar. 发布's picture is centred 88/3 pt under the bar's top, in the stock +'s
  /// square.
  static const skinIconWidth = 60.0;
  static const skinIconHeight = 45.0;
  static const skinIconCentre = 19 / 3;
  static const skinPostCentre = 88 / 3;
  static const skinPostSize = TabIconTheme.postSquare;

  /// How far an icon's box rises over the bar's top. The bar takes taps that high over each icon (pages run under a
  /// dressed bar, so a press on the icon's top would otherwise land on the page), not over the rest of its picture.
  static const skinIconOverhang = skinIconHeight / 2 - skinIconCentre;

  /// With `tail_icon_ani`, each change of place fades the incoming picture in, rising this far into place.
  static const skinIconMotion = Duration(milliseconds: 300);
  static const skinIconRise = 20.0;
}

/// A 推荐 cover still loading (14): the official grey with its faint 小电视, centred on the cover. The asset is cut to
/// its ink, 117 × 109 px at 3× (the clip's is 117 × 110 px of #CDCDCD); it is drawn white and tinted.
abstract final class CoverPlaceholderTheme {
  static CoverPlaceholderThemeColors colorsOf(BuildContext context) => CoverPlaceholderThemeColors(BiliPalette.of(context));

  static const fill = Color(0xFFDEDFE1);
  static const ink = Color(0xFFCDCDCD);
  static const width = 117 / 3;
  static const height = 109 / 3;
}

/// The bottom bar's glyphs (01, 02): their size, strokes and colours, and the + on its pink rounded square.
abstract final class TabIconTheme {
  static TabIconThemeColors colorsOf(BuildContext context) => TabIconThemeColors(BiliPalette.of(context));

  /// The square each line glyph is drawn in. On 01 and 02 every glyph's ink is centred on its column (88 pt wide) at
  /// y 891 pt; the widest, 关注 and 我的, are 21.33 pt.
  static const size = 22.0;

  static const ink = Color(0xFF61666D);
  static const selectedInk = BiliColors.pink;

  /// Outlines; 关注's pinwheel is a touch heavier on both shots.
  static const line = 2.0;
  static const fanLine = 2.1;

  /// 首页's smile or mouth, 我的's eyes and antennae.
  static const faceLine = 1.5;

  /// 发布: a 38 pt square (centred at y 897.67 pt on 01, its top at 878.67) with 14 pt corners, shaded top to bottom,
  /// and a white + 13 pt across with 2.5 pt round-capped strokes.
  static const postSquare = 38.0;
  static const postRadius = 14.0;
  static const postTop = Color(0xFFFE739A);
  static const postBottom = Color(0xFFFF4AA4);
  static const postPlus = 13.0;
  static const postPlusLine = 2.5;
  static const postPlusInk = Color(0xFFFFFFFF);
}

/// 搜索's page (52-55): the field row, the empty page's 热搜, 搜索历史 and 搜索发现, and the suggestions.
abstract final class SearchTheme {
  static SearchThemeColors colorsOf(BuildContext context) => SearchThemeColors(BiliPalette.of(context));

  static const page = BiliColors.card;

  /// Measured on 52-55 at 3 px per pt. Every word on the page is #18191C; the field's grey word, ‹ and 反馈 are
  /// #61666D, the sections' glyphs and 完整榜单 #9499A0.
  static const text = BiliColors.text;
  static const dim = Color(0xFF61666D);
  static const grey = BiliColors.secondaryText;
  static const highlight = BiliColors.pink;

  /// The row under the status bar: ‹ (8.7 × 16.7, its middle 19 in), the 34 tall stadium from 38 to 376 with its
  /// 0.67 grey rim drawn over it (insetting nothing), and 搜索 centred in the 64 after it. The magnifier's ink is
  /// centred 56 in and half a point above the field's middle (its box raised 2/3, as its ink sits low in it); the
  /// word's box starts at 68.
  static const barHeight = 44.0;
  static const backTarget = 38.0;
  static const backWidth = 26 / 3;
  static const backHeight = 50 / 3;
  static const backStroke = 1.5;
  static const fieldHeight = 34.0;
  static const fieldRim = 0.67;
  static const fieldRimColor = BiliColors.secondaryText;
  static const fieldText = 15.0;
  static const fieldLine = 21.0;
  static const magnifierInset = 35 / 3;
  static const magnifier = SearchGlyphTheme.magnifierSize;
  static const magnifierLift = 2 / 3;
  static const magnifierGap = 6.0;
  static const caret = BiliColors.pink;

  /// The grey ⓧ: 13.3 across, its middle 18 from the field's right end, in a 36 wide target.
  static const clear = 40 / 3;
  static const clearColor = Color(0xFFC9CCCF);
  static const clearRight = 18.0;
  static const submitWidth = 64.0;
  static const submitText = 16.0;
  static const submitDrop = 0.5;
  static const submit = BiliColors.pink;

  /// The opening spinner over the page, as 首页's.
  static const openingFill = BiliColors.toastFill;
  static const openingSpinner = BiliColors.panelText;

  /// The empty page's sections: a 14 pt medium title whose middle is 17 down a 34 tall header, its glyphs centred
  /// 73 and 20 (⌄) or 26 (👁) from the right edge with a 1 px #C9CCD0 rule 46.5 in between. Each glyph is pressed in
  /// a 44 wide target. 🗑's box is raised 2/3 and ⌃'s 5/6, where their ink would otherwise sit low (53, 54).
  static const gutter = 12.0;
  static const headerHeight = 34.0;
  static const headerText = 14.0;
  static const headerWeight = FontWeight.w500;
  static const headerLine = 20.0;
  static const headerFirstGlyph = 73.0;
  static const headerRule = 46.5;
  static const headerExpandGlyph = 20.0;
  static const headerEyeGlyph = 26.0;
  static const headerGlyphTarget = 44.0;
  static const trashLift = 2 / 3;
  static const collapseLift = 5 / 6;
  static const ruleWidth = 1 / 3;
  static const ruleHeight = 8.0;
  static const rule = Color(0xFFC9CCD0);
  static const trash = 40 / 3;
  static const expand = 12.0;
  static const refresh = 40 / 3;
  static const eye = 46 / 3;

  /// The words in the sections and the suggestions: 14 pt on a 20 pt line.
  static const wordText = 14.0;
  static const wordLine = 20.0;

  /// bilibili热搜: 1/3 below the bar, then rows 34 tall in two 196 wide columns 24 apart, each word's 14 pt badge 4
  /// after it. 完整榜单 is 12 pt with a 5.3 × 9.3 › 4 after it, ending 15.3 from the right.
  static const hotTop = 1 / 3;
  static const hotRowHeight = 34.0;
  static const hotColumnGap = 24.0;
  static const hotWords = 10;
  static const badge = 14.0;
  static const badgeGap = 4.0;
  static const moreText = 12.0;
  static const moreGap = 4.0;
  static const moreChevronWidth = 16 / 3;
  static const moreChevronHeight = 28 / 3;
  static const moreChevronStroke = 1.2;
  static const moreRight = 46 / 3;

  /// The gap after 热搜's rows, and after the chips or cells of the other sections, before the next title's header.
  static const afterHot = 12.0;
  static const afterList = 61 / 3;

  /// Between a header and its chips or cells.
  static const listTop = 8 / 3;

  /// 搜索历史's chips: 30 tall, 14 in on both sides, 10 apart and 8 between rows, 4 corners; a word is cut with … at
  /// 117 (the chip at 145). Folded it shows two rows (52, 53).
  static const chipHeight = 30.0;
  static const chipPadding = 14.0;
  static const chipSpacing = 10.0;
  static const chipRunSpacing = 8.0;
  static const chipRadius = 4.0;
  static const chipTextMax = 117.0;
  static const chipFill = BiliColors.softGrey;
  static const foldedRows = 2;
  static const historyMotion = Duration(milliseconds: 250);

  /// 搜索发现's cells: two columns 7 apart, 30 tall, 8 between rows, the word 8 in.
  static const cellHeight = 30.0;
  static const cellGap = 7.0;
  static const cellRunSpacing = 8.0;
  static const cellPadding = 8.0;
  static const cellRadius = 4.0;
  static const cellFill = BiliColors.softGrey;
  static const discoveryWords = 12;

  /// A 搜索发现 word's grey "·昨天更新" (52's first cell).
  static const suffix = grey;

  /// The 反馈 pill, 28 under the last cell: 66 × 24 with a 0.67 #C9CCD0 rim, its 14 pt glyph 3 before the 12.5 pt
  /// word.
  static const feedbackTop = 28.0 - afterList;
  static const feedbackWidth = 66.0;
  static const feedbackHeight = 24.0;
  static const feedbackRim = 0.67;
  static const feedbackGlyph = 14.0;
  static const feedbackGap = 3.0;
  static const feedbackText = 12.5;
  static const feedbackBottom = 24.0;
  static const feedbackPressedScale = IntroTheme.followPressedScale;

  /// The pressed 反馈 pill shrinking; chips, cells and words darken with [BiliColors.pressedFill] instead.
  static const pressMotion = Duration(milliseconds: 120);

  /// The suggestions (55): rows 44 tall, each ending in a 1 px #D9DBDE hairline from the gutter to the right edge.
  static const suggestionHeight = 44.0;
  static const suggestionHairline = 1 / 3;
  static const suggestionHairlineColor = Color(0xFFD9DBDE);
}

/// 搜索's results (56, 57, 59-61): the tab row, the video and uploader rows, the ⋮ sheet.
abstract final class SearchResultTheme {
  static SearchResultThemeColors colorsOf(BuildContext context) => SearchResultThemeColors(BiliPalette.of(context));

  static const page = BiliColors.card;

  /// The tab row: 40 under the field row (which ends 106 down, where 55's suggestions start), then a hairline across
  /// the page, lighter than the rows' own. Labels sit in 54 wide slots from the left edge, the shown one 16 and pink,
  /// the others 15 and grey, all on one baseline.
  static const tabRowHeight = 40.0;
  static const hairline = 1 / 3;
  static const hairlineInk = Color(0xFFE3E5E7);
  static const rowHairlineInk = Color(0xFFD9DBDE);
  static const tabSlot = 54.0;
  static const tabText = 15.0;
  static const tabSelectedText = 16.0;
  static const tabBaseline = 77 / 3;
  static const tabInk = Color(0xFF61666D);
  static const tabSelected = BiliColors.pink;
  static const indicatorWidth = 18.0;
  static const indicatorHeight = 3.0;
  static const indicatorTop = 34.0;
  static const tabMotion = Duration(milliseconds: 200);

  /// 筛选's funnel, centred 26 from the right edge and 19.5 down the tab row; pink while 筛选 is open (58).
  static const funnel = 52 / 3;
  static const funnelCentreRight = 26.0;
  static const funnelCentreTop = 19.5;
  static const funnelTarget = 44.0;
  static const funnelInk = tabInk;
  static const funnelOpen = BiliColors.pink;

  /// 用户's 默认排序 and 全部用户 (60), each centred in half the width; on 用户 the hairline runs under this row, not the
  /// tab row.
  static const sortRowHeight = 119 / 3;
  static const sortText = 13.0;
  static const sortInk = tabInk;
  static const sortChevronWidth = 8.0;
  static const sortChevronHeight = 4.4;
  static const sortChevronStroke = 1.1;
  static const sortChevronGap = 4.3;

  /// Rows scrolled this close to the end ask for the next page.
  static const loadAhead = 360.0;

  /// A video row (56, 61): the 172 × 97 cover 12 down, 11.67 under it to the hairline, which runs from the gutter to
  /// the right edge.
  static const gutter = 12.0;
  static const rowPadTop = 12.0;
  static const rowPadBottom = 35 / 3;
  static const coverWidth = 172.0;
  static const coverHeight = 97.0;
  static const coverRadius = 13 / 3;
  static const coverPlaceholder = BiliColors.pageGrey;
  static const textGap = 8.0;

  /// Two title lines 19.33 apart, their first ink 3.3 under the cover's top; they wrap before 422.
  static const titleText = 14.0;
  static const titleLine = 58 / 3;
  static const titleTop = 0.0;
  static const titleRight = 18.0;
  static const titleInk = BiliColors.text;
  static const highlight = BiliColors.pink;

  /// UP and ▷ lines, ink centred 27.33 and 8.5 above the cover's bottom; both glyphs start 1.33 into their 13.67
  /// slot, ▷ 12.67 wide.
  static const metaText = 12.0;
  static const metaLine = 17.0;
  static const metaGap = 2.2;
  static const metaBottom = -0.2;
  static const metaInk = BiliColors.secondaryText;
  static const metaGlyphSlot = 41 / 3;
  static const metaGlyphInset = 4 / 3;
  static const metaGlyph = 38 / 3;
  static const metaGlyphGap = 4.0;

  /// The · between counts has 6.67 clear on each side (56, 60): a space and this much more.
  static const dotSpacing = 5 / 3;

  /// ⋮, centred 16 from the right edge on the ▷ line.
  static const moreCentreRight = 16.0;
  static const moreTarget = 32.0;

  /// The length on the cover: a 14 tall pill 4 in from its right and bottom.
  static const durationText = 10.0;
  static const durationHeight = 14.0;
  static const durationPadX = 8 / 3;
  static const durationRight = 4.0;
  static const durationBottom = 4.0;
  static const durationRadius = 3.0;
  static const durationFill = Color(0x99000000);
  static const durationInk = BiliColors.onCover;

  /// An uploader row (60): 80 with its hairline, inset 12 at both ends; the 48 avatar 16 down, the text 8 after it.
  static const userRowHeight = 80.0;
  static const avatar = 48.0;
  static const avatarTop = 16.0;
  static const userTextGap = 8.0;
  static const nameText = 14.0;
  static const nameInk = BiliColors.text;
  static const nameLine = 20.0;
  static const levelGap = 5.0;
  static const countsText = 12.0;
  static const countsLine = 17.0;
  static const countsInk = BiliColors.secondaryText;

  /// Where each line centres from the avatar's centre, with the counts alone or with the description under them.
  static const nameCentreTwo = -11.17;
  static const countsCentreTwo = 13.0;
  static const nameCentreThree = -18.67;
  static const countsCentreThree = 1.33;
  static const descCentreThree = 20.33;

  /// The bolt disc at the avatar's lower right, ringed in white: yellow for a person, blue for an organisation.
  static const badge = 40 / 3;
  static const badgeRing = 4 / 3;
  static const badgePerson = IntroTheme.badgePerson;
  static const badgeOrganisation = IntroTheme.badgeOrganisation;
  static const badgeBolt = IntroTheme.badgeBolt;

  /// "+ 关注": the pink pill 12 from the right, level with the avatar; followed, 简介's grey 已关注.
  static const followWidth = 70.0;
  static const followHeight = 24.0;
  static const followText = 13.0;
  static const followPlus = 29 / 3;
  static const followPlusStroke = 1.2;
  static const followPlusGap = 13 / 3;
  static const followFill = BiliColors.pink;
  static const followInk = BiliColors.onPink;
  static const followedFill = IntroTheme.followedFill;
  static const followedInk = IntroTheme.followedText;
  static const followPressedScale = IntroTheme.followPressedScale;

  /// 简介's: the fill and words change over [followMotion], the label fading in from [followSwapScale]; a press
  /// shrinks the pill over [followPressMotion].
  static const followMotion = Duration(milliseconds: 220);
  static const followPressMotion = Duration(milliseconds: 120);
  static const followSwapScale = 0.85;
  static const textRight = 12.0;

  /// The next page's spinner, 重试 and 没有找到相关内容.
  static const stateText = 14.0;
  static const stateInk = BiliColors.secondaryText;
  static const stateGap = 16.0;
  static const spinnerRadius = 10.0;
  static const footerPad = 16.0;
  static const retryText = 14.0;
  static const retryHeight = 30.0;
  static const retryPadX = 20.0;
  static const retryRim = 1.0;

  /// Let go with the header part shown, it finishes coming in or going out, whichever is nearer.
  static const headerSnap = Duration(milliseconds: 200);

  /// 筛选's dim over the rows only (58).
  static const filterDim = Color(0x4D000000);
  static const filterMotion = Duration(milliseconds: 220);

  /// ⋮'s sheet (59): the page dimmed, the soft-grey sheet rising to 411.33 tall from the screen's bottom with a 12
  /// corner, white cards 16 in.
  static const sheetDim = Color(0x52000000);
  static const sheetIn = Duration(milliseconds: 280);
  static const sheetOut = Duration(milliseconds: 220);
  static const sheetFill = BiliColors.softGrey;
  static const sheetRadius = 12.0;
  static const sheetInset = 16.0;
  static const grabberTop = 8.0;
  static const grabberWidth = 30.0;
  static const grabberHeight = 3.0;
  static const grabberInk = Color(0xFFC5C6C6);
  static const sheetCardTop = 19.0;
  static const sheetCardHeight = 137 / 3;
  static const sheetCardRadius = 6.0;
  static const sheetCardFill = BiliColors.card;
  static const sheetIcon = 18.0;
  static const sheetIconLeft = 13.0;
  static const sheetIconGap = 9.0;
  static const sheetText = 18.0;
  static const sheetInk = BiliColors.text;
  static const sheetHeaderText = 55 / 3;

  /// The words on the sheet's cards sit this much lower in their boxes than the stand-ins put them (59).
  static const sheetTextDrop = 2 / 3;
  static const sheetHeaderWeight = FontWeight.w600;

  /// A heading's block runs from the card above to its buttons, the words centred 32.67 down it.
  static const sheetHeaderBlock = 172 / 3;
  static const sheetHeaderCentre = 98 / 3;
  static const sheetButtonHeight = 44.0;
  static const sheetButtonGap = 8.0;
  static const sheetBottom = 6.0;

  /// Dragged down this far, or flung, the sheet closes.
  static const sheetDragClose = 0.25;
  static const sheetFlingClose = 700.0;
}

/// 筛选 (58): its chip rows and the dimmed list under it.
abstract final class SearchFilterTheme {
  static SearchFilterThemeColors colorsOf(BuildContext context) => SearchFilterThemeColors(BiliPalette.of(context));

  static const panel = BiliColors.card;

  /// 58's rhythm: the first title's middle 20 below the panel's top, each title's middle 18.67 above its chips and
  /// 24.33 below the chips before it. 58 cuts the panel off under a fade at 450 pt, so the bottom is the space a chip
  /// grid leaves above the next title's ink.
  static const side = BiliMetrics.gutter;
  static const firstTitleMiddle = 20.0;
  static const titleToChips = 56 / 3;
  static const chipsToTitle = 73 / 3;
  static const bottom = 56 / 3;

  static const titleText = 12.0;
  static const title = BiliColors.text;

  /// Four to a row, 99 wide at 440 pt: 58 floors the width to a whole point, leaving 14 on the right.
  static const columns = 4;
  static const chipHeight = 26.0;
  static const chipGap = 6.0;
  static const chipRowGap = 10.0;
  static const chipRadius = 4.0;
  static const chipText = 12.0;

  /// 58 draws 内容时长's digits a pixel further apart than SF and a point further from Chinese; Flutter's SF draws
  /// neither.
  static double get chipLatinSpacing => BiliFonts.nudged ? 0 : 1 / 3;
  static double get chipHanGap => BiliFonts.nudged ? 0 : 1.0;

  /// The chosen chip keeps the same grey; only its label turns the deeper pink of the comment composer's accent.
  static const chip = BiliColors.softGrey;
  static const chipLabel = Color(0xFF62666C);
  static const chipChosenLabel = Color(0xFFED7098);
}

/// 搜索's glyphs (52-60): their strokes.
abstract final class SearchGlyphTheme {
  static const stroke = 1.0;

  /// Each glyph's ink box, the larger side, measured at 3 px per pt: pass it as the icon's size. Strokes below are at
  /// these sizes and scale with them.
  static const magnifierSize = 12.33;
  static const clearSize = 13.33;
  static const trashSize = 13.33;
  static const expandSize = 12.0;
  static const refreshSize = 13.33;
  static const eyeSize = 15.33;
  static const feedbackSize = 14.0;
  static const chevronSize = 9.33;
  static const funnelSize = 16.67;
  static const playSize = 13.33;
  static const plusSize = 9.33;
  static const watchLaterSize = 18.0;

  static const magnifierStroke = 1.5;
  static const clearStroke = 1.1;
  static const funnelStroke = 1.3;
  static const plusStroke = 1.1;
  static const watchLaterStroke = 1.2;
}

/// The official app's loading TV (14, 64, 67).
abstract final class LoadingTvTheme {
  static LoadingTvThemeColors colorsOf(BuildContext context) => LoadingTvThemeColors(BiliPalette.of(context));

  static const size = 60.0;
  static const frame = Duration(milliseconds: 133);

  /// How far a pull goes before it arms.
  static const trigger = 100.0;

  /// 正在努力加载... under the TV on a page's first load (64, 67).
  static const stateText = 14.0;
  static const stateInk = Color(0xFF86898B);

  /// From the TV's box to the text's line box.
  static const stateGap = 6.0;

  /// From the top of a list's area (under 搜索's field row, 历史记录's title bar) to the TV's box (67).
  static const stateTop = 892 / 3;
}

/// The player's 正在缓冲... with its pink TV (65, 66), measured in px / 3: the TV's ink is 64 × 60 px, the Lottie's
/// 24 pt design at 1:1, centred on the video box's centre in both presentations; the line is 14 pt regular white
/// (CJK pitch 40-43 px, digits 30 px tall), with no shadow, its baseline 21.3 pt below the TV's box.
abstract final class PlayerLoadingTheme {
  static const tvSize = 24.0;
  static const text = 14.0;
  static const ink = BiliColors.onVideo;

  /// From the TV's box to the line's box: the system font's baseline lands where the recordings have it.
  static const gap = 6.5;

  /// A wait for data shorter than this shows nothing: the controller's 卡顿 line (`StallFilter.afterMs`), so the TV
  /// shows for exactly the waits the app counts as stalls or slow seeks.
  static const grace = Duration(milliseconds: 750);
}

/// The uploader sheet over the video page's body (62, 68, 76), measured on 68 and 76 at 3 px per pt from the sheet's
/// top, which meets the player box's bottom.
abstract final class UploaderSheetTheme {
  static UploaderSheetThemeColors colorsOf(BuildContext context) => UploaderSheetThemeColors(BiliPalette.of(context));

  static const fill = BiliColors.card;
  static const radius = 12.0;
  static const grabberTop = 8.0;
  static const grabberWidth = 30.0;
  static const grabberHeight = 3.0;
  static const grabber = BiliColors.sheetGrabber;

  static const rise = Duration(milliseconds: 300);
  static const fall = Duration(milliseconds: 220);

  /// Let go dragged down past this share of its height, or flung faster than [flingClose] points a second, the sheet
  /// closes; short of both it springs back over [dragBack].
  static const dragClose = 0.25;
  static const flingClose = 700.0;
  static const dragBack = Duration(milliseconds: 200);

  /// An edge swipe closes it as one closes 评论详情.
  static const edgeCloseShare = CommentOverlayTheme.threadCloseShare;
  static const edgeFlingWidths = CommentOverlayTheme.threadFlingWidths;

  /// The header: the face 16 in and 31 down, the name and its pill on a line centred 35.33 down, the counts on one
  /// 62 down, both 12 after the face; 进入空间 › centred 44 down, its chevron ending 16.33 from the right edge. The
  /// grid starts 77 down.
  static const side = 16.0;
  static const face = 34.0;
  static const faceTop = 31.0;
  static const textGap = 12.0;
  static const nameText = 14.0;
  static const nameWeight = FontWeight.w500;
  static const nameInk = BiliColors.text;
  static const nameLine = 20.0;
  static const nameCentre = 106 / 3;

  /// The name's line ends this far from the right edge, clear of 进入空间.
  static const nameRight = 100.0;
  static const countsText = 12.0;
  static const countsInk = BiliColors.secondaryText;
  static const countsLine = 17.0;

  static const countsCentre = 62.0;
  static const countsGap = 8.5;

  /// The counts fade in once the space answers.
  static const countsFade = Duration(milliseconds: 220);

  /// PingFang sets digits a little apart from the Chinese they meet ("3 万粉丝"); Flutter's layout sets them touching.
  static const countsHanGap = 5 / 3;
  static const enterText = 13.0;
  static const enterInk = Color(0xFF61666D);
  static const enterCentre = 44.0;
  static const enterLine = 18.0;

  /// 进入空间's Chinese draws half a point under its line's middle, where the chevron centres.
  static const enterTextLift = 0.5;
  static const enterRight = 49 / 3;
  static const chevronWidth = 20 / 3;
  static const chevronHeight = 12.0;
  static const chevronStroke = 1.0;
  static const chevronInk = Color(0xFF939393);
  static const chevronGap = 14.0;

  /// The tap target around the face and around 进入空间 ›.
  static const targetPad = 8.0;

  /// + 关注: a 60 × 24 pink pill 9 after the name; followed, 03's grey 已关注.
  static const followGap = 9.0;
  static const followWidth = 60.0;
  static const followHeight = 24.0;
  static const followText = 13.0;
  static const followPlus = 28 / 3;
  static const followPlusStroke = 1.1;
  static const followPlusGap = 4.0;
  static const followedFill = IntroTheme.followedFill;
  static const followedInk = IntroTheme.followedText;
  static const followPressedScale = IntroTheme.followPressedScale;

  /// 简介's: the fill and words change over [followMotion]; a press shrinks the pill over [followPressMotion].
  static const followMotion = SearchResultTheme.followMotion;
  static const followPressMotion = SearchResultTheme.followPressMotion;

  static const gridTop = 77.0;

  /// Two columns of 16:9 covers, 8 from the sides and each other; a card is its cover and 52 under it.
  static const gridSide = 8.0;
  static const gridGap = 8.0;
  static const coverAspect = 16 / 9;
  static const belowCover = 52.0;
  static const coverRadius = 4.0;
  static const coverShadeHeight = 30.0;

  /// The title's two 13 pt lines 15.33 apart (Flutter draws them 15 apart), the first centred 16.17 under the cover.
  static const titleText = 13.0;
  static const titleLine = 46 / 3;
  static const titleTop = 16.17 - titleLine / 2;
  static const titleInk = BiliColors.text;

  /// The page's own video: its title pink after the playing mark, three rounded bars (10, 5.33 and 10 tall, 3.45
  /// apart) 2 in from the title's start and 6 before its text, a little under the line's middle.
  static const playingInk = BiliColors.pink;
  static const barsInk = Color(0xFFEB7093);
  static const barsLead = 2.0;
  static const barsTrail = 6.0;
  static const barsDrop = 0.25;
  static const barWidth = 1.5;
  static const barPitch = 3.45;
  static const barTall = 10.0;
  static const barShort = 16 / 3;

  /// The cover's ▶ count and date at its bottom left, the length at its bottom right: 10 pt white, its digits
  /// centred 11 above the cover's bottom and the ▶ box 11.17, 7.33 in with 3.5 after it and 11 between the count
  /// and the date.
  static const statText = 10.0;
  static const statInk = BiliColors.onCover;
  static const statCentre = 11.5;
  static const statIconDrop = 2 / 3;
  static const statLine = 14.0;
  static const statLeft = 22 / 3;
  static const statRight = 8.0;
  static const statIconWidth = 40 / 3;
  static const statIconHeight = 11.0;
  static const statIconGap = 3.5;
  static const statDateGap = 11.0;

  /// The end of the grid: 已经到底啦~ (76) or the next page's spinner, in a 40 band.
  static const footerHeight = 40.0;
  static const endText = 14.0;
  static const endInk = Color(0xFF727272);
  static const spinnerRadius = 10.0;

  /// The first load's TV, its failure and 重试.
  static const stateText = 14.0;
  static const stateInk = BiliColors.secondaryText;
  static const stateGap = 16.0;
  static const retryText = 14.0;
  static const retryHeight = 30.0;
  static const retryPadX = 20.0;
  static const retryRim = 1.0;
}

/// UP主空间's header, its collapsed bar and its tab row (63, 69-73, 75, 77-79), measured in px / 3 from the screen's
/// top with the header unscrolled.
abstract final class SpaceTheme {
  static SpaceThemeColors colorsOf(BuildContext context) => SpaceThemeColors(BiliPalette.of(context));

  static const page = BiliColors.card;

  /// The banner runs under the status bar to 187.67; a space without one draws this light fill in its place.
  static const bannerHeight = 563 / 3;
  static const bannerDefault = Color(0xFFF3F2F7);

  /// 〈, 私信, search and ⋮: 30 pt discs of black at 30% centred 7 under the safe area's top, 〈 25 from the left and
  /// the others 109, 67 and 25 from the right. Their glyphs are white over the banner and grey on the white bar.
  static const buttonDrop = 7.0;
  static const button = 30.0;
  static const buttonTarget = 44.0;
  static const buttonFill = Color(0x4D000000);
  static const buttonInk = Color(0xFFFFFFFF);
  static const barInk = Color(0xFF61666D);
  static const backCentre = 25.0;
  static const chatCentreRight = 109.0;
  static const searchCentreRight = 67.0;
  static const moreCentreRight = 25.0;

  /// The glyphs' ink boxes and strokes (63, 73). 〈's ink centres 0.83 left of its disc, the magnifier's 0.5 up and
  /// left.
  static const glyphStroke = 1.5;
  static const backGlyphShift = -5 / 6;
  static const searchGlyphShift = -0.5;
  static const backWidth = 23 / 3;
  static const backHeight = 44 / 3;
  static const chatWidth = 16.0;
  static const chatHeight = 46 / 3;
  static const searchSize = 15.0;
  static const moreDot = 8 / 3;
  static const moreStep = 16 / 3;

  /// Scrolled, the white bar (73) covers the status bar and 32 more; it shows once the name passes under the status
  /// bar (77), fading in while the discs fade out.
  static const barRow = 32.0;
  static const bar = Color(0xFFFFFFFF);
  static const barFade = Duration(milliseconds: 150);

  /// The bar's centred pill (73, 77): a 30 tall tint with the 26 pt face 2 in from its left, + 关注 8.33 after it and
  /// 13 clear of the text's ink on the right.
  static const pillHeight = 30.0;
  static const pillFace = 26.0;
  static const pillFaceInset = 2.0;
  static const pillFaceGap = 25 / 3;
  static const pillPadRight = 12.0;
  static const pillFill = Color(0xFFFFECF1);
  static const pillInk = BiliColors.pink;
  static const pillFollowedFill = Color(0xFFF1F2F3);
  static const pillFollowedInk = BiliColors.secondaryText;
  static const pillText = 14.0;
  static const pillPlus = 35 / 3;
  static const pillPlusGap = 4.0;

  /// While the space loads, the bar shows the face and name the tap knew.
  static const loadingNameText = 15.0;
  static const loadingNameGap = 8.0;
  static const loadingNameWidth = 240.0;

  /// The face: an 80 pt picture in a 2 pt white ring, the ring's box 30 from the left and 165.67 down, its badge a
  /// 20 pt disc in its own 2 pt ring flush with the box's lower right (70, 78).
  static const faceLeft = 30.0;
  static const faceTop = 497 / 3;
  static const face = 84.0;
  static const faceRing = 2.0;
  static const faceRingInk = Color(0xFFFFFFFF);
  static const faceBadge = 24.0;

  /// 粉丝 | 关注 | 获赞: three equal columns from 153.5 to 9.5 short of the right edge with 1 pt rules between them,
  /// the count's ink centred 202.5 down and the label's 220.5.
  static const statsLeft = 153.5;
  static const statsRight = 9.5;
  static const countCentre = 202.5;
  static const countLine = 18.0;
  static const countText = 14.0;
  static const countInk = BiliColors.text;
  static const labelCentre = 220.5;
  static const labelLine = 14.0;
  static const labelText = 11.0;
  static const labelInk = BiliColors.secondaryText;
  static const statsRuleTop = 607 / 3;
  static const statsRule = 16.0;
  static const statsRuleWidth = 1.0;
  static const statsRuleInk = BiliColors.divider;

  /// The 关注 row, 30 tall at 232.67 from 156 to 12 short of the right edge: + 关注 pink across what 充电 leaves;
  /// followed, 已关注 (grey) and ▽ (30 square) 2 after it (70). 充电 (83 wide, outlined, 4 before the rest) shows
  /// whenever the uploader takes it (78, 79).
  static const followTop = 698 / 3;
  static const followHeight = 30.0;
  static const followLeft = 156.0;
  static const followRight = 12.0;
  static const followRadius = 4.0;
  static const followText = 14.0;
  static const followFill = BiliColors.pink;
  static const followInk = Color(0xFFFFFFFF);
  static const followPlus = 34 / 3;
  static const followPlusStroke = 1.0;
  static const followPlusGap = 13 / 3;

  /// Each label sits a little right of its button's middle: + 关注 and 已关注 by 0.67, 充电 by 2.33 (63, 70).
  static const followShift = 2 / 3;
  static const chargeShift = 7 / 3;
  static const followedFill = BiliColors.divider;
  static const followedInk = BiliColors.secondaryText;
  static const followedListWidth = 12.0;
  static const followedListHeight = 26 / 3;
  static const followedListStroke = 0.9;
  static const followedListGap = 11 / 3;
  static const chargeWidth = 83.0;
  static const chargeGap = 4.0;
  static const chargeBorder = 1.0;
  static const chargeInk = BiliColors.pink;
  static const chargeBoltWidth = 7.0;
  static const chargeBoltHeight = 12.0;
  static const chargeBoltGap = 6.5;
  static const chargeText = 13.0;
  static const moreWidth = 30.0;
  static const moreGap = 2.0;
  static const moreChevronWidth = 12.0;
  static const moreChevronHeight = 19 / 3;
  static const moreChevronStroke = 1.0;
  static const moreChevronDrop = 5 / 6;

  /// The rows under the face, 12 from the edges: the name's box from 280, 25 tall; the bio's 6.83 under it, 21 tall
  /// (its ink centred 322.83); the tag row's 6.83 under that, 15 tall; the cards 12 under that, 40 tall; then 16 to the
  /// tab row.
  static const gutter = 12.0;
  static const topBlock = 280.0;
  static const nameBox = 25.0;
  static const nameText = 18.0;
  static const nameInk = Color(0xFF2F3238);
  static const nameVipInk = BiliColors.pink;
  static const levelGap = 25 / 3;
  static const vipLabelGap = 22 / 3;
  static const vipLabelHeight = 18.0;
  static const vipLabelWidth = 82.0;

  /// The LV badge, 11.33 tall and 22 wide; 硬核会员's runs 6 further with its bolt. LV4-6 are the space's own
  /// colours, brighter than 评论's (63, 69, 75); LV0-3 have no shot yet and keep 评论's.
  static const levelHeight = 34 / 3;
  static const levelWidth = 22.0;
  static const levelSeniorExtra = 6.0;
  static const levels = [
    Color(0xFFC0C4CC),
    Color(0xFFC0C4CC),
    Color(0xFF8BD29B),
    Color(0xFF7BCDEF),
    Color(0xFFFFB37C),
    Color(0xFFEE672A),
    Color(0xFFF04C49),
  ];
  static const levelInk = Color(0xFFFFFFFF);

  /// bilibili UP主认证's line takes the bio's place and moves the rest down 30 (78): a 22 tall grey pill with the
  /// verification's 16 pt disc 5 in, its bolt 0.44 of the disc wide and 0.62 tall.
  static const officialBlock = 30.0;
  static const officialCentre = 18.5;
  static const officialHeight = 22.0;
  static const officialFill = BiliColors.pageGrey;
  static const officialDisc = 16.0;
  static const officialBoltWidth = officialDisc * 0.44;
  static const officialBoltHeight = officialDisc * 0.62;
  static const officialDiscInset = 5.0;
  static const officialTextGap = 6.0;
  static const officialPadRight = 8.0;
  static const officialText = 12.0;
  static const officialInk = Color(0xFF61666D);

  /// The bio stops short of 详情 even when 详情 is on the line above (69, 78).
  static const bioGap = 41 / 6;
  static const bioBox = 21.0;
  static const bioText = 12.0;
  static const bioInk = BiliColors.secondaryText;
  static const bioRight = 40.0;
  static const detailText = 12.0;
  static const detailInk = BiliColors.link;

  /// IP属地 and the like on one row, 11.33 apart: a 10.33 × 8.67 IP box 1 in, the text's ink 3.33 after it; a link
  /// ends with ›.
  static const tagGap = 41 / 6;
  static const tagBox = 15.0;
  static const tagText = 10.0;
  static const tagInk = Color(0xFF61666D);
  static const tagSpacing = 34 / 3;
  static const tagIconWidth = 31 / 3;
  static const tagIconHeight = 26 / 3;
  static const tagIconInset = 1.0;
  static const tagIconGap = 3.0;
  static const tagIconStroke = 0.9;
  static const tagIconRadius = 2.0;
  static const tagChevronWidth = 10 / 3;
  static const tagChevronHeight = 6.0;
  static const tagChevronGap = 3.0;

  /// 小店 and 充电: 40 tall grey cards, side by side 8 apart when there are two (78), the icon 10 in (小店's bag 12 ×
  /// 10.5), the title 12 pt and the note 11 pt, its ink ending 9 from the right.
  static const entriesGap = 12.0;
  static const entryHeight = 40.0;
  static const entrySpacing = 8.0;
  static const entryRadius = 4.5;
  static const entryFill = BiliColors.softGrey;
  static const entryPad = 10.0;
  static const entryPadRight = 25 / 3;
  static const entryIcon = 12.0;
  static const entryShopHeight = 10.5;
  static const entryBoltWidth = 25 / 3;
  static const entryBoltHeight = 13.0;
  static const entryIconGap = 13 / 3;
  static const entryText = 12.0;
  static const entryTextDrop = 2 / 3;
  static const entryInk = BiliColors.text;
  static const entryNoteText = 11.0;
  static const entryNoteInk = Color(0xFF61666D);
  static const entryIconInk = Color(0xFFFFC200);
  static const bottomGap = 16.0;

  /// The tab row: 39.5 between 0.5 pt hairlines. Its labels sit in equal cells across the width and 4 beyond each
  /// edge (63's five, 78's four, 69's three); the shown one pink over a 14 × 2 bar 4 above the lower hairline.
  static const tabsHairline = 0.5;
  static const tabsBody = 39.5;
  static const tabsHeight = tabsHairline * 2 + tabsBody;
  static const tabsHairlineInk = BiliColors.divider;
  static const tabsSpread = 4.0;
  static const tabText = 16.0;
  static const tabLine = 22.0;
  static const tabInk = Color(0xFF61666D);
  static const tabSelected = BiliColors.pink;
  static const indicatorWidth = 14.0;
  static const indicatorHeight = 2.0;
  static const indicatorBottom = 4.0;

  /// 已关注's sheet (71): rows 50 tall, the second and third with a 0.5 pt rule along their top from 20 in, a 5 pt
  /// gap, then 取消 in a 56 tall row with 14 under it, over the page dimmed by half.
  static const sheetDim = Color(0x80000000);
  static const sheetFill = Color(0xFFFFFFFF);
  static const sheetShadow = Color(0x1F000000);
  static const sheetShadowBlur = 12.0;
  static const sheetRow = 50.0;
  static const sheetRule = 0.5;
  static const sheetRuleInk = Color(0xFFAEB3B9);
  static const sheetInset = 20.0;
  static const sheetText = 14.0;
  static const sheetInk = BiliColors.text;
  static const sheetGap = 5.0;
  static const sheetGapFill = BiliColors.divider;
  static const sheetCancel = 56.0;
  static const sheetCancelText = 16.0;
  static const sheetBottom = 14.0;
  static const sheetIn = Duration(milliseconds: 280);
  static const sheetOut = Duration(milliseconds: 220);

  /// Why the space didn't load, with 点击重试 under it, in the middle of the page.
  static const retryText = 14.0;
  static const retryInk = BiliColors.secondaryText;
  static const retryAction = BiliColors.link;
}

/// 投稿's chips, 播放全部, sort and rows, and a row's ⋮ menu (63, 69, 70, 74). Measured in px / 3 from the tab row's
/// hairline, where the list starts.
abstract final class SpaceVideosTheme {
  static SpaceVideosThemeColors colorsOf(BuildContext context) => SpaceVideosThemeColors(BiliPalette.of(context));

  static const gutter = BiliMetrics.gutter;

  /// The chips (69, 70): 28 tall, 6.33 under the hairline and 12 apart, in a 42 band; 14 pt words about 8 in from each
  /// side, a long title cut with … at [chipMaxText] (70's cut title is 102.7 wide with its …, a glyph more would be
  /// 116.3; between them, so the stand-in's 1 em … fits too). The chosen one is pink on a pink tint, the others
  /// #61666D in a 0.5 hairline rim drawn 0.5 inside the chip's box. A two-glyph chip is 43.8 wide (69's six chips end
  /// at 362.33): the padding gives back what the official app's narrower Chinese (about 0.993 em) leaves.
  static const chipsBlock = 42.0;
  static const chipsTop = 19 / 3;
  static const chipHeight = 28.0;
  static const chipGap = 12.0;
  static const chipPadX = 7.9;
  static const chipMaxText = 110.0;
  static const chipRadius = 4.0;
  static const chipText = 14.0;
  static const chipInk = Color(0xFF61666D);
  static const chipChosenInk = BiliColors.pink;
  static const chipChosenFill = Color(0xFFFFECF1);
  static const chipRim = BiliColors.divider;
  static const chipRimWidth = 0.5;
  static const chipRimInset = 0.5;

  /// 播放全部 and the sort share a strip 27.33 tall, their line 14.33 down it (63's first cover is 37.33 under the
  /// hairline). The ring is 16.67 across from 13.67, its ▶ 5.17 long and 5.67 tall; the words start at 40.
  static const stripHeight = 82 / 3;
  static const stripCentre = 43 / 3;
  static const playAllRing = 50 / 3;
  static const playAllRingLeft = 41 / 3;
  static const playAllStroke = 3.5 / 3;
  static const playAllTriangleLeft = -1.75;
  static const playAllTriangleRight = 2.85;
  static const playAllTriangleHalf = 2.6;
  static const playAllTriangleRound = 0.5;
  static const playAllGlyphInk = BiliColors.pink;
  static const playAllTextLeft = 40.0;
  static const playAllText = 14.0;
  static const playAllInk = BiliColors.text;

  /// ≡ 最新发布: three 12 wide bars 1.33 thick and 4 apart, 3.67 before 12 pt grey words ending 12.33 from the edge.
  static const sortGlyphWidth = 12.0;
  static const sortGlyphBar = 4 / 3;
  static const sortGlyphPitch = 4.0;
  static const sortGlyphInk = Color(0xFF999999);
  static const sortGlyphGap = 11 / 3;
  static const sortText = 12.0;
  static const sortInk = BiliColors.secondaryText;
  static const sortRight = 37 / 3;

  /// A row (63, 69, 70): 93 with its hairline, the 128 × 72 cover 10 down with a 4 corner, then 10 to a 1 pt hairline
  /// from the gutter to the edge.
  static const rowHeight = 93.0;
  static const rowPadTop = 10.0;
  static const rowPadBottom = 10.0;
  static const hairline = 1.0;
  static const hairlineInk = BiliColors.divider;
  static const coverWidth = 128.0;
  static const coverHeight = 72.0;
  static const coverRadius = 4.0;
  static const coverPlaceholder = BiliColors.pageGrey;
  static const textGap = 10.0;

  /// Two 14 pt title lines 18 apart, the first's ink 0.67 under the cover's top; they wrap before 428.
  static const titleText = 14.0;
  static const titleLine = 18.0;
  static const titleTop = -1.88;
  static const titleRight = 12.0;
  static const titleInk = BiliColors.text;

  /// The date and the counts in 11 pt grey, centred 46.67 and 66 under the cover's top. The ▶ box starts 1 in, the
  /// danmaku box 80 after it whatever the plays' width; each number 3 after its 14 × 12 box.
  static const metaText = 11.0;
  static const metaLine = 14.0;
  static const metaInk = BiliColors.secondaryText;
  static const dateCentre = 140 / 3;
  static const countsCentre = 66.0;
  static const countsInset = 1.0;
  static const countGlyphWidth = 14.0;
  static const countGlyphHeight = 12.0;
  static const countGap = 3.0;
  static const danmakuColumn = 80.0;

  /// ⋮ on the counts' line, centred 20 from the edge: 2.33 dots 4.33 apart.
  static const moreCentreRight = 20.0;
  static const moreTarget = 32.0;
  static const moreDot = 7 / 3;
  static const morePitch = 13 / 3;
  static const moreInk = BiliColors.secondaryText;

  /// The length: a 16 tall pill 4 in from the cover's right and 5 up from its bottom, black at half.
  static const durationText = 10.0;
  static const durationHeight = 16.0;
  static const durationPadX = 14 / 3;
  static const durationRight = 4.0;
  static const durationBottom = 5.0;
  static const durationRadius = 2.0;
  static const durationFill = Color(0x80000000);
  static const durationInk = BiliColors.onCover;

  /// 合作 and the like: pink, 16 tall, 4 in from the cover's top right corner.
  static const badgeText = 10.0;
  static const badgeHeight = 16.0;
  static const badgePadX = 4.0;
  static const badgeTop = 4.0;
  static const badgeRight = 4.0;
  static const badgeGap = 4.0;
  static const badgeRadius = 2.0;
  static const badgeFill = BiliColors.pink;
  static const badgeInk = BiliColors.onPink;

  /// Rows scrolled this close to the end ask for the next page.
  static const loadAhead = 360.0;

  /// Under the rows: the next page's small spinner, 已经到底啦~ (76's #727272 14 pt) or the failure, in a 20 line 16
  /// clear of the last hairline. Before the first page: the loading TV, the failure or the end, 40 under the strip.
  static const footerPad = 16.0;
  static const footerLine = 20.0;
  static const spinnerRadius = 10.0;
  static const endText = 14.0;
  static const endInk = Color(0xFF727272);
  static const stateTop = 40.0;
  static const stateText = 14.0;
  static const stateInk = BiliColors.secondaryText;
  static const stateGap = 16.0;

  /// 重试, as 搜索's.
  static const retryHeight = SearchResultTheme.retryHeight;
  static const retryPadX = SearchResultTheme.retryPadX;
  static const retryRim = SearchResultTheme.retryRim;
  static const retryText = SearchResultTheme.retryText;
  static const retryPressedScale = SearchResultTheme.followPressedScale;
  static const retryPressMotion = SearchResultTheme.followPressMotion;

  /// ⋮'s popover (74): the page under black at half; a white box 200 × 104 with a 12 corner, its top 16 under the dots'
  /// centre and its right 15 past it (5 from the screen's edge at most), an arrow 5.33 tall with 45° sides pointing
  /// at the dots. Two 52 rows: pink icons centred 26.83 and 25.67 in, 14 pt words from 44.
  static const menuDim = BiliColors.sheetDim;
  static const menuIn = Duration(milliseconds: 200);
  static const menuOut = Duration(milliseconds: 150);
  static const menuStartScale = 0.85;
  static const menuFill = BiliColors.card;
  static const menuWidth = 200.0;
  static const menuRowHeight = 52.0;
  static const menuRadius = 12.0;
  static const menuGap = 16.0;
  static const menuPastAnchor = 15.0;
  static const menuMargin = 5.0;
  static const menuArrowHeight = 16 / 3;
  static const menuArrowFoot = 0.5;
  static const menuArrowRound = 0.5;

  /// The arrow's tip sits this far right of the dots' centre.
  static const menuArrowShift = 2.5 / 3;
  static const menuText = 14.0;
  static const menuInk = BiliColors.text;
  static const menuTextLeft = 44.0;
  static const menuIconInk = BiliColors.pink;
  static const menuIconSlot = 24.0;
  static const menuWatchLaterCentre = 80.5 / 3;
  static const menuWatchLaterIcon = 55 / 3;
  static const menuShareCentre = 77 / 3;
  static const menuShareIcon = 59.5 / 3;
  static const menuShareStroke = 1.2;

  /// 分享's icon sits a little above its row's middle (74).
  static const menuShareLift = 2.5 / 3;
}

/// 推荐's ⋮ sheet, the card after 不感兴趣 and the reasons sheet (90, 91, 92).
abstract final class FeedDislikeTheme {
  static FeedDislikeThemeColors colorsOf(BuildContext context) => FeedDislikeThemeColors(BiliPalette.of(context));

  /// Both sheets (90, 92): the page dimmed by half, the soft-grey sheet with a 12 corner and its grabber 8 down,
  /// white cards 16 in with an 8 corner, 16 between groups and below the last one.
  static const dim = Color(0x80000000);
  static const sheetIn = Duration(milliseconds: 280);
  static const sheetOut = Duration(milliseconds: 220);
  static const sheetFill = BiliColors.softGrey;
  static const sheetRadius = 12.0;
  static const grabberTop = 8.0;
  static const grabberWidth = 30.0;
  static const grabberHeight = 3.0;
  static const grabberInk = Color(0xFFC9CCD0);
  static const inset = 16.0;
  static const groupGap = 16.0;
  static const sheetBottom = 16.0;
  static const cardFill = BiliColors.card;
  static const cardRadius = 8.0;

  /// Dragged down this far, or flung, a sheet closes.
  static const dragClose = 0.25;
  static const flingClose = 700.0;

  /// 90's rows: 52 tall, the icon's middle 26.67 in from the card's edge and the words 44 in, 14 pt; the hairline
  /// between two rows starts under the words.
  static const menuTop = 19.0;
  static const rowHeight = 52.0;
  static const rowIconCentre = 80 / 3;
  static const rowIconBox = 20.0;
  static const watchLaterIcon = 18.0;

  /// 添加至稍后再看's ring sits a little right of the other icons' middle.
  static const watchLaterShift = 1 / 6;
  static const rowTextLeft = 44.0;
  static const rowText = 14.0;
  static const ink = BiliColors.text;
  static const hairline = 1 / 3;
  static const hairlineInk = BiliColors.divider;

  /// The line drawings' stroke, 90's and 92's.
  static const glyphStroke = 4 / 3;
  static const tileGlyphStroke = 1.5;

  /// 92: 不感兴趣原因 bold 14, its middle 33 below the sheet's top; tiles 4 across from 55 down, 67 tall and 8 apart,
  /// the icon's middle 24 below a tile's top and the label's 51.5, 11 pt grey.
  static const titleCentre = 33.0;
  static const titleText = 14.0;
  static const titleWeight = FontWeight.w600;
  static const tilesTop = 55.0;
  static const tileHeight = 67.0;
  static const tileGap = 8.0;
  static const tileColumns = 4;
  static const tileIconCentre = 24.0;
  static const tileIconBox = 22.0;
  static const tileLabelCentre = 51.5;
  static const tileLabelText = 11.0;
  static const tileLabelInk = Color(0xFF61666D);

  /// 91: the cover blurred under a light shade, a white disc 23.33 across with the ✓ cut out of it, 已减少此类内容推荐
  /// white 13 pt and ↶ 撤销 12 pt in white at 60 %; under the cover, 选择不感兴趣原因 › 14 pt in the middle of the white.
  /// The card keeps its top corners only.
  static const coverBlur = 24.0;
  static const coverShade = Color(0x26000000);
  static const checkDisc = 70 / 3;
  static const checkStroke = 5 / 3;

  /// Middles measured from the cover's middle (the ✓ and the words) and from its bottom (撤销).
  static const checkCentre = -21.5;
  static const messageCentre = 6.5;
  static const messageText = 13.0;
  static const messageInk = Color(0xFFFFFFFF);
  static const undoFromBottom = 20.0;
  static const undoText = 12.0;
  static const undoInk = Color(0x99FFFFFF);
  static const undoGlyphWidth = 26 / 3;
  static const undoGlyphHeight = 9.0;
  static const undoGap = 11 / 3;

  /// ↶ 撤销 sits right of the card's middle, and 选择不感兴趣原因 › left of it, 41.83 below the cover (the middle of
  /// 91's taller card).
  static const undoShift = 3.0;
  static const reasonsCentre = 251 / 6;
  static const reasonsShift = -1.5;
  static const undoGlyphStroke = 1.0;
  static const reasonsText = 14.0;
  static const chevronWidth = 14 / 3;
  static const chevronHeight = 28 / 3;
  static const chevronGap = 11 / 3;
  static const chevronStroke = 1.2;

  static const fadeIn = Duration(milliseconds: 220);
}

/// 我的收藏: the folders, a folder, all videos, a row's ⋮ (80-84), measured at 3 px per pt from the screen's top.
abstract final class FavouritesTheme {
  static FavouritesThemeColors colorsOf(BuildContext context) => FavouritesThemeColors(BiliPalette.of(context));

  static const textWeight = FontWeight.w400;

  /// The bar under the status bar (80, 81, 83): ‹ as 历史记录's, 44 tall.
  static const barHeight = HistoryTheme.barHeight;
  static const backTarget = HistoryTheme.backTarget;
  static const backTipX = HistoryTheme.backTipX;
  static const backWidth = HistoryTheme.backWidth;

  /// 收藏 and 追更 (80, 83): 16 pt regular centred 35.92 either side of the page's middle (0.25 left of it), 收藏 pink
  /// over a 12 × 2 bar 15 under the bar's middle, 追更 black.
  static const tabText = 16.0;
  static const tabLine = 22.0;
  static const tabHalfSpacing = 215.5 / 6;
  static const tabCentreShift = -0.25;
  static const tabWidth = 64.0;
  static const tabInk = BiliColors.text;
  static const tabChosenInk = BiliColors.pink;
  static const tabBarWidth = 12.0;
  static const tabBarHeight = 2.0;
  static const tabBarCentreBelow = 15.0;
  static const tabBarRadius = 1.0;

  /// The chips under the bar: 28 tall, 12 below it and 12 in, 8 apart, 13 pt words 8 in from each side; the chosen
  /// one pink on a pink tint, the other #61666D. The band ends at a #F1F2F3 hairline 157.67 down.
  static const chipsBand = 155 / 3;
  static const chipTop = 12.0;
  static const chipLeft = 12.0;
  static const chipHeight = 28.0;
  static const chipGap = 8.0;
  static const chipPadX = 8.0;
  static const chipRadius = 4.0;
  static const chipText = 13.0;
  static const chipLine = 18.0;
  static const chipInk = Color(0xFF61666D);
  static const chipChosenInk = BiliColors.pink;
  static const chipChosenFill = SpaceVideosTheme.chipChosenFill;
  static const headerHairline = 1 / 3;
  static const headerHairlineInk = BiliColors.pageGrey;

  /// The chip row's glyphs, #61666D with 1.33 lines in 40 wide slots ending 2 from the edge (centres 418, 378, 338):
  /// 🔍 15.33 × 15, + 14, the layout's two stacked boxes 15.33 × 16, 83's list 15.33 × 13.67.
  static const toolSlot = 40.0;
  static const toolRight = 2.0;
  static const toolCentreDrop = -0.25;
  static const toolInk = Color(0xFF61666D);
  static const toolStroke = 4 / 3;
  static const toolSearch = 46 / 3;
  static const toolPlus = 14.0;
  static const toolLayoutWidth = 46 / 3;
  static const toolLayoutHeight = 16.0;
  static const toolListWidth = 46 / 3;
  static const toolListHeight = 41 / 3;

  /// The folders (80) on the page's grey: white cards 12 in, 8 under the hairline and 8 apart, with a 12 corner.
  static const page = BiliColors.softGrey;
  static const listTop = 8.0;
  static const cardInset = 12.0;
  static const cardGap = 8.0;
  static const cardRadius = 12.0;
  static const cardFill = BiliColors.card;
  static const cardPad = 12.0;

  /// The title, 16 pt medium, its middle 27 under the card's top; the count 12 pt grey, a lock 12 × 13 and a dot
  /// before it on a private folder, and the › 6.67 × 12 in #C9CCD0 16.67 from the card's right.
  static const cardTitleCentre = 27.0;
  static const cardTitleText = 16.0;
  static const cardTitleLine = 22.0;
  static const cardTitleWeight = FontWeight.w500;
  static const cardTitleInk = BiliColors.text;
  static const cardCountText = 12.0;
  static const cardCountInk = BiliColors.secondaryText;
  static const chevronWidth = 20 / 3;
  static const chevronHeight = 12.0;
  static const chevronRight = 50 / 3;
  static const chevronInk = Color(0xFFC9CCD0);
  static const chevronStroke = 1.2;
  static const chevronGap = 23 / 3;
  static const lockWidth = 12.0;
  static const lockHeight = 13.0;
  static const lockStroke = 1.1;
  static const lockGap = 22 / 3;
  static const dotSize = 5 / 3;
  static const dotGap = 17 / 3;

  /// Three covers 128 × 72, 4 apart with a 6 corner, 50 under the card's top; grey where there's no video. Under
  /// them each title in 12 pt, 5.33 in, its middle 17.83 below; a card ends 16 under the covers, or 41 with titles.
  static const tilesTop = 50.0;
  static const tileWidth = 128.0;
  static const tileHeight = 72.0;
  static const tileGap = 4.0;
  static const tileRadius = 6.0;
  static const tileEmpty = BiliColors.pageGrey;
  static const tileTitleText = 12.0;
  static const tileTitleLine = 17.0;
  static const tileTitleInset = 16 / 3;
  static const tileTitleCentre = 53.5 / 3;
  static const tileTitleInk = BiliColors.text;
  static const cardBottom = 16.0;
  static const cardBottomTitled = 41.0;

  /// + 新建收藏夹: a 34 tall pill 58 under the last card, a 1 pt #E3E5E7 rim; + 11.33 then 12 pt grey words.
  static const newGap = 58.0;
  static const newHeight = 34.0;
  static const newPadLeft = 40 / 3;
  static const newPadRight = 34 / 3;
  static const newRim = 1.0;
  static const newRimInk = BiliColors.divider;
  static const newPlus = 34 / 3;
  static const newPlusStroke = 1.1;
  static const newPlusGap = 4.0;
  static const newText = 12.0;
  static const newLine = 17.0;
  static const newInk = BiliColors.secondaryText;
  static const newBottom = 40.0;

  /// A folder's page (81): the bar's 🔍 18, the multi-select list 18.67 × 16.33 and ⋮'s 3.33 dots 6.67 apart in
  /// #484C52, centred 141, 87 and 32.67 from the right.
  static const folderBarInk = Color(0xFF484C52);
  static const folderBarStroke = 1.5;
  static const folderSearchRight = 141.0;
  static const folderSelectRight = 87.0;
  static const folderMoreRight = 98 / 3;
  static const folderToolDrop = -0.5;
  static const folderToolSlot = 44.0;
  static const folderSearch = 18.0;
  static const folderSelectWidth = 56 / 3;
  static const folderSelectHeight = 49 / 3;
  static const folderMoreDot = 10 / 3;
  static const folderMorePitch = 20 / 3;

  /// Under the bar: the title in 18 pt regular, its middle 27 below the bar; 创建者 and the count in 12 pt grey,
  /// their middles 60.5 and 78.83 below; 20 in. The rows start 102 below the bar.
  static const folderInset = 20.0;
  static const folderTitleText = 18.0;
  static const folderTitleLine = 25.0;
  static const folderTitleCentre = 27.0;
  static const folderMetaText = 12.0;
  static const folderMetaLine = 18.0;
  static const folderMetaInk = BiliColors.secondaryText;
  static const folderOwnerCentre = 60.5;
  static const folderCountCentre = 236.5 / 3;
  static const folderHeader = 102.0;

  /// 点赞, 收藏 and 分享: glyphs centred 132, 82 and 32 from the right and 57.33 below the bar, 10 pt grey words
  /// 80.17 below; 收藏's folder is lighter.
  static const folderActionRights = [132.0, 82.0, 32.0];
  static const folderActionWidth = 50.0;
  static const folderActionGlyphCentre = 172 / 3;
  static const folderActionLabelCentre = 239 / 3;
  static const folderActionText = 10.0;
  static const folderActionLine = 14.0;
  static const folderAddStroke = 1.1;
  static const folderAddDrop = 2 / 3;
  static const folderActionInk = Color(0xFF797F87);
  static const folderActionFaint = Color(0xFFAEB3B9);
  static const folderActionLabelInk = BiliColors.secondaryText;
  /// The thumb's and the arrow's ink widths; the icons are drawn by `ActionIcon`, which sizes by its square.
  static const folderLikeInk = 52 / 3;
  static const folderShareInk = 50 / 3;
  static const folderAddWidth = 50 / 3;
  static const folderAddHeight = 14.0;

  /// A video row (81, 83), 历史记录's: 100 tall, the 136 × 76 cover 12 down, a hairline under every row but the
  /// last; the title in two 14 pt lines; the UP and the counts in 12 pt grey, the danmaku's glyph 10 after the plays.
  static const rowHeight = HistoryTheme.rowHeight;
  static const rowPadTop = HistoryTheme.rowPadTop;
  static const gutter = HistoryTheme.gutter;
  static const coverWidth = HistoryTheme.coverWidth;
  static const coverHeight = HistoryTheme.coverHeight;
  static const coverRadius = HistoryTheme.coverRadius;
  static const coverEmpty = BiliColors.pageGrey;
  static const textGap = HistoryTheme.textGap;
  static const hairline = HistoryTheme.hairline;
  static const divider = HistoryTheme.divider;
  static const rowTitleText = HistoryTheme.rowTitleText;
  static const rowTitleLine = HistoryTheme.rowTitleLine;
  static const rowTitleTop = HistoryTheme.rowTitleTop;
  static const titleRight = HistoryTheme.titleRight;
  static const rowTitleInk = BiliColors.text;
  static const metaText = HistoryTheme.metaText;
  static const metaLine = HistoryTheme.metaLine;
  static const metaGap = HistoryTheme.metaGap + 0.5;
  static const metaBottom = HistoryTheme.metaBottom;
  static const metaInk = HistoryTheme.meta;
  static const glyphBox = HistoryTheme.glyphBox;
  static const glyphGap = HistoryTheme.glyphGap;
  static const countGlyphWidth = BiliMetrics.endCountIconWidth;
  static const countGlyphHeight = BiliMetrics.endCountIconHeight;
  static const countGap = 10.0;

  /// On the counts' line (81, 83) the digits sit a third of a point higher than the UP's name, the glyphs 0.67.
  static const countLift = 1 / 3;
  static const countGlyphLift = 2 / 3;
  static const moreCentreRight = HistoryTheme.moreCentreRight;
  static const moreTarget = HistoryTheme.moreTarget;

  /// The length on the cover, and the pink line of how much was watched (83's, #FA6496).
  static const pillFont = HistoryTheme.pillText;
  static const pillHeight = HistoryTheme.pillHeight;
  static const pillPadX = HistoryTheme.pillPadX;
  static const pillRight = 4.0;
  static const pillBottom = HistoryTheme.pillBottom;
  static const pillRadius = HistoryTheme.pillRadius;
  static const pillFill = HistoryTheme.pillFill;
  static const pillInk = HistoryTheme.pillInk;
  static const progressHeight = HistoryTheme.progressHeight;
  static const progressRadius = 1.0;
  static const progress = Color(0xFFFA6496);

  /// Under the last row (84): 仅展示本App中可查看的稿件 in 12 pt #C9CCD0, its middle 40.5 below the row.
  static const endText = 12.0;
  static const endInk = Color(0xFFC9CCD0);
  static const endLine = 17.0;
  static const endTop = 94 / 3;
  static const endBottom = 95 / 3;

  /// Loading more, a failure and the page's states, as 历史记录's.
  static const footerPad = HistoryTheme.footerPad;
  static const footerText = HistoryTheme.footerText;
  static const footerInk = HistoryTheme.footerInk;
  static const spinnerRadius = HistoryTheme.spinnerRadius;
  static const stateText = HistoryTheme.stateText;
  static const stateGap = HistoryTheme.stateGap;
  static const stateInk = HistoryTheme.stateInk;
  static const loginText = HistoryTheme.loginText;
  static const loginHeight = HistoryTheme.loginHeight;
  static const loginPadX = HistoryTheme.loginPadX;
  static const retryText = HistoryTheme.retryText;
  static const retryPadX = HistoryTheme.retryPadX;
  static const retryHeight = HistoryTheme.retryHeight;
  static const buttonWeight = HistoryTheme.buttonWeight;

  /// Rows scrolled this close to the end ask for the next page.
  static const loadAhead = 360.0;

  /// ⋮'s sheet (82), 历史记录's (48) without its row of other apps: 取消收藏's star, struck through, 26 × 25 and 29
  /// under the sheet's top, its words' ink 70.67 under it; then the band and 取消.
  static const sheetDim = HistoryTheme.sheetDim;
  static const sheetIn = HistoryTheme.sheetIn;
  static const sheetOut = HistoryTheme.sheetOut;
  static const sheetFill = HistoryTheme.sheetFill;
  static const sheetItemCentre = HistoryTheme.sheetItemCentre;
  static const sheetItemWidth = HistoryTheme.sheetItemWidth;
  static const sheetRemoveHeight = HistoryTheme.sheetDeleteHeight;
  static const sheetStarTop = 29.0;
  static const sheetStarWidth = 26.0;
  static const sheetStarHeight = 25.0;
  static const sheetStarStroke = 1.4;
  static const sheetLabelTop = 227 / 3;
  static const sheetLabelText = HistoryTheme.sheetLabelText;
  static const sheetRemoveInk = HistoryTheme.sheetDeleteInk;
  static const sheetBand = HistoryTheme.sheetBand;
  static const sheetBandFill = HistoryTheme.sheetBandFill;
  static const sheetCancelHeight = HistoryTheme.sheetCancelHeight;
  static const sheetCancelText = HistoryTheme.sheetCancelText;
  static const sheetCancelInk = HistoryTheme.sheetCancelInk;
  static double get sheetTextDrop => HistoryTheme.sheetTextDrop;

  /// The layout toggle in 99's list: two rows of a box 7 wide and two bars, the upper one long, 16 × 15.33.
  static const toolLayoutListWidth = 16.0;
  static const toolLayoutListHeight = 46 / 3;

  /// 99's list: a white card per folder, 92 tall with 80's insets; its cover 120 × 66, 13 down, grey when empty; the
  /// title (80's) and the count 142 in, their middles 22.33 and 71.83 down (a private folder's count 0.67 higher, by
  /// its lock).
  static const rowCardHeight = 92.0;
  static const rowCoverTop = 13.0;
  static const rowCoverWidth = 120.0;
  static const rowCoverHeight = 66.0;
  static const rowTextLeft = 142.0;
  static const rowTitleCentre = 67 / 3;
  static const rowCountCentre = 215.5 / 3;
  static const rowPrivateCountLift = 2 / 3;
  static const rowLockInset = 2.0;
  static const rowTitleGap = 8.0;

  /// ▶ 播放: a 52 × 24 pill 12 from the card's right, centred; a rounded ▶ 8.67 × 9.33, 7.67 in and 3.67 before 12 pt
  /// words, #61666D on #F6F7F8. An empty folder's is pale.
  static const playWidth = 52.0;
  static const playHeight = 24.0;
  static const playRight = 12.0;
  static const playPadLeft = 23 / 3;
  static const playGlyphWidth = 26 / 3;
  static const playGlyphHeight = 28 / 3;
  static const playGap = 11 / 3;
  static const playText = 12.0;
  static const playLine = 17.0;
  static const playFill = BiliColors.softGrey;
  static const playInk = Color(0xFF61666D);
  static const playFillOff = Color(0xFFFAFBFB);
  static const playInkOff = Color(0xFFAFB2B6);
  static const playGlyphOff = Color(0xFFD5D6D8);

  /// 创建 (100): the bar's 创建 20 pt bold and centred, 完成 20 pt ending 20 from the edge, grey (#484C53) until there
  /// is a name; white groups on #F1F2F3, 10 apart and 10 under the bar: 封面 64 tall, 名称 44, 简介 144, 公开 44.
  static const newTitleText = 20.0;
  static const newTitleLine = 28.0;
  static const newTitleWeight = FontWeight.w600;

  /// The stand-ins centre Chinese ink on the line's middle; 100's bar words and labels sit a point higher.
  static const formTextLift = 1.0;
  static const newDoneText = 20.0;
  static const newDoneRight = 20.0;
  static const newDoneTarget = 64.0;
  static const newDoneOffInk = Color(0xFF484C53);

  /// Not in 100 (its name is empty): Bilibili's pink, a guess.
  static const newDoneInk = BiliColors.pink;
  static const newPage = BiliColors.pageGrey;
  static const newGroupFill = BiliColors.card;
  static const newGroupGap = 10.0;

  /// 简介's group starts a third of a point lower than the others' gap would put it.
  static const newIntroGap = 31 / 3;
  static const newCoverHeight = 64.0;
  static const newRowHeight = 44.0;
  static const newIntroHeight = 144.0;

  /// Labels 14 pt, 12 in; the fields from 88, 12 short of the edge, their placeholders #AEB3B9. 名称's * is #D0021B.
  /// 简介's label sits with its middle 20.5 under the group's top, its field's first line 22.67.
  static const formText = 14.0;
  static const formLine = 20.0;
  static const formInk = BiliColors.text;
  static const newHintInk = Color(0xFFAEB3B9);
  static const newRequiredInk = Color(0xFFD0021B);
  static const newLabelLeft = 12.0;
  static const newFieldLeft = 88.0;
  static const newFieldRight = 12.0;
  static const newIntroLabelCentre = 20.5;
  static const newIntroFieldCentre = 68 / 3;
  static const newIntroBottom = 12.0;
  static const newTitleMax = 20;
  static const newIntroMax = 200;

  /// 封面's ›, 80's chevron in #999999; a picked cover's 64 × 36 thumbnail 8 before it.
  static const newChevronInk = Color(0xFF999999);
  static const newThumbWidth = 64.0;
  static const newThumbHeight = 36.0;
  static const newThumbRadius = 4.0;
  static const newThumbGap = 8.0;
  static const newThumbBusy = Color(0x66FFFFFF);

  /// 公开's switch, the system's 51 × 31 in #FB7299, 10 from the edge (its 59 × 39 box 6).
  static const newSwitchOn = Color(0xFFFB7299);
  static const newSwitchRight = 6.0;

  /// 封面's sheet (101), the system's: the page dimmed 20%; 8 in, 从相册选择 and 拍照 57 tall on #EFEFEF with a
  /// #B1B1B2 hairline, then 8 apart 取消 alone on white, bold, with 14 corners and the home bar's 34 under it; 23 pt
  /// #D16585 words.
  static const coverSheetDim = Color(0x33000000);
  static const coverSheetMargin = 8.0;
  static const coverSheetRow = 57.0;
  static const coverSheetGap = 8.0;
  static const coverSheetRadius = 14.0;
  static const coverSheetFill = Color(0xFFEFEFEF);
  static const coverSheetCancelFill = BiliColors.card;
  static const coverSheetHairline = 1 / 3;
  static const coverSheetHairlineInk = Color(0xFFB1B1B2);
  static const coverSheetText = 23.0;
  static const coverSheetLine = 28.0;
  static const coverSheetTextDrop = 2 / 3;
  static const coverSheetInk = Color(0xFFD16585);
  static const coverSheetCancelWeight = FontWeight.w600;
}

/// 稍后再看: the list and its empty page (85, 86).
abstract final class WatchLaterTheme {
  static WatchLaterThemeColors colorsOf(BuildContext context) => WatchLaterThemeColors(BiliPalette.of(context));

  static const gutter = 12.0;
  static const ink = BiliColors.text;
  static const grey = Color(0xFF61666D);

  /// Greyed while nothing can be done (85, and the strip in edit mode, 95).
  static const greyOff = Color(0xFFC0C2C5);
  static const pinkOff = Color(0xFFFFC2D6);

  /// The title bar (85, 86): ‹ #61666D, its tip 25.96 in and its ends 8.35 above and below; 稍后再看 17 pt bold and
  /// centred; 管理 (取消管理 in edit mode, 95) 14 pt, its words ending 16.67 from the edge.
  static const barHeight = 44.0;
  static const backTarget = 44.0;
  static const backTipX = 25.96;
  static const backEndX = 33.96;
  static const backHalfHeight = 8.35;
  static const backStroke = 1.45;
  static const titleText = 17.0;
  static const titleWeight = FontWeight.w600;
  static const manageText = 14.0;
  static const manageRight = 50 / 3;

  /// The stand-ins sit 稍后再看 0.5 high and the strip's words 0.5 low against 86.
  static const titleDrop = 0.5;
  static const stripTextLift = 0.5;
  static const chipChosenWeight = FontWeight.w500;

  /// 历史记录's UP glyph sits 0.5 lower in its line than 86's.
  static const upGlyphLift = 0.5;

  /// The strip under the bar, 52 tall and ending in a 0.5 hairline, the list 2/3 under the hairline's top. The chips are
  /// 25.67 tall, 13.33 down, 8 apart, 13 pt words 8 in from each side; the chosen one pink on a pink tint (paler in
  /// edit mode, 95). Its line is 26.17 down the strip.
  static const stripHeight = 52.0;
  static const stripCentre = 157 / 6;
  static const stripHairline = 0.5;
  static const listGap = 2 / 3;
  static const hairlineInk = BiliColors.divider;
  static const chipTop = 40 / 3;
  static const chipHeight = 77 / 3;
  static const chipGap = 8.0;
  static const chipPadX = 8.0;
  static const chipRadius = 3.0;
  static const chipText = 13.0;
  static const chipChosenFill = Color(0xFFFFECF1);
  static const chipChosenFillOff = Color(0xFFFFF7F9);

  /// ≡↑ 最近添加: three bars and a half-headed arrow, 12.67 × 9.67 from 268.33, 4 before 13 pt words; then 23.33 to
  /// ▶ 播放全部, an 11.33 × 12 rounded triangle 6.3 before its words, which end 12.67 from the edge. The stand-in's
  /// Chinese runs about 0.2 a glyph wider, so the gaps here are a little shorter to keep each piece's middle.
  static const sortGlyphWidth = 38 / 3;
  static const sortGlyphHeight = 29 / 3;
  static const sortGlyphStroke = 1.0;
  static const sortGlyphGap = 3.5;
  static const sortText = 13.0;
  static const sortToPlay = 21.5;
  static const playGlyphWidth = 34 / 3;
  static const playGlyphHeight = 12.0;
  static const playGlyphRound = 1.6;
  static const playGlyphGap = 6.3;
  static const playText = 13.0;
  static const playRight = 37 / 3;

  /// A row (86): 98 tall, the 139 × 78 cover 10 down with a 6 corner; text 10 after it. In edit mode (95) everything
  /// moves 34 right for the circle and the title runs to 12 from the edge; out of it the title stops 28 short, so
  /// 86's line breaks where it does.
  static const rowHeight = 98.0;
  static const rowPadTop = 10.0;
  static const coverWidth = 139.0;
  static const coverHeight = 78.0;
  static const coverRadius = 6.0;
  static const coverPlaceholder = BiliColors.pageGrey;
  static const textGap = 10.0;
  static const editShift = 34.0;
  static const editMotion = Duration(milliseconds: 220);

  /// Two 14 pt lines 21.33 apart, the first's middle 8.5 under the cover's top.
  static const titleLineText = 14.0;
  static const titleLine = 64 / 3;
  static const titleTop = -2.5;
  static const titleRight = 28.0;
  static const titleRightEditing = 12.0;

  /// UP and the counts in 12 pt grey, centred 52 and 70 under the cover's top; each glyph 1 in, 13.33 × 11.33, its
  /// words 3.33 after its box; the danmaku glyph 11.33 after the plays.
  static const metaText = 12.0;
  static const metaLine = 16.0;
  static const metaInk = BiliColors.secondaryText;
  static const upCentre = 52.0;
  static const countsCentre = 70.0;
  static const metaInset = 1.0;
  static const glyphBox = 41 / 3;
  static const countGlyphWidth = 40 / 3;
  static const countGlyphHeight = 34 / 3;
  static const glyphGap = 10 / 3;
  static const countsGap = 12.0;

  /// ⋮ on the counts' line, centred 20 from the edge: 2.67 dots 4.33 apart.
  static const moreCentreRight = 20.0;
  static const moreTarget = 44.0;
  static const moreDot = 8 / 3;
  static const morePitch = 13 / 3;
  static const moreInk = Color(0xFFC9CCD0);

  /// watched / total on the cover, 10 pt white with no pill, its digits ending 8 from the right and 7.33 above the
  /// bottom.
  static const progressText = 10.0;
  static const progressRight = 22 / 3;
  static const progressBottom = 4.9;
  static const progressInk = BiliColors.onCover;
  static const progressLineHeight = 1.2;
  static const progressShadow = Color(0x66000000);
  static const progressShadowBlur = 2.0;

  /// The edit-mode circle (95, 96): 21.33 across, centred 23 in; a hairline grey ring, or pink with a white ✓.
  static const circleCentreX = 23.0;
  static const circleSize = 64 / 3;
  static const circleStroke = 1.0;
  static const circleInk = Color(0xFFC9CCD0);
  static const circleChosen = BiliColors.pink;
  static const checkInk = BiliColors.onPink;
  static const checkStroke = 1.2;

  /// 仅展示本App中可查看的稿件 under the last row, 12 pt, centred 37.2 below it.
  static const noteTop = 27.2;
  static const noteLine = 20.0;
  static const noteText = 12.0;
  static const noteInk = Color(0xFFC9CCD0);
  static const loadAhead = 360.0;
  static const spinnerRadius = 10.0;

  /// The empty page (85): the grey TV, its box 120 × 100 from 160 across and 267.33 under the list's top, and
  /// 暂无稍后再看视频哦 14 pt, centred 406.83 under it.
  static const emptyArtTop = 802 / 3;
  static const emptyArtLeft = 160.0;
  static const emptyArtWidth = 120.0;
  static const emptyArtHeight = 100.0;
  static const emptyTextCentre = 1220.5 / 3;
  static const emptyText = 14.0;
  static const emptyInk = BiliColors.secondaryText;
  static const artBody = Color(0xFFEBEDEF);
  static const artShade = Color(0xFFDADCDF);

  /// Logged out and failed: the words and pink buttons 历史记录 uses.
  static const stateText = HistoryTheme.stateText;
  static const stateGap = HistoryTheme.stateGap;
  static const stateInk = HistoryTheme.stateInk;
  static const buttonText = HistoryTheme.loginText;
  static const buttonHeight = HistoryTheme.loginHeight;
  static const buttonPadX = HistoryTheme.loginPadX;
  static const buttonWeight = HistoryTheme.buttonWeight;

  /// 管理's and ⋮'s sheets (93, 94): the page dimmed by 32 % black; a #F6F7F8 sheet with a 12 corner, its grabber 30 × 3
  /// 8 down; one white group 19 down, 16 in from each side, 12 corner, 24 above the home indicator's inset. Rows
  /// 53.44 tall: the 20 pt glyph centred 42 across, 18 pt words from 60, a 0.5 hairline from 60 between rows.
  static const sheetDim = Color(0x52000000);
  static const sheetIn = Duration(milliseconds: 280);
  static const sheetOut = Duration(milliseconds: 220);
  static const sheetFill = BiliColors.softGrey;
  static const sheetRadius = 12.0;
  static const grabberTop = 8.0;
  static const grabberWidth = 30.0;
  static const grabberHeight = 3.0;
  static const grabberInk = Color(0xFFC5C6C6);
  static const groupTop = 19.0;
  static const groupInset = 16.0;
  static const groupRadius = 12.0;
  static const groupBottom = 24.0;
  static const groupFill = BiliColors.card;
  static const actionRowHeight = 481 / 9;
  static const actionGlyphCentre = 42.0;
  static const actionGlyphSize = 20.0;
  static const actionGlyphStroke = 0.95;
  static const actionTextLeft = 60.0;
  static const actionText = 18.0;
  static const actionWeight = FontWeight.w500;
  static const actionHairline = 0.5;
  static const actionHairlineInk = BiliColors.pageGrey;
  static const actionPressed = Color(0x0A000000);
  static const actionIdle = BiliColors.chromeShadeClear;

  /// 复制到 / 移动到's sheet (97, 98): white, 554.67 tall; the 📁 16 × 15 at 12, 24.67 down; 选择收藏夹 22 pt from 34 and
  /// + 新建收藏夹 20 pt grey ending 12 from the edge, centred 32.33 down. The folders from 56.17 down, 61 a row: the
  /// name 20 pt centred 17.33 down (16.83 here: the stand-in sits it 0.5 low), 公开 · N个内容 17 pt grey centred 46.67
  /// down, and a 0.5 hairline 12 in from each side atop every row after the first.
  static const folderSheetHeight = 1664 / 3;
  static const folderSheetFill = BiliColors.card;
  static const folderGrabberInk = Color(0xFFC9CCD0);
  static const folderHeaderCentre = 97 / 3;
  static const folderIconLeft = 12.0;
  static const folderIconTop = 74 / 3;
  static const folderIconWidth = 16.0;
  static const folderIconHeight = 15.0;
  static const folderIconInk = Color(0xFFF3C14A);
  static const folderTitleLeft = 34.0;
  static const folderTitleText = 22.0;
  static const folderNewText = 20.0;
  static const folderNewRight = 12.0;
  static const plusSize = 34 / 3;
  static const plusStroke = 1.2;
  static const plusGap = 5.5;
  static const folderRowsTop = 337 / 6;
  static const folderRowHeight = 61.0;
  static const folderNameCentre = 50.5 / 3;
  static const folderNameText = 20.0;
  static const folderMetaCentre = 140 / 3;
  static const folderMetaText = 17.0;
  static const folderHairline = 0.5;

  /// The edit-mode bar (95, 96): 48 above the home indicator's inset over a 2/3 hairline, a soft shade 31.33 tall
  /// above it; ○ 全选 at the left, 13 pt; 取消选择 / 删除 / 复制到 / 移动到 at the right, 16 apart and ending 12.67 from
  /// the edge, light grey until something is chosen.
  static const editBarHeight = 48.0;
  static const editBarHairline = 2 / 3;
  static const editShadeHeight = 94 / 3;
  static const editShade = Color(0x1A000000);
  static const editShadeClear = BiliColors.chromeShadeClear;
  static const selectAllLeft = 42.0;
  static const editText = 13.0;
  static const editActionGap = 16.0;
  static const editActionRight = 12.67;
  static const editActionOff = Color(0xFFC9CCD0);
}

/// The app token's confirm and 开发者's 官方接口 card.
abstract final class AppAuthTheme {
  static AppAuthThemeColors colorsOf(BuildContext context) => AppAuthThemeColors(BiliPalette.of(context));

  /// The confirm is 设置's alert (51), coming and going as it does there.
  static const promptIn = SettingsTheme.confirmIn;
  static const promptOut = SettingsTheme.confirmOut;

  /// 开发者's state line: 已授权 · 剩 N 天, or 未授权.
  static const status = BiliColors.secondaryText;
  static const statusText = BiliMetrics.smallText;
}

/// The account's own space (108, 115): the tall banner, 编辑资料, the name line's pills, the level's exp bar and the
/// bar scrolled.
abstract final class OwnSpaceTheme {
  static OwnSpaceThemeColors colorsOf(BuildContext context) => OwnSpaceThemeColors(BiliPalette.of(context));

  /// The banner's bottom edge, measured on 108. The face, the counts and 编辑资料 sit where others' spaces have them
  /// (SpaceTheme), [drop] lower.
  static const bannerHeight = 887 / 3;
  static const drop = bannerHeight - SpaceTheme.bannerHeight;
  static const topBlock = SpaceTheme.topBlock + drop;

  /// The 空间头图's label over the banner's foot: a 40 pt band shading from clear at 270 to 60% black at the right edge;
  /// the title (11 pt) set to end 390.67, its last glyph's ink ending 390 as on 108, over the number ending 389.33,
  /// their middles 27.83 and 11.67 above the banner's foot; then a 1 × 10 rule of 40% white 9 after them, its middle
  /// 20 above the foot, and 👕 (17.33 × 15.33 of 1.33 pt line) centred 418 across and 20.33 above the foot.
  static const labelShade = 40.0;
  static const labelShadeLeft = 270.0;
  static const labelShadeClear = Color(0x00000000);
  static const labelShadeInk = Color(0x99000000);
  static const labelTitleRight = 148 / 3;
  static const labelNumberRight = 152 / 3;
  static const labelTitleText = 11.0;
  static const labelTitleLine = 14.0;
  static const labelTitleRise = 83.5 / 3;
  static const labelSubtitleText = 14.0;
  static const labelSubtitleLine = 17.0;
  static const labelSubtitleRise = 35 / 3;

  /// The number's block letters (评论's fan card's): 10 tall, 7.83 wide with 2.1 strokes, 2.5 apart. A subtitle they
  /// can't spell is set in 14 pt bold.
  static const labelNumberHeight = 10.0;
  static const labelNumberWidth = 23.5 / 3;
  static const labelNumberWeight = 2.1;
  static const labelNumberGap = 2.5;
  static const labelInk = Color(0xFFFFFFFF);
  static const labelRuleLeft = 399.0;
  static const labelRule = 1.0;
  static const labelRuleHeight = 10.0;
  static const labelRuleInk = Color(0x66FFFFFF);
  static const labelIconRise = 20.0;
  static const skinRise = 61 / 3;
  static const skinCentre = 418.0;
  static const skinWidth = 52 / 3;
  static const skinHeight = 46 / 3;
  static const skinStroke = 4 / 3;
  static const skinInk = Color(0xFFFFFFFF);
  static const skinTarget = 44.0;

  /// The face's middle, where others' spaces have it. Under a frame it is a 62 pt circle with no ring and the frame
  /// 评论's 1.75 times it; the 大 is a 20 pt disc in a 2 pt white ring, its middle 25.33 right of the face's and 26.67
  /// below. Without a frame the face and its badge are others' (SpaceTheme.face, faceBadge).
  static const faceCentreX = SpaceTheme.faceLeft + SpaceTheme.face / 2;
  static const faceCentreY = SpaceTheme.faceTop + SpaceTheme.face / 2 + drop;
  static const pendantFace = 62.0;
  static const pendantScale = CommentRowTheme.pendantScale;
  static const vipDisc = 20.0;
  static const vipRing = 2.0;
  static const vipRingInk = Color(0xFFFFFFFF);
  static const vipPendantShift = Offset(76 / 3, 80 / 3);

  /// 编辑资料 in place of + 关注: the same box, outlined in 1 pt pink with the label centred.
  static const editTop = SpaceTheme.followTop + drop;
  static const editBorder = 1.0;
  static const editInk = BiliColors.pink;
  static const editFill = SpaceTheme.page;

  /// After the name: the 大会员 label's picture 14.67 tall, 6.67 on; then "+ 成就勋章" and "+ 粉丝勋章", 16 tall
  /// stadiums of 1 pt grey dashes (3 on, 3 off), 6.67 after the label and 6.33 apart, the + (8.67 square) 6.67 in and
  /// the 10 pt words 4.33 after it.
  static const vipLabelGap = 20 / 3;
  static const vipLabelHeight = 44 / 3;
  static const vipLabelMaxWidth = 120.0;
  static const pillGap = 20 / 3;
  static const pillSpacing = 19 / 3;
  static const pillHeight = 16.0;
  static const pillBorder = 1.0;
  static const pillDash = 3.0;
  static const pillDashGap = 3.0;
  static const pillRim = Color(0xFFC9CCD0);
  static const pillPad = 20 / 3;
  static const pillPlus = 26 / 3;
  static const pillPlusGap = 13 / 3;
  static const pillText = 10.0;
  static const pillInk = BiliColors.secondaryText;

  /// The level's row between the name and the bio (37.83 from the name's box to the bio's): the LV badge 10.67 tall
  /// from 13.33, its middle 14.67 down; "14805/28800" in 11 pt grey from 42.33, its line's middle 14.5 down (the
  /// digits' ink 14.83); under them a 2 pt bar 101.67 long from the gutter, 23.67 down, filled in the level's colour
  /// by exp / next.
  static const levelBlock = 227 / 6;
  static const levelLeft = 40 / 3;
  static const levelCentre = 44 / 3;
  static const levelHeight = 32 / 3;
  static const expLeft = 127 / 3;
  static const expCentre = 43.5 / 3;
  static const expText = 11.0;
  static const expLine = 14.0;
  static const expInk = BiliColors.secondaryText;
  static const expBarTop = 71 / 3;
  static const expBarWidth = 305 / 3;
  static const expBarHeight = 2.0;
  static const expTrack = BiliColors.divider;

  /// Scrolled (115): the bar of others' spaces with the name centred in 17 pt, white with the stock look; under a
  /// skin that dresses second pages, the skin's colours.
  static const barName = 17.0;
  static const barNameWidth = 240.0;
  static const bar = SpaceTheme.bar;
  static const barInk = SpaceTheme.barInk;

  /// A skin's light text without a colour of its own.
  static const barLightInk = Color(0xFFFFFFFF);
}

/// The own space's tabs: 主页's sections (114, 115), 收藏 (116), 追番 (117) and 投稿's empty page (108), measured in
/// px / 3 from the tab row's lower hairline, where a tab's body starts.
abstract final class OwnSpaceTabsTheme {
  static OwnSpaceTabsThemeColors colorsOf(BuildContext context) => OwnSpaceTabsThemeColors(BiliPalette.of(context));

  static const gutter = SpaceTheme.gutter;

  /// 主页 and 追番 lie on the page's grey, 收藏 and 投稿 on white; either runs on to the screen's bottom.
  static const greyPage = BiliColors.softGrey;
  static const whitePage = BiliColors.card;

  /// 主页's section header: its line centred 22 down a 44.5 band, the cards under it, then 16.5 to the next band. The
  /// title and its count 14 pt, the count 9 after the title, the eye-slash 8 after the count (9 after a title with
  /// none); 更多 13 pt with its › 9.17 after it, ending 15 from the edge.
  static const headerHeight = 44.5;
  static const headerCentre = 22.0;
  static const headerLine = 20.0;
  static const sectionBottom = 16.5;
  static const titleText = 14.0;
  static const titleInk = BiliColors.text;
  static const countText = 14.0;
  static const countInk = BiliColors.secondaryText;
  static const countGap = 9.0;
  static const eyeGap = 8.0;
  static const eyeWidth = 46 / 3;
  static const eyeHeight = 34 / 3;
  static const eyeStroke = 1.0;
  static const eyeInk = BiliColors.secondaryText;
  static const moreText = 13.0;
  static const moreInk = BiliColors.secondaryText;

  /// 更多's words sit half a point above the header's line, its › on it.
  static const moreLift = 0.5;
  static const moreChevronGap = 55 / 6;
  static const moreChevronWidth = 5.0;
  static const moreChevronHeight = 28 / 3;
  static const moreChevronStroke = 1.1;
  static const moreRight = 15.0;

  /// 收藏's folders and the videos: two white cards a row 10 apart, 173 tall with a 6 corner and a soft shadow, the
  /// cover 126 tall across the top.
  static const pairGap = 10.0;
  static const cardHeight = 173.0;
  static const cardRadius = 6.0;
  static const cardFill = BiliColors.card;
  static const cardShadow = Color(0x1B000000);
  static const cardShadowBlur = 2.0;
  static const cardShadowDrop = 1.0;
  static const coverHeight = 126.0;
  static const coverEmpty = BiliColors.pageGrey;

  /// Under the cover, 10 in: the title 13 pt, its middle 13.33 below (a video's in up to two lines 18 apart); a
  /// folder's "N个内容 · 公开" 12 pt grey, its middle 34.17 below.
  static const cardPadX = 10.0;
  static const cardTitleText = 13.0;
  static const cardTitleLine = 18.0;
  static const cardTitleInk = BiliColors.text;
  static const folderTitleCentre = 40 / 3;
  static const folderCountCentre = 205 / 6;
  static const folderCountText = 12.0;
  static const folderCountLine = 17.0;
  static const folderCountInk = BiliColors.secondaryText;
  static const videoTitleCentre = 40 / 3;

  /// A video's cover darkens over its bottom 46 for the counts: ▶ and the danmaku box (13.33 × 11.33) in white,
  /// 7.33 in, the 11 pt counts 3.67 after each box and the next box 9.75 after the plays; the length ending 6.5 from
  /// the right; all on a line centred 12 above the cover's bottom.
  static const shadeHeight = 46.0;
  static const shade = Color(0x8C000000);
  static const statText = 11.0;
  static const statLine = 14.0;
  static const statCentre = 12.0;
  static const statLeft = 22 / 3;
  static const statRight = 6.5;
  static const statIconWidth = 40 / 3;
  static const statIconHeight = 34 / 3;
  static const statIconGap = 11 / 3;
  static const statGroupGap = 9.75;
  static const statInk = BiliColors.onCover;

  /// A folder without a cover: the TV in a lighter grey, 81.67 × 76.33 and centred (114). 116's rows draw it smaller
  /// and darker.
  static const tvInk = Color(0xFFF6F7F8);
  static const tvWidth = 245 / 3;
  static const tvHeight = 229 / 3;

  /// The folder's badge: a 20 pt square of black at half with a 2.33 corner, 4 in from the cover's lower right (5 up
  /// on 116's rows); the stacked bars and the ▶ card in white.
  static const stackSize = 20.0;
  static const stackRadius = 7 / 3;
  static const stackFill = Color(0x80000000);
  static const stackInk = Color(0xFFFFFFFF);
  static const stackInset = 4.0;

  /// 追番's posters (114, 117): three a row 12 apart, 130.67 × 175 with a 6 corner, darkening over their bottom 47 to
  /// black at 80%; the title 13 pt and the progress 11 pt in white, 5.33 in, their middles 29.5 and 11.33 above the
  /// bottom, the title cut with … 7 short of the right.
  static const posterWidth = 392 / 3;
  static const posterHeight = 175.0;
  static const posterGap = 12.0;
  static const posterRadius = 6.0;
  static const posterEmpty = BiliColors.pageGrey;
  static const posterShadeHeight = 47.0;
  static const posterShade = Color(0xCC000000);
  static const posterInk = BiliColors.onCover;
  static const posterTextLeft = 16 / 3;
  static const posterTextRight = 7.0;
  static const posterTitleText = 13.0;
  static const posterTitleLine = 18.0;
  static const posterTitleCentre = 29.5;
  static const posterProgressText = 11.0;
  static const posterProgressLine = 15.0;
  static const posterProgressCentre = 34 / 3;

  /// 拥有的个性装扮 (115): three cards a row 13 apart, 130 wide with a 6 corner. 115 cuts them off 198 down, the title's
  /// 12 pt ink starting 193.17 down; the 9:16 height, the gradient's 60 and the NO. pill are guesses until a
  /// screenshot shows a card whole.
  static const garbWidth = 130.0;
  static const garbHeight = garbWidth * 16 / 9;
  static const garbGap = 13.0;
  static const garbRadius = 6.0;
  static const garbShadeHeight = 60.0;
  static const garbShade = Color(0xB3000000);
  static const garbInk = BiliColors.onCover;
  static const garbTextLeft = 6.5;
  static const garbTextRight = 6.5;
  static const garbTitleText = 12.0;
  static const garbTitleLine = 17.0;
  static const garbTitleCentre = garbHeight - 198.7;
  static const garbNumberCentre = 14.0;
  static const garbNumberHeight = 14.0;
  static const garbNumberPadX = 4.0;
  static const garbNumberRadius = 2.0;
  static const garbNumberText = 9.0;
  static const garbNumberFill = Color(0x66000000);

  /// The section's cards at most: one row of each.
  static const homeFolders = 2;
  static const homeBangumi = 3;
  static const homeVideos = 2;
  static const homeGarbs = 3;

  /// 收藏 (116): the header 48.33 tall, ^ (12 × 6.33, grey) 14 in, 我创建的收藏夹 14 pt from 36.17 and its count 12
  /// pt grey 8.67 after it; a 1 pt #F6F7F8 band under it and after the last row. Each row 12 under the one before:
  /// the 117 × 73 cover with a 4 corner, the title 14 pt 10 after it, its middle 10 under the cover's top, and the
  /// count 12 pt grey, its middle 64.33 under it.
  static const folderHeaderHeight = 145 / 3;
  static const folderChevronLeft = 14.0;
  static const folderChevronWidth = 12.0;
  static const folderChevronHeight = 19 / 3;
  static const folderChevronStroke = 0.9;
  static const folderChevronInk = BiliColors.secondaryText;
  static const folderChevronTurn = Duration(milliseconds: 200);
  static const folderHeaderTitleLeft = 217 / 6;
  static const folderHeaderTitleText = 14.0;
  static const folderHeaderCountText = 12.0;
  static const folderHeaderCountGap = 26 / 3;
  static const folderBand = 1.0;
  static const folderBandInk = BiliColors.softGrey;
  static const rowGap = 12.0;
  static const rowCoverWidth = 117.0;
  static const rowCoverHeight = 73.0;
  static const rowCoverRadius = 4.0;
  static const rowTextGap = 10.0;
  static const rowTitleText = 14.0;
  static const rowTitleLine = 20.0;
  static const rowTitleCentre = 10.0;
  static const rowCountText = 12.0;
  static const rowCountLine = 17.0;
  static const rowCountCentre = 193 / 3;
  static const rowTvInk = Color(0xFFCCCCCC);
  static const rowTvWidth = 34.0;
  static const rowTvHeight = 33.0;
  static const rowStackBottom = 5.0;

  /// 追番 (117): the posters from 11.33 under the hairline, rows 12 apart; 再怎么找也没有啦 14 pt grey, its middle 21.17
  /// under the last row.
  static const bangumiTop = 34 / 3;
  static const endText = 14.0;
  static const endLine = 20.0;
  static const endInk = BiliColors.secondaryText;
  static const endCentre = 127 / 6;
  static const endBottom = 20.0;

  /// 投稿 with no videos (108): a 48 disc of #F5F7F9 centred 63.33 down with the upload glyph (#61666D, 1.2 lines);
  /// 发布第一个视频，领新人福利 16 pt grey, its middle 120.67 down; 我要投稿, a 140 × 44 pill rimmed 1 pt pink with 16
  /// pt pink words, centred 173.33 down; 去创作中心领奖 12 pt link blue and its › 7 after it, centred 225.83 down.
  static const emptyDisc = 48.0;
  static const emptyDiscFill = Color(0xFFF5F7F9);
  static const emptyDiscCentre = 190 / 3;
  static const uploadInk = Color(0xFF61666D);
  static const uploadStroke = 1.2;
  static const uploadSize = 20.0;
  static const emptyText = 16.0;
  static const emptyLine = 22.0;
  static const emptyInk = BiliColors.secondaryText;
  static const emptyTextCentre = 362 / 3;
  static const uploadPillWidth = 140.0;
  static const uploadPillHeight = 44.0;
  static const uploadPillRim = 1.0;
  static const uploadPillInk = BiliColors.pink;
  static const uploadPillText = 16.0;
  static const uploadPillCentre = 520 / 3;
  static const rewardText = 12.0;
  static const rewardLine = 17.0;
  static const rewardInk = BiliColors.link;
  static const rewardCentre = 677.5 / 3;
  static const rewardChevronGap = 7.0;
  static const emptyBottom = 40.0;

  /// The first load's TV, the next page's small spinner and 加载失败，点击重试, as 我的收藏's.
  static const stateTop = 40.0;
  static const footerPad = FavouritesTheme.footerPad;
  static const footerText = FavouritesTheme.footerText;
  static const footerInk = FavouritesTheme.footerInk;
  static const footerRetryInk = BiliColors.link;
  static const spinnerRadius = FavouritesTheme.spinnerRadius;

  /// Lists scrolled this close to the end ask for the next page.
  static const loadAhead = 360.0;
}

/// The equipped 加载动画 in a refresh, in place of the loading TV (119 and KaiC's 15, 推荐 mid-refresh, measured in
/// px / 3): the header ends at 142 pt and the first card starts at 233.33 pt, so the room the refresh holds open is
/// 85.33 pt under the feed's 6 pt spacing. The picture is drawn whole in the TV's own 60 pt box: Violet's 300 px
/// file draws its chibi 42 × 52 pt there, as the official app does (an 85.33 pt box drew it 57 × 73). The box sits at
/// the room's bottom: the ink ends 6 pt above the spacing in 119.
abstract final class SkinLoadingTheme {
  static const room = 256 / 3;
  static const size = LoadingTvTheme.size;

  /// A pull arms once the whole picture shows, as the official app's starts playing then (KaiC: Violet plays at a
  /// 68 pt pull, ours waited for the TV's 100). Let go short of the room, the refresh holds what was pulled.
  static const trigger = size;

  /// Decoded at most this many pixels a side: the box at the phone's 3×.
  static const decodePixels = 180;

  /// A frame time a file leaves at 0 or 10 ms plays at 100 ms, as browsers play such gifs.
  static const shortestFrame = Duration(milliseconds: 20);
  static const defaultFrame = Duration(milliseconds: 100);
}

/// 首页's header folding its top row away as 推荐 scrolls (121, measured in px / 3).
abstract final class HomeHeaderTheme {
  static HomeHeaderThemeColors colorsOf(BuildContext context) => HomeHeaderThemeColors(BiliPalette.of(context));

  /// The top row (avatar and search) folds away by its own height: the header ends at 142 pt open, 98 pt folded.
  /// All of it moves up by the fold, the 装扮's pictures with it (folded, the screen's top 20 pt show what 44-64 pt
  /// showed open), so the tab row lands under the status bar and the top row fades as it slides under it.
  static const fold = BiliMetrics.topRowHeight;

  /// 推荐 scrolled this far folds it (the first card at the hairline), and back under it opens it again. In 121 the
  /// fold starts in the first frame that scrolled, 6 pt down.
  static const trigger = BiliMetrics.feedSpacing;

  /// 121's frames fit UIKit's ease-in-out over 0.3 s within 0.11 pt (rms over 20 frames).
  static const duration = Duration(milliseconds: 300);
  static const curve = Curves.easeInOut;

  /// The tab row's magnifier, folded: ink 17 pt square from x 412 and y 71 (9 pt under the tab row's top). Its stroke
  /// is 1.83 pt; the search glyph scaled to this size draws 2.1. It rides in from [searchSlide] to the right with the
  /// fold, unfaded, in a [searchTarget] wide tap box at the row's end. The other tabs' grey on white (01's #61666D);
  /// over a 装扮's picture its colour at the other tabs' 72% (121: #393F35 over #D1E1CA under a black 推荐).
  static const searchSize = 52 / 3;
  static const searchRight = 11.0;
  static const searchTop = 26 / 3;
  static const searchTarget = 44.0;
  static const searchSlide = 36.0;
  static const searchInk = Color(0xFF61666D);
  static const skinSearchOpacity = 0.72;
}

/// 推荐's refreshes kept as batches: each refresh's page on top, then 刚刚看到这里，点击刷新, then the cards before it
/// (122, measured in px / 3).
abstract final class FeedBatchTheme {
  static FeedBatchThemeColors colorsOf(BuildContext context) => FeedBatchThemeColors(BiliPalette.of(context));

  /// From the bottom of the cards above to the top of the cards below.
  static const dividerGap = 44.0;

  /// The words and the ⟳ in the app's pink. Both read about rgb(253, 89, 140) at their strongest in the recording,
  /// which takes 12 to 14 off green and blue of a saturated colour: the cards' #FF6633 reason tags read (253, 90, 37).
  static const ink = BiliColors.pink;

  /// 11 glyphs from x 138 to 279.67 pt, 13 pt apart.
  static const text = 13.0;

  /// The APK's `ic_promo_index_refresh` at its own 3× size: 44 px, its ink from x 289.33 to 304 pt.
  static const icon = 44 / 3;
  static const iconGap = 28 / 3;

  /// The words and the icon together sit this far right of the screen's middle and [drop] under the gap's: so each
  /// glyph's ink centre and the icon's (296.38, 731.44) land within a pixel of the recording's.
  static const right = 0.5;
  static const drop = 1 / 3;
}

/// 推荐's big card: the official feed's `large_cover_v9`, full width and playing inline (122; KaiC's screenshot of it
/// playing, measured in px / 3).
abstract final class FeedBigCardTheme {
  static FeedBigCardThemeColors colorsOf(BuildContext context) => FeedBigCardThemeColors(BiliPalette.of(context));

  /// The card spans both columns, inside the feed's side spacing.
  static const spacing = BiliMetrics.feedSpacing;
  static const radius = BiliMetrics.cardRadius;

  /// 6 to 434 pt wide, the video 240.75 pt tall (123, 126).
  static const videoAspect = 16 / 9;

  /// The title band: one line 40.33 pt, two 59.67 (123 and 126), so lines 19.33 apart with 21 above and below them;
  /// the first line's ink 15.33 under the video, a point lower than the strut's middle puts it, so [titleDrop] of the
  /// 21 is above. The ink starts 8.67 in (8 and the glyph's bearing); two-line titles wrap before x 351, 83 pt short of
  /// the card's right.
  static const titleText = BiliMetrics.cardTitleText;
  static const titleLine = 58 / 3;
  static const titlePad = 10.5;
  static const titleDrop = 1.0;
  static const titleInset = BiliMetrics.cardInset;
  static const titleTrailing = 83.0;
  static const title = BiliColors.text;

  /// 👍: the APK's `ic_list_inline_dislike` (its ink 52 of 114 px), its ink 16.72 pt square (x 366.43-383.15 in 123
  /// and 126), centred 59.21 pt from the card's right and 1.6 above the band's middle, #61666D; liked, the APK's
  /// `inline_click_to_like` Lottie in pink. The count hangs off its top right: 10 pt grey ("2.8万" 23.3 pt wide, as
  /// 123's), its ink from 3.25 pt left of the thumb's right edge and 3.83 above its top.
  static const likeInk = 16.72;
  static const likeAssetInk = 52 / 114;
  static const likeRight = 59.21;
  static const likeRise = 1.6;
  static const like = Color(0xFF61666D);
  static const liked = BiliColors.pink;
  static const countText = 10.0;
  static const countOverlap = 3.25;
  static const countTop = 5.43;
  static const count = BiliColors.secondaryText;

  /// The Lottie's thumb at rest is 103 px of its 228 px frame at 3×. Both pictures' ink centre sits 0.77 pt above
  /// their box's at this size.
  static const likeLottieInk = 103 / 228;
  static const likeInkRise = 0.77;

  /// The Lottie's 62 frames at 60 fps.
  static const likeMotion = Duration(milliseconds: 1033);

  /// ⋮ centred 12 pt from the card's right, 0.67 under the band's middle: the small card's glyph.
  static const moreRight = 12.0;
  static const moreDrop = 2 / 3;
  static const moreTarget = 32.0;
  static const likeTarget = 40.0;

  /// The counts over the video (12 pt, the small card's icons): 10.67 pt in, centred 16.5 pt above the video's bottom on
  /// the cover (122) and 15 while it plays (123); the duration 9 pt from the right, on the cover only.
  static const statText = 12.0;
  static const statLead = 32 / 3;
  static const statCentre = 16.5;
  static const statCentrePlaying = 15.0;
  static const statIconGap = BiliMetrics.cardStatIconGap;
  static const statGap = BiliMetrics.cardStatGap;
  static const durationTrail = 9.0;

  /// The cover's ▶: the APK's `bili_player_play` at 54.9 pt wide (its body 46.67 pt, 204 of 240 px), at 77% of its
  /// white, centred on the video (122).
  static const playWidth = 46.67 * 240 / 204;
  static const playOpacity = 0.77;

  /// 弹 and the speaker while it plays, centred 17 pt above the video's bottom and 69.9 and 22.8 pt from the card's
  /// right (123, 126). The speaker is the APK's `ic_volumn_inline_switch_off` / `_on` (72 px with its margins) drawn
  /// 22 pt square; 弹 the player's own glyph.
  static const buttonCentre = 17.0;
  static const danmakuRight = 69.9;
  static const speakerRight = 22.8;
  static const speakerSize = 22.0;
  static const buttonTarget = 40.0;

  /// From the second time round (125, 126): the counts are gone and the buttons at half their white, over 0.2 s.
  static const dimmed = 0.5;
  static const dim = Duration(milliseconds: 200);

  /// The played part along the video's bottom edge, 2 pt of pink (124), nothing under the rest.
  static const progress = 2.0;
  static const progressInk = BiliColors.pink;

  /// The card's video plays only while at least this much of its box is on screen once a scroll comes to rest (KaiC).
  static const visibleToPlay = 0.5;

  /// Paused this long off screen (or under another page), its player is let go; the card starts again where it was.
  static const releaseAfter = Duration(seconds: 30);
}

/// A 动态 card's sizes and colours (127, 128, 135-137, 139), measured in px / 3 from the card's top, which meets the
/// band above it.
abstract final class DynamicCardTheme {
  static DynamicCardThemeColors colorsOf(BuildContext context) => DynamicCardThemeColors(BiliPalette.of(context));

  static const fill = BiliColors.card;
  static const gutter = 12.0;

  /// The 10 pt band under every card (127, 135, 139); a space's 动态 draws it in the lighter grey (136).
  static const band = 10.0;
  static const bandInk = BiliColors.pageGrey;
  static const spaceBandInk = BiliColors.softGrey;

  /// The face: 40 pt, 12 in and 12 down; its verification a 12 pt disc in a 2/3 pt white ring, flush with the face's
  /// lower right (127, 128). 动态's organisation blue is lighter than the video page's.
  static const face = 40.0;
  static const faceTop = 12.0;
  static const badge = 12.0;
  static const badgeRing = 2 / 3;
  static const badgePerson = Color(0xFFFFCC00);
  static const badgeOrganisation = Color(0xFF40C5F1);
  static const badgeBolt = Color(0xFFFFFFFF);

  /// The name (15 pt, pink for 大会员) and under it `pubTime · pubAction` (12 pt grey), 60 in, their Chinese ink
  /// centred 23.5 and 42.67 down. The dot is 2 pt, its ink 7 after the time's ink and 6.67 before the action's: 6.5
  /// and 6.17 from the text boxes.
  static const textLeft = 60.0;
  static const nameText = 15.0;
  static const nameWeight = FontWeight.w500;
  static const nameLine = 21.0;
  static const nameCentre = 23.5;
  static const nameInk = BiliColors.text;
  static const nameVipInk = BiliColors.pink;
  static const timeText = 12.0;
  static const timeLine = 17.0;
  static const timeCentre = 42.67;
  static const timeInk = BiliColors.secondaryText;
  static const timeDot = 2.0;
  static const timeDotBefore = 6.5;
  static const timeDotAfter = 6.17;

  /// The name and time stop this far before the fan card, or ⋮'s box when there is none.
  static const nameClearance = 4.0;

  /// With an avatar frame (136) the face is 26 pt about (40, 32), the frame 评论's 1.75 times it about the same middle;
  /// the name and time start at 75.33, the time 1.5 lower; ⋮ rises 5.5 and the fan card 7, and all under the row
  /// drops 6.5.
  static const pendantFace = 26.0;
  static const pendantScale = CommentRowTheme.pendantScale;
  static const pendantCentreX = 40.0;
  static const pendantCentreY = 32.0;
  static const pendantTextLeft = 226 / 3;
  static const pendantTimeDrop = 1.5;
  static const pendantMoreRise = 5.5;
  static const pendantDecorationRise = 7.0;
  static const pendantDrop = 6.5;

  /// The fan card (127, 139): the art fitted to 77.33 pt wide in a 35 tall box from 21 down, ending 42 from the card's
  /// right; its number in the block letters of 评论's fan card, 5.67 tall, 18.33 down, ending 43 from the box's right
  /// (355 on the phone) however many digits it has. A 1 is 4.33 from its stroke to the next digit's, other digits 6.
  static const decorationRight = 42.0;
  static const decorationTop = 21.0;
  static const decorationWidth = 232 / 3;
  static const decorationHeight = 35.0;
  static const decorationNumberRight = 43.0;
  static const decorationNumberTop = 55 / 3;
  static const decorationGlyphWidth = 14 / 3;
  static const decorationGlyphHeight = 17 / 3;
  static const decorationGlyphWeight = 1.15;
  static const decorationGlyphGap = 4 / 3;
  static const decorationOneAdvance = 13 / 3;
  static const decorationNumberInk = Color(0xFF83BF54);

  /// ⋮: the official icon font's `more-vertical-fill`, 3.33 × 16.67 pt, grey, centred 23.83 from the card's right and
  /// 38.17 down; its tap target 44 square.
  static const moreWidth = 10 / 3;
  static const moreHeight = 50 / 3;
  static const moreRight = 23.83;
  static const moreCentre = 38.17;
  static const moreInk = BiliColors.secondaryText;
  static const moreTarget = 44.0;

  /// The text: 17 pt, its lines 24 apart (128, 136); a 图文 post's in the 关注 feed 26.78 apart (127, 135), set a little
  /// lower under the face. Topics, links and @names in the link blue; at most four lines, then ... 全文 / 展开.
  static const text = 17.0;
  static const textLine = 24.0;
  static const opusTextLine = 80.33 / 3;
  static const textInk = BiliColors.text;
  static const linkInk = BiliColors.link;
  static const maxLines = 4;

  /// Where the text's first line box starts, and the body with no text above it (139: the cover 60 down).
  static const textTop = 57.67;
  static const opusTextTop = 59.5;
  static const bodyTop = 60.0;

  /// From the text's last line box to the body under it: 128's cover starts 12.67 under the last line's ink, 127's
  /// pictures and 135's picture 15.5 under it.
  static const bodyGap = 9.33;
  static const opusBodyGap = 10.5;

  /// A post with nothing under its text: its footer this far under the last line box.
  static const footerGap = 6.0;

  /// Emotes in the text: 20 pt (136), a large one 28.
  static const emote = 20.0;
  static const emoteLarge = 28.0;

  /// The lottery's gift and a video link's ▶ circle, the icon font's, in the link blue (135, 131).
  static const giftWidth = 47 / 3;
  static const giftHeight = 16.0;
  static const giftBefore = 3.0;
  static const giftAfter = 10 / 3;
  static const videoLinkSide = 49 / 3;
  static const videoLinkBefore = 5 / 3;
  static const videoLinkAfter = 4.0;

  /// The pictures: corners of 4 pt; two to four two a row and more three a row, in 119.17 pt cells 1.67 apart (127),
  /// square, or about 3:4 (158.33 tall) for pictures taller than square; one alone at its shape across the width
  /// (135), a tall one two cells wide and at most 3:4. The post page's grid (140) has square third-width cells 6 apart,
  /// two a row for two to four pictures and three a row for more.
  static const pictureRadius = 4.0;
  static const pictureCell = 238.33 / 2;
  static const pictureGap = 5 / 3;
  static const pictureTallest = 475 / 357.5;
  static const pictureWidest = 16 / 9;
  static const detailPictureGap = 6.0;
  static const pictureFill = BiliColors.pageGrey;

  /// The video box (128, 139): 16:9 from 12 to 13 short of the right (415 pt on the phone), corners of 4 pt. On its
  /// bottom left the duration in an 18 pt pill of half black 8 in and 6 up, then the plays and danmaku, 12 pt white
  /// centred on the pill; 动态视频 in a #FB7299 pill 8 from the top right; the APK's `ic_upper_tv_play` 42 pt wide,
  /// 11.83 from the right and 7.67 from the bottom.
  static const videoAspect = 16 / 9;
  static const videoTrail = 13.0;
  static const videoRadius = 4.0;
  static const statText = 12.0;
  static const statInk = BiliColors.onCover;
  static const durationLeft = 8.0;
  static const durationBottom = 6.0;
  static const durationHeight = 18.0;
  static const durationPad = 4.5;
  static const durationRadius = 2.0;
  static const durationFill = Color(0x80000000);
  static const statFirstGap = 26 / 3;
  static const statGap = 34 / 3;

  /// PingFang sets digits apart from the Chinese they meet ("37.1 万播放"); Flutter's layout sets them touching.
  static const statHanGap = 2.0;
  static const shadeHeight = 36.0;
  static const shade = Color(0x4D000000);
  static const badgeInset = 8.0;
  static const badgeHeight = 16.0;
  static const badgeText = 10.0;
  static const badgePad = 4.0;
  static const badgeRadius = 8 / 3;
  static const badgeFill = Color(0xFFFB7299);
  static const badgeInk = Color(0xFFFFFFFF);
  static const tvWidth = 42.0;
  static const tvRight = 11.83;
  static const tvBottom = 7.67;

  /// The TV's white is about 80% opaque on 128; the APK's art is 70%.
  static const tvAlpha = 0.8;
  static const tvArtAlpha = 0.7;

  /// Playing inline (139): the speaker, the 推荐 card's 24 pt art, 7.33 from the right and 8.67 from the bottom; the
  /// played part a 2 pt pink line along the cover's bottom.
  static const speaker = 24.0;
  static const speakerRight = 22 / 3;
  static const speakerBottom = 26 / 3;
  static const speakerTarget = 44.0;
  static const progress = 2.0;
  static const progressInk = BiliColors.pink;

  /// The title under a 投稿视频's box (139): 15 pt, one line, its ink 8 under the cover and the footer 4 under it.
  static const titleText = 15.0;
  static const titleWeight = FontWeight.w500;
  static const titleLine = 21.0;
  static const titleTop = 13 / 3;
  static const titleBottom = 1 / 3;
  static const titleInk = BiliColors.text;

  /// A repost's original (136): a grey block across the card, its @name 15 pt link blue on a line from 14 down, + 关注
  /// 13 pt pink 12 from the right; the original's text 17 pt #61666D, its body under it, 10 under the block's bottom.
  static const repostFill = BiliColors.pageGrey;
  static const repostTop = 14.0;
  static const repostNameText = 15.0;
  static const repostNameLine = 21.0;
  static const repostTextGap = 7.0;
  static const repostTextInk = Color(0xFF61666D);
  static const repostBottom = 10.0;
  static const repostFollowText = 13.0;
  static const repostFollowInk = BiliColors.pink;

  /// + 关注's cross 7 pt square, its strokes 1 pt, 4.5 before 关注; the label sits 0.83 under the name's middle.
  static const repostPlus = 7.0;
  static const repostPlusStroke = 1.0;
  static const repostPlusGap = 4.5;
  static const repostFollowDrop = 5 / 6;
  static const repostFollowPad = 8.0;

  /// The block's top, under the repost's own text (136: 14 under its ink).
  static const repostGap = 10.0;

  /// The original's pictures (136): one row 202 pt tall scrolling sideways, each picture at its own shape with corners
  /// of 6, 6 apart, from the block's inset and off its right edge, 22 under the text's last line box.
  static const repostStrip = 202.0;
  static const repostStripGap = 6.0;
  static const repostStripRadius = 6.0;
  static const repostStripTop = 22.0;

  /// On the post page (132) the block's text and body sit 20 in and its @name 24, so the video box is 400 × 225; the
  /// @name's line 1.33 higher than on the list, the box 44 under the block's top, its title's ink 9.33 under the box
  /// and 15.33 over the block's end.
  static const repostDetailInset = 20.0;
  static const repostDetailNameInset = 24.0;
  static const repostDetailTop = 38 / 3;
  static const repostDetailBodyGap = 31 / 3;
  static const repostDetailTitleTop = 6.0;
  static const repostDetailBottom = 35 / 3;

  /// UP主的推荐 (127, 135): the icon font's lock and the 12 pt grey head centred 18.83 under the pictures; 8.33 under
  /// the head's ink the 80 pt #F6F7F8 box, corners of 5 pt: a 64 pt cover 8 in, the name 14 pt and the brief 12 pt
  /// grey 8 after it, the 56 × 24 pink 去看看 (13 pt white) 8 from the right.
  static const goodsHeadLine = 17.0;
  static const goodsHeadText = 12.0;
  static const goodsHeadInk = BiliColors.secondaryText;
  static const goodsHeadTop = 11.0;
  static const goodsLockLead = 1.0;
  static const goodsLockWidth = 10.0;
  static const goodsLockGap = 16 / 3;
  static const goodsBoxGap = 14 / 3;
  static const goodsBox = 80.0;
  static const goodsFill = BiliColors.softGrey;
  static const goodsRadius = 5.0;
  static const goodsCover = 64.0;
  static const goodsCoverRadius = 2.0;
  static const goodsInset = 8.0;
  static const goodsNameText = 14.0;
  static const goodsNameInk = BiliColors.text;
  static const goodsNameCentre = 30.33;
  static const goodsNameLine = 20.0;
  static const goodsBriefText = 12.0;
  static const goodsBriefLine = 17.0;
  static const goodsBriefInk = BiliColors.secondaryText;
  static const goodsBriefCentre = 53.33;
  static const goodsButtonWidth = 56.0;
  static const goodsButtonHeight = 24.0;
  static const goodsButtonRadius = 5.0;
  static const goodsButtonText = 13.0;
  static const goodsButtonFill = BiliColors.pink;
  static const goodsButtonInk = Color(0xFFFFFFFF);

  /// The footer: 48 tall, three equal columns between the gutters, each its icon and count centred 0.67 pt right of
  /// the column's middle; the APK's icons drawn 16.67, 17.33 and 18 pt wide (135), #61666D, centred 23, 24 and 23
  /// down; the count or word 13 pt, its ink 6 to 6.33 after the icon's (135, 136, 139), centred 24 down. Liked, the
  /// filled thumb and its count pink.
  static const footer = 48.0;
  static const footerText = 13.0;
  static const footerInk = Color(0xFF61666D);
  static const footerLiked = BiliColors.pink;
  static const footerGapToCount = 17 / 3;
  static const footerShift = 2 / 3;
  static const footerCentre = 24.0;
  static const forwardWidth = 50 / 3;
  static const commentWidth = 52 / 3;
  static const likeWidth = 18.0;
  static const forwardCentre = 23.0;
  static const commentCentre = 24.0;
  static const likeCentre = 23.0;

  /// ⋮'s sheet (137): over the page dimmed by half, #F6F7F8 with square corners; rows 50 tall, a hairline (1/3 pt
  /// #E3E5E7) from 20 in under each but the last; the icon font's icons in pink centred about 31 in, the words 14 pt
  /// from 58; a 5 pt #F1F2F3 gap, then 取消 (15 pt) in its own 50 tall row over the home indicator's inset.
  static const sheetDim = Color(0x80000000);
  static const sheetFill = BiliColors.softGrey;
  static const sheetRow = 50.0;
  static const sheetHairline = 1 / 3;
  static const sheetHairlineLeft = 20.0;
  static const sheetHairlineInk = BiliColors.divider;
  static const sheetIconInk = BiliColors.pink;
  static const sheetText = 14.0;
  static const sheetTextLeft = 58.0;
  static const sheetInk = BiliColors.text;
  static const sheetGap = 5.0;
  static const sheetGapFill = BiliColors.pageGrey;
  static const sheetCancelText = 15.0;

  /// Centred in their rows, the labels' ink sits this much higher on 159.
  static const sheetLabelLift = 4 / 3;
  static const sheetCancelLift = 1.0;
  static const sheetCancelInk = Color(0xFF484C53);
  static const sheetIn = Duration(milliseconds: 250);
  static const sheetOut = Duration(milliseconds: 200);

  /// The icons' ink widths and centres: 分享 55 px, 取消关注 52, 举报 56; centred 30.67, 32.17 and 30.83 in, and 1 above,
  /// 0.33 below and 0.67 above the row's middle.
  static const sheetShareWidth = 55 / 3;
  static const sheetUnfollowWidth = 52 / 3;
  static const sheetReportWidth = 56 / 3;
  static const sheetShareCentre = 30.67;
  static const sheetUnfollowCentre = 32.17;
  static const sheetReportCentre = 30.83;
  static const sheetShareRise = 1.0;
  static const sheetUnfollowRise = -1 / 3;
  static const sheetReportRise = 2 / 3;
}

/// The 关注 tab: header, 全部 / 视频, 最常访问, 我的追番 · 追剧 and the face sheet (127, 128, 139), measured in px / 3.
abstract final class DynamicFeedTheme {
  static DynamicFeedThemeColors colorsOf(BuildContext context) => DynamicFeedThemeColors(BiliPalette.of(context));

  /// The header ends 88 pt down on the 62 pt status bar: its 44 pt row lies 18 pt up into the status bar, as the
  /// official app lays it under a 44 pt one. 关注 is centred on the row (17 pt, ink 15.33 tall); the APK's `dy_ic_write`
  /// (its ink 18.67 pt square) centred 22.17 pt in from the right. Over a 装扮 both take its colour, the pen at 88% (127
  /// draws it #1F1F1E where the title is #000); without one (no screenshot) a white bar.
  static const barRow = 44.0;
  static const barRise = 18.0;
  static const bar = BiliColors.card;
  static const titleText = 17.0;
  static const titleWeight = FontWeight.w500;
  static const titleInk = BiliColors.text;
  static const write = 56 / 3;
  static const writeCentreRight = 22.17;
  static const writeOpacity = 0.88;
  static const writeTarget = 44.0;

  /// The white top under the header, 186 pt to the first grey band. 全部 / 视频: two #F6F7F8 halves 26 pt tall, 8 pt
  /// under the header, 12 pt in and 8 apart, 4 pt corners; the chosen one's word pink.
  static const top = 186.0;
  static const switchTop = 8.0;
  static const switchHeight = 26.0;
  static const switchGap = 8.0;
  static const switchFill = BiliColors.softGrey;
  static const switchRadius = 4.0;
  static const switchText = 12.0;
  static const switchOn = BiliColors.pink;
  static const switchOnWeight = FontWeight.w500;
  static const switchOff = Color(0xFF61666D);

  /// Both sections' titles (最常访问, 我的追番 · 追剧): 14 pt semibold on 20 pt lines, 12 pt in. 最常访问 centred 60.17 pt
  /// under the white top's start (148.17 on 127), 我的追番 · 追剧 22.5 under its section's.
  static const gutter = 12.0;
  static const sectionText = 14.0;
  static const sectionLine = 20.0;
  static const sectionWeight = FontWeight.w600;
  static const sectionInk = BiliColors.text;
  static const facesTitleCentre = 60.17;
  static const bangumiTitleCentre = 22.5;

  /// 更多 › after 最常访问 (only on 全部: 128 has none), 全部 › after 我的追番 · 追剧: the › 4.67 × 9.33 pt with its right
  /// edge 17.67 pt in; 更多's ink ends 7 pt before it, 全部's 9.67.
  static const moreText = 12.0;
  static const moreInk = BiliColors.secondaryText;
  static const allText = 13.0;
  static const allInk = Color(0xFF61666D);
  static const chevronWidth = 14 / 3;
  static const chevronHeight = 28 / 3;
  static const chevronStroke = 1.1;
  static const chevronInk = BiliColors.secondaryText;
  static const chevronRight = 17.67;
  static const moreGap = 35 / 6;
  static const allGap = 53 / 6;
  static const moreTarget = 44.0;

  /// The faces: 52 pt circles in a 1 px #F1F2F3 ring, 74 pt apart from a centre 45 pt in, their tops 82 pt under the
  /// white top's start; names 11 pt #484C53 on 14 pt lines, centred under each and wrapping at 60 pt (a six-character
  /// Chinese name breaks after its fifth), the first line's centre 13.17 pt under the face. The pink dot (8 pt in an 11.67 pt white ring) 18 pt right and
  /// down of the face's centre.
  static const facesTop = 82.0;
  static const face = 52.0;
  static const faceRing = 1 / 3;
  static const faceRingInk = BiliColors.pageGrey;
  static const facePitch = 74.0;
  static const facesInset = 8.0;
  static const nameWidth = 60.0;
  static const nameText = 11.0;
  static const nameLine = 14.0;
  static const nameInk = Color(0xFF484C53);
  static const nameCentre = 79 / 6;
  static const dot = 8.0;
  static const dotRing = 35 / 3;
  static const dotInk = BiliColors.pink;
  static const dotOffset = 18.0;

  /// The row asks Bilibili for more faces once scrolled within this of its end.
  static const facesAhead = 148.0;

  /// The grey between the top's sections and above the first post; each card draws its own under itself.
  static const band = 10.0;
  static const bandFill = BiliColors.pageGrey;

  /// 我的追番 · 追剧 (128): 152 pt from band to band; posters 113 × 70 pt, 6 apart, 4 pt corners, their tops 43 pt under
  /// the section's start; 全N话 10 pt white, 6 pt in, its ink 7.33 pt over the poster's bottom on a shade; the title one
  /// 20 pt line of 14 pt #18191C centred 14.5 pt under the poster.
  static const bangumi = 152.0;
  static const posterTop = 43.0;
  static const posterWidth = 113.0;
  static const posterHeight = 70.0;
  static const posterGap = 6.0;
  static const posterRadius = 4.0;
  static const posterShadeTop = Color(0x00000000);
  static const posterShade = Color(0x66000000);
  static const posterShadeHeight = 28.0;
  static const progressText = 10.0;
  static const progressInk = BiliColors.onCover;
  static const progressLeft = 6.0;
  static const progressBottom = 5.0;
  static const posterTitleText = 14.0;
  static const posterTitleLine = 20.0;
  static const posterTitleInk = BiliColors.text;
  static const posterTitleCentre = 14.5;

  /// The page's own states (no screenshot): logged out, empty, failed, and the footer under the posts.
  static const stateText = 15.0;
  static const stateInk = BiliColors.secondaryText;
  static const stateGap = 16.0;
  static const stateTop = 96.0;
  static const loginText = 15.0;
  static const loginHeight = 36.0;
  static const loginPadX = 36.0;
  static const retryText = 14.0;
  static const retryHeight = 30.0;
  static const retryPadX = 20.0;
  static const buttonWeight = FontWeight.w500;
  static const footerText = 12.0;
  static const footerInk = Color(0xFFC9CCD0);
  static const footerPad = 16.0;
  static const spinnerRadius = 10.0;

  /// 关注 tapped while shown: the list back to the top, then the refresh's TV held open there (首页's own pace).
  static const reloadScroll = Duration(milliseconds: 300);
  static const reloadHeader = Duration(milliseconds: 200);
  static const reloadCollapse = Duration(milliseconds: 100);

  /// The face sheet (139): the page behind frosted to #F2F2F2, the faces row moved up to 16.33 pt under the status bar,
  /// the sheet from 127 pt under it with 8 pt corners, the APK's `dy_ic_indicator_triangle` drawn 15.67 × 8 pt with
  /// its tip under the chosen face; the sheet's head 44 pt with `<name>的动态` 14 pt medium 12 pt in, a 13.33 pt ✕ in
  /// #626262 centred 23 pt in from the right, and a 1 px #E3E5E7 rule.
  static const sheetFrost = Color(0xF2F2F2F2);
  static const sheetBlur = 20.0;
  static const sheetFacesTop = 16.33;
  static const sheetTop = 127.0;
  static const sheetRadius = 8.0;
  static const sheetFill = BiliColors.card;
  static const pointerWidth = 47 / 3;
  static const pointerHeight = 8.0;
  static const sheetHead = 44.0;
  static const sheetTitleText = 14.0;
  static const sheetTitleWeight = FontWeight.w500;
  static const sheetTitleInk = BiliColors.text;
  static const closeSize = 40 / 3;
  static const closeStroke = 1.4;
  static const closeInk = Color(0xFF626262);
  static const closeCentreRight = 23.0;
  static const closeTarget = 44.0;
  static const sheetRule = 1 / 3;
  static const sheetRuleInk = BiliColors.divider;
  static const sheetIn = Duration(milliseconds: 300);
  static const sheetOut = Duration(milliseconds: 220);
  static const sheetCurve = Curves.easeOutCubic;
  static const pointerSlide = Duration(milliseconds: 200);
}

/// A post on its own page (131-134, 140), measured in px / 3 from the status bar's 62 pt down.
abstract final class DynamicPostTheme {
  static DynamicPostThemeColors colorsOf(BuildContext context) => DynamicPostThemeColors(BiliPalette.of(context));

  static const page = BiliColors.card;

  /// The bar: 48 under the status bar; ‹, ↗ and ⋮ in #61666D centred 24 down. Once the author block is under it, the
  /// poster's 25 pt face and 13 pt name (in the text's black, never pink) come in with a 2/3 pt hairline just below the
  /// bar's 48, over the tabs pinned there (134: 110-110.67).
  static const barRow = 48.0;
  static const barInk = Color(0xFF61666D);
  static const barTarget = 44.0;
  static const barFade = Duration(milliseconds: 150);
  static const barRule = BiliColors.divider;
  static const barHairline = 2 / 3;

  /// ‹: its ink 19.33-28.67 × 18 pt with 1.5 pt round strokes.
  static const backTipX = 20.08;
  static const backWidth = 7.83;
  static const backHalfHeight = 8.25;
  static const backStroke = 1.5;

  /// ↗ is the APK's 转发 arrow drawn 20 wide, centred 68 from the right edge and 1 pt above the row's middle.
  static const shareWidth = 20.0;
  static const shareCentreRight = 68.0;
  static const shareRise = 1.0;

  /// ⋮: 10/3 pt dots 20/3 apart, centred 24 from the right edge.
  static const moreCentreRight = 24.0;
  static const moreDot = 10 / 3;
  static const morePitch = 20 / 3;

  static const titleFace = 25.0;
  static const titleFaceLeft = 43.0;
  static const titleGap = 35 / 6;
  static const titleText = 13.0;
  static const titleInk = BiliColors.text;
  static const titleRight = 96.0;

  /// The author block, 11.67 under the bar: the 36 pt face 20 in, its verify badge's disc (10.67 across in a 1 pt white
  /// ring) flush with the face's bottom right; the name 15 pt semibold 10 after it, pink for 大会员 (#FB7299, as
  /// comments'), then the time and, for the posts that keep it there (132), IP属地 in 12 pt grey, 17.17 and 15.33
  /// apart. The face centres on the lines beside it, or they on the face when they are shorter. Every height is in
  /// whole pixels, so the hairlines below stay sharp.
  static const gutter = 20.0;
  static const authorTop = 35 / 3;
  static const face = 36.0;
  static const faceGap = 10.0;
  static const badge = 38 / 3;
  static const badgeRing = 1.0;
  static const badgeOrganisation = Color(0xFF40C5F1);
  static const badgePersonal = Color(0xFFFFCC00);
  static const badgeBolt = Color(0xFFFFFFFF);
  static const nameText = 15.0;
  static const nameWeight = FontWeight.w600;
  static const nameLine = 20.0;
  static const name = BiliColors.text;
  static const vipName = CommentRowTheme.vipName;
  static const metaText = 12.0;
  static const metaLine = 43 / 3;
  static const metaGap = 1.0;
  static const meta = BiliColors.secondaryText;

  /// The text, 12 under the author block, 17 pt in #2F3238 (a shade lighter than the comments' black) on 29.33 pt lines
  /// (131, 132, 140); the body (pictures, a video, a repost's grey block) 12 under it, and IP属地 12 under that for a
  /// picture or text post (140). 12 more before the tabs.
  static const textGap = 12.0;
  static const text = 17.0;
  static const textLine = 88 / 3;
  static const textInk = Color(0xFF2F3238);
  static const bodyGap = 12.0;
  static const endGap = 12.0;

  /// 评论 N / 赞和转发 N: 14 pt in a 40 pt row (its last 2/3 pt the hairline), the first 12 in, 20 between them; the
  /// chosen one pink over a 4/3 pt pink line as wide as its words, standing on the hairline.
  static const tabsHeight = 40.0;
  static const tabText = 14.0;
  static const tabFirst = 12.0;
  static const tabSpacing = 20.0;
  static const tabChosen = BiliColors.pink;
  static const tabInk = BiliColors.secondaryText;
  static const tabUnderline = 4 / 3;
  static const tabHairline = 2 / 3;
  static const tabRule = BiliColors.divider;

  /// The bar at the bottom (131, 132, 140): two 1/3 pt rules (#E3E5E7 over #F1F2F3), then a 44 pt row over the home
  /// indicator. 点我发评论 in a 32 pt grey pill 12 in, ending 37 short of the first count's centre; the counts' centres
  /// 54 apart, the last 37 from the right edge, each icon's ink centred 15.5 down (as 131's lands: 💬 a third of a
  /// point lower, ⭐ a third higher, 👍 0.83 higher) and its 11.5 pt count 33.2 down.
  static const bottomRule = BiliColors.divider;
  static const bottomRuleSoft = BiliColors.pageGrey;
  static const bottomRuleEach = 1 / 3;
  static const bottomRow = 44.0;
  static const pillHeight = 32.0;
  static const pillLeft = 12.0;
  static const pillPadding = 11.0;
  static const pillToAction = 37.0;
  static const pillFill = BiliColors.pageGrey;
  static const pillText = 13.0;
  static const pillInk = BiliColors.secondaryText;
  static const actionPitch = 54.0;
  static const lastActionRight = 37.0;
  static const commentIconCentre = 15.83;
  static const starIconCentre = 15.17;
  static const likeIconCentre = 14.67;
  static const actionCountCentre = 33.2;
  static const actionCountText = 11.5;
  static const actionCountLine = 14.0;
  static const actionInk = Color(0xFF61666D);
  static const actionCountInk = BiliColors.secondaryText;
  static const actionLiked = BiliColors.pink;

  /// The APK's 评论, ⭐ and 赞 drawn as wide as 131's ink.
  static const commentIcon = 56 / 3;
  static const starIcon = 18.0;
  static const likeIcon = 58 / 3;

  /// How long 💬's scroll to 评论 takes, and the first load's failure: why, then 重试 as 搜索's.
  static const toComments = Duration(milliseconds: 300);
  static const stateText = SearchResultTheme.stateText;
  static const stateInk = SearchResultTheme.stateInk;
  static const stateGap = SearchResultTheme.stateGap;
  static const retryHeight = SearchResultTheme.retryHeight;
  static const retryPadX = SearchResultTheme.retryPadX;
  static const retryRim = SearchResultTheme.retryRim;
  static const retryText = SearchResultTheme.retryText;
  static const retryInk = BiliColors.pink;
  static const retryPressedScale = SearchResultTheme.followPressedScale;
  static const retryPressMotion = SearchResultTheme.followPressMotion;
}

/// 我的关注 (129, 130). Measured in px / 3; the shots' colours are Display P3, so the pink reads #ED7098 and the badges'
/// yellow #F7CE45 there.
abstract final class FollowingListTheme {
  static FollowingListThemeColors colorsOf(BuildContext context) => FollowingListThemeColors(BiliPalette.of(context));

  /// The bar under the status bar, 54 tall: the skin's `colorSecondPage` with its text colour (KaiC's green, 129), else
  /// white with the page's text (a guess). A 2/3 hairline ends it.
  static const barRow = 54.0;

  /// ‹ and the title centre this far under the status bar, above the row's middle.
  static const rowCentre = 22.0;
  static const bar = BiliColors.card;
  static const barInk = BiliColors.text;
  static const barLightInk = Color(0xFFFFFFFF);
  static const barHairline = 2 / 3;
  static const hairline = BiliColors.divider;

  /// 我的关注: 20 pt semibold, its ink centred on the screen and the bar's row.
  static const titleText = 20.0;
  static const titleWeight = FontWeight.w600;
  static const titleLine = 28.0;
  static const titleDrop = 1 / 3;

  /// ‹ in the round glass button: a 45.33 disc centred 42 in and on the row, the bar's colour lifted by white, a thin
  /// darker rim, white light along its top and bottom edges and a soft shadow; ‹ 7 × 14 with 1.5 strokes, its tip 4
  /// left of the disc's middle (ink 37.33-45.67 by 76.33-91.67).
  static const backDisc = 136 / 3;
  static const backCentreX = 42.0;
  static const backTarget = 52.0;
  static const backLift = Color(0x4DFFFFFF);
  static const backRim = Color(0x40000000);
  static const backRimWidth = 0.5;
  static const backGloss = Color(0xCCFFFFFF);
  static const backGlossWidth = 1.0;
  static const backShadow = Color(0x0D000000);
  static const backShadowBlur = 10.0;
  static const backShadowDrop = 2.0;
  static const backTip = -4.0;
  static const backWidth = 7.0;
  static const backHalfHeight = 7.0;
  static const backStroke = 1.5;
  static const backInk = Color(0xFF000000);

  /// 搜索我的关注: a 30 tall #F1F2F3 stadium 6 under the bar, 12 in from each side, then 5.67 and a 1/3 hairline the
  /// screen's width. The magnifier's ink is 12 square, centred 18 in and 1/3 above the field's middle (搜索's glyph,
  /// whose box is a third wider than its ink, raised half a point); the words, 13 pt, start 6 after it.
  static const searchTop = 6.0 - barHairline;
  static const searchBottom = 17 / 3;
  static const searchRule = 1 / 3;
  static const field = BiliColors.pageGrey;
  static const fieldHeight = 30.0;
  static const fieldInset = 12.0;
  static const fieldText = 13.0;
  static const fieldLine = 18.0;
  static const fieldInk = BiliColors.text;
  static const placeholder = Color(0xFFAEB3B9);
  static const caret = BiliColors.pink;
  static const magnifier = 37 / 3;
  static const magnifierLead = 35 / 3;
  static const magnifierLift = 0.5;
  static const magnifierInk = BiliColors.secondaryText;
  static const magnifierGap = 6.0;

  /// The grey ⓧ once there is text (搜索's; no screenshot shows it here).
  static const clear = 40 / 3;
  static const clearColor = Color(0xFFC9CCCF);
  static const clearTarget = 36.0;

  /// 排序方式 and the order: a 40 tall row, both 13 pt on its middle; 排序方式 #9499A0 12 in, the order #484C52 ending 8
  /// before ▽ (9.33 × 5 of ink, 1.2 strokes, its right 13.33 from the edge, #61666D). △ while the menu is open.
  static const sortRow = 40.0;
  static const sortText = 13.0;
  static const sortLine = 18.0;
  static const sortDrop = -1 / 3;
  static const sortLabel = BiliColors.secondaryText;
  static const sortValue = Color(0xFF484C52);
  static const sortGap = 8.0;
  static const sortChevronWidth = 8.13;
  static const sortChevronHeight = 3.6;
  static const sortChevronStroke = 1.2;
  static const sortChevronRight = 40 / 3;
  static const sortChevron = Color(0xFF61666D);
  static const sortTarget = 110.0;

  /// The menu (130), from the sort row's bottom: a 2/3 hairline, then three 40 tall rows, 14 pt 12 in, the chosen pink
  /// with ✓ (12.67 × 8.67 of ink, centred 23 from the right and 2/3 under the row's middle); the rest #484C52. A notch
  /// 9 wide and 4.67 tall rises from the hairline 56 from the right, under the order's words, the hairline open
  /// beneath it. Below the menu the page is dimmed by half; a tap there, or anywhere above the menu, closes it.
  static const menuRow = 40.0;
  static const menuText = 14.0;
  static const menuLine = 20.0;
  static const menuDrop = 1.0;
  static const menuInk = Color(0xFF484C52);
  static const menuChosen = BiliColors.pink;
  static const menuFill = BiliColors.card;
  static const checkWidth = 11.17;
  static const checkHeight = 7.17;
  static const checkStroke = 1.5;
  static const checkRight = 23.0;
  static const checkDrop = 2 / 3;
  static const notchRight = 56.0;
  static const notchWidth = 9.0;
  static const notchHeight = 14 / 3;
  static const notchRim = 0.5;
  static const dim = BiliColors.sheetDim;
  static const menuMotion = Duration(milliseconds: 150);

  /// A row (129): 60 tall; the face 40 at 12 in on the row's middle, its verified bolt a 12 disc (1 ringed in white)
  /// flush with the face's right and bottom; the name 14 pt from 64, pink for a 大会员; the pink dot for new posts 9
  /// across, centred 17.5 from the right. A 1 pt hairline ends each row, 20 in from both sides.
  static const row = 60.0;
  static const face = 40.0;
  static const faceInset = 12.0;
  static const badge = 12.0;
  static const badgeRing = 1.0;
  static const badgePerson = IntroTheme.badgePerson;
  static const badgeOrganisation = IntroTheme.badgeOrganisation;
  static const nameLeft = 64.0;
  static const nameText = 14.0;
  static const nameLine = 20.0;
  static const nameDrop = 2 / 3;
  static const name = BiliColors.text;
  static const vipName = BiliColors.pink;
  static const nameGap = 12.0;
  static const dot = 9.0;
  static const dotRight = 17.5;
  static const dotInk = BiliColors.pink;
  static const rowRule = 1.0;
  static const rowRuleInset = 20.0;
  static const page = BiliColors.card;

  /// Typing waits this long for a pause before 搜索我的关注 asks.
  static const searchPause = Duration(milliseconds: 300);

  /// The next page is asked for this close to the list's end.
  static const loadAhead = 360.0;

  /// The first load's failure: its words 14 pt grey over a pink-ringed 重试, as logged out over 登录 (a guess); the
  /// list's footer 加载失败，点击重试 and the small spinner while a page loads (历史记录's).
  static const stateText = 14.0;
  static const stateInk = BiliColors.secondaryText;
  static const stateGap = 16.0;
  static const retryText = 14.0;
  static const retryHeight = 32.0;
  static const retryPadX = 20.0;
  static const retryRim = 0.67;
  static const footerText = 13.0;
  static const footerInk = BiliColors.secondaryText;
  static const footerPad = 16.0;
  static const spinnerRadius = 9.0;
}

/// The iPad's 首页 (ipad/01, 02), measured at 2× (pt = px / 2).
abstract final class PadHomeTheme {
  static PadHomeThemeColors colorsOf(BuildContext context) => PadHomeThemeColors(BiliPalette.of(context));

  /// 推荐's grid: 375 pt cards sideways and 255 upright, 22 pt from the edges and 12 apart; the first row starts as
  /// far under the hairline as 01's banner does (the banner is left out).
  static const columns = 3;
  static const page = BiliColors.card;
  static const margin = 22.0;
  static const gutter = 12.0;
  static const rowGap = 12.0;
  static const firstRow = 18.0;

  /// Bilibili's own pink, as the iPad's selected tab, bar place and 推荐 draw it.
  static const pink = Color(0xFFFB7299);

  /// The top: one row from the status bar to the hairline, everything centred [rowCentre] under the status bar.
  static const rowHeight = 45.5;
  static const rowCentre = 21.0;
  static const hairline = 0.5;
  static const avatar = 40.0;
  static const avatarLeft = 20.0;

  /// The search entry: a grey stadium from 75 pt, as wide as its word up to [fieldTabGap] short of the tab row.
  static const fieldLeft = 75.0;
  static const fieldHeight = 30.0;
  static const fieldFill = BiliColors.pageGrey;
  static const fieldGlyph = 13.0;
  static const fieldGlyphLead = 16.5;
  static const fieldGlyphInk = Color(0xFF999999);
  static const fieldTextStart = 35.5;
  static const fieldTextEnd = 17.0;
  static const fieldText = 13.0;
  static const fieldInk = BiliColors.secondaryText;
  static const fieldTabGap = 40.0;

  /// 直播 推荐 热门 追番 影视, centred on the screen, 65 pt apart.
  static const tabs = ['直播', '推荐', '热门', '追番', '影视'];
  static const tabText = 16.0;
  static const tabPitch = 65.0;
  static const tabInk = Color(0xFF999999);
  static const tabRise = 1.25;

  /// Scan, 历史记录 and 消息, their centres this far from the right edge.
  static const icon = 20.0;
  static const iconInk = Color(0xFF757575);
  static const scanRight = 142.0;
  static const historyRight = 90.0;
  static const messagesRight = 38.0;
  static const iconLine = 1.5;

  /// The bottom bar: 50 pt from its hairline to the home indicator, four 118 pt places centred.
  static const barHeight = 50.0;
  static const barSlot = 118.0;
  static const barIconCentre = 18.25;
  static const barLabelTop = 31.5;
  static const barLabelText = 11.0;
  static const barIconInk = Color(0xFF747474);
  static const barLabelInk = Color(0xFF929292);

  /// A 装扮's bar picture is made for a phone: the iPad draws it at the phone's 440 pt width grown by the bars'
  /// heights, centred, so it rises as far as on the phone (a guess: no screenshot of a dressed iPad bar).
  static const barArtWidth = 440 * barHeight / HomeTabBarTheme.height;

  /// A card: the cover's corners, its counts row, then the face, two title lines, the uploader and date, and ⋮.
  static const coverRadius = 4.0;
  static const footer = 87.0;
  static const face = 40.0;
  static const faceTop = 8.0;
  static const titleLeft = 46.0;
  static const titleRight = 39.0;
  static const titleTop = 7.75;
  static const titleText = 14.0;
  static const titleLine = 19.5;
  static const subTop = 51.0;
  static const subText = 13.0;
  static const subInk = BiliColors.secondaryText;
  static const bylineDotGap = 2.0;
  static const moreRight = 17.0;
  static const moreCentre = 27.0;
  static const moreDot = 3.0;
  static const morePitch = 5.0;
  static const moreInk = Color(0xFF757575);
  static const moreTarget = 34.0;
  static const tagHeight = 16.0;
  static const tagText = 11.0;
  static const tagPad = 4.0;
  static const tagRadius = 2.0;
  static const tagGap = 4.0;
  static const statText = 11.0;
  static const statIconWidth = 13.0;
  static const statIconHeight = 11.0;
  static const statLead = 10.5;
  static const statIconGap = 6.0;
  static const statGap = 15.0;
  static const statTrail = 11.5;
  static const statCentre = 17.5;
  static const durationGap = 4.0;
  static const shade = 40.0;

  /// The loading card's two grey title bars: the first [skeletonTitleDrop] under the face's top, [skeletonLineGap]
  /// between them.
  static const skeletonTitleDrop = 4.0;
  static const skeletonLineGap = 10.0;

  /// The cover's height on a card [width] wide: 16:9 and a pt and a half (212 sideways, 145 upright).
  static double coverHeight(double width) => (width * 9 / 16 + 1.5).roundToDouble();

  static double cardHeight(double width) => coverHeight(width) + footer;

  /// How wide each of the [columns] cards is in a grid [width] wide: whole points, the rest left at the right.
  static double cardWidth(double width) => ((width - margin * 2 - gutter * (columns - 1)) / columns).floorToDouble();

  static double rightMargin(double width) => width - margin - cardWidth(width) * columns - gutter * (columns - 1);
}

/// The iPad's video page frame: the two columns sideways (ipad/03, 05), one upright (06), the player's shrink to the
/// pink 立即播放 bar (05, 20).
abstract final class PadPageTheme {
  static PadPageThemeColors colorsOf(BuildContext context) => PadPageThemeColors(BiliPalette.of(context));

  /// 03, 05 and 06 keep the page 32 pt below the screen's top, black above it, past the 24 pt status bar inset.
  static const statusBand = 32.0;

  /// The column's side margins (03, 06).
  static const gutter = 20.0;

  /// Sideways the related column is 437 pt with a 0.5 pt rule to its left and along its top (03); the player's column
  /// takes the rest (756.5 on the 1194 pt screen).
  static const relatedWidth = 437.0;
  static const rule = 0.5;
  static const ruleColour = BiliColors.divider;

  /// The paused player shrinks to the pink 立即播放 bar (05): 60 pt, its row centred 33 below its top, ‹ 18 in, ⋮ 21
  /// from the column's right, the APK's `ic_upper_tv_play` made opaque, 22 pt wide, 4.5 pt before 立即播放.
  static const barHeight = 60.0;
  static const barFill = BiliColors.pink;
  static const barRowCentre = 33.0;
  static const backLeft = 18.0;
  static const moreRight = 21.0;
  static const playGlyphWidth = 22.0;
  static const playGlyphHeight = 22.0 * 133 / 144;
  static const labelGap = 4.5;
  static const labelText = 16.0;
  static const label = BiliColors.onVideo;

  /// Once the player is the bar and 简介's actions have scrolled under it, a 60 pt strip stays pinned below it (05):
  /// the 40 pt face 20 in, the five actions at a 62 pt pitch from 79.75, 点我发弹幕 at the right; a rule under it.
  static const stripHeight = 60.0;
  static const stripFace = 40.0;
  static const stripFaceLeft = 20.0;

  /// The actions' icons start 10.5 below the strip's top.
  static const stripIconTop = 10.5;
  static const stripActionsLeft = 79.75;
  static const stripActionPitch = 62.0;

  /// The upright tab row (06): 60 pt, no underline and no rule, 简介 20 pt in and 评论 (N) 38 pt after it, both 16 pt.
  static const tabRowHeight = 60.0;
  static const tabText = 16.0;
  static const tabFirstLabel = 20.0;
  static const tabSpacing = 38.0;
  static const tabInk = PageTheme.tabText;

  /// 点我发弹幕 (the body's [PadDanmakuCapsule]) sits 20 pt from the right on the tab row and the strip (05, 06).
  static const capsuleRight = 20.0;

  /// The inline 热门评论 header sideways (03): a rule on top, 49.5 pt with its line centred 25.25 down; the title
  /// semibold 16 pt 20 in, the 218 × 30 field 96.5 in (13 pt, 15.5 in, the face 20 pt 7 from its end), then at the
  /// right ⇅ 按热度, a 12 pt rule and 查看 N 条评论 › 19.5 from the column's right, all 14 pt in 61666D.
  static const headerHeight = 49.5;
  static const headerCentre = 25.25;
  static const headerTitleText = 16.0;
  static const headerTitleWeight = FontWeight.w600;
  static const headerTitle = BiliColors.text;
  static const headerFieldLeft = 96.5;
  static const headerFieldWidth = 218.0;
  static const headerFieldHeight = 30.0;
  static const headerFieldText = 13.0;
  static const headerFieldPadding = 15.5;
  static const headerFieldFill = BiliColors.softGrey;
  static const headerFieldInk = BiliColors.secondaryText;
  static const headerFace = 20.0;
  static const headerFaceRight = 7.0;
  static const headerText = 14.0;
  static const headerInk = PageTheme.tabText;
  static const headerSortGlyph = 12.0;
  static const headerSortGap = 6.5;
  static const headerRuleHeight = 12.0;
  static const headerRuleGap = 10.0;
  static const headerChevronGap = 5.5;
  static const headerChevronWidth = 5.5;
  static const headerChevronHeight = 9.5;
  static const headerChevronStroke = 1.2;
  static const headerRight = 19.5;

  /// The 发条评论 bar under the sideways column (05): a 0.5 pt rule, then the 32 pt field 6.5 under it and 6.5 above
  /// the screen's bottom, over the home indicator; the field 20 in and 47.75 short of the column's right, its 12 pt
  /// prompt 20 in, the 20 pt face centred 15.75 from its end; ↑ (back to the top) centred 23.5 from the column's right,
  /// 18 × 20 with 1.25 pt strokes.
  static const commentRule = Color(0xFFC9CCD0);
  static const commentGap = 6.5;
  static const commentFieldHeight = 32.0;
  static const commentFieldLeft = 20.0;
  static const commentFieldRight = 47.75;
  static const commentFieldFill = BiliColors.softGrey;
  static const commentPromptLeft = 20.0;
  static const commentPromptText = 12.0;
  static const commentInk = BiliColors.secondaryText;
  static const commentFaceRight = 15.75;
  static const commentTopRight = 23.5;
  static const commentTopWidth = 18.0;
  static const commentTopHeight = 20.0;
  static const commentTopStroke = 1.25;

  /// A guess: no screenshot shows an upright video on the page; KaiC's iPad shows it pillarboxed in full screen (25),
  /// so the box stays 16:9.
  static const uprightLimit = 1 / BiliMetrics.videoAspect;

  /// The player growing into full screen and back (22).
  static const fullScreenGrow = Duration(milliseconds: 300);
  static const fullScreenCurve = Curves.easeInOut;
}

/// The iPad's page body: 简介's sections and the related column (ipad/03, 04, 06).
abstract final class PadBodyTheme {
  static PadBodyThemeColors colorsOf(BuildContext context) => PadBodyThemeColors(BiliPalette.of(context));

  /// Everything in 简介's head starts 20 in, the action cells too (03).
  static const gutter = 20.0;

  /// The avatar's top is 10 below the player sideways (03) and below the tab row upright (06).
  static const uploaderTop = 10.0;
  static const avatar = 40.0;
  static const avatarGap = 10.0;
  static const nameText = 14.0;
  static const nameLine = 18.0;
  static const fansText = 12.0;
  static const fansLine = 15.0;

  /// The name's and the counts' centres below the avatar's top.
  static const nameCentre = 10.0;
  static const fansCentre = 29.0;

  /// + 关注 follows the wider of the name and the counts, 21.5 after it: a 72 × 26 card with 4 pt corners.
  static const followGap = 21.5;
  static const followWidth = 72.0;
  static const followHeight = 26.0;
  static const followRadius = 4.0;
  static const followText = 13.0;
  static const followPlus = 9.5;
  static const followPlusStroke = 1.1;
  static const followPlusGap = 5.0;

  /// 点我发弹幕 and the 弹 toggle (03 sideways, 06 in the tab row upright): 158 × 32, 20 from the right edge, the
  /// words 15 in, the toggle's white 39.5 wide with the glyph centred 18.5 from the capsule's end.
  static const capsuleWidth = 158.0;
  static const capsuleHeight = 32.0;
  static const capsuleBorder = 0.5;
  static const capsuleToggle = 39.5;
  static const capsuleToggleOff = 44.0;
  static const capsuleTextLead = 15.0;
  static const capsuleText = 13.0;
  static const capsuleMarkCentre = 18.5;

  /// The words sit 1 lower than centred in the capsule.
  static const capsuleTextDrop = 1.0;

  /// The title's centre below the avatar's bottom: 32.5 sideways, 30.5 upright (03, 06).
  static const titleGap = 32.5;
  static const titleGapUpright = 30.5;
  static const titleText = 18.0;
  static const titleLine = 24.0;

  /// The iPad's title is the name's grey in a medium weight, lighter than the iPhone's.
  static const titleInk = IntroTheme.name;

  /// The 活动 capsule sits 1 below the title's centre.
  static const honorHeight = 20.0;
  static const honorDrop = 1.0;
  static const honorPadding = 8.0;
  static const honorText = 12.0;
  static const honorGap = 4.5;

  /// The meta line: 30 under the title's centre, ▶ 1.5 in, 15 × 13 icons 4 before their counts, groups 15.5 apart,
  /// then the BV id and 查看简介 with its 9 × 4.5 chevron 2.5 after it.
  static const metaGap = 30.0;
  static const metaLine = 16.0;
  static const metaText = 12.0;
  static const metaLead = 1.5;
  static const metaIconWidth = 15.0;
  static const metaIconHeight = 13.0;
  static const metaIconGap = 4.0;
  static const metaGroupGap = 15.5;
  static const toggleChevronGap = 2.5;
  static const toggleChevronWidth = 9.0;
  static const toggleChevronHeight = 4.5;

  /// 查看简介 opened (04): the description's 17 pt lines start 8.5 under the meta line, then the plain tags, 26 tall,
  /// 6.5 under the description, 12 apart, their names 13.5 from each end.
  static const descGap = 8.5;
  static const descText = 13.0;
  static const descLine = 17.0;
  static const tagsGap = 6.5;
  static const tagHeight = 26.0;
  static const tagText = 12.0;
  static const tagPadding = 13.5;
  static const tagSpacing = 12.0;
  static const tagInk = IntroTheme.name;

  /// The actions (03): 70 pt cells from the gutter, a 30 pt icon centred 35.5 under the meta line's centre, its count
  /// centred 26.75 below the icon's in the icons' grey, and the head ending 21.25 under the counts, where 热门评论's
  /// hairline is.
  static const actionCell = 70.0;
  static const actionTopGap = 35.5 - metaLine / 2 - actionIcon / 2;
  static const actionIcon = 30.0;
  static const actionCountLine = 15.0;
  static const actionCountGap = 26.75 - actionIcon / 2 - actionCountLine / 2;
  static const actionCountText = 12.0;
  static const actionCount = ActionTheme.icon;
  static const actionsBottom = 21.25 - actionCountLine / 2;
  static const actionRing = 40.0;

  /// The sections that follow (合集, parts, topic chips) keep the iPhone's look at the iPad's gutter.
  static const sectionInset = gutter - BiliMetrics.gutter;

  /// A related row (03, 06): 97 apart, a 138 × 77 cover 10 below the row's top, the text 10.5 right of it. No
  /// hairlines between rows; upright the list opens with one 10 under the head, 10 in from each side.
  static const relatedRowHeight = 97.0;
  static const relatedCoverTop = 10.0;
  static const relatedCoverWidth = 138.0;
  static const relatedCoverHeight = 77.0;
  static const relatedTextGap = 10.5;
  static const relatedTitleLift = 1.5;

  /// The iPad's related titles are medium, where the iPhone's are regular.
  static const relatedTitleWeight = FontWeight.w500;

  /// The first cover sits where the ad's does, 16 under the column's top or the list's hairline.
  static const relatedListTop = 6.0;
  static const relatedHairlineGap = 10.0;
  static const relatedHairlineInset = 10.0;

  /// Sideways the column's rows sit 10 from its edges; upright the page's 20.
  static const relatedColumnGutter = 10.0;
  static const relatedUploaderCentre = 49.75;
  static const relatedCountsCentre = 69.0;
  static const relatedMetaLead = 0.5;
  static const relatedMetaGap = 6.0;
  static const relatedCountSpacing = 12.5;
  static const relatedIconWidth = 14.0;
  static const relatedIconHeight = 12.0;
  static const relatedUpFont = 8.0;
  static const relatedUpRadius = 3.0;

  /// ⋮: three 3 pt dots 1.5 apart, centred 8 inside the gutter on the counts' line.
  static const moreDot = 3.0;
  static const moreDotGap = 1.5;
  static const moreInset = 8.0;

  /// The cover's duration tag (06), 5 in from the corner, a lighter shade than the iPhone's, reads 04:15 as the iPad
  /// writes it.
  static const durationInset = 5.0;
  static const durationHeight = 14.0;
  static const durationPad = 4.5;
  static const durationRadius = 3.0;
  static const durationFill = Color(0x80000000);
}

/// The iPad's controls over the page's player and its end screen (ipad/03, 07, 17).
abstract final class PadInlineControlsTheme {
  /// A control's centre from its edge of the player: back, ⋮ and 全屏 (03: 28.5-29 pt; 07 the same).
  static const edgeCentre = 29.0;

  /// The top row's centre from the player's top, and the bottom row's from its bottom.
  static const topCentre = 29.0;
  static const bottomCentre = 29.0;

  /// From the player's right: the 投屏 TV and 倍速 share a column, the 小窗 icon is left of the TV.
  static const castCentre = 87.0;
  static const floatCentre = 144.25;

  /// The glyphs' ink (03, 07), drawn from the APK's `biliplayer_ic_topbar_floatwindow` and `_tv`.
  static const floatWidth = 24.5;
  static const floatHeight = 19.5;
  static const castWidth = 24.0;
  static const castHeight = 19.33;
  static const backWidth = 9.0;
  static const backHeight = 18.0;
  static const moreDot = 3.0;
  static const moreDotGap = 4.5;

  /// The float window's lines, 1 of its 22-unit viewport at the ink's scale.
  static const floatStroke = 1.17;

  /// ⏮ (the APK's `bili_mini_player_ctrl_play_prev`), its centre from the left, and half white with nothing before.
  static const previousCentre = 29.0;
  static const previousWidth = 11.67;
  static const previousHeight = 13.33;
  static const previousOffOpacity = 0.5;

  static const playCentre = 86.5;
  static const playWidth = 17.0;
  static const playHeight = 20.0;

  /// The bar's left end (the TV's left at 0:00: its centre at 116) and the gap before the time; the time ends 142
  /// from the right, so the bar ends 232.5 from it with 03's time.
  static const barLeft = 107.0;
  static const timeGap = 17.0;
  static const timeRight = 142.0;
  static const timeFont = 12.5;

  static const speedFont = 16.0;
  static const speedWidth = 60.0;
  static const fullScreenGlyph = 16.0;

  /// 章节 · (chapter) ›: 14 pt from 21 pt in, its centre 65.75 above the player's bottom; the chevron 6.5 × 11, 11
  /// after the text.
  static const chapterLeft = 21.0;
  static const chapterCentre = 65.75;
  static const chapterFont = 14.0;
  static const chapterHeight = 24.0;
  static const chevronWidth = 6.5;
  static const chevronHeight = 11.0;
  static const chevronGap = 11.0;
  static const chevronStroke = 1.5;
  static const chapterShadow = 2.0;

  /// The shades behind both rows (07 against 06, the same frame): near black at the edge, gone 96 pt in.
  static const shadeHeight = 96.0;
  static const shade = [
    Color(0xFF000000),
    Color(0xF5000000),
    Color(0xC7000000),
    Color(0x87000000),
    Color(0x42000000),
    Color(0x14000000),
    Color(0x00000000),
  ];
  static const shadeStops = [0.0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1.0];

  /// With the controls hidden, the chapters across the bottom (06): each title 9 pt, centred on its stretch, 10.67
  /// above the bottom, between hairlines 20 pt tall, over a 22 pt shade.
  static const stripFont = 9.0;
  static const stripCentre = 10.67;
  static const stripLine = 0.5;
  static const stripLineHeight = 20.0;
  static const stripLineInk = Color(0x4DFFFFFF);
  static const stripShadeHeight = 22.0;
  static const stripShade = Color(0x9E000000);
  static const stripPad = 4.0;

  /// The end screen (17) on a 756.5 × 425.5 player, its block placed from the player's middle.
  static const endTopCentre = 42.0;
  static const endEdgeCentre = 21.5;
  static const endBackWidth = 9.5;
  static const endCaptionLeft = 51.0;
  static const endCaptionCentre = -34.25;
  static const endCaptionFont = 13.5;
  static const endCoverLeft = 50.0;
  static const endCoverTop = -18.75;
  static const endCoverWidth = 224.0;
  static const endCoverHeight = 126.0;
  static const endCoverRadius = 6.0;
  static const endCoverShadeHeight = 40.0;
  static const endCoverTextInset = 9.0;
  static const endCoverTimeFont = 12.0;
  static const endPlayWidth = 18.5;
  static const endPlayHeight = 21.0;
  static const endInfoGap = 11.0;
  static const endInfoRight = 24.0;
  static const endTitleCentre = 0.75;
  static const endTitleFont = 16.0;
  static const endUploaderCentre = 70.25;
  static const endCountsCentre = 89.25;
  static const endMetaFont = 12.5;
  static const endCountFont = 12.0;
  static const endMetaRow = 16.0;
  static const endMetaGap = 6.0;
  static const endMetaSpacing = 14.0;

  /// 重播 and 分享 on one line, the share text's end 67.5 from the right.
  static const endActionsCentre = -33.75;
  static const endActionsRight = 67.5;
  static const endActionFont = 14.0;
  static const endReplayWidth = 19.5;
  static const endReplayHeight = 21.0;
  static const endReplayGap = 10.0;
  static const endShareInk = 24.0;
  static const endShareGap = 6.7;
  static const endActionSpacing = 37.2;
}

/// The iPad's full screen: top and bottom bars, side buttons, the end screen, the hold, buffering and the seek
/// preview (ipad/08, 14-16, 18, 19, 24). Measured at 2 px per pt on KaiC's
/// iPad Pro 11" sideways (1194 × 834, the status bar's 24 pt above, the home indicator's 20 below); rows are placed
/// from the safe area's edges, columns from the screen's.
abstract final class PadFullScreenTheme {
  /// The shades behind the bars, black at the safe area's edge and clear 100 pt into the top and 108 into the bottom
  /// (18 against 19). 08's bands are the video's letterbox, black either way.
  static const topShade = 100.0;
  static const bottomShade = 108.0;
  static const bottomShadeSolid = 6.0;

  /// The top row: 44 pt tall, centred 28.8 pt under the status bar; ‹ centred 28.3 pt in, the title from 58.8.
  static const topRowTop = 6.8;
  static const backLeft = 6.3;
  static const backWidth = 10.0;
  static const backHeight = 17.3;
  static const titleLeft = 58.8;
  static const titleText = 18.0;
  static const titleGap = 16.0;

  /// The system font's ink sits 1.5 pt higher in its line than 08's title, 1.2 pt for the times' digits, 2 for the
  /// chapter line and 1 for 关注.
  static const titleDrop = 1.5;
  static const timeDrop = 1.2;
  static const chapterDrop = 2.0;
  static const followDrop = 1.0;

  /// 点赞 不喜欢 投币 收藏 充电 分享, 70 pt apart, then ⋮ centred 34 pt from the right edge.
  static const actionSlot = 70.0;
  static const actionsToMore = 13.0;
  static const moreRight = 12.0;
  static const actionIcon = 28.5;
  static const actionStroke = 1.3;

  /// 不喜欢's thumb hangs lower in its box than 08 draws it.
  static const dislikeLift = 2.2;

  /// The superscript like count: its left edge 7.8 pt right of the button's centre, on a baseline 12.4 pt into it.
  static const countText = 10.0;
  static const countLead = 7.8;
  static const countBaseline = 12.4;

  /// N人正在看 centred 83 pt down, its icon under the title's first character, in white where the phone's is 60%.
  static const onlineCentre = 58.0;
  static const onlineHeight = 16.0;
  static const online = Color(0xFFFFFFFF);
  static const onlineIcon = Color(0xEBFFFFFF);

  /// The uploader's chip (18, 24): a 27% black capsule 31.5 pt tall from 16.2 pt in, centred 114 pt down, holding
  /// the 28 pt avatar 1.5 pt in, the plus 11 pt after it, 关注 5.4 pt after that and 15.3 pt of the capsule after it.
  /// No name (24's and 18's chips have none).
  static const chipLeft = 16.2;
  static const chipCentre = 90.0;
  static const chipHeight = 31.5;
  static const chipFill = Color(0x45000000);
  static const chipInset = 1.5;
  static const avatar = 28.0;
  static const plusLead = 11.0;
  static const plus = 10.3;
  static const plusStroke = 1.0;
  static const plusGap = 5.4;
  static const followText = 13.5;
  static const followTrailing = 15.3;

  /// 截图 and the lock in 51.5 pt tiles of 30% black with 9 pt corners, 8.3 pt from the right edge, 16.5 pt apart,
  /// the pair's middle 18.6 pt above the screen's.
  static const tile = 51.5;
  static const tileRadius = 9.0;
  static const tileFill = Color(0x4D000000);
  static const tileRight = 8.3;
  static const tileGap = 16.5;
  static const tilesLift = 18.6;
  static const cameraWidth = 23.5;
  static const cameraHeight = 18.0;
  static const lockWidth = 21.5;
  static const lockHeight = 23.3;

  /// From the safe area's bottom: the bottom row's centre 36 pt up, the bar's 82, the chapter line's 113.4.
  static const rowBottom = 14.0;
  static const rowToBar = 12.0;
  static const barToChapter = 7.4;
  static const chapterBox = 24.0;

  /// 章节 · title › from 23.6 pt in, 15 pt, the chevron 10 pt tall 8 pt after the title.
  static const chapterLeft = 23.6;
  static const chapterText = 15.0;
  static const chapterChevronGap = 8.0;
  static const chapterChevronWidth = 6.0;
  static const chapterChevronHeight = 11.0;
  static const chapterChevronStroke = 1.6;

  /// The bar from 74.5 pt in to 74.5 pt from the right, the TV's travel 83.5 to 1110.5; the times 24 pt in from
  /// either edge, 13 pt.
  static const barInset = 74.5;
  static const timeInset = 24.0;
  static const timeText = 13.0;

  /// The bottom row: ⏮ centred 29.1 pt in, ▶ 92, 弹 157.6, 弹幕设置 221.6; the field from 264 to 287.1 pt from the
  /// right edge; 倍速, 1080P, 小窗 and 退出全屏 centred 240.7, 169.7, 97.5 and 34.2 pt from it.
  static const prevLeft = 7.1;
  static const prevToPlay = 18.9;
  static const playToDanmaku = 21.6;
  static const danmakuToSettings = 20.0;
  static const settingsToField = 20.4;
  static const fieldToSpeed = 23.4;
  static const speedToQuality = 17.5;
  static const qualityToPip = 19.7;
  static const pipToExit = 19.3;
  static const exitRight = 12.2;
  static const textPad = 8.0;
  static const labelText = 15.0;

  /// ⏮ (the APK's `bili_player_ctrl_play_previous`) 13.7 × 14.5 pt, half white with nothing before it; ▶'s ink 23 ×
  /// 26.4, its box larger by what the rounded corners take off.
  static const prevWidth = 13.7;
  static const prevHeight = 14.5;
  static const prevOff = Color(0x80FFFFFF);
  static const playWidth = 25.0;
  static const playHeight = 29.5;
  static const playCorner = 1.6;
  static const playShift = 1.2;
  static const pauseBar = 6.5;
  static const pauseGap = 5.5;

  /// 弹 and 弹幕设置, the phone's TVs drawn 24 × 23.
  static const danmakuWidth = 24.0;
  static const danmakuHeight = 23.0;

  /// 发个友善的弹幕见证当下 in a 29.7 pt field of 30% white with 5 pt corners, 12 pt half-white text 12.4 pt in.
  static const fieldHeight = 29.7;
  static const fieldRadius = 5.0;
  static const fieldFill = Color(0x4DFFFFFF);
  static const fieldInk = Color(0x80FFFFFF);
  static const fieldInset = 12.4;
  static const fieldText = 12.0;

  /// 高码率's tag: centred 14.9 pt above the row's centre, its right end 10.8 pt past 1080P's.
  static const tagRise = 14.9;
  static const tagOverhang = 10.8;

  /// 小窗's ink (the APK's `biliplayer_ic_topbar_floatwindow`, as the page's player draws it) 24.4 × 19.6; 退出全屏's
  /// two brackets 21 pt, the elbows 8.5 pt in from their corners.
  static const pipWidth = 24.4;
  static const pipHeight = 19.6;
  static const exitBox = 21.0;
  static const exitElbow = 8.5;
  static const glyphStroke = 1.3;
  static const offOpacity = 0.5;

  /// 09's strip while the controls are hidden: 19 pt under the video, the played part a grey fading down, under the
  /// inline player's titles (`PadChapterStrip`), whose box ends 22.3 pt down so they centre 11.6 pt under the video.
  static const stripHeight = 19.0;
  static const stripBox = 22.3;
  static const stripPlayed = Color(0x99B4B4B4);

  /// The hold's arrows (15), smaller than the phone's: 16.8 × 10.9 pt, 7.6 pt before the label.
  static const hudArrowWidth = 9.6;
  static const hudArrowHeight = 10.9;
  static const hudArrowStep = 7.2;
  static const hudGap = 7.6;

  /// Recording 24: the frame 144 × 81 (16:9) with 3 pt corners, its bottom 20.2 pt above the bar's middle and its
  /// middle 16 pt left of the TV's; the arrows and the time (13 pt, white) inside, centred 23.8 pt above its bottom;
  /// the chapter's title in an 90% black box 31.5 pt tall with 3.5 pt corners, 4.7 pt above the frame.
  static const previewWidth = 144.0;
  static const previewHeight = 81.0;
  static const previewRadius = 3.0;
  static const previewAboveBar = 20.2;
  static const previewShift = 16.0;
  static const previewEdge = 8.0;
  static const previewTimeText = 13.0;
  static const previewTimeRise = 23.8;
  static const previewArrowGap = 7.8;
  static const previewTitleHeight = 31.5;
  static const previewTitleRadius = 3.5;
  static const previewTitlePad = 12.5;
  static const previewTitleText = 12.0;
  static const previewTitleGap = 4.7;
  static const previewTitleFill = Color(0xE61B1B1B);

  /// The end screen (16): ‹ in the band above the video, the 60 pt avatar ringed 1.5 pt white at 22.2, 82.2; the
  /// name 16 pt from 98.2, its ink centred 92 down; + 关注 (59.5 wide, pink) and 为TA充电 (71.6 wide, outlined) 29.5
  /// pt tall with 2.5 pt corners, 12.5 pt apart from 112.2 down. Text boxes are placed where the stand-in fonts' ink
  /// lands on 16's, which sits about 2 pt above the box's middle.
  static const endDim = Color(0xD9000000);
  static const endBackTop = 20.0;
  static const endHeadTop = 82.2;
  static const endInset = 22.0;
  static const endAvatar = 60.0;
  static const endAvatarRing = 1.5;
  static const endNameLeft = 98.2;
  static const endNameText = 16.0;
  static const endNameCentre = 11.6;
  static const endPillTop = 30.0;
  static const endPillHeight = 29.5;
  static const endPillRadius = 2.5;
  static const endFollowWidth = 59.5;
  static const endChargeWidth = 71.6;
  static const endPillGap = 12.5;
  static const endPillText = 14.0;
  static const endPillPlus = 9.0;
  static const endPillPlusStroke = 1.2;
  static const endPillPlusGap = 5.0;

  /// 重播, a rule, 点赞 不喜欢 投币 收藏 分享 in 70 pt columns, 分享 centred 73 pt from the right edge: the icons
  /// centred 13.8 pt and the 15 pt labels' ink 52.3 below the avatar's top; the rule 56 tall, 57 pt from 重播's
  /// centre.
  static const endActionSlot = 70.0;
  static const endActionsRight = 38.0;
  static const endActionIcon = 28.5;

  /// The phone's replay ring, which scales by its height, drawn about as wide as 16's 21 pt.
  static const endReplayWidth = 21.0;
  static const endReplayHeight = 20.0;
  static const endIconCentre = 13.8;
  static const endLabelCentre = 54.1;
  static const endLabelText = 15.0;
  static const endReplayToRule = 57.0;
  static const endRuleHeight = 56.0;
  static const endRuleTop = 1.8;
  static const endRule = Color(0x26FFFFFF);

  /// 推荐视频 (14 pt from 30.7, centred 186.7 down), then four columns from 22 pt in, 12.5 apart, of 16:10 covers with 4
  /// pt corners from 210 down, a row every 237 pt.
  static const endHeaderLeft = 30.7;
  static const endHeaderCentre = 105.8;
  static const endHeaderText = 14.0;
  static const endGridTop = 23.3;
  static const endColumns = 4;
  static const endCardGap = 12.5;
  static const endRowGap = 22.4;
  static const endCoverAspect = 1.6;
  static const endCoverRadius = 4.0;

  /// On the cover: the counts 10 pt with the icons 9.3 pt in, the duration 9.1 pt from the right, centred 10.8 pt above
  /// its bottom. Under it the title, 14 pt in 16.8 pt lines, 65% white, 7.2 pt down.
  static const endCoverInset = 9.3;
  static const endCoverTrailing = 9.1;
  static const endCountCentre = 10.8;
  static const endCountText = 10.0;
  static const endCountSpacing = 10.7;
  static const endCountIconGap = 4.0;
  static const endTitleTop = 7.2;
  static const endTitleText = 14.0;
  static const endTitleLeading = 1.2;
  static const endTitleInk = Color(0xA6FFFFFF);
}

/// The iPad's player panels (ipad/10-13), measured at 2× (pt = px / 2). In full screen every panel is a hard-edged
/// strip at the right, the same width in points whichever way the iPad is held; the rows inside are the phone's.
abstract final class PadPanelTheme {
  /// 清晰度 and 倍速 (10, 11): a 242 pt strip; ⋮, 弹幕设置 and the panels opened from them (12, 13): 320.
  static const narrowWidth = 242.0;
  static const wideWidth = 320.0;

  /// The video shows through 16% under 清晰度 and ⋮, 12% under 倍速 and 弹幕设置.
  static const shade = Color(0xD6000000);
  static const darkShade = Color(0xE0000000);

  /// 弹幕设置's cards and the side panels' rows end this far before the screen's edge, as the phone's do before its
  /// safe area; ⋮'s cards keep [moreInset] each side, so its four squares sit [moreActionGap] apart.
  static const trailing = 16.0;
  static const moreInset = 12.0;
  static const moreActionGap = 32.0;

  /// 12's first card is 80 pt down, 8 below where the phone's header puts it under the 24 pt status bar.
  static const danmakuTop = 8.0;

  /// 10's rows: 66 pt apart, their block centred [qualityLift] above the screen's middle, the text [qualityLead] in
  /// from the strip and the 大会员 tag ending [qualityTrailing] before the screen's edge.
  static const qualityRow = 66.0;
  static const qualityLift = 12.0;
  static const qualityLead = 43.5;
  static const qualityTrailing = 36.0;
  static const qualityText = 16.0;
  static const qualitySubtitleText = 11.0;
  static const qualityHeaderTop = 14.0;
  static const qualityHeaderGap = 8.0;
  static const qualitySelected = Color(0xFFFB7299);
  static const badgeHeight = 15.0;
  static const badgePad = 6.0;
  static const badgeText = 10.0;
  static const badgeFill = Color(0xFFFB7299);

  /// 11's values: 58 pt apart, centred on the screen and in the strip.
  static const speedRow = 58.0;
  static const speedText = 16.0;
  static const speedSelected = Color(0xFFFF6699);

  /// On the page (no screenshot): the sheets keep the phone's heights in points (shares of its 956) and stay under
  /// the player, in its column.
  static const phoneHeight = 956.0;
}

/// The iPad's danmaku, on the page's player and in full screen (ipad/09, 25).
abstract final class PadDanmakuTheme {
  /// Full screen's text at an elem's fontSize of 25: 09's CJK advances are 43.4 px (9 of them over 391 px) and 25's
  /// lanes 62.6 px apart, which the phone's 1.44 lane spacing and 1 pt outline give at 21.75 pt. Lanes run from the
  /// screen's top edge, 25's six of them filling 25% of the whole 834 pt height, pillarbox included.
  static const fontFullScreen = 21.75;

  /// The landscape screen's width, against which the page's player scales [fontFullScreen]: no screenshot shows
  /// danmaku on the page (03, 07), so they keep full screen's share of a 16:9 picture, as the phone's small player
  /// does (12.5 against 22).
  static const fullScreenWidth = 1194.0;

  /// The style panel's height before a keyboard has been up to measure (the iPad Pro 11"'s, with its suggestions
  /// row); the panel takes the real keyboard's height once it has risen.
  static const landscapePanelHeight = 405.0;
  static const portraitPanelHeight = 320.0;
}

/// 缓存's sheet (141-144, 153, 154) and the portrait ⋮ sheet it opens from (42, 43, differences/22).
abstract final class DownloadSheetTheme {
  static DownloadSheetThemeColors colorsOf(BuildContext context) => DownloadSheetThemeColors(BiliPalette.of(context));

  /// Both sheets are light grey with white cards; in 竖屏 they stand 573.67 pt tall (43), in the small player they run
  /// from the player's bottom.
  static const sheet = BiliColors.softGrey;
  static const card = BiliColors.card;
  static const verticalHeight = 573.67 / 956;
  static const cardRadius = 8.0;
  static const cardInset = 16.0;
  static const hairline = BiliColors.divider;
  static const grey = Color(0xFF61666D);

  /// ⋮ (42, 43): the squares 35 below the sheet's top (where 42's share icons start; KaiC took that row out), then
  /// the card of rows 51 below them.
  static const tilesTop = 24.0;
  static const tileSize = 48.0;
  static const tileLead = 18.0;
  static const tileGap = 16.0;
  static const tileRadius = 8.0;
  static const tileLabelCentre = 14.67;
  static const tileLabelText = 11.0;
  static const tilesBottom = 51.0;
  static const cardGap = 12.0;
  static const bottom = 12.0;

  /// The icon fonts' glyphs at the ink width 42 measures on each square, drawn in [ink].
  static const tileGlyphWidth = 20.0;
  static const tileGlyphWide = 21.0;
  static const ink = BiliColors.text;

  static const rowHeight = 52.0;
  static const rowText = 14.0;
  static const detailText = 12.0;
  static const segmentText = 12.0;
  static const segmentDivider = 12.0;

  /// 循环播放's three cells and 倍速's strip, right-aligned at the row's trailing edge; the strip starts 88 into the
  /// card and fades its first 12 pt, so 0.75 shows only as .75 under 42's 倍速.
  static const loopCell = 88.33;
  static const speedCell = 54.67;
  static const speedStart = 88.0;
  static const speedFade = 12.0;

  /// The switch, off: a light grey track and a white knob with a faint shadow.
  static const trackOff = Color(0xFFE6E6E8);
  static const knobShadow = Color(0x29000000);
  static const knobShadowBlur = 2.0;

  /// The pages ⋮ opens inside the sheet (定时关闭 ›, 画面尺寸 ›; no screenshot).
  static const pageHeader = 44.0;
  static const pageTitleText = 16.0;
  static const pageBackGlyph = 16.0;

  /// The row icons drawn from 42 and 43 (their ink boxes).
  static const speedGlyphWidth = 16.33;
  static const speedGlyphHeight = 11.0;
  static const timerGlyphWidth = 16.67;
  static const timerGlyphHeight = 17.67;
  static const listenGlyphWidth = 16.0;
  static const listenGlyphHeight = 15.0;
  static const subtitleGlyphWidth = 16.67;
  static const subtitleGlyphHeight = 14.33;
  static const gestureGlyph = 18.33;
  static const qualityGlyph = 16.67;
  static const glyphStroke = 1.2;

  /// 缓存 (141): 画质 and the quality's name on a line 30.2 below the grabber, the list from 52 below it.
  static const headerCentre = 30.2;
  static const listTop = 52.0;
  static const headerText = 14.0;
  static const headerGap = 12.0;
  static const headerChevronGap = 4.0;
  static const headerChevronWidth = 9.33;
  static const headerChevronHeight = 5.0;

  static const rowGap = 12.0;

  /// A video or a part (141, 153): its title on one line in a card 52 tall, the mark in the card's corner.
  static const titleRowHeight = 52.0;
  static const titleRowLead = 14.0;
  static const titleRowTrailing = 5.67;
  static const titleText = 14.0;
  static const titleLine = 20.0;
  static const playingGap = 6.67;
  static const playing = BiliColors.pink;
  static const playingBars = Color(0xFFFB7299);

  /// A 合集's video (144, 154): the cover 134.67 × 76 with 12 round it, the title two 20 pt lines beside it.
  static const coverRowPad = 12.0;
  static const coverWidth = 134.67;
  static const coverHeight = 76.0;
  static const coverGap = 8.67;

  /// The state's 13 pt circle: an empty ring, the pink progress over it, or 153's green ✓.
  static const mark = 13.0;
  static const markStroke = 2.5;
  static const markInset = 4.0;
  static const markTrack = BiliColors.divider;
  static const markDone = Color(0xFF2AC864);
  static const markFailed = BiliColors.failure;

  /// KaiC's sizes: 约 78.4MB left of the mark, on its line.
  static const sizeText = 10.0;
  static const sizeGap = 6.0;

  /// 内容到底啦 (154), centred 40.5 under the last card, 28.5 over the bar.
  static const footerCentre = 40.5;
  static const footerBottom = 28.5;

  /// The bar (141): 缓存全部 | 查看缓存 on a line 28 below its hairline, the space line 62.5 below it; its numbers
  /// are medium and a little larger than the words (their caps 7.67 tall on 141 and 154).
  static const barHeight = 70.0;
  static const barButtonCentre = 28.0;
  static const barButtonText = 16.0;
  static const barDivider = 22.0;
  static const barSpaceCentre = 62.5;
  static const barSpaceText = 10.0;
  static const barSpaceValueText = 10.5;
  static const barSpaceValueWeight = FontWeight.w500;
  static const dot = Color(0xFFF85A54);
  static const dotSize = 6.0;
  static const dotRing = 1.0;
  static const dotLift = 1.0;

  /// 画质's own sheet (142): its card 19 below its top, rows of 52 with the text 16 in.
  static const pickerCardTop = 19.0;
  static const pickerRowLead = 16.0;
  static const pickerBottom = 12.0;
}

/// 离线缓存, 正在缓存, a 合集's page and their search and edit modes (143, 145-151, 155-157), measured at 3 px per pt.
abstract final class OfflineListTheme {
  static OfflineListThemeColors colorsOf(BuildContext context) => OfflineListThemeColors(BiliPalette.of(context));

  static const page = BiliColors.card;
  static const ink = BiliColors.text;
  static const grey = Color(0xFF61666D);
  static const meta = BiliColors.secondaryText;

  /// The bar, 44 under the status bar: the 装扮's second-page colour and text colour (KaiC's green, 143), else white
  /// with the page's text (a guess, as 我的关注's). No hairline ends it.
  static const barRow = 44.0;
  static const bar = BiliColors.card;
  static const barInk = BiliColors.text;
  static const barLightInk = Color(0xFFFFFFFF);

  /// The title, 17 pt semibold, centred on the screen and the row.
  static const titleText = 17.0;
  static const titleWeight = FontWeight.w600;
  static const titleLine = 24.0;
  static const titleDrop = 0.0;

  /// ‹: 1.5 strokes, its tip 20.08 in and its ends 27.92 in, 8.25 above and below the row's middle.
  static const backTarget = 44.0;
  static const backTipX = 20.08;
  static const backEndX = 27.92;
  static const backHalfHeight = 8.25;
  static const backStroke = 1.5;

  /// 🔍 and ☰, 36 apart, the last centred 24 from the edge (🔍 takes ☰'s place while nothing is finished, 143).
  static const iconTarget = 36.0;
  static const iconLastCentre = 24.0;

  /// 🔍: an 18 square, its ring 16.67 across with 1.67 strokes, the handle to the corner; centred 0.67 above the row's
  /// middle.
  static const searchBox = 18.0;
  static const searchRingCentre = 25 / 3;
  static const searchRingRadius = 7.5;
  static const searchStroke = 5 / 3;
  static const searchHandleEnd = 17.17;
  static const searchLift = 2 / 3;

  /// ☰ (edit): three 1.5 bars 11.67 long, 6.17 apart; ✓, ○, ✓ before them. 18.67 × 16.33 of ink, centred 0.17 above
  /// the row's middle.
  static const editWidth = 56 / 3;
  static const editHeight = 49 / 3;
  static const editStroke = 1.5;
  static const editPitch = 37 / 6;
  static const editBarLeft = 7.75;
  static const editBarRight = 17.92;
  static const editMarkCentre = 2.83;
  static const editRingRadius = 1.85;
  static const editRingStroke = 1.3;
  static const editLift = 1 / 6;

  /// 完成 (149) and the search's 取消 (151), 14 pt in the bar's ink, ending 16.67 and 12.33 from the edge.
  static const actionText = 14.0;
  static const doneRight = 50 / 3;
  static const cancelRight = 37 / 3;

  /// 搜索已下载的内容 (151): a 28 tall #F1F2F3 stadium from 12 in to 52 from the edge on the row's middle; the grey
  /// magnifier (搜索's) 12 square of ink, 18 in and 0.67 low; the words 14 pt from 30.33 in; 搜索's ⓧ once there is
  /// text (no screenshot).
  static const fieldLeft = 12.0;
  static const fieldRight = 52.0;
  static const fieldHeight = 28.0;
  static const field = BiliColors.pageGrey;
  static const fieldText = 14.0;
  static const fieldLine = 20.0;
  static const fieldInk = BiliColors.text;
  static const fieldHint = BiliColors.sheetHint;
  static const caret = BiliColors.pink;
  static const fieldGlyph = 37 / 3;
  static const fieldGlyphCentre = 18.0;
  static const fieldGlyphDrop = 2 / 3;
  static const clearGlyph = 40 / 3;
  static const clearInk = Color(0xFFC9CCCF);
  static const clearTarget = 36.0;
  static const fieldTextLeft = 91 / 3;

  /// 正在缓存 and 已缓存视频: a 43 tall block, 16 pt semibold 12 in, its middle 25.33 down.
  static const headerHeight = 43.0;
  static const headerCentre = 76 / 3;
  static const headerText = 16.0;
  static const headerWeight = FontWeight.w600;
  static const headerLeft = 12.0;

  /// A row: 102 tall, the 139 × 78 cover 12 in and 12 down with 6 corners; the words from 159 to 12 from the edge.
  static const row = 102.0;
  static const coverLeft = 12.0;
  static const coverTop = 12.0;
  static const coverWidth = 139.0;
  static const coverHeight = 78.0;
  static const coverRadius = 6.0;
  static const coverPlaceholder = BiliColors.pageGrey;
  static const textLeft = 159.0;
  static const textRight = 12.0;

  /// The title, 14 pt in up to two lines 21.33 apart, the first's middle 8.25 under the cover's top; under it the part
  /// or episode, 12 pt #61666D, its middle 28.33 down.
  static const rowTitleText = 14.0;
  static const rowTitleLine = 64 / 3;
  static const rowTitleCentre = 8.25;
  static const subText = 12.0;
  static const subLine = 16.0;
  static const subCentre = 85 / 3;

  /// The state, 12 pt #61666D, its middle 62.83 down; then a 2 tall line from the words' left to 12 from the edge at
  /// the cover's bottom: pink while downloading, #9499A0 otherwise, on #E3E5E7.
  static const stateText = 12.0;
  static const stateLine = 16.0;
  static const stateCentre = 377 / 6;
  static const progressHeight = 2.0;
  static const progressTrack = BiliColors.divider;
  static const progressActive = BiliColors.pink;
  static const progressIdle = BiliColors.secondaryText;

  /// UP and the name, then the size, 12 pt #9499A0, their middles 55.67 and 70.83 down; 大会员专享 · size in pink.
  /// UP is 历史记录's glyph in a 13.67 box 1 in, the name 3.33 after it.
  static const metaText = 12.0;
  static const metaLine = 16.0;
  static const upCentre = 167 / 3;
  static const sizeCentre = 425 / 6;
  static const metaInset = 1.0;
  static const upBox = 41 / 3;
  static const upGap = 10 / 3;
  static const upLift = 0.5;
  static const vip = BiliColors.pink;

  /// Between rows a 2/3 hairline from the cover's left to the screen's edge, halfway between the covers.
  static const divider = Color(0xFFEAEBED);
  static const dividerHeight = 2 / 3;

  /// On the cover: the length (or watched / length) 10 pt white in a 15.67 tall pill of black at 0.4, 4 in from the
  /// right and 4.33 up, 3.67 each side of the words; a watched line 2 tall at the bottom, pink on black at 0.6.
  static const pillText = 10.0;
  static const pillHeight = 47 / 3;
  static const pillPadX = 11 / 3;
  static const pillRight = 4.0;
  static const pillBottom = 13 / 3;
  static const pillRadius = 4.0;
  static const pillFill = Color(0x66000000);
  static const pillInk = BiliColors.onCover;
  static const watchedHeight = 2.0;
  static const watchedTrack = Color(0x99000000);
  static const watched = BiliColors.pink;

  /// A 合集's cover (155): the pill holds the stack, 10 × 9.17 of ink, and the count 5.67 after it.
  static const stackWidth = 10.0;
  static const stackHeight = 55 / 6;
  static const stackGap = 17 / 3;

  /// 正在缓存's stacked cover (143, 145): a #C9CCD0 card 7 above it, 6 in each side; the cover shaded by half and
  /// N个内容 12 pt white on its middle.
  static const stackCard = Color(0xFFC9CCD0);
  static const stackCardRise = 7.0;
  static const stackCardInset = 6.0;
  static const queueShade = BiliColors.coverShade;
  static const queueCountText = 12.0;

  /// 已使用 / 剩余, 12 pt, its middle 19.67 above the home indicator's inset on 离线缓存 and 正在缓存, 22.67 on a
  /// 合集's page (156).
  static const footerText = 12.0;
  static const footerLine = 16.0;
  static const footerHeight = 40.0;
  static const footerCentre = 59 / 3;
  static const folderFooterCentre = 68 / 3;

  /// 正在缓存's strip (146): 56 tall. The pill 12 in and 12 down, 32 tall, #F6F7F8: ❚❚ or ▶ (#61666D) 14 in, 8 wide,
  /// then 14 pt words 6.33 after it and 11.33 before the end. 同时缓存数量：N 14 pt #9499A0, then ⌄ 8.67 × 4.67 with
  /// 1.2 strokes, 9.17 after the words and 13.67 from the edge.
  static const stripHeight = 56.0;
  static const pillTop = 12.0;
  static const pillLeft = 12.0;
  static const allHeight = 32.0;
  static const allFill = BiliColors.softGrey;
  static const allPadLeft = 14.0;
  static const allPadRight = 34 / 3;
  static const allGlyphWidth = 8.0;
  static const allGlyphGap = 19 / 3;
  static const allText = 14.0;
  static const allGlyph = Color(0xFF61666D);
  static const pauseBar = 3.0;
  static const pauseHeight = 28 / 3;
  static const playHeight = 9.2;
  static const playRound = 1.2;
  static const countText = 14.0;
  static const countInk = BiliColors.secondaryText;
  static const chevronWidth = 26 / 3;
  static const chevronHeight = 14 / 3;
  static const chevronStroke = 1.2;
  static const chevronGap = 9.17;
  static const chevronRight = 41 / 3;

  /// Edit mode (149): the strip goes, rows slide 32 right for a 19.33 circle centred 24 in on the cover's middle, a
  /// 1 pt #61666D ring or pink with a white ✓. At the bottom, 全选 (its circle the same, 14 pt #484C52 from 44) and
  /// 删除 (14 pt #61666D, at half until something is chosen, ending 13 from the edge), their middle 26.08 above the
  /// home indicator's inset.
  static const editShift = 32.0;
  static const editMotion = Duration(milliseconds: 220);
  static const circle = 58 / 3;
  static const circleCentreX = 24.0;
  static const circleStroke = 1.0;
  static const circleRing = Color(0xFF61666D);
  static const circleChosen = BiliColors.pink;
  static const checkInk = BiliColors.onPink;
  static const checkStroke = 1.4;
  static const editBarHeight = 158 / 3;
  static const editBarCentre = 313 / 12;
  static const editText = 14.0;
  static const selectAllLeft = 44.0;
  static const selectAllInk = Color(0xFF484C52);
  static const deleteInk = Color(0xFF61666D);
  static const deleteOffOpacity = 0.5;
  static const deleteRight = 13.0;

  /// 确定要删除吗? (150): 280 wide with 8 corners, centred between the status bar and the home indicator's inset, over
  /// black at 0.6; the question 20 pt semibold, 3 above the middle of a 66.33 block, a 2/3 #E3E5E7 rule, 取消 and pink
  /// 确认 20 pt in a 44.33 row, each 4 further out than its half's middle.
  static const confirmWidth = 280.0;
  static const confirmRadius = 8.0;
  static const confirmDim = Color(0x99000000);
  static const confirmTitleText = 20.0;
  static const confirmTitleWeight = FontWeight.w600;
  static const confirmTitleHeight = 199 / 3;
  static const confirmTitleLift = 3.0;
  static const confirmRule = 2 / 3;
  static const confirmRuleInk = BiliColors.divider;
  static const confirmButtonHeight = 133 / 3;
  static const confirmButtonText = 20.0;
  static const confirmButtonSpread = 8.0;
  static const confirmCancel = BiliColors.text;
  static const confirmAction = BiliColors.pink;
  static const confirmPressed = BiliColors.pressedFill;
  static const confirmMotion = Duration(milliseconds: 200);

  /// 同时缓存数量's sheet (147): #F6F7F8 with 12 corners over black at 0.32; a 30 × 3 #C9CCD0 handle 8 down; a white
  /// card 16 in at 19 down with 8 corners, three 52 rows split by 0.5 #E3E5E7 rules 16 in; 14 pt words 16 in, the
  /// chosen pink; (大会员专享) 10 pt white in a 13 tall pink stadium 8.67 after the words, 4.33 each side; 20 under
  /// the card.
  static const sheet = BiliColors.softGrey;
  static const sheetRadius = 12.0;
  static const sheetDim = Color(0x52000000);
  static const sheetMotion = Duration(milliseconds: 250);
  static const handleWidth = 30.0;
  static const handleHeight = 3.0;
  static const handleTop = 8.0;
  static const handle = Color(0xFFC9CCD0);
  static const cardTop = 19.0;
  static const cardInset = 16.0;
  static const cardRadius = 8.0;
  static const cardBottom = 20.0;
  static const optionRow = 52.0;
  static const optionText = 14.0;
  static const optionInk = BiliColors.text;
  static const optionChosen = BiliColors.pink;
  static const optionInset = 16.0;
  static const optionRule = 0.5;
  static const optionRuleInk = BiliColors.divider;
  static const badgeGap = 26 / 3;
  static const badgeHeight = 13.0;
  static const badgeText = 10.0;
  static const badgePadX = 13 / 3;
  static const badgeFill = BiliColors.pink;
  static const badgeInk = BiliColors.onPink;

  /// No screenshot: an empty page or search says so in 14 pt #9499A0, 120 under the bar.
  static const emptyText = 14.0;
  static const emptyTop = 120.0;
}

/// A cached video's page under the player (158-161), measured at 3 px per pt.
abstract final class OfflinePageTheme {
  static OfflinePageThemeColors colorsOf(BuildContext context) => OfflinePageThemeColors(BiliPalette.of(context));

  /// 离线缓存 (N个视频) and 点我发弹幕 in a 42 pt band under the player with no hairline, the capsule 30 tall, border
  /// to border, its border one crisp pixel. Its top is 316.67 on 158, 7 under the phone's player, which ends on the
  /// pixel at 309.67; ours ends at 309.5, so the extra sixth keeps the border on a pixel.
  static const headerHeight = 42.0;
  static const capsuleCentre = 22 + 1 / 6;
  static const capsuleHeight = 30.0;
  static const capsuleBorder = 1 / 3;
  static const gutter = 12.0;

  /// 离线缓存 in black, bold, its ink centred 21.2 below the player; (N个视频) in the page's grey after it.
  static const titleText = 16.0;
  static const titleWeight = FontWeight.w600;
  static const titleInk = Color(0xFF000000);
  static const titleCentre = 21.17;
  static const countText = 12.0;
  static const countInk = BiliColors.secondaryText;
  static const countGap = 4.0;

  /// A row is 100: the 135 × 76 cover 12 down at the gutter, the text 8.5 right of it, a hairline between rows from
  /// the gutter to the right edge (none after the last).
  static const rowHeight = 100.0;
  static const rowPadTop = 12.0;
  static const coverWidth = 135.0;
  static const coverHeight = 76.0;
  static const coverRadius = 6.0;
  static const textGap = 8.5;
  static const hairline = 1 / 3;
  static const divider = BiliColors.divider;

  /// The title: 14 pt (158's pink and 160's black alike step 14 a glyph) in two lines 20 apart, its ink from 2 below the
  /// cover's top; the box ends at the gutter, which holds 160's 19 glyphs a line and not a 20th.
  static const rowTitleText = 14.0;
  static const rowTitleLine = 20.0;
  static const rowTitleTop = -4 / 3;
  static const titleRight = gutter;
  static const rowTitle = BiliColors.text;
  static const playing = BiliColors.pink;

  /// The playing bars before the title (158, 160): three round-ended 2 wide, 4.67 apart, the first centred 1.83 into
  /// the text box, standing on a line 1.33 above the baseline, 4 before the first glyph; they rise and fall while the
  /// video plays.
  static const barsLead = 5 / 6;
  static const barsLift = 4 / 3;
  static const barWidth = 2.0;
  static const barPitch = 14 / 3;
  static const barsWidth = barWidth + 2 * barPitch;
  static const barsHeight = 25 / 3;
  static const barsGap = 29 / 6;
  static const barMin = 3.0;
  static const barsInk = Color(0xFFFB7299);
  static const barsCycle = Duration(milliseconds: 900);

  /// Heights at rest, as 160 caught them.
  static const barRest = <double>[6, 6, 25 / 3];

  /// The UP line and the size line, their ink centred 53 and 70 below the cover's top: UP and the name in the page's
  /// grey, the size grey or, for a 大会员 quality, 大会员专享 · size in pink.
  static const metaText = 12.0;
  static const metaLine = 16.0;
  static const upCentre = 53.0;
  static const sizeCentre = 70.0;
  static const meta = BiliColors.secondaryText;
  static const vip = BiliColors.pink;
  static const upBox = 41 / 3;
  static const upGap = 3.3;

  /// ⋮: 2 pt dots 4.33 apart, centred 20 from the right on the size line.
  static const moreCentreRight = 20.0;
  static const moreTarget = 44.0;

  /// The duration on the cover: a 15.33 tall pill of half black, 4 in from the cover's lower right.
  static const pillText = 10.5;
  static const pillHeight = 46 / 3;
  static const pillPadX = 2.0;
  static const pillRight = 4.0;
  static const pillBottom = 4.0;
  static const pillRadius = 2.0;
  static const pillFill = BiliColors.coverShade;
  static const pillInk = BiliColors.onCover;

  /// 仅展示本App中可查看的稿件, its ink centred 29 below the last row.
  static const footerText = 12.0;
  static const footerCentre = 29.0;
  static const footerInk = Color(0xFFC9CCD0);
  static const footerBottom = 24.0;

  /// A row's ⋮ sheet (159): the page dimmed by half, a white 查看详情页 row 50 tall with the pink ▷ ring 22 in, a 5 pt
  /// grey band, 取消 55 tall, and the home indicator's inset in the band's grey.
  static const sheetDim = Color(0x80000000);
  static const sheetIn = Duration(milliseconds: 280);
  static const sheetOut = Duration(milliseconds: 220);
  static const sheetFill = BiliColors.card;
  static const sheetBand = BiliColors.pageGrey;
  static const sheetRowHeight = 50.0;
  static const sheetBandHeight = 5.0;
  static const sheetCancelHeight = 55.0;
  static const sheetIconLeft = 22.0;
  static const sheetIcon = 21.0;
  static const sheetIconStroke = 1.5;
  static const sheetIconInk = BiliColors.pink;
  static const sheetLabelLeft = 60.0;
  static const sheetLabelText = 14.0;
  static const sheetCancelText = 15.0;

  /// Centred in their rows, the labels' ink sits this much higher on 159.
  static const sheetLabelLift = 4 / 3;
  static const sheetCancelLift = 1.0;
  static const sheetInk = BiliColors.text;
}

// Context-resolved color views. The static constants above remain the measured light values.

@immutable
class BiliColorsColors {
  const BiliColorsColors(this._palette);

  final BiliPalette _palette;
  Color get pink => _palette.choose(BiliColors.pink, _palette.accent);
  Color get pinkTint => _palette.choose(BiliColors.pinkTint, _palette.accentTint);
  Color get text => _palette.choose(BiliColors.text, _palette.text);
  Color get secondaryText => _palette.choose(BiliColors.secondaryText, _palette.secondary);
  Color get pageGrey => _palette.choose(BiliColors.pageGrey, _palette.page);
  Color get softGrey => _palette.choose(BiliColors.softGrey, _palette.raised);
  Color get divider => _palette.choose(BiliColors.divider, _palette.divider);
  Color get link => _palette.choose(BiliColors.link, _palette.link);
  Color get card => _palette.choose(BiliColors.card, _palette.surface);
  Color get reasonTint => _palette.choose(BiliColors.reasonTint, const Color(0xFF38251F));
  Color get sheetGrabber => _palette.choose(BiliColors.sheetGrabber, _palette.disabled);
  Color get sheetCloseGlyph => _palette.choose(BiliColors.sheetCloseGlyph, _palette.icon);
  Color get sheetHint => _palette.choose(BiliColors.sheetHint, _palette.disabled);
  Color get shimmerBase => _palette.choose(BiliColors.shimmerBase, _palette.shimmerBase);
  Color get shimmerHighlight => _palette.choose(BiliColors.shimmerHighlight, _palette.shimmerHighlight);
  Color get glassFill => _palette.choose(BiliColors.glassFill, _palette.glass);
  Color get glassBorder => _palette.choose(BiliColors.glassBorder, _palette.glassBorder);
  Color get pressedFill => _palette.choose(BiliColors.pressedFill, _palette.pressed);
}

@immutable
class PageThemeColors {
  const PageThemeColors(this._palette);

  final BiliPalette _palette;
  Color get tabText => _palette.choose(PageTheme.tabText, _palette.icon);
}

@immutable
class IntroThemeColors {
  const IntroThemeColors(this._palette);

  final BiliPalette _palette;
  Color get name => _palette.choose(IntroTheme.name, _palette.icon);
  Color get followedFill => _palette.choose(IntroTheme.followedFill, _palette.page);
  Color get followedText => _palette.choose(IntroTheme.followedText, _palette.secondary);
  Color get tagInk => _palette.choose(IntroTheme.tagInk, _palette.icon);
}

@immutable
class IntroListThemeColors {
  const IntroListThemeColors(this._palette);

  final BiliPalette _palette;
  Color get chipTextColor => _palette.choose(IntroListTheme.chipTextColor, _palette.icon);
  Color get chipGlyphColor => _palette.choose(IntroListTheme.chipGlyphColor, _palette.icon);
}

@immutable
class ActionThemeColors {
  const ActionThemeColors(this._palette);

  final BiliPalette _palette;
  Color get icon => _palette.choose(ActionTheme.icon, _palette.icon);
  Color get count => _palette.choose(ActionTheme.count, _palette.secondary);
}

@immutable
class FavouriteThemeColors {
  const FavouriteThemeColors(this._palette);

  final BiliPalette _palette;
  Color get ringLight => _palette.choose(FavouriteTheme.ringLight, _palette.disabled);
  Color get switchOffLight => _palette.choose(FavouriteTheme.switchOffLight, _palette.raised);
}

@immutable
class CommentRowThemeColors {
  const CommentRowThemeColors(this._palette);

  final BiliPalette _palette;
  Color get vipMarkFill => _palette.choose(CommentRowTheme.vipMarkFill, _palette.accent);
  Color get name => _palette.choose(CommentRowTheme.name, _palette.secondary);
  Color get upFill => _palette.choose(CommentRowTheme.upFill, _palette.accent);
  Color get pinnedInk => _palette.choose(CommentRowTheme.pinnedInk, _palette.accent);
  Color get text => _palette.choose(CommentRowTheme.text, _palette.text);
  Color get picturePlaceholder => _palette.choose(CommentRowTheme.picturePlaceholder, _palette.page);
  Color get meta => _palette.choose(CommentRowTheme.meta, _palette.disabled);
  Color get action => _palette.choose(CommentRowTheme.action, _palette.icon);
  Color get liked => _palette.choose(CommentRowTheme.liked, _palette.accent);
  Color get upLiked => _palette.choose(CommentRowTheme.upLiked, _palette.secondary);
  Color get upChipFill => _palette.choose(CommentRowTheme.upChipFill, _palette.raised);
  Color get upChipInk => _palette.choose(CommentRowTheme.upChipInk, _palette.icon);
  Color get box => _palette.choose(CommentRowTheme.box, _palette.raised);
  Color get preview => _palette.choose(CommentRowTheme.preview, _palette.text);
  Color get previewName => _palette.choose(CommentRowTheme.previewName, _palette.secondary);
  Color get moreLink => _palette.choose(CommentRowTheme.moreLink, _palette.link);
  Color get dividerColour => _palette.choose(CommentRowTheme.dividerColour, _palette.divider);
}

@immutable
class CommentListThemeColors {
  const CommentListThemeColors(this._palette);

  final BiliPalette _palette;
  Color get background => _palette.choose(CommentListTheme.background, _palette.surface);
  Color get rule => _palette.choose(CommentListTheme.rule, _palette.divider);
  Color get sortInk => _palette.choose(CommentListTheme.sortInk, _palette.secondary);
  Color get footerInk => _palette.choose(CommentListTheme.footerInk, _palette.disabled);
  Color get retryInk => _palette.choose(CommentListTheme.retryInk, _palette.secondary);
  Color get retryAction => _palette.choose(CommentListTheme.retryAction, _palette.link);
  Color get closedInk => _palette.choose(CommentListTheme.closedInk, _palette.secondary);
  Color get fieldFill => _palette.choose(CommentListTheme.fieldFill, _palette.page);
  Color get fieldInk => _palette.choose(CommentListTheme.fieldInk, _palette.secondary);
  Color get faceInk => _palette.choose(CommentListTheme.faceInk, _palette.secondary);
  Color get threadTitleInk => _palette.choose(CommentListTheme.threadTitleInk, _palette.text);
  Color get closeInk => _palette.choose(CommentListTheme.closeInk, _palette.secondary);
  Color get band => _palette.choose(CommentListTheme.band, _palette.page);
}

@immutable
class CommentTextThemeColors {
  const CommentTextThemeColors(this._palette);

  final BiliPalette _palette;
  Color get link => _palette.choose(CommentTextTheme.link, _palette.link);
  Color get replyTarget => _palette.choose(CommentTextTheme.replyTarget, _palette.secondary);
}

@immutable
class ComposerThemeColors {
  const ComposerThemeColors(this._palette);

  final BiliPalette _palette;
  Color get sheet => _palette.choose(ComposerTheme.sheet, _palette.surface);
  Color get text => _palette.choose(ComposerTheme.text, _palette.text);
  Color get placeholder => _palette.choose(ComposerTheme.placeholder, _palette.disabled);
  Color get tool => _palette.choose(ComposerTheme.tool, _palette.secondary);
  Color get syncText => _palette.choose(ComposerTheme.syncText, _palette.icon);
  Color get syncRing => _palette.choose(ComposerTheme.syncRing, _palette.disabled);
  Color get panel => _palette.choose(ComposerTheme.panel, _palette.page);
  Color get tabBar => _palette.choose(ComposerTheme.tabBar, _palette.surface);
  Color get tabSelected => _palette.choose(ComposerTheme.tabSelected, _palette.page);
  Color get sectionTitle => _palette.choose(ComposerTheme.sectionTitle, _palette.icon);
  Color get kaomoji => _palette.choose(ComposerTheme.kaomoji, _palette.text);
  Color get kaomojiTab => _palette.choose(ComposerTheme.kaomojiTab, _palette.secondary);
}

@immutable
class CommentOverlayThemeColors {
  const CommentOverlayThemeColors(this._palette);

  final BiliPalette _palette;
  Color get threadFill => _palette.choose(CommentOverlayTheme.threadFill, _palette.surface);
  Color get alertTitle => _palette.choose(CommentOverlayTheme.alertTitle, _palette.text);
  Color get alertMessage => _palette.choose(CommentOverlayTheme.alertMessage, _palette.secondary);
  Color get alertCancel => _palette.choose(CommentOverlayTheme.alertCancel, _palette.secondary);
  Color get alertDelete => _palette.choose(CommentOverlayTheme.alertDelete, _palette.accent);
}

@immutable
class MentionThemeColors {
  const MentionThemeColors(this._palette);

  final BiliPalette _palette;
  Color get fieldFill => _palette.choose(MentionTheme.fieldFill, _palette.page);
  Color get clearFill => _palette.choose(MentionTheme.clearFill, _palette.disabled);
  Color get clearGlyphColor => _palette.choose(MentionTheme.clearGlyphColor, _palette.surface);
  Color get sectionColour => _palette.choose(MentionTheme.sectionColour, _palette.icon);
  Color get match => _palette.choose(MentionTheme.match, _palette.accent);
}

@immutable
class AvatarPageThemeColors {
  const AvatarPageThemeColors(this._palette);

  final BiliPalette _palette;
  Color get background => _palette.choose(AvatarPageTheme.background, _palette.raised);
  Color get barIcon => _palette.choose(AvatarPageTheme.barIcon, _palette.icon);
  Color get remove => _palette.choose(AvatarPageTheme.remove, _palette.disabled);
}

@immutable
class MeThemeColors {
  const MeThemeColors(this._palette);

  final BiliPalette _palette;
  Color get background => _palette.choose(MeTheme.background, _palette.surface);
  Color get topGlyph => _palette.choose(MeTheme.topGlyph, _palette.icon);
  Color get vipDiscFill => _palette.choose(MeTheme.vipDiscFill, _palette.accent);
  Color get name => _palette.choose(MeTheme.name, _palette.text);
  Color get vipName => _palette.choose(MeTheme.vipName, _palette.accent);
  Color get pencil => _palette.choose(MeTheme.pencil, _palette.secondary);
  Color get coins => _palette.choose(MeTheme.coins, _palette.secondary);
  Color get space => _palette.choose(MeTheme.space, _palette.secondary);
  Color get count => _palette.choose(MeTheme.count, _palette.text);
  Color get countLabel => _palette.choose(MeTheme.countLabel, _palette.secondary);
  Color get countRule => _palette.choose(MeTheme.countRule, _palette.divider);
  Color get cardTitle => _palette.choose(MeTheme.cardTitle, _palette.text);
  Color get cardButtonFill => _palette.choose(MeTheme.cardButtonFill, _palette.accent);
  Color get shortcutLabel => _palette.choose(MeTheme.shortcutLabel, _palette.text);
  Color get servicesTitle => _palette.choose(MeTheme.servicesTitle, _palette.text);
  Color get serviceLabel => _palette.choose(MeTheme.serviceLabel, _palette.text);
  Color get serviceChevron => _palette.choose(MeTheme.serviceChevron, _palette.secondary);
  Color get card => _palette.choose(MeTheme.card, _palette.raised);
  Color get cardMore => _palette.choose(MeTheme.cardMore, _palette.secondary);
  List<Color> get skinFadeColors => _palette.isDark
      ? MeTheme.skinFadeColors.map((color) => _palette.surface.withValues(alpha: color.a)).toList()
      : MeTheme.skinFadeColors;
}

@immutable
class DanmakuPanelThemeColors {
  const DanmakuPanelThemeColors(this._palette);

  final BiliPalette _palette;
  Color get lightBackground => _palette.choose(DanmakuPanelTheme.lightBackground, _palette.raised);
  Color get lightCard => _palette.choose(DanmakuPanelTheme.lightCard, _palette.surface);
  Color get lightSquare => _palette.choose(DanmakuPanelTheme.lightSquare, _palette.divider);
  Color get lightTrack => _palette.choose(DanmakuPanelTheme.lightTrack, _palette.divider);
  Color get lightHairline => _palette.choose(DanmakuPanelTheme.lightHairline, _palette.divider);
  Color get lightText => _palette.choose(DanmakuPanelTheme.lightText, _palette.text);
  Color get lightSecondary => _palette.choose(DanmakuPanelTheme.lightSecondary, _palette.secondary);
  Color get lightReset => _palette.choose(DanmakuPanelTheme.lightReset, _palette.icon);
  Color get lightSwitchOff => _palette.choose(DanmakuPanelTheme.lightSwitchOff, _palette.raised);
}

@immutable
class BlockWordsThemeColors {
  const BlockWordsThemeColors(this._palette);

  final BiliPalette _palette;
  Color get grey => _palette.choose(BlockWordsTheme.grey, _palette.secondary);
  Color get fieldFill => _palette.choose(BlockWordsTheme.fieldFill, _palette.surface);
  Color get fieldInk => _palette.choose(BlockWordsTheme.fieldInk, _palette.text);
}

@immutable
class DanmakuSendThemeColors {
  const DanmakuSendThemeColors(this._palette);

  final BiliPalette _palette;
  Color get lightBar => _palette.choose(DanmakuSendTheme.lightBar, _palette.surface);
  Color get lightArea => _palette.choose(DanmakuSendTheme.lightArea, _palette.page);
  Color get lightAccent => _palette.choose(DanmakuSendTheme.lightAccent, _palette.accent);
  Color get lightGlyph => _palette.choose(DanmakuSendTheme.lightGlyph, _palette.icon);
  Color get lightField => _palette.choose(DanmakuSendTheme.lightField, _palette.page);
  Color get lightSecondary => _palette.choose(DanmakuSendTheme.lightSecondary, _palette.secondary);
}

@immutable
class DanmakuListThemeColors {
  const DanmakuListThemeColors(this._palette);

  final BiliPalette _palette;
  Color get liked => _palette.choose(DanmakuListTheme.liked, _palette.accent);
  Color get divider => _palette.choose(DanmakuListTheme.divider, _palette.text);
  Color get emptyColor => _palette.choose(DanmakuListTheme.emptyColor, _palette.secondary);
}

@immutable
class HistoryThemeColors {
  const HistoryThemeColors(this._palette);

  final BiliPalette _palette;
  Color get back => _palette.choose(HistoryTheme.back, _palette.icon);
  Color get divider => _palette.choose(HistoryTheme.divider, _palette.divider);
  Color get rowTitle => _palette.choose(HistoryTheme.rowTitle, _palette.text);
  Color get meta => _palette.choose(HistoryTheme.meta, _palette.secondary);
  Color get more => _palette.choose(HistoryTheme.more, _palette.disabled);
  Color get stateInk => _palette.choose(HistoryTheme.stateInk, _palette.secondary);
  Color get footerInk => _palette.choose(HistoryTheme.footerInk, _palette.disabled);
  Color get sheetFill => _palette.choose(HistoryTheme.sheetFill, _palette.surface);
  Color get sheetHeaderInk => _palette.choose(HistoryTheme.sheetHeaderInk, _palette.icon);
  Color get sheetCircleFill => _palette.choose(HistoryTheme.sheetCircleFill, _palette.accent);
  Color get sheetLabelInk => _palette.choose(HistoryTheme.sheetLabelInk, _palette.secondary);
  Color get sheetDividerInk => _palette.choose(HistoryTheme.sheetDividerInk, _palette.divider);
  Color get sheetDeleteInk => _palette.choose(HistoryTheme.sheetDeleteInk, _palette.icon);
  Color get sheetBandFill => _palette.choose(HistoryTheme.sheetBandFill, _palette.raised);
  Color get sheetCancelInk => _palette.choose(HistoryTheme.sheetCancelInk, _palette.icon);
}

@immutable
class LoginThemeColors {
  const LoginThemeColors(this._palette);

  final BiliPalette _palette;
  Color get bar => _palette.choose(LoginTheme.bar, _palette.surface);
  Color get page => _palette.choose(LoginTheme.page, _palette.surface);
  Color get title => _palette.choose(LoginTheme.title, _palette.text);
  Color get close => _palette.choose(LoginTheme.close, _palette.text);
  Color get message => _palette.choose(LoginTheme.message, _palette.secondary);
  Color get retry => _palette.choose(LoginTheme.retry, _palette.accent);
  Color get qrModule => _palette.choose(LoginTheme.qrModule, _palette.text);
  Color get qrBackground => _palette.choose(LoginTheme.qrBackground, _palette.surface);
}

@immutable
class SettingsThemeColors {
  const SettingsThemeColors(this._palette);

  final BiliPalette _palette;
  Color get bar => _palette.choose(SettingsTheme.bar, _palette.surface);
  Color get barTitle => _palette.choose(SettingsTheme.barTitle, _palette.text);
  Color get backGlyph => _palette.choose(SettingsTheme.backGlyph, _palette.icon);
  Color get page => _palette.choose(SettingsTheme.page, _palette.page);
  Color get row => _palette.choose(SettingsTheme.row, _palette.surface);
  Color get rowTitle => _palette.choose(SettingsTheme.rowTitle, _palette.text);
  Color get rowDisabled => _palette.choose(SettingsTheme.rowDisabled, _palette.secondary);
  Color get value => _palette.choose(SettingsTheme.value, _palette.secondary);
  Color get hairlineColor => _palette.choose(SettingsTheme.hairlineColor, _palette.divider);
  Color get chevron => _palette.choose(SettingsTheme.chevron, _palette.secondary);
  Color get switchOn => _palette.choose(SettingsTheme.switchOn, _palette.accent);
  Color get switchOff => _palette.choose(SettingsTheme.switchOff, _palette.raised);
  Color get footer => _palette.choose(SettingsTheme.footer, _palette.secondary);
  Color get confirm => _palette.choose(SettingsTheme.confirm, _palette.surface);
  Color get confirmTitle => _palette.choose(SettingsTheme.confirmTitle, _palette.text);
  Color get confirmMessage => _palette.choose(SettingsTheme.confirmMessage, _palette.secondary);
  Color get confirmRuleColor => _palette.choose(SettingsTheme.confirmRuleColor, _palette.divider);
  Color get confirmCancel => _palette.choose(SettingsTheme.confirmCancel, _palette.text);
  Color get confirmAction => _palette.choose(SettingsTheme.confirmAction, _palette.accent);
  Color get confirmPressed => _palette.choose(SettingsTheme.confirmPressed, _palette.pressed);
  Color get vipName => _palette.choose(SettingsTheme.vipName, _palette.accent);
  Color get vipBadge => _palette.choose(SettingsTheme.vipBadge, _palette.accent);
}

@immutable
class HomeTabBarThemeColors {
  const HomeTabBarThemeColors(this._palette);

  final BiliPalette _palette;
  Color get bar => _palette.choose(HomeTabBarTheme.bar, _palette.surface);
  Color get hairline => _palette.choose(HomeTabBarTheme.hairline, _palette.divider);
  Color get label => _palette.choose(HomeTabBarTheme.label, _palette.icon);
  Color get selected => _palette.choose(HomeTabBarTheme.selected, _palette.accent);
  Color get fieldInk => _palette.choose(HomeTabBarTheme.fieldInk, _palette.icon);
  Color get headDivider => _palette.choose(HomeTabBarTheme.headDivider, _palette.page);
  Color get headField => _palette.choose(HomeTabBarTheme.headField, _palette.surface);
}

@immutable
class CoverPlaceholderThemeColors {
  const CoverPlaceholderThemeColors(this._palette);

  final BiliPalette _palette;
  Color get fill => _palette.choose(CoverPlaceholderTheme.fill, _palette.raised);
  Color get ink => _palette.choose(CoverPlaceholderTheme.ink, _palette.disabled);
}

@immutable
class TabIconThemeColors {
  const TabIconThemeColors(this._palette);

  final BiliPalette _palette;
  Color get ink => _palette.choose(TabIconTheme.ink, _palette.icon);
  Color get selectedInk => _palette.choose(TabIconTheme.selectedInk, _palette.accent);
}

@immutable
class SearchThemeColors {
  const SearchThemeColors(this._palette);

  final BiliPalette _palette;
  Color get page => _palette.choose(SearchTheme.page, _palette.surface);
  Color get text => _palette.choose(SearchTheme.text, _palette.text);
  Color get grey => _palette.choose(SearchTheme.grey, _palette.secondary);
  Color get highlight => _palette.choose(SearchTheme.highlight, _palette.accent);
  Color get fieldRimColor => _palette.choose(SearchTheme.fieldRimColor, _palette.secondary);
  Color get caret => _palette.choose(SearchTheme.caret, _palette.accent);
  Color get clearColor => _palette.choose(SearchTheme.clearColor, _palette.disabled);
  Color get submit => _palette.choose(SearchTheme.submit, _palette.accent);
  Color get rule => _palette.choose(SearchTheme.rule, _palette.disabled);
  Color get chipFill => _palette.choose(SearchTheme.chipFill, _palette.raised);
  Color get cellFill => _palette.choose(SearchTheme.cellFill, _palette.raised);
  Color get suffix => _palette.choose(SearchTheme.suffix, _palette.secondary);
  Color get suggestionHairlineColor => _palette.choose(SearchTheme.suggestionHairlineColor, _palette.disabled);
}

@immutable
class SearchResultThemeColors {
  const SearchResultThemeColors(this._palette);

  final BiliPalette _palette;
  Color get page => _palette.choose(SearchResultTheme.page, _palette.surface);
  Color get hairlineInk => _palette.choose(SearchResultTheme.hairlineInk, _palette.divider);
  Color get rowHairlineInk => _palette.choose(SearchResultTheme.rowHairlineInk, _palette.disabled);
  Color get tabInk => _palette.choose(SearchResultTheme.tabInk, _palette.icon);
  Color get tabSelected => _palette.choose(SearchResultTheme.tabSelected, _palette.accent);
  Color get funnelInk => _palette.choose(SearchResultTheme.funnelInk, _palette.icon);
  Color get funnelOpen => _palette.choose(SearchResultTheme.funnelOpen, _palette.accent);
  Color get sortInk => _palette.choose(SearchResultTheme.sortInk, _palette.icon);
  Color get coverPlaceholder => _palette.choose(SearchResultTheme.coverPlaceholder, _palette.page);
  Color get titleInk => _palette.choose(SearchResultTheme.titleInk, _palette.text);
  Color get highlight => _palette.choose(SearchResultTheme.highlight, _palette.accent);
  Color get metaInk => _palette.choose(SearchResultTheme.metaInk, _palette.secondary);
  Color get nameInk => _palette.choose(SearchResultTheme.nameInk, _palette.text);
  Color get countsInk => _palette.choose(SearchResultTheme.countsInk, _palette.secondary);
  Color get followFill => _palette.choose(SearchResultTheme.followFill, _palette.accent);
  Color get followedFill => _palette.choose(SearchResultTheme.followedFill, _palette.page);
  Color get followedInk => _palette.choose(SearchResultTheme.followedInk, _palette.secondary);
  Color get stateInk => _palette.choose(SearchResultTheme.stateInk, _palette.secondary);
  Color get sheetFill => _palette.choose(SearchResultTheme.sheetFill, _palette.raised);
  Color get grabberInk => _palette.choose(SearchResultTheme.grabberInk, _palette.disabled);
  Color get sheetCardFill => _palette.choose(SearchResultTheme.sheetCardFill, _palette.surface);
  Color get sheetInk => _palette.choose(SearchResultTheme.sheetInk, _palette.text);
}

@immutable
class SearchFilterThemeColors {
  const SearchFilterThemeColors(this._palette);

  final BiliPalette _palette;
  Color get panel => _palette.choose(SearchFilterTheme.panel, _palette.surface);
  Color get title => _palette.choose(SearchFilterTheme.title, _palette.text);
  Color get chip => _palette.choose(SearchFilterTheme.chip, _palette.raised);
  Color get chipLabel => _palette.choose(SearchFilterTheme.chipLabel, _palette.icon);
}

@immutable
class LoadingTvThemeColors {
  const LoadingTvThemeColors(this._palette);

  final BiliPalette _palette;
  Color get stateInk => _palette.choose(LoadingTvTheme.stateInk, _palette.secondary);
}

@immutable
class UploaderSheetThemeColors {
  const UploaderSheetThemeColors(this._palette);

  final BiliPalette _palette;
  Color get fill => _palette.choose(UploaderSheetTheme.fill, _palette.surface);
  Color get grabber => _palette.choose(UploaderSheetTheme.grabber, _palette.disabled);
  Color get nameInk => _palette.choose(UploaderSheetTheme.nameInk, _palette.text);
  Color get countsInk => _palette.choose(UploaderSheetTheme.countsInk, _palette.secondary);
  Color get enterInk => _palette.choose(UploaderSheetTheme.enterInk, _palette.icon);
  Color get chevronInk => _palette.choose(UploaderSheetTheme.chevronInk, _palette.secondary);
  Color get followedFill => _palette.choose(UploaderSheetTheme.followedFill, _palette.page);
  Color get followedInk => _palette.choose(UploaderSheetTheme.followedInk, _palette.secondary);
  Color get titleInk => _palette.choose(UploaderSheetTheme.titleInk, _palette.text);
  Color get playingInk => _palette.choose(UploaderSheetTheme.playingInk, _palette.accent);
  Color get endInk => _palette.choose(UploaderSheetTheme.endInk, _palette.icon);
  Color get stateInk => _palette.choose(UploaderSheetTheme.stateInk, _palette.secondary);
}

@immutable
class SpaceThemeColors {
  const SpaceThemeColors(this._palette);

  final BiliPalette _palette;
  Color get page => _palette.choose(SpaceTheme.page, _palette.surface);
  Color get bannerDefault => _palette.choose(SpaceTheme.bannerDefault, _palette.divider);
  Color get barInk => _palette.choose(SpaceTheme.barInk, _palette.icon);
  Color get bar => _palette.choose(SpaceTheme.bar, _palette.surface);
  Color get pillInk => _palette.choose(SpaceTheme.pillInk, _palette.accent);
  Color get pillFollowedFill => _palette.choose(SpaceTheme.pillFollowedFill, _palette.raised);
  Color get pillFollowedInk => _palette.choose(SpaceTheme.pillFollowedInk, _palette.secondary);
  Color get countInk => _palette.choose(SpaceTheme.countInk, _palette.text);
  Color get labelInk => _palette.choose(SpaceTheme.labelInk, _palette.secondary);
  Color get statsRuleInk => _palette.choose(SpaceTheme.statsRuleInk, _palette.divider);
  Color get followFill => _palette.choose(SpaceTheme.followFill, _palette.accent);
  Color get followedFill => _palette.choose(SpaceTheme.followedFill, _palette.divider);
  Color get followedInk => _palette.choose(SpaceTheme.followedInk, _palette.secondary);
  Color get chargeInk => _palette.choose(SpaceTheme.chargeInk, _palette.accent);
  Color get nameInk => _palette.choose(SpaceTheme.nameInk, _palette.text);
  Color get nameVipInk => _palette.choose(SpaceTheme.nameVipInk, _palette.accent);
  Color get officialFill => _palette.choose(SpaceTheme.officialFill, _palette.page);
  Color get officialInk => _palette.choose(SpaceTheme.officialInk, _palette.icon);
  Color get bioInk => _palette.choose(SpaceTheme.bioInk, _palette.secondary);
  Color get detailInk => _palette.choose(SpaceTheme.detailInk, _palette.link);
  Color get tagInk => _palette.choose(SpaceTheme.tagInk, _palette.icon);
  Color get entryFill => _palette.choose(SpaceTheme.entryFill, _palette.raised);
  Color get entryInk => _palette.choose(SpaceTheme.entryInk, _palette.text);
  Color get entryNoteInk => _palette.choose(SpaceTheme.entryNoteInk, _palette.icon);
  Color get tabsHairlineInk => _palette.choose(SpaceTheme.tabsHairlineInk, _palette.divider);
  Color get tabInk => _palette.choose(SpaceTheme.tabInk, _palette.icon);
  Color get tabSelected => _palette.choose(SpaceTheme.tabSelected, _palette.accent);
  Color get sheetFill => _palette.choose(SpaceTheme.sheetFill, _palette.surface);
  Color get sheetRuleInk => _palette.choose(SpaceTheme.sheetRuleInk, _palette.secondary);
  Color get sheetInk => _palette.choose(SpaceTheme.sheetInk, _palette.text);
  Color get sheetGapFill => _palette.choose(SpaceTheme.sheetGapFill, _palette.divider);
  Color get retryInk => _palette.choose(SpaceTheme.retryInk, _palette.secondary);
  Color get retryAction => _palette.choose(SpaceTheme.retryAction, _palette.link);
}

@immutable
class SpaceVideosThemeColors {
  const SpaceVideosThemeColors(this._palette);

  final BiliPalette _palette;
  Color get chipInk => _palette.choose(SpaceVideosTheme.chipInk, _palette.icon);
  Color get chipChosenInk => _palette.choose(SpaceVideosTheme.chipChosenInk, _palette.accent);
  Color get chipRim => _palette.choose(SpaceVideosTheme.chipRim, _palette.divider);
  Color get playAllGlyphInk => _palette.choose(SpaceVideosTheme.playAllGlyphInk, _palette.accent);
  Color get playAllInk => _palette.choose(SpaceVideosTheme.playAllInk, _palette.text);
  Color get sortGlyphInk => _palette.choose(SpaceVideosTheme.sortGlyphInk, _palette.secondary);
  Color get sortInk => _palette.choose(SpaceVideosTheme.sortInk, _palette.secondary);
  Color get hairlineInk => _palette.choose(SpaceVideosTheme.hairlineInk, _palette.divider);
  Color get coverPlaceholder => _palette.choose(SpaceVideosTheme.coverPlaceholder, _palette.page);
  Color get titleInk => _palette.choose(SpaceVideosTheme.titleInk, _palette.text);
  Color get metaInk => _palette.choose(SpaceVideosTheme.metaInk, _palette.secondary);
  Color get moreInk => _palette.choose(SpaceVideosTheme.moreInk, _palette.secondary);
  Color get badgeFill => _palette.choose(SpaceVideosTheme.badgeFill, _palette.accent);
  Color get endInk => _palette.choose(SpaceVideosTheme.endInk, _palette.icon);
  Color get stateInk => _palette.choose(SpaceVideosTheme.stateInk, _palette.secondary);
  Color get menuFill => _palette.choose(SpaceVideosTheme.menuFill, _palette.surface);
  Color get menuInk => _palette.choose(SpaceVideosTheme.menuInk, _palette.text);
  Color get menuIconInk => _palette.choose(SpaceVideosTheme.menuIconInk, _palette.accent);
}

@immutable
class FeedDislikeThemeColors {
  const FeedDislikeThemeColors(this._palette);

  final BiliPalette _palette;
  Color get sheetFill => _palette.choose(FeedDislikeTheme.sheetFill, _palette.raised);
  Color get grabberInk => _palette.choose(FeedDislikeTheme.grabberInk, _palette.disabled);
  Color get cardFill => _palette.choose(FeedDislikeTheme.cardFill, _palette.surface);
  Color get ink => _palette.choose(FeedDislikeTheme.ink, _palette.text);
  Color get hairlineInk => _palette.choose(FeedDislikeTheme.hairlineInk, _palette.divider);
  Color get tileLabelInk => _palette.choose(FeedDislikeTheme.tileLabelInk, _palette.icon);
}

@immutable
class FavouritesThemeColors {
  const FavouritesThemeColors(this._palette);

  final BiliPalette _palette;
  Color get tabInk => _palette.choose(FavouritesTheme.tabInk, _palette.text);
  Color get tabChosenInk => _palette.choose(FavouritesTheme.tabChosenInk, _palette.accent);
  Color get chipInk => _palette.choose(FavouritesTheme.chipInk, _palette.icon);
  Color get chipChosenInk => _palette.choose(FavouritesTheme.chipChosenInk, _palette.accent);
  Color get headerHairlineInk => _palette.choose(FavouritesTheme.headerHairlineInk, _palette.page);
  Color get toolInk => _palette.choose(FavouritesTheme.toolInk, _palette.icon);
  Color get page => _palette.choose(FavouritesTheme.page, _palette.raised);
  Color get cardFill => _palette.choose(FavouritesTheme.cardFill, _palette.surface);
  Color get cardTitleInk => _palette.choose(FavouritesTheme.cardTitleInk, _palette.text);
  Color get cardCountInk => _palette.choose(FavouritesTheme.cardCountInk, _palette.secondary);
  Color get chevronInk => _palette.choose(FavouritesTheme.chevronInk, _palette.disabled);
  Color get tileEmpty => _palette.choose(FavouritesTheme.tileEmpty, _palette.page);
  Color get tileTitleInk => _palette.choose(FavouritesTheme.tileTitleInk, _palette.text);
  Color get newRimInk => _palette.choose(FavouritesTheme.newRimInk, _palette.divider);
  Color get newInk => _palette.choose(FavouritesTheme.newInk, _palette.secondary);
  Color get folderBarInk => _palette.choose(FavouritesTheme.folderBarInk, _palette.icon);
  Color get folderMetaInk => _palette.choose(FavouritesTheme.folderMetaInk, _palette.secondary);
  Color get folderActionInk => _palette.choose(FavouritesTheme.folderActionInk, _palette.secondary);
  Color get folderActionFaint => _palette.choose(FavouritesTheme.folderActionFaint, _palette.secondary);
  Color get folderActionLabelInk => _palette.choose(FavouritesTheme.folderActionLabelInk, _palette.secondary);
  Color get coverEmpty => _palette.choose(FavouritesTheme.coverEmpty, _palette.page);
  Color get divider => _palette.choose(FavouritesTheme.divider, _palette.divider);
  Color get rowTitleInk => _palette.choose(FavouritesTheme.rowTitleInk, _palette.text);
  Color get metaInk => _palette.choose(FavouritesTheme.metaInk, _palette.secondary);
  Color get endInk => _palette.choose(FavouritesTheme.endInk, _palette.disabled);
  Color get footerInk => _palette.choose(FavouritesTheme.footerInk, _palette.disabled);
  Color get stateInk => _palette.choose(FavouritesTheme.stateInk, _palette.secondary);
  Color get sheetFill => _palette.choose(FavouritesTheme.sheetFill, _palette.surface);
  Color get sheetRemoveInk => _palette.choose(FavouritesTheme.sheetRemoveInk, _palette.icon);
  Color get sheetBandFill => _palette.choose(FavouritesTheme.sheetBandFill, _palette.raised);
  Color get sheetCancelInk => _palette.choose(FavouritesTheme.sheetCancelInk, _palette.icon);
  Color get playFill => _palette.choose(FavouritesTheme.playFill, _palette.raised);
  Color get playInk => _palette.choose(FavouritesTheme.playInk, _palette.icon);
  Color get playInkOff => _palette.choose(FavouritesTheme.playInkOff, _palette.secondary);
  Color get playGlyphOff => _palette.choose(FavouritesTheme.playGlyphOff, _palette.disabled);
  Color get newDoneOffInk => _palette.choose(FavouritesTheme.newDoneOffInk, _palette.icon);
  Color get newDoneInk => _palette.choose(FavouritesTheme.newDoneInk, _palette.accent);
  Color get newPage => _palette.choose(FavouritesTheme.newPage, _palette.page);
  Color get newGroupFill => _palette.choose(FavouritesTheme.newGroupFill, _palette.surface);
  Color get formInk => _palette.choose(FavouritesTheme.formInk, _palette.text);
  Color get newHintInk => _palette.choose(FavouritesTheme.newHintInk, _palette.secondary);
  Color get newChevronInk => _palette.choose(FavouritesTheme.newChevronInk, _palette.secondary);
  Color get coverSheetFill => _palette.choose(FavouritesTheme.coverSheetFill, _palette.raised);
  Color get coverSheetCancelFill => _palette.choose(FavouritesTheme.coverSheetCancelFill, _palette.surface);
  Color get coverSheetHairlineInk => _palette.choose(FavouritesTheme.coverSheetHairlineInk, _palette.secondary);
}

@immutable
class WatchLaterThemeColors {
  const WatchLaterThemeColors(this._palette);

  final BiliPalette _palette;
  Color get ink => _palette.choose(WatchLaterTheme.ink, _palette.text);
  Color get grey => _palette.choose(WatchLaterTheme.grey, _palette.icon);
  Color get greyOff => _palette.choose(WatchLaterTheme.greyOff, _palette.disabled);
  Color get hairlineInk => _palette.choose(WatchLaterTheme.hairlineInk, _palette.divider);
  Color get coverPlaceholder => _palette.choose(WatchLaterTheme.coverPlaceholder, _palette.page);
  Color get metaInk => _palette.choose(WatchLaterTheme.metaInk, _palette.secondary);
  Color get moreInk => _palette.choose(WatchLaterTheme.moreInk, _palette.disabled);
  Color get circleInk => _palette.choose(WatchLaterTheme.circleInk, _palette.disabled);
  Color get circleChosen => _palette.choose(WatchLaterTheme.circleChosen, _palette.accent);
  Color get noteInk => _palette.choose(WatchLaterTheme.noteInk, _palette.disabled);
  Color get emptyInk => _palette.choose(WatchLaterTheme.emptyInk, _palette.secondary);
  Color get artBody => _palette.choose(WatchLaterTheme.artBody, _palette.divider);
  Color get stateInk => _palette.choose(WatchLaterTheme.stateInk, _palette.secondary);
  Color get sheetFill => _palette.choose(WatchLaterTheme.sheetFill, _palette.raised);
  Color get grabberInk => _palette.choose(WatchLaterTheme.grabberInk, _palette.disabled);
  Color get groupFill => _palette.choose(WatchLaterTheme.groupFill, _palette.surface);
  Color get actionHairlineInk => _palette.choose(WatchLaterTheme.actionHairlineInk, _palette.page);
  Color get folderSheetFill => _palette.choose(WatchLaterTheme.folderSheetFill, _palette.surface);
  Color get folderGrabberInk => _palette.choose(WatchLaterTheme.folderGrabberInk, _palette.disabled);
  Color get editActionOff => _palette.choose(WatchLaterTheme.editActionOff, _palette.disabled);
}

@immutable
class AppAuthThemeColors {
  const AppAuthThemeColors(this._palette);

  final BiliPalette _palette;
  Color get status => _palette.choose(AppAuthTheme.status, _palette.secondary);
}

@immutable
class OwnSpaceThemeColors {
  const OwnSpaceThemeColors(this._palette);

  final BiliPalette _palette;
  Color get editInk => _palette.choose(OwnSpaceTheme.editInk, _palette.accent);
  Color get editFill => _palette.choose(OwnSpaceTheme.editFill, _palette.surface);
  Color get pillRim => _palette.choose(OwnSpaceTheme.pillRim, _palette.disabled);
  Color get pillInk => _palette.choose(OwnSpaceTheme.pillInk, _palette.secondary);
  Color get expInk => _palette.choose(OwnSpaceTheme.expInk, _palette.secondary);
  Color get expTrack => _palette.choose(OwnSpaceTheme.expTrack, _palette.divider);
  Color get bar => _palette.choose(OwnSpaceTheme.bar, _palette.surface);
  Color get barInk => _palette.choose(OwnSpaceTheme.barInk, _palette.icon);
}

@immutable
class OwnSpaceTabsThemeColors {
  const OwnSpaceTabsThemeColors(this._palette);

  final BiliPalette _palette;
  Color get greyPage => _palette.choose(OwnSpaceTabsTheme.greyPage, _palette.raised);
  Color get whitePage => _palette.choose(OwnSpaceTabsTheme.whitePage, _palette.surface);
  Color get titleInk => _palette.choose(OwnSpaceTabsTheme.titleInk, _palette.text);
  Color get countInk => _palette.choose(OwnSpaceTabsTheme.countInk, _palette.secondary);
  Color get eyeInk => _palette.choose(OwnSpaceTabsTheme.eyeInk, _palette.secondary);
  Color get moreInk => _palette.choose(OwnSpaceTabsTheme.moreInk, _palette.secondary);
  Color get cardFill => _palette.choose(OwnSpaceTabsTheme.cardFill, _palette.surface);
  Color get coverEmpty => _palette.choose(OwnSpaceTabsTheme.coverEmpty, _palette.page);
  Color get cardTitleInk => _palette.choose(OwnSpaceTabsTheme.cardTitleInk, _palette.text);
  Color get folderCountInk => _palette.choose(OwnSpaceTabsTheme.folderCountInk, _palette.secondary);
  Color get tvInk => _palette.choose(OwnSpaceTabsTheme.tvInk, _palette.divider);
  Color get posterEmpty => _palette.choose(OwnSpaceTabsTheme.posterEmpty, _palette.page);
  Color get folderChevronInk => _palette.choose(OwnSpaceTabsTheme.folderChevronInk, _palette.secondary);
  Color get folderBandInk => _palette.choose(OwnSpaceTabsTheme.folderBandInk, _palette.raised);
  Color get rowTvInk => _palette.choose(OwnSpaceTabsTheme.rowTvInk, _palette.disabled);
  Color get endInk => _palette.choose(OwnSpaceTabsTheme.endInk, _palette.secondary);
  Color get emptyDiscFill => _palette.choose(OwnSpaceTabsTheme.emptyDiscFill, _palette.raised);
  Color get uploadInk => _palette.choose(OwnSpaceTabsTheme.uploadInk, _palette.icon);
  Color get emptyInk => _palette.choose(OwnSpaceTabsTheme.emptyInk, _palette.secondary);
  Color get uploadPillInk => _palette.choose(OwnSpaceTabsTheme.uploadPillInk, _palette.accent);
  Color get rewardInk => _palette.choose(OwnSpaceTabsTheme.rewardInk, _palette.link);
  Color get footerInk => _palette.choose(OwnSpaceTabsTheme.footerInk, _palette.disabled);
  Color get footerRetryInk => _palette.choose(OwnSpaceTabsTheme.footerRetryInk, _palette.link);
}

@immutable
class HomeHeaderThemeColors {
  const HomeHeaderThemeColors(this._palette);

  final BiliPalette _palette;
  Color get searchInk => _palette.choose(HomeHeaderTheme.searchInk, _palette.icon);
}

@immutable
class FeedBatchThemeColors {
  const FeedBatchThemeColors(this._palette);

  final BiliPalette _palette;
  Color get ink => _palette.choose(FeedBatchTheme.ink, _palette.accent);
}

@immutable
class FeedBigCardThemeColors {
  const FeedBigCardThemeColors(this._palette);

  final BiliPalette _palette;
  Color get title => _palette.choose(FeedBigCardTheme.title, _palette.text);
  Color get like => _palette.choose(FeedBigCardTheme.like, _palette.icon);
  Color get liked => _palette.choose(FeedBigCardTheme.liked, _palette.accent);
  Color get count => _palette.choose(FeedBigCardTheme.count, _palette.secondary);
  Color get progressInk => _palette.choose(FeedBigCardTheme.progressInk, _palette.accent);
}

@immutable
class DynamicCardThemeColors {
  const DynamicCardThemeColors(this._palette);

  final BiliPalette _palette;
  Color get fill => _palette.choose(DynamicCardTheme.fill, _palette.surface);
  Color get bandInk => _palette.choose(DynamicCardTheme.bandInk, _palette.page);
  Color get spaceBandInk => _palette.choose(DynamicCardTheme.spaceBandInk, _palette.raised);
  Color get nameInk => _palette.choose(DynamicCardTheme.nameInk, _palette.text);
  Color get nameVipInk => _palette.choose(DynamicCardTheme.nameVipInk, _palette.accent);
  Color get timeInk => _palette.choose(DynamicCardTheme.timeInk, _palette.secondary);
  Color get moreInk => _palette.choose(DynamicCardTheme.moreInk, _palette.secondary);
  Color get textInk => _palette.choose(DynamicCardTheme.textInk, _palette.text);
  Color get linkInk => _palette.choose(DynamicCardTheme.linkInk, _palette.link);
  Color get pictureFill => _palette.choose(DynamicCardTheme.pictureFill, _palette.page);
  Color get progressInk => _palette.choose(DynamicCardTheme.progressInk, _palette.accent);
  Color get titleInk => _palette.choose(DynamicCardTheme.titleInk, _palette.text);
  Color get repostFill => _palette.choose(DynamicCardTheme.repostFill, _palette.page);
  Color get repostTextInk => _palette.choose(DynamicCardTheme.repostTextInk, _palette.icon);
  Color get repostFollowInk => _palette.choose(DynamicCardTheme.repostFollowInk, _palette.accent);
  Color get goodsHeadInk => _palette.choose(DynamicCardTheme.goodsHeadInk, _palette.secondary);
  Color get goodsFill => _palette.choose(DynamicCardTheme.goodsFill, _palette.raised);
  Color get goodsNameInk => _palette.choose(DynamicCardTheme.goodsNameInk, _palette.text);
  Color get goodsBriefInk => _palette.choose(DynamicCardTheme.goodsBriefInk, _palette.secondary);
  Color get goodsButtonFill => _palette.choose(DynamicCardTheme.goodsButtonFill, _palette.accent);
  Color get footerInk => _palette.choose(DynamicCardTheme.footerInk, _palette.icon);
  Color get footerLiked => _palette.choose(DynamicCardTheme.footerLiked, _palette.accent);
  Color get sheetFill => _palette.choose(DynamicCardTheme.sheetFill, _palette.raised);
  Color get sheetHairlineInk => _palette.choose(DynamicCardTheme.sheetHairlineInk, _palette.divider);
  Color get sheetIconInk => _palette.choose(DynamicCardTheme.sheetIconInk, _palette.accent);
  Color get sheetInk => _palette.choose(DynamicCardTheme.sheetInk, _palette.text);
  Color get sheetGapFill => _palette.choose(DynamicCardTheme.sheetGapFill, _palette.page);
  Color get sheetCancelInk => _palette.choose(DynamicCardTheme.sheetCancelInk, _palette.icon);
}

@immutable
class DynamicFeedThemeColors {
  const DynamicFeedThemeColors(this._palette);

  final BiliPalette _palette;
  Color get bar => _palette.choose(DynamicFeedTheme.bar, _palette.surface);
  Color get titleInk => _palette.choose(DynamicFeedTheme.titleInk, _palette.text);
  Color get switchFill => _palette.choose(DynamicFeedTheme.switchFill, _palette.raised);
  Color get switchOn => _palette.choose(DynamicFeedTheme.switchOn, _palette.accent);
  Color get switchOff => _palette.choose(DynamicFeedTheme.switchOff, _palette.icon);
  Color get sectionInk => _palette.choose(DynamicFeedTheme.sectionInk, _palette.text);
  Color get moreInk => _palette.choose(DynamicFeedTheme.moreInk, _palette.secondary);
  Color get allInk => _palette.choose(DynamicFeedTheme.allInk, _palette.icon);
  Color get chevronInk => _palette.choose(DynamicFeedTheme.chevronInk, _palette.secondary);
  Color get faceRingInk => _palette.choose(DynamicFeedTheme.faceRingInk, _palette.page);
  Color get nameInk => _palette.choose(DynamicFeedTheme.nameInk, _palette.icon);
  Color get dotInk => _palette.choose(DynamicFeedTheme.dotInk, _palette.accent);
  Color get bandFill => _palette.choose(DynamicFeedTheme.bandFill, _palette.page);
  Color get posterTitleInk => _palette.choose(DynamicFeedTheme.posterTitleInk, _palette.text);
  Color get stateInk => _palette.choose(DynamicFeedTheme.stateInk, _palette.secondary);
  Color get footerInk => _palette.choose(DynamicFeedTheme.footerInk, _palette.disabled);
  Color get sheetFrost => _palette.choose(DynamicFeedTheme.sheetFrost, _palette.divider);
  Color get sheetFill => _palette.choose(DynamicFeedTheme.sheetFill, _palette.surface);
  Color get sheetTitleInk => _palette.choose(DynamicFeedTheme.sheetTitleInk, _palette.text);
  Color get closeInk => _palette.choose(DynamicFeedTheme.closeInk, _palette.icon);
  Color get sheetRuleInk => _palette.choose(DynamicFeedTheme.sheetRuleInk, _palette.divider);
}

@immutable
class DynamicPostThemeColors {
  const DynamicPostThemeColors(this._palette);

  final BiliPalette _palette;
  Color get page => _palette.choose(DynamicPostTheme.page, _palette.surface);
  Color get barInk => _palette.choose(DynamicPostTheme.barInk, _palette.icon);
  Color get barRule => _palette.choose(DynamicPostTheme.barRule, _palette.divider);
  Color get titleInk => _palette.choose(DynamicPostTheme.titleInk, _palette.text);
  Color get name => _palette.choose(DynamicPostTheme.name, _palette.text);
  Color get meta => _palette.choose(DynamicPostTheme.meta, _palette.secondary);
  Color get textInk => _palette.choose(DynamicPostTheme.textInk, _palette.text);
  Color get tabChosen => _palette.choose(DynamicPostTheme.tabChosen, _palette.accent);
  Color get tabInk => _palette.choose(DynamicPostTheme.tabInk, _palette.secondary);
  Color get tabRule => _palette.choose(DynamicPostTheme.tabRule, _palette.divider);
  Color get bottomRule => _palette.choose(DynamicPostTheme.bottomRule, _palette.divider);
  Color get bottomRuleSoft => _palette.choose(DynamicPostTheme.bottomRuleSoft, _palette.page);
  Color get pillFill => _palette.choose(DynamicPostTheme.pillFill, _palette.page);
  Color get pillInk => _palette.choose(DynamicPostTheme.pillInk, _palette.secondary);
  Color get actionInk => _palette.choose(DynamicPostTheme.actionInk, _palette.icon);
  Color get actionCountInk => _palette.choose(DynamicPostTheme.actionCountInk, _palette.secondary);
  Color get actionLiked => _palette.choose(DynamicPostTheme.actionLiked, _palette.accent);
  Color get stateInk => _palette.choose(DynamicPostTheme.stateInk, _palette.secondary);
  Color get retryInk => _palette.choose(DynamicPostTheme.retryInk, _palette.accent);
}

@immutable
class FollowingListThemeColors {
  const FollowingListThemeColors(this._palette);

  final BiliPalette _palette;
  Color get bar => _palette.choose(FollowingListTheme.bar, _palette.surface);
  Color get barInk => _palette.choose(FollowingListTheme.barInk, _palette.text);
  Color get hairline => _palette.choose(FollowingListTheme.hairline, _palette.divider);
  Color get backInk => _palette.choose(FollowingListTheme.backInk, _palette.text);
  Color get field => _palette.choose(FollowingListTheme.field, _palette.page);
  Color get fieldInk => _palette.choose(FollowingListTheme.fieldInk, _palette.text);
  Color get placeholder => _palette.choose(FollowingListTheme.placeholder, _palette.secondary);
  Color get caret => _palette.choose(FollowingListTheme.caret, _palette.accent);
  Color get magnifierInk => _palette.choose(FollowingListTheme.magnifierInk, _palette.secondary);
  Color get clearColor => _palette.choose(FollowingListTheme.clearColor, _palette.disabled);
  Color get sortLabel => _palette.choose(FollowingListTheme.sortLabel, _palette.secondary);
  Color get sortValue => _palette.choose(FollowingListTheme.sortValue, _palette.icon);
  Color get sortChevron => _palette.choose(FollowingListTheme.sortChevron, _palette.icon);
  Color get menuInk => _palette.choose(FollowingListTheme.menuInk, _palette.icon);
  Color get menuChosen => _palette.choose(FollowingListTheme.menuChosen, _palette.accent);
  Color get menuFill => _palette.choose(FollowingListTheme.menuFill, _palette.surface);
  Color get name => _palette.choose(FollowingListTheme.name, _palette.text);
  Color get vipName => _palette.choose(FollowingListTheme.vipName, _palette.accent);
  Color get dotInk => _palette.choose(FollowingListTheme.dotInk, _palette.accent);
  Color get page => _palette.choose(FollowingListTheme.page, _palette.surface);
  Color get stateInk => _palette.choose(FollowingListTheme.stateInk, _palette.secondary);
  Color get footerInk => _palette.choose(FollowingListTheme.footerInk, _palette.secondary);
}

@immutable
class PadHomeThemeColors {
  const PadHomeThemeColors(this._palette);

  final BiliPalette _palette;
  Color get page => _palette.choose(PadHomeTheme.page, _palette.surface);
  Color get fieldFill => _palette.choose(PadHomeTheme.fieldFill, _palette.page);
  Color get fieldGlyphInk => _palette.choose(PadHomeTheme.fieldGlyphInk, _palette.secondary);
  Color get fieldInk => _palette.choose(PadHomeTheme.fieldInk, _palette.secondary);
  Color get tabInk => _palette.choose(PadHomeTheme.tabInk, _palette.secondary);
  Color get iconInk => _palette.choose(PadHomeTheme.iconInk, _palette.icon);
  Color get barIconInk => _palette.choose(PadHomeTheme.barIconInk, _palette.icon);
  Color get barLabelInk => _palette.choose(PadHomeTheme.barLabelInk, _palette.secondary);
  Color get subInk => _palette.choose(PadHomeTheme.subInk, _palette.secondary);
  Color get moreInk => _palette.choose(PadHomeTheme.moreInk, _palette.icon);
}

@immutable
class PadPageThemeColors {
  const PadPageThemeColors(this._palette);

  final BiliPalette _palette;
  Color get ruleColour => _palette.choose(PadPageTheme.ruleColour, _palette.divider);
  Color get barFill => _palette.choose(PadPageTheme.barFill, _palette.accent);
  Color get tabInk => _palette.choose(PadPageTheme.tabInk, _palette.icon);
  Color get headerTitle => _palette.choose(PadPageTheme.headerTitle, _palette.text);
  Color get headerFieldFill => _palette.choose(PadPageTheme.headerFieldFill, _palette.raised);
  Color get headerFieldInk => _palette.choose(PadPageTheme.headerFieldInk, _palette.secondary);
  Color get headerInk => _palette.choose(PadPageTheme.headerInk, _palette.icon);
  Color get commentRule => _palette.choose(PadPageTheme.commentRule, _palette.disabled);
  Color get commentFieldFill => _palette.choose(PadPageTheme.commentFieldFill, _palette.raised);
  Color get commentInk => _palette.choose(PadPageTheme.commentInk, _palette.secondary);
}

@immutable
class PadBodyThemeColors {
  const PadBodyThemeColors(this._palette);

  final BiliPalette _palette;
  Color get titleInk => _palette.choose(PadBodyTheme.titleInk, _palette.icon);
  Color get tagInk => _palette.choose(PadBodyTheme.tagInk, _palette.icon);
  Color get actionCount => _palette.choose(PadBodyTheme.actionCount, _palette.icon);
}

@immutable
class DownloadSheetThemeColors {
  const DownloadSheetThemeColors(this._palette);

  final BiliPalette _palette;
  Color get sheet => _palette.choose(DownloadSheetTheme.sheet, _palette.raised);
  Color get card => _palette.choose(DownloadSheetTheme.card, _palette.surface);
  Color get hairline => _palette.choose(DownloadSheetTheme.hairline, _palette.divider);
  Color get grey => _palette.choose(DownloadSheetTheme.grey, _palette.icon);
  Color get ink => _palette.choose(DownloadSheetTheme.ink, _palette.text);
  Color get trackOff => _palette.choose(DownloadSheetTheme.trackOff, _palette.raised);
  Color get playing => _palette.choose(DownloadSheetTheme.playing, _palette.accent);
  Color get markTrack => _palette.choose(DownloadSheetTheme.markTrack, _palette.divider);
}

@immutable
class OfflineListThemeColors {
  const OfflineListThemeColors(this._palette);

  final BiliPalette _palette;
  Color get page => _palette.choose(OfflineListTheme.page, _palette.surface);
  Color get ink => _palette.choose(OfflineListTheme.ink, _palette.text);
  Color get grey => _palette.choose(OfflineListTheme.grey, _palette.icon);
  Color get meta => _palette.choose(OfflineListTheme.meta, _palette.secondary);
  Color get bar => _palette.choose(OfflineListTheme.bar, _palette.surface);
  Color get barInk => _palette.choose(OfflineListTheme.barInk, _palette.text);
  Color get field => _palette.choose(OfflineListTheme.field, _palette.page);
  Color get fieldInk => _palette.choose(OfflineListTheme.fieldInk, _palette.text);
  Color get fieldHint => _palette.choose(OfflineListTheme.fieldHint, _palette.disabled);
  Color get caret => _palette.choose(OfflineListTheme.caret, _palette.accent);
  Color get clearInk => _palette.choose(OfflineListTheme.clearInk, _palette.disabled);
  Color get coverPlaceholder => _palette.choose(OfflineListTheme.coverPlaceholder, _palette.page);
  Color get progressTrack => _palette.choose(OfflineListTheme.progressTrack, _palette.divider);
  Color get progressActive => _palette.choose(OfflineListTheme.progressActive, _palette.accent);
  Color get progressIdle => _palette.choose(OfflineListTheme.progressIdle, _palette.secondary);
  Color get vip => _palette.choose(OfflineListTheme.vip, _palette.accent);
  Color get divider => _palette.choose(OfflineListTheme.divider, _palette.divider);
  Color get watched => _palette.choose(OfflineListTheme.watched, _palette.accent);
  Color get stackCard => _palette.choose(OfflineListTheme.stackCard, _palette.disabled);
  Color get allFill => _palette.choose(OfflineListTheme.allFill, _palette.raised);
  Color get allGlyph => _palette.choose(OfflineListTheme.allGlyph, _palette.icon);
  Color get countInk => _palette.choose(OfflineListTheme.countInk, _palette.secondary);
  Color get circleRing => _palette.choose(OfflineListTheme.circleRing, _palette.icon);
  Color get circleChosen => _palette.choose(OfflineListTheme.circleChosen, _palette.accent);
  Color get selectAllInk => _palette.choose(OfflineListTheme.selectAllInk, _palette.icon);
  Color get deleteInk => _palette.choose(OfflineListTheme.deleteInk, _palette.icon);
  Color get confirmRuleInk => _palette.choose(OfflineListTheme.confirmRuleInk, _palette.divider);
  Color get confirmCancel => _palette.choose(OfflineListTheme.confirmCancel, _palette.text);
  Color get confirmAction => _palette.choose(OfflineListTheme.confirmAction, _palette.accent);
  Color get confirmPressed => _palette.choose(OfflineListTheme.confirmPressed, _palette.pressed);
  Color get sheet => _palette.choose(OfflineListTheme.sheet, _palette.raised);
  Color get handle => _palette.choose(OfflineListTheme.handle, _palette.disabled);
  Color get optionInk => _palette.choose(OfflineListTheme.optionInk, _palette.text);
  Color get optionChosen => _palette.choose(OfflineListTheme.optionChosen, _palette.accent);
  Color get optionRuleInk => _palette.choose(OfflineListTheme.optionRuleInk, _palette.divider);
  Color get badgeFill => _palette.choose(OfflineListTheme.badgeFill, _palette.accent);
}

@immutable
class OfflinePageThemeColors {
  const OfflinePageThemeColors(this._palette);

  final BiliPalette _palette;
  Color get titleInk => _palette.choose(OfflinePageTheme.titleInk, _palette.text);
  Color get countInk => _palette.choose(OfflinePageTheme.countInk, _palette.secondary);
  Color get divider => _palette.choose(OfflinePageTheme.divider, _palette.divider);
  Color get rowTitle => _palette.choose(OfflinePageTheme.rowTitle, _palette.text);
  Color get playing => _palette.choose(OfflinePageTheme.playing, _palette.accent);
  Color get meta => _palette.choose(OfflinePageTheme.meta, _palette.secondary);
  Color get vip => _palette.choose(OfflinePageTheme.vip, _palette.accent);
  Color get footerInk => _palette.choose(OfflinePageTheme.footerInk, _palette.disabled);
  Color get sheetFill => _palette.choose(OfflinePageTheme.sheetFill, _palette.surface);
  Color get sheetBand => _palette.choose(OfflinePageTheme.sheetBand, _palette.page);
  Color get sheetIconInk => _palette.choose(OfflinePageTheme.sheetIconInk, _palette.accent);
  Color get sheetInk => _palette.choose(OfflinePageTheme.sheetInk, _palette.text);
}
