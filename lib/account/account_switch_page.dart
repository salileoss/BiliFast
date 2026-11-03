import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_environment.dart';
import '../app/app_scope.dart';
import '../settings/settings_confirm.dart';
import '../shared/menu.dart';
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../video/intro/collection_row.dart' show Chevron;
import 'account_switch_theme.dart';
import 'account_vault.dart';
import 'login_page.dart';

/// Saved accounts stay local until a row is selected; opening the list makes no API calls.
class AccountSwitchPage extends StatefulWidget {
  const AccountSwitchPage({super.key, this.environment});

  final AppEnvironment? environment;

  @override
  State<AccountSwitchPage> createState() => _AccountSwitchPageState();
}

class _AccountSwitchPageState extends State<AccountSwitchPage> {
  AppEnvironment get _environment =>
      widget.environment ?? AppScope.of(context).environment;
  bool _managing = false;
  bool _busy = false;
  int? _pendingMid;
  SavedAccount? _removing;

  Future<void> _choose(SavedAccount account) async {
    if (_busy) return;
    if (_managing) {
      setState(() => _removing = account);
      return;
    }
    if (account.expired) {
      await _login(expectedMid: account.mid);
      return;
    }
    if (account.mid == _environment.activeAccountMid) return;
    setState(() {
      _busy = true;
      _pendingMid = account.mid;
    });
    try {
      await _environment.switchAccount(account.mid);
      if (mounted) _returnToRoot();
    } catch (error) {
      if (mounted) _failure(error, '切换失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingMid = null;
        });
      }
    }
  }

  Future<void> _login({int? expectedMid}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _pendingMid = expectedMid;
    });
    try {
      final loggedIn = await Navigator.of(context, rootNavigator: true)
          .push<bool>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => LoginPage(expectedMid: expectedMid),
            ),
          );
      if (mounted && loggedIn == true) _returnToRoot();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingMid = null;
        });
      }
    }
  }

  Future<void> _remove() async {
    final account = _removing;
    if (account == null || _busy) return;
    final active = account.mid == _environment.activeAccountMid;
    setState(() {
      _busy = true;
      _pendingMid = account.mid;
      _removing = null;
    });
    try {
      await _environment.removeAccount(account.mid);
      if (mounted && active) _returnToRoot();
    } catch (error) {
      if (mounted) _failure(error, '移除失败，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingMid = null;
        });
      }
    }
  }

  void _failure(Object error, String fallback) => showToast(
    context,
    error is AccountSwitchFailure ? error.message : fallback,
  );

  void _returnToRoot() => Navigator.of(
    context,
    rootNavigator: true,
  ).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final palette = BiliPalette.of(context);
    return PopScope(
      canPop: !_busy && _removing == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _removing != null) setState(() => _removing = null);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: palette.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AccountSwitchTheme.page(context),
          body: ListenableBuilder(
            listenable: _environment,
            builder: (context, _) {
              final disabled = _busy || _environment.accountTransitioning;
              final accounts = _environment.savedAccounts;
              return Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _bar(context, disabled),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.paddingOf(context).bottom,
                          ),
                          children: [
                            SizedBox(
                              height: AccountSwitchTheme.hintHeight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AccountSwitchTheme.inset,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _managing ? '点击账号移除登录信息' : '点击头像切换账号',
                                    style: _text(
                                      AccountSwitchTheme.hintSize,
                                      palette.secondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            for (final account in accounts)
                              _AccountRow(
                                key: ValueKey('switch-account-${account.mid}'),
                                account: account,
                                current:
                                    account.mid ==
                                    _environment.activeAccountMid,
                                managing: _managing,
                                busy: _busy && _pendingMid == account.mid,
                                onTap: disabled
                                    ? null
                                    : () => unawaited(_choose(account)),
                              ),
                            const SizedBox(
                              height: AccountSwitchTheme.sectionGap,
                            ),
                            _addRow(context, disabled),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_removing != null)
                    Positioned.fill(
                      child: SettingsConfirm(
                        title: '移除此账号？',
                        message: '将退出并移除此账号，其他账号不受影响。',
                        action: '移除',
                        onConfirm: () => unawaited(_remove()),
                        onCancel: () => setState(() => _removing = null),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, bool disabled) {
    final palette = BiliPalette.of(context);
    return ColoredBox(
      color: AccountSwitchTheme.surface(context),
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: SizedBox(
          height: AccountSwitchTheme.barHeight,
          child: Stack(
            children: [
              Center(
                child: Text(
                  '账号切换',
                  style: _text(
                    AccountSwitchTheme.titleSize,
                    palette.text,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: '返回',
                  enabled: !disabled,
                  child: PressHighlight(
                    key: const ValueKey('account-switch-back'),
                    onTap: disabled
                        ? null
                        : () => unawaited(Navigator.of(context).maybePop()),
                    child: SizedBox(
                      width: AccountSwitchTheme.actionWidth,
                      height: AccountSwitchTheme.barHeight,
                      child: Center(
                        child: Transform.flip(
                          flipX: true,
                          child: Chevron(
                            size: const Size(
                              SettingsTheme.backGlyphWidth,
                              SettingsTheme.backGlyphHeight,
                            ),
                            stroke: SettingsTheme.backStroke,
                            color: palette.icon,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  button: true,
                  enabled: !disabled,
                  child: PressHighlight(
                    key: const ValueKey('account-switch-manage'),
                    onTap: disabled
                        ? null
                        : () => setState(() => _managing = !_managing),
                    child: SizedBox(
                      width: AccountSwitchTheme.actionWidth,
                      height: AccountSwitchTheme.barHeight,
                      child: Center(
                        child: Text(
                          _managing ? '完成' : '管理',
                          style: _text(
                            AccountSwitchTheme.actionSize,
                            palette.secondary,
                          ),
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
    );
  }

  Widget _addRow(BuildContext context, bool disabled) {
    final palette = BiliPalette.of(context);
    return Semantics(
      button: true,
      enabled: !disabled,
      child: PressHighlight(
        key: const ValueKey('account-switch-add'),
        onTap: disabled ? null : () => unawaited(_login()),
        child: Container(
          height: AccountSwitchTheme.rowHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: AccountSwitchTheme.inset,
          ),
          color: AccountSwitchTheme.surface(context),
          child: Row(
            children: [
              Container(
                width: AccountSwitchTheme.avatar,
                height: AccountSwitchTheme.avatar,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AccountSwitchTheme.addFill(context),
                ),
                child: Icon(
                  Icons.add,
                  size: AccountSwitchTheme.plus,
                  color: palette.secondary,
                ),
              ),
              const SizedBox(width: AccountSwitchTheme.avatarGap),
              Expanded(
                child: Text(
                  '添加账号',
                  style: _text(AccountSwitchTheme.nameSize, palette.text),
                ),
              ),
              if (_busy && _pendingMid == null)
                const CupertinoActivityIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _text(double size, Color color, {FontWeight? weight}) => TextStyle(
  fontFamily: BiliFonts.family,
  fontFamilyFallback: BiliFonts.fallback,
  fontSize: size,
  color: color,
  fontWeight: weight,
  letterSpacing: 0,
);

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    super.key,
    required this.account,
    required this.current,
    required this.managing,
    required this.busy,
    required this.onTap,
  });

  final SavedAccount account;
  final bool current;
  final bool managing;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = BiliPalette.of(context);
    final name = account.name.isEmpty ? '已保存的账号' : account.name;
    return Semantics(
      button: true,
      selected: current,
      enabled: onTap != null,
      onTap: onTap,
      label:
          '$name${current ? '，当前账号' : ''}${account.expired ? '，登录已失效，重新登录' : ''}${managing ? '，移除' : ''}',
      excludeSemantics: true,
      child: PressHighlight(
        onTap: onTap,
        child: Container(
          height: AccountSwitchTheme.rowHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: AccountSwitchTheme.inset,
          ),
          decoration: BoxDecoration(
            color: AccountSwitchTheme.surface(context),
            border: Border(
              bottom: BorderSide(
                color: AccountSwitchTheme.ruleColor(context),
                width: AccountSwitchTheme.rule,
              ),
            ),
          ),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: AccountSwitchTheme.avatar,
                  child: RemoteImage.avatar(
                    account.face,
                    size: const Size.square(AccountSwitchTheme.avatar),
                  ),
                ),
              ),
              const SizedBox(width: AccountSwitchTheme.avatarGap),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(AccountSwitchTheme.nameSize, palette.text),
                    ),
                    if (account.expired) ...[
                      const SizedBox(height: AccountSwitchTheme.noteGap),
                      Text(
                        '登录已失效，重新登录',
                        style: _text(
                          AccountSwitchTheme.noteSize,
                          palette.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AccountSwitchTheme.inset),
              if (busy)
                const CupertinoActivityIndicator(
                  key: ValueKey('account-switch-progress'),
                )
              else if (managing)
                Text(
                  '移除',
                  style: _text(AccountSwitchTheme.nameSize, palette.accent),
                )
              else if (current)
                Container(
                  key: ValueKey('switch-current-${account.mid}'),
                  width: AccountSwitchTheme.check,
                  height: AccountSwitchTheme.check,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.accent,
                  ),
                  child: Icon(
                    Icons.check,
                    size: AccountSwitchTheme.checkGlyph,
                    color: AccountSwitchTheme.checkInk(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
