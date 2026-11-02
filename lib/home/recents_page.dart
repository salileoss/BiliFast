import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../shared/menu.dart';
import '../shared/theme.dart';
import '../video/video_route.dart';
import 'recent_store.dart';

/// 最近打开 (port of RecentsView in HomeView.swift): the parts opened from links, newest first, with 清空.
class RecentsPage extends StatelessWidget {
  const RecentsPage({super.key});

  Future<void> _confirmClear(BuildContext context, RecentStore recents) async {
    final clear = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('清空最近打开的视频？'),
        actions: [
          CupertinoActionSheetAction(
            key: const ValueKey('recents-clear-confirm'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
      ),
    );
    if (clear ?? false) recents.clear();
  }

  @override
  Widget build(BuildContext context) {
    final recents = AppScope.of(context).recents;
    return ListenableBuilder(
      listenable: recents,
      builder: (context, _) {
        final items = recents.items;
        return Scaffold(
          backgroundColor: BiliColors.colorsOf(context).pageGrey,
          appBar: AppBar(
            backgroundColor: BiliColors.colorsOf(context).card,
            surfaceTintColor: BiliColors.colorsOf(context).card,
            centerTitle: true,
            title: Text(
              '最近打开',
              style: TextStyle(fontSize: BiliMetrics.titleText, color: BiliColors.colorsOf(context).text),
            ),
            actions: [
              if (items.isNotEmpty)
                TextButton(
                  key: const ValueKey('recents-clear'),
                  onPressed: () => _confirmClear(context, recents),
                  child: Text('清空', style: TextStyle(color: BiliColors.colorsOf(context).pink)),
                ),
            ],
          ),
          body: items.isEmpty
              ? Center(
                  child: Text(
                    '还没有打开过视频',
                    style: TextStyle(fontSize: BiliMetrics.bodyText, color: BiliColors.colorsOf(context).secondaryText),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 0.5, thickness: 0.5, indent: 64, color: BiliColors.colorsOf(context).divider),
                  itemBuilder: (context, index) => _RecentRow(item: items[index]),
                ),
        );
      },
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.item});

  final RecentVideo item;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      button: true,
      child: ColoredBox(
        color: BiliColors.colorsOf(context).card,
        child: PressHighlight(
          key: ValueKey('recent-${item.id}'),
          onTap: () {
            AppScope.of(context).recents.add(item);
            unawaited(openVideoPage(context, VideoRoute(bvid: item.bvid, cid: item.cid, title: item.title)));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BiliMetrics.sectionGap, vertical: BiliMetrics.gutter),
            child: Row(
              children: [
                Container(
                  width: BiliMetrics.recentsTile,
                  height: BiliMetrics.recentsTile,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [BiliColors.recentsTileTop, BiliColors.colorsOf(context).pink],
                    ),
                    borderRadius: BorderRadius.circular(BiliMetrics.recentsTileRadius),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: BiliColors.colorsOf(context).card,
                    size: BiliMetrics.recentsTileIcon,
                  ),
                ),
                const SizedBox(width: BiliMetrics.gutter),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: BiliMetrics.bodyText, color: BiliColors.colorsOf(context).text),
                        strutStyle: BiliFonts.strutOf(context, const TextStyle(fontSize: BiliMetrics.bodyText)),
                      ),
                      if (item.pageCount > 1)
                        Text(
                          'P${item.page} ${item.part}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.colorsOf(context).secondaryText),
                          strutStyle: BiliFonts.strutOf(context, const TextStyle(fontSize: BiliMetrics.smallText)),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: BiliColors.colorsOf(context).divider),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
