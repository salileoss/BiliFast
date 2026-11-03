import 'dart:async';

import 'package:bili_core/devlog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle, appBuildName, appBuildNumber;

import '../app/app_environment.dart';
import '../account/account_switch_page.dart';
import '../app/app_scope.dart';
import '../app/swipe_back_route.dart';
import '../shared/image_disk_cache.dart';
import '../shared/menu.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../video/intro/collection_row.dart' show Chevron;
import '../video/player_prefs.dart';
import 'font_page.dart';
import 'node_page.dart';
import 'settings_confirm.dart';

/// What 设置 asks before doing (BiliNative SettingsView's `ClearAction`, and 51's 退出登录).
enum SettingsConfirmKind {
  codecMemory('重置编码记忆？', '本机播放失败过的编码会重新参与尝试。', '重置'),
  recents('清除最近观看？', '「最近在看的视频」列表会被清空。', '清除'),
  logs('清除日志？', '手机上保存的调试日志会被删除，已发送到电脑的不受影响。', '清除'),
  images('清除图片缓存？', '保存在手机上的图片会被删除，再看到时会重新下载。', '清除'),
  logout('退出登录', null, '确定');

  const SettingsConfirmKind(this.title, this.message, this.action);

  final String title;
  final String? message;
  final String action;
}

/// A size as 设置 shows it, "12.3 MB".
String megabytesLabel(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// The build's version, as "1.0.0 (9)".
String buildVersionLabel() => switch ((appBuildName, appBuildNumber)) {
  (final String name, final String number) => '$name ($number)',
  (final String name, null) => name,
  _ => '未知',
};

/// 设置 (50): the account, 字体, the engine's nodes and BTR, clearing what the app keeps, 开发者 in dev builds, the
/// version, and 退出登录 last (51).
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.developerPage, this.prefs, this.version});

  /// Dev builds' 开发者 page; null hides its row.
  final WidgetBuilder? developerPage;

  /// [PlayerPrefs.shared] unless a test passes its own.
  final PlayerPrefs? prefs;

  /// The build's own unless a test passes one.
  final String? version;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late final AnimationController _confirmMotion = AnimationController(
    vsync: this,
    duration: SettingsTheme.confirmIn,
    reverseDuration: SettingsTheme.confirmOut,
  );
  late final CurvedAnimation _confirmCurve = CurvedAnimation(
    parent: _confirmMotion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// The confirm asked for, or null once it is answered (it may still be fading out as [_shown]).
  SettingsConfirmKind? _confirm;
  SettingsConfirmKind? _shown;
  bool _loggingOut = false;

  /// What the stored pictures take, once read.
  int? _imageBytes;
  bool _imageBytesAsked = false;

  PlayerPrefs get _prefs => widget.prefs ?? PlayerPrefs.shared;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    _confirmMotion
      ..duration = still ? Duration.zero : SettingsTheme.confirmIn
      ..reverseDuration = still ? Duration.zero : SettingsTheme.confirmOut;
    if (!_imageBytesAsked) {
      _imageBytesAsked = true;
      final images = AppScope.of(context).imageCache;
      if (images != null) unawaited(_readImageBytes(images));
    }
  }

  Future<void> _readImageBytes(ImageDiskCache images) async {
    final bytes = await images.sizeBytes();
    if (mounted) setState(() => _imageBytes = bytes);
  }

  Future<void> _clearImages(ImageDiskCache images) async {
    await images.clear();
    await _readImageBytes(images);
  }

  @override
  void dispose() {
    _confirmCurve.dispose();
    _confirmMotion.dispose();
    super.dispose();
  }

  void _ask(SettingsConfirmKind kind) {
    setState(() => _confirm = _shown = kind);
    unawaited(_confirmMotion.forward());
  }

  void _dismiss() {
    if (_confirm == null) return;
    setState(() => _confirm = null);
    unawaited(
      _confirmMotion.reverse().then((_) {
        if (mounted && _confirm == null) setState(() => _shown = null);
      }),
    );
  }

  Future<void> _perform(SettingsConfirmKind kind) async {
    if (_confirm != kind) return;
    final services = AppScope.of(context);
    Logger.shared.info(LogCategory.ui, 'settings clear', {'what': kind.name});
    switch (kind) {
      case SettingsConfirmKind.codecMemory:
        services.playback.resetCodecMemory();
      case SettingsConfirmKind.recents:
        services.recents.clear();
      case SettingsConfirmKind.logs:
        unawaited(
          services.logFiles.clear().catchError((Object error) {
            Logger.shared.warn(LogCategory.app, 'log files not cleared', {'error': '${error.runtimeType}'});
          }),
        );
      case SettingsConfirmKind.images:
        if (services.imageCache case final images?) {
          unawaited(
            _clearImages(images).catchError((Object error) {
              Logger.shared.warn(LogCategory.ui, 'image cache not cleared', {'error': '${error.runtimeType}'});
            }),
          );
        }
      case SettingsConfirmKind.logout:
        await _logout(services.environment);
        return;
    }
    _dismiss();
  }

  Future<void> _logout(AppEnvironment environment) async {
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      await environment.logout();
    } catch (error) {
      Logger.shared.warn(LogCategory.app, 'logout failed', {'error': '${error.runtimeType}'});
      if (!mounted) return;
      _dismiss();
      showToast(context, error is ServerLogoutFailed ? 'B 站未确认退出，登录已保留，请稍后重试' : '退出登录失败，请重试');
      return;
    } finally {
      _loggingOut = false;
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _setNode(NodeChoice choice) {
    _prefs.node = choice;
    if (mounted) setState(() {});
    Logger.shared.info(LogCategory.ui, 'settings node', {'node': choice.name});
    // A cold start reads the saved node; the engine running now, or starting now, is told.
    AppScope.of(context).playback.setNodeMode(choice.mode);
  }

  void _push(WidgetBuilder builder) =>
      unawaited(Navigator.of(context).push(SwipeBackPageRoute<void>(builder: builder)));

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final environment = services.environment;
    final recents = services.recents;
    final fonts = services.fonts;
    final developerPage = widget.developerPage;
    final imageBytes = _imageBytes;
    return PopScope(
      canPop: _confirm == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dismiss();
      },
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([environment, recents, fonts]),
            builder: (context, _) {
              final account = environment.account;
              return SettingsScaffold(
                title: '设置',
                children: [
                  SettingsSection(
                    children: [
                      switch (account) {
                        LoggedOut() => SettingsRow(
                          key: const ValueKey('settings-login'),
                          title: '登录',
                          onTap: () => unawaited(services.loginGate.request(context)),
                        ),
                        LoginExpired() => SettingsRow(
                          key: const ValueKey('settings-relogin'),
                          title: '重新登录',
                          onTap: () => unawaited(services.loginGate.request(context)),
                        ),
                        AccountUnknown() when environment.accountCheckFailed => SettingsRow(
                          key: const ValueKey('settings-account'),
                          title: '账号',
                          value: '无法获取账号信息，点按重试',
                          onTap: () => unawaited(environment.refreshAccount()),
                        ),
                        LoggedIn(:final vip) => SettingsRow(
                          key: const ValueKey('settings-account'),
                          title: '账号',
                          value: environment.accountLabel,
                          valueColor: vip ? SettingsTheme.colorsOf(context).vipName : SettingsTheme.colorsOf(context).value,
                          badge: vip ? const VipBadge() : null,
                        ),
                        AccountUnknown() => SettingsRow(
                          key: const ValueKey('settings-account'),
                          title: '账号',
                          value: environment.accountLabel,
                        ),
                      },
                      if (environment.hasAccountVault || environment.savedAccounts.isNotEmpty)
                        SettingsRow(
                          key: const ValueKey('settings-switch-account'),
                          title: '切换账号',
                          onTap: () => _push((_) => const AccountSwitchPage()),
                        ),
                    ],
                  ),
                  SettingsSection(
                    children: [
                      SettingsRow(
                        key: const ValueKey('settings-font'),
                        title: '字体',
                        value: fonts.label,
                        onTap: () => _push((_) => FontPage(fonts: fonts)),
                      ),
                    ],
                  ),
                  SettingsSection(
                    children: [
                      SettingsRow(
                        key: const ValueKey('settings-node'),
                        title: 'CDN 节点',
                        value: _prefs.node.label,
                        onTap: () => _push((_) => NodePage(choice: _prefs.node, onChanged: _setNode)),
                      ),
                      SettingsSwitchRow(
                        key: const ValueKey('settings-btr'),
                        title: 'BTR 加速（默认）',
                        value: _prefs.btr,
                        onChanged: (on) => setState(() => _prefs.btr = on),
                      ),
                    ],
                  ),
                  SettingsSection(
                    children: [
                      SettingsRow(
                        key: const ValueKey('settings-codec-memory'),
                        title: '重置编码记忆',
                        onTap: () => _ask(SettingsConfirmKind.codecMemory),
                      ),
                      SettingsRow(
                        key: const ValueKey('settings-recents'),
                        title: '清除最近观看',
                        enabled: recents.items.isNotEmpty,
                        onTap: () => _ask(SettingsConfirmKind.recents),
                      ),
                      SettingsRow(
                        key: const ValueKey('settings-logs'),
                        title: '清除日志',
                        onTap: () => _ask(SettingsConfirmKind.logs),
                      ),
                      if (services.imageCache != null)
                        SettingsRow(
                          key: const ValueKey('settings-images'),
                          title: '清除图片缓存',
                          value: imageBytes == null ? null : megabytesLabel(imageBytes),
                          onTap: () => _ask(SettingsConfirmKind.images),
                        ),
                    ],
                  ),
                  if (developerPage != null)
                    SettingsSection(
                      children: [
                        SettingsRow(
                          key: const ValueKey('settings-developer'),
                          title: '开发者',
                          onTap: () => _push(developerPage),
                        ),
                      ],
                    ),
                  SettingsSection(
                    footer: '下载加速移植自 Bilibili 线程撕裂者（BTR），MIT 许可。',
                    children: [
                      SettingsRow(
                        key: const ValueKey('settings-version'),
                        title: '版本',
                        value: widget.version ?? buildVersionLabel(),
                      ),
                    ],
                  ),
                  if (account is LoggedIn || environment.logoutIncomplete || environment.loginUnreadable)
                    SettingsSection(
                      children: [
                        SettingsRow(
                          key: const ValueKey('settings-logout'),
                          title: '退出登录',
                          onTap: () => _ask(SettingsConfirmKind.logout),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
          if (_shown case final shown?)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _confirm == null,
                child: ExcludeSemantics(
                  excluding: _confirm == null,
                  // Up, it is modal: VoiceOver reads only it, not the rows under it.
                  child: BlockSemantics(
                    blocking: _confirm != null,
                    child: SettingsConfirm(
                      title: shown.title,
                      message: shown.message,
                      action: shown.action,
                      motion: _confirmCurve,
                      onConfirm: () => unawaited(_perform(shown)),
                      onCancel: _dismiss,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A settings page (50): the white bar with its bold title and ‹ under the status bar, over the grey page with
/// its sections stacked below.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final titleStyle = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: SettingsTheme.barTitleText,
      fontWeight: SettingsTheme.barTitleWeight,
      color: SettingsTheme.colorsOf(context).barTitle,
    );
    // Its own, not the app's default: pushed or swiped back over a dressed 我的, the page under it is still drawn and
    // its light style would be found through this one.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: BiliPalette.of(context).isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: SettingsTheme.colorsOf(context).page,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: SettingsTheme.colorsOf(context).bar,
              child: Padding(
                padding: EdgeInsets.only(top: padding.top),
                child: SizedBox(
                  height: SettingsTheme.barHeight,
                  child: Stack(
                    children: [
                      Center(
                        child: Transform.translate(
                          offset: Offset(0, SettingsTheme.barTitleDrop),
                          // Under the Scaffold's Material, whose style the title takes.
                          child: Builder(
                            builder: (context) => Text(
                              title,
                              maxLines: 1,
                              style: titleStyle,
                              strutStyle: BiliFonts.strutOf(context, titleStyle),
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: SettingsTheme.backLeft - (SettingsTheme.backTarget - SettingsTheme.backGlyphWidth) / 2,
                        top: 0,
                        bottom: 0,
                        width: SettingsTheme.backTarget,
                        child: _BackButton(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: ListView(
                  padding: EdgeInsets.only(bottom: padding.bottom),
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '返回',
    onTap: () => unawaited(Navigator.of(context).maybePop()),
    excludeSemantics: true,
    child: GestureDetector(
      key: const ValueKey('settings-back'),
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(Navigator.of(context).maybePop()),
      child: Center(
        child: Transform.flip(
          flipX: true,
          child: Chevron(
            size: Size(SettingsTheme.backGlyphWidth, SettingsTheme.backGlyphHeight),
            stroke: SettingsTheme.backStroke,
            color: SettingsTheme.colorsOf(context).backGlyph,
          ),
        ),
      ),
    ),
  );
}

/// The grey gap, a full-width hairline, then white rows each with an inset hairline under it; grey text below when
/// there is a [footer].
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.children, this.footer});

  /// A one-line row's height above its hairline.
  static const rowHeight = BiliMetrics.settingsRowHeight - SettingsTheme.hairline;

  final List<Widget> children;
  final String? footer;

  static TextStyle footerStyle(BuildContext context) =>
      TextStyle(fontFamily: BiliFonts.family, fontSize: SettingsTheme.footerText, color: SettingsTheme.colorsOf(context).footer);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: BiliMetrics.settingsSectionGap),
      ColoredBox(
        color: SettingsTheme.colorsOf(context).hairlineColor,
        child: SizedBox(height: SettingsTheme.hairline),
      ),
      ColoredBox(
        color: SettingsTheme.colorsOf(context).row,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final child in children) ...[
              child,
              Padding(
                padding: EdgeInsets.only(left: SettingsTheme.rowInset),
                child: ColoredBox(
                  color: SettingsTheme.colorsOf(context).hairlineColor,
                  child: SizedBox(height: SettingsTheme.hairline),
                ),
              ),
            ],
          ],
        ),
      ),
      if (footer case final footer?)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SettingsTheme.rowInset,
            SettingsTheme.footerTop,
            SettingsTheme.rowInset,
            SettingsTheme.footerBottom,
          ),
          child: Text(footer, style: footerStyle(context), strutStyle: BiliFonts.strutOf(context, footerStyle(context))),
        ),
    ],
  );
}

/// A row: its title, the value in grey when there is one (with a [badge] after it), and a › when it does something.
/// A row that is not [enabled] greys its title and ignores taps.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.value,
    this.valueColor,
    this.badge,
    this.onTap,
    this.enabled = true,
  });

  final String title;
  final String? value;
  final Color? valueColor;
  final Widget? badge;
  final VoidCallback? onTap;
  final bool enabled;

  /// A row's title, set where 50's are.
  static Widget titleText(String title, {Color? color}) => Builder(builder: (context) {
    final style = TextStyle(fontFamily: BiliFonts.family, fontSize: SettingsTheme.rowTitleText,
        color: color ?? SettingsTheme.colorsOf(context).rowTitle);
    return Transform.translate(
      offset: Offset(0, SettingsTheme.rowTitleDrop),
      child: Builder(
        builder: (context) => Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
          strutStyle: BiliFonts.strutOf(context, style),
        ),
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final active = enabled ? onTap : null;
    final valueStyle = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: BiliMetrics.settingsValueText,
      color: valueColor ?? SettingsTheme.colorsOf(context).value,
    );
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        enabled: onTap == null || enabled,
        child: PressHighlight(
          onTap: active,
          child: SizedBox(
            height: SettingsSection.rowHeight,
            child: Padding(
              padding: const EdgeInsets.only(left: SettingsTheme.rowInset, right: SettingsTheme.chevronRight),
              child: Row(
                children: [
                  Expanded(
                    child: titleText(title, color: enabled ? SettingsTheme.colorsOf(context).rowTitle : SettingsTheme.colorsOf(context).rowDisabled),
                  ),
                  if (value != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: BiliMetrics.settingsValueWidth),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: valueStyle,
                              strutStyle: BiliFonts.strutOf(context, valueStyle),
                            ),
                          ),
                          if (badge case final badge?) ...[const SizedBox(width: SettingsTheme.vipBadgeGap), badge],
                        ],
                      ),
                    ),
                  if (onTap != null) ...[
                    if (value != null) const SizedBox(width: SettingsTheme.valueGap),
                    Chevron(
                      size: Size(SettingsTheme.chevronWidth, SettingsTheme.chevronHeight),
                      stroke: SettingsTheme.chevronStroke,
                      color: SettingsTheme.colorsOf(context).chevron,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row with a switch at its end; the whole row flips it.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({super.key, required this.title, required this.value, required this.onChanged});

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      toggled: value,
      child: PressHighlight(
        onTap: () => onChanged(!value),
        child: SizedBox(
          height: SettingsSection.rowHeight,
          child: Padding(
            padding: const EdgeInsets.only(left: SettingsTheme.rowInset, right: SettingsTheme.switchRight),
            child: Row(
              children: [
                Expanded(child: SettingsRow.titleText(title)),
                _Switch(on: value),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    const inset = (BiliMetrics.panelSwitchHeight - BiliMetrics.panelSwitchKnob) / 2;
    final motion = MediaQuery.disableAnimationsOf(context) ? Duration.zero : SettingsTheme.switchMotion;
    return AnimatedContainer(
      key: const ValueKey('settings-switch'),
      duration: motion,
      curve: Curves.easeOutCubic,
      width: BiliMetrics.panelSwitchWidth,
      height: BiliMetrics.panelSwitchHeight,
      padding: const EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: on ? SettingsTheme.colorsOf(context).switchOn : SettingsTheme.colorsOf(context).switchOff,
        borderRadius: BorderRadius.circular(BiliMetrics.panelSwitchHeight / 2),
      ),
      child: AnimatedAlign(
        duration: motion,
        curve: Curves.easeOutBack,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: BiliMetrics.panelSwitchKnob,
          height: BiliMetrics.panelSwitchKnob,
          decoration: const BoxDecoration(
            color: SettingsTheme.switchKnob,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: SettingsTheme.switchKnobShadow, blurRadius: SettingsTheme.switchKnobShadowBlur),
            ],
          ),
        ),
      ),
    );
  }
}

/// 大会员's pink pill after the account's name, as the avatar menu drew it.
class VipBadge extends StatelessWidget {
  const VipBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('settings-vip'),
    height: BiliMetrics.vipBadgeHeight,
    padding: const EdgeInsets.symmetric(horizontal: SettingsTheme.vipBadgePadding),
    alignment: Alignment.center,
    decoration: ShapeDecoration(color: SettingsTheme.colorsOf(context).vipBadge, shape: StadiumBorder()),
    child: Text(
      '大会员',
      style: TextStyle(
        fontFamily: BiliFonts.family,
        fontSize: BiliMetrics.vipBadgeText,
        fontWeight: FontWeight.w600,
        color: SettingsTheme.vipBadgeLabel,
        height: 1,
      ),
    ),
  );
}
