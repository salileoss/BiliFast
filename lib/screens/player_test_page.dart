import 'dart:async';

import 'package:bili_core/devlog.dart';
import 'package:bili_core/engine.dart';
import 'package:bili_core/logic.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../account/app_auth.dart';
import '../app/app_environment.dart';
import '../app/app_scope.dart';
import '../devtools/crash_log.dart';
import '../devtools/log_forwarder.dart';
import '../devtools/log_server_discovery.dart';
import '../playback/playback_controller.dart';
import '../playback/playback_setup.dart';
import '../playback/shared_engine.dart';
import '../player_ui/player_stage.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../video/intro/collection_row.dart' show Chevron;
import '../video/player_prefs.dart';
import '../speedtest/speed_test_plan.dart';
import '../speedtest/speed_test_results.dart';
import '../speedtest/speed_test_runner.dart';

typedef StageBuilder = Widget Function(BuildContext context, PlaybackController controller,
    {required bool showStats, required bool danmakuEnabled});

Widget playerStage(BuildContext context, PlaybackController controller,
        {required bool showStats, required bool danmakuEnabled}) =>
    PlayerStage(
      player: controller.player,
      clock: controller.clock,
      stats: controller.stats,
      showStats: showStats,
      duration: controller.duration,
      danmaku: controller.danmaku.timeline,
      danmakuEnabled: danmakuEnabled,
      onSeek: controller.userSeeked,
      onHint: controller.seekHint,
    );

/// The real plan fetch and engines.
const appSpeedTestHooks =
    SpeedTestHooks(choosePlan: choosePlan, startEngine: _startVariantEngine, appEngine: startPlatformEngine);

Future<PlaybackEngine> _startVariantEngine(SpeedTestVariant variant) =>
    startPlatformEngine(config: variant.config, connectionsPerHost: variant.connectionsPerHost);

/// The app's: each variant runs on an engine of its own, so the pages' [shared] engine is never swapped, and a run
/// ends back on a lease of [shared].
SpeedTestHooks appSpeedTestHooksOn(SharedEngine? shared) => shared == null
    ? appSpeedTestHooks
    : SpeedTestHooks(choosePlan: choosePlan, startEngine: _startVariantEngine, appEngine: shared.lease);

/// Hands a file to the share sheet, which on an iPad points at [origin].
typedef ShareFile = Future<void> Function(String path, Rect? origin);

Future<void> shareFileThroughSystem(String path, Rect? origin) async {
  await SharePlus.instance.share(ShareParams(files: [XFile(path)], sharePositionOrigin: origin));
}

/// Slice 1's whole app, now 开发者 in 设置 (dev builds): the account the keychain login gave, a BV field, the player and
/// its switches, 旋转动画, the official API's token and 推荐's source, the log forwarder with 导出日志 and 测试崩溃,
/// and the speed test.
class PlayerTestPage extends StatefulWidget {
  const PlayerTestPage({
    super.key,
    required this.environment,
    required this.startPlayback,
    this.logs,
    this.stageBuilder = playerStage,
    this.initialLink,
    this.speedTestHooks = appSpeedTestHooks,
    this.releasePlayback,
    this.shareFile = shareFileThroughSystem,
    this.prefs,
    this.appAuth,
  });

  final AppEnvironment environment;
  final Future<PlaybackController> Function() startPlayback;

  /// Null when the build has no dev tools.
  final LogForwarder? logs;
  final StageBuilder stageBuilder;

  /// Played as soon as the player is up (tests; `--play=` on the PC now opens a video page from home).
  final String? initialLink;
  final SpeedTestHooks speedTestHooks;

  /// Takes the controller back when the page leaves (the app's AppPlayback.release, which also hears lifecycle and
  /// memory events for it); without it the page disposes the controller itself.
  final void Function(PlaybackController controller)? releasePlayback;

  /// Tests pass their own so nothing reaches the platform.
  final ShareFile shareFile;

  /// [PlayerPrefs.shared] unless a test passes its own.
  final PlayerPrefs? prefs;

  /// The official API's token, for the 官方接口 row; without it the row is left out.
  final AppAuth? appAuth;

  @override
  State<PlayerTestPage> createState() => _PlayerTestPageState();
}

class _PlayerTestPageState extends State<PlayerTestPage> with WidgetsBindingObserver {
  final _link = TextEditingController();
  final _testLinks = TextEditingController();
  late final TextEditingController _logAddress = TextEditingController(text: widget.logs?.manual ?? '');
  AppLifecycleListener? _lifecycle;
  PlaybackController? _controller;

  /// Dev builds only, like the log section.
  SpeedTestRunner? _speedTest;
  String? _startError;
  bool _showStats = true;
  bool _danmakuEnabled = true;
  bool _exporting = false;

  PlayerPrefs get _prefs => widget.prefs ?? PlayerPrefs.shared;

  /// The page owns its controller and nothing else hears the app's events for it.
  bool get _standalone => widget.releasePlayback == null;

  /// PlayerDevice.platform gives the rotation a host, and so turns to take over, only on iOS.
  static bool get _canTakeOverTurns => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (_standalone) {
      _lifecycle = AppLifecycleListener(onResume: () => unawaited(_controller?.appResumed()));
      WidgetsBinding.instance.addObserver(this);
    }
    final release = widget.releasePlayback;
    widget.startPlayback().then((controller) {
      if (!mounted) {
        if (release != null) {
          release(controller);
        } else {
          controller.dispose();
        }
        return;
      }
      setState(() {
        _controller = controller;
        if (widget.logs != null) {
          _speedTest = SpeedTestRunner(
            target: ControllerTarget(controller),
            hooks: widget.speedTestHooks,
          );
        }
      });
      final link = widget.initialLink;
      if (link != null) {
        _link.text = link;
        _openLink(controller, link);
      }
    }, onError: (Object error) {
      if (mounted) setState(() => _startError = '$error');
    });
  }

  @override
  void didHaveMemoryPressure() => _controller?.memoryPressure();

  @override
  void dispose() {
    if (_standalone) WidgetsBinding.instance.removeObserver(this);
    _lifecycle?.dispose();
    // Before the controller, so sound and screen are put back while the player is still there.
    _stopSpeedTest();
    final controller = _controller;
    final release = widget.releasePlayback;
    if (release != null) {
      if (controller != null) release(controller);
    } else {
      controller?.dispose();
    }
    _link.dispose();
    _testLinks.dispose();
    _logAddress.dispose();
    super.dispose();
  }

  bool _speedTestStopped = false;

  /// Runs at the pop, not at dispose half a second later, so the run stops with the swipe.
  void _stopSpeedTest() {
    if (_speedTestStopped) return;
    _speedTestStopped = true;
    _speedTest?.dispose();
  }

  void _play() {
    final controller = _controller;
    if (controller == null || _link.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    _openLink(controller, _link.text);
  }

  void _openLink(PlaybackController controller, String text) {
    unawaited(controller.open(text));
  }

  /// From the next turn on; the controller logs a host that fails.
  void _setTurnTakeover(bool drawn) {
    setState(() => _prefs.turnTakeover = drawn);
    unawaited(AppScope.of(context).device.orientation.setTurnTakeover(drawn));
  }

  void _startSpeedTest() {
    final runner = _speedTest;
    if (runner == null || runner.running) return;
    FocusScope.of(context).unfocus();
    final links = [
      for (final line in _testLinks.text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    final logs = widget.logs;
    unawaited(runner.start(links: links, server: logs != null && logs.enabled ? logs.target : null));
  }

  Future<void> _exportLogs(Rect? origin) async {
    if (_exporting) return;
    final files = AppScope.of(context).logFiles;
    setState(() => _exporting = true);
    String? path;
    var failed = false;
    try {
      path = await files.export();
    } catch (_) {
      // The export logged why.
      failed = true;
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    if (path == null) {
      showToast(context, failed ? '导出日志失败' : '没有可导出的日志');
      return;
    }
    try {
      await widget.shareFile(path, origin);
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'log share failed', {'error': '$error'});
      if (mounted) showToast(context, '无法打开分享');
    }
  }

  /// A Dart error the app doesn't catch, thrown from the next frame's callbacks, so the framework hands it to
  /// CrashLog as it would any other. Native crashes aren't captured yet, so the app carries on.
  Future<void> _confirmCrash() async {
    final crash = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('让应用立即崩溃？'),
        message: const Text('会抛出一个未捕获的 Dart 错误，崩溃报告作为 crash 事件发送到电脑。'),
        actions: [
          CupertinoActionSheetAction(
            key: const ValueKey('crash-confirm'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('崩溃'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          key: const ValueKey('crash-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
      ),
    );
    if (crash != true) return;
    Logger.shared.warn(LogCategory.ui, 'test crash');
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => throw DeveloperTestCrash())
      ..scheduleFrame();
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop && !_standalone) _stopSpeedTest();
        },
        child: _page(context),
      );

  Widget _page(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: BiliColors.colorsOf(context).pageGrey,
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.environment, ?widget.appAuth, ?controller, ?controller?.danmaku]),
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Bar(),
              Padding(
                padding: const EdgeInsets.all(BiliMetrics.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AccountBar(environment: widget.environment),
                    const SizedBox(height: BiliMetrics.rowGap),
                    _LinkBar(link: _link, ready: controller != null, onPlay: _play),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(color: BiliColors.videoBackground, child: _stage(context, controller)),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(BiliMetrics.gutter),
                  children: [
                    if (controller != null) ..._playbackSection(controller),
                    _Card(children: [
                      _Row(
                        label: _canTakeOverTurns ? '旋转动画' : '旋转动画（仅 iPhone）',
                        trailing: _turnTakeoverChoice(),
                      ),
                    ]),
                    const SizedBox(height: BiliMetrics.sectionGap),
                    _Card(children: [
                      if (widget.appAuth case final appAuth?)
                        _Row(label: '官方接口', trailing: _appAuthState(appAuth)),
                      _Row(label: '推荐', trailing: _feedChoice()),
                    ]),
                    const SizedBox(height: BiliMetrics.sectionGap),
                    if (widget.logs case final logs?) ...[
                      _LogSection(
                        logs: logs,
                        address: _logAddress,
                        exporting: _exporting,
                        onExport: _exportLogs,
                        onCrash: _confirmCrash,
                      ),
                      const SizedBox(height: DevToolsTheme.footnoteGap),
                      Text('在电脑上运行 uv run tools/logserver.py，手机和电脑连同一个 Wi-Fi。',
                          style: TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.colorsOf(context).secondaryText)),
                    ],
                    if (_speedTest case final runner? when !_speedTestStopped) ...[
                      const SizedBox(height: BiliMetrics.sectionGap),
                      _SpeedTestSection(runner: runner, links: _testLinks, onStart: _startSpeedTest),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Off-limits (Windows), it still shows the stored choice: Material leaves a disabled segment unfilled, chosen or
  /// not. Accessibility reads it as that choice, with nothing to press.
  Widget _turnTakeoverChoice() {
    final choice = SegmentedButton<bool>(
      key: const ValueKey('turn-takeover'),
      showSelectedIcon: false,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) && states.contains(WidgetState.selected)
              ? BiliColors.colorsOf(context).divider
              : null,
        ),
      ),
      segments: const [
        ButtonSegment(value: true, label: Text('自绘')),
        ButtonSegment(value: false, label: Text('系统')),
      ],
      selected: {_prefs.turnTakeover},
      onSelectionChanged: _canTakeOverTurns ? (selected) => _setTurnTakeover(selected.first) : null,
    );
    if (_canTakeOverTurns) return choice;
    return Semantics(
      container: true,
      label: _prefs.turnTakeover ? '自绘' : '系统',
      child: ExcludeSemantics(child: choice),
    );
  }

  Widget _appAuthState(AppAuth appAuth) {
    final expiresAt = appAuth.expiresAt;
    final authorized = appAuth.authorized;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          authorized && expiresAt != null
              ? '已授权 · 剩 ${expiresAt.difference(DateTime.now()).inDays} 天'
              : '未授权',
          key: const ValueKey('app-auth-state'),
          style: TextStyle(fontSize: AppAuthTheme.statusText, color: AppAuthTheme.colorsOf(context).status),
        ),
        const SizedBox(width: BiliMetrics.rowGap),
        OutlinedButton(
          key: const ValueKey('app-auth-button'),
          onPressed: () => unawaited(authorized ? appAuth.reauthorize(context) : appAuth.request(context)),
          child: Text(authorized ? '重新授权' : '授权'),
        ),
      ],
    );
  }

  /// Which feed 推荐 asks for; 官方 only while the token is held.
  Widget _feedChoice() => SegmentedButton<bool>(
        key: const ValueKey('official-feed'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: true, label: Text('官方')),
          ButtonSegment(value: false, label: Text('网页')),
        ],
        selected: {_prefs.officialFeed},
        onSelectionChanged: (selected) => setState(() => _prefs.officialFeed = selected.first),
      );

  Widget _stage(BuildContext context, PlaybackController? controller) {
    if (controller == null) {
      return _VideoNote(_startError == null ? '播放器启动中…' : '播放器启动失败：$_startError');
    }
    if (controller.video == null) {
      return _VideoNote(switch (controller.phase) {
        PlaybackPhase.loading => '正在打开…',
        PlaybackPhase.failed => controller.error ?? '播放失败',
        _ => '粘贴链接或 BV 号，点播放',
      });
    }
    return widget.stageBuilder(context, controller, showStats: _showStats, danmakuEnabled: _danmakuEnabled);
  }

  List<Widget> _playbackSection(PlaybackController controller) {
    final video = controller.video;
    final page = controller.page;
    final playing = controller.playing;
    return [
      if (video != null)
        Text(
          (video.pages.length > 1 && page != null) ? '${video.title} · P${page.page} ${page.part}' : video.title,
          style: TextStyle(fontSize: BiliMetrics.bodyText, color: BiliColors.colorsOf(context).text, fontWeight: FontWeight.w600),
        ),
      if (controller.phase == PlaybackPhase.failed && controller.video != null) ...[
        const SizedBox(height: BiliMetrics.rowGap),
        Text(controller.error ?? '播放失败',
            key: const ValueKey('playback-error'),
            style: const TextStyle(fontSize: BiliMetrics.bodyText, color: BiliColors.failure)),
      ],
      if (controller.phase == PlaybackPhase.failed && controller.playerFailure != null)
        Text('播放器：${controller.playerFailure}',
            style: TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.colorsOf(context).secondaryText)),
      const SizedBox(height: BiliMetrics.rowGap),
      Text(
        [
          controller.modeLabel,
          if (playing != null) playing.line(qualityName: controller.qualityName(playing.quality)),
          if (controller.pictureInPicture) '小窗中',
        ].join(' · '),
        style: TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.colorsOf(context).secondaryText),
      ),
      const SizedBox(height: BiliMetrics.sectionGap),
      _Card(children: [
        _Row(
          label: '加速',
          trailing: SegmentedButton<PlaybackMode>(
            key: const ValueKey('mode'),
            showSelectedIcon: false,
            segments: [
              for (final mode in PlaybackMode.values.where((mode) => mode != PlaybackMode.local))
                ButtonSegment(value: mode, label: Text(mode.label)),
            ],
            selected: {controller.mode},
            onSelectionChanged: (selected) => unawaited(controller.setMode(selected.first)),
          ),
        ),
        _Row(
          label: '显示统计',
          trailing: Switch.adaptive(
            key: const ValueKey('stats-switch'),
            activeTrackColor: BiliColors.colorsOf(context).pink,
            value: _showStats,
            onChanged: (on) => setState(() => _showStats = on),
          ),
        ),
        _Row(
          label: controller.danmaku.closed ? '弹幕（UP 主已关闭）' : '弹幕',
          trailing: Switch.adaptive(
            key: const ValueKey('danmaku-switch'),
            activeTrackColor: BiliColors.colorsOf(context).pink,
            value: _danmakuEnabled,
            onChanged: (on) => setState(() => _danmakuEnabled = on),
          ),
        ),
        if (controller.player.capabilities.pictureInPicture)
          _Row(
            label: '小窗播放',
            trailing: OutlinedButton(
              key: const ValueKey('pip-button'),
              onPressed: controller.video == null ? null : () => unawaited(controller.startPictureInPicture()),
              child: const Text('小窗'),
            ),
          ),
      ]),
      if (controller.qualities.isNotEmpty) ...[
        const SizedBox(height: BiliMetrics.sectionGap),
        _Card(children: [
          Text('清晰度', style: TextStyle(fontSize: BiliMetrics.bodyText, color: BiliColors.colorsOf(context).text)),
          const SizedBox(height: BiliMetrics.rowGap),
          Wrap(
            spacing: BiliMetrics.rowGap,
            runSpacing: BiliMetrics.rowGap,
            children: [
              for (final option in controller.qualities)
                ChoiceChip(
                  key: ValueKey('quality-${option.id}'),
                  label: Text(controller.qualityName(option.id)),
                  selected: option.id == (playing?.quality ?? controller.selectedQuality),
                  onSelected: (_) => unawaited(controller.setQuality(option.id)),
                ),
            ],
          ),
        ]),
      ],
      const SizedBox(height: BiliMetrics.sectionGap),
    ];
  }
}

class _AccountBar extends StatelessWidget {
  const _AccountBar({required this.environment});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    final label = environment.accountLabel;
    final account = environment.account;
    return Row(
      children: [
        Container(
          width: BiliMetrics.avatarSize,
          height: BiliMetrics.avatarSize,
          decoration: BoxDecoration(color: BiliColors.colorsOf(context).pinkTint, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            account is LoggedIn && label.isNotEmpty ? label.characters.first : '?',
            style: TextStyle(fontSize: BiliMetrics.bodyText, color: BiliColors.colorsOf(context).pink, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: BiliMetrics.rowGap),
        Flexible(
          child: Text(
            label,
            key: const ValueKey('account-name'),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: BiliMetrics.titleText, color: BiliColors.colorsOf(context).text, fontWeight: FontWeight.w600),
          ),
        ),
        if (account is LoggedIn && account.vip) ...[
          const SizedBox(width: BiliMetrics.rowGap),
          const _Tag('大会员'),
        ],
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: BiliColors.colorsOf(context).pinkTint, borderRadius: BorderRadius.circular(BiliMetrics.cardRadius)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BiliMetrics.tagPadding, vertical: BiliMetrics.tagVerticalPadding),
          child: Text(text, style: TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.colorsOf(context).pink)),
        ),
      );
}

class _LinkBar extends StatelessWidget {
  const _LinkBar({required this.link, required this.ready, required this.onPlay});

  final TextEditingController link;
  final bool ready;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: BiliMetrics.fieldHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('link-field'),
                controller: link,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => onPlay(),
                style: TextStyle(fontSize: BiliMetrics.bodyText, color: BiliColors.colorsOf(context).text),
                decoration: InputDecoration(
                  hintText: '粘贴链接或BV号',
                  hintStyle: TextStyle(fontSize: BiliMetrics.bodyText, color: BiliColors.colorsOf(context).secondaryText),
                  filled: true,
                  fillColor: BiliColors.colorsOf(context).card,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: BiliMetrics.gutter),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BiliMetrics.cardRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: BiliMetrics.rowGap),
            FilledButton(
              key: const ValueKey('play-button'),
              onPressed: ready ? onPlay : null,
              style: FilledButton.styleFrom(
                backgroundColor: BiliColors.colorsOf(context).pink,
                foregroundColor: BiliColors.onPink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BiliMetrics.cardRadius)),
              ),
              child: const Text('播放', style: TextStyle(fontSize: BiliMetrics.bodyText)),
            ),
          ],
        ),
      );
}

class _VideoNote extends StatelessWidget {
  const _VideoNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(BiliMetrics.gutter),
          child: Text(
            text,
            key: const ValueKey('video-note'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: BiliMetrics.bodyText, color: BiliColors.onVideo),
          ),
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: BiliColors.colorsOf(context).card, borderRadius: BorderRadius.circular(BiliMetrics.cardRadius)),
        child: Padding(
          padding: const EdgeInsets.all(BiliMetrics.gutter),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.trailing});

  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: BiliMetrics.rowGap / 2),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: TextStyle(fontSize: BiliMetrics.bodyText, color: BiliColors.colorsOf(context).text)),
            ),
            trailing,
          ],
        ),
      );
}

/// BiliNative's 开发者 section: 发送日志到电脑 with the PCs found and a typed address, 导出日志 and 测试崩溃.
class _LogSection extends StatelessWidget {
  const _LogSection({
    required this.logs,
    required this.address,
    required this.exporting,
    required this.onExport,
    required this.onCrash,
  });

  final LogForwarder logs;
  final TextEditingController address;
  final bool exporting;
  final void Function(Rect? origin) onExport;
  final VoidCallback onCrash;

  static Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: logs,
        builder: (context, _) => _Card(children: [
          _Row(
            label: '发送日志到电脑',
            trailing: Switch.adaptive(
              key: const ValueKey('log-switch'),
              activeTrackColor: BiliColors.colorsOf(context).pink,
              value: logs.enabled,
              onChanged: logs.setEnabled,
            ),
          ),
          if (logs.enabled) ...[
            for (final server in logs.discovered) _ServerTile(server: server, logs: logs),
            const SizedBox(height: BiliMetrics.rowGap),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('log-address'),
                    controller: address,
                    keyboardType: TextInputType.url,
                    onSubmitted: logs.setManual,
                    style: TextStyle(fontSize: BiliMetrics.bodyText, color: BiliColors.colorsOf(context).text),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '或手动输入 IP:端口（默认 ${LogServerEndpoint.defaultPort}）',
                      hintStyle: TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.colorsOf(context).secondaryText),
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('log-connect'),
                  onPressed: () => logs.setManual(address.text),
                  child: const Text('连接'),
                ),
              ],
            ),
          ],
          const SizedBox(height: BiliMetrics.rowGap),
          Text(logs.status,
              key: const ValueKey('log-status'),
              style: TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.colorsOf(context).secondaryText)),
          const SizedBox(height: BiliMetrics.rowGap),
          _Row(
            label: '导出日志（最近 20 MB）',
            trailing: Builder(
              builder: (button) => OutlinedButton(
                key: const ValueKey('log-export'),
                onPressed: exporting ? null : () => onExport(_originOf(button)),
                child: Text(exporting ? '准备中…' : '导出'),
              ),
            ),
          ),
          _Row(
            label: '测试崩溃',
            trailing: OutlinedButton(
              key: const ValueKey('test-crash'),
              style: OutlinedButton.styleFrom(foregroundColor: DevToolsTheme.crashInk),
              onPressed: onCrash,
              child: const Text('崩溃'),
            ),
          ),
        ]),
      );
}

/// A PC the phone found over Bonjour; tapping it sends the logs there, tapping it again goes back to the typed
/// address.
class _ServerTile extends StatelessWidget {
  const _ServerTile({required this.server, required this.logs});

  final LogServerEndpoint server;
  final LogForwarder logs;

  @override
  Widget build(BuildContext context) {
    final selected = logs.service?.host == server.host && logs.service?.port == server.port;
    return InkWell(
      key: ValueKey('log-server-${server.name}'),
      onTap: () => logs.selectService(selected ? null : server),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: BiliMetrics.rowGap),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(server.name, style: TextStyle(fontSize: BiliMetrics.bodyText, color: BiliColors.colorsOf(context).text)),
                  Text('${server.host}:${server.port}',
                      style: TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.colorsOf(context).secondaryText)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check, color: BiliColors.colorsOf(context).pink, size: BiliMetrics.iconSize),
          ],
        ),
      ),
    );
  }
}

class _SpeedTestSection extends StatelessWidget {
  const _SpeedTestSection({required this.runner, required this.links, required this.onStart});

  final SpeedTestRunner runner;
  final TextEditingController links;
  final VoidCallback onStart;

  static TextStyle _secondary(BuildContext context) => TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.colorsOf(context).secondaryText);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: runner,
        builder: (context, _) {
          final groups = GroupSummary.of(runner.results);
          final error = runner.error;
          final status = _status;
          return _Card(children: [
            _Row(
              label: '速度测试',
              trailing: runner.running
                  ? OutlinedButton(
                      key: const ValueKey('speedtest-stop'),
                      onPressed: runner.cancelled ? null : runner.stop,
                      child: const Text('停止'),
                    )
                  : FilledButton(
                      key: const ValueKey('speedtest-start'),
                      onPressed: onStart,
                      style: FilledButton.styleFrom(
                          backgroundColor: BiliColors.colorsOf(context).pink, foregroundColor: BiliColors.onPink),
                      child: const Text('开始测试'),
                    ),
            ),
            TextField(
              key: const ValueKey('speedtest-links'),
              controller: links,
              enabled: !runner.running,
              minLines: 2,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              style: TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.colorsOf(context).text),
              decoration: InputDecoration(
                isDense: true,
                hintText: '每行一个链接，留空则用电脑上的计划或当前视频',
                hintStyle: _secondary(context),
              ),
            ),
            const SizedBox(height: BiliMetrics.rowGap),
            if (status.isNotEmpty) Text(status, key: const ValueKey('speedtest-status'), style: _secondary(context)),
            if (error != null)
              Text(error,
                  key: const ValueKey('speedtest-error'),
                  style: const TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.failure)),
            for (final note in runner.notes) Text(note, style: _secondary(context)),
            for (final failed in runner.results.where((pass) => pass.failed))
              Text('第 ${failed.pass} 次（${failed.variant}）失败：${failed.failure ?? ''}', style: _secondary(context)),
            if (groups.isNotEmpty) ...[
              const SizedBox(height: BiliMetrics.rowGap),
              _SpeedTestTable(groups: groups),
              const SizedBox(height: BiliMetrics.rowGap),
              Text(
                  '时间为秒（中位数），跳转超时按 15 秒计；卡顿为各次合计；内存为峰值 MB；'
                  '冷 = 每个视频的第一次（CDN 还没缓存），热 = 之后各次',
                  style: _secondary(context)),
            ],
          ]);
        },
      );

  String get _status {
    final plan = runner.plan;
    final pass = runner.pass;
    return [
      if (plan != null) '计划 ${plan.plan.id}（${plan.source == PlanSource.pc ? '电脑' : '内置，${plan.note}'}）',
      if (pass != null) ...['第 ${pass.index}/${runner.passCount} 次', pass.variant.name, _quality(pass.quality)],
      if (runner.step.isNotEmpty) runner.step,
    ].join(' · ');
  }
}

String _quality(int qn) => QualityNames.short(qn: qn, serverText: null);

/// One row per variant, quality and cold or warm, then each later variant's difference from the first.
class _SpeedTestTable extends StatelessWidget {
  const _SpeedTestTable({required this.groups});

  final List<GroupSummary> groups;

  static TextStyle _style(BuildContext context) => TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.colorsOf(context).text);
  static TextStyle _header(BuildContext context) => TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.colorsOf(context).secondaryText);

  @override
  Widget build(BuildContext context) => Table(
        key: const ValueKey('speedtest-results'),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        columnWidths: const {2: FlexColumnWidth()},
        children: [
          _row(const ['', '首帧', '跳转 中位/P90/最慢', '回跳', '卡顿', '内存'], _header(context)),
          for (final group in groups)
            _row([
              '${group.variant} ${_quality(group.quality)} ${group.cold ? '冷' : '热'} ×${group.passes}',
              _seconds(group.firstFrameMs),
              [group.seekMedianMs, group.seekP90Ms, group.seekMaxMs].map(_seconds).join('/'),
              _seconds(group.backMedianMs),
              '${group.stalls}',
              '${group.rssMaxMB}',
            ], _style(context)),
          for (final delta in GroupDelta.of(groups))
            TableRow(children: [
              _cell(
                  '${delta.other.variant}−${delta.base.variant} ${_quality(delta.base.quality)} '
                  '${delta.base.cold ? '冷' : '热'}',
                  _style(context)),
              _cell(_signed(delta.firstFrameMs), _better(context, delta.firstFrameMs)),
              _cell([delta.seekMedianMs, delta.seekP90Ms, delta.seekMaxMs].map(_signed).join('/'),
                  _better(context, delta.seekMedianMs)),
              _cell(_signed(delta.backMedianMs), _better(context, delta.backMedianMs)),
              _cell(_signedCount(delta.stalls), _better(context, delta.stalls.toDouble())),
              _cell(_signedCount(delta.rssMaxMB), _better(context, delta.rssMaxMB.toDouble())),
            ]),
        ],
      );

  static TableRow _row(List<String> cells, TextStyle style) =>
      TableRow(children: [for (final text in cells) _cell(text, style)]);

  static Widget _cell(String text, TextStyle style) => Padding(
        padding: const EdgeInsets.only(right: BiliMetrics.rowGap, bottom: BiliMetrics.rowGap / 2),
        child: Text(text, style: style),
      );

  static String _seconds(double? ms) => ms == null ? '–' : (ms / 1000).toStringAsFixed(2);

  static String _signed(double? ms) {
    if (ms == null) return '–';
    final text = (ms.abs() / 1000).toStringAsFixed(2);
    return ms < 0 ? '−$text' : '+$text';
  }

  static String _signedCount(int value) => value < 0 ? '−${-value}' : '+$value';

  /// Lower is better in every column.
  static TextStyle _better(BuildContext context, double? difference) => TextStyle(
        fontSize: BiliMetrics.smallText,
        color: difference == null || difference == 0
            ? BiliColors.colorsOf(context).text
            : (difference < 0 ? BiliColors.faster : BiliColors.slower),
      );
}

/// 设置's white bar with ‹, so the page can be left without the edge swipe (Windows has none).
class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) {
    void back() => unawaited(Navigator.of(context).maybePop());
    return ColoredBox(
      color: SettingsTheme.colorsOf(context).bar,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: SizedBox(
          height: SettingsTheme.barHeight,
          child: Stack(
            children: [
              Center(
                child: Text(
                  '开发者',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: BiliFonts.family,
                    fontSize: SettingsTheme.barTitleText,
                    fontWeight: SettingsTheme.barTitleWeight,
                    color: SettingsTheme.colorsOf(context).barTitle,
                  ),
                ),
              ),
              Positioned(
                left: SettingsTheme.backLeft - (SettingsTheme.backTarget - SettingsTheme.backGlyphWidth) / 2,
                top: 0,
                bottom: 0,
                width: SettingsTheme.backTarget,
                child: Semantics(
                  button: true,
                  label: '返回',
                  onTap: back,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: const ValueKey('developer-back'),
                    behavior: HitTestBehavior.opaque,
                    onTap: back,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
