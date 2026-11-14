import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../shared/toast.dart';

/// Copies the card's full title and video URL without a network request or login.
Future<void> copyFeedLink(BuildContext context, FeedCard card) async {
  final link = 'https://www.bilibili.com/video/${card.bvid}';
  try {
    await Clipboard.setData(ClipboardData(text: '【${card.title}-哔哩哔哩】 $link'));
    if (context.mounted) showToast(context, '已复制链接');
  } catch (error) {
    Logger.shared.warn(LogCategory.ui, 'copy feed link failed', {
      'error': '$error',
    });
    if (context.mounted) showToast(context, '复制失败，请重试');
  }
}
