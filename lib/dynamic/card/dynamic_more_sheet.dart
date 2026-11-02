import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../app/app_environment.dart';
import '../../app/app_scope.dart';
import '../../shared/menu.dart' show PressHighlight;
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../../video/actions/actions_model.dart' show ActionsModel;
import 'dynamic_open.dart';

enum _MoreChoice { share, unfollow, report }

/// ⋮ on a card (137): 分享, then 取消关注 and 举报 (which toasts) when [DynamicItem.menu] offers them, and 取消.
Future<void> showDynamicMoreSheet(BuildContext context, DynamicItem item) async {
  final choice = await Navigator.of(context)
      .push(_MoreSheetRoute(item: item, reduceMotion: MediaQuery.disableAnimationsOf(context)));
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _MoreChoice.share:
      try {
        await DynamicOpen.share(item.shareLink);
      } catch (error) {
        Logger.shared.warn(LogCategory.ui, 'dynamic share failed', {'error': '${error.runtimeType}'});
        if (context.mounted) showToast(context, '分享失败');
      }
    case _MoreChoice.unfollow:
      await _unfollow(context, item.author.mid);
    case _MoreChoice.report:
      showToast(context, notBuilt);
  }
}

Future<void> _unfollow(BuildContext context, int mid) async {
  final services = AppScope.of(context);
  if (services.environment.account case LoggedOut() || LoginExpired()) {
    await services.loginGate.request(context);
    return;
  }
  try {
    await services.dynamicApi.unfollow(mid);
    services.follows.changed(mid, following: false);
    if (context.mounted) showToast(context, '取消关注成功');
  } catch (error) {
    Logger.shared.warn(LogCategory.api, 'dynamic unfollow failed', {'error': '${error.runtimeType}'});
    if (!context.mounted) return;
    if (error is BiliError && error.needsLogin) {
      await services.loginGate.request(context);
    } else {
      showToast(context, ActionsModel.failureMessage(error));
    }
  }
}

class _MoreSheetRoute extends PopupRoute<_MoreChoice> {
  _MoreSheetRoute({required this.item, required this.reduceMotion});

  final DynamicItem item;
  final bool reduceMotion;

  @override
  Color? get barrierColor => DynamicCardTheme.sheetDim;

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => '关闭';

  @override
  Duration get transitionDuration => reduceMotion ? Duration.zero : DynamicCardTheme.sheetIn;

  @override
  Duration get reverseTransitionDuration => reduceMotion ? Duration.zero : DynamicCardTheme.sheetOut;

  CurvedAnimation? _curve;

  @override
  Animation<double> createAnimation() => _curve = CurvedAnimation(
    parent: super.createAnimation(),
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void dispose() {
    _curve?.dispose();
    super.dispose();
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    void pick(_MoreChoice choice) => Navigator.of(context).pop(choice);
    final rows = [
      (
        choice: _MoreChoice.share,
        label: '分享',
        asset: DynamicArt.share,
        width: DynamicCardTheme.sheetShareWidth,
        centre: DynamicCardTheme.sheetShareCentre,
        rise: DynamicCardTheme.sheetShareRise,
      ),
      if (item.menu.contains(DynamicMenuItem.unfollow))
        (
          choice: _MoreChoice.unfollow,
          label: '取消关注',
          asset: DynamicArt.unfollow,
          width: DynamicCardTheme.sheetUnfollowWidth,
          centre: DynamicCardTheme.sheetUnfollowCentre,
          rise: DynamicCardTheme.sheetUnfollowRise,
        ),
      if (item.menu.contains(DynamicMenuItem.report))
        (
          choice: _MoreChoice.report,
          label: '举报',
          asset: DynamicArt.report,
          width: DynamicCardTheme.sheetReportWidth,
          centre: DynamicCardTheme.sheetReportCentre,
          rise: DynamicCardTheme.sheetReportRise,
        ),
    ];
    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
        // The route sits outside the page's Material, whose text style the rows would otherwise miss.
        child: Material(
          type: MaterialType.transparency,
          child: ColoredBox(
            key: const ValueKey('dynamic-more-sheet'),
            color: DynamicCardTheme.colorsOf(context).sheetFill,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, row) in rows.indexed)
                  _Row(
                    key: ValueKey('dynamic-more-${row.choice.name}'),
                    label: row.label,
                    asset: row.asset,
                    iconWidth: row.width,
                    iconCentre: row.centre,
                    iconRise: row.rise,
                    hairline: index < rows.length - 1,
                    onTap: () => pick(row.choice),
                  ),
                SizedBox(
                  height: DynamicCardTheme.sheetGap,
                  child: ColoredBox(color: DynamicCardTheme.colorsOf(context).sheetGapFill),
                ),
                Semantics(
                  container: true,
                  button: true,
                  label: '取消',
                  onTap: () => Navigator.of(context).pop(),
                  excludeSemantics: true,
                  child: PressHighlight(
                    key: const ValueKey('dynamic-more-cancel'),
                    onTap: () => Navigator.of(context).pop(),
                    child: SizedBox(
                      height: DynamicCardTheme.sheetRow + bottom,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottom),
                        child: Center(
                          child: Text(
                            '取消',
                            style: dynamicStyle(
                              DynamicCardTheme.sheetCancelText,
                              DynamicCardTheme.colorsOf(context).sheetCancelInk,
                            ).copyWith(height: 1),
                          ),
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
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// A 50 pt row: its pink icon centred about 31 in, its words from 58; the hairline under it from 20 in.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.label,
    required this.asset,
    required this.iconWidth,
    required this.iconCentre,
    required this.iconRise,
    required this.hairline,
    required this.onTap,
  });

  final String label;
  final String asset;
  final double iconWidth;
  final double iconCentre;
  final double iconRise;
  final bool hairline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: PressHighlight(
      onTap: onTap,
      child: SizedBox(
        height: DynamicCardTheme.sheetRow,
        child: Stack(
          children: [
            Positioned(
              left: iconCentre - DynamicCardTheme.sheetRow / 2,
              top: 0,
              bottom: 0,
              width: DynamicCardTheme.sheetRow,
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, -iconRise),
                  child: DynamicIcon(asset, width: iconWidth, color: DynamicCardTheme.colorsOf(context).sheetIconInk),
                ),
              ),
            ),
            Positioned(
              left: DynamicCardTheme.sheetTextLeft,
              right: 0,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  style: dynamicStyle(DynamicCardTheme.sheetText, DynamicCardTheme.colorsOf(context).sheetInk).copyWith(height: 1),
                ),
              ),
            ),
            if (hairline)
              Positioned(
                left: DynamicCardTheme.sheetHairlineLeft,
                right: 0,
                bottom: 0,
                height: DynamicCardTheme.sheetHairline,
                child: ColoredBox(color: DynamicCardTheme.colorsOf(context).sheetHairlineInk),
              ),
          ],
        ),
      ),
    ),
  );
}
