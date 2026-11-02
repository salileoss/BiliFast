import 'dart:async';

import 'package:bili_core/api.dart' show OfficialKind, UploaderCard, VideoCard, VideoDetail, VideoTag, VideoTagKind;
import 'package:bili_core/devlog.dart';
import 'package:bili_core/logic.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../danmaku/danmaku_session.dart';
import '../../player_ui/end_screen_portrait.dart' show CountGlyph, CountPainter;
import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../../space/uploader_tap.dart';
import '../actions/video_actions.dart';
import '../intro/action_row.dart';
import '../intro/collection_row.dart';
import '../intro/desc_text.dart';
import '../intro/intro_tab.dart';
import '../intro/part_strip.dart';
import '../intro/related_list.dart';
import '../intro/tag_chips.dart';
import '../intro/title_block.dart' show OnlinePainter;
import '../intro/uploader_row.dart';
import '../page_details.dart';
import '../page_tabs.dart' show DanmakuMark;
import '../player_prefs.dart';
import '../player_session.dart';

/// The iPad's 简介 sections without the related videos (ipad/03, 04, 06): the uploader, the title block, the actions,
/// the parts or the 合集 and the chips, in one column at the iPad's gutters. Sideways it heads the left column above
/// 热门评论, with 点我发弹幕 at the end of the uploader's row; upright it heads 简介 above the related videos and the
/// field is the tab row's. It ends where 热门评论's hairline goes.
class PadIntroHead extends StatelessWidget {
  const PadIntroHead({
    super.key,
    required this.content,
    required this.details,
    required this.onSeek,
    required this.onOpenVideo,
    required this.onPlayEpisode,
    required this.onOpenEpisodes,
    this.player,
    this.danmaku,
  });

  final IntroContent content;
  final PageDetails details;
  final ValueChanged<double> onSeek;
  final ValueChanged<String> onOpenVideo;
  final ValueChanged<Episode> onPlayEpisode;
  final VoidCallback onOpenEpisodes;

  /// The page's session, for the 弹 toggle sideways; before it exists the toggle shows the saved switch.
  final PlayerSession? player;

  /// The page's danmaku, which 点我发弹幕 opens the send bar of.
  final DanmakuSession? danmaku;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final sideways = size.width > size.height;
    return ListenableBuilder(
      listenable: details,
      builder: (context, _) {
        final detail = content.detail;
        if (detail == null) return const SizedBox.shrink();
        final actions = details.actions;
        final season = detail.season;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PadUploaderRow(
              detail: detail,
              card: details.uploader,
              actions: actions,
              trailing: sideways ? _DanmakuEntry(player: player, danmaku: danmaku) : null,
            ),
            PadTitleBlock(
              detail: detail,
              online: details.online,
              tags: details.tags,
              onSeek: onSeek,
              onOpenVideo: onOpenVideo,
              titleGap: sideways ? PadBodyTheme.titleGap : PadBodyTheme.titleGapUpright,
            ),
            if (actions != null) ActionRow(actions: actions, metrics: ActionRowMetrics.pad),
            // No iPad screenshot has parts, a 合集 or topic chips: the iPhone's, at the iPad's gutter.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PadBodyTheme.sectionInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (content.episodesAreParts && content.episodes.isNotEmpty)
                    PartStrip(parts: content.episodes, onChoose: onPlayEpisode, onOpenList: onOpenEpisodes)
                  else if (season != null)
                    CollectionRow(title: season.title, episodes: content.episodes, onOpen: onOpenEpisodes),
                  TagChips(tags: details.tags),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The related videos as the iPad's right column sideways (ipad/03), scrolling on its own.
class PadRelatedColumn extends StatelessWidget {
  const PadRelatedColumn({super.key, required this.cards, required this.onOpen, required this.onWatchLater});

  final List<VideoCard> cards;
  final ValueChanged<VideoCard> onOpen;
  final ValueChanged<VideoCard> onWatchLater;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    key: const PageStorageKey('pad-related'),
    primary: false,
    slivers: [
      RelatedSliver(cards: cards, onOpen: onOpen, onWatchLater: onWatchLater, column: true),
      SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + PageTheme.introBottom)),
    ],
  );
}

/// The uploader on the iPad (03): the face, the name over 粉丝 and 视频, + 关注 right after them, and [trailing] at
/// the row's end. A 联合投稿 keeps the iPhone's staff row (no iPad screenshot).
class PadUploaderRow extends StatelessWidget {
  const PadUploaderRow({super.key, required this.detail, this.card, this.actions, this.trailing});

  final VideoDetail detail;
  final UploaderCard? card;
  final VideoActions? actions;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    if (detail.staff.length > 1) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: PadBodyTheme.sectionInset),
              child: UploaderRow(detail: detail, card: this.card, actions: actions),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(top: PadBodyTheme.uploaderTop, right: PadBodyTheme.gutter),
              child: trailing,
            ),
        ],
      );
    }
    final card = this.card;
    final name = _or(card?.name, detail.owner.name);
    final face = _or(card?.face, detail.owner.face);
    final uploader = UploaderRef(mid: detail.owner.mid, name: name, face: face);
    final open = uploader.mid > 0 ? () => openUploader(context, uploader) : null;
    return Padding(
      padding: const EdgeInsets.only(
        left: PadBodyTheme.gutter,
        right: PadBodyTheme.gutter,
        top: PadBodyTheme.uploaderTop,
      ),
      child: SizedBox(
        height: PadBodyTheme.avatar,
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Semantics(
                      key: const ValueKey('uploader-open'),
                      container: true,
                      button: open != null,
                      label: name,
                      value: card == null ? null : _counts(card),
                      onTap: open,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: open,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Avatar(face: face, official: card?.official ?? OfficialKind.none),
                            const SizedBox(width: PadBodyTheme.avatarGap),
                            Flexible(
                              child: _NameAndCounts(name: name, card: card),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: PadBodyTheme.followGap),
                  _Follow(actions: actions, cardFollowing: card?.following ?? false),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: PadBodyTheme.followGap), trailing],
          ],
        ),
      ),
    );
  }
}

String _or(String? fromCard, String fromView) => fromCard == null || fromCard.isEmpty ? fromView : fromCard;

class _Avatar extends StatelessWidget {
  const _Avatar({required this.face, required this.official});

  final String face;
  final OfficialKind official;

  @override
  Widget build(BuildContext context) {
    final badge = switch (official) {
      OfficialKind.person => IntroTheme.badgePerson,
      OfficialKind.organisation => IntroTheme.badgeOrganisation,
      OfficialKind.none => null,
    };
    return SizedBox.square(
      dimension: PadBodyTheme.avatar,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: ClipOval(child: RemoteImage.avatar(face))),
          if (badge != null)
            Positioned(
              right: -IntroTheme.badgeRing,
              bottom: -IntroTheme.badgeRing,
              child: ExcludeSemantics(child: VerifiedBadge(color: badge)),
            ),
        ],
      ),
    );
  }
}

class _NameAndCounts extends StatelessWidget {
  const _NameAndCounts({required this.name, required this.card});

  final String name;
  final UploaderCard? card;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    final animate = !MediaQuery.disableAnimationsOf(context);
    final nameStyle = TextStyle(
      fontFamily: BiliFonts.family,
      fontFamilyFallback: BiliFonts.fallback,
      fontSize: PadBodyTheme.nameText,
      height: PadBodyTheme.nameLine / PadBodyTheme.nameText,
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: 0,
      color: card?.isVip == true ? BiliColors.colorsOf(context).pink : IntroTheme.colorsOf(context).name,
    );
    final countsStyle = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: PadBodyTheme.fansText,
      height: PadBodyTheme.fansLine / PadBodyTheme.fansText,
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: 0,
      color: BiliColors.colorsOf(context).secondaryText,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: PadBodyTheme.nameCentre - PadBodyTheme.nameLine / 2),
        SizedBox(
          height: PadBodyTheme.nameLine,
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: nameStyle),
        ),
        const SizedBox(
          height:
              PadBodyTheme.fansCentre - PadBodyTheme.fansLine / 2 - PadBodyTheme.nameCentre - PadBodyTheme.nameLine / 2,
        ),
        SizedBox(
          height: PadBodyTheme.fansLine,
          child: AnimatedOpacity(
            opacity: card == null ? 0 : 1,
            duration: animate ? const Duration(milliseconds: 220) : Duration.zero,
            curve: Curves.easeOut,
            child: Text.rich(
              apartFromHan(card == null ? '' : _counts(card), BiliFonts.nudged ? 0 : IntroTheme.fansHanGap),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: countsStyle,
            ),
          ),
        ),
      ],
    );
  }
}

/// One space between the counts, where the iPhone has two (03).
String _counts(UploaderCard card) => '${CountFormat.short(card.fans)}粉丝 ${CountFormat.short(card.videos)}视频';

class _Follow extends StatelessWidget {
  const _Follow({required this.actions, required this.cardFollowing});

  final VideoActions? actions;
  final bool cardFollowing;

  @override
  Widget build(BuildContext context) {
    final actions = this.actions;
    if (actions == null) return FollowPill(following: cardFollowing, onTap: null, pad: true);
    return ListenableBuilder(
      listenable: actions,
      builder: (context, _) => FollowPill(following: actions.following, onTap: actions.tapFollow, pad: true),
    );
  }
}

/// The page's 点我发弹幕 and 弹 toggle, following the session's switch and the send bar.
class _DanmakuEntry extends StatelessWidget {
  const _DanmakuEntry({required this.player, required this.danmaku});

  final PlayerSession? player;
  final DanmakuSession? danmaku;

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    final danmaku = this.danmaku;
    final still = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([?player, ?danmaku, ?danmaku?.sendOpen]),
      builder: (context, _) {
        final closed = danmaku?.closed ?? false;
        return PadDanmakuCapsule(
          on: player?.danmakuOn ?? PlayerPrefs.shared.danmakuOn,
          onToggle: player == null ? null : () => player.setDanmakuOn(!player.danmakuOn),
          onSend: closed ? null : () => danmaku?.openSend(),
          text: closed ? 'UP主已关闭弹幕' : ((danmaku?.sendOpen.value ?? false) ? '弹幕输入中' : '点我发弹幕'),
          duration: still ? Duration.zero : const Duration(milliseconds: 250),
        );
      },
    );
  }
}

/// The iPad's 点我发弹幕 joined to the 弹 toggle (ipad/03, 06), or the toggle alone in a grey capsule while danmaku is
/// off, as the iPhone's tab row does it.
class PadDanmakuCapsule extends StatelessWidget {
  const PadDanmakuCapsule({
    super.key,
    required this.on,
    required this.onToggle,
    required this.onSend,
    required this.text,
    required this.duration,
  });

  final bool on;
  final VoidCallback? onToggle;

  /// Null while the uploader has danmaku closed.
  final VoidCallback? onSend;
  final String text;
  final Duration duration;

  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: PadBodyTheme.capsuleText,
      color: BiliColors.colorsOf(context).secondaryText,
      height: 1.2,
      letterSpacing: 0,
    );
    const fieldWidth = PadBodyTheme.capsuleWidth - PadBodyTheme.capsuleToggle;
    return AnimatedContainer(
      key: const ValueKey('pad-danmaku-capsule'),
      duration: duration,
      curve: _curve,
      width: on ? PadBodyTheme.capsuleWidth : PadBodyTheme.capsuleToggleOff,
      height: PadBodyTheme.capsuleHeight,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(color: BiliColors.colorsOf(context).softGrey, shape: StadiumBorder()),
      foregroundDecoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(color: BiliColors.colorsOf(context).divider, width: PadBodyTheme.capsuleBorder),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRect(
              child: OverflowBox(
                minWidth: fieldWidth,
                maxWidth: fieldWidth,
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: on ? 1 : 0,
                  duration: duration,
                  child: ExcludeSemantics(
                    excluding: !on,
                    child: Semantics(
                      key: const ValueKey('danmaku-send'),
                      button: onSend != null,
                      label: text,
                      onTap: on ? onSend : null,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: on ? onSend : null,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: PadBodyTheme.capsuleTextLead,
                            top: PadBodyTheme.capsuleTextDrop * 2,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedSwitcher(
                              duration: duration,
                              child: Text(
                                text,
                                key: ValueKey(text),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.clip,
                                style: style,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: duration,
            curve: _curve,
            width: on ? PadBodyTheme.capsuleToggle : PadBodyTheme.capsuleToggleOff,
            color: on ? BiliColors.colorsOf(context).card : BiliColors.colorsOf(context).softGrey,
            child: Semantics(
              key: const ValueKey('danmaku-toggle'),
              button: true,
              toggled: on,
              label: on ? '关闭弹幕' : '开启弹幕',
              onTap: onToggle,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedPositioned(
                      duration: duration,
                      curve: _curve,
                      top: 0,
                      bottom: 0,
                      right:
                          (on ? PadBodyTheme.capsuleMarkCentre : PadBodyTheme.capsuleToggleOff / 2) -
                          PageTheme.danmakuMark / 2,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: duration,
                          child: DanmakuMark(key: ValueKey(on), on: on),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _style(double size, Color color, {double? line, FontWeight? weight}) => TextStyle(
  fontFamily: BiliFonts.family,
  fontFamilyFallback: BiliFonts.fallback,
  fontSize: size,
  height: (line ?? size) / size,
  leadingDistribution: TextLeadingDistribution.even,
  letterSpacing: 0,
  fontWeight: weight,
  color: color,
);

/// The iPad's title block (03, 04): the title with its 活动 tag on one line, then ▶ 💬 the date, N人正在看, the BV id
/// and 查看简介 ∨, which opens the description and the plain tags in place (04). The title opens them too, as the
/// iPhone's does.
class PadTitleBlock extends StatefulWidget {
  const PadTitleBlock({
    super.key,
    required this.detail,
    required this.online,
    required this.tags,
    required this.onSeek,
    required this.onOpenVideo,
    this.titleGap = PadBodyTheme.titleGap,
    this.openLink = _openInBrowser,
  });

  final VideoDetail detail;
  final ValueListenable<String?> online;
  final List<VideoTag> tags;
  final ValueChanged<double> onSeek;
  final ValueChanged<String> onOpenVideo;

  /// The title's centre below the uploader row's bottom.
  final double titleGap;

  /// A web address in the description; the browser by default. False when nothing could open it.
  final Future<bool> Function(Uri link) openLink;

  static Future<bool> _openInBrowser(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  State<PadTitleBlock> createState() => _PadTitleBlockState();
}

class _PadTitleBlockState extends State<PadTitleBlock> with SingleTickerProviderStateMixin {
  late final _reveal = AnimationController(vsync: this, duration: IntroTheme.expandDuration);
  late final _curve = CurvedAnimation(parent: _reveal, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _reveal.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(PadTitleBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail.bvid != widget.detail.bvid && _expanded) {
      _expanded = false;
      _reveal.value = 0;
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = _expanded ? 1 : 0;
    } else if (_expanded) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }
  }

  Future<void> _openLink(Uri link) async {
    var opened = false;
    try {
      opened = await widget.openLink(link);
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'description link failed', {'error': '$error'});
    }
    if (!opened && mounted) showToast(context, '无法打开链接');
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final animate = !MediaQuery.disableAnimationsOf(context);
    final title = _style(
      PadBodyTheme.titleText,
      PadBodyTheme.colorsOf(context).titleInk,
      line: PadBodyTheme.titleLine,
      weight: FontWeight.w500,
    );
    final titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.honor != null) ...[const _HonorTag(), const SizedBox(width: PadBodyTheme.honorGap)],
        Expanded(
          child: Text(
            detail.title,
            maxLines: _expanded ? null : 1,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: title,
            strutStyle: BiliFonts.strut(title),
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(
        left: PadBodyTheme.gutter,
        right: PadBodyTheme.gutter,
        top: widget.titleGap - PadBodyTheme.titleLine / 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: detail.honor == null ? detail.title : '活动，${detail.title}',
            hint: _expanded ? '收起简介' : '展开简介',
            onTap: _toggle,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: animate
                  ? AnimatedSize(
                      duration: IntroTheme.expandDuration,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: titleRow,
                    )
                  : titleRow,
            ),
          ),
          const SizedBox(height: PadBodyTheme.metaGap - PadBodyTheme.titleLine / 2 - PadBodyTheme.metaLine / 2),
          _MetaLine(detail: detail, online: widget.online, expanded: _expanded, onToggle: _toggle),
          if (detail.argueMessage case final notice?)
            Padding(
              padding: const EdgeInsets.only(top: IntroTheme.noticeGap),
              child: Text(
                notice,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style(PadBodyTheme.metaText, BiliColors.colorsOf(context).secondaryText, line: PadBodyTheme.metaLine),
              ),
            ),
          SizeTransition(
            sizeFactor: _curve,
            alignment: Alignment.topCenter,
            child: FadeTransition(
              opacity: _curve,
              child: _reveal.isDismissed && !_expanded
                  ? const SizedBox(width: double.infinity)
                  : _Details(
                      detail: detail,
                      tags: widget.tags,
                      onSeek: widget.onSeek,
                      onOpenVideo: widget.onOpenVideo,
                      openLink: (link) => unawaited(_openLink(link)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HonorTag extends StatelessWidget {
  const _HonorTag();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: PadBodyTheme.titleLine,
    child: Align(
      alignment: const Alignment(0, PadBodyTheme.honorDrop / ((PadBodyTheme.titleLine - PadBodyTheme.honorHeight) / 2)),
      widthFactor: 1,
      child: Container(
        height: PadBodyTheme.honorHeight,
        padding: const EdgeInsets.symmetric(horizontal: PadBodyTheme.honorPadding),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BiliColors.colorsOf(context).softGrey,
          borderRadius: BorderRadius.circular(PadBodyTheme.honorHeight / 2),
        ),
        child: Text('活动', style: _style(PadBodyTheme.honorText, BiliColors.colorsOf(context).pink, line: PadBodyTheme.honorHeight)),
      ),
    ),
  );
}

/// ▶ 59.7万  ☰ 77  2026年10月27日 15:40  Ω 4000+人正在看  BV1Fk4x7NqTz  查看简介 ∨. A line too long for the width
/// shrinks a little rather than cut.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.detail, required this.online, required this.expanded, required this.onToggle});

  final VideoDetail detail;
  final ValueListenable<String?> online;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final text = _style(PadBodyTheme.metaText, BiliColors.colorsOf(context).secondaryText, line: PadBodyTheme.metaLine);
    final strut = BiliFonts.strut(text);
    const icon = Size(PadBodyTheme.metaIconWidth, PadBodyTheme.metaIconHeight);
    const group = SizedBox(width: PadBodyTheme.metaGroupGap);
    const iconGap = SizedBox(width: PadBodyTheme.metaIconGap);
    final animate = !MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: PadBodyTheme.metaLine,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const SizedBox(width: PadBodyTheme.metaLead),
            CustomPaint(
              size: icon,
              painter: CountPainter(CountGlyph.views, color: BiliColors.colorsOf(context).secondaryText),
            ),
            iconGap,
            Text(CountFormat.short(detail.stat.view), style: text, strutStyle: strut),
            group,
            CustomPaint(
              size: icon,
              painter: CountPainter(CountGlyph.danmaku, color: BiliColors.colorsOf(context).secondaryText),
            ),
            iconGap,
            Text(CountFormat.short(detail.stat.danmaku), style: text, strutStyle: strut),
            group,
            Text(TimeFormat.publish(detail.pubdate), style: text, strutStyle: strut),
            ValueListenableBuilder(
              valueListenable: online,
              builder: (context, count, _) {
                if (count == null || count.isEmpty) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    group,
                    const CustomPaint(size: icon, painter: OnlinePainter()),
                    iconGap,
                    Text('$count人正在看', style: text, strutStyle: strut),
                  ],
                );
              },
            ),
            group,
            Text(detail.bvid, style: text, strutStyle: strut),
            group,
            Semantics(
              key: const ValueKey('pad-intro-toggle'),
              button: true,
              label: '查看简介',
              expanded: expanded,
              onTap: onToggle,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('查看简介', style: text, strutStyle: strut),
                    const SizedBox(width: PadBodyTheme.toggleChevronGap),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: animate ? IntroTheme.expandDuration : Duration.zero,
                      curve: Curves.easeOutCubic,
                      child: CustomPaint(
                        size: Size(PadBodyTheme.toggleChevronWidth, PadBodyTheme.toggleChevronHeight),
                        painter: _ChevronPainter(palette: BiliPalette.of(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  final BiliPalette palette;
  const _ChevronPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = IntroTheme.chevronStroke / 2;
    final path = Path()
      ..moveTo(inset, inset)
      ..lineTo(size.width / 2, size.height - inset)
      ..lineTo(size.width - inset, inset);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = IntroTheme.chevronStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = BiliColorsColors(palette).secondaryText,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// 04's opened part: the description, then the plain tags as grey capsules.
class _Details extends StatelessWidget {
  const _Details({
    required this.detail,
    required this.tags,
    required this.onSeek,
    required this.onOpenVideo,
    required this.openLink,
  });

  final VideoDetail detail;
  final List<VideoTag> tags;
  final ValueChanged<double> onSeek;
  final ValueChanged<String> onOpenVideo;
  final ValueChanged<Uri> openLink;

  @override
  Widget build(BuildContext context) {
    final runs = descriptionRuns(detail.descParts);
    final plain = [
      for (final tag in tags)
        if (tag.kind == VideoTagKind.normal) tag,
    ];
    final tagStyle = _style(PadBodyTheme.tagText, PadBodyTheme.colorsOf(context).tagInk, line: PadBodyTheme.tagHeight);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (runs.isNotEmpty) ...[
          const SizedBox(height: PadBodyTheme.descGap),
          DescriptionText(
            runs: runs,
            style: _style(PadBodyTheme.descText, BiliColors.colorsOf(context).secondaryText, line: PadBodyTheme.descLine),
            onSeek: onSeek,
            onOpenVideo: onOpenVideo,
            onOpenLink: openLink,
          ),
        ],
        if (plain.isNotEmpty) ...[
          const SizedBox(height: PadBodyTheme.tagsGap),
          Wrap(
            spacing: PadBodyTheme.tagSpacing,
            runSpacing: PadBodyTheme.tagSpacing,
            children: [
              for (final tag in plain)
                Container(
                  height: PadBodyTheme.tagHeight,
                  padding: const EdgeInsets.symmetric(horizontal: PadBodyTheme.tagPadding),
                  decoration: BoxDecoration(
                    color: BiliColors.colorsOf(context).pageGrey,
                    borderRadius: BorderRadius.circular(PadBodyTheme.tagHeight / 2),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      tag.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tagStyle,
                      strutStyle: BiliFonts.strut(tagStyle),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
