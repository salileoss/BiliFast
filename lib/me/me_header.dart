import 'package:bili_core/logic.dart' show CountFormat;
import 'package:flutter/cupertino.dart' show CupertinoButton;
import 'package:flutter/material.dart';

import '../comments/comment_badges.dart' show DecorImage;
import '../shared/menu.dart' show PressHighlight;
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import 'me_glyphs.dart';
import 'me_model.dart';

/// How a [MeTap] answers a finger: glyphs and short labels fade as iOS buttons do, rows and the 会员 card darken.
enum MeTapFeedback { fade, highlight }

/// A control with its own accessibility press, so VoiceOver and ghosthand reach it.
class MeTap extends StatelessWidget {
  const MeTap({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.feedback = MeTapFeedback.fade,
    this.toggled,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final MeTapFeedback feedback;
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final outer = DefaultTextStyle.of(context);
    return Semantics(
      container: true,
      button: true,
      label: label,
      toggled: toggled,
      excludeSemantics: true,
      onTap: onTap,
      child: switch (feedback) {
        MeTapFeedback.highlight => PressHighlight(onTap: onTap, child: child),
        // CupertinoButton's own text style brings -0.41 pt tracking and drops the page's fallback to PingFang.
        MeTapFeedback.fade => CupertinoButton(
          onPressed: onTap,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          child: DefaultTextStyle(
            style: outer.style,
            textAlign: outer.textAlign,
            softWrap: outer.softWrap,
            overflow: outer.overflow,
            maxLines: outer.maxLines,
            textWidthBasis: outer.textWidthBasis,
            textHeightBehavior: outer.textHeightBehavior,
            child: child,
          ),
        ),
      },
    );
  }
}

/// What the header's controls do; the page fills them in.
class MeActions {
  const MeActions({required this.openSpace, required this.login, required this.soon, required this.openVipCentre});

  final VoidCallback openSpace;
  final VoidCallback login;

  /// The toast for everything not built yet.
  final VoidCallback soon;
  final VoidCallback openVipCentre;
}

/// 我的's fixed part under the top row (87): the avatar, the name and what follows it, 空间 ›, the counts and, for a
/// 大会员, the 会员 card. Laid out from the safe area's top, as [MeTheme] measures it.
class MeHeader extends StatelessWidget {
  const MeHeader({
    super.key,
    required this.view,
    required this.actions,
    this.reserveCard = false,
    this.animate = false,
    this.ink,
  });

  final MeView view;
  final MeActions actions;

  /// The text and icons over a 装扮's picture (109), the counts' rules left out; null for 87's colours.
  final Color? ink;

  /// Keeps the card's room, the card unseen, while a 大会员's profile is still to come, so the list doesn't jump.
  final bool reserveCard;

  /// Whether the card fades in and out as it comes and goes, rather than at once.
  final bool animate;

  /// How far below the safe area's top the header ends: at the card's bottom, or where the card would start.
  static double extent(MeView view, {bool reserveCard = false}) =>
      hasCard(view) || reserveCard ? MeTheme.cardTop + MeTheme.cardHeight : MeTheme.cardTop;

  static bool hasCard(MeView view) => view is MeShown && view.profile.vip;

  /// B币 and 硬币 as the official app writes them: 2.3, 878, 878.5.
  static String amount(double value) {
    if (value == value.roundToDouble()) return '${value.round()}';
    var text = value.toStringAsFixed(2);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
  }

  @override
  Widget build(BuildContext context) {
    final view = this.view;
    final profile = view is MeShown ? view.profile : null;
    final textLeft = MeTheme.textLeft + (profile?.pendant != null ? MeTheme.pendantTextShift : 0);
    final counts = view is MeShown ? view.counts : null;
    final card = hasCard(view);
    final ink = this.ink;
    return SizedBox(
      height: extent(view, reserveCard: reserveCard),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: MeTheme.avatarLeft,
            top: MeTheme.avatarTop,
            width: MeTheme.avatar,
            height: MeTheme.avatar,
            child: MeTap(
              key: const ValueKey('me-avatar'),
              label: view is MeLoggedOut ? '点击登录' : '头像',
              onTap: switch (view) {
                MeShown() => actions.openSpace,
                MeLoggedOut() => actions.login,
                _ => null,
              },
              child: _Avatar(profile: profile),
            ),
          ),
          if (view is MeLoggedOut)
            Positioned(
              left: textLeft,
              top: MeTheme.avatarTop,
              height: MeTheme.avatar,
              child: MeTap(
                key: const ValueKey('me-login'),
                label: '点击登录',
                onTap: actions.login,
                child: Center(
                  child: Text(
                    '点击登录',
                    style: TextStyle(
                      fontFamily: BiliFonts.family,
                      fontSize: MeTheme.loggedOutText,
                      color: ink ?? MeTheme.colorsOf(context).name,
                    ),
                  ),
                ),
              ),
            ),
          if (profile != null) ...[
            _CentredRow(
              left: textLeft,
              centre: MeTheme.nameCentre,
              child: _NameRow(profile: profile, onEdit: actions.soon, ink: ink),
            ),
            if (profile.vipLabel.isNotEmpty)
              Positioned(
                left: textLeft,
                top: MeTheme.vipLabelTop,
                height: MeTheme.vipLabelHeight,
                child: _VipLabel(profile.vipLabel),
              ),
            _CentredRow(
              left: textLeft,
              centre: MeTheme.coinsCentre,
              child: _Coins(profile: profile, ink: ink),
            ),
            Positioned(
              right: 0,
              top: MeTheme.spaceCentre - MeTheme.countTap / 2,
              height: MeTheme.countTap,
              child: MeTap(
                key: const ValueKey('me-space'),
                label: '空间',
                onTap: actions.openSpace,
                child: Padding(
                  padding: const EdgeInsets.only(left: BiliMetrics.gutter, right: MeTheme.spaceRight),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '空间',
                        style: TextStyle(
                          fontFamily: BiliFonts.family,
                          fontSize: MeTheme.spaceText,
                          color: ink ?? MeTheme.colorsOf(context).space,
                        ),
                      ),
                      const SizedBox(width: MeTheme.spaceChevronGap),
                      CustomPaint(
                        size: const Size(MeTheme.chevronWidth, MeTheme.chevronHeight),
                        painter: MeChevronPainter(color: ink ?? MeTheme.colorsOf(context).space, stroke: MeTheme.chevronStroke),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          Positioned(
            left: 0,
            right: 0,
            top: MeTheme.countRuleTop - (MeTheme.countTap - MeTheme.countRuleHeight) / 2,
            height: MeTheme.countTap,
            child: _Counts(counts: counts, onTap: actions.soon, ink: ink),
          ),
          if (card || reserveCard)
            Positioned(
              left: MeTheme.cardInset,
              right: MeTheme.cardInset,
              top: MeTheme.cardTop,
              height: MeTheme.cardHeight,
              child: _CardFade(
                visible: card,
                animate: animate,
                child: _VipCard(onOpen: actions.openVipCentre),
              ),
            ),
        ],
      ),
    );
  }
}

/// A row whose middle sits [centre] below the header's top.
class _CentredRow extends StatelessWidget {
  const _CentredRow({required this.left, required this.centre, required this.child});

  final double left;
  final double centre;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    left: left,
    top: centre - MeTheme.lineBox / 2,
    height: MeTheme.lineBox,
    child: Align(alignment: Alignment.centerLeft, widthFactor: 1, child: child),
  );
}

/// The face, its frame when it wears one and the 大 on its corner; Bilibili's grey head until a profile shows.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final MeProfile? profile;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    final pendant = profile?.pendant;
    final face = pendant == null ? MeTheme.avatar : MeTheme.pendantFace;
    const frame = MeTheme.pendantFace * MeTheme.pendantScale;
    final inset = pendant == null ? 0.0 : MeTheme.vipPendantInset;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        SizedBox.square(
          dimension: face,
          child: ClipOval(
            child: profile == null
                ? ColoredBox(
                    key: const ValueKey('me-avatar-blank'),
                    color: BiliColors.colorsOf(context).pageGrey,
                    child: Icon(Icons.person, size: face * MeTheme.blankHead, color: BiliColors.colorsOf(context).divider),
                  )
                : RemoteImage.avatar(profile.face),
          ),
        ),
        if (pendant != null)
          OverflowBox(
            maxWidth: frame,
            maxHeight: frame,
            child: IgnorePointer(
              child: SizedBox.square(key: const ValueKey('me-pendant'), dimension: frame, child: DecorImage(pendant)),
            ),
          ),
        if (profile != null && profile.vipBadge)
          Positioned(
            right: inset - MeTheme.vipRing,
            bottom: inset - MeTheme.vipRing,
            child: Container(
              key: const ValueKey('me-vip-badge'),
              padding: const EdgeInsets.all(MeTheme.vipRing),
              decoration: const BoxDecoration(color: MeTheme.vipRingInk, shape: BoxShape.circle),
              child: MeVipDisc(),
            ),
          ),
      ],
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.profile, required this.onEdit, required this.ink});

  final MeProfile profile;
  final VoidCallback onEdit;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final ink = this.ink;
    final pencil = CustomPaint(size: Size.square(MeTheme.pencilBox), painter: MePencilPainter(palette: BiliPalette.of(context)));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          profile.name,
          key: const ValueKey('me-name'),
          maxLines: 1,
          style: TextStyle(
            fontFamily: BiliFonts.family,
            fontSize: MeTheme.nameText,
            fontWeight: MeTheme.nameWeight,
            color: ink ?? (profile.vip ? MeTheme.colorsOf(context).vipName : MeTheme.colorsOf(context).name),
          ),
        ),
        MeTap(
          key: const ValueKey('me-edit'),
          label: '编辑资料',
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.only(left: MeTheme.pencilGap - (MeTheme.pencilBox - MeTheme.pencilInk) / 2),
            child: ink == null
                ? pencil
                : ColorFiltered(colorFilter: ColorFilter.mode(ink, BlendMode.srcIn), child: pencil),
          ),
        ),
        const SizedBox(width: MeTheme.levelGap - (MeTheme.pencilBox - MeTheme.pencilInk) / 2),
        MeLevelBadge(level: profile.level),
      ],
    );
  }
}

class _VipLabel extends StatelessWidget {
  const _VipLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('me-vip-label'),
    padding: const EdgeInsets.symmetric(horizontal: MeTheme.vipLabelPad),
    alignment: Alignment.center,
    decoration: ShapeDecoration(color: MeTheme.colorsOf(context).vipLabelFill, shape: StadiumBorder()),
    child: Text(
      label,
      maxLines: 1,
      style: TextStyle(
        fontFamily: BiliFonts.family,
        fontSize: MeTheme.vipLabelText,
        fontWeight: MeTheme.vipLabelWeight,
        height: 1,
        color: MeTheme.vipLabelInk,
      ),
    ),
  );
}

class _Coins extends StatelessWidget {
  const _Coins({required this.profile, required this.ink});

  final MeProfile profile;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontFamily: BiliFonts.family, fontSize: MeTheme.coinsText, color: ink ?? MeTheme.colorsOf(context).coins);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('B币：${MeHeader.amount(profile.bcoin)}', key: const ValueKey('me-bcoin'), style: style),
        const SizedBox(width: MeTheme.coinsGap),
        Text('硬币：${MeHeader.amount(profile.coins)}', key: const ValueKey('me-coins'), style: style),
      ],
    );
  }
}

/// 动态, 关注 and 粉丝, each a third of the width; - until the counts answer.
class _Counts extends StatelessWidget {
  const _Counts({required this.counts, required this.onTap, required this.ink});

  final MeCounts? counts;
  final VoidCallback onTap;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final counts = this.counts;
    final ink = this.ink;
    String value(int Function(MeCounts counts) of) => counts == null ? '-' : CountFormat.short(of(counts));
    final columns = [
      ('me-dynamics', '动态', value((c) => c.dynamics)),
      ('me-following', '关注', value((c) => c.following)),
      ('me-followers', '粉丝', value((c) => c.followers)),
    ];
    const lift = (MeTheme.countTap - MeTheme.countRuleHeight) / 2;
    return Row(
      children: [
        for (final (index, (key, label, number)) in columns.indexed)
          Expanded(
            child: Stack(
              children: [
                if (index > 0 && ink == null)
                  Positioned(
                    left: 0,
                    top: lift,
                    width: MeTheme.countRuleWidth,
                    height: MeTheme.countRuleHeight,
                    child: ColoredBox(color: MeTheme.colorsOf(context).countRule),
                  ),
                Positioned.fill(
                  child: MeTap(
                    key: ValueKey(key),
                    label: '$label $number',
                    onTap: onTap,
                    child: SizedBox.expand(
                      child: Stack(
                        children: [
                          _CountLine(
                            centre: MeTheme.countCentre - MeTheme.countRuleTop + lift,
                            text: number,
                            style: TextStyle(
                              fontFamily: BiliFonts.family,
                              fontSize: MeTheme.countText,
                              fontWeight: MeTheme.countWeight,
                              color: ink ?? MeTheme.colorsOf(context).count,
                            ),
                          ),
                          _CountLine(
                            centre: MeTheme.countLabelCentre - MeTheme.countRuleTop + lift,
                            text: label,
                            style: TextStyle(
                              fontFamily: BiliFonts.family,
                              fontSize: MeTheme.countLabelText,
                              color: ink ?? MeTheme.colorsOf(context).countLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CountLine extends StatelessWidget {
  const _CountLine({required this.centre, required this.text, required this.style});

  final double centre;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: centre - MeTheme.lineBox / 2,
    height: MeTheme.lineBox,
    child: IgnorePointer(
      child: Center(child: Text(text, maxLines: 1, style: style)),
    ),
  );
}

/// The 会员 card's room: the card fades in when a profile shows it and out when one doesn't.
class _CardFade extends StatefulWidget {
  const _CardFade({required this.visible, required this.animate, required this.child});

  final bool visible;
  final bool animate;
  final Widget child;

  @override
  State<_CardFade> createState() => _CardFadeState();
}

class _CardFadeState extends State<_CardFade> with SingleTickerProviderStateMixin {
  late final _opacity = AnimationController(vsync: this, duration: MeTheme.cardFade);
  late final _curved = CurvedAnimation(parent: _opacity, curve: MeTheme.cardFadeCurve);

  @override
  void initState() {
    super.initState();
    if (widget.visible && widget.animate) {
      _opacity.forward();
    } else {
      _opacity.value = widget.visible ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(_CardFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (!widget.animate) {
      _opacity.value = widget.visible ? 1 : 0;
    } else if (widget.visible) {
      _opacity.forward();
    } else {
      _opacity.reverse();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !widget.visible,
    child: ExcludeSemantics(
      excluding: !widget.visible,
      child: FadeTransition(opacity: _curved, child: widget.child),
    ),
  );
}

/// 续订会员 and 更多独家内容 › beside the pink 会员中心; the card and the button both open the 会员 centre. The button
/// lies over the card rather than in it, so each keeps its own accessibility press.
class _VipCard extends StatelessWidget {
  const _VipCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MeTheme.cardRadius),
          child: MeTap(
            key: const ValueKey('me-vip-card'),
            label: '续订会员',
            onTap: onOpen,
            feedback: MeTapFeedback.highlight,
            child: ColoredBox(
              color: MeTheme.colorsOf(context).card,
              child: Stack(
                children: [
                  _CentredRow(
                    left: MeTheme.cardInset,
                    centre: MeTheme.cardLineCentre,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MeVipDisc(),
                        const SizedBox(width: MeTheme.cardTitleGap),
                        Text(
                          '续订会员',
                          style: TextStyle(
                            fontFamily: BiliFonts.family,
                            fontSize: MeTheme.cardTitleText,
                            fontWeight: MeTheme.cardTitleWeight,
                            color: MeTheme.colorsOf(context).cardTitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CentredRow(
                    left: MeTheme.cardInset,
                    centre: MeTheme.cardMoreCentre,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '更多独家内容',
                          style: TextStyle(
                            fontFamily: BiliFonts.family,
                            fontSize: MeTheme.cardMoreText,
                            color: MeTheme.colorsOf(context).cardMore,
                          ),
                        ),
                        const SizedBox(width: MeTheme.cardMoreChevronGap),
                        CustomPaint(
                          size: Size(MeTheme.cardMoreChevronWidth, MeTheme.cardMoreChevronHeight),
                          painter: MeChevronPainter(color: MeTheme.colorsOf(context).cardMore, stroke: MeTheme.cardMoreChevronStroke),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: MeTheme.cardInset,
        top: (MeTheme.cardHeight - MeTheme.cardButtonHeight) / 2,
        width: MeTheme.cardButtonWidth,
        height: MeTheme.cardButtonHeight,
        child: MeTap(
          key: const ValueKey('me-vip-centre'),
          label: '会员中心',
          onTap: onOpen,
          child: DecoratedBox(
            decoration: ShapeDecoration(color: MeTheme.colorsOf(context).cardButtonFill, shape: StadiumBorder()),
            child: Center(
              child: Text(
                '会员中心',
                style: TextStyle(
                  fontFamily: BiliFonts.family,
                  fontSize: MeTheme.cardButtonText,
                  color: MeTheme.cardButtonInk,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
