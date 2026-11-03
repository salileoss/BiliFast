part of 'bili_client.dart';

/// What the Android app 8.43.0 sends with every official call.
const _androidQuery = {
  'build': '8430300',
  'version': '8.43.0',
  'c_locale': 'zh_CN',
  'channel': 'master',
  'mobi_app': 'android',
  'platform': 'android',
  's_locale': 'zh_CN',
  'statistics': '{"appId":1,"platform":3,"version":"8.43.0","abtest":""}',
};

const _androidHeaders = {
  'User-Agent':
      'Mozilla/5.0 BiliDroid/8.43.0 (bbcallen@gmail.com) os/android model/android mobi_app/android build/8430300 '
      'channel/master innerVer/8430300 osVer/15 network/2',
  'bili-http-engine': 'cronet',
};

/// The answers that mean Bilibili no longer takes the app token (账号未登录, Access Key错误).
const _rejectedTokenCodes = {-101, -2};

/// The official app's API: signed as the Android app signs it ([AppSigner.android]) and sent without the account's
/// cookies. An account call ([account] true) carries the app token as `access_key` and throws
/// [BiliError.noAppToken] without one; a rejected token is reported through [BiliClient.onAppTokenRejected] before
/// the call throws. [query] and [form] win over the Android defaults, so a call can name its own `mobi_app`.
extension BiliClientOfficial on BiliClient {
  Future<T> _officialGet<T>(
    String path,
    Map<String, String> query,
    JsonDecode<T> decode, {
    bool account = true,
    Map<String, String> headers = const {},
  }) async {
    final generation = _requestGeneration;
    final token = _officialToken(account);
    final envelope = await _getEnvelope(
      path,
      query: _officialSigned(query, token),
      signed: false,
      host: BiliClient.appAPI,
      sendCookies: false,
      extraHeaders: _officialHeaders(headers),
      decode: decode,
    );
    _checkSession(generation);
    return _checked(_officialChecked(envelope, token));
  }

  /// A write; the signed fields go in the form, as the app sends them.
  Future<T> _officialPost<T>(
    String path,
    Map<String, String> form,
    JsonDecode<T> decode, {
    String host = BiliClient.appAPI,
    bool account = true,
    Map<String, String> headers = const {},
  }) async {
    final generation = _requestGeneration;
    final token = _officialToken(account);
    final envelope = await _postEnvelope(
      path,
      form: _officialSigned(form, token),
      host: host,
      cookies: false,
      extraHeaders: _officialHeaders(headers),
      decode: decode,
    );
    _checkSession(generation);
    return _checked(_officialChecked(envelope, token));
  }

  /// For writes whose success carries no data.
  Future<void> _officialPostVoid(
    String path,
    Map<String, String> form, {
    String host = BiliClient.appAPI,
    bool account = true,
    Map<String, String> headers = const {},
  }) async {
    final generation = _requestGeneration;
    final token = _officialToken(account);
    final envelope = await _postEnvelope(
      path,
      form: _officialSigned(form, token),
      host: host,
      cookies: false,
      extraHeaders: _officialHeaders(headers),
      decode: (_) => null,
    );
    _checkSession(generation);
    final checked = _officialChecked(envelope, token);
    if (checked.code != 0) throw BiliError.api(code: checked.code, message: checked.message ?? '');
  }

  Map<String, String> _officialHeaders(Map<String, String> headers) {
    final buvid = appBuvid;
    return {..._androidHeaders, 'buvid': ?buvid, ...headers};
  }

  /// The token an account call signs with, read once, so a rejection names that one even if [appToken] has changed
  /// by the time the answer comes; null for a call without the account.
  AppToken? _officialToken(bool account) {
    if (!account) return null;
    return appToken ?? (throw BiliError.noAppToken);
  }

  Map<String, String> _officialSigned(Map<String, String> params, AppToken? token) =>
      AppSigner.android.signed({..._androidQuery, ...params, 'access_key': ?token?.accessToken}, ts: _unixSeconds);

  BiliEnvelope<T> _officialChecked<T>(BiliEnvelope<T> envelope, AppToken? token) {
    if (token != null && _rejectedTokenCodes.contains(envelope.code)) {
      _logger.warn(LogCategory.api, 'app token rejected', {'code': envelope.code});
      onAppTokenRejected?.call(token.accessToken);
    }
    return envelope;
  }
}
