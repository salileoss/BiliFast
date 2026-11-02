import 'dart:async';

import 'package:bili_core/api.dart' show FavFolder;
import 'package:bili_core/devlog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' show InputBorder, InputDecoration, Material, MaterialType, TextField, Theme;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app/swipe_back_route.dart';
import '../comments/composer_model.dart' show PickedPicture;
import '../comments/picture_attach.dart' show PickFailure, withoutLocation;
import '../history/history_glyphs.dart' show HistoryBackPainter;
import '../home/feed_model.dart' show requestFailureMessage;
import '../shared/menu.dart' show PressHighlight;
import '../shared/theme.dart';
import '../shared/toast.dart';
import 'favourite_rows.dart';
import 'favourites_glyphs.dart';

/// Makes the folder; [cover] is an address [UploadCover] gave, empty for none.
typedef CreateFolder = Future<FavFolder> Function({
  required String title,
  required String intro,
  required bool isPrivate,
  String cover,
});

/// Uploads 封面's picture and answers its address.
typedef UploadCover = Future<String> Function({required List<int> bytes, required String filename});

/// What 封面's picker brought back: a picture, nothing after a cancel, or why it failed.
typedef CoverPick = ({PickedPicture? picture, PickFailure? failure});

typedef PickCover = Future<CoverPick> Function(ImageSource source);

/// 我的收藏's + and 新建收藏夹, and 稍后再看's folder sheet: completes with the folder made, or null. Without
/// [uploadCover], 封面 says 暂未开放.
Future<FavFolder?> openNewFolder(BuildContext context, {required CreateFolder create, UploadCover? uploadCover}) =>
    Navigator.of(context).push<FavFolder>(
      SwipeBackPageRoute(
        builder: (_) => NewFolderPage(create: create, uploadCover: uploadCover),
      ),
    );

/// 封面's picture from the library or the camera, without asking for library access.
Future<CoverPick> pickFolderCover(ImageSource source, {ImagePicker? picker}) async {
  final XFile? file;
  try {
    file = await (picker ?? ImagePicker()).pickImage(
      source: source,
      requestFullMetadata: false,
      // A cover is shown small; a phone photo at full size runs past 10 MB.
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );
  } catch (error) {
    Logger.shared.warn(LogCategory.ui, 'pick cover failed', {'error': '$error'});
    return (picture: null, failure: _accessDenied(error) ? PickFailure.noAccess : PickFailure.failed);
  }
  if (file == null) return (picture: null, failure: null);
  try {
    final bytes = await file.readAsBytes();
    // The upload names the picture's type by its extension; image_picker re-encodes to JPEG.
    final name = file.name.contains('.') ? file.name : 'cover.jpg';
    return (picture: PickedPicture(bytes: withoutLocation(bytes), name: name), failure: null);
  } catch (error) {
    Logger.shared.warn(LogCategory.ui, 'read cover failed', {'error': '${error.runtimeType}'});
    return (picture: null, failure: PickFailure.failed);
  }
}

bool _accessDenied(Object error) =>
    error is PlatformException &&
    const {
      'photo_access_denied',
      'photo_access_restricted',
      'camera_access_denied',
      'camera_access_restricted',
    }.contains(error.code);

/// 创建 (100): 封面, 名称 (required), 简介 and 公开; 完成 creates the folder and pops with it. 封面 opens 101's sheet,
/// and the picture uploads as soon as it is picked; 完成 waits for it.
class NewFolderPage extends StatefulWidget {
  const NewFolderPage({super.key, required this.create, this.uploadCover, this.pickCover = pickFolderCover});

  final CreateFolder create;
  final UploadCover? uploadCover;

  /// [pickFolderCover] unless a test hands in its own.
  final PickCover pickCover;

  @override
  State<NewFolderPage> createState() => _NewFolderPageState();
}

class _NewFolderPageState extends State<NewFolderPage> {
  final _title = TextEditingController();
  final _intro = TextEditingController();
  final _sheet = ValueNotifier<bool>(false);
  var _public = true;
  var _creating = false;

  Uint8List? _coverBytes;
  var _coverUrl = '';
  var _uploading = false;
  Future<bool>? _upload;

  /// Bumped by each pick, so an upload a newer pick replaced cannot set the cover.
  var _pick = 0;

  @override
  void dispose() {
    _title.dispose();
    _intro.dispose();
    _sheet.dispose();
    super.dispose();
  }

  bool get _ready => _title.text.trim().isNotEmpty && !_creating;

  void _closeKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  void _openSheet() {
    if (_creating) return;
    if (widget.uploadCover == null) {
      showToast(context, '暂未开放');
      return;
    }
    _closeKeyboard();
    _sheet.value = true;
  }

  Future<void> _choose(ImageSource source) async {
    _sheet.value = false;
    if (source == ImageSource.camera && defaultTargetPlatform == TargetPlatform.windows) {
      showToast(context, '暂未开放');
      return;
    }
    final picked = await widget.pickCover(source);
    if (!mounted) return;
    switch (picked.failure) {
      case PickFailure.noAccess:
        showToast(context, source == ImageSource.camera ? '无法访问相机，请在设置中允许BiliFast访问相机' : '无法访问照片，请在设置中允许BiliFast访问照片');
      case PickFailure.failed:
        showToast(context, '图片读取失败，请重试');
      case null:
    }
    final picture = picked.picture;
    if (picture == null) return;
    final pick = ++_pick;
    setState(() {
      _coverBytes = picture.bytes;
      _coverUrl = '';
      _uploading = true;
    });
    _upload = _send(picture, pick);
  }

  /// True once the cover is up; a failure says why and leaves 封面 empty.
  Future<bool> _send(PickedPicture picture, int pick) async {
    try {
      final url = await widget.uploadCover!(bytes: picture.bytes, filename: picture.name);
      if (!mounted || pick != _pick) return false;
      setState(() {
        _coverUrl = url;
        _uploading = false;
      });
      return true;
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'favourites cover upload failed', {'error': '$error'});
      if (!mounted || pick != _pick) return false;
      setState(() {
        _coverBytes = null;
        _uploading = false;
      });
      showToast(context, requestFailureMessage(error, fallback: '封面上传失败，请重试'));
      return false;
    }
  }

  Future<void> _done() async {
    if (!_ready) return;
    _closeKeyboard();
    setState(() => _creating = true);
    final upload = _upload;
    if (_uploading && upload != null && !await upload) {
      if (mounted) setState(() => _creating = false);
      return;
    }
    if (!mounted) return;
    try {
      final folder = await widget.create(
        title: _title.text.trim(),
        intro: _intro.text.trim(),
        isPrivate: !_public,
        cover: _coverUrl,
      );
      if (mounted) Navigator.of(context).pop(folder);
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'favourites create folder failed', {'error': '$error'});
      if (!mounted) return;
      setState(() => _creating = false);
      showToast(context, requestFailureMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ValueListenableBuilder<bool>(
      valueListenable: _sheet,
      builder: (context, open, page) => PopScope<Object?>(
        canPop: !open,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _sheet.value = false;
        },
        child: page!,
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: BiliPalette.of(context).isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle(
            style: favStyle(FavouritesTheme.formText, FavouritesTheme.colorsOf(context).formInk),
            child: ColoredBox(
              color: FavouritesTheme.colorsOf(context).newPage,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _closeKeyboard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ColoredBox(
                          color: FavouritesTheme.colorsOf(context).newGroupFill,
                          child: Padding(
                            padding: EdgeInsets.only(top: top),
                            child: _bar(),
                          ),
                        ),
                        const SizedBox(height: FavouritesTheme.newGroupGap),
                        _coverRow(),
                        const SizedBox(height: FavouritesTheme.newGroupGap),
                        _titleRow(),
                        const SizedBox(height: FavouritesTheme.newIntroGap),
                        _introGroup(),
                        const SizedBox(height: FavouritesTheme.newGroupGap),
                        _publicRow(),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: _CoverSheet(open: _sheet, onChoose: (source) => unawaited(_choose(source))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar() {
    final title = favStyle(
      FavouritesTheme.newTitleText,
      FavouritesTheme.colorsOf(context).formInk,
      line: FavouritesTheme.newTitleLine,
      weight: FavouritesTheme.newTitleWeight,
    );
    return SizedBox(
      height: FavouritesTheme.barHeight,
      child: Stack(
        children: [
          Positioned(
            left: FavouritesTheme.backTipX + FavouritesTheme.backWidth / 2 - FavouritesTheme.backTarget / 2,
            top: 0,
            bottom: 0,
            width: FavouritesTheme.backTarget,
            child: FavTap(
              key: const ValueKey('fav-new-back'),
              label: '返回',
              onTap: () => unawaited(Navigator.of(context).maybePop()),
              child: const CustomPaint(painter: HistoryBackPainter()),
            ),
          ),
          Center(
            child: Semantics(
              header: true,
              child: _lifted(Text('创建', style: title, strutStyle: BiliFonts.strut(title))),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: ListenableBuilder(
              listenable: _title,
              builder: (context, _) {
                final ready = _ready;
                final style = favStyle(
                  FavouritesTheme.newDoneText,
                  ready ? FavouritesTheme.colorsOf(context).newDoneInk : FavouritesTheme.colorsOf(context).newDoneOffInk,
                  line: FavouritesTheme.newTitleLine,
                );
                return Semantics(
                  button: true,
                  enabled: ready,
                  label: '完成',
                  onTap: ready ? () => unawaited(_done()) : null,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: const ValueKey('fav-new-done'),
                    behavior: HitTestBehavior.opaque,
                    onTap: ready ? () => unawaited(_done()) : null,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: FavouritesTheme.newDoneTarget),
                      padding: const EdgeInsets.only(right: FavouritesTheme.newDoneRight),
                      alignment: Alignment.centerRight,
                      child: _lifted(Text('完成', style: style, strutStyle: BiliFonts.strut(style))),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    final style = favStyle(FavouritesTheme.formText, FavouritesTheme.colorsOf(context).formInk, line: FavouritesTheme.formLine);
    return _lifted(
      Text.rich(
        TextSpan(
          children: [
            if (required)
              TextSpan(
                text: '*',
                style: style.copyWith(color: FavouritesTheme.newRequiredInk),
              ),
            TextSpan(text: text),
          ],
        ),
        style: style,
        strutStyle: BiliFonts.strut(style),
      ),
    );
  }

  static Widget _lifted(Widget child) =>
      Transform.translate(offset: const Offset(0, -FavouritesTheme.formTextLift), child: child);

  Widget _field({
    required String key,
    required TextEditingController controller,
    required String hint,
    required int max,
    bool multiline = false,
  }) {
    final style = favStyle(FavouritesTheme.formText, FavouritesTheme.colorsOf(context).formInk, line: FavouritesTheme.formLine);
    // A TextField's text starts from the theme's bodyLarge, not the inherited style.
    final strut = BiliFonts.strut(Theme.of(context).textTheme.bodyLarge?.merge(style) ?? style);
    return TextField(
      keyboardAppearance: BiliPalette.of(context).brightness,
      key: ValueKey(key),
      controller: controller,
      inputFormatters: [LengthLimitingTextInputFormatter(max)],
      maxLines: multiline ? null : 1,
      expands: multiline,
      textAlignVertical: multiline ? TextAlignVertical.top : TextAlignVertical.center,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      textInputAction: multiline ? TextInputAction.newline : TextInputAction.done,
      cursorColor: BiliColors.colorsOf(context).pink,
      style: style,
      strutStyle: strut,
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: favStyle(FavouritesTheme.formText, FavouritesTheme.colorsOf(context).newHintInk, line: FavouritesTheme.formLine),
      ),
    );
  }

  Widget _coverRow() {
    final bytes = _coverBytes;
    const chevronLeft = FavouritesTheme.chevronRight + FavouritesTheme.chevronWidth;
    return Semantics(
      button: true,
      label: _coverUrl.isEmpty ? '封面' : '封面，已选择',
      onTap: _openSheet,
      excludeSemantics: true,
      child: PressHighlight(
        key: const ValueKey('fav-new-cover'),
        onTap: _openSheet,
        child: SizedBox(
          height: FavouritesTheme.newCoverHeight,
          child: ColoredBox(
            color: FavouritesTheme.colorsOf(context).newGroupFill,
            child: Stack(
              children: [
                Positioned(
                  left: FavouritesTheme.newLabelLeft,
                  top: 0,
                  bottom: 0,
                  child: Center(widthFactor: 1, child: _label('封面')),
                ),
                if (bytes != null)
                  Positioned(
                    right: chevronLeft + FavouritesTheme.newThumbGap,
                    top: (FavouritesTheme.newCoverHeight - FavouritesTheme.newThumbHeight) / 2,
                    width: FavouritesTheme.newThumbWidth,
                    height: FavouritesTheme.newThumbHeight,
                    child: _Thumbnail(key: const ValueKey('fav-new-cover-thumb'), bytes: bytes, busy: _uploading),
                  ),
                Positioned(
                  right: FavouritesTheme.chevronRight,
                  top: (FavouritesTheme.newCoverHeight - FavouritesTheme.chevronHeight) / 2,
                  child: FavGlyphIcon(
                    FavGlyph.chevron,
                    width: FavouritesTheme.chevronWidth,
                    height: FavouritesTheme.chevronHeight,
                    color: FavouritesTheme.colorsOf(context).newChevronInk,
                    stroke: FavouritesTheme.chevronStroke,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleRow() => ColoredBox(
    color: FavouritesTheme.colorsOf(context).newGroupFill,
    child: SizedBox(
      height: FavouritesTheme.newRowHeight,
      child: Row(
        children: [
          SizedBox(
            width: FavouritesTheme.newFieldLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: FavouritesTheme.newLabelLeft),
              child: _label('名称', required: true),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: FavouritesTheme.newFieldRight),
              child: _lifted(
                _field(key: 'fav-new-title', controller: _title, hint: '名称', max: FavouritesTheme.newTitleMax),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _introGroup() => ColoredBox(
    color: FavouritesTheme.colorsOf(context).newGroupFill,
    child: SizedBox(
      height: FavouritesTheme.newIntroHeight,
      child: Stack(
        children: [
          Positioned(
            left: FavouritesTheme.newLabelLeft,
            top: FavouritesTheme.newIntroLabelCentre - FavouritesTheme.formLine / 2,
            child: _label('简介'),
          ),
          Positioned(
            left: FavouritesTheme.newFieldLeft,
            right: FavouritesTheme.newFieldRight,
            top: FavouritesTheme.newIntroFieldCentre - FavouritesTheme.formLine / 2 - FavouritesTheme.formTextLift,
            bottom: FavouritesTheme.newIntroBottom,
            child: _field(
              key: 'fav-new-intro',
              controller: _intro,
              hint: '可填写简介',
              max: FavouritesTheme.newIntroMax,
              multiline: true,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _publicRow() => ColoredBox(
    color: FavouritesTheme.colorsOf(context).newGroupFill,
    child: SizedBox(
      height: FavouritesTheme.newRowHeight,
      child: Row(
        children: [
          const SizedBox(width: FavouritesTheme.newLabelLeft),
          Expanded(child: _label('公开')),
          MergeSemantics(
            child: Semantics(
              label: '公开',
              child: CupertinoSwitch(
                key: const ValueKey('fav-new-public'),
                value: _public,
                activeTrackColor: FavouritesTheme.colorsOf(context).newSwitchOn,
                onChanged: (on) => setState(() => _public = on),
              ),
            ),
          ),
          const SizedBox(width: FavouritesTheme.newSwitchRight),
        ],
      ),
    ),
  );
}

/// The picked cover, faded under a spinner while it uploads.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({super.key, required this.bytes, required this.busy});

  final Uint8List bytes;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    // Twice the width it's shown at is plenty; a photo decoded whole would cost tens of MB.
    final pixels = (2 * FavouritesTheme.newThumbWidth * MediaQuery.devicePixelRatioOf(context)).ceil();
    return ClipRRect(
      borderRadius: BorderRadius.circular(FavouritesTheme.newThumbRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            bytes,
            fit: BoxFit.cover,
            cacheWidth: pixels,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stack) => ColoredBox(color: FavouritesTheme.colorsOf(context).tileEmpty),
          ),
          if (busy)
            const ColoredBox(
              color: FavouritesTheme.newThumbBusy,
              child: CupertinoActivityIndicator(radius: FavouritesTheme.spinnerRadius),
            ),
        ],
      ),
    );
  }
}

/// 101: 从相册选择 and 拍照, then 取消, over the dimmed page. An in-page layer: [open] shows it, and 取消, a tap on the
/// dim or back close it.
class _CoverSheet extends StatefulWidget {
  const _CoverSheet({required this.open, required this.onChoose});

  final ValueNotifier<bool> open;
  final ValueChanged<ImageSource> onChoose;

  @override
  State<_CoverSheet> createState() => _CoverSheetState();
}

class _CoverSheetState extends State<_CoverSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: FavouritesTheme.sheetIn,
    reverseDuration: FavouritesTheme.sheetOut,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    widget.open.addListener(_changed);
    _motion.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !widget.open.value && mounted) setState(() => _shown = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    _motion
      ..duration = still ? Duration.zero : FavouritesTheme.sheetIn
      ..reverseDuration = still ? Duration.zero : FavouritesTheme.sheetOut;
  }

  @override
  void dispose() {
    widget.open.removeListener(_changed);
    _curve.dispose();
    _motion.dispose();
    super.dispose();
  }

  void _changed() {
    if (!widget.open.value) {
      if (_shown) _motion.reverse();
      return;
    }
    setState(() => _shown = true);
    _motion.forward();
  }

  void _close() => widget.open.value = false;

  @override
  Widget build(BuildContext context) {
    if (!_shown) return const SizedBox.shrink();
    final open = widget.open.value;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return IgnorePointer(
      ignoring: !open,
      child: ExcludeSemantics(
        excluding: !open,
        child: BlockSemantics(
          blocking: open,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('fav-new-cover-dim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: FadeTransition(
                    opacity: _curve,
                    child: const ColoredBox(color: FavouritesTheme.coverSheetDim),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(_curve),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      FavouritesTheme.coverSheetMargin,
                      0,
                      FavouritesTheme.coverSheetMargin,
                      bottom > FavouritesTheme.coverSheetMargin ? bottom : FavouritesTheme.coverSheetMargin,
                    ),
                    child: Column(
                      key: const ValueKey('fav-new-cover-sheet'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _group(FavouritesTheme.colorsOf(context).coverSheetFill, [
                          _button('fav-new-cover-album', '从相册选择', () => widget.onChoose(ImageSource.gallery)),
                          SizedBox(
                            height: FavouritesTheme.coverSheetHairline,
                            child: ColoredBox(color: FavouritesTheme.colorsOf(context).coverSheetHairlineInk),
                          ),
                          _button('fav-new-cover-camera', '拍照', () => widget.onChoose(ImageSource.camera)),
                        ]),
                        const SizedBox(height: FavouritesTheme.coverSheetGap),
                        _group(FavouritesTheme.colorsOf(context).coverSheetCancelFill, [
                          _button('fav-new-cover-cancel', '取消', _close, weight: FavouritesTheme.coverSheetCancelWeight),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(Color fill, List<Widget> children) => ClipRRect(
    borderRadius: BorderRadius.circular(FavouritesTheme.coverSheetRadius),
    child: ColoredBox(
      color: fill,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );

  Widget _button(String key, String label, VoidCallback onTap, {FontWeight weight = FavouritesTheme.textWeight}) {
    final style = favStyle(
      FavouritesTheme.coverSheetText,
      FavouritesTheme.coverSheetInk,
      line: FavouritesTheme.coverSheetLine,
      weight: weight,
    );
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: PressHighlight(
        key: ValueKey(key),
        onTap: onTap,
        child: SizedBox(
          height: FavouritesTheme.coverSheetRow,
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, FavouritesTheme.coverSheetTextDrop),
              child: Text(label, style: style, strutStyle: BiliFonts.strut(style)),
            ),
          ),
        ),
      ),
    );
  }
}
