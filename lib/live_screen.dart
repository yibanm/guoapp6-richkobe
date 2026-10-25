import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'live_models.dart';
import 'local_store.dart';
import 'widgets.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key, required this.store});
  final LocalStore store;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<LiveSource> _sources = const [];
  LiveSource? _source;
  List<LiveChannel> _channels = const [];
  String _group = '';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sources = widget.store.liveSources;
    _source = _sources.isEmpty ? null : _sources.first;
    if (_source != null) unawaited(_load());
  }

  List<LiveChannel> get _visible => _group.isEmpty
      ? _channels
      : _channels.where((channel) => channel.group == _group).toList();

  List<String> get _groups =>
      _channels.map((channel) => channel.group).toSet().toList()..sort();

  Future<void> _load() async {
    final source = _source;
    if (source == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = await HttpClient()
          .getUrl(Uri.parse(source.url))
          .timeout(const Duration(seconds: 15));
      request.headers.set('User-Agent', 'kobedrama-live/1.0');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        throw StateError('服务器返回 ${response.statusCode}');
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      final channels = parseLiveChannels(body, source.kind);
      if (!mounted) return;
      if (channels.isEmpty) {
        setState(() {
          _loading = false;
          _error = '该源没有解析出可用频道，请检查地址格式（m3u / json）';
        });
        return;
      }
      setState(() {
        _channels = channels;
        _group = '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is TimeoutException
            ? '连接超时，请检查网络或源地址'
            : error.toString();
      });
    }
  }

  Future<void> _manage() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _LiveSourceManager(store: widget.store, sources: _sources),
    );
    if (changed == true) {
      setState(() {
        _sources = widget.store.liveSources;
        if (_source != null &&
            !_sources.any((entry) => entry.id == _source!.id)) {
          _source = _sources.isEmpty ? null : _sources.first;
          _channels = const [];
        }
      });
      if (_source != null) unawaited(_load());
    }
  }

  Future<void> _addSource() async {
    final name = TextEditingController();
    final url = TextEditingController();
    var kind = 'm3u';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('添加直播源'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '例如：秀果',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '源地址',
                  hintText: 'm3u 或 json 地址',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: kind,
                items: const [
                  DropdownMenuItem(value: 'm3u', child: Text('M3U 播放列表')),
                  DropdownMenuItem(value: 'json', child: Text('JSON 频道列表')),
                ],
                onChanged: (value) => update(() => kind = value ?? 'm3u'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final address = url.text.trim();
    if (address.isEmpty || !mounted) return;
    final source = LiveSource(
      id: 'live-${DateTime.now().millisecondsSinceEpoch}',
      name: name.text.trim().isEmpty ? '直播源' : name.text.trim(),
      url: address,
      kind: kind,
    );
    await saveUserChange(
      context,
      () => widget.store.saveLiveSources([..._sources, source]),
    );
    if (!mounted) return;
    setState(() {
      _sources = widget.store.liveSources;
      _source = source;
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('直播'),
      actions: [
        PopupMenuButton<LiveSource>(
          tooltip: '切换直播源',
          enabled: _sources.isNotEmpty,
          onSelected: (source) {
            setState(() => _source = source);
            unawaited(_load());
          },
          itemBuilder: (_) => [
            for (final source in _sources)
              PopupMenuItem(value: source, child: Text(source.name)),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_source?.name ?? '未添加源'),
                const Icon(Icons.expand_more_rounded),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: '添加直播源',
          icon: const Icon(Icons.add_rounded),
          onPressed: _addSource,
        ),
        IconButton(
          tooltip: '管理直播源',
          icon: const Icon(Icons.tune_rounded),
          onPressed: _manage,
        ),
      ],
    ),
    body: _sources.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('还没有直播源'),
                const SizedBox(height: 8),
                const Text('添加一个 m3u 或 json 直播源后即可观看。'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _addSource,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('添加直播源'),
                ),
              ],
            ),
          )
        : Column(
            children: [
              if (_groups.length > 1)
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('全部'),
                          selected: _group.isEmpty,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _group = ''),
                        ),
                      ),
                      for (final group in _groups)
                        if (group.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(group),
                              selected: _group == group,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _group = group),
                            ),
                          ),
                    ],
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _load,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _visible.length,
                        itemBuilder: (_, index) {
                          final channel = _visible[index];
                          final favorite = widget.store.isLiveFavorite(
                            _source!.id,
                            channel.url,
                          );
                          return ListTile(
                            leading: const Icon(Icons.live_tv_rounded),
                            title: Text(channel.name),
                            subtitle: channel.group.isEmpty
                                ? null
                                : Text(channel.group),
                            trailing: IconButton(
                              tooltip: favorite ? '取消收藏' : '收藏',
                              icon: Icon(
                                favorite
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                              ),
                              onPressed: () async {
                                await saveUserChange(
                                  context,
                                  () => widget.store.toggleLiveFavorite(
                                    _source!.id,
                                    channel.url,
                                  ),
                                );
                                if (mounted) setState(() {});
                              },
                            ),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => LivePlayerScreen(
                                  channel: channel,
                                  channels: _visible,
                                  initialIndex: index,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
  );
}

class _LiveSourceManager extends StatefulWidget {
  const _LiveSourceManager({required this.store, required this.sources});
  final LocalStore store;
  final List<LiveSource> sources;

  @override
  State<_LiveSourceManager> createState() => _LiveSourceManagerState();
}

class _LiveSourceManagerState extends State<_LiveSourceManager> {
  late List<LiveSource> _sources = List.of(widget.sources);
  bool _changed = false;

  Future<void> _remove(LiveSource source) async {
    await saveUserChange(
      context,
      () => widget.store.saveLiveSources(
        _sources.where((entry) => entry.id != source.id).toList(),
      ),
    );
    setState(() {
      _sources = widget.store.liveSources;
      _changed = true;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('管理直播源'),
    content: SizedBox(
      width: 420,
      child: _sources.isEmpty
          ? const Text('暂无直播源')
          : ListView(
              shrinkWrap: true,
              children: [
                for (final source in _sources)
                  ListTile(
                    title: Text(source.name),
                    subtitle: Text(
                      source.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: '删除',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _remove(source),
                    ),
                  ),
              ],
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, _changed),
        child: const Text('完成'),
      ),
    ],
  );
}

class LivePlayerScreen extends StatefulWidget {
  const LivePlayerScreen({
    super.key,
    required this.channel,
    required this.channels,
    required this.initialIndex,
  });
  final LiveChannel channel;
  final List<LiveChannel> channels;
  final int initialIndex;

  @override
  State<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<LivePlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  int _index;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _player = Player();
    _controller = VideoController(_player);
    _open();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    await _player.open(Media(widget.channels[_index].url), play: true);
  }

  void _switch(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.channels.length) return;
    setState(() => _index = next);
    unawaited(_open());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () => setState(() => _controlsVisible = !_controlsVisible),
          child: Video(controller: _controller),
        ),
        if (_controlsVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: .7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '返回',
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.channels[_index].name,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: '上一频道',
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _index > 0 ? () => _switch(-1) : null,
                    ),
                    IconButton(
                      tooltip: '下一频道',
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _index + 1 < widget.channels.length
                          ? () => _switch(1)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
