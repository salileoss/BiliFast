import 'dart:async';

import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/login_gate.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/devtools/log_files.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/playback/codec_memory.dart';
import 'package:bilifast/playback/playback_controller.dart';
import 'package:bilifast/playback/shared_engine.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/shared/image_disk_cache.dart';
import 'package:bilifast/video/fake_page_api.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../playback/fakes.dart';

/// The account half 设置 reads, without a keychain or a network: the state is set by the test, and [logout] records
/// the call and ends logged out, as the real one does.
class FakeEnvironment extends ChangeNotifier implements AppEnvironment {
  FakeEnvironment(this._account);

  Account _account;
  int logouts = 0;
  int refreshes = 0;

  @override
  bool accountCheckFailed = false;

  /// Thrown by the next [logout].
  Object? logoutError;

  @override
  Account get account => _account;

  @override
  ValueListenable<int> get logins => _logins;
  final _logins = ValueNotifier<int>(0);

  @override
  ValueListenable<int> get sessions => _sessions;
  final _sessions = ValueNotifier<int>(0);
  @override
  int get sessionGeneration => _sessions.value;
  @override
  bool get hasAccountVault => false;
  @override
  bool get accountTransitioning => false;
  @override
  int? get activeAccountMid => null;
  @override
  Future<void> Function()? beforeAccountChange;
  @override
  VoidCallback? accountChangeAborted;

  set account(Account value) {
    _account = value;
    notifyListeners();
  }

  @override
  String get accountLabel => switch (_account) {
    LoggedIn(:final name) => name,
    LoggedOut() => '未登录',
    LoginExpired() => '登录已失效',
    AccountUnknown() => accountCheckFailed ? '账号确认失败' : '正在确认账号…',
  };

  @override
  Future<bool> refreshAccount() async {
    refreshes += 1;
    return false;
  }

  @override
  bool logoutIncomplete = false;

  @override
  bool loginUnreadable = false;

  @override
  bool loginSaved = true;

  /// As the real one: every step runs and the account ends logged out, then a keychain that kept the login throws.
  @override
  Future<void> logout() async {
    logouts += 1;
    logoutIncomplete = false;
    final error = logoutError;
    account = const LoggedOut();
    if (error != null) {
      logoutError = null;
      logoutIncomplete = true;
      notifyListeners();
      throw error;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLoginGate implements LoginGate {
  int requests = 0;

  @override
  Future<bool> request(BuildContext context) async {
    requests += 1;
    return false;
  }
}

class FakeLogFiles implements LogFiles {
  int clears = 0;

  @override
  Future<void> clear() async => clears += 1;

  @override
  Future<String?> export() async => null;
}

/// Pictures kept on the phone, without a folder: [size] bytes until [clear] empties them, or throws [clearError].
class FakeImageDiskCache extends ImageDiskCache {
  FakeImageDiskCache(this.size) : super(folder: 'unused');

  int size;
  int clears = 0;
  Object? clearError;

  @override
  Future<int> sizeBytes() async => size;

  @override
  Future<void> clear() async {
    clears += 1;
    if (clearError case final error?) throw error;
    size = 0;
  }
}

/// 设置's world: the app's players, with no page open, on the [shared] engine (the fake [engine], running unless a
/// [startGate] holds its start until the test completes it) and the codec [memory]; an empty 最近打开 and the fakes
/// above.
class SettingsWorld {
  SettingsWorld._(this.services, this.environment, this.gate, this.logFiles, this.engine, this.shared, this.memory);

  static Future<SettingsWorld> create({
    Account account = const LoggedOut(),
    Completer<void>? startGate,
    ImageDiskCache? imageCache,
  }) async {
    final environment = FakeEnvironment(account);
    final gate = FakeLoginGate();
    final logFiles = FakeLogFiles();
    final engine = FakeEngine();
    final memory = CodecMemory();
    final logger = Logger(session: 'test');
    final shared = SharedEngine(() async {
      await startGate?.future;
      return engine;
    }, logger: logger);
    final playback = AppPlayback(
      () => Completer<PlaybackController>().future,
      engine: shared,
      codecMemory: memory,
      logger: logger,
    );
    if (startGate == null) await shared.current();
    final services = AppServices(
      environment: environment,
      playback: playback,
      recents: await RecentStore.load(null),
      fonts: FontStore.memory(logger: logger),
      pageApi: FakePageApi(),
      loginGate: gate,
      imageCache: imageCache,
      logFiles: logFiles,
    );
    return SettingsWorld._(services, environment, gate, logFiles, engine, shared, memory);
  }

  final AppServices services;
  final FakeEnvironment environment;
  final FakeLoginGate gate;
  final FakeLogFiles logFiles;
  final FakeEngine engine;
  final SharedEngine shared;
  final CodecMemory memory;

  void dispose() => services.playback.dispose();
}

const sampleRecent = RecentVideo(bvid: 'BV1GJ411x7h7', cid: 1, title: '一个视频', part: '', page: 1, pageCount: 1);
