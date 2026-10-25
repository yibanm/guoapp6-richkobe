import 'dart:convert';

class LiveSource {
  const LiveSource({
    required this.id,
    required this.name,
    required this.url,
    this.kind = 'm3u',
  });
  final String id;
  final String name;
  final String url;
  final String kind;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'kind': kind,
  };

  factory LiveSource.fromJson(Map<String, dynamic> json) => LiveSource(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '直播源',
    url: json['url'] as String? ?? '',
    kind: json['kind'] as String? ?? 'm3u',
  );
}

class LiveChannel {
  const LiveChannel({
    required this.name,
    required this.url,
    this.group = '',
    this.logo = '',
  });
  final String name;
  final String url;
  final String group;
  final String logo;
}

List<LiveChannel> parseM3uPlaylist(String body) {
  final channels = <LiveChannel>[];
  String name = '';
  String group = '';
  String logo = '';
  for (final raw in const LineSplitter().convert(body)) {
    final line = raw.trim();
    if (line.startsWith('#EXTINF')) {
      final comma = line.indexOf(',');
      name = comma >= 0 ? line.substring(comma + 1).trim() : '';
      final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
      group = groupMatch?.group(1) ?? '';
      final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
      logo = logoMatch?.group(1) ?? '';
    } else if (line.isNotEmpty && !line.startsWith('#')) {
      if (name.isEmpty) name = line;
      channels.add(
        LiveChannel(name: name, url: line, group: group, logo: logo),
      );
      name = '';
      group = '';
      logo = '';
    }
  }
  return channels;
}

List<LiveChannel> parseJsonChannels(String body) {
  final decoded = jsonDecode(body);
  final rows = decoded is List
      ? decoded
      : (decoded is Map
            ? (decoded['channels'] ?? decoded['list'] ?? decoded['data'])
            : null);
  if (rows is! List) return const [];
  final channels = <LiveChannel>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final url =
        row['url'] ?? row['playUrl'] ?? row['play_url'] ?? row['stream'];
    if (url is! String || url.isEmpty) continue;
    channels.add(
      LiveChannel(
        name: (row['name'] ?? row['title'] ?? row['channel'] ?? '频道')
            .toString(),
        url: url,
        group: (row['group'] ?? row['category'] ?? '').toString(),
        logo: (row['logo'] ?? row['icon'] ?? '').toString(),
      ),
    );
  }
  return channels;
}

List<LiveChannel> parseLiveChannels(String body, String kind) {
  final trimmed = body.trimLeft();
  if (kind == 'json' || trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      return parseJsonChannels(trimmed);
    } catch (_) {
      return const [];
    }
  }
  return parseM3uPlaylist(body);
}
