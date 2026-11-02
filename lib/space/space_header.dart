import 'package:bili_core/api.dart' show SpaceEntry, SpaceEntryKind, SpaceOfficial, SpaceProfile, SpaceTagLine;
import 'package:bili_core/logic.dart' show CountFormat;
import 'package:flutter/widgets.dart';

import '../comments/comment_badges.dart' show DecorImage, VipMark;
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import '../video/intro/uploader_row.dart' show VerifiedBadge;
import 'space_header_glyphs.dart';

TextStyle spaceStyle(double size, Color color, {double? line}) => TextStyle(
  fontFamily: BiliFonts.family,
  fontFamilyFallback: BiliFonts.fallback,
  fontSize: size,
  fontWeight: FontWeight.w400,
  color: color,
  height: line == null ? null : line / size,
  leadingDistribution: TextLeadingDistribution.even,
  letterSpacing: 0,
  decoration: TextDecoration.none,
);

/// One line of [text], cut with … when it doesn't fit.
Widget spaceLine(String text, TextStyle style, {Key? key, TextAlign? align}) => Text(
  text,
  key: key,
  style: style,
  strutStyle: BiliFonts.strut(style),
  maxLines: 1,
  softWrap: false,
  overflow: TextOverflow.ellipsis,
  textAlign: align,
);

/// What a space with no bio shows (63).
const spaceEmptyBio = '这个人很神秘，什么都没有写';

/// Everything above the tab row (63, 69, 70, 72, 78): the banner, the face with its badge, the counts and 关注, the
/// name with its badges, the verification, the bio, the tag row and the 小店/充电 cards. [stretch] is how far a pull
/// past the top has stretched the banner. Its height is fixed by what the profile has ([heightOf]), so the page can
/// collapse it to the bar.
class SpaceHeader extends StatelessWidget {
  const SpaceHeader({
    super.key,
    required this.profile,
    required this.following,
    required this.onFollow,
    required this.onFollowed,
    required this.onSoon,
    this.stretch = 0,
  });

  final SpaceProfile profile;
  final bool following;

  /// + 关注.
  final VoidCallback onFollow;

  /// 已关注, which opens the 取消关注 sheet.
  final VoidCallback onFollowed;

  /// What isn't built yet: 充电, ▽, 详情, the cards and link tags.
  final VoidCallback onSoon;
  final double stretch;

  static double heightOf(SpaceProfile profile) {
    var height =
        SpaceTheme.topBlock + SpaceTheme.nameBox + SpaceTheme.bioGap + SpaceTheme.bioBox + SpaceTheme.bottomGap;
    if (profile.officialTitle.isNotEmpty) height += SpaceTheme.officialBlock;
    if (profile.tagLines.isNotEmpty) height += SpaceTheme.tagGap + SpaceTheme.tagBox;
    if (profile.entries.isNotEmpty) height += SpaceTheme.entriesGap + SpaceTheme.entryHeight;
    return height;
  }

  /// How far down the name's line centres, which the bar waits for.
  static const nameCentre = SpaceTheme.topBlock + SpaceTheme.nameBox / 2;

  @override
  Widget build(BuildContext context) {
    final official = profile.officialTitle.isNotEmpty;
    return ColoredBox(
      key: const ValueKey('space-header'),
      color: SpaceTheme.colorsOf(context).page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: SpaceTheme.topBlock + stretch,
            child: _Top(
              profile: profile,
              following: following,
              stretch: stretch,
              onFollow: onFollow,
              onFollowed: onFollowed,
              onSoon: onSoon,
            ),
          ),
          SizedBox(height: SpaceTheme.nameBox, child: _NameRow(profile: profile)),
          if (official)
            SizedBox(
              height: SpaceTheme.officialBlock,
              child: _OfficialLine(profile: profile, onDetail: onSoon),
            ),
          const SizedBox(height: SpaceTheme.bioGap),
          SizedBox(
            height: SpaceTheme.bioBox,
            child: _BioLine(sign: profile.sign, onDetail: official ? null : onSoon),
          ),
          if (profile.tagLines.isNotEmpty) ...[
            const SizedBox(height: SpaceTheme.tagGap),
            SizedBox(height: SpaceTheme.tagBox, child: _TagRow(tags: profile.tagLines, onLink: onSoon)),
          ],
          if (profile.entries.isNotEmpty) ...[
            const SizedBox(height: SpaceTheme.entriesGap),
            SizedBox(height: SpaceTheme.entryHeight, child: _Entries(entries: profile.entries, onTap: onSoon)),
          ],
          const SizedBox(height: SpaceTheme.bottomGap),
        ],
      ),
    );
  }
}

class _Top extends StatelessWidget {
  const _Top({
    required this.profile,
    required this.following,
    required this.stretch,
    required this.onFollow,
    required this.onFollowed,
    required this.onSoon,
  });

  final SpaceProfile profile;
  final bool following;
  final double stretch;
  final VoidCallback onFollow;
  final VoidCallback onFollowed;
  final VoidCallback onSoon;

  @override
  Widget build(BuildContext context) {
    final banner = profile.banner;
    const statsTop = SpaceTheme.countCentre - SpaceTheme.countLine / 2;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: SpaceTheme.bannerHeight + stretch,
          child: ExcludeSemantics(
            child: banner == null || banner.isEmpty
                ? ColoredBox(key: ValueKey('space-banner-default'), color: SpaceTheme.colorsOf(context).bannerDefault)
                : RemoteImage(
                    banner,
                    // A pull stretches the box every frame; the download keeps the resting size.
                    size: Size(MediaQuery.sizeOf(context).width, SpaceTheme.bannerHeight),
                    placeholder: ColoredBox(color: SpaceTheme.colorsOf(context).bannerDefault),
                  ),
          ),
        ),
        Positioned(
          left: SpaceTheme.faceLeft,
          top: SpaceTheme.faceTop + stretch,
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
          top: SpaceTheme.followTop + stretch,
          height: SpaceTheme.followHeight,
          child: SpaceFollowRow(
            following: following,
            chargeable: profile.chargeable,
            onFollow: onFollow,
            onFollowed: onFollowed,
            onSoon: onSoon,
          ),
        ),
      ],
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.profile});

  final SpaceProfile profile;

  @override
  Widget build(BuildContext context) {
    final Widget? badge = switch (profile.official) {
      SpaceOfficial.person => const VerifiedBadge(color: IntroTheme.badgePerson),
      SpaceOfficial.organisation => const VerifiedBadge(color: IntroTheme.badgeOrganisation),
      SpaceOfficial.none => profile.vip ? const VipMark() : null,
    };
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(SpaceTheme.faceRing),
              decoration: const BoxDecoration(color: SpaceTheme.faceRingInk, shape: BoxShape.circle),
              child: ClipOval(child: RemoteImage.avatar(profile.face)),
            ),
          ),
          // The video page's bolt and 评论's 大 are drawn at half this size; scaled up whole, ring and all.
          if (badge != null)
            Positioned(
              right: 0,
              bottom: 0,
              width: SpaceTheme.faceBadge,
              height: SpaceTheme.faceBadge,
              child: FittedBox(key: const ValueKey('space-face-badge'), child: badge),
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
        Expanded(child: _Count(key: const ValueKey('space-fans'), count: profile.fans, label: '粉丝')),
        rule,
        Expanded(child: _Count(key: const ValueKey('space-following'), count: profile.following, label: '关注')),
        rule,
        Expanded(child: _Count(key: const ValueKey('space-likes'), count: profile.likes, label: '获赞')),
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

/// + 关注 across the row; followed, 已关注 and ▽; 充电 first when the uploader takes it (63, 70, 78, 79).
class SpaceFollowRow extends StatelessWidget {
  const SpaceFollowRow({
    super.key,
    required this.following,
    required this.chargeable,
    required this.onFollow,
    required this.onFollowed,
    required this.onSoon,
  });

  final bool following;
  final bool chargeable;
  final VoidCallback onFollow;
  final VoidCallback onFollowed;
  final VoidCallback onSoon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (chargeable) ...[
        SizedBox(
          width: SpaceTheme.chargeWidth,
          child: _Button(
            key: const ValueKey('space-charge'),
            label: '充电',
            onTap: onSoon,
            decoration: BoxDecoration(
              color: SpaceTheme.colorsOf(context).page,
              border: Border.all(color: SpaceTheme.colorsOf(context).chargeInk, width: SpaceTheme.chargeBorder),
              borderRadius: BorderRadius.circular(SpaceTheme.followRadius),
            ),
            glyph: SpaceGlyphIcon(
              SpaceGlyph.bolt,
              width: SpaceTheme.chargeBoltWidth,
              height: SpaceTheme.chargeBoltHeight,
              color: SpaceTheme.colorsOf(context).chargeInk,
            ),
            glyphGap: SpaceTheme.chargeBoltGap,
            ink: SpaceTheme.colorsOf(context).chargeInk,
            text: SpaceTheme.chargeText,
            shift: SpaceTheme.chargeShift,
          ),
        ),
        const SizedBox(width: SpaceTheme.chargeGap),
      ],
      if (following) ...[
        Expanded(
          child: _Button(
            key: const ValueKey('space-followed'),
            label: '已关注',
            onTap: onFollowed,
            decoration: BoxDecoration(
              color: SpaceTheme.colorsOf(context).followedFill,
              borderRadius: BorderRadius.circular(SpaceTheme.followRadius),
            ),
            glyph: SpaceGlyphIcon(
              SpaceGlyph.list,
              width: SpaceTheme.followedListWidth,
              height: SpaceTheme.followedListHeight,
              color: SpaceTheme.colorsOf(context).followedInk,
            ),
            glyphGap: SpaceTheme.followedListGap,
            ink: SpaceTheme.colorsOf(context).followedInk,
          ),
        ),
        const SizedBox(width: SpaceTheme.moreGap),
        SizedBox(
          width: SpaceTheme.moreWidth,
          child: Semantics(
            button: true,
            label: '更多推荐',
            onTap: onSoon,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('space-follow-more'),
              behavior: HitTestBehavior.opaque,
              onTap: onSoon,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: SpaceTheme.colorsOf(context).followedFill,
                  borderRadius: BorderRadius.circular(SpaceTheme.followRadius),
                ),
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, SpaceTheme.moreChevronDrop),
                    child: SpaceGlyphIcon(
                      SpaceGlyph.chevronDown,
                      width: SpaceTheme.moreChevronWidth,
                      height: SpaceTheme.moreChevronHeight,
                      color: SpaceTheme.colorsOf(context).followedInk,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ] else
        Expanded(
          child: _Button(
            key: const ValueKey('space-follow'),
            label: '关注',
            onTap: onFollow,
            decoration: BoxDecoration(
              color: SpaceTheme.colorsOf(context).followFill,
              borderRadius: BorderRadius.circular(SpaceTheme.followRadius),
            ),
            glyph: const SpaceGlyphIcon(
              SpaceGlyph.plus,
              width: SpaceTheme.followPlus,
              height: SpaceTheme.followPlus,
              color: SpaceTheme.followInk,
            ),
            glyphGap: SpaceTheme.followPlusGap,
            ink: SpaceTheme.followInk,
          ),
        ),
    ],
  );
}

class _Button extends StatelessWidget {
  const _Button({
    super.key,
    required this.label,
    required this.onTap,
    required this.decoration,
    required this.glyph,
    required this.glyphGap,
    required this.ink,
    this.text = SpaceTheme.followText,
    this.shift = SpaceTheme.followShift,
  });

  final String label;
  final VoidCallback onTap;
  final BoxDecoration decoration;
  final Widget glyph;
  final double glyphGap;
  final Color ink;
  final double text;
  final double shift;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: decoration,
        child: Transform.translate(
          offset: Offset(shift, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              glyph,
              SizedBox(width: glyphGap),
              spaceLine(label, spaceStyle(text, ink, line: SpaceTheme.followHeight)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.profile});

  final SpaceProfile profile;

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
              key: const ValueKey('space-name'),
            ),
          ),
          const SizedBox(width: SpaceTheme.levelGap),
          SpaceLevelBadge(level: profile.level, senior: profile.seniorMember),
          if (label != null && label.isNotEmpty) ...[
            const SizedBox(width: SpaceTheme.vipLabelGap),
            SizedBox(
              key: const ValueKey('space-vip-label'),
              width: SpaceTheme.vipLabelWidth,
              height: SpaceTheme.vipLabelHeight,
              child: ExcludeSemantics(child: DecorImage(label, alignment: Alignment.centerLeft)),
            ),
          ],
        ],
      ),
    );
  }
}

/// 详情, which shows the whole profile in the official app.
class _Detail extends StatelessWidget {
  const _Detail({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '详情',
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      key: const ValueKey('space-detail'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: SpaceTheme.gutter),
        child: spaceLine('详情', spaceStyle(SpaceTheme.detailText, SpaceTheme.colorsOf(context).detailInk, line: SpaceTheme.bioBox)),
      ),
    ),
  );
}

class _OfficialLine extends StatelessWidget {
  const _OfficialLine({required this.profile, required this.onDetail});

  final SpaceProfile profile;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final disc = profile.official == SpaceOfficial.organisation
        ? IntroTheme.badgeOrganisation
        : IntroTheme.badgePerson;
    return Stack(
      children: [
        Positioned(
          left: SpaceTheme.gutter,
          right: SpaceTheme.bioRight,
          top: SpaceTheme.officialCentre - SpaceTheme.officialHeight / 2,
          height: SpaceTheme.officialHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              key: const ValueKey('space-official'),
              decoration: BoxDecoration(
                color: SpaceTheme.colorsOf(context).officialFill,
                borderRadius: BorderRadius.circular(SpaceTheme.officialHeight / 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: SpaceTheme.officialDiscInset),
                  Container(
                    width: SpaceTheme.officialDisc,
                    height: SpaceTheme.officialDisc,
                    decoration: BoxDecoration(color: disc, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const SpaceGlyphIcon(
                      SpaceGlyph.bolt,
                      width: SpaceTheme.officialBoltWidth,
                      height: SpaceTheme.officialBoltHeight,
                      color: IntroTheme.badgeBolt,
                    ),
                  ),
                  const SizedBox(width: SpaceTheme.officialTextGap),
                  Flexible(
                    child: spaceLine(
                      profile.officialTitle,
                      spaceStyle(SpaceTheme.officialText, SpaceTheme.colorsOf(context).officialInk, line: SpaceTheme.officialHeight),
                    ),
                  ),
                  const SizedBox(width: SpaceTheme.officialPadRight),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: SpaceTheme.gutter,
          top: SpaceTheme.officialCentre - SpaceTheme.bioBox / 2,
          height: SpaceTheme.bioBox,
          child: _Detail(onTap: onDetail),
        ),
      ],
    );
  }
}

class _BioLine extends StatelessWidget {
  const _BioLine({required this.sign, required this.onDetail});

  final String sign;

  /// Null when 详情 sits on the verification's line instead.
  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context) {
    final detail = onDetail;
    return Stack(
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
              key: const ValueKey('space-bio'),
            ),
          ),
        ),
        if (detail != null) Positioned(right: SpaceTheme.gutter, top: 0, bottom: 0, child: _Detail(onTap: detail)),
      ],
    );
  }
}

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
              Flexible(child: _Tag(tag: tag, style: style, onLink: onLink)),
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

class _Entries extends StatelessWidget {
  const _Entries({required this.entries, required this.onTap});

  final List<SpaceEntry> entries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: SpaceTheme.gutter),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, entry) in entries.take(2).indexed) ...[
          if (i > 0) const SizedBox(width: SpaceTheme.entrySpacing),
          Expanded(child: _Entry(entry: entry, onTap: onTap)),
        ],
      ],
    ),
  );
}

class _Entry extends StatelessWidget {
  const _Entry({required this.entry, required this.onTap});

  final SpaceEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (entry.kind) {
      SpaceEntryKind.shop => const SpaceGlyphIcon(
        SpaceGlyph.shop,
        width: SpaceTheme.entryIcon,
        height: SpaceTheme.entryShopHeight,
        color: SpaceTheme.entryIconInk,
      ),
      SpaceEntryKind.charge => const SizedBox(
        width: SpaceTheme.entryIcon,
        child: Center(
          child: SpaceGlyphIcon(
            SpaceGlyph.bolt,
            width: SpaceTheme.entryBoltWidth,
            height: SpaceTheme.entryBoltHeight,
            color: SpaceTheme.entryIconInk,
          ),
        ),
      ),
    };
    return Semantics(
      button: true,
      label: '${entry.title}，${entry.note}',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('space-entry-${entry.kind.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: SpaceTheme.colorsOf(context).entryFill,
            borderRadius: BorderRadius.circular(SpaceTheme.entryRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: SpaceTheme.entryPad, right: SpaceTheme.entryPadRight),
            child: Row(
              children: [
                icon,
                const SizedBox(width: SpaceTheme.entryIconGap),
                Transform.translate(
                  offset: const Offset(0, SpaceTheme.entryTextDrop),
                  child: spaceLine(
                    entry.title,
                    spaceStyle(SpaceTheme.entryText, SpaceTheme.colorsOf(context).entryInk, line: SpaceTheme.entryHeight),
                  ),
                ),
                const SizedBox(width: SpaceTheme.entryPad),
                Expanded(
                  child: spaceLine(
                    entry.note,
                    spaceStyle(SpaceTheme.entryNoteText, SpaceTheme.colorsOf(context).entryNoteInk, line: SpaceTheme.entryHeight),
                    align: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
