import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

import 'follow_state.dart';
import 'models.dart';

const _syncFolder = 'shortdramaSync';
const _syncFile = 'library.json';

class WebDavConfig {
  const WebDavConfig({
    this.url = '',
    this.user = '',
    this.password = '',
    this.autoSync = false,
  });
  final String url;
  final String user;
  final String password;
  final bool autoSync;
  bool get configured => url.trim().isNotEmpty;

  WebDavConfig copyWith({
    String? url,
    String? user,
    String? password,
    bool? autoSync,
  }) => WebDavConfig(
    url: url ?? this.url,
    user: user ?? this.user,
    password: password ?? this.password,
    autoSync: autoSync ?? this.autoSync,
  );

  Map<String, dynamic> toJson() => {
    'url': url,
    'user': user,
    'password': password,
    'autoSync': autoSync,
  };

  factory WebDavConfig.fromJson(Map<String, dynamic> json) => WebDavConfig(
    url: json['url'] as String? ?? '',
    user: json['user'] as String? ?? '',
    password: json['password'] as String? ?? '',
    autoSync: json['autoSync'] == true,
  );
}

class WebDavSyncResult {
  const WebDavSyncResult({
    required this.uploaded,
    required this.downloaded,
    required this.message,
  });
  final int uploaded;
  final int downloaded;
  final String message;
}

class WebDavLibrary {
  WebDavLibrary({
    required this.history,
    required this.favorites,
    required this.followStates,
    required this.updatedAt,
    required this.device,
  });
  final List<WatchEntry> history;
  final List<Drama> favorites;
  final Map<String, FollowState> followStates;
  final int updatedAt;
  final String device;

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'device': device,
    'updatedAt': updatedAt,
    'history': history.map((entry) => entry.toJson()).toList(),
    'favorites': favorites.map((drama) => drama.toJson()).toList(),
    'followStates': {
      for (final entry in followStates.entries) entry.key: entry.value.toJson(),
    },
  };

  factory WebDavLibrary.fromJson(Map<String, dynamic> json) {
    final history = <WatchEntry>[];
    for (final row in json['history'] as List? ?? const []) {
      try {
        history.add(WatchEntry.fromJson(Map<String, dynamic>.from(row as Map)));
      } catch (_) {}
    }
    final favorites = <Drama>[];
    for (final row in json['favorites'] as List? ?? const []) {
      try {
        favorites.add(Drama.fromJson(Map<String, dynamic>.from(row as Map)));
      } catch (_) {}
    }
    final followStates = <String, FollowState>{};
    final states = json['followStates'];
    if (states is Map) {
      for (final entry in states.entries) {
        try {
          followStates[entry.key as String] = FollowState.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        } catch (_) {}
      }
    }
    return WebDavLibrary(
      history: history,
      favorites: favorites,
      followStates: followStates,
      updatedAt: intValue(json['updatedAt']),
      device: json['device'] as String? ?? '',
    );
  }
}

WebDavClient createClient(WebDavConfig config) {
  var url = config.url.trim();
  if (!url.endsWith('/')) url += '/';
  final client = WebdavClient.basicAuth(
    url: url,
    user: config.user,
    pwd: config.password,
  );
  client.setConnectTimeout(10000);
  client.setSendTimeout(15000);
  client.setReceiveTimeout(15000);
  return client;
}

Future<void> ensureSyncFolder(WebDavClient client) async {
  if (!await client.exists('/$_syncFolder')) {
    await client.mkdirAll('/$_syncFolder');
  }
}

Future<WebDavLibrary?> fetchRemoteLibrary(WebDavClient client) async {
  final path = '/$_syncFolder/$_syncFile';
  if (!await client.exists(path)) return null;
  final bytes = await client.read(path);
  final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  return WebDavLibrary.fromJson(json);
}

Future<void> pushLibrary(WebDavClient client, WebDavLibrary library) async {
  await ensureSyncFolder(client);
  await client.write(
    utf8.encode(jsonEncode(library.toJson())),
    '/$_syncFolder/$_syncFile',
  );
}

WebDavLibrary mergeLibraries(WebDavLibrary local, WebDavLibrary remote) {
  final history = <String, WatchEntry>{
    for (final entry in remote.history) entry.drama.id: entry,
  };
  for (final entry in local.history) {
    final existing = history[entry.drama.id];
    if (existing == null || entry.updatedAt.isAfter(existing.updatedAt)) {
      history[entry.drama.id] = entry;
    }
  }
  final favorites = <String, Drama>{
    for (final drama in remote.favorites) drama.id: drama,
  };
  for (final drama in local.favorites) {
    favorites[drama.id] = drama;
  }
  final followStates = Map.of(remote.followStates);
  for (final entry in local.followStates.entries) {
    followStates[entry.key] = entry.value;
  }
  return WebDavLibrary(
    history: history.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    favorites: favorites.values.toList(),
    followStates: followStates,
    updatedAt: DateTime.now().millisecondsSinceEpoch,
    device: local.device,
  );
}

int countDifferences(WebDavLibrary a, WebDavLibrary b) {
  var count = 0;
  final aHistory = {for (final entry in a.history) entry.drama.id: entry};
  for (final entry in b.history) {
    final local = aHistory[entry.drama.id];
    if (local == null || local.updatedAt != entry.updatedAt) count++;
  }
  final aFavorites = a.favorites.map((drama) => drama.id).toSet();
  for (final drama in b.favorites) {
    if (!aFavorites.contains(drama.id)) count++;
  }
  return count;
}

String describeError(Object error) {
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => '连接超时，请检查服务器地址与网络',
      DioExceptionType.badCertificate => '证书校验失败，请确认服务器证书有效',
      DioExceptionType.badResponse => switch (error.response?.statusCode) {
        401 || 403 => '账号或密码错误，或没有访问权限',
        404 => '服务器地址不存在该 WebDAV 服务',
        405 => '服务器不支持 WebDAV 方法',
        _ => '服务器返回错误 ${error.response?.statusCode}',
      },
      _ => '无法连接 WebDAV 服务器：${error.message ?? error.type.name}',
    };
  }
  if (error is FormatException) return '服务器返回的数据无法解析';
  return error.toString();
}

typedef LibrarySnapshot = ({
  List<WatchEntry> history,
  List<Drama> favorites,
  Map<String, FollowState> followStates,
});

class WebDavSyncController extends ChangeNotifier {
  WebDavSyncController({required this.deviceName});
  final String deviceName;
  String _status = '';
  bool _busy = false;
  bool get busy => _busy;
  String get status => _status;

  void _set(String status, {bool busy = false}) {
    _status = status;
    _busy = busy;
    notifyListeners();
  }

  Future<String> testConnection(WebDavConfig config) async {
    if (!config.configured) return '请先填写服务器地址';
    _set('正在测试连接…', busy: true);
    try {
      final client = createClient(config);
      await client.ping();
      await ensureSyncFolder(client);
      _set('连接成功，同步目录 $_syncFolder 已就绪');
      return '';
    } catch (error) {
      final message = describeError(error);
      _set(message);
      return message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<WebDavSyncResult?> sync(
    WebDavConfig config,
    LibrarySnapshot local,
    Future<void> Function(WebDavLibrary merged) apply,
  ) async {
    if (!config.configured) return null;
    _set('正在同步…', busy: true);
    try {
      final client = createClient(config);
      final localLibrary = WebDavLibrary(
        history: local.history,
        favorites: local.favorites,
        followStates: local.followStates,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        device: deviceName,
      );
      final remote = await fetchRemoteLibrary(client);
      if (remote == null) {
        await pushLibrary(client, localLibrary);
        _set('已上传本机记录到云端');
        return WebDavSyncResult(
          uploaded: local.history.length + local.favorites.length,
          downloaded: 0,
          message: '已上传本机记录到云端',
        );
      }
      final merged = mergeLibraries(localLibrary, remote);
      final incoming = countDifferences(localLibrary, remote);
      await pushLibrary(client, merged);
      await apply(merged);
      _set('同步完成：合并 ${merged.history.length} 条观看记录');
      return WebDavSyncResult(
        uploaded: countDifferences(remote, merged),
        downloaded: incoming,
        message: '同步完成',
      );
    } catch (error) {
      final message = describeError(error);
      _set(message);
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
