import 'package:flutter_test/flutter_test.dart';

import 'package:duanju_app/follow_state.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';
import 'package:duanju_app/models.dart';
import 'package:duanju_app/webdav_sync.dart';

// 需要本机在 127.0.0.1:8090 跑一个匿名 WebDAV 服务（wsgidav）：
//   wsgidav --host 127.0.0.1 --port 8090 --root <目录> --auth anonymous
// 没有服务时跳过，不影响 CI 与无服务环境。
Future<bool> _serverAvailable() async {
  try {
    final client = createClient(
      const WebDavConfig(url: 'http://127.0.0.1:8090/'),
    );
    await client.ping();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const config = WebDavConfig(url: 'http://127.0.0.1:8090/');

  test('webdav 连接测试、上传、合并全链路', () async {
    if (!await _serverAvailable()) {
      // 无本地 WebDAV 服务时跳过，避免误报失败
      return;
    }
    final controller = WebDavSyncController(deviceName: 'test-device');
    addTearDown(controller.dispose);

    // 1. 测试连接应成功（返回空串），并自动创建 shortdramaSync 目录
    expect(await controller.testConnection(config), '');

    // 2. 先清空远端，保证用例可重复
    final client = createClient(config);
    final remoteFile = '/shortdramaSync/library.json';
    if (await client.exists(remoteFile)) {
      await client.remove(remoteFile);
    }

    // 3. 首次同步：远端为空 → 上传本机记录
    final drama = Drama(id: 'hongguo:1', source: 'hongguo', title: '同步测试剧');
    final local = (
      history: [
        WatchEntry(
          drama: drama,
          episode: 3,
          position: 12.5,
          duration: 60,
          updatedAt: DateTime(2026, 10, 26, 8),
        ),
      ],
      favorites: [drama],
      followStates: const <String, FollowState>{},
    );
    var applied = 0;
    final first = await controller.sync(config, local, (merged) async {
      applied++;
      expect(merged.history, hasLength(1));
      expect(merged.favorites, hasLength(1));
    });
    expect(first, isNotNull);
    expect(first!.uploaded, greaterThan(0));
    expect(await client.exists(remoteFile), isTrue);

    // 4. 模拟另一台设备写入更新记录后，本机同步应合并接收
    final otherDevice = WebDavLibrary(
      history: [
        WatchEntry(
          drama: drama,
          episode: 5,
          position: 30,
          duration: 60,
          updatedAt: DateTime(2026, 10, 26, 9),
        ),
      ],
      favorites: [drama],
      followStates: const {},
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      device: 'other-device',
    );
    await pushLibrary(client, otherDevice);
    final second = await controller.sync(config, local, (merged) async {
      applied++;
      // 合并后应取更新时间更远的第 5 集进度
      expect(merged.history.single.episode, 5);
    });
    expect(second, isNotNull);
    expect(second!.downloaded, greaterThan(0));
    expect(applied, 2);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
