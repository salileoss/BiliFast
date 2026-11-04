import 'guarded_transport.dart';

sealed class BiliError implements Exception {
  const BiliError();

  const factory BiliError.http(int status) = BiliHTTPError;
  const factory BiliError.api({required int code, required String message}) = BiliAPIError;
  const factory BiliError.decoding(String detail) = BiliDecodingError;
  static const BiliError notDash = BiliNotDashError();
  static const BiliError invalidLink = BiliInvalidLinkError();

  /// An official-API account call with no app token yet (or one just dropped as rejected).
  static const BiliError noAppToken = BiliNoAppTokenError();

  const factory BiliError.network(String type, {String? domain, int? code}) = BiliNetworkError;

  bool get needsLogin => switch (this) {
    BiliAPIError(code: -101) => true,
    _ => false,
  };

  String get userMessage => switch (this) {
    BiliHTTPError(status: 412) => 'B 站暂时拒绝了请求（风控），稍后再试',
    BiliHTTPError(:final status) => '网络请求失败（HTTP $status）',
    BiliAPIError(code: -101) => '需要登录',
    BiliAPIError(code: -352 || -412) => '请求过于频繁，请稍后再试',
    BiliAPIError(code: -404 || 62002 || 62004) => '视频不存在或已被删除',
    // The Windows guard's refusals never reached Bilibili.
    BiliAPIError(code: GuardedTransport.readOnlyCode || GuardedTransport.capCode, :final message) => message,
    BiliAPIError(:final code, :final message) => 'B 站返回错误 $code：$message',
    BiliDecodingError() => 'B 站返回的数据无法解析',
    BiliNotDashError() => '这个视频不是 DASH 格式，暂不支持',
    BiliInvalidLinkError() => '没有找到视频链接',
    BiliNoAppTokenError() => '需要先授权官方接口',
    BiliNetworkError() => '网络连接失败，请检查网络后重试',
    BiliSessionChangedError() => '账号已切换，请重试',
  };
}

/// Work belonging to a previous login must not continue with the current credentials.
final class BiliSessionChangedError extends BiliError {
  const BiliSessionChangedError();

  @override
  String toString() => 'BiliSessionChangedError';
}

final class BiliHTTPError extends BiliError {
  const BiliHTTPError(this.status);

  final int status;

  @override
  bool operator ==(Object other) => other is BiliHTTPError && other.status == status;

  @override
  int get hashCode => status.hashCode;

  @override
  String toString() => 'BiliError.http($status)';
}

final class BiliAPIError extends BiliError {
  const BiliAPIError({required this.code, required this.message});

  final int code;
  final String message;

  @override
  bool operator ==(Object other) => other is BiliAPIError && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'BiliError.api($code, $message)';
}

final class BiliDecodingError extends BiliError {
  const BiliDecodingError(this.detail);

  final String detail;

  @override
  bool operator ==(Object other) => other is BiliDecodingError && other.detail == detail;

  @override
  int get hashCode => detail.hashCode;

  @override
  String toString() => 'BiliError.decoding($detail)';
}

final class BiliNotDashError extends BiliError {
  const BiliNotDashError();

  @override
  String toString() => 'BiliError.notDash';
}

final class BiliInvalidLinkError extends BiliError {
  const BiliInvalidLinkError();

  @override
  String toString() => 'BiliError.invalidLink';
}

final class BiliNoAppTokenError extends BiliError {
  const BiliNoAppTokenError();

  @override
  String toString() => 'BiliError.noAppToken';
}

/// The request got no answer: offline, timed out, refused. It keeps only the transport error's type and an NSError's
/// domain and code, because the transport's own words end with the request's URL, and an official call's query
/// carries the app token.
final class BiliNetworkError extends BiliError {
  const BiliNetworkError(this.type, {this.domain, this.code});

  /// The transport error's runtime type, such as `TimeoutException` or `NSErrorClientException`.
  final String type;
  final String? domain;
  final int? code;

  @override
  bool operator ==(Object other) =>
      other is BiliNetworkError && other.type == type && other.domain == domain && other.code == code;

  @override
  int get hashCode => Object.hash(type, domain, code);

  @override
  String toString() => domain == null ? 'BiliError.network($type)' : 'BiliError.network($type, $domain $code)';
}
