import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// 按下即缩小的触感容器（L1 动效规范：进 90ms / 出 140ms，移动 > 10px 回弹，只动 transform）。
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    this.scale = 0.985,
    this.enabled = true,
    required this.child,
  });

  final double scale;
  final bool enabled;
  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  static const _cancelSlop = 10.0;

  late final _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 140),
  );
  late final _curve = CurvedAnimation(
    parent: _press,
    curve: Curves.easeOutCubic,
  );

  int? _pointer;
  Offset? _origin;

  @override
  void dispose() {
    _curve.dispose();
    _press.dispose();
    super.dispose();
  }

  bool get _active => widget.enabled && !context.disableAnimations;

  void _onDown(PointerDownEvent event) {
    if (!_active || _pointer != null) return;
    _pointer = event.pointer;
    _origin = event.position;
    _press.forward();
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if ((event.position - _origin!).distance > _cancelSlop) _release();
  }

  void _release() {
    if (_pointer == null) return;
    _pointer = null;
    _origin = null;
    _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Transform.scale(
          scale: 1 - (1 - widget.scale) * _curve.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// 数值变化滚动动效（L3 动效规范：180ms easeOutCubic，只动 transform + opacity）。
class CountRoll extends StatelessWidget {
  const CountRoll({
    super.key,
    required this.text,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (context.disableAnimations) {
      return Text(text, style: style, maxLines: 1);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(anim);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Text(
        text,
        key: ValueKey(text),
        style: style,
        maxLines: 1,
      ),
    );
  }
}
