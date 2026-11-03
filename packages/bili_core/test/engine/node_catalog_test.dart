import 'package:bili_core/engine.dart';
import 'package:test/test.dart';

const _primary = 'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/1/2/3/v.m4s?deadline=9&os=cosbv&upsig=x';
const _backup = 'https://upos-sz-mirrorali.bilivideo.com/upgcxcode/1/2/3/v.m4s?deadline=9&os=alibv';

bool _allows(String text) => MediaURLPolicy.bilibili.allowsURL(text);

List<String> _urls(String primary, List<String> backups, NodeMode mode, [MediaURLPolicy policy = MediaURLPolicy.bilibili]) =>
    NodeCatalog.representationURLs(primary: primary, backups: backups, mode: mode, policy: policy);

void main() {
  test('auto preserves exact ordinary addresses and includes both regional pools', () {
    const edge = 'https://upos-hz-mirrorakam.akamaized.net/upgcxcode/v.m4s?hdnts=a%2Fb&deadline=9';
    final urls = _urls(edge, [_primary, _backup], NodeMode.auto);
    expect(urls.take(3), [edge, _primary, _backup]);
    expect(urls.map(NodeCatalog.host).toSet(), containsAll([...NodeCatalog.overseas, ...NodeCatalog.mainland]));
    expect(urls.toSet(), hasLength(urls.length));
    expect(_urls('https://evil.example.com/v.m4s', [], NodeMode.auto), isEmpty);
  });

  test('overseas swaps the signed address onto overseas nodes', () {
    final urls = _urls(_primary, [_backup], NodeMode.overseas);
    expect(urls.map(NodeCatalog.host), NodeCatalog.overseas);
    expect(urls.every((url) => NodeCatalog.address(url) == '/upgcxcode/1/2/3/v.m4s?deadline=9&os=cosbv&upsig=x'), isTrue);
  });

  test('mainland keeps originals first and deduplicates', () {
    final urls = _urls(_primary, [_backup], NodeMode.mainland);
    expect(urls.take(2), [_primary, _backup]);
    expect(urls, hasLength(9));
    expect(urls.toSet(), hasLength(urls.length));
  });

  test('akamai-only addresses become donors', () {
    const akamai = 'https://upos-hz-mirrorakam.akamaized.net/upgcxcode/1/2/3/v.m4s?deadline=9&os=akam&hdnts=x';
    final urls = _urls(akamai, [], NodeMode.overseas);
    expect(urls.first, akamai);
    expect(urls, hasLength(1 + NodeCatalog.overseas.length));
    expect(NodeCatalog.swapHost(akamai, NodeAddress('upos-sz-mirrorcosov.bilivideo.com')), isNull);
  });

  test('swap clears a non-standard port', () {
    const withPort = 'https://upos-sz-mirrorcos.bilivideo.com:4483/upgcxcode/v.m4s?deadline=9';
    expect(NodeCatalog.swapHost(withPort, NodeAddress('upos-sz-mirrorcosov.bilivideo.com')),
        'https://upos-sz-mirrorcosov.bilivideo.com/upgcxcode/v.m4s?deadline=9');
  });

  test('swap keeps the signed path and query byte for byte', () {
    const query = 'deadline=9&gen=playurlv3&upsig=a%2Fb%2Bc+d%3D%3D&hdnts=exp%3D1~acl%3D%2F*&e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfq';
    const path = '/upgcxcode/1/2/3%2F4/v%20x.m4s';
    const signed = 'https://upos-sz-mirrorcos.bilivideo.com$path?$query';
    expect(NodeCatalog.swapHost(signed, NodeAddress('upos-sz-mirrorcosov.bilivideo.com')),
        'https://upos-sz-mirrorcosov.bilivideo.com$path?$query');
    expect(NodeCatalog.address(signed), '$path?$query');
  });

  test('policy rejects foreign hosts', () {
    expect(_urls('https://evil.example.com/v.m4s', [], NodeMode.overseas), isEmpty);
    expect(_allows('http://upos-sz-mirrorcos.bilivideo.com/v.m4s'), isFalse);
    expect(_allows('https://upos-sz-mirrorcos.bilivideo.com/v.txt'), isFalse);
  });

  test('custom nodes with ports for tests', () {
    const local = 'http://127.0.0.1:9001/v.mp4?deadline=1';
    final urls = _urls(
      local,
      [],
      CustomNodes([NodeAddress('127.0.0.1', port: 9001), NodeAddress('127.0.0.1', port: 9002)]),
      MediaURLPolicy.any,
    );
    expect(urls, [local, 'http://127.0.0.1:9002/v.mp4?deadline=1']);
    expect(urls.map(NodeCatalog.nodeKey), ['127.0.0.1:9001', '127.0.0.1:9002']);
  });

  test('policy accepts plain hosts in any case', () {
    expect(_allows('https://upos-sz-mirrorcos.bilivideo.com/v.m4s?deadline=1'), isTrue);
    expect(_allows('https://UPOS-SZ-MIRRORCOS.BILIVIDEO.COM/V.M4S'), isTrue);
    expect(_allows('https://bilivideo.com/v.mp4'), isTrue);
  });

  test('policy rejects look-alike hosts', () {
    expect(_allows('https://bilivideo.com.evil.com/v.m4s'), isFalse);
    expect(_allows('https://evilbilivideo.com/v.m4s'), isFalse);
    expect(_allows('https://upos-sz-mirrorcos.bilivideo.com.evil.com/v.m4s'), isFalse);
  });

  test('policy rejects userinfo in both directions', () {
    expect(_allows('https://upos-sz-mirrorcos.bilivideo.com@evil.com/v.m4s'), isFalse);
    expect(_allows('https://evil.com@upos-sz-mirrorcos.bilivideo.com/v.m4s'), isFalse);
    expect(_allows('https://evil.com:pw@upos-sz-mirrorcos.bilivideo.com/v.m4s'), isFalse);
  });

  test('policy rejects encoded and backslash hosts', () {
    expect(_allows('https://evil.com%2f.bilivideo.com/v.m4s'), isFalse);
    expect(_allows('https://evil.com%2F.bilivideo.com/v.m4s'), isFalse);
    expect(_allows('https://evil%2ecom.bilivideo.com/v.m4s'), isFalse);
    expect(_allows(r'https://evil.com\@upos-sz-mirrorcos.bilivideo.com/v.m4s'), isFalse);
    expect(_allows(r'https://evil.com\.bilivideo.com/v.m4s'), isFalse);
  });

  test('policy rejects a trailing-dot host', () {
    expect(_allows('https://upos-sz-mirrorcos.bilivideo.com./v.m4s'), isFalse);
  });

  test('policy checks the extension on the encoded path', () {
    expect(_allows('https://upos-sz-mirrorcos.bilivideo.com/v.txt%2Em4s'), isFalse);
    expect(_allows('https://upos-sz-mirrorcos.bilivideo.com/v.m4s%2F.txt'), isFalse);
    expect(_allows('https://upos-sz-mirrorcos.bilivideo.com/a%20b/v.m4s'), isTrue);
  });

  test('representation URLs drop every bypass attempt', () {
    const attempts = [
      'https://evil.com%2f.bilivideo.com/v.m4s',
      r'https://evil.com\@upos-sz-mirrorcos.bilivideo.com/v.m4s',
      'https://evil.com@upos-sz-mirrorcos.bilivideo.com/v.m4s',
    ];
    for (final attempt in attempts) {
      expect(_urls(attempt, [], NodeMode.overseas), isEmpty, reason: attempt);
    }
  });

  test('node key has no port when there is none', () {
    expect(NodeCatalog.nodeKey(_primary), 'upos-sz-mirrorcos.bilivideo.com');
    expect(NodeCatalog.nodeKey('https://UPOS-SZ-MIRRORCOS.bilivideo.com:4483/v.m4s'),
        'upos-sz-mirrorcos.bilivideo.com:4483');
  });

  test('an empty custom list falls back to mainland', () {
    final urls = _urls(_primary, [_backup], const CustomNodes([]));
    expect(urls, _urls(_primary, [_backup], NodeMode.mainland));
    expect(urls, hasLength(9));
  });
}
