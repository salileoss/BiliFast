import 'package:flutter/material.dart';

import '../shared/menu.dart';
import '../shared/theme.dart';
import '../video/player_prefs.dart';
import 'settings_page.dart';

/// 设置 → CDN 节点: automatic selection or a regional set, picked as 字体's fonts are.
class NodePage extends StatefulWidget {
  const NodePage({super.key, required this.choice, required this.onChanged});

  final NodeChoice choice;
  final ValueChanged<NodeChoice> onChanged;

  @override
  State<NodePage> createState() => _NodePageState();
}

class _NodePageState extends State<NodePage> {
  late NodeChoice _choice = widget.choice;

  void _pick(NodeChoice choice) {
    if (choice == _choice) return;
    setState(() => _choice = choice);
    widget.onChanged(choice);
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: 'CDN 节点',
    children: [
      SettingsSection(
        footer: '自动优选会比较原始地址、海外及大陆节点。从下一个视频开始使用。',
        children: [
          for (final choice in NodeChoice.values)
            MergeSemantics(
              child: Semantics(
                button: true,
                selected: choice == _choice,
                child: PressHighlight(
                  key: ValueKey('node-${choice.name}'),
                  onTap: () => _pick(choice),
                  child: SizedBox(
                    height: SettingsSection.rowHeight,
                    child: Padding(
                      padding: const EdgeInsets.only(left: SettingsTheme.rowInset, right: SettingsTheme.chevronRight),
                      child: Row(
                        children: [
                          Expanded(child: SettingsRow.titleText(choice.label)),
                          if (choice == _choice)
                            Icon(Icons.check, size: BiliMetrics.fontCheck, color: BiliColors.colorsOf(context).pink),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}
