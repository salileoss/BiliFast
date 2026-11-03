import 'package:bili_core/engine.dart';
import 'package:bili_core/src/engine/ban_list.dart';
import 'package:bili_core/src/engine/resolver.dart';
import 'package:test/test.dart';

// BTR 2026.10.17.1 (`6bf1e44`, issue #47) and its tests in `dev/shared-core-test.js`.
const _file = '/upgcxcode/00/00/1/1-1-30080.m4s';
const _relay = 'https://xy1x2x3x4xy.mcdn.bilivideo.cn:8082/v1/resource$_file?e=1&os=mcdn&upsig=r';
const _edge = 'https://ccf958o.edge.mountaintoys.cn:4483/v1/resource$_file?e=1&os=mcdn&upsig=e';
const _estgoss = 'https://upos-sz-estgoss.bilivideo.com$_file?e=1&os=estgoss&upsig=x';
const _akamai = 'https://upos-hz-mirrorakam.akamaized.net$_file?e=1&os=akam&hdnts=x';

List<String> _urls(String primary, List<String> backups, NodeMode mode) => NodeCatalog.representationURLs(
  primary: primary,
  backups: backups,
  mode: mode,
  policy: MediaURLPolicy.bilibili,
);

void main() {
  test('relay addresses are told apart', () {
    expect(NodeCatalog.isRelay(_relay), isTrue);
    expect(NodeCatalog.isRelay(_edge), isTrue);
    expect(NodeCatalog.isRelay(_estgoss), isFalse);
    expect(NodeCatalog.isRelay(_akamai), isFalse);
    expect(NodeCatalog.isRelay('https://a.MCDN.bilivideo.cn/v.m4s'), isTrue, reason: 'by host');
    expect(NodeCatalog.isRelay('https://upos-sz-mirrorcos.bilivideo.com/V1/Resource/v.m4s'), isTrue, reason: 'by path');
    expect(NodeCatalog.isRelay('https://upos-sz-mirrorcos.bilivideo.com/v.m4s?e=1&os=MCDN'), isTrue, reason: 'by os');
    expect(NodeCatalog.isRelay('https://upos-sz-mirrorcos.bilivideo.com/v.m4s?os=akam&os=mcdn'), isFalse);
    expect(NodeCatalog.isRelay('https://xmcdn.bilivideo.cn/v.m4s'), isFalse);
    expect(NodeCatalog.isRelay('https://upos-sz-mirrorcos.bilivideo.com/v.m4s?os=%E0%A4'), isFalse);
  });

  test('a relay address is never moved to the ordinary nodes (#47)', () {
    final mixed = _urls(_relay, [_edge, _estgoss], NodeMode.mainland);
    expect(mixed, hasLength(NodeCatalog.mainland.length));
    expect(mixed.where(NodeCatalog.isRelay), isEmpty, reason: 'the ordinary backup donates its address');
    final overseas = _urls(_relay, [_edge, _estgoss], NodeMode.overseas);
    for (final url in overseas.where(NodeCatalog.isRelay)) {
      expect([_relay, _edge], contains(url), reason: 'a relay address only on its own relay');
    }
    expect(overseas.where((url) => NodeCatalog.address(url) == NodeCatalog.address(_estgoss)), hasLength(4));
  });

  test('a track handed out only through relays is downloaded from them, in every mode', () {
    for (final mode in [NodeMode.auto, NodeMode.mainland, NodeMode.overseas]) {
      expect(_urls(_relay, [_edge], mode), [_relay, _edge], reason: '$mode');
    }
    final custom = CustomNodes([NodeAddress('upos-sz-mirrorali.bilivideo.com')]);
    expect(_urls(_relay, [_edge], custom), [_relay, _edge]);
  });

  test('an Akamai address beside relays is still the donor of last resort', () {
    final urls = _urls(_relay, [_akamai], NodeMode.overseas);
    expect(urls.where((url) => NodeCatalog.address(url) == NodeCatalog.address(_akamai)), hasLength(5));
    expect(urls.where((url) => NodeCatalog.isRelay(url) && url != _relay), isEmpty);
  });

  test('parsed parts stay right past the cache limit', () {
    for (var index = 0; index < 2100; index++) {
      final url = 'https://n$index.bilivideo.com:${8000 + index % 3}/p/$index.m4s?deadline=$index';
      expect(NodeCatalog.nodeKey(url), 'n$index.bilivideo.com:${8000 + index % 3}');
      expect(NodeCatalog.address(url), '/p/$index.m4s?deadline=$index');
      expect(Resolver.routeKey(url), 'n$index.bilivideo.com:${8000 + index % 3}/p/$index.m4s');
    }
    expect(NodeCatalog.nodeKey('not a url'), '');
    expect(Resolver.routeKey('http://[::1'), 'http://[::1', reason: 'unparsable: the text itself');
    expect(NodeCatalog.address('http://[::1'), '');
  });

  test('the resolver hands out its own copy of the addresses', () {
    final resolver = Resolver(
      primary: _estgoss,
      backups: const [],
      mode: NodeMode.overseas,
      bans: BanList(),
    );
    final first = resolver.allURLs()..clear();
    expect(first, isEmpty);
    expect(resolver.allURLs(), hasLength(4));
    resolver.urls().clear();
    expect(resolver.urls(), hasLength(4));
    resolver.replaceURLs(primary: _estgoss.replaceAll('e=1', 'e=2'), backups: const []);
    expect(resolver.allURLs().every((url) => url.contains('e=2')), isTrue, reason: 'new addresses rebuild the list');
  });
}
