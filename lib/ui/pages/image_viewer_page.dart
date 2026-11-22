import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../core/html_text.dart';
import '../../data/image_cache.dart';
import '../../data/media_saver.dart';
import '../../data/settings.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/press_scale.dart';
import '../widgets/remote_image.dart';

/// 全屏看图页：
/// - 复用二级缓存，无缝衔接列表缩略图与原图切换（零闪黑）
/// - 自动预加载相邻页图片
/// - 支持双击定点平滑缩放、双指缩放、未放大时上下拖跟手关闭。
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  final List<RichImageNode> images;
  final int initialIndex;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final int _safeInitial = widget.images.isEmpty
      ? 0
      : widget.initialIndex.clamp(0, widget.images.length - 1);
  late final PageController _page = PageController(initialPage: _safeInitial);
  late int _index = _safeInitial;
  final Set<int> _originIndexes = {};
  final ValueNotifier<double> _backdropAlpha = ValueNotifier<double>(1.0);
  bool _saving = false;
  bool _pageLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.images.isEmpty) return;
      if (context.read<FrostedSettings>().loadOriginImage) {
        setState(() {
          for (var i = 0; i < widget.images.length; i++) {
            if (widget.images[i].originUrl.isNotEmpty) {
              _originIndexes.add(i);
            }
          }
        });
      }
      _prefetchNeighbors(_index);
    });
  }

  @override
  void dispose() {
    _page.dispose();
    _backdropAlpha.dispose();
    super.dispose();
  }

  RichImageNode get _current => widget.images[_index];

  String _urlFor(int i) {
    final img = widget.images[i];
    if (_originIndexes.contains(i) && img.originUrl.isNotEmpty) {
      return img.originUrl;
    }
    return img.url.isNotEmpty ? img.url : img.originUrl;
  }

  void _prefetchNeighbors(int center) {
    if (widget.images.isEmpty) return;
    for (final delta in const [-1, 1]) {
      final target = center + delta;
      if (target >= 0 && target < widget.images.length) {
        final url = _urlFor(target);
        if (url.isNotEmpty) {
          unawaited(TiebaImageCache.instance.prefetch(url));
        }
      }
    }
  }

  Future<void> _saveCurrent() async {
    if (_saving || widget.images.isEmpty) return;
    setState(() => _saving = true);
    try {
      final url = _current.originUrl.isNotEmpty
          ? _current.originUrl
          : _current.url;
      await context.read<MediaSaver>().saveImageFromUrl(url);
      if (mounted) {
        HapticFeedback.lightImpact();
        showFrostedToast(context, '已保存到系统相册');
      }
    } on Object catch (e) {
      if (mounted) {
        showFrostedToast(context, cleanError(e), level: BannerLevel.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showActions() async {
    HapticFeedback.mediumImpact();
    final picked = await showFrostedChoices<String>(
      context,
      title: '图片操作',
      choices: const [
        FrostedChoice(value: 'save', label: '保存到相册'),
        FrostedChoice(value: 'origin', label: '查看原图'),
        FrostedChoice(value: 'copy', label: '复制图片链接'),
      ],
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case 'save':
        await _saveCurrent();
      case 'origin':
        setState(() => _originIndexes.add(_index));
      case 'copy':
        final url = _current.originUrl.isNotEmpty
            ? _current.originUrl
            : _current.url;
        await Clipboard.setData(ClipboardData(text: url));
        if (mounted) showFrostedToast(context, '已复制图片链接');
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ValueListenableBuilder<double>(
      valueListenable: _backdropAlpha,
      builder: (context, alpha, child) => ColoredBox(
        color: Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)),
        child: child,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _page,
              physics: _pageLocked
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: widget.images.length,
              onPageChanged: (i) {
                setState(() {
                  _index = i;
                  _pageLocked = false;
                });
                _prefetchNeighbors(i);
              },
              itemBuilder: (context, i) {
                return _ZoomableImageSlide(
                  key: ValueKey('viewer-slide-$i'),
                  url: _urlFor(i),
                  onTap: () => Navigator.of(context).maybePop(),
                  onLongPress: _showActions,
                  onZoomChanged: (zoomed) {
                    if (mounted && _pageLocked != zoomed) {
                      setState(() => _pageLocked = zoomed);
                    }
                  },
                  onDismissProgress: (alpha) => _backdropAlpha.value = alpha,
                  onDismissed: () => Navigator.of(context).maybePop(),
                );
              },
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _backdropAlpha,
            builder: (context, alpha, child) {
              final chromeOpacity = ((alpha - 0.55) / 0.45).clamp(0.0, 1.0);
              return IgnorePointer(
                ignoring: chromeOpacity < 0.2,
                child: Opacity(opacity: chromeOpacity, child: child),
              );
            },
            child: Stack(
              children: [
                Positioned(
                  left: 12,
                  right: 12,
                  top: top + 8,
                  child: Row(
                    children: [
                      PressScale(
                        scale: 0.92,
                        child: FrostedTapSurface(
                          onPressed: () => Navigator.of(context).maybePop(),
                          pill: true,
                          fill: const Color(0x66000000),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: GlyphIcon(
                              Glyphs.chevronBack,
                              size: 22,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: const ShapeDecoration(
                          color: Color(0x66000000),
                          shape: AppShape.full,
                        ),
                        child: Text(
                          '${_index + 1} / ${widget.images.length}',
                          style: AppTextStyle.footnote
                              .of(context)
                              .copyWith(color: const Color(0xFFFFFFFF)),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: bottom + 16,
                  child: Row(
                    children: [
                      if (widget.images.isNotEmpty &&
                          !_originIndexes.contains(_index) &&
                          _current.originUrl.isNotEmpty &&
                          _current.originUrl != _current.url)
                        PressScale(
                          scale: 0.94,
                          child: FrostedTapSurface(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() => _originIndexes.add(_index));
                            },
                            pill: true,
                            fill: const Color(0x77000000),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: Text(
                                '查看原图',
                                style: AppTextStyle.footnote
                                    .of(context)
                                    .copyWith(color: const Color(0xFFFFFFFF)),
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      PressScale(
                        scale: 0.94,
                        enabled: !_saving,
                        child: FrostedTapSurface(
                          onPressed: _saving ? null : _saveCurrent,
                          pill: true,
                          fill: const Color(0x77000000),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_saving)
                                  const ActivityIndicator(size: 14)
                                else
                                  const GlyphIcon(
                                    FrostedGlyphs.download,
                                    size: 16,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  _saving ? '保存中' : '保存',
                                  style: AppTextStyle.footnote
                                      .of(context)
                                      .copyWith(color: const Color(0xFFFFFFFF)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单张可缩放、双击定点放大、未放大时上下拖跟手关闭的大图画布。
class _ZoomableImageSlide extends StatefulWidget {
  const _ZoomableImageSlide({
    super.key,
    required this.url,
    required this.onTap,
    required this.onLongPress,
    required this.onZoomChanged,
    required this.onDismissProgress,
    required this.onDismissed,
  });

  final String url;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onZoomChanged;
  final ValueChanged<double> onDismissProgress;
  final VoidCallback onDismissed;

  @override
  State<_ZoomableImageSlide> createState() => _ZoomableImageSlideState();
}

class _ZoomableImageSlideState extends State<_ZoomableImageSlide>
    with TickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  late final AnimationController _zoomAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final CurvedAnimation _zoomCurve = CurvedAnimation(
    parent: _zoomAnim,
    curve: Curves.easeOutCubic,
  );
  late final AnimationController _dragReturnAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final CurvedAnimation _dragReturnCurve = CurvedAnimation(
    parent: _dragReturnAnim,
    curve: Curves.easeOutCubic,
  );

  final ValueNotifier<Offset> _dragOffset = ValueNotifier<Offset>(Offset.zero);
  Matrix4Tween? _matrixTween;
  Offset _doubleTapLocal = Offset.zero;
  Offset _returnStart = Offset.zero;
  bool _dismissingDrag = false;

  bool get _isZoomed => _transform.value.getMaxScaleOnAxis() > 1.04;

  @override
  void initState() {
    super.initState();
    _zoomAnim.addListener(_tickZoom);
    _dragReturnAnim.addListener(_tickDragReturn);
  }

  @override
  void dispose() {
    _zoomAnim.removeListener(_tickZoom);
    _dragReturnAnim.removeListener(_tickDragReturn);
    _zoomCurve.dispose();
    _zoomAnim.dispose();
    _dragReturnCurve.dispose();
    _dragReturnAnim.dispose();
    _transform.dispose();
    _dragOffset.dispose();
    super.dispose();
  }

  void _tickZoom() {
    final tween = _matrixTween;
    if (tween == null) return;
    _transform.value = tween.evaluate(_zoomCurve);
  }

  void _tickDragReturn() {
    final next = Offset.lerp(_returnStart, Offset.zero, _dragReturnCurve.value)!;
    _dragOffset.value = next;
    widget.onDismissProgress(_alphaForOffset(next));
  }

  double _alphaForOffset(Offset offset) =>
      (1.0 - (offset.dy.abs() / 320.0)).clamp(0.15, 1.0);

  void _handleDoubleTap() {
    final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Matrix4 target;
    if (_isZoomed) {
      target = Matrix4.identity();
      widget.onZoomChanged(false);
    } else {
      const targetScale = 2.4;
      final x = -_doubleTapLocal.dx * (targetScale - 1);
      final y = -_doubleTapLocal.dy * (targetScale - 1);
      target = Matrix4.identity()
        ..translateByDouble(x, y, 0, 1)
        ..scaleByDouble(targetScale, targetScale, 1, 1);
      widget.onZoomChanged(true);
    }
    if (disableAnim) {
      _transform.value = target;
      return;
    }
    _matrixTween = Matrix4Tween(begin: _transform.value.clone(), end: target);
    _zoomAnim
      ..stop()
      ..value = 0
      ..forward();
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_isZoomed) return;
    _dragReturnAnim.stop();
    _dismissingDrag = true;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_dismissingDrag || _isZoomed) return;
    final next = _dragOffset.value + details.delta;
    _dragOffset.value = next;
    widget.onDismissProgress(_alphaForOffset(next));
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_dismissingDrag) return;
    _dismissingDrag = false;
    final dy = _dragOffset.value.dy;
    final velocity = details.primaryVelocity ?? 0;
    if (dy.abs() > 110 || velocity.abs() > 650) {
      HapticFeedback.selectionClick();
      widget.onDismissed();
      return;
    }
    _returnStart = _dragOffset.value;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _dragOffset.value = Offset.zero;
      widget.onDismissProgress(1.0);
      return;
    }
    _dragReturnAnim
      ..stop()
      ..value = 0
      ..forward();
  }

  void _onVerticalDragCancel() {
    if (!_dismissingDrag) return;
    _dismissingDrag = false;
    _returnStart = _dragOffset.value;
    _dragReturnAnim
      ..stop()
      ..value = 0
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onDoubleTapDown: (d) => _doubleTapLocal = d.localPosition,
      onDoubleTap: _handleDoubleTap,
      onVerticalDragStart: _isZoomed ? null : _onVerticalDragStart,
      onVerticalDragUpdate: _isZoomed ? null : _onVerticalDragUpdate,
      onVerticalDragEnd: _isZoomed ? null : _onVerticalDragEnd,
      onVerticalDragCancel: _isZoomed ? null : _onVerticalDragCancel,
      child: ValueListenableBuilder<Offset>(
        valueListenable: _dragOffset,
        builder: (context, offset, child) {
          final dragFraction = (offset.dy.abs() / 360.0).clamp(0.0, 1.0);
          final scale = 1.0 - 0.18 * dragFraction;
          return Transform.translate(
            offset: offset,
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 0.85,
          maxScale: 4.0,
          onInteractionEnd: (_) {
            final zoomed = _isZoomed;
            widget.onZoomChanged(zoomed);
            if (!zoomed && _transform.value.getMaxScaleOnAxis() < 1.0) {
              _matrixTween = Matrix4Tween(
                begin: _transform.value.clone(),
                end: Matrix4.identity(),
              );
              _zoomAnim
                ..stop()
                ..value = 0
                ..forward();
            }
          },
          child: Center(
            child: RemoteImage(
              url: widget.url,
              fit: BoxFit.contain,
              resizeCache: false,
              transparentPlaceholder: true,
              fadeIn: false,
            ),
          ),
        ),
      ),
    );
  }
}
