import 'package:bili_core/api.dart' show VideoCard, VideoDetail;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../app/form_factor.dart';
import '../../shared/theme.dart';
import '../collapsing_player.dart';
import '../pad/pad_body.dart';
import '../page_details.dart';
import '../player_session.dart';
import 'action_row.dart';
import 'collection_row.dart';
import 'part_strip.dart';
import 'related_list.dart';
import 'tag_chips.dart';
import 'title_block.dart';
import 'uploader_row.dart';

/// What 简介 shows of the session's video; the page stops taking it once it leaves.
@immutable
final class IntroContent {
  const IntroContent({
    this.detail,
    this.related = const [],
    this.episodes = const [],
    this.episodesAreParts = false,
    this.detailFailed = false,
    this.onRetryDetail,
  });

  IntroContent.of(PlayerSession session)
    : this(
        detail: session.detail,
        related: session.related,
        episodes: session.episodes,
        episodesAreParts: session.episodesAreParts,
        detailFailed: session.detailFailed,
        onRetryDetail: session.retryDetail,
      );

  final VideoDetail? detail;
  final List<VideoCard> related;
  final List<Episode> episodes;
  final bool episodesAreParts;

  /// The detail never came: 简介 offers 加载失败，点击重试, which calls [onRetryDetail].
  final bool detailFailed;
  final VoidCallback? onRetryDetail;

  @override
  bool operator ==(Object other) =>
      other is IntroContent &&
      other.detail == detail &&
      identical(other.related, related) &&
      listEquals(other.episodes, episodes) &&
      other.episodesAreParts == episodesAreParts &&
      other.detailFailed == detailFailed &&
      other.onRetryDetail == onRetryDetail;

  @override
  int get hashCode => Object.hash(
    detail,
    identityHashCode(related),
    Object.hashAll(episodes),
    episodesAreParts,
    detailFailed,
    onRetryDetail,
  );
}

/// 简介 (03, 18): the uploader, the title block, the action row once the actions exist, the parts or the 合集, the
/// topic and BGM chips, and the related videos. Each section keeps its own gap above and its own gutters. Nothing
/// shows, and nothing spins, until the video's detail arrives; then the column fades up into place. A detail that
/// never came leaves 加载失败，点击重试 in the middle instead. Its list scrolls with the page's primary scroll
/// controller and starts [PlayerReserve] below its top. On the iPad its sections are [PadIntroHead]'s.
class IntroTab extends StatelessWidget {
  const IntroTab({
    super.key,
    required this.content,
    required this.details,
    required this.onSeek,
    required this.onOpenVideo,
    required this.onPlayEpisode,
    required this.onOpenEpisodes,
    required this.onOpenRelated,
    required this.onWatchLater,
  });

  final IntroContent content;
  final PageDetails details;
  final ValueChanged<double> onSeek;

  /// A BV or av id from the description.
  final ValueChanged<String> onOpenVideo;
  final ValueChanged<Episode> onPlayEpisode;

  /// The 选集 sheet.
  final VoidCallback onOpenEpisodes;
  final ValueChanged<VideoCard> onOpenRelated;
  final ValueChanged<VideoCard> onWatchLater;

  @override
  Widget build(BuildContext context) {
    final detail = content.detail;
    final bottom = MediaQuery.paddingOf(context).bottom + PageTheme.introBottom;
    return ListenableBuilder(
      listenable: details,
      builder: (context, _) => CustomScrollView(
        key: const PageStorageKey('intro-scroll'),
        primary: true,
        slivers: [
          SliverToBoxAdapter(
            child: Builder(builder: (context) => SizedBox(height: PlayerReserve.of(context))),
          ),
          if (detail != null) ...[
            SliverToBoxAdapter(
              child: _Arrival(
                key: ValueKey(detail.bvid),
                child: FormFactor.of(context).isPad
                    ? PadIntroHead(
                        content: content,
                        details: details,
                        onSeek: onSeek,
                        onOpenVideo: onOpenVideo,
                        onPlayEpisode: onPlayEpisode,
                        onOpenEpisodes: onOpenEpisodes,
                      )
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _sections(detail)),
              ),
            ),
            RelatedSliver(cards: content.related, onOpen: onOpenRelated, onWatchLater: onWatchLater),
          ] else if (content.detailFailed && content.onRetryDetail != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: _RetryLine(onRetry: content.onRetryDetail!)),
            ),
          SliverToBoxAdapter(child: SizedBox(height: bottom)),
        ],
      ),
    );
  }

  List<Widget> _sections(VideoDetail detail) {
    final actions = details.actions;
    final season = detail.season;
    return [
      UploaderRow(detail: detail, card: details.uploader, actions: actions),
      TitleBlock(detail: detail, online: details.online, tags: details.tags, onSeek: onSeek, onOpenVideo: onOpenVideo),
      if (actions != null) ActionRow(actions: actions),
      if (content.episodesAreParts && content.episodes.isNotEmpty)
        PartStrip(parts: content.episodes, onChoose: onPlayEpisode, onOpenList: onOpenEpisodes)
      else if (season != null)
        CollectionRow(title: season.title, episodes: content.episodes, onOpen: onOpenEpisodes),
      TagChips(tags: details.tags),
    ];
  }
}

class _RetryLine extends StatelessWidget {
  const _RetryLine({required this.onRetry});

  final VoidCallback onRetry;

  TextStyle _style(Color color) => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: CommentListTheme.footerText,
    color: color,
    height: CommentListTheme.footerLine / CommentListTheme.footerText,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('intro-retry'),
    button: true,
    label: '加载失败，点击重试',
    onTap: onRetry,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onRetry,
      child: Padding(
        padding: const EdgeInsets.all(CommentListTheme.footerPadding),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '加载失败，', style: _style(CommentListTheme.colorsOf(context).retryInk)),
              TextSpan(text: '点击重试', style: _style(CommentListTheme.colorsOf(context).retryAction)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

/// Fades the column in and lifts it the last few points, once per video, as the official page settles.
class _Arrival extends StatelessWidget {
  const _Arrival({super.key, required this.child});

  final Widget child;

  static const _duration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * PageTheme.introRise), child: child),
      ),
    );
  }
}
