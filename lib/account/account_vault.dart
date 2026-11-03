import 'dart:convert';

import 'package:bili_core/api.dart';

/// A remembered web login and the optional official-app authorization for the same uid.
final class SavedAccount {
  SavedAccount({
    required this.mid,
    required this.name,
    required Map<String, String> cookies,
    this.face,
    this.vip = false,
    this.appToken,
    this.authDeclined = false,
    this.expired = false,
  }) : cookies = Map.unmodifiable(cookies);

  final int mid;
  final String name;
  final String? face;
  final bool vip;
  final Map<String, String> cookies;
  final AppToken? appToken;
  final bool authDeclined;
  final bool expired;

  factory SavedAccount.fromJson(Object? json) {
    if (json is! Map<String, Object?>) throw const FormatException('invalid saved account');
    final mid = json['mid'];
    final name = json['name'];
    final face = json['face'];
    final cookies = json['cookies'];
    final vip = json['vip'];
    final declined = json['auth_declined'];
    final expired = json['expired'];
    if (mid is! int || mid <= 0 || name is! String ||
        (face != null && face is! String) || cookies is! Map<String, Object?> ||
        cookies.keys.any((key) => key.isEmpty) || cookies.values.any((value) => value is! String) ||
        vip is! bool || declined is! bool || expired is! bool) {
      throw const FormatException('invalid saved account');
    }
    final token = json['app_token'] == null ? null : AppToken.fromJson(json['app_token']);
    if (token != null && token.mid != mid) throw const FormatException('app token owner mismatch');
    return SavedAccount(
      mid: mid,
      name: name,
      face: face as String?,
      cookies: cookies.cast<String, String>(),
      vip: vip,
      appToken: token,
      authDeclined: declined,
      expired: expired,
    );
  }

  Map<String, Object?> toJson() {
    if (mid <= 0 || cookies.keys.any((key) => key.isEmpty) || (appToken != null && appToken!.mid != mid)) {
      throw const FormatException('invalid saved account');
    }
    return {
      'mid': mid,
      'name': name,
      'face': face,
      'vip': vip,
      'cookies': cookies,
      'app_token': appToken?.toJson(),
      'auth_declined': authDeclined,
      'expired': expired,
    };
  }

  SavedAccount copyWith({
    String? name,
    String? face,
    bool? vip,
    Map<String, String>? cookies,
    AppToken? appToken,
    bool clearToken = false,
    bool? authDeclined,
    bool? expired,
  }) => SavedAccount(
    mid: mid,
    name: name ?? this.name,
    face: face ?? this.face,
    vip: vip ?? this.vip,
    cookies: cookies ?? this.cookies,
    appToken: clearToken ? null : appToken ?? this.appToken,
    authDeclined: authDeclined ?? this.authDeclined,
    expired: expired ?? this.expired,
  );

  @override
  String toString() => 'SavedAccount';
}

/// The secure store is authoritative even when the collection is empty.
final class AccountVault {
  AccountVault({this.activeMid, Map<int, SavedAccount> accounts = const {}})
    : accounts = Map.unmodifiable(accounts);

  final int? activeMid;
  final Map<int, SavedAccount> accounts;

  static const version = 1;

  factory AccountVault.fromJson(Object? json) {
    if (json is! Map<String, Object?> || json['version'] is! int) {
      throw const FormatException('invalid account vault');
    }
    if (json['version'] != version) throw const UnsupportedAccountVaultVersion();
    final active = json['active_mid'];
    final entries = json['accounts'];
    if ((active != null && active is! int) || entries is! Map<String, Object?>) {
      throw const FormatException('invalid account vault');
    }
    final accounts = <int, SavedAccount>{};
    for (final entry in entries.entries) {
      final saved = SavedAccount.fromJson(entry.value);
      if (entry.key != '${saved.mid}') throw const FormatException('account key mismatch');
      accounts[saved.mid] = saved;
    }
    if (active != null && !accounts.containsKey(active)) throw const FormatException('active account missing');
    return AccountVault(activeMid: active as int?, accounts: accounts);
  }

  Map<String, Object?> toJson() {
    if ((activeMid != null && !accounts.containsKey(activeMid)) ||
        accounts.entries.any((entry) => entry.key != entry.value.mid)) {
      throw const FormatException('invalid account vault');
    }
    return {
      'version': version,
      'active_mid': activeMid,
      'accounts': {for (final entry in accounts.entries) '${entry.key}': entry.value.toJson()},
    };
  }

  @override
  String toString() => 'AccountVault';
}

/// Separate from corrupt data, so a newer schema is never mistaken for an empty store.
final class UnsupportedAccountVaultVersion implements Exception {
  const UnsupportedAccountVaultVersion();
  @override
  String toString() => 'UnsupportedAccountVaultVersion';
}

String encodeAccountVault(AccountVault vault) => jsonEncode(vault.toJson());

AccountVault decodeAccountVault(String text) {
  try {
    return AccountVault.fromJson(jsonDecode(text));
  } on FormatException {
    // jsonDecode's FormatException includes its source, which contains credentials.
    throw const FormatException('invalid account vault');
  }
}

sealed class AccountVaultLoad {
  const AccountVaultLoad();
}

final class StoredAccountVault extends AccountVaultLoad {
  const StoredAccountVault(this.vault);
  final AccountVault vault;
}

final class NoAccountVault extends AccountVaultLoad {
  const NoAccountVault();
}

final class AccountVaultLoadFailed extends AccountVaultLoad {
  const AccountVaultLoadFailed(this.status);
  final int status;
}

abstract interface class AccountVaultStore {
  Future<AccountVaultLoad> load();
  Future<bool> save(AccountVault vault);
}

/// Used by fake accounts and tests; never opens platform credential storage.
class MemoryAccountVaultStore implements AccountVaultStore {
  MemoryAccountVaultStore([this.vault]);

  AccountVault? vault;

  @override
  Future<AccountVaultLoad> load() async => vault == null ? const NoAccountVault() : StoredAccountVault(vault!);

  @override
  Future<bool> save(AccountVault vault) async {
    this.vault = vault;
    return true;
  }
}
