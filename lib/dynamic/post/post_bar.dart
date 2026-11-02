import 'package:bili_core/api.dart' show DynamicAuthor;
import 'package:flutter/widgets.dart';

import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import 'post_author.dart';
import 'post_glyphs.dart';

/// The bar over the post (131, 133, 134): ‹ alone while it loads, then ↗ and ⋮; once [titled], the poster's face and
/// name between them, with [PostBarRule] under the bar.
class PostBar extends StatelessWidget {
  const PostBar({super.key, required this.onBack, this.author, this.titled = false, this.onShare, this.onMore});

  final VoidCallback onBack;

  /// Null while the post loads.
  final DynamicAuthor? author;
  final bool titled;
  final VoidCallback? onShare;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final fade = MediaQuery.disableAnimationsOf(context) ? Duration.zero : DynamicPostTheme.barFade;
    final author = this.author;
    final share = onShare;
    final more = onMore;
    return ColoredBox(
      color: DynamicPostTheme.colorsOf(context).page,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: SizedBox(
          height: DynamicPostTheme.barRow,
          child: Stack(
            children: [
              if (author != null)
                Positioned(
                  left: DynamicPostTheme.titleFaceLeft,
                  right: DynamicPostTheme.titleRight,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      excluding: !titled,
                      child: AnimatedOpacity(
                        key: const ValueKey('post-bar-title'),
                        opacity: titled ? 1 : 0,
                        duration: fade,
                        child: Row(
                          children: [
                            SizedBox.square(
                              dimension: DynamicPostTheme.titleFace,
                              child: ClipOval(child: RemoteImage.avatar(author.face)),
                            ),
                            const SizedBox(width: DynamicPostTheme.titleGap),
                            Flexible(
                              child: postLine(
                                context,
                                author.name,
                                postStyle(DynamicPostTheme.titleText, DynamicPostTheme.colorsOf(context).titleInk),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: DynamicPostTheme.barTarget,
                child: _BarButton(
                  key: const ValueKey('post-back'),
                  label: '返回',
                  onTap: onBack,
                  child: CustomPaint(painter: PostBackPainter(palette: BiliPalette.of(context))),
                ),
              ),
              if (share != null)
                Positioned(
                  right: DynamicPostTheme.shareCentreRight - DynamicPostTheme.barTarget / 2,
                  top: 0,
                  bottom: 0,
                  width: DynamicPostTheme.barTarget,
                  child: _BarButton(
                    key: const ValueKey('post-share'),
                    label: '分享',
                    onTap: share,
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(0, -DynamicPostTheme.shareRise),
                        child: Image.asset(
                          'assets/images/dynamic/dy_ic_arrow_share_line_24.png',
                          width: DynamicPostTheme.shareWidth,
                          color: DynamicPostTheme.colorsOf(context).barInk,
                          filterQuality: FilterQuality.medium,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                ),
              if (more != null)
                Positioned(
                  right: DynamicPostTheme.moreCentreRight - DynamicPostTheme.barTarget / 2,
                  top: 0,
                  bottom: 0,
                  width: DynamicPostTheme.barTarget,
                  child: _BarButton(
                    key: const ValueKey('post-more'),
                    label: '更多',
                    onTap: more,
                    child: CustomPaint(painter: PostMorePainter(palette: BiliPalette.of(context))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar's hairline once [shown] (134): just under the bar, over the top of what scrolls under it, so the page
/// lays it in its Stack.
class PostBarRule extends StatelessWidget {
  const PostBarRule({super.key, required this.shown});

  final bool shown;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedOpacity(
      key: const ValueKey('post-bar-rule'),
      opacity: shown ? 1 : 0,
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : DynamicPostTheme.barFade,
      child: ColoredBox(color: DynamicPostTheme.colorsOf(context).barRule),
    ),
  );
}

class _BarButton extends StatelessWidget {
  const _BarButton({super.key, required this.label, required this.onTap, required this.child});

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.expand(child: child),
    ),
  );
}
