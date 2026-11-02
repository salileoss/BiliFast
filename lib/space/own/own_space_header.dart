import 'package:bili_core/api.dart' show BiliClient, SpaceBannerLabel, SpaceProfile, SpaceTagLine;
import 'package:bili_core/logic.dart' show CountFormat;
import 'package:flutter/widgets.dart';

import '../../comments/comment_badges.dart' show DecorImage;
import '../../me/me_glyphs.dart' show MeVipDisc;
import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import '../space_header.dart' show spaceEmptyBio, spaceLine, spaceStyle;
import '../space_header_glyphs.dart';
import 'own_space_glyphs.dart';

/// The account's own space above the tab row (108): the tall banner with the 空间头图's label and 👕, the face in its
/// frame, the counts and 编辑资料, the name with the 大会员 label and the 勋章 pills, the level with its exp, the bio
/// and the tag row. [stretch] is how far a pull past the top has stretched the banner.
class OwnSpaceHeader extends StatelessWidget {
  const OwnSpaceHeader({super.key, required this.profile, required this.onSoon, this.stretch = 0});

  final SpaceProfile profile;

  /// What isn't built yet: 编辑资料, the pills, 详情, 👕 and link tags.
  final VoidCallback onSoon;
  final double stretch;

  static double heightOf(SpaceProfile profile) {
    var height =
        OwnSpaceTheme.topBlock +
        SpaceTheme.nameBox +
        OwnSpaceTheme.levelBlock +
        SpaceTheme.bioBox +
        SpaceTheme.bottomGap;
    if (profile.tagLines.isNotEmpty) height += SpaceTheme.tagGap + SpaceTheme.tagBox;
    return height;
  }

  /// How far down the name's line centres, which the bar waits for.
  static const nameCentre = OwnSpaceTheme.topBlock + SpaceTheme.nameBox / 2;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('own-space-header'),
    color: SpaceTheme.colorsOf(context).page,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: OwnSpaceTheme.topBlock + stretch,
          child: _Top(profile: profile, stretch: stretch, onSoon: onSoon),
        ),
        SizedBox(
          height: SpaceTheme.nameBox,
          child: _NameRow(profile: profile, onSoon: onSoon),
        ),
        SizedBox(
          height: OwnSpaceTheme.levelBlock,
          child: _LevelRow(profile: profile),
        ),
        SizedBox(
          height: SpaceTheme.bioBox,
          child: _BioLine(sign: profile.sign, onDetail: onSoon),
        ),
        if (profile.tagLines.isNotEmpty) ...[
          const SizedBox(height: SpaceTheme.tagGap),
          SizedBox(
            height: SpaceTheme.tagBox,
            child: _TagRow(tags: profile.tagLines, onLink: onSoon),
          ),
        ],
        const SizedBox(height: SpaceTheme.bottomGap),
      ],
    ),
  );
}

class _Top extends StatelessWidget {
  const _Top({required this.profile, required this.stretch, required this.onSoon});

  final SpaceProfile profile;
  final double stretch;
  final VoidCallback onSoon;

  @override
  Widget build(BuildContext context) {
    final banner = profile.own?.banner ?? profile.banner;
    final label = profile.own?.bannerLabel;
    const half = SpaceTheme.face / 2;
    const statsTop = SpaceTheme.countCentre - SpaceTheme.countLine / 2 + OwnSpaceTheme.drop;
    final foot = OwnSpaceTheme.bannerHeight + stretch;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: foot,
          child: ExcludeSemantics(
            child: banner == null || banner.isEmpty
                ? ColoredBox(key: ValueKey('own-space-banner-default'), color: SpaceTheme.colorsOf(context).bannerDefault)
                : RemoteImage(
                    banner,
                    key: const ValueKey('own-space-banner'),
                    // A pull stretches the box every frame; the download keeps the resting size.
                    size: Size(MediaQuery.sizeOf(context).width, OwnSpaceTheme.bannerHeight),
                    placeholder: ColoredBox(color: SpaceTheme.colorsOf(context).bannerDefault),
                  ),
          ),
        ),
        Positioned(
          left: OwnSpaceTheme.labelShadeLeft,
          right: 0,
          top: foot - OwnSpaceTheme.labelShade,
          height: OwnSpaceTheme.labelShade,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [OwnSpaceTheme.labelShadeClear, OwnSpaceTheme.labelShadeInk]),
              ),
            ),
          ),
        ),
        if (label != null) ..._label(label, foot),
        Positioned(
          left: OwnSpaceTheme.skinCentre - OwnSpaceTheme.skinTarget / 2,
          top: foot - OwnSpaceTheme.skinRise - OwnSpaceTheme.skinTarget / 2,
          width: OwnSpaceTheme.skinTarget,
          height: OwnSpaceTheme.skinTarget,
          child: Semantics(
            button: true,
            label: '装扮',
            onTap: onSoon,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('own-space-skin'),
              behavior: HitTestBehavior.opaque,
              onTap: onSoon,
              child: Center(child: OwnSkinGlyph(color: OwnSpaceTheme.skinInk)),
            ),
          ),
        ),
        Positioned(
          left: OwnSpaceTheme.faceCentreX - half,
          top: OwnSpaceTheme.faceCentreY - half + stretch,
          width: SpaceTheme.face,
          height: SpaceTheme.face,
          child: _Face(profile: profile),
        ),
        Positioned(
          left: SpaceTheme.statsLeft,
          right: SpaceTheme.statsRight,
          top: statsTop + stretch,
          child: _Stats(profile: profile),
        ),
        Positioned(
          left: SpaceTheme.followLeft,
          right: SpaceTheme.followRight,
          top: OwnSpaceTheme.editTop + stretch,
          height: SpaceTheme.followHeight,
          child: _EditButton(onTap: onSoon),
        ),
      ],
    );
  }

  /// The title over the subtitle, right-aligned before a thin rule.
  List<Widget> _label(SpaceBannerLabel label, double foot) {
    final subtitleColor = label.subtitleColor;
    final subtitleInk = subtitleColor == null ? OwnSpaceTheme.labelInk : Color(subtitleColor);
    final subtitle = label.subtitle;
    return [
      Positioned(
        left: SpaceTheme.gutter,
        right: OwnSpaceTheme.labelTitleRight,
        top: foot - OwnSpaceTheme.labelTitleRise - OwnSpaceTheme.labelTitleLine / 2,
        height: OwnSpaceTheme.labelTitleLine,
        child: spaceLine(
          label.title,
          spaceStyle(OwnSpaceTheme.labelTitleText, OwnSpaceTheme.labelInk, line: OwnSpaceTheme.labelTitleLine),
          key: const ValueKey('own-space-label-title'),
          align: TextAlign.right,
        ),
      ),
      if (subtitle.isNotEmpty)
        Positioned(
          left: SpaceTheme.gutter,
          right: OwnSpaceTheme.labelNumberRight,
          top: foot - OwnSpaceTheme.labelSubtitleRise - OwnSpaceTheme.labelSubtitleLine / 2,
          height: OwnSpaceTheme.labelSubtitleLine,
          child: Align(
            alignment: Alignment.centerRight,
            child: OwnLabelNumber.draws(subtitle)
                ? OwnLabelNumber(key: const ValueKey('own-space-label-subtitle'), text: subtitle, color: subtitleInk)
                : spaceLine(
                    subtitle,
                    spaceStyle(
                      OwnSpaceTheme.labelSubtitleText,
                      subtitleInk,
                      line: OwnSpaceTheme.labelSubtitleLine,
                    ).copyWith(fontWeight: FontWeight.w700),
                    key: const ValueKey('own-space-label-subtitle'),
                    align: TextAlign.right,
                  ),
          ),
        ),
      Positioned(
        left: OwnSpaceTheme.labelRuleLeft,
        top: foot - OwnSpaceTheme.labelIconRise - OwnSpaceTheme.labelRuleHeight / 2,
        width: OwnSpaceTheme.labelRule,
        height: OwnSpaceTheme.labelRuleHeight,
        child: ColoredBox(color: OwnSpaceTheme.labelRuleInk),
      ),
    ];
  }
}

/// The face: others' 80 pt picture in its white ring, or under a frame a smaller face with the frame around it; the
/// 大 on its lower right.
class _Face extends StatelessWidget {
  const _Face({required this.profile});

  final SpaceProfile profile;

  @override
  Widget build(BuildContext context) {
    final own = profile.own;
    final pendant = own?.pendant;
    final framed = pendant != null && pendant.isNotEmpty;
    final vip = own?.vipBadge ?? profile.vip;
    const half = SpaceTheme.face / 2;
    const badge = OwnSpaceTheme.vipDisc + OwnSpaceTheme.vipRing * 2;
    const frame = OwnSpaceTheme.pendantFace * OwnSpaceTheme.pendantScale;
    return ExcludeSemantics(
      child: Stack(
        key: const ValueKey('own-space-face'),
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (framed) ...[
            SizedBox.square(
              dimension: OwnSpaceTheme.pendantFace,
              child: ClipOval(child: RemoteImage.avatar(profile.face)),
            ),
            OverflowBox(
              maxWidth: frame,
              maxHeight: frame,
              child: IgnorePointer(
                child: SizedBox.square(
                  key: const ValueKey('own-space-pendant'),
                  dimension: frame,
                  child: DecorImage(pendant),
                ),
              ),
            ),
          ] else
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.all(SpaceTheme.faceRing),
                decoration: const BoxDecoration(color: SpaceTheme.faceRingInk, shape: BoxShape.circle),
                child: ClipOval(child: RemoteImage.avatar(profile.face)),
              ),
            ),
          if (vip)
            Positioned(
              left: framed ? half + OwnSpaceTheme.vipPendantShift.dx - badge / 2 : SpaceTheme.face - badge,
              top: framed ? half + OwnSpaceTheme.vipPendantShift.dy - badge / 2 : SpaceTheme.face - badge,
              width: badge,
              height: badge,
              child: Container(
                key: const ValueKey('own-space-vip-badge'),
                padding: const EdgeInsets.all(OwnSpaceTheme.vipRing),
                decoration: const BoxDecoration(color: OwnSpaceTheme.vipRingInk, shape: BoxShape.circle),
                child: FittedBox(child: MeVipDisc()),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.profile});

  final SpaceProfile profile;

  @override
  Widget build(BuildContext context) {
    const ruleTop = SpaceTheme.statsRuleTop - (SpaceTheme.countCentre - SpaceTheme.countLine / 2);
    final rule = Padding(
      padding: EdgeInsets.only(top: ruleTop),
      child: SizedBox(
        width: SpaceTheme.statsRuleWidth,
        height: SpaceTheme.statsRule,
        child: ColoredBox(color: SpaceTheme.colorsOf(context).statsRuleInk),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Count(key: const ValueKey('own-space-fans'), count: profile.fans, label: '粉丝'),
        ),
        rule,
        Expanded(
          child: _Count(key: const ValueKey('own-space-following'), count: profile.following, label: '关注'),
        ),
        rule,
        Expanded(
          child: _Count(key: const ValueKey('own-space-likes'), count: profile.likes, label: '获赞'),
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({super.key, required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    const gap =
        (SpaceTheme.labelCentre - SpaceTheme.labelLine / 2) - (SpaceTheme.countCentre + SpaceTheme.countLine / 2);
    final value = CountFormat.short(count);
    return Semantics(
      label: '$value$label',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: SpaceTheme.countLine,
            child: Center(
              child: spaceLine(
                value,
                spaceStyle(SpaceTheme.countText, SpaceTheme.colorsOf(context).countInk, line: SpaceTheme.countLine),
              ),
            ),
          ),
          const SizedBox(height: gap),
          SizedBox(
            height: SpaceTheme.labelLine,
            child: Center(
              child: spaceLine(
                label,
                spaceStyle(SpaceTheme.labelText, SpaceTheme.colorsOf(context).labelInk, line: SpaceTheme.labelLine),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '编辑资料',
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      key: const ValueKey('own-space-edit'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: OwnSpaceTheme.colorsOf(context).editFill,
          border: Border.all(color: OwnSpaceTheme.colorsOf(context).editInk, width: OwnSpaceTheme.editBorder),
          borderRadius: BorderRadius.circular(SpaceTheme.followRadius),
        ),
        child: Center(
          child: spaceLine(
            '编辑资料',
            spaceStyle(SpaceTheme.followText, OwnSpaceTheme.colorsOf(context).editInk, line: SpaceTheme.followHeight),
          ),
        ),
      ),
    ),
  );
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.profile, required this.onSoon});

  final SpaceProfile profile;
  final VoidCallback onSoon;

  @override
  Widget build(BuildContext context) {
    final label = profile.vipLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpaceTheme.gutter),
      child: Row(
        children: [
          Flexible(
            child: spaceLine(
              profile.name,
              spaceStyle(
                SpaceTheme.nameText,
                profile.vip ? SpaceTheme.colorsOf(context).nameVipInk : SpaceTheme.colorsOf(context).nameInk,
                line: SpaceTheme.nameBox,
              ),
              key: const ValueKey('own-space-name'),
            ),
          ),
          if (label != null && label.isNotEmpty) _VipLabel(label),
          const SizedBox(width: OwnSpaceTheme.pillGap),
          _MedalPill(pillKey: const ValueKey('own-space-medal'), title: '成就勋章', onTap: onSoon),
          const SizedBox(width: OwnSpaceTheme.pillSpacing),
          _MedalPill(pillKey: const ValueKey('own-space-fan-medal'), title: '粉丝勋章', onTap: onSoon),
        ],
      ),
    );
  }
}

/// The 大会员 label's picture at its own width; nothing, gap included, until it draws.
class _VipLabel extends StatelessWidget {
  const _VipLabel(this.url);

  final String url;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: OwnSpaceTheme.vipLabelGap + OwnSpaceTheme.vipLabelMaxWidth),
    child: ExcludeSemantics(
      child: Image(
        key: const ValueKey('own-space-vip-label'),
        image: StoredNetworkImage(secureImageUrl(url), headers: BiliClient.mediaHeaders, still: false),
        height: OwnSpaceTheme.vipLabelHeight,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, synchronous) => frame == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(left: OwnSpaceTheme.vipLabelGap),
                child: child,
              ),
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
      ),
    ),
  );
}

/// "+ 成就勋章" and "+ 粉丝勋章" in their dashed stadiums, each taking taps across the name row's height.
class _MedalPill extends StatelessWidget {
  const _MedalPill({required this.pillKey, required this.title, required this.onTap});

  final Key pillKey;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: title,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: SpaceTheme.nameBox,
        child: Center(
          child: SizedBox(key: pillKey, height: OwnSpaceTheme.pillHeight, child: _pill(context)),
        ),
      ),
    ),
  );

  Widget _pill(BuildContext context) => CustomPaint(
    painter: OwnDashedPillPainter(palette: BiliPalette.of(context)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: OwnSpaceTheme.pillPad),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SpaceGlyphIcon(
            SpaceGlyph.plus,
            width: OwnSpaceTheme.pillPlus,
            height: OwnSpaceTheme.pillPlus,
            color: OwnSpaceTheme.colorsOf(context).pillInk,
          ),
          const SizedBox(width: OwnSpaceTheme.pillPlusGap),
          spaceLine(title, spaceStyle(OwnSpaceTheme.pillText, OwnSpaceTheme.colorsOf(context).pillInk, line: OwnSpaceTheme.pillHeight)),
        ],
      ),
    ),
  );
}

/// LV, the exp towards the next level, and its bar in the level's colour.
class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.profile});

  final SpaceProfile profile;

  @override
  Widget build(BuildContext context) {
    final own = profile.own;
    final level = profile.level.clamp(0, SpaceTheme.levels.length - 1);
    final next = own?.nextExp ?? 0;
    final share = next > 0 ? (own!.exp / next).clamp(0.0, 1.0) : 0.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: OwnSpaceTheme.levelLeft,
          top: OwnSpaceTheme.levelCentre - OwnSpaceTheme.levelHeight / 2,
          height: OwnSpaceTheme.levelHeight,
          child: FittedBox(
            child: SpaceLevelBadge(level: profile.level, senior: profile.seniorMember),
          ),
        ),
        if (own != null && next > 0) ...[
          Positioned(
            left: OwnSpaceTheme.expLeft,
            top: OwnSpaceTheme.expCentre - OwnSpaceTheme.expLine / 2,
            height: OwnSpaceTheme.expLine,
            child: spaceLine(
              '${own.exp}/$next',
              spaceStyle(OwnSpaceTheme.expText, OwnSpaceTheme.colorsOf(context).expInk, line: OwnSpaceTheme.expLine),
              key: const ValueKey('own-space-exp'),
            ),
          ),
          Positioned(
            left: SpaceTheme.gutter,
            top: OwnSpaceTheme.expBarTop,
            width: OwnSpaceTheme.expBarWidth,
            height: OwnSpaceTheme.expBarHeight,
            child: ColoredBox(
              key: const ValueKey('own-space-exp-bar'),
              color: OwnSpaceTheme.colorsOf(context).expTrack,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  key: const ValueKey('own-space-exp-fill'),
                  widthFactor: share,
                  heightFactor: 1,
                  child: ColoredBox(color: SpaceTheme.levels[level]),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BioLine extends StatelessWidget {
  const _BioLine({required this.sign, required this.onDetail});

  final String sign;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: SpaceTheme.gutter,
        right: SpaceTheme.bioRight,
        top: 0,
        bottom: 0,
        child: Align(
          alignment: Alignment.centerLeft,
          child: spaceLine(
            sign.trim().isEmpty ? spaceEmptyBio : sign.replaceAll('\n', ' '),
            spaceStyle(SpaceTheme.bioText, SpaceTheme.colorsOf(context).bioInk, line: SpaceTheme.bioBox),
            key: const ValueKey('own-space-bio'),
          ),
        ),
      ),
      Positioned(
        right: SpaceTheme.gutter,
        top: 0,
        bottom: 0,
        child: Semantics(
          button: true,
          label: '详情',
          onTap: onDetail,
          excludeSemantics: true,
          child: GestureDetector(
            key: const ValueKey('own-space-detail'),
            behavior: HitTestBehavior.opaque,
            onTap: onDetail,
            child: Padding(
              padding: const EdgeInsets.only(left: SpaceTheme.gutter),
              child: spaceLine('详情', spaceStyle(SpaceTheme.detailText, SpaceTheme.colorsOf(context).detailInk, line: SpaceTheme.bioBox)),
            ),
          ),
        ),
      ),
    ],
  );
}

/// IP属地 and the like, as others' spaces draw them; a link toasts.
class _TagRow extends StatelessWidget {
  const _TagRow({required this.tags, required this.onLink});

  final List<SpaceTagLine> tags;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final style = spaceStyle(SpaceTheme.tagText, SpaceTheme.colorsOf(context).tagInk, line: SpaceTheme.tagBox);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpaceTheme.gutter),
      child: ClipRect(
        child: Row(
          children: [
            for (final (i, tag) in tags.indexed) ...[
              if (i > 0) const SizedBox(width: SpaceTheme.tagSpacing),
              Flexible(
                child: _Tag(tag: tag, style: style, onLink: onLink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.tag, required this.style, required this.onLink});

  final SpaceTagLine tag;
  final TextStyle style;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final icon = tag.icon;
    final Widget? glyph = tag.text.startsWith('IP属地')
        ? SpaceGlyphIcon(
            SpaceGlyph.ip,
            width: SpaceTheme.tagIconWidth,
            height: SpaceTheme.tagIconHeight,
            color: SpaceTheme.colorsOf(context).tagInk,
          )
        : icon != null && icon.isNotEmpty
        ? SizedBox(
            width: SpaceTheme.tagIconWidth,
            height: SpaceTheme.tagIconWidth,
            child: ExcludeSemantics(child: DecorImage(icon)),
          )
        : null;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (glyph != null) ...[
          const SizedBox(width: SpaceTheme.tagIconInset),
          glyph,
          const SizedBox(width: SpaceTheme.tagIconGap),
        ],
        Flexible(child: spaceLine(tag.text, style)),
        if (tag.link) ...[
          const SizedBox(width: SpaceTheme.tagChevronGap),
          SpaceGlyphIcon(
            SpaceGlyph.chevron,
            width: SpaceTheme.tagChevronWidth,
            height: SpaceTheme.tagChevronHeight,
            color: SpaceTheme.colorsOf(context).tagInk,
          ),
        ],
      ],
    );
    if (!tag.link) return row;
    return Semantics(
      button: true,
      label: tag.text,
      onTap: onLink,
      excludeSemantics: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onLink, child: row),
    );
  }
}
