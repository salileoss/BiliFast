// Port of BTR's cdn-resolver node lists (see LICENSE-BTR.txt), by way of BiliNative's NodeCatalog.swift.

final class NodeAddress {
  NodeAddress(String host, {this.port}) : host = host.toLowerCase();

  final String host;
  final int? port;

  @override
  bool operator ==(Object other) => other is NodeAddress && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => port == null ? host : '$host:$port';
}

sealed class NodeMode {
  const NodeMode();

  static const mainland = MainlandNodes();
  static const overseas = OverseasNodes();
  static const auto = AutoNodes();
}

/// The exact API addresses plus both regional node sets, selected by measured performance.
final class AutoNodes extends NodeMode {
  const AutoNodes();
}

final class MainlandNodes extends NodeMode {
  const MainlandNodes();
}

final class OverseasNodes extends NodeMode {
  const OverseasNodes();
}

/// Explicit nodes, as BTR's custom mode; the tests use it for loopback nodes.
final class CustomNodes extends NodeMode {
  const CustomNodes(this.nodes);

  final List<NodeAddress> nodes;
}

final class MediaURLPolicy {
  const MediaURLPolicy(this.allowsURL);

  final bool Function(String url) allowsURL;

  /// Signed download addresses are only ever sent to Bilibili's own media hosts.
  static const bilibili = MediaURLPolicy(_allowsBilibili);

  static const any = MediaURLPolicy(_allowsAny);
}

bool _allowsAny(String url) => true;

// Checked on the raw text as well as the parsed URI: Dart's Uri decodes escapes in the host and path that
// URLComponents' percent-encoded accessors keep, so the two could disagree about the host.
bool _allowsBilibili(String text) {
  if (text.contains(r'\')) return false;
  final uri = Uri.tryParse(text);
  final raw = NodeCatalog._parts.firstMatch(text);
  if (uri == null || raw == null || uri.scheme.toLowerCase() != 'https') return false;
  final authority = raw[2]!;
  if (authority.contains('@') || uri.userInfo.isNotEmpty) return false;
  final colon = authority.lastIndexOf(':');
  final host = (colon < 0 ? authority : authority.substring(0, colon)).toLowerCase();
  if (host != uri.host.toLowerCase() || !NodeCatalog.isPlainHostName(host)) return false;
  final rest = raw[3]!;
  final pathEnd = rest.indexOf(RegExp('[?#]'));
  final path = (pathEnd < 0 ? rest : rest.substring(0, pathEnd)).toLowerCase();
  if (!(path.endsWith('.m4s') || path.endsWith('.mp4') || path.endsWith('.flv'))) return false;
  return NodeCatalog.mediaHostSuffixes.any((suffix) => host == suffix || host.endsWith('.$suffix'));
}

/// What the engine reads from one address, parsed once: every candidate list, ban check and node record asks it
/// of the same few signed addresses (about 400 characters each) many times a second.
final class _Parsed {
  const _Parsed({
    required this.host,
    required this.nodeKey,
    required this.address,
    required this.routeKey,
    required this.relay,
  });

  factory _Parsed.of(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return _Parsed(host: '', nodeKey: '', address: '', routeKey: url, relay: false);
    final host = uri.host.toLowerCase();
    final nodeKey = host.isEmpty ? '' : (uri.hasPort ? '$host:${uri.port}' : host);
    return _Parsed(
      host: host,
      nodeKey: nodeKey,
      address: uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path,
      routeKey: nodeKey + uri.path,
      relay:
          NodeCatalog._relayHost.hasMatch(uri.host) ||
          NodeCatalog._relayPath.hasMatch(uri.path) ||
          _os(uri)?.toLowerCase() == 'mcdn',
    );
  }

  final String host;
  final String nodeKey;
  final String address;
  final String routeKey;
  final bool relay;

  /// The first `os`, as BTR's `searchParams.get`; a query that does not decode has none.
  static String? _os(Uri uri) {
    try {
      return uri.queryParametersAll['os']?.firstOrNull;
    } on FormatException {
      return null;
    }
  }
}

abstract final class NodeCatalog {
  static const mainland = [
    'upos-sz-mirrorali.bilivideo.com',
    'upos-sz-mirrorhw.bilivideo.com',
    'upos-sz-mirrorbos.bilivideo.com',
    'upos-sz-mirror08c.bilivideo.com',
    'upos-sz-mirrorbd.bilivideo.com',
    'upos-sz-mirror14b.bilivideo.com',
    'upos-sz-estgoss.bilivideo.com',
    'upos-sz-mirrorcos.bilivideo.com',
  ];

  static const overseas = [
    'upos-sz-mirrorcosov.bilivideo.com',
    'upos-sz-mirroraliov.bilivideo.com',
    'cn-hk-eq-01-01.bilivideo.com',
    'cn-hk-eq-01-03.bilivideo.com',
  ];

  static const mediaHostSuffixes = [
    'bilivideo.com', 'bilivideo.cn', 'bilivideo.net', 'akamaized.net', 'szbdyd.com', //
    'hdslb.com', 'xycdn.com', 'mountaintoys.cn', 'nexusedgeio.com', 'ahdohpiechei.com',
  ];

  static final _plainHost = RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$');
  static final _parts = RegExp(r'^([A-Za-z][A-Za-z0-9+.\-]*://)([^/?#]*)(.*)$', dotAll: true);
  static final _relayHost = RegExp(r'(?:^|\.)mcdn\.', caseSensitive: false);
  static final _relayPath = RegExp(r'^/v1/resource/', caseSensitive: false);

  /// A session sees a few dozen addresses (nodes × tracks × signatures); every new video brings new ones, so the
  /// cache starts over rather than grow for the life of the engine.
  static const _parsedLimit = 1024;
  static final _parsed = <String, _Parsed>{};

  static _Parsed _parse(String url) {
    final cached = _parsed[url];
    if (cached != null) return cached;
    if (_parsed.length >= _parsedLimit) _parsed.clear();
    return _parsed[url] = _Parsed.of(url);
  }

  /// BTR `normalizeCdnHost`'s shape check: letters, digits and hyphens in dot-separated labels,
  /// so no percent escapes, userinfo, port or trailing dot.
  static bool isPlainHostName(String host) => _plainHost.hasMatch(host);

  static String host(String url) => _parse(url).host;

  static String nodeKey(String url) => _parse(url).nodeKey;

  /// The signed address without its node: the same address can be asked of any node.
  static String address(String url) => _parse(url).address;

  /// Node and path without the query, so a fresh signature is the same route ([url] itself when it does not parse).
  static String routeKey(String url) => _parse(url).routeKey;

  static bool isAkamai(String url) => host(url).endsWith('.akamaized.net');

  /// BTR `isRelayUrl` (2026.10.17.1, issue #47): a P2P or edge-cache relay (an mcdn node, or the mountaintoys.cn
  /// caches beside them) wraps the file in its own path and signature, which every ordinary node refuses.
  static bool isRelay(String url) => _parse(url).relay;

  /// Rebuilt on the original text, so the signed query goes out byte for byte as Bilibili wrote it.
  static String? swapHost(String url, NodeAddress node, {bool allowAkamai = false}) {
    if (!allowAkamai && isAkamai(url)) return null;
    final match = _parts.firstMatch(url);
    if (Uri.tryParse(url) == null || match == null) return null;
    final authority = match[2]!;
    final at = authority.lastIndexOf('@');
    final userInfo = at < 0 ? '' : authority.substring(0, at + 1);
    // The port is replaced too, or a peer CDN's non-standard port such as :4483 would stay.
    final port = node.port == null ? '' : ':${node.port}';
    return '${match[1]}$userInfo${node.host}$port${match[3]}';
  }

  static List<NodeAddress> nodes(NodeMode mode) => switch (mode) {
    AutoNodes() => [for (final host in {...overseas, ...mainland}) NodeAddress(host)],
    MainlandNodes() => [for (final host in mainland) NodeAddress(host)],
    OverseasNodes() => [for (final host in overseas) NodeAddress(host)],
    CustomNodes(:final nodes) => nodes,
  };

  /// BTR `representationUrls`: the addresses Bilibili gave that suit the mode, then the signed
  /// address swapped onto every node of the mode.
  static List<String> representationURLs({
    required String primary,
    required List<String> backups,
    required NodeMode mode,
    required MediaURLPolicy policy,
  }) {
    final originals = deduplicated([primary, ...backups].where(policy.allowsURL).toList());
    // BTR: a custom mode without servers works like the mainland mode.
    final effective = mode is CustomNodes && mode.nodes.isEmpty ? NodeMode.mainland : mode;
    final nodes = NodeCatalog.nodes(effective);
    // BTR #47: a relay address moved to an ordinary node is refused there (HTTP 403 on every node), so only
    // ordinary addresses are moved.
    final ordinary = originals.where((url) => !isRelay(url)).toList();
    // Some overseas accounts only get akamaized.net addresses; the nodes accept those
    // signatures too, so then every one of them is tried on every node.
    final donor = ordinary.where((url) => !isAkamai(url)).firstOrNull;
    final synthetic = donor != null
        ? [for (final node in nodes) ?swapHost(donor, node)]
        : [
            for (final node in nodes)
              for (final original in ordinary) ?swapHost(original, node, allowAkamai: true),
          ];
    final allowedOriginals = switch (effective) {
      AutoNodes() => ordinary,
      CustomNodes(:final nodes) => originals.where((url) => nodes.any((node) => node.host == host(url))),
      OverseasNodes() => originals.where((url) => !mainland.contains(host(url))),
      MainlandNodes() => originals.where((url) => mainland.contains(host(url))),
    };
    // A track Bilibili hands out only through relays can be served by nothing else, so the relays are used
    // whatever the mode rather than giving the video up.
    final relays = ordinary.isEmpty ? originals : const <String>[];
    return deduplicated([...allowedOriginals, ...synthetic.where(policy.allowsURL), ...relays]);
  }

  static List<String> deduplicated(List<String> list) {
    final seen = <String>{};
    return [
      for (final url in list)
        if (seen.add(url)) url,
    ];
  }
}
