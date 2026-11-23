import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// 分段胶囊滑块在任意瞬时位置 / 形变下的纯函数几何结果。
///
/// 独立抽取便于单元测试验证：中间项切换保留真实欠阻尼过冲，两端项触壁过冲
/// 转为弹性压墙形变，滑块全程不越出圆角轨道。
@immutable
class CapsulePillGeometry {
  const CapsulePillGeometry({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  Rect get rect => Rect.fromLTWH(left, top, width, height);

  static CapsulePillGeometry compute({
    required double position,
    required double stretch,
    required double pressBoost,
    required int count,
    required double trackWidth,
    required double trackHeight,
  }) {
    if (count <= 0 || trackWidth <= 0 || trackHeight <= 0) {
      return const CapsulePillGeometry(left: 0, top: 0, width: 0, height: 0);
    }
    final slotWidth = trackWidth / count;
    final maxPos = math.max(0.0, (count - 1).toDouble());

    final double clampedPos;
    final double wallCompression;
    final bool atLeftWall;
    final bool atRightWall;
    if (position < 0) {
      clampedPos = 0;
      wallCompression = capsuleRubberBand(-position, 0.16);
      atLeftWall = true;
      atRightWall = false;
    } else if (position > maxPos) {
      clampedPos = maxPos;
      wallCompression = capsuleRubberBand(position - maxPos, 0.16);
      atLeftWall = false;
      atRightWall = true;
    } else {
      clampedPos = position;
      wallCompression = 0;
      atLeftWall = false;
      atRightWall = false;
    }

    // 速度拉伸（水平拉长 + 垂直微压），触壁压缩时方向反转（水平微缩 + 垂直微膨）。
    final netStretch = (stretch - wallCompression * 0.85).clamp(-0.18, 0.22);
    final swell = 1.0 + pressBoost * 0.025;
    final rawWidth = (slotWidth * (1.0 + netStretch) * swell)
        .clamp(slotWidth * 0.78, math.min(trackWidth, slotWidth * 1.24))
        .toDouble();
    final rawHeight = (trackHeight * (1.0 - netStretch * 0.42) * swell)
        .clamp(trackHeight * 0.84, trackHeight)
        .toDouble();

    final double left;
    if (atLeftWall) {
      left = 0;
    } else if (atRightWall) {
      left = trackWidth - rawWidth;
    } else {
      final centerX = (clampedPos + 0.5) * slotWidth;
      left = (centerX - rawWidth / 2).clamp(0.0, trackWidth - rawWidth);
    }

    return CapsulePillGeometry(
      left: left,
      top: (trackHeight - rawHeight) / 2,
      width: rawWidth,
      height: rawHeight,
    );
  }
}

/// 把越界量压成接近线性的柔和阻力，模拟滑块撞到端壁时的橡皮筋手感。
double capsuleRubberBand(double overshoot, double limit) {
  if (overshoot <= 0 || limit <= 0) return 0;
  final pull = 1.0 - 1.0 / (overshoot * 0.55 / limit + 1.0);
  return limit * pull;
}

/// 双曲正切饱和：把瞬时速度平滑映射到 `[0, 1)`，高速滑行不会被拉成面条。
double capsuleSaturate(double value) =>
    1.0 - 2.0 / (math.exp(2.0 * value) + 1.0);

/// 独立 Ticker 驱动的连续可打断物理弹簧。
///
/// `AnimationController.animateWith` 每次重设目标都会重启 Ticker，首帧 `elapsed == 0`
/// 让值钉在原地；这里改为读取当前瞬时速度 `v0` 后重建 `SpringSimulation`，Ticker
/// 全程不重启，快速连点 / 跟手拖拽都能继承速度平滑转向。
class CapsuleSpring extends ChangeNotifier {
  CapsuleSpring(TickerProvider vsync, this._value, {this.rest = 1e-3}) {
    _ticker = vsync.createTicker(_tick);
  }

  /// 静止判定距离；速度容差按弹簧固有角频率缩放，高速弹簧不提前截断。
  final double rest;

  late final Ticker _ticker;
  double _value;
  double _target = 0;
  SpringSimulation? _simulation;
  double _now = 0;
  double _start = 0;

  double get value => _value;

  /// 目标值：弹簧已停时即当前值，供次级弹簧只在目标显著变化时才重定向。
  double get target => _simulation == null ? _value : _target;

  double get velocity => _simulation?.dx(_now - _start) ?? 0;
  bool get isAnimating => _simulation != null;

  /// 首帧（`t == 0`）瞬时速度必为 0，据此区分「刚起跑」与「已停稳」。
  bool get hasAdvanced => _now > _start;

  void springTo(
    double target,
    SpringDescription spring, {
    double? initialVelocity,
  }) {
    final v0 = initialVelocity ?? velocity;
    _simulation = SpringSimulation(
      spring,
      _value,
      target,
      v0,
      tolerance: Tolerance(
        distance: rest,
        velocity: rest * math.sqrt(spring.stiffness / spring.mass),
      ),
    );
    _target = target;
    if (_ticker.isActive) {
      _start = _now;
      return;
    }
    _now = _start = 0;
    _ticker.start();
  }

  void jumpTo(double value) {
    _simulation = null;
    _ticker.stop();
    if (_value == value) return;
    _value = value;
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    _now = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final sim = _simulation;
    if (sim == null) {
      _ticker.stop();
      return;
    }
    final t = _now - _start;
    if (sim.isDone(t)) {
      _value = _target;
      _simulation = null;
      _ticker.stop();
    } else {
      _value = sim.x(t);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// 物理弹簧分段胶囊：`prism_ui` 原生 `SegmentedControl` 的替代品。
///
/// - 欠阻尼弹簧 + 速度继承：连续点切保留当前速度平滑转向，到点自然微回弹；
/// - 速度驱动果冻拉伸与两端压墙回弹；
/// - 文字颜色 / 字重随滑块滑过实时插值；
/// - 按住胶囊左右拖拽即可跟手切换。
class FrostedSegmentedControl<T> extends StatefulWidget {
  const FrostedSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  static const double height = 44;
  static const double inset = 4;

  /// 滑块本体，测试用它断言位移与行进中的拉伸。
  static const ValueKey<String> pillKey = ValueKey<String>('capsule-pill');

  /// 点击切换的主位移弹簧：响应利落，到点带少量过冲。
  static final SpringDescription travelSpring =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 380),
        bounce: 0.24,
      );

  /// 手指拖拽时的跟手弹簧：高刚度近临界阻尼，紧跟手指又过滤手抖。
  static final SpringDescription followSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 1050, ratio: 0.88);

  /// 速度驱动果冻拉伸 / 挤压的次级欠阻尼弹簧。
  static final SpringDescription jellySpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 200, ratio: 0.48);

  /// 按住时的轻微膨胀反馈弹簧。
  static final SpringDescription pressSpring =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 220),
        bounce: 0.15,
      );

  final List<(T, String)> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  State<FrostedSegmentedControl<T>> createState() =>
      _FrostedSegmentedControlState<T>();
}

class _FrostedSegmentedControlState<T> extends State<FrostedSegmentedControl<T>>
    with TickerProviderStateMixin {
  late final CapsuleSpring _pos;
  late final CapsuleSpring _jelly;
  late final CapsuleSpring _press;

  bool _dragging = false;
  int _dragHighlightIndex = -1;

  int get _selectedIndex {
    final index = widget.segments.indexWhere((s) => s.$1 == widget.value);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _pos = CapsuleSpring(this, _selectedIndex.toDouble(), rest: 8e-4)
      ..addListener(_onPosTick);
    _jelly = CapsuleSpring(this, 0, rest: 1e-3);
    _press = CapsuleSpring(this, 0, rest: 2e-3);
  }

  @override
  void didUpdateWidget(covariant FrostedSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _selectedIndex;
    final oldIndex = oldWidget.segments.indexWhere(
      (s) => s.$1 == oldWidget.value,
    );
    if (nextIndex != oldIndex && !_dragging) {
      _animateToIndex(nextIndex);
    } else if (widget.segments.length != oldWidget.segments.length &&
        !_dragging) {
      _pos.jumpTo(nextIndex.toDouble());
      _jelly.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _pos.removeListener(_onPosTick);
    _pos.dispose();
    _jelly.dispose();
    _press.dispose();
    super.dispose();
  }

  void _onPosTick() {
    if (_dragging) return;
    // 首帧 t == 0 瞬时速度为 0，此时回零会吞掉起步拉伸脉冲。
    if (_pos.isAnimating && !_pos.hasAdvanced) return;
    final speed = _pos.velocity.abs();
    final targetStretch = _pos.isAnimating && speed > 0.15
        ? 0.16 * capsuleSaturate(speed / 5)
        : 0.0;
    if ((_jelly.target - targetStretch).abs() > 0.012 ||
        (targetStretch == 0 && _jelly.target != 0)) {
      _jelly.springTo(targetStretch, FrostedSegmentedControl.jellySpring);
    }
  }

  void _animateToIndex(int targetIndex, {double? initialVelocity}) {
    if (context.disableAnimations) {
      _pos.jumpTo(targetIndex.toDouble());
      _jelly.jumpTo(0);
      return;
    }
    final distance = (targetIndex - _pos.value).abs();
    if (distance > 0.25) {
      // 起步瞬间先给一记拉伸脉冲，启动更有张力。
      final kick = (0.09 + 0.03 * math.min(distance, 2)).clamp(0.0, 0.16);
      _jelly.springTo(kick, FrostedSegmentedControl.jellySpring);
    }
    _pos.springTo(
      targetIndex.toDouble(),
      FrostedSegmentedControl.travelSpring,
      initialVelocity: initialVelocity,
    );
  }

  void _selectSegment(int index) {
    if (index < 0 || index >= widget.segments.length) return;
    final option = widget.segments[index].$1;
    if (option == widget.value) {
      _animateToIndex(index);
      return;
    }
    HapticFeedback.selectionClick();
    _animateToIndex(index);
    widget.onChanged(option);
  }

  void _onDragStart(DragStartDetails details, double trackWidth) {
    if (widget.segments.length <= 1 || trackWidth <= 0) return;
    _dragging = true;
    _dragHighlightIndex = _selectedIndex;
    if (context.disableAnimations) {
      _press.jumpTo(1);
    } else {
      _press.springTo(1, FrostedSegmentedControl.pressSpring);
    }
    _followDrag(details.localPosition.dx, trackWidth, velocityPx: 0);
  }

  void _onDragUpdate(DragUpdateDetails details, double trackWidth) {
    if (!_dragging || trackWidth <= 0) return;
    _followDrag(
      details.localPosition.dx,
      trackWidth,
      velocityPx: details.delta.dx * 60,
    );
  }

  void _followDrag(
    double localX,
    double trackWidth, {
    required double velocityPx,
  }) {
    final count = widget.segments.length;
    final slotWidth = trackWidth / count;
    final maxIndex = (count - 1).toDouble();
    final raw = localX / slotWidth - 0.5;
    final target = raw < 0
        ? -capsuleRubberBand(-raw, 0.22)
        : raw > maxIndex
        ? maxIndex + capsuleRubberBand(raw - maxIndex, 0.22)
        : raw;

    if (context.disableAnimations) {
      _pos.jumpTo(target.clamp(0.0, maxIndex));
    } else {
      _pos.springTo(target, FrostedSegmentedControl.followSpring);
      final segmentVelocity = velocityPx / math.max(1.0, slotWidth);
      final stretch = 0.12 * capsuleSaturate(segmentVelocity.abs() / 5);
      _jelly.springTo(stretch, FrostedSegmentedControl.jellySpring);
    }

    final hovered = raw.round().clamp(0, count - 1);
    if (hovered != _dragHighlightIndex) {
      _dragHighlightIndex = hovered;
      HapticFeedback.selectionClick();
    }
  }

  void _onDragEnd(DragEndDetails details, double trackWidth) {
    if (!_dragging) return;
    _dragging = false;
    if (context.disableAnimations) {
      _press.jumpTo(0);
    } else {
      _press.springTo(0, FrostedSegmentedControl.pressSpring);
    }

    final count = widget.segments.length;
    final slotWidth = trackWidth > 0 ? trackWidth / count : 60.0;
    final segmentVelocity = details.velocity.pixelsPerSecond.dx / slotWidth;
    // 快速短拖时跟手弹簧还没追上手指，落格用目标位 + 轻度速度预测。
    final projected = (_pos.target + segmentVelocity * 0.06).round().clamp(
      0,
      count - 1,
    );
    _jelly.springTo(0, FrostedSegmentedControl.jellySpring);
    _animateToIndex(
      projected,
      initialVelocity: segmentVelocity.clamp(-14.0, 14.0),
    );
    final option = widget.segments[projected].$1;
    if (option != widget.value) {
      widget.onChanged(option);
    }
  }

  void _onDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    if (context.disableAnimations) {
      _press.jumpTo(0);
      _jelly.jumpTo(0);
    } else {
      _press.springTo(0, FrostedSegmentedControl.pressSpring);
      _jelly.springTo(0, FrostedSegmentedControl.jellySpring);
    }
    _animateToIndex(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final count = widget.segments.length;
    final baseStyle = AppTextStyle.subheadline.of(context);
    final animation = Listenable.merge([_pos, _jelly, _press]);

    return Container(
      height: FrostedSegmentedControl.height,
      padding: const EdgeInsets.all(FrostedSegmentedControl.inset),
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
        shape: AppShape.full,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          final trackHeight = constraints.maxHeight;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (d) => _onDragStart(d, trackWidth),
            onHorizontalDragUpdate: (d) => _onDragUpdate(d, trackWidth),
            onHorizontalDragEnd: (d) => _onDragEnd(d, trackWidth),
            onHorizontalDragCancel: _onDragCancel,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final geometry = CapsulePillGeometry.compute(
                  position: _pos.value,
                  stretch: _jelly.value,
                  pressBoost: _press.value,
                  count: count,
                  trackWidth: trackWidth,
                  trackHeight: trackHeight,
                );
                final visualPosition = _pos.value.clamp(
                  0.0,
                  math.max(0.0, (count - 1).toDouble()),
                );

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (count > 0)
                      Positioned(
                        left: geometry.left,
                        top: geometry.top,
                        width: geometry.width,
                        height: geometry.height,
                        child: DecoratedBox(
                          key: FrostedSegmentedControl.pillKey,
                          decoration: ShapeDecoration(
                            color: colorScheme.primary,
                            shape: AppShape.full,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        for (var i = 0; i < count; i++)
                          Expanded(
                            child: _CapsuleSegment(
                              label: widget.segments[i].$2,
                              selected: widget.segments[i].$1 == widget.value,
                              focus: Curves.easeInOut.transform(
                                (1.0 - (visualPosition - i).abs()).clamp(
                                  0.0,
                                  1.0,
                                ),
                              ),
                              baseStyle: baseStyle,
                              colorScheme: colorScheme,
                              onTap: () => _selectSegment(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CapsuleSegment extends StatelessWidget {
  const _CapsuleSegment({
    required this.label,
    required this.selected,
    required this.focus,
    required this.baseStyle,
    required this.colorScheme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double focus;
  final TextStyle baseStyle;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      colorScheme.onSurfaceVariant,
      colorScheme.onPrimary,
      focus,
    )!;
    final weight = FontWeight.lerp(FontWeight.w400, FontWeight.w600, focus);
    final scale = lerpDouble(1, 1.02, focus)!;

    return PressSurface(
      fill: const Color(0x00000000),
      shape: AppShape.full,
      look: selected ? PressLook.none : PressLook.ink,
      ringStandsOff: selected,
      selected: selected,
      childFills: true,
      onPressed: onTap,
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: baseStyle.copyWith(color: color, fontWeight: weight),
          ),
        ),
      ),
    );
  }
}
