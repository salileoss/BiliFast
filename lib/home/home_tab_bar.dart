import 'dart:io';

import 'package:flutter/widgets.dart';

import '../app/form_factor.dart';
import '../shared/theme.dart';
import '../skin/skin.dart';
import 'tab_bar_icons.dart';

/// The bottom bar's five places (01, 02).
enum HomeTab {
  home('首页', 0),
  follow('关注', 1),
  post('发布'),
  messages('消息', 3),
  mine('我的', 4);

  const HomeTab(this.label, [this.skinIcon]);

  final String label;

  /// Which of a 装扮's five icons (main, channel, dynamic, shop, myself) is this place's. The official app drops the
  /// middle one (dynamic) when it has fewer places, so 关注 takes channel and 消息 shop.
  final int? skinIcon;
}

/// The iPad's four places (ipad/01, 02), in the 装扮's own order: 动态 is the phone's 关注 place, and 分区 has no place
/// of its own yet.
enum PadTab {
  home(HomeTab.home, '首页', 0, 'home', 20),
  partition(null, '分区', 1, 'partition', 21),
  moments(HomeTab.follow, '动态', 2, 'moments', 21),
  mine(HomeTab.mine, '我的', 4, 'mine', 21);

  const PadTab(this.place, this.label, this.skinIcon, this._art, this.iconWidth);

  final HomeTab? place;
  final String label;
  final int skinIcon;
  final String _art;

  /// The icon's ink width on 01; its height follows the picture.
  final double iconWidth;

  /// The APK's tab bar icon; 首页 and 我的 change face when selected.
  String art({required bool selected}) {
    final selectedArt = selected && (this == home || this == mine);
    return 'assets/images/home/pad_tab_$_art${selectedArt ? '_selected' : ''}.png';
  }

  /// The key the phone's bar gives the same place, so a place is found the same way on both.
  String get key => place?.name ?? name;
}

/// One place on the bar as drawn: its key, label, 装扮 icon and stock icon.
typedef _Place = ({
  String key,
  String label,
  int? skinIcon,
  bool post,
  bool selected,
  Widget Function(bool selected) icon,
  VoidCallback onTap,
});

/// What differs between the phone's bar and the iPad's.
typedef _Shape = ({
  double height,
  double iconCentre,
  double labelTop,
  double labelText,
  double? slot,
  double? artWidth,
  double hairline,
  Color label,
  Color selected,
});

/// The bottom bar under 首页 and 我的 (01, 02): 首页, 关注, the pink +, 消息 and 我的 over the home indicator, [selected]
/// pink; on the iPad 首页, 分区, 动态 and 我的, centred (ipad/01, 02). A [skin] that [dresses] it draws its picture,
/// icons and label colours instead (109, 110), once its still pictures have decoded; until then, or for good when
/// one won't, the bar stays stock.
class HomeTabBar extends StatelessWidget {
  const HomeTabBar({super.key, required this.selected, required this.onTap, this.onPartition, this.skin});

  final HomeTab selected;
  final ValueChanged<HomeTab> onTap;

  /// The iPad's 分区.
  final VoidCallback? onPartition;

  /// The equipped 装扮; null, or one [dresses] refuses, leaves it stock.
  final Skin? skin;

  /// Whether [skin] dresses the bar: its picture, both label colours and all five icons each way. Without any of
  /// them the bar stays stock.
  static bool dresses(Skin? skin) => skin != null && skin.themesBar;

  /// The bar's height over the home indicator, the hairline included.
  static double heightOf(BuildContext context) =>
      FormFactor.of(context).isPad ? PadHomeTheme.barHeight : HomeTabBarTheme.height;

  static _Shape _phone(BuildContext context) => (
    height: HomeTabBarTheme.height,
    iconCentre: HomeTabBarTheme.iconCentre,
    labelTop: HomeTabBarTheme.labelTop,
    labelText: HomeTabBarTheme.labelText,
    slot: null,
    artWidth: null,
    hairline: HomeTabBarTheme.hairlineWidth,
    label: HomeTabBarTheme.colorsOf(context).label,
    selected: HomeTabBarTheme.colorsOf(context).selected,
  );

  static _Shape _pad(BuildContext context) => (
    height: PadHomeTheme.barHeight,
    iconCentre: PadHomeTheme.barIconCentre,
    labelTop: PadHomeTheme.barLabelTop,
    labelText: PadHomeTheme.barLabelText,
    slot: PadHomeTheme.barSlot,
    artWidth: PadHomeTheme.barArtWidth,
    hairline: PadHomeTheme.hairline,
    label: PadHomeTheme.colorsOf(context).barLabelInk,
    selected: PadHomeTheme.colorsOf(context).pink,
  );

  List<_Place> _places(bool pad) => pad
      ? [
          for (final tab in PadTab.values)
            (
              key: 'home-tab-${tab.key}',
              label: tab.label,
              skinIcon: tab.skinIcon,
              post: false,
              selected: tab.place == selected,
              icon: (selected) => PadTabIcon(tab, selected: selected),
              onTap: () => tab.place == null ? onPartition?.call() : onTap(tab.place!),
            ),
        ]
      : [
          for (final tab in HomeTab.values)
            (
              key: 'home-tab-${tab.name}',
              label: tab.label,
              skinIcon: tab.skinIcon,
              post: tab == HomeTab.post,
              selected: tab == selected,
              icon: (selected) => HomeTabIcon(tab, selected: selected),
              onTap: () => onTap(tab),
            ),
        ];

  /// The still pictures a dressed bar draws. Animated icons wait on their own decode, over a still fallback.
  static List<File> _stills(Skin skin, List<_Place> places) => [
    skin.tailBg!,
    for (final icon in [
      for (final place in places)
        if (place.skinIcon case final index?) ...[skin.tailIcons[index], skin.tailIconsSelected[index]],
      if (places.any((place) => place.post)) ?skin.pubButton,
    ])
      if (!icon.animated) icon.file,
  ];

  @override
  Widget build(BuildContext context) {
    final skin = dresses(this.skin) ? this.skin : null;
    final pad = FormFactor.of(context).isPad;
    final places = _places(pad);
    final shape = pad ? _pad(context) : _phone(context);
    return SkinDecodeGate(
      pictures: skin == null ? const [] : _stills(skin, places),
      builder: (context, decoded) =>
          skin != null && decoded ? _dressed(context, skin, places, shape) : _stock(context, places, shape),
    );
  }

  /// The phone's places share the width; the iPad's keep their own width, centred.
  static Widget _slots(_Shape shape, List<Widget> children) {
    final slot = shape.slot;
    if (slot == null) return Row(children: [for (final child in children) Expanded(child: child)]);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [for (final child in children) SizedBox(width: slot, child: child)],
    );
  }

  Widget _row(BuildContext context, Skin? skin, List<_Place> places, _Shape shape) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
    child: SizedBox(
      height: shape.height,
      child: _slots(shape, [
        for (final place in places) _Slot(place: place, shape: shape, skin: skin),
      ]),
    ),
  );

  static BoxDecoration _stockFill(BuildContext context, _Shape shape) => BoxDecoration(
    color: HomeTabBarTheme.colorsOf(context).bar,
    border: Border(
      top: BorderSide(color: HomeTabBarTheme.colorsOf(context).hairline, width: shape.hairline),
    ),
  );

  Widget _stock(BuildContext context, List<_Place> places, _Shape shape) =>
      DecoratedBox(decoration: _stockFill(context, shape), child: _row(context, null, places, shape));

  /// The picture's own shape sets how far it rises over the row; one too flat to reach the row's top is cropped at
  /// the sides to cover it. Above the row the bar takes taps only over the icons' tops: the rest of a rising picture
  /// leaves them to the page under it. The iPad draws it at [_Shape.artWidth], centred over the stock bar: the
  /// picture is made for a phone's width, and at the iPad's whole width it rose over a third of the screen.
  Widget _dressed(BuildContext context, Skin skin, List<_Place> places, _Shape shape) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final artWidth = shape.artWidth;
    final art = ConstrainedBox(
      key: const ValueKey('home-tab-art'),
      constraints: BoxConstraints(minHeight: shape.height + bottom),
      child: SkinDecodeGate.image(skin.tailBg!, alignment: Alignment.bottomCenter),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: HomeTabBarTheme.skinIconOverhang,
          child: _slots(shape, [
            for (final place in places)
              place.skinIcon == null
                  ? const SizedBox.shrink()
                  : Center(
                      child: GestureDetector(
                        key: ValueKey('${place.key}-rise'),
                        behavior: HitTestBehavior.opaque,
                        excludeFromSemantics: true,
                        onTap: place.onTap,
                        child: const SizedBox(
                          width: HomeTabBarTheme.skinIconWidth,
                          height: HomeTabBarTheme.skinIconOverhang,
                        ),
                      ),
                    ),
          ]),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            if (artWidth != null) Positioned.fill(child: DecoratedBox(decoration: _stockFill(context, shape))),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: artWidth == null
                  ? art
                  : Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(width: artWidth, child: art),
                    ),
            ),
            _row(context, skin, places, shape),
          ],
        ),
      ],
    );
  }
}

/// A glyph over its label, or the + alone, centred in the bar. Dressed, the 装扮's picture rises over the bar's top.
class _Slot extends StatelessWidget {
  const _Slot({required this.place, required this.shape, this.skin});

  final _Place place;
  final _Shape shape;
  final Skin? skin;

  @override
  Widget build(BuildContext context) {
    final post = place.post;
    final selected = place.selected;
    final centre = post ? HomeTabBarTheme.postCentre : shape.iconCentre;
    final skin = this.skin;
    final pub = skin?.pubButton;
    final labelColour = skin == null
        ? (selected ? shape.selected : shape.label)
        : (selected ? skin.tailColorSelected! : skin.tailColor!);
    return Semantics(
      button: true,
      selected: selected,
      label: place.label,
      child: GestureDetector(
        key: ValueKey(place.key),
        behavior: HitTestBehavior.opaque,
        onTap: place.onTap,
        child: ExcludeSemantics(
          child: Stack(
            clipBehavior: skin == null ? Clip.hardEdge : Clip.none,
            children: [
              if (skin == null || (post && pub == null))
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: centre * 2,
                  child: Center(child: place.icon(selected)),
                )
              else if (pub != null && post)
                _box(
                  centre: HomeTabBarTheme.skinPostCentre,
                  width: HomeTabBarTheme.skinPostSize,
                  height: HomeTabBarTheme.skinPostSize,
                  child: SkinPicture(pub),
                )
              else if (place.skinIcon case final index?)
                _box(
                  centre: HomeTabBarTheme.skinIconCentre,
                  width: HomeTabBarTheme.skinIconWidth,
                  height: HomeTabBarTheme.skinIconHeight,
                  child: SkinTabIcon(
                    icon: skin.tailIcons[index],
                    selectedIcon: skin.tailIconsSelected[index],
                    selected: selected,
                    loop: skin.equip.colors.tailIconCycle,
                    rise: skin.equip.colors.tailIconAnimated,
                  ),
                ),
              if (!post)
                Positioned(
                  top: shape.labelTop,
                  left: 0,
                  right: 0,
                  child: Text(
                    place.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(fontSize: shape.labelText, color: labelColour),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// A dressed picture's box, centred on the slot's column [centre] pt under the bar's top.
  Widget _box({required double centre, required double width, required double height, required Widget child}) =>
      Positioned(
        key: ValueKey('${place.key}-skin'),
        top: centre - height / 2,
        left: 0,
        right: 0,
        height: height,
        child: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      );
}
