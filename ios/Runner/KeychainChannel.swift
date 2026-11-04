import Flutter
import Foundation
import Security

/// The old Swift login items remain readable for migration. Saved accounts use a separate
/// versioned vault item; Dart commits it before removing the legacy items.
/// Values never cross into logs: errors report only the OSStatus.
enum KeychainChannel {
  private static let cookieService = "com.kaichuan.bilinative.cookies"
  private static let tokenService = "com.kaichuan.bilinative.apptoken"
  private static let vaultService = "com.kaichuan.bilifast.accounts"
  private static let account = "bilibili"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "bilifast/keychain", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let arguments = call.arguments as? [String: Any]
      switch call.method {
      case "loadCookies":
        result(loadCookies())
      case "saveCookies":
        // An empty map deletes the login, so a malformed argument must never read as one.
        guard let cookies = arguments?["cookies"] as? [String: String] else {
          result(["ok": false, "code": Int(errSecParam)])
          return
        }
        result(saveCookies(cookies))
      case "deleteCookies":
        result(deleteError(delete(cookieService)))
      case "loadAppToken":
        result(loadAppToken())
      case "saveAppToken":
        guard let token = arguments?["token"] as? String else {
          result(["ok": false, "code": Int(errSecParam)])
          return
        }
        result(saveAppToken(token))
      case "deleteAppToken":
        result(deleteError(delete(tokenService)))
      case "loadAccountVault":
        let (status, data) = load(vaultService)
        if status == errSecItemNotFound {
          result(["status": "notFound"])
        } else if status != errSecSuccess {
          result(["status": "failed", "code": Int(status)])
        } else if let data, let vault = String(data: data, encoding: .utf8), !vault.isEmpty {
          result(["status": "vault", "vault": vault])
        } else {
          result(["status": "failed", "code": Int(errSecDecode)])
        }
      case "saveAccountVault":
        guard let vault = arguments?["vault"] as? String, !vault.isEmpty else {
          result(["ok": false, "code": Int(errSecParam)])
          return
        }
        // Even an empty account collection is a document: absence would revive a legacy login.
        result(save(Data(vault.utf8), service: vaultService))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func query(_ service: String) -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: service,
     kSecAttrAccount as String: account]
  }

  /// An item that isn't there counts as deleted.
  private static func delete(_ service: String) -> OSStatus {
    let status = SecItemDelete(query(service) as CFDictionary)
    return status == errSecItemNotFound ? errSecSuccess : status
  }

  /// nil (Dart's void) once deleted; otherwise an error Dart throws as a PlatformException.
  private static func deleteError(_ status: OSStatus) -> FlutterError? {
    status == errSecSuccess
      ? nil
      : FlutterError(code: "keychain", message: "delete failed", details: Int(status))
  }

  private static func load(_ service: String) -> (OSStatus, Data?) {
    var q = query(service)
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(q as CFDictionary, &item)
    return (status, item as? Data)
  }

  /// errSecInteractionNotAllowed before the first unlock is a failure, not "logged out": the stored
  /// cookies may still be there, and the Dart side then blocks writes so it can't wipe them.
  private static func loadCookies() -> [String: Any] {
    let (status, data) = load(cookieService)
    if status == errSecItemNotFound { return ["status": "notFound"] }
    guard status == errSecSuccess else { return ["status": "failed", "code": Int(status)] }
    guard let data,
          let cookies = try? JSONDecoder().decode([String: String].self, from: data) else {
      return ["status": "failed", "code": Int(errSecDecode)]
    }
    return ["status": "cookies", "cookies": cookies]
  }

  private static func saveCookies(_ cookies: [String: String]) -> [String: Any] {
    if cookies.isEmpty {
      let status = delete(cookieService)
      return status == errSecSuccess ? ["ok": true] : ["ok": false, "code": Int(status)]
    }
    guard let data = try? JSONEncoder().encode(cookies) else {
      return ["ok": false, "code": Int(errSecParam)]
    }
    return save(data, service: cookieService)
  }

  private static func loadAppToken() -> [String: Any] {
    let (status, data) = load(tokenService)
    guard status == errSecSuccess else {
      return status == errSecItemNotFound ? [:] : ["code": Int(status)]
    }
    guard let data, let token = String(data: data, encoding: .utf8), !token.isEmpty else {
      return ["code": Int(errSecDecode)]
    }
    return ["token": token]
  }

  private static func saveAppToken(_ token: String) -> [String: Any] {
    guard !token.isEmpty else {
      let status = delete(tokenService)
      return status == errSecSuccess ? ["ok": true] : ["ok": false, "code": Int(status)]
    }
    return save(Data(token.utf8), service: tokenService)
  }

  private static func save(_ data: Data, service: String) -> [String: Any] {
    let attributes: [String: Any] = [kSecValueData as String: data,
                                     kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
    var status = SecItemUpdate(query(service) as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      status = SecItemAdd(query(service).merging(attributes) { $1 } as CFDictionary, nil)
    }
    return status == errSecSuccess ? ["ok": true] : ["ok": false, "code": Int(status)]
  }
}
