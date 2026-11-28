import 'dart:async';

import 'package:flutter/gestures.dart' show kTouchSlop;
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
/// - 双指手势缩放（实时倍率提示）、双击定点平滑缩放、放大后可单指拖动、
///   深度放大时自动换原图保证细节清晰；未放大时上下拖跟手关闭。
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
  bool _sharing = false;

  /// 当前屏幕上按下的手指。
  final Set<int> _activePointers = <int>{};
  bool _imageZoomed = false;

  /// 翻页由自己数指针实现：PageView 自带的横向拖动会抢在捏合之前赢下手势，
  /// 第一根手指先横向动过的「错峰捏合」就会失效，所以它只负责渲染。
  int? _swipePointer;
  int _swipeFromIndex = 0;
  Offset _swipeStart = Offset.zero;
  Offset? _swipeLastPosition;
  Duration? _swipeLastTime;
  double _swipeVelocity = 0;
  double _swipeStartPixels = 0;
  bool _swiping = false;

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

  /// 双指放大到一定倍率后自动换原图：缩略图放大约 1.6 倍就只剩马赛克。
  void _upgradeToOrigin(int index) {
    if (index < 0 || index >= widget.images.length) return;
    if (_originIndexes.contains(index)) return;
    final img = widget.images[index];
    if (img.originUrl.isEmpty || img.originUrl == img.url) return;
    setState(() => _originIndexes.add(index));
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length > 1) {
      _cancelSwipe();
      return;
    }
    if (_imageZoomed || !_page.hasClients) return;
    _swipePointer = event.pointer;
    _swipeFromIndex = _index;
    _swipeStart = event.position;
    _swipeStartPixels = _page.position.pixels;
    _swipeLastPosition = event.position;
    _swipeLastTime = event.timeStamp;
    _swipeVelocity = 0;
    _swiping = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _swipePointer) return;
    if (_activePointers.length > 1 || _imageZoomed) {
      _cancelSwipe();
      return;
    }
    final delta = event.position - _swipeStart;
    if (!_swiping) {
      if (delta.distance < 12) return;
      // 以竖向为主：交给本页的上下拖关闭，不翻页。
      if (delta.dx.abs() <= delta.dy.abs() * 1.2) {
        _swipePointer = null;
        return;
      }
      _swiping = true;
      _swipeFromIndex = _index;
      _swipeStartPixels = _page.position.pixels;
    }
    final last = _swipeLastPosition;
    final lastTime = _swipeLastTime;
    if (last != null && lastTime != null) {
      final elapsed = (event.timeStamp - lastTime).inMicroseconds / 1e6;
      if (elapsed > 0.001) {
        _swipeVelocity = (event.position.dx - last.dx) / elapsed;
      }
    }
    _swipeLastPosition = event.position;
    _swipeLastTime = event.timeStamp;
    final position = _page.position;
    position.jumpTo(
      (_swipeStartPixels - delta.dx).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  void _onPointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (event.pointer != _swipePointer) return;
    final wasSwiping = _swiping;
    final velocity = _swipeVelocity;
    _swipePointer = null;
    _swiping = false;
    _swipeLastPosition = null;
    _swipeLastTime = null;
    if (!wasSwiping || !_page.hasClients) return;
    final metrics = _page.position;
    final width = metrics.viewportDimension;
    final deltaPages = (metrics.pixels - _swipeStartPixels) / width;
    var target = _swipeFromIndex;
    if (deltaPages > 0.25 || velocity < -500) {
      target = _swipeFromIndex + 1;
    } else if (deltaPages < -0.25 || velocity > 500) {
      target = _swipeFromIndex - 1;
    }
    _animateToPage(target.clamp(0, widget.images.length - 1));
  }

  void _cancelSwipe() {
    final wasSwiping = _swiping;
    _swipePointer = null;
    _swiping = false;
    _swipeLastPosition = null;
    _swipeLastTime = null;
    if (wasSwiping) _animateToPage(_swipeFromIndex);
  }

  void _animateToPage(int target) {
    if (!_page.hasClients) return;
    _page.animateToPage(
      target,
      duration: MediaQuery.maybeDisableAnimationsOf(context) ?? false
          ? Duration.zero
          : const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
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

  Future<void> _shareCurrent() async {
    if (_sharing || widget.images.isEmpty) return;
    setState(() => _sharing = true);
    try {
      final url = _current.originUrl.isNotEmpty
          ? _current.originUrl
          : _current.url;
      final ok = await context.read<MediaSaver>().shareImageFromUrl(url);
      if (!ok && mounted) {
        showFrostedToast(context, '分享图片失败', level: BannerLevel.error);
      }
    } on Object catch (e) {
      if (mounted) {
        showFrostedToast(context, cleanError(e), level: BannerLevel.error);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _showActions() async {
    HapticFeedback.mediumImpact();
    final picked = await showFrostedChoices<String>(
      context,
      title: '图片操作',
      choices: const [
        FrostedChoice(value: 'save', label: '保存到相册'),
        FrostedChoice(value: 'share', label: '分享图片'),
        FrostedChoice(value: 'origin', label: '查看原图'),
        FrostedChoice(value: 'copy', label: '复制图片链接'),
      ],
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case 'save':
        await _saveCurrent();
      case 'share':
        await _shareCurrent();
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
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerEnd,
              onPointerCancel: _onPointerEnd,
              child: PageView.builder(
                controller: _page,
                // 翻页手势由本页的 Listener 接管，PageView 只渲染与承接
                // 程序化的 jumpTo / animateToPage。
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.images.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _prefetchNeighbors(i);
                },
                itemBuilder: (context, i) {
                  final img = widget.images[i];
                  final canUpgrade =
                      !_originIndexes.contains(i) &&
                      img.originUrl.isNotEmpty &&
                      img.originUrl != img.url;
                  return _ZoomableImageSlide(
                    key: ValueKey('viewer-slide-$i'),
                    url: _urlFor(i),
                    canUpgrade: canUpgrade,
                    onUpgrade: () => _upgradeToOrigin(i),
                    onTap: () => Navigator.of(context).maybePop(),
                    onLongPress: _showActions,
                    onZoomChanged: (zoomed) {
                      _imageZoomed = zoomed;
                      if (zoomed) _cancelSwipe();
                    },
                    onDismissProgress: (alpha) => _backdropAlpha.value = alpha,
                    onDismissed: () => Navigator.of(context).maybePop(),
                  );
                },
              ),
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
    required this.canUpgrade,
    required this.onUpgrade,
    required this.onTap,
    required this.onLongPress,
    required this.onZoomChanged,
    required this.onDismissProgress,
    required this.onDismissed,
  });

  final String url;

  /// 这张图还有更清晰的原图可换：深度放大时由 [onUpgrade] 触发。
  final bool canUpgrade;
  final VoidCallback onUpgrade;
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
  /// 双击目标倍率：够看清文字，又不至于一下糊成马赛克。
  static const double _doubleTapScale = 2.4;

  /// 低于这个倍率视为没放大，松手弹回 1x。
  static const double _zoomResetScale = 1.08;

  /// 超过这个倍率换原图，缩略图到这里已经没有细节了。
  static const double _upgradeScale = 1.6;

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
  bool _upgradeRequested = false;

  /// 本张图上的手指。下拉关闭自己数指针、自己算位移，不再挂
  /// `onVerticalDrag*`：竖向捏合时那套识别器会先抢到第一根手指，导致捏合失效。
  final Set<int> _pointers = <int>{};

  int? _dragPointer;
  Offset _dragStart = Offset.zero;
  Offset? _lastMovePosition;
  Duration? _lastMoveTime;
  double _dragVelocity = 0;
  bool _dragCandidate = false;
  bool _dragging = false;

  void _onPointerDown(PointerDownEvent event) {
    setState(() => _pointers.add(event.pointer));
    if (_pointers.length > 1) {
      _cancelDismissDrag();
      return;
    }
    if (_isZoomed) return;
    _dragPointer = event.pointer;
    _dragStart = event.position;
    _lastMovePosition = event.position;
    _lastMoveTime = event.timeStamp;
    _dragVelocity = 0;
    _dragCandidate = true;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _dragPointer) return;
    if (!_dragCandidate || _pointers.length > 1 || _isZoomed) return;
    final delta = event.position - _dragStart;
    if (!_dragging) {
      if (delta.distance < kTouchSlop) return;
      // 以竖向为主才算下拉关闭；横向为主留给 PageView 翻页。
      if (delta.dx.abs() > delta.dy.abs() * 1.2) {
        _dragCandidate = false;
        return;
      }
      _dragging = true;
      _dragReturnAnim.stop();
    }
    final last = _lastMovePosition;
    final lastTime = _lastMoveTime;
    if (last != null && lastTime != null) {
      final elapsed = (event.timeStamp - lastTime).inMicroseconds / 1e6;
      if (elapsed > 0.001) _dragVelocity = (event.position.dy - last.dy) / elapsed;
    }
    _lastMovePosition = event.position;
    _lastMoveTime = event.timeStamp;
    final offset = Offset(0, delta.dy);
    _dragOffset.value = offset;
    widget.onDismissProgress(_alphaForOffset(offset));
  }

  void _onPointerEnd(PointerEvent event) {
    final wasDragging = _dragging;
    final pointer = event.pointer;
    setState(() => _pointers.remove(pointer));
    if (pointer != _dragPointer) return;
    _dragPointer = null;
    _dragCandidate = false;
    _dragging = false;
    _lastMovePosition = null;
    _lastMoveTime = null;
    if (!wasDragging) return;
    if (event is PointerCancelEvent) {
      _springDragBack();
      return;
    }
    final dy = _dragOffset.value.dy;
    if (dy.abs() > 110 || _dragVelocity.abs() > 650) {
      HapticFeedback.selectionClick();
      widget.onDismissed();
      return;
    }
    _springDragBack();
  }

  void _cancelDismissDrag() {
    _dragCandidate = false;
    _dragging = false;
    _dragPointer = null;
    _lastMovePosition = null;
    _lastMoveTime = null;
    if (_dragOffset.value != Offset.zero) _springDragBack();
  }

  void _springDragBack() {
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
    final Matrix4 target;
    if (_isZoomed) {
      target = Matrix4.identity();
      widget.onZoomChanged(false);
    } else {
      final x = -_doubleTapLocal.dx * (_doubleTapScale - 1);
      final y = -_doubleTapLocal.dy * (_doubleTapScale - 1);
      target = Matrix4.identity()
        ..translateByDouble(x, y, 0, 1)
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
      widget.onZoomChanged(true);
      _maybeUpgrade(_doubleTapScale);
    }
    _animateTo(target);
  }

  void _animateTo(Matrix4 target) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _transform.value = target;
      return;
    }
    _matrixTween = Matrix4Tween(begin: _transform.value.clone(), end: target);
    _zoomAnim
      ..stop()
      ..value = 0
      ..forward();
  }

  /// 放大到能看清细节时把缩略图换成原图；每张图只请求一次。
  void _maybeUpgrade(double scale) {
    if (_upgradeRequested || !widget.canUpgrade || scale < _upgradeScale) {
      return;
    }
    _upgradeRequested = true;
    widget.onUpgrade();
  }

  void _onInteractionStart(ScaleStartDetails details) {
    // 1x 下 pan 已关闭，收到多指手势基本就是双指缩放：先把翻页锁住，
    // 免得 PageView 在第二根手指落下前把第一根手指抢走。
    if (details.pointerCount >= 2) {
      widget.onZoomChanged(true);
    }
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    _maybeUpgrade(_transform.value.getMaxScaleOnAxis());
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    final scale = _transform.value.getMaxScaleOnAxis();
    if (scale < _zoomResetScale) {
      // 差一点点没放大成功的直接弹回 1x，别留在「既没放大又翻不了页」的状态。
      if (scale != 1.0) _animateTo(Matrix4.identity());
      widget.onZoomChanged(false);
      return;
    }
    widget.onZoomChanged(true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pointers.length > 1 ? null : widget.onTap,
            // 双指落下后摘掉长按识别器：按住不动再捏合时，它会把第一根手指抢走。
            onLongPress: _pointers.length > 1 ? null : widget.onLongPress,
            onDoubleTapDown: (d) => _doubleTapLocal = d.localPosition,
            onDoubleTap: _handleDoubleTap,
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
                // 1x 时把单指平移关掉，把横滑留给翻页、上下拖留给下拉关闭；
                // 放大后再恢复，才能拖到画面外的细节。
                panEnabled: _isZoomed,
                minScale: 1.0,
                maxScale: 5.0,
                onInteractionStart: _onInteractionStart,
                onInteractionUpdate: _onInteractionUpdate,
                onInteractionEnd: _onInteractionEnd,
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
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 96,
          child: IgnorePointer(
            child: Center(child: _ZoomBadge(controller: _transform)),
          ),
        ),
      ],
    );
  }
}

/// 手势缩放时浮出的倍率提示，松手回到 1x 后自动淡出。
class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge({required this.controller});

  final TransformationController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Matrix4>(
      valueListenable: controller,
      builder: (context, matrix, _) {
        final scale = matrix.getMaxScaleOnAxis();
        return AnimatedOpacity(
          opacity: scale > 1.05 ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: DecoratedBox(
            decoration: const ShapeDecoration(
              color: Color(0x77000000),
              shape: AppShape.full,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                '${scale.toStringAsFixed(1)}×',
                style: AppTextStyle.caption1
                    .of(context)
                    .copyWith(
                      color: const Color(0xFFFFFFFF),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        );
      },
    );
  }
}
