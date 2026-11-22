import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// 左右滑动切页：手指横拖时把目标页交给 [onIndexChanged]，页面本身由调用方按
/// 这个值重建，所以这里不持有任何页面状态。
///
/// 不用 PageView：页面里是纵向列表，横拖一旦被它认领，列表的纵向拖动就要等手势
/// 竞技场裁决，快速上下滑会先被横拖吃掉一截。这里只挂横向识别器，纵向拖动原样
/// 留给列表；页面内部自己的横滑（如热榜的分类条）仍归内层滚动。
class SwipePager extends StatefulWidget {
  const SwipePager({
    super.key,
    required this.index,
    required this.count,
    required this.onIndexChanged,
    required this.child,
    this.enabled = true,
    this.dragStartBehavior = DragStartBehavior.start,
  });

  final int index;
  final int count;
  final ValueChanged<int> onIndexChanged;
  final Widget child;
  final bool enabled;
  final DragStartBehavior dragStartBehavior;

  @override
  State<SwipePager> createState() => _SwipePagerState();
}

class _SwipePagerState extends State<SwipePager> {
  /// 松手时走过的屏宽比例，或甩出的速度，够一个就切。
  static const _commitFraction = 0.22;
  static const _commitVelocity = 320.0;

  double _dx = 0;

  bool get _canSwipe => widget.enabled && widget.count > 1;

  void _onStart(DragStartDetails details) => _dx = 0;

  void _onUpdate(DragUpdateDetails details) => _dx += details.delta.dx;

  void _onEnd(DragEndDetails details) {
    final width = context.size?.width ?? 0;
    if (width <= 0) return;
    final velocity = details.primaryVelocity ?? 0;
    final far = _dx.abs() > width * _commitFraction;
    final fast = velocity.abs() > _commitVelocity;
    if (!far && !fast) return;
    final step = _dx < 0 ? 1 : -1;
    final next = (widget.index + step).clamp(0, widget.count - 1);
    if (next != widget.index) widget.onIndexChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (!_canSwipe) return widget.child;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        HorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(debugOwner: this),
              (recognizer) => recognizer
                ..dragStartBehavior = widget.dragStartBehavior
                ..onStart = _onStart
                ..onUpdate = _onUpdate
                ..onEnd = _onEnd,
            ),
      },
      child: widget.child,
    );
  }
}
