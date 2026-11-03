import 'package:bili_core/devlog.dart';
import 'package:flutter/services.dart';

import 'account_vault.dart';
import 'dpapi_keychain_store.dart';
import 'keychain_store.dart';

const _unreadable = -1;
const _malformed = -2;
const _unsupported = -3;

/// A new Keychain item, kept separate from the legacy login until migration succeeds.
class ChannelAccountVaultStore implements AccountVaultStore {
  ChannelAccountVaultStore([MethodChannel? channel, Logger? logger])
    : _channel = channel ?? const MethodChannel('bilifast/keychain'),
      _logger = logger ?? Logger.shared;

  final MethodChannel _channel;
  final Logger _logger;

  @override
  Future<AccountVaultLoad> load() async {
    try {
      final reply = await _channel.invokeMapMethod<String, Object?>('loadAccountVault');
      if (reply?['status'] == 'notFound') return const NoAccountVault();
      if (reply?['status'] != 'vault') {
        return AccountVaultLoadFailed(reply?['code'] is int ? reply!['code']! as int : _unreadable);
      }
      final text = reply?['vault'];
      if (text is! String) return const AccountVaultLoadFailed(_malformed);
      return _decode(text);
    } catch (_) {
      _logger.error(LogCategory.app, 'account vault read failed', {'status': _unreadable});
      return const AccountVaultLoadFailed(_unreadable);
    }
  }

  @override
  Future<bool> save(AccountVault vault) async {
    try {
      final reply = await _channel.invokeMapMethod<String, Object?>(
        'saveAccountVault', {'vault': encodeAccountVault(vault)},
      );
      if (reply?['ok'] == true) return true;
    } catch (_) {
      // Exception messages can contain the payload; only a fixed failure reaches the log.
    }
    _logger.error(LogCategory.app, 'account vault write failed');
    return false;
  }
}

/// Uses the same DPAPI protection and atomic file replacement as the PC's legacy login.
/// The encrypted payload has one field containing the versioned vault document.
class DpapiAccountVaultStore implements AccountVaultStore {
  DpapiAccountVaultStore(this.path, {Logger? logger}) : _storage = DpapiKeychainStore(path, logger: logger);

  final String path;
  final DpapiKeychainStore _storage;

  @override
  Future<AccountVaultLoad> load() async {
    switch (await _storage.loadCookies()) {
      case NoStoredCookies():
        return const NoAccountVault();
      case CookieLoadFailed(:final status):
        return AccountVaultLoadFailed(status);
      case StoredCookies(:final cookies):
        final text = cookies['vault'];
        if (cookies.length != 1 || text == null) return const AccountVaultLoadFailed(_malformed);
        final loaded = _decode(text);
        if (loaded case StoredAccountVault(:final vault) when vault.accounts.values.any((entry) => entry.appToken != null)) {
          return const AccountVaultLoadFailed(_malformed);
        }
        return loaded;
    }
  }

  @override
  Future<bool> save(AccountVault vault) async {
    // Official app tokens never belong in the PC's credential file.
    if (vault.accounts.values.any((entry) => entry.appToken != null)) return false;
    try {
      return await _storage.saveCookies({'vault': encodeAccountVault(vault)});
    } catch (_) {
      return false;
    }
  }
}

AccountVaultLoad _decode(String text) {
  try {
    return StoredAccountVault(decodeAccountVault(text));
  } on UnsupportedAccountVaultVersion {
    return const AccountVaultLoadFailed(_unsupported);
  } catch (_) {
    return const AccountVaultLoadFailed(_malformed);
  }
}
