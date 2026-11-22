import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import 'glyphs.dart';

/// Prism 风格顶部药丸下拉刷新（阻尼跟手、过阈轻震、图标旋转，零子列表重建开销）。
class FrostedRefresh extends StatefulWidget {
  const FrostedRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.topInset = 0,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double topInset;

  @override
  State<FrostedRefresh> createState() => _FrostedRefreshState();
}

class _FrostedRefreshState extends State<FrostedRefresh>
    with SingleTickerProviderStateMixin {
  static const _threshold = 72.0;
  static const _maxPull = 132.0;
  static const _hold = 54.0;

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _settle,
    curve: Curves.easeOutCubic,
  );
  final ValueNotifier<double> _pullNotifier = ValueNotifier<double>(0);
  final ValueNotifier<bool> _refreshingNotifier = ValueNotifier<bool>(false);

  double _from = 0;
  double _to = 0;
  bool _atTop = true;
  bool _tracking = false;
  bool _crossedThreshold = false;
  int? _pointer;
  double _startX = 0;
  double _startY = 0;
  double _startPull = 0;

  double get _pull => _pullNotifier.value;
  bool get _refreshing => _refreshingNotifier.value;

  @override
  void initState() {
    super.initState();
    _settle.addListener(_tick);
  }

  @override
  void dispose() {
    _settle.removeListener(_tick);
    _curve.dispose();
    _settle.dispose();
    _pullNotifier.dispose();
    _refreshingNotifier.dispose();
    super.dispose();
  }

  void _tick() {
    final value = _from + (_to - _from) * _curve.value;
    if (value != _pullNotifier.value) {
      _pullNotifier.value = value;
    }
  }

  void _animateTo(double target) {
    _from = _pull;
    _to = target;
    final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnim) {
      _pullNotifier.value = target;
      return;
    }
    _settle
      ..stop()
      ..value = 0
      ..forward();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      _atTop = notification.metrics.extentBefore <= 0.5;
      if (!_atTop && _tracking && _pull <= 0.5) {
        _tracking = false;
      }
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_refreshing || _pointer != null) return;
    _pointer = event.pointer;
    _tracking = _atTop;
    _crossedThreshold = false;
    _startX = event.position.dx;
    _startY = event.position.dy;
    _startPull = _pull;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_tracking || event.pointer != _pointer) return;
    final dx = event.position.dx - _startX;
    final dy = event.position.dy - _startY;

    // 横滑主导（如 SwipePager）或向上滚动时立即让出，避免误触下拉刷新。
    if (_pull <= 0.5) {
      if (dy < -6 || (dx.abs() > 8 && dx.abs() > dy.abs() * 1.15)) {
        _tracking = false;
        return;
      }
    }
    if (dy <= 0 && _startPull <= 0) {
      if (_pull != 0) _pullNotifier.value = 0;
      return;
    }

    // 柔和非线性阻尼：阈值前线性顺滑，越过阈值后逐级加大阻尼，接近原生弹簧手感。
    final raw = (_startPull + dy * 0.58).clamp(0.0, 420.0);
    final double next;
    if (raw <= _threshold) {
      next = raw;
    } else {
      final extra = raw - _threshold;
      next = _threshold + (_maxPull - _threshold) * (extra / (extra + 88.0));
    }

    if (!_crossedThreshold && next >= _threshold) {
      _crossedThreshold = true;
      HapticFeedback.selectionClick();
    } else if (_crossedThreshold && next < _threshold - 8) {
      _crossedThreshold = false;
    }

    if (next == _pull) return;
    _settle.stop();
    _pullNotifier.value = next;
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    final tracking = _tracking;
    _tracking = false;
    _crossedThreshold = false;
    if (!tracking) return;
    if (_pull >= _threshold) {
      _start();
    } else if (_pull > 0) {
      _animateTo(0);
    }
  }

  Future<void> _start() async {
    if (_refreshing) return;
    _refreshingNotifier.value = true;
    _animateTo(_hold);
    try {
      await widget.onRefresh();
    } on Object {
      // 由调用方提示
    } finally {
      if (mounted) {
        _refreshingNotifier.value = false;
        _animateTo(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerEnd,
              onPointerCancel: _onPointerEnd,
              child: widget.child,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                _pullNotifier,
                _refreshingNotifier,
              ]),
              builder: (context, _) {
                final pull = _pullNotifier.value;
                final refreshing = _refreshingNotifier.value;
                if (pull <= 0.5 && !refreshing) {
                  return const SizedBox.shrink();
                }
                final scheme = context.colorScheme;
                final progress = (pull / _threshold).clamp(0.0, 1.0);
                final ready = pull >= _threshold;
                final shown = refreshing ? 1.0 : progress;
                final overRatio = ((pull - _threshold) / (_maxPull - _threshold))
                    .clamp(0.0, 1.0);
                final scale = refreshing
                    ? 1.0
                    : (0.72 + 0.28 * shown + (ready ? 0.06 * (1 - overRatio * 0.4) : 0.0));

                return Transform.translate(
                  offset: Offset(0, widget.topInset + 6 + pull * 0.55),
                  child: Center(
                    child: Opacity(
                      opacity: shown,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: SurfaceLevel.floatingOf(scheme).colorOf(scheme),
                            shadows: dockShadows(scheme),
                            shape: AppShape.full,
                          ),
                          child: refreshing
                              ? const ActivityIndicator(size: 16)
                              : Transform.rotate(
                                  angle: progress * math.pi * 1.4,
                                  child: GlyphIcon(
                                    FrostedGlyphs.refresh,
                                    size: 16,
                                    color: ready
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
