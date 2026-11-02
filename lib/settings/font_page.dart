import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../shared/menu.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import 'font_store.dart';
import 'settings_page.dart';

typedef PickedFont = ({String name, Uint8List bytes});

/// The document picker for .ttf, .otf and .ttc files; null when cancelled.
Future<PickedFont?> pickFontFile() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: '字体', extensions: ['ttf', 'otf', 'ttc'], uniformTypeIdentifiers: ['public.font']),
    ],
  );
  if (file == null) return null;
  return (name: file.name, bytes: await file.readAsBytes());
}

/// 设置 → 字体: each font drawn in itself, picked with a tap and applied at once, and 导入字体 for a file of your own.
class FontPage extends StatefulWidget {
  const FontPage({super.key, required this.fonts, this.pick = pickFontFile});

  final FontStore fonts;
  final Future<PickedFont?> Function() pick;

  @override
  State<FontPage> createState() => _FontPageState();
}

class _FontPageState extends State<FontPage> {
  bool _importing = false;

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final PickedFont? picked;
      try {
        picked = await widget.pick();
      } catch (_) {
        if (mounted) showToast(context, '无法打开文件');
        return;
      }
      if (picked == null) return;
      final outcome = await widget.fonts.importFont(picked.name, picked.bytes);
      if (!mounted) return;
      showToast(context, switch (outcome) {
        ImportOutcome.imported => '已使用 ${widget.fonts.label}',
        ImportOutcome.notAFont => '这不是字体文件',
        ImportOutcome.failed => '导入失败，请重试',
      });
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fonts = widget.fonts;
    return ListenableBuilder(
      listenable: fonts,
      builder: (context, _) => SettingsScaffold(
        title: '字体',
        children: [
          SettingsSection(
            children: [
              for (final choice in FontChoice.values)
                if (choice != FontChoice.imported || fonts.imported != null)
                  _FontRow(
                    key: ValueKey('font-${choice.name}'),
                    name: fonts.labelOf(choice),
                    family: fonts.familyOf(choice),
                    selected: fonts.choice == choice,
                    onTap: () => fonts.select(choice),
                  ),
            ],
          ),
          SettingsSection(
            footer: '支持 .ttf、.otf、.ttc 字体文件。字体里没有的字会用系统字体显示。',
            children: [
              MergeSemantics(
                child: Semantics(
                  button: true,
                  enabled: !_importing,
                  child: PressHighlight(
                    key: const ValueKey('font-import'),
                    onTap: _importing ? null : () => unawaited(_import()),
                    child: SizedBox(
                      height: SettingsSection.rowHeight,
                      child: Center(
                        child: Text(
                          fonts.imported == null ? '导入字体' : '导入其他字体',
                          style: TextStyle(
                            fontSize: BiliMetrics.bodyText,
                            color: _importing ? BiliColors.colorsOf(context).secondaryText : BiliColors.colorsOf(context).pink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A font's name and a sample line, both drawn in that font, with a pink tick on the one in use.
class _FontRow extends StatelessWidget {
  const _FontRow({super.key, required this.name, required this.family, required this.selected, required this.onTap});

  final String name;

  /// Null for the system's, which the page around it may not be drawing in.
  final String? family;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final family =
        this.family ?? Typography.material2021(platform: Theme.of(context).platform).black.bodyMedium?.fontFamily;
    // The PingFang strut fits only the system font's row; the others draw in a font of their own.
    final system = family == BiliFonts.system;
    final nameStyle = TextStyle(fontFamily: family, fontSize: BiliMetrics.bodyText, color: BiliColors.colorsOf(context).text);
    final sampleStyle = TextStyle(fontFamily: family, fontSize: BiliMetrics.smallText, color: BiliColors.colorsOf(context).secondaryText);
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: PressHighlight(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BiliMetrics.sectionGap,
              BiliMetrics.fontRowPadding,
              BiliMetrics.gutter,
              BiliMetrics.fontRowPadding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: nameStyle,
                        strutStyle: system ? BiliFonts.strutOf(context, nameStyle) : null,
                      ),
                      const SizedBox(height: BiliMetrics.fontSampleGap),
                      ExcludeSemantics(
                        child: Text(
                          '推荐 关注 热门 · 1.2万播放 03:45',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: sampleStyle,
                          strutStyle: system ? BiliFonts.strutOf(context, sampleStyle) : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check, size: BiliMetrics.fontCheck, color: BiliColors.colorsOf(context).pink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
