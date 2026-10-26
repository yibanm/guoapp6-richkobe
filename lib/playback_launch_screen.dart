import 'dart:async';

import 'package:flutter/material.dart';

import 'core_bridge.dart';
import 'follow_state.dart';
import 'local_store.dart';
import 'models.dart';
import 'player_screen.dart';
import 'widgets.dart';

Future<void> openPlaybackDirectly(
  BuildContext context, {
  required Drama drama,
  required AppRepository repository,
  required LocalStore store,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => PlaybackLaunchScreen(
      drama: drama,
      repository: repository,
      store: store,
    ),
  ),
);

class PlaybackLaunchScreen extends StatefulWidget {
  const PlaybackLaunchScreen({
    super.key,
    required this.drama,
    required this.repository,
    required this.store,
  });

  final Drama drama;
  final AppRepository repository;
  final LocalStore store;

  @override
  State<PlaybackLaunchScreen> createState() => _PlaybackLaunchScreenState();
}

class _PlaybackLaunchScreenState extends State<PlaybackLaunchScreen> {
  late final int _profileEpoch;
  int _generation = 0;
  String? _error;
  int _elapsedSeconds = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _profileEpoch = widget.store.profileEpoch;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _error = null;
      _elapsedSeconds = 0;
    });
    try {
      final detail = await widget.repository.detail(widget.drama);
      if (!mounted ||
          generation != _generation ||
          _profileEpoch != widget.store.profileEpoch) {
        return;
      }
      final drama = widget.repository.catalogUpdates
          .current(widget.drama)
          .merge(detail.drama);
      final merged = DramaDetail(
        drama,
        detail.episodes,
        warning: detail.warning,
      );
      widget.repository.catalogUpdates.publish(drama, retryCover: true);
      await saveUserChange(context, () => widget.store.refreshDrama(drama));
      if (!mounted ||
          generation != _generation ||
          _profileEpoch != widget.store.profileEpoch) {
        return;
      }
      if (merged.episodes.isEmpty) {
        setState(() => _error = '暂时没有可播放的集数');
        return;
      }
      final watched = widget.store.watched(drama.id);
      final index = resumeEpisodeIndex(merged.episodes, watched);
      final episode = merged.episodes[index];
      if (episode.vip && drama.source != SourceSite.dsd.id) {
        if (!mounted) return;
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('这是一集 VIP 内容'),
            content: const Text('站源可能只提供试看或限制播放。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('尝试播放'),
              ),
            ],
          ),
        );
        if (accepted != true) {
          if (mounted) Navigator.of(context).maybePop();
          return;
        }
        if (!mounted) {
          return;
        }
      }
      final position =
          watched?.episode == episode.number && watched?.finished == false
          ? watched!.position
          : 0.0;
      if (!mounted ||
          generation != _generation ||
          _profileEpoch != widget.store.profileEpoch) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PlayerScreen(
            detail: merged,
            initialIndex: index,
            initialPosition: position,
            repository: widget.repository,
            store: widget.store,
          ),
        ),
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = error.toString());
      widget.repository.catalogUpdates.publish(
        widget.repository.catalogUpdates.current(widget.drama),
        retryCover: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.drama.title)),
    body: SafeArea(
      top: false,
      child: _error == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _elapsedSeconds < 3
                        ? '正在获取剧集信息'
                        : _elapsedSeconds < 8
                        ? '源站响应较慢，仍在获取（已等待 $_elapsedSeconds 秒）'
                        : '源站响应很慢（已等待 $_elapsedSeconds 秒），可返回重试或换一部',
                  ),
                ],
              ),
            )
          : StatusPanel(
              title: '暂时无法播放',
              message: _error!,
              onRetry: _load,
              action: '重试',
              icon: Icons.play_disabled_rounded,
            ),
    ),
  );
}
