import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';

import '../danmaku/danmaku_filter.dart';
import '../danmaku/danmaku_segment.dart';
import '../devlog/log_event.dart';
import '../devlog/logger.dart';
import 'action_models.dart';
import 'app_signer.dart';
import 'app_token.dart';
import 'bili_error.dart';
import 'bili_hosts.dart';
import 'comment_models.dart';
import 'cookie_jar.dart';
import 'dynamic_models.dart';
import 'fav_models.dart';
import 'feed_models.dart';
import 'form_encoding.dart';
import 'http.dart';
import 'json.dart';
import 'link_parser.dart';
import 'login_models.dart';
import 'me_models.dart';
import 'models.dart';
import 'search_models.dart';
import 'skin_models.dart';
import 'space_models.dart';
import 'video_models.dart';
import 'watch_later_models.dart';
import 'wbi.dart';

part 'bili_client_actions.dart';
part 'bili_client_dynamic.dart';
part 'bili_client_app.dart';
part 'bili_client_comments.dart';
part 'bili_client_danmaku.dart';
part 'bili_client_fav.dart';
part 'bili_client_login.dart';
part 'bili_client_me.dart';
part 'bili_client_feed.dart';
part 'bili_client_feed_official.dart';
part 'bili_client_official.dart';
part 'bili_client_actions_official.dart';
part 'bili_client_search.dart';
part 'bili_client_skin.dart';
part 'bili_client_space.dart';
part 'bili_client_toview.dart';
part 'bili_client_video.dart';

typedef _Sent = ({HTTPResponse response, double ms});

typedef _FilePart = ({String field, String filename, String contentType, List<int> bytes});

final class BiliClient {
  BiliClient({required this._transport, required this.cookies, DateTime Function()? now, Logger? logger})
    : now = now ?? DateTime.now,
      _logger = logger ?? Logger.shared;

  static const userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15';
  static const referer = 'https://www.bilibili.com/';
  static Map<String, String> get mediaHeaders => {'User-Agent': userAgent, 'Referer': referer};

  /// DASH | HDR | 4K | Dolby audio | Dolby Vision | 8K | AV1.
  static const dashFnval = 4048;

  static const api = 'https://api.bilibili.com';
  static const passport = 'https://passport.bilibili.com';
  static const appAPI = 'https://app.bilibili.com';
  static const _origin = 'https://www.bilibili.com';
  static const _spiPath = '/x/frontend/finger/spi';

  final HTTPTransport _transport;
  final CookieJar cookies;
  final DateTime Function() now;
  final Logger _logger;
  ({String day, String mixin})? _wbiCache;

  int _sessionGeneration = 0;
  final Object _sessionZoneKey = Object();

  int get sessionGeneration => _sessionGeneration;

  /// Called before publishing a different login, even when its uid is unchanged.
  void invalidateSession() {
    _sessionGeneration++;
    _navOut = null;
    _wbiCache = null;
  }

  int get _requestGeneration => Zone.current[_sessionZoneKey] as int? ?? _sessionGeneration;

  void _checkSession(int generation) {
    if (generation != _sessionGeneration) throw const BiliSessionChangedError();
  }

  /// Keeps queued or multi-call work with the login that started it. A switch cancels
  /// subsequent sends and results without replaying the operation for another account.
  Future<T> runInSession<T>(int generation, Future<T> Function() body) => runZoned(() async {
    _checkSession(generation);
    try {
      final result = await body();
      _checkSession(generation);
      return result;
    } catch (_) {
      _checkSession(generation);
      rethrow;
    }
  }, zoneValues: {_sessionZoneKey: generation});

  /// The official API's login, set by the app once it has one; account calls to `app.bilibili.com` need it.
  AppToken? appToken;

  /// Called with the access token an official account call was signed with when the answer says it is no longer
  /// taken; the app drops it, unless [appToken] has changed since, and asks again.
  void Function(String accessToken)? onAppTokenRejected;

  /// The device id the official calls name (`buvid`), made once by the app and kept, so the feed learns one device.
  String? appBuvid;

  /// The cookie every write call must echo back as the `csrf` form field.
  String? get csrf {
    final token = cookies.value('bili_jct');
    return token == null || token.isEmpty ? null : token;
  }

  int get _unixSeconds => now().millisecondsSinceEpoch ~/ 1000;

  /// A logged-out reply (-101) still carries the WBI keys, so it is returned, not thrown.
  ///
  /// A call while one is out for the same login shares its answer: at launch the account check and the first signed
  /// call's WBI keys (首页's search word) would otherwise ask twice, 40 ms apart.
  Future<NavInfo> nav() {
    _checkSession(_requestGeneration);
    final session = cookies.value('SESSDATA');
    if (_navOut case (session: final asked, :final answer) when asked == session) return answer;
    late final Future<NavInfo> answer;
    answer = _fetchNav().whenComplete(() {
      if (identical(_navOut?.answer, answer)) _navOut = null;
    });
    _navOut = (session: session, answer: answer);
    return answer;
  }

  ({String? session, Future<NavInfo> answer})? _navOut;

  Future<NavInfo> _fetchNav() async {
    final generation = _requestGeneration;
    final envelope = await _getEnvelope('/x/web-interface/nav', signed: false, decode: NavInfo.fromJson);
    _checkSession(generation);
    final nav = envelope.data;
    if (nav == null) throw BiliError.api(code: envelope.code, message: envelope.message ?? '');
    final imgKey = WBI.keyFromURL(nav.imgURL);
    final subKey = WBI.keyFromURL(nav.subURL);
    final mixin = WBI.mixinKey(imgKey: imgKey, subKey: subKey);
    final valid = imgKey.isNotEmpty && subKey.isNotEmpty && mixin.length == 32;
    _wbiCache = valid ? (day: _today(), mixin: mixin) : null;
    return nav;
  }

  /// The web API answers 412 to requests without the website's fingerprint cookies.
  Future<void> ensureRiskCookies() async {
    final generation = _requestGeneration;
    _checkSession(generation);
    if (cookies.value('buvid3') != null && cookies.value('buvid4') != null) return;
    final envelope = await _getEnvelope(_spiPath, signed: false, decode: SPIInfo.fromJson);
    final spi = _checked(envelope);
    _checkSession(generation);
    if (cookies.value('buvid3') == null) cookies.set('buvid3', spi.b3);
    if (cookies.value('buvid4') == null) cookies.set('buvid4', spi.b4);
  }

  /// One of [bvid] or [aid].
  Future<VideoView> view({String? bvid, int? aid}) {
    if ((bvid == null) == (aid == null)) throw ArgumentError('view needs exactly one of bvid and aid');
    final query = bvid != null ? {'bvid': bvid} : {'aid': '$aid'};
    return get('/x/web-interface/view', query: query, signed: false, decode: VideoView.fromJson);
  }

  Future<({VideoView view, int? page})> resolve(VideoLink link) async {
    final generation = _requestGeneration;
    _checkSession(generation);
    switch (link) {
      case BvidLink(:final id, :final page):
        return (view: await view(bvid: id), page: page);
      case AidLink(:final id, :final page):
        return (view: await view(aid: id), page: page);
      case ShortLink(:final url):
        // The link parser accepts http:// share links; only https is ever requested.
        final Uri secure;
        try {
          secure = url.replace(scheme: 'https');
        } on FormatException {
          throw BiliError.invalidLink;
        }
        final response = await _sendOver(
          HTTPRequest(url: secure, headers: {'User-Agent': userAgent}),
          'resolve short link',
        );
        _checkSession(generation);
        _logger.info(LogCategory.api, 'resolve short link', {'host': secure.host, 'status': response.status});
        final next = LinkParser.parse(response.finalURL.toString());
        if (next == null || next.isShort) throw BiliError.invalidLink;
        return resolve(next);
    }
  }

  Future<PlayURLInfo> playURL({required String bvid, required int cid, required int quality}) async {
    final query = {'bvid': bvid, 'cid': '$cid', 'qn': '$quality', 'fnval': '$dashFnval', 'fnver': '0', 'fourk': '1'};
    final info = await get('/x/player/wbi/playurl', query: query, signed: true, decode: PlayURLInfo.fromJson);
    if (info.dash == null) throw BiliError.notDash;
    return info;
  }

  Future<String> _mixinKey() async {
    final cached = _wbiCache;
    if (cached != null && cached.day == _today()) return cached.mixin;
    await nav();
    final fresh = _wbiCache;
    if (fresh == null || fresh.day != _today()) {
      throw const BiliError.decoding('WBI keys missing or malformed in nav');
    }
    return fresh.mixin;
  }

  String _today() => '${_unixSeconds ~/ 86400}';

  T _checked<T>(BiliEnvelope<T> envelope) {
    final data = envelope.data;
    if (envelope.code != 0 || data == null) {
      throw BiliError.api(code: envelope.code, message: envelope.message ?? '');
    }
    return data;
  }

  Future<T> get<T>(
    String path, {
    Map<String, String> query = const {},
    required bool signed,
    String host = api,
    String? referer,
    required JsonDecode<T> decode,
  }) async =>
      _checked(await _getEnvelope(path, query: query, signed: signed, host: host, referer: referer, decode: decode));

  /// For reads whose success may carry `data: null`, which is an empty result rather than an error.
  Future<T?> _getIfPresent<T>(
    String path, {
    Map<String, String> query = const {},
    required bool signed,
    required JsonDecode<T> decode,
  }) async {
    final envelope = await _getEnvelope(path, query: query, signed: signed, decode: decode);
    if (envelope.code != 0) throw BiliError.api(code: envelope.code, message: envelope.message ?? '');
    return envelope.data;
  }

  /// For endpoints that do not answer with the JSON envelope, such as the protobuf danmaku segments.
  Future<Uint8List> getData(
    String path, {
    Map<String, String> query = const {},
    required bool signed,
    String host = api,
  }) async {
    final generation = _requestGeneration;
    final sent = await _send(method: 'GET', path: path, query: query, signed: signed, host: host, accept: '*/*');
    _checkSession(generation);
    _logger.info(LogCategory.api, path, {'status': sent.response.status, 'ms': sent.ms.round()});
    return sent.response.body;
  }

  Future<T> post<T>(
    String path, {
    Map<String, String> form = const {},
    String? referer,
    String host = api,
    bool cookies = true,
    required JsonDecode<T> decode,
  }) async =>
      _checked(await _postEnvelope(path, form: form, referer: referer, host: host, cookies: cookies, decode: decode));

  /// For writes whose success carries no data (`data` may be null).
  Future<void> postVoid(
    String path, {
    Map<String, String> form = const {},
    String? referer,
    String host = api,
    bool cookies = true,
  }) async {
    final envelope = await _postEnvelope(
      path,
      form: form,
      referer: referer,
      host: host,
      cookies: cookies,
      decode: (_) => null,
    );
    if (envelope.code != 0) throw BiliError.api(code: envelope.code, message: envelope.message ?? '');
  }

  /// The transport's timeout counts the whole body going out, so a picture of a few MB over a slow uplink needs longer.
  static const uploadTimeout = Duration(seconds: 60);

  /// An upload: [form] and [file] as multipart/form-data, with the csrf field as [post] adds it.
  Future<T> _postFile<T>(
    String path, {
    Map<String, String> form = const {},
    required _FilePart file,
    required JsonDecode<T> decode,
  }) async {
    final sent = await _send(
      method: 'POST',
      path: path,
      signed: false,
      host: api,
      form: form,
      file: file,
      accept: 'application/json',
      timeout: uploadTimeout,
    );
    return _checked(_decodeEnvelope(sent, path, decode));
  }

  Future<BiliEnvelope<T>> _getEnvelope<T>(
    String path, {
    Map<String, String> query = const {},
    required bool signed,
    String host = api,
    String? referer,
    bool sendCookies = true,
    Map<String, String> extraHeaders = const {},
    required JsonDecode<T> decode,
  }) async {
    final generation = _requestGeneration;
    final sent = await _send(
      method: 'GET',
      path: path,
      query: query,
      signed: signed,
      host: host,
      referer: referer,
      accept: 'application/json',
      sendCookies: sendCookies,
      extraHeaders: extraHeaders,
    );
    _checkSession(generation);
    return _decodeEnvelope(sent, path, decode);
  }

  Future<BiliEnvelope<T>> _postEnvelope<T>(
    String path, {
    required Map<String, String> form,
    String? referer,
    required String host,
    bool cookies = true,
    Map<String, String> extraHeaders = const {},
    required JsonDecode<T> decode,
  }) async {
    final generation = _requestGeneration;
    final sent = await _send(
      method: 'POST',
      path: path,
      signed: false,
      host: host,
      form: form,
      referer: referer,
      accept: 'application/json',
      sendCookies: cookies,
      extraHeaders: extraHeaders,
    );
    _checkSession(generation);
    return _decodeEnvelope(sent, path, decode);
  }

  /// A write whose body is JSON, as the website's newer calls take it: the csrf token goes in the query instead.
  Future<BiliEnvelope<T>> _postJsonEnvelope<T>(
    String path, {
    required Map<String, Object?> json,
    String? referer,
    required JsonDecode<T> decode,
  }) async {
    final sent = await _send(
      method: 'POST',
      path: path,
      signed: false,
      host: api,
      json: json,
      referer: referer,
      accept: 'application/json',
    );
    return _decodeEnvelope(sent, path, decode);
  }

  BiliEnvelope<T> _decodeEnvelope<T>(_Sent sent, String path, JsonDecode<T> decode) {
    try {
      final envelope = BiliEnvelope.parse(utf8.decode(sent.response.body), decode);
      _logger.info(LogCategory.api, path, {
        'status': sent.response.status,
        'code': envelope.code,
        'ms': sent.ms.round(),
      });
      return envelope;
    } on Exception catch (error) {
      if (error is! DecodeError && error is! FormatException) rethrow;
      final failure = _decodeFailure(error);
      _logger.error(LogCategory.api, '$path decode failed', {'error': failure});
      throw BiliError.decoding(failure);
    }
  }

  /// A FormatException quotes the answer it choked on, which can echo what the user searched for.
  static String _decodeFailure(Exception error) =>
      error is FormatException ? 'FormatException: ${error.message}' : '$error';

  static final _nsError = RegExp(r'\[domain=([\w.]+), code=(-?\d+)\]');

  /// The transport's failure as [BiliNetworkError], logged under [path]. Only the error's type and an NSError's
  /// domain and code, which cupertino_http writes into its message, are kept: `package:http`'s errors end with the
  /// request's URL, query and all, so the error itself never leaves here. An [Error] is a bug, not the network, and
  /// goes on as it is.
  Future<HTTPResponse> _sendOver(HTTPRequest request, String path) async {
    try {
      return await _transport.send(request);
    } on BiliError {
      // The Windows guard's refusals, which must reach the caller as they are.
      rethrow;
    } catch (error, stack) {
      if (error is! Exception) {
        _logger.error(LogCategory.api, path, {'error': '${error.runtimeType}'});
        rethrow;
      }
      final ns = _nsError.firstMatch('$error');
      final failure = BiliNetworkError(
        '${error.runtimeType}',
        domain: ns?[1],
        code: ns == null ? null : int.parse(ns[2]!),
      );
      _logger.error(LogCategory.api, path, {
        'error': failure.type,
        'domain': ?failure.domain,
        'code': ?failure.code,
      });
      Error.throwWithStackTrace(failure, stack);
    }
  }

  /// Logs the path only: the query and form can carry the csrf token or a comment the user typed.
  /// `sendCookies: false` is for the app API: no session cookies, no csrf field (its calls carry a signature and
  /// an access token instead), and no 412 retry, since fresh fingerprint cookies would not be sent anyway.
  /// [extraHeaders] add to the website's and win over them, as the official app's User-Agent does.
  Future<_Sent> _send({
    required String method,
    required String path,
    Map<String, String> query = const {},
    required bool signed,
    required String host,
    Map<String, String>? form,
    Map<String, Object?>? json,
    _FilePart? file,
    String? referer,
    required String accept,
    bool sendCookies = true,
    Map<String, String> extraHeaders = const {},
    Duration? timeout,
    bool retried = false,
  }) async {
    final generation = _requestGeneration;
    _checkSession(generation);
    // CSRF and Cookie must come from one snapshot, including while WBI loads.
    final cookieSnapshot = CookieJar(cookies.all);
    final rawCsrf = cookieSnapshot.value('bili_jct');
    final csrfSnapshot = rawCsrf == null || rawCsrf.isEmpty ? null : rawCsrf;
    Uint8List? body;
    var sentQuery = query;
    final headers = {
      'User-Agent': userAgent,
      'Referer': referer ?? BiliClient.referer,
      'Accept': accept,
      ...extraHeaders,
    };
    if (json != null) {
      if (sendCookies) {
        final token = csrfSnapshot;
        if (token == null) throw const BiliError.api(code: -101, message: '账号未登录');
        sentQuery = {...query, 'csrf': token};
        headers['Origin'] = _origin;
      }
      body = utf8.encode(jsonEncode(json));
      headers['Content-Type'] = 'application/json; charset=UTF-8';
    }
    if (form != null) {
      final fields = Map.of(form);
      if (sendCookies) {
        final token = csrfSnapshot;
        if (token == null) throw const BiliError.api(code: -101, message: '账号未登录');
        fields['csrf'] = token;
        headers['Origin'] = _origin;
      }
      if (file == null) {
        body = FormEncoding.encode(fields);
        headers['Content-Type'] = 'application/x-www-form-urlencoded; charset=UTF-8';
      } else {
        final boundary = _boundary();
        body = _multipart(fields, file, boundary);
        headers['Content-Type'] = 'multipart/form-data; boundary=$boundary';
      }
    }
    final String queryString;
    if (signed) {
      final key = await _mixinKey();
      _checkSession(generation);
      queryString = WBI.signedQuery(sentQuery, mixinKey: key, wts: _unixSeconds);
    } else {
      queryString = WBI.encodeQuery(sentQuery);
    }
    final Uri url;
    try {
      url = Uri.parse(host + path + (queryString.isEmpty ? '' : '?$queryString'));
    } on FormatException {
      throw BiliError.invalidLink;
    }
    // The session cookies and the csrf token must never leave Bilibili's own hosts.
    if (BiliHosts.isBilibili(url.host)) {
      final cookie = cookieSnapshot.headerValue;
      if (sendCookies && cookie != null) headers['Cookie'] = cookie;
    } else if (form != null || json != null) {
      throw BiliError.invalidLink;
    }
    final watch = Stopwatch()..start();
    final HTTPResponse response;
    try {
      response = await _sendOver(
        HTTPRequest(url: url, headers: headers, method: method, body: body, timeout: timeout),
        path,
      );
    } catch (_) {
      _checkSession(generation);
      rethrow;
    }
    _checkSession(generation);
    final ms = watch.elapsedMicroseconds / 1000;
    if (response.status < 200 || response.status >= 300) {
      _logger.warn(LogCategory.api, path, {'status': response.status, 'ms': ms.round()});
      // 412 is risk control; fresh fingerprint cookies usually clear it once.
      if (response.status == 412 && !retried && sendCookies && path != _spiPath) {
        cookies.remove('buvid3');
        cookies.remove('buvid4');
        await ensureRiskCookies();
        _checkSession(generation);
        return _send(
          method: method,
          path: path,
          query: query,
          signed: signed,
          host: host,
          form: form,
          json: json,
          file: file,
          referer: referer,
          accept: accept,
          sendCookies: sendCookies,
          extraHeaders: extraHeaders,
          timeout: timeout,
          retried: true,
        );
      }
      throw BiliError.http(response.status);
    }
    return (response: response, ms: ms);
  }

  static final _random = Random.secure();

  static String _boundary() =>
      'BiliFast${[for (var i = 0; i < 16; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join()}';

  static Uint8List _multipart(Map<String, String> fields, _FilePart file, String boundary) {
    final out = BytesBuilder(copy: false);
    void line(String text) => out.add(utf8.encode('$text\r\n'));
    for (final MapEntry(:key, :value) in fields.entries) {
      line('--$boundary');
      line('Content-Disposition: form-data; name="${_quoted(key)}"');
      line('');
      line(value);
    }
    line('--$boundary');
    line('Content-Disposition: form-data; name="${_quoted(file.field)}"; filename="${_quoted(file.filename)}"');
    line('Content-Type: ${file.contentType}');
    line('');
    out.add(file.bytes);
    line('');
    line('--$boundary--');
    return out.takeBytes();
  }

  /// As browsers escape a name in the header: a quote or line break would end it early.
  static String _quoted(String text) => text.replaceAll('\r', '%0D').replaceAll('\n', '%0A').replaceAll('"', '%22');
}
