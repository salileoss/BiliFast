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
