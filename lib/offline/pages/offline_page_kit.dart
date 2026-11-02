import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../app/app_environment.dart';
import '../../shared/theme.dart';
import '../../skin/skin.dart';
import '../offline_library.dart';
import '../offline_models.dart';
import '../offline_route.dart';
import 'offline_bar.dart';
import 'offline_edit.dart';

/// Opens a finished part; [openOfflinePage] unless a test watches it instead.
typedef OfflineOpener = void Function(BuildContext context, OfflineItem item);

void openItemPage(BuildContext context, OfflineItem item) => unawaited(openOfflinePage(context, item));

/// Whether 2个 and 3个 can be picked (147): a 大会员, or an account not yet checked (the phone may be offline, which is
/// when this list matters most). Only this picker checks: the library runs whatever count it was given, up to 3, so
/// one kept from a 大会员 login stays after the account changes.
bool offlineVip(AppEnvironment environment) => switch (environment.account) {
  LoggedIn(:final vip) => vip,
  AccountUnknown() => true,
  LoggedOut() || LoginExpired() => false,
};

/// The page's frame: the skin's bar look, the status bar by its fill, a white Scaffold and back closing [onBack]'s
/// layers first while [canPop] is false.
Widget offlineScaffold({
  required ValueListenable<Skin?> skin,
  required bool canPop,
  required VoidCallback onBack,
  required Widget Function(OfflineBarLook look) builder,
}) => PopScope<Object?>(
  canPop: canPop,
  onPopInvokedWithResult: (didPop, _) {
    if (!didPop) onBack();
  },
  child: ValueListenableBuilder<Skin?>(
    valueListenable: skin,
    builder: (context, skin, _) {
      final look = OfflineBarLook.of(skin, context: context);
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: look.lightStatus ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(backgroundColor: OfflineListTheme.colorsOf(context).page, resizeToAvoidBottomInset: false, body: builder(look)),
      );
    },
  ),
);

/// A scroll view under the bar, without the status bar's padding again.
Widget offlineScroll(BuildContext context, List<Widget> slivers, {Key? key}) => MediaQuery.removePadding(
  context: context,
  removeTop: true,
  removeBottom: true,
  child: CustomScrollView(
    key: key,
    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    slivers: slivers,
  ),
);

/// Edit mode as 149 and 150 have it: ☰ starts it, 完成 ends it; rows are chosen by key, 全选 chooses all or none,
/// 删除 asks 确定要删除吗? and 确认 deletes the chosen parts and leaves edit mode. Back closes the confirm, then the mode.
mixin OfflineEditing<W extends StatefulWidget> on State<W> {
  final selection = OfflineSelection();
  bool editing = false;
  bool confirming = false;

  OfflineLibrary get library;

  /// The rows edit mode can choose now, by key.
  Map<String, List<int>> selectable();

  void startEdit() {
    selection.clear();
    setState(() => editing = true);
  }

  void endEdit() {
    selection.clear();
    setState(() {
      editing = false;
      confirming = false;
    });
  }

  void askDelete() {
    if (selection.isEmpty) return;
    setState(() => confirming = true);
  }

  Future<void> confirmDelete() async {
    final cids = selection.cids;
    endEdit();
    await library.delete(cids);
  }

  void cancelDelete() => setState(() => confirming = false);

  /// Closes the confirm, else edit mode; false when neither was up.
  bool closeEditLayer() {
    if (confirming) {
      cancelDelete();
      return true;
    }
    if (editing) {
      endEdit();
      return true;
    }
    return false;
  }

  /// Rows that left the list leave the choice too; after the frame, since the list learns of it while building.
  void pruneSelection() {
    if (selection.isEmpty) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) selection.keepOnly(selectable());
    });
  }

  void toggle(String key, List<int> cids) => selection.toggle(key, cids);

  Widget editBar() => ListenableBuilder(
    listenable: Listenable.merge([selection, library]),
    builder: (context, _) {
      final rows = selectable();
      return OfflineEditBar(
        allChosen: selection.allOf(rows),
        anyChosen: !selection.isEmpty,
        onToggleAll: () => selection.toggleAll(rows),
        onDelete: askDelete,
      );
    },
  );

  Widget confirmLayer() => Positioned.fill(
    child: OfflineDeleteConfirm(onConfirm: () => unawaited(confirmDelete()), onCancel: cancelDelete),
  );

  @override
  void dispose() {
    selection.dispose();
    super.dispose();
  }
}
