import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../data/media_saver.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';

/// 贴吧内置视频播放页（支持播放暂停、拖动进度与保存视频）。
class VideoPage extends StatefulWidget {
  const VideoPage({
    super.key,
    required this.videoUrl,
    this.title = '视频播放',
  });

  final String videoUrl;
  final String title;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final url = widget.videoUrl.startsWith('//')
          ? 'https:${widget.videoUrl}'
          : widget.videoUrl;
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: const {
          'User-Agent': 'bdtb for Android 12.64.1.1',
          'Referer': 'https://tieba.baidu.com/',
        },
      );
      _controller = ctrl;
      await ctrl.initialize();
      ctrl.addListener(_onUpdate);
      await ctrl.play();
      if (mounted) setState(() => _loading = false);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = cleanError(e);
          _loading = false;
        });
      }
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onUpdate);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _saveVideo() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<MediaSaver>().saveVideoFromUrl(widget.videoUrl);
      if (mounted) showFrostedToast(context, '视频已保存到相册');
    } on Object catch (e) {
      if (mounted) {
        showFrostedToast(context, cleanError(e), level: BannerLevel.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return FrostedPage(
      title: widget.title,
      actions: [
        IconButton(
          onPressed: _saving ? null : _saveVideo,
          tooltip: '保存视频',
          icon: _saving
              ? const ActivityIndicator(size: 18)
              : const GlyphIcon(FrostedGlyphs.download, size: 20),
        ),
      ],
      body: ColoredBox(
        color: const Color(0xFF000000),
        child: _loading
            ? const FrostedLoading(label: '加载视频中...')
            : _error != null
                ? FrostedEmpty(
                    title: '视频播放失败',
                    message: _error,
                    icon: FrostedGlyphs.play,
                  )
                : Stack(
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: ctrl!.value.aspectRatio > 0
                              ? ctrl.value.aspectRatio
                              : 16 / 9,
                          child: GestureDetector(
                            onTap: () {
                              if (ctrl.value.isPlaying) {
                                ctrl.pause();
                              } else {
                                ctrl.play();
                              }
                            },
                            child: VideoPlayer(ctrl),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: bottom + 16,
                        child: FrostedCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  if (ctrl.value.isPlaying) {
                                    ctrl.pause();
                                  } else {
                                    ctrl.play();
                                  }
                                },
                                tooltip: ctrl.value.isPlaying ? '暂停' : '播放',
                                icon: GlyphIcon(
                                  FrostedGlyphs.play,
                                  size: 20,
                                  color: context.colorScheme.primary,
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  value: ctrl.value.duration.inMilliseconds > 0
                                      ? (ctrl.value.position.inMilliseconds /
                                              ctrl.value.duration.inMilliseconds)
                                          .clamp(0.0, 1.0)
                                      : 0.0,
                                  onChanged: (v) {
                                    final target = Duration(
                                      milliseconds:
                                          (ctrl.value.duration.inMilliseconds *
                                                  v)
                                              .round(),
                                    );
                                    ctrl.seekTo(target);
                                  },
                                ),
                              ),
                              Text(
                                '${_fmt(ctrl.value.position)} / ${_fmt(ctrl.value.duration)}',
                                style: AppTextStyle.caption1.of(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s < 10 ? '0$s' : '$s'}';
  }
}
