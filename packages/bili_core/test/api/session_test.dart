import 'dart:async';
import 'dart:convert';

import 'package:bili_core/api.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

class _Transport implements HTTPTransport {
  final requests = <HTTPRequest>[];
  final gates = <String, Completer<void>>{};
  final replies = <String, (int, String)>{};

  @override
  Future<HTTPResponse> send(HTTPRequest request) async {
    requests.add(request);
    final reply = replies[request.url.path] ?? (200, '{"code":0,"data":{}}');
    await gates[request.url.path]?.future;
    return HTTPResponse(status: reply.$1, headers: {}, body: utf8.encode(reply.$2), finalURL: request.url);
  }
}

void main() {
  late _Transport http;
  late BiliClient client;

  setUp(() {
    http = _Transport()..replies['/x/web-interface/nav'] = (200, Fixtures.navLoggedIn);
    client = BiliClient(transport: http, cookies: CookieJar({'SESSDATA': 'session-a', 'bili_jct': 'csrf-a'}));
  });

  test('a request waiting for signing never sends with a later account', () async {
    final nav = http.gates['/x/web-interface/nav'] = Completer<void>();
    final call = client.get('/signed', signed: true, decode: (json) => json);
    final failed = expectLater(call, throwsA(isA<BiliSessionChangedError>()));
    await Future<void>.delayed(Duration.zero);
    expect(http.requests.map((request) => request.url.path), ['/x/web-interface/nav']);
    client.invalidateSession();
    client.cookies.replaceAll({'SESSDATA': 'session-b', 'bili_jct': 'csrf-b'});
    nav.complete();
    await failed;
    expect(http.requests, hasLength(1));
    await client.nav();
    expect(http.requests, hasLength(2), reason: 'the old nav cannot supply the new login cache');
  });

  test('cookie and CSRF use the same snapshot while signing loads', () async {
    final nav = http.gates['/x/web-interface/nav'] = Completer<void>();
    final call = client.get('/signed', signed: true, decode: (json) => json);
    await Future<void>.delayed(Duration.zero);
    client.cookies.set('bili_jct', 'refreshed-in-same-session');
    nav.complete();
    await call;
    expect(http.requests.last.headers['Cookie'], contains('bili_jct=csrf-a'));
  });

  test('a late 412 neither removes new risk cookies nor retries', () async {
    final held = http.gates['/old'] = Completer<void>();
    http.replies['/old'] = (412, '');
    final failed = expectLater(client.get('/old', signed: false, decode: (json) => json), throwsA(isA<BiliSessionChangedError>()));
    await Future<void>.delayed(Duration.zero);
    client.invalidateSession();
    client.cookies.replaceAll({'SESSDATA': 'session-b', 'buvid3': 'b3-new', 'buvid4': 'b4-new'});
    held.complete();
    await failed;
    expect(client.cookies.value('buvid3'), 'b3-new');
    expect(http.requests, hasLength(1));
  });

  test('a late fingerprint answer cannot write into the next jar', () async {
    const path = '/x/frontend/finger/spi';
    final held = http.gates[path] = Completer<void>();
    http.replies[path] = (200, Fixtures.spi);
    final failed = expectLater(client.ensureRiskCookies(), throwsA(isA<BiliSessionChangedError>()));
    await Future<void>.delayed(Duration.zero);
    client.invalidateSession();
    client.cookies.replaceAll({'SESSDATA': 'session-b'});
    held.complete();
    await failed;
    expect(client.cookies.all, {'SESSDATA': 'session-b'});
  });

  test('queued multi-call work stays invalid after A to B to A', () async {
    final gate = Completer<void>();
    final generation = client.sessionGeneration;
    final call = client.runInSession(generation, () async {
      await client.postVoid('/first');
      await gate.future;
      await client.postVoid('/second');
    });
    final failed = expectLater(call, throwsA(isA<BiliSessionChangedError>()));
    await Future<void>.delayed(Duration.zero);
    client.invalidateSession();
    client.cookies.replaceAll({'SESSDATA': 'session-b', 'bili_jct': 'csrf-b'});
    client.invalidateSession();
    client.cookies.replaceAll({'SESSDATA': 'session-a', 'bili_jct': 'csrf-a'});
    gate.complete();
    await failed;
    expect(http.requests.map((request) => request.url.path), ['/first']);
  });

  test('a late official rejection does not reject a restored account token', () async {
    const path = '/x/v2/view/like';
    final token = AppToken(accessToken: 'test-access', refreshToken: 'test-refresh', mid: 1,
        expiresAt: DateTime.utc(2030));
    client.appToken = token;
    final held = http.gates[path] = Completer<void>();
    http.replies[path] = (200, '{"code":-101,"message":"expired"}');
    var rejected = false;
    client.onAppTokenRejected = (_) => rejected = true;
    final failed = expectLater(client.officialLike(aid: 1, on: true), throwsA(isA<BiliSessionChangedError>()));
    await Future<void>.delayed(Duration.zero);
    client.invalidateSession();
    client.invalidateSession();
    client.appToken = token;
    held.complete();
    await failed;
    expect(rejected, isFalse);
    expect(client.appToken, token);
  });
}
