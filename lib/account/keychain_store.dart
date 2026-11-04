import 'dart:io' show Platform;

import 'package:bili_core/devlog.dart';
import 'package:flutter/services.dart';

sealed class CookieLoad {
  const CookieLoad();
}

final class StoredCookies extends CookieLoad {
  const StoredCookies(this.cookies);
  final Map<String, String> cookies;
}

final class NoStoredCookies extends CookieLoad {
  const NoStoredCookies();
}

/// The keychain refused (e.g. errSecInteractionNotAllowed before the first unlock). The stored cookies may
/// still be there, so callers must not overwrite them.
final class CookieLoadFailed extends CookieLoad {
  const CookieLoadFailed(this.status);
  final int status;
}

/// The keychain items the Swift BiliFast wrote (`ios/Runner/KeychainChannel.swift`), so its login carries over.
abstract interface class KeychainStore {
  Future<CookieLoad> loadCookies();

  /// An empty map deletes the item. Returns whether the keychain took it.
  Future<bool> saveCookies(Map<String, String> cookies);

  /// Throws when the keychain refused the delete; an item that wasn't there counts as deleted.
  Future<void> deleteCookies();

  /// The official API's access token; null when absent. An unreadable item throws so migration retains it.
  Future<String?> loadAppToken();
  Future<bool> saveAppToken(String token);
  /// Throws as [deleteCookies].
  Future<void> deleteAppToken();

  /// The iOS keychain on the phone; elsewhere (the Windows development build) nothing is stored and the app
  /// runs logged out.
  factory KeychainStore.platform() => Platform.isIOS ? ChannelKeychainStore() : const NoKeychainStore();
}

/// A refused delete comes back as a `FlutterError`, which the channel throws as a [PlatformException].
class ChannelKeychainStore implements KeychainStore {
  ChannelKeychainStore([MethodChannel? channel, Logger? logger])
    : _channel = channel ?? const MethodChannel('bilifast/keychain'),
      _logger = logger ?? Logger.shared;

  final MethodChannel _channel;
  final Logger _logger;

  @override
  Future<CookieLoad> loadCookies() async {
    final reply = await _channel.invokeMapMethod<String, Object?>('loadCookies') ?? const {};
    switch (reply['status']) {
      case 'cookies':
        final cookies = reply['cookies'];
        if (cookies is Map) {
          return StoredCookies({for (final e in cookies.entries) '${e.key}': '${e.value}'});
        }
        return const CookieLoadFailed(-26275); // errSecDecode
      case 'notFound':
        return const NoStoredCookies();
      default:
        return CookieLoadFailed(reply['code'] as int? ?? 0);
    }
  }

  @override
  Future<bool> saveCookies(Map<String, String> cookies) async {
    final reply = await _channel.invokeMapMethod<String, Object?>('saveCookies', {'cookies': cookies});
    if (reply?['ok'] == true) return true;
    // The OSStatus goes no further than this reply.
    final code = reply?['code'];
    _logger.error(LogCategory.app, 'keychain cookie write failed', {'status': code is int ? code : 0});
    return false;
  }

  @override
  Future<void> deleteCookies() => _channel.invokeMethod<void>('deleteCookies');

  @override
  Future<String?> loadAppToken() async {
    final reply = await _channel.invokeMapMethod<String, Object?>('loadAppToken');
    if (reply?['code'] case final int status) {
      throw PlatformException(code: 'keychain', message: 'app token read failed', details: status);
    }
    final token = reply?['token'];
    return token is String && token.isNotEmpty ? token : null;
  }

  @override
  Future<bool> saveAppToken(String token) async {
    final reply = await _channel.invokeMapMethod<String, Object?>('saveAppToken', {'token': token});
    return reply?['ok'] == true;
  }

  @override
  Future<void> deleteAppToken() => _channel.invokeMethod<void>('deleteAppToken');
}

class NoKeychainStore implements KeychainStore {
  const NoKeychainStore();

  @override
  Future<CookieLoad> loadCookies() async => const NoStoredCookies();
  /// Nothing to store is not a failed write.
  @override
  Future<bool> saveCookies(Map<String, String> cookies) async => true;
  @override
  Future<void> deleteCookies() async {}
  @override
  Future<String?> loadAppToken() async => null;
  @override
  Future<bool> saveAppToken(String token) async => false;
  @override
  Future<void> deleteAppToken() async {}
}
