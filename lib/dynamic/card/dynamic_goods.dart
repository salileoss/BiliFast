import 'package:bili_core/api.dart';
import 'package:flutter/widgets.dart';

import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import 'dynamic_open.dart';

/// UP主的推荐 (127, 135): the locked head, then the first item's box with its cover, name, brief and 去看看. Nothing in
/// it is built yet: a tap toasts.
class DynamicGoodsBlock extends StatelessWidget {
  const DynamicGoodsBlock({super.key, required this.goods});

  final DynamicGoods goods;

  @override
  Widget build(BuildContext context) {
    final item = goods.items.first;
    void soon() => showToast(context, notBuilt);
    final head = goods.headText.isEmpty ? 'UP主的推荐' : goods.headText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DynamicCardTheme.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: DynamicCardTheme.goodsHeadTop),
          SizedBox(
            height: DynamicCardTheme.goodsHeadLine,
            child: Row(
              children: [
                const SizedBox(width: DynamicCardTheme.goodsLockLead),
                DynamicIcon(
                  DynamicArt.lock,
                  width: DynamicCardTheme.goodsLockWidth,
                  color: DynamicCardTheme.colorsOf(context).goodsHeadInk,
                ),
                const SizedBox(width: DynamicCardTheme.goodsLockGap),
                Flexible(
                  child: Text(
                    head,
                    key: const ValueKey('dynamic-goods-head'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dynamicStyle(
                      DynamicCardTheme.goodsHeadText,
                      DynamicCardTheme.colorsOf(context).goodsHeadInk,
                      line: DynamicCardTheme.goodsHeadLine,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DynamicCardTheme.goodsBoxGap),
          Semantics(
            container: true,
            button: true,
            label: item.name,
            onTap: soon,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('dynamic-goods'),
              behavior: HitTestBehavior.opaque,
              onTap: soon,
              child: Container(
                height: DynamicCardTheme.goodsBox,
                decoration: BoxDecoration(
                  color: DynamicCardTheme.colorsOf(context).goodsFill,
                  borderRadius: BorderRadius.circular(DynamicCardTheme.goodsRadius),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: DynamicCardTheme.goodsInset,
                      top: DynamicCardTheme.goodsInset,
                      width: DynamicCardTheme.goodsCover,
                      height: DynamicCardTheme.goodsCover,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(DynamicCardTheme.goodsCoverRadius),
                        child: RemoteImage(item.cover),
                      ),
                    ),
                    _line(
                      item.name,
                      centre: DynamicCardTheme.goodsNameCentre,
                      style: dynamicStyle(
                        DynamicCardTheme.goodsNameText,
                        DynamicCardTheme.colorsOf(context).goodsNameInk,
                        line: DynamicCardTheme.goodsNameLine,
                      ),
                    ),
                    if (item.brief.isNotEmpty)
                      _line(
                        item.brief,
                        centre: DynamicCardTheme.goodsBriefCentre,
                        style: dynamicStyle(
                          DynamicCardTheme.goodsBriefText,
                          DynamicCardTheme.colorsOf(context).goodsBriefInk,
                          line: DynamicCardTheme.goodsBriefLine,
                        ),
                      ),
                    Positioned(
                      right: DynamicCardTheme.goodsInset,
                      top: (DynamicCardTheme.goodsBox - DynamicCardTheme.goodsButtonHeight) / 2,
                      width: DynamicCardTheme.goodsButtonWidth,
                      height: DynamicCardTheme.goodsButtonHeight,
                      child: GestureDetector(
                        key: const ValueKey('dynamic-goods-go'),
                        behavior: HitTestBehavior.opaque,
                        onTap: soon,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: DynamicCardTheme.colorsOf(context).goodsButtonFill,
                            borderRadius: BorderRadius.circular(DynamicCardTheme.goodsButtonRadius),
                          ),
                          child: Center(
                            child: Text(
                              item.jumpText.isEmpty ? '去看看' : item.jumpText,
                              maxLines: 1,
                              style: dynamicStyle(
                                DynamicCardTheme.goodsButtonText,
                                DynamicCardTheme.goodsButtonInk,
                              ).copyWith(height: 1),
                            ),
                          ),
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

  Widget _line(String text, {required double centre, required TextStyle style}) {
    final line = style.height! * style.fontSize!;
    return Positioned(
      left: DynamicCardTheme.goodsInset * 2 + DynamicCardTheme.goodsCover,
      right: DynamicCardTheme.goodsInset * 2 + DynamicCardTheme.goodsButtonWidth,
      top: centre - line / 2,
      height: line,
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style, strutStyle: BiliFonts.strut(style)),
    );
  }
}
