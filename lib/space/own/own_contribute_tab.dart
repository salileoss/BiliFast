import 'package:bili_core/api.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../favourites/favourite_rows.dart' show FavTap;
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../space_videos.dart';
import 'own_tab_cards.dart';
import 'own_tab_glyphs.dart';

/// 投稿: the space's video list, or with no videos 108's empty page (发布第一个视频，领新人福利, 我要投稿, 去创作中心领奖).
/// Uploading isn't built, so both of the empty page's buttons say so.
class OwnContributeSliver extends StatelessWidget {
  const OwnContributeSliver({super.key, required this.profile, this.open});

  final SpaceProfile profile;

  /// Tests pass their own; null pushes the video page.
  final OpenSpaceVideo? open;

  /// What the videos and the empty page lie on.
  static const fill = OwnSpaceTabsTheme.whitePage;
  static Color fillOf(BuildContext context) => OwnSpaceTabsTheme.colorsOf(context).whitePage;

  @override
  Widget build(BuildContext context) {
    if (profile.videoCount > 0) {
      return SpaceVideosSliver(profile: profile, api: AppScope.of(context).spaceApi, open: open);
    }
    void soon() => showToast(context, '暂未开放');
    final text = ownStyle(OwnSpaceTabsTheme.emptyText, OwnSpaceTabsTheme.colorsOf(context).emptyInk, line: OwnSpaceTabsTheme.emptyLine);
    final pill = ownStyle(
      OwnSpaceTabsTheme.uploadPillText,
      OwnSpaceTabsTheme.colorsOf(context).uploadPillInk,
      line: OwnSpaceTabsTheme.emptyLine,
    );
    final reward = ownStyle(
      OwnSpaceTabsTheme.rewardText,
      OwnSpaceTabsTheme.colorsOf(context).rewardInk,
      line: OwnSpaceTabsTheme.rewardLine,
    );
    const discTop = OwnSpaceTabsTheme.emptyDiscCentre - OwnSpaceTabsTheme.emptyDisc / 2;
    const textTop = OwnSpaceTabsTheme.emptyTextCentre - OwnSpaceTabsTheme.emptyLine / 2;
    const pillTop = OwnSpaceTabsTheme.uploadPillCentre - OwnSpaceTabsTheme.uploadPillHeight / 2;
    const rewardTop = OwnSpaceTabsTheme.rewardCentre - OwnSpaceTabsTheme.rewardLine / 2;
    return DecoratedSliver(
      decoration: BoxDecoration(color: OwnContributeSliver.fillOf(context)),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              key: const ValueKey('own-contribute-empty'),
              height: rewardTop + OwnSpaceTabsTheme.rewardLine + OwnSpaceTabsTheme.emptyBottom,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: discTop,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: OwnSpaceTabsTheme.colorsOf(context).emptyDiscFill, shape: BoxShape.circle),
                        child: SizedBox.square(
                          dimension: OwnSpaceTabsTheme.emptyDisc,
                          child: Center(child: UploadGlyph()),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: OwnSpaceTabsTheme.gutter,
                    right: OwnSpaceTabsTheme.gutter,
                    top: textTop,
                    child: Text(
                      '发布第一个视频，领新人福利',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: text,
                      strutStyle: BiliFonts.strut(text),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: pillTop,
                    child: Center(
                      child: FavTap(
                        key: const ValueKey('own-contribute-upload'),
                        label: '我要投稿',
                        onTap: soon,
                        child: Container(
                          width: OwnSpaceTabsTheme.uploadPillWidth,
                          height: OwnSpaceTabsTheme.uploadPillHeight,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: OwnSpaceTabsTheme.colorsOf(context).uploadPillInk,
                                width: OwnSpaceTabsTheme.uploadPillRim,
                              ),
                            ),
                          ),
                          child: Text('我要投稿', maxLines: 1, style: pill, strutStyle: BiliFonts.strut(pill)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: rewardTop,
                    height: OwnSpaceTabsTheme.rewardLine,
                    child: Center(
                      child: FavTap(
                        key: const ValueKey('own-contribute-reward'),
                        label: '去创作中心领奖',
                        onTap: soon,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('去创作中心领奖', maxLines: 1, style: reward, strutStyle: BiliFonts.strut(reward)),
                            const SizedBox(width: OwnSpaceTabsTheme.rewardChevronGap),
                            OwnChevron(color: OwnSpaceTabsTheme.colorsOf(context).rewardInk),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
          const SliverFillRemaining(hasScrollBody: false, child: SizedBox.shrink()),
        ],
      ),
    );
  }
}
