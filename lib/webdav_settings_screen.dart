import 'package:flutter/material.dart';

import 'local_store.dart';
import 'webdav_sync.dart';
import 'widgets.dart';

class WebDavSettingsScreen extends StatefulWidget {
  const WebDavSettingsScreen({super.key, required this.store});
  final LocalStore store;

  @override
  State<WebDavSettingsScreen> createState() => _WebDavSettingsScreenState();
}

class _WebDavSettingsScreenState extends State<WebDavSettingsScreen> {
  late final TextEditingController _url;
  late final TextEditingController _user;
  late final TextEditingController _password;
  late WebDavConfig _config;
  late final WebDavSyncController _controller;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _config = widget.store.webDavConfig;
    _url = TextEditingController(text: _config.url);
    _user = TextEditingController(text: _config.user);
    _password = TextEditingController(text: _config.password);
    _controller = WebDavSyncController(deviceName: widget.store.deviceId);
    _controller.addListener(_statusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_statusChanged);
    _controller.dispose();
    _url.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  void _statusChanged() {
    if (mounted) setState(() {});
  }

  WebDavConfig get _draft => WebDavConfig(
    url: _url.text.trim(),
    user: _user.text.trim(),
    password: _password.text,
    autoSync: _config.autoSync,
  );

  Future<void> _test() async {
    final message = await _controller.testConnection(_draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.isEmpty ? '连接成功' : message),
        backgroundColor: message.isEmpty
            ? null
            : Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _save() async {
    final config = _draft;
    if (!config.configured) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写服务器地址')));
      return;
    }
    await saveUserChange(context, () => widget.store.saveWebDavConfig(config));
    setState(() => _config = config);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存 WebDAV 配置')));
    }
  }

  Future<void> _syncNow() async {
    final config = widget.store.webDavConfig;
    if (!config.configured) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先保存配置')));
      return;
    }
    final result = await _controller.sync(
      config,
      widget.store.webDavSnapshot(),
      widget.store.applyWebDavLibrary,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? _controller.status
              : '同步完成：接收 ${result.downloaded} 条，上传 ${result.uploaded} 条',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('云端同步（WebDAV）')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '将追剧、观看状态与续播进度同步到你自己的 WebDAV 服务器，'
              '在多台设备之间共享。同步目录固定为 shortdramaSync，'
              '不会上传账号密码以外的敏感信息；局域网设备互联保持独立。',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'https://dav.example.com/dav/',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _user,
              decoration: const InputDecoration(
                labelText: '账号',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: '密码',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _showPassword ? '隐藏密码' : '显示密码',
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _controller.busy ? null : _test,
                    icon: const Icon(Icons.network_check_rounded),
                    label: const Text('测试连接'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _controller.busy ? null : _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('保存'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _controller.busy ? null : _syncNow,
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('立即同步'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: _config.autoSync,
              title: const Text('启动时自动同步'),
              subtitle: const Text('打开应用后自动拉取并合并云端记录'),
              onChanged: _controller.busy
                  ? null
                  : (value) async {
                      final config = _draft.copyWith(autoSync: value);
                      await saveUserChange(
                        context,
                        () => widget.store.saveWebDavConfig(config),
                      );
                      if (mounted) setState(() => _config = config);
                    },
            ),
            if (_controller.status.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _controller.status,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
