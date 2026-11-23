import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import 'segmented_capsule.dart';

/// 滚动胶囊标签条里的一项：宽度按文字自适应，选中后可再点一次弹出排序菜单。
class CapsuleTabItem<T> {
  const CapsuleTabItem({
    required this.value,
    required this.label,
    this.onMenuTap,
  });

  final T value;
  final String label;

  /// 已选中时再点一次该项触发的排序菜单；为 null 时该项不带 ▾。
  final Future<void> Function()? onMenuTap;
}

/// 可横向滚动的胶囊标签条：贴吧吧主页红框里的「最新 ▾ / 精品 / 分区…」。
///
/// 与 [FrostedSegmentedControl] 共用弹簧底座，区别是每项按文字宽度自适应：
/// 项数多到装不下时可以横滑；装得下时按住横拖即跟手切换。
class CapsuleTabStrip<T> extends StatefulWidget {
  const CapsuleTabStrip({
    super.key,
    required this.tabs,
    required this.value,
    required this.onChanged,
  });

  static const double height = FrostedSegmentedControl.height;
  static const double inset = FrostedSegmentedControl.inset;

  /// 项内左右留白，同时作为滚动时保留在可视边缘的呼吸位。
  static const double _lead = 12;

  /// 滑块本体，测试用它断言选中项真的移动了。
  static const ValueKey<String> pillKey = ValueKey<String>('capsule-tab-pill');

  final List<CapsuleTabItem<T>> tabs;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  State<CapsuleTabStrip<T>> createState() => _CapsuleTabStripState<T>();
}

class _CapsuleTabStripState<T> extends State<CapsuleTabStrip<T>>
    with TickerProviderStateMixin {
  static final _travelSpring = FrostedSegmentedControl.travelSpring;

  final ScrollController _scroll = ScrollController();
  late final CapsuleSpring _left;
  late final CapsuleSpring _width;

  late List<GlobalKey> _keys = _newKeys(widget.tabs.length);
  List<double> _itemWidths = const [];
  double _viewportWidth = 0;

  /// 第一帧测量后直接落位，之后的目标变化才走弹簧。
  bool _pillPlaced = false;
  int _pillIndex = 0;
  int? _revealedIndex;
  bool _overflows = false;

  bool _dragging = false;
  int _dragIndex = -1;
  double _dragPosition = 0;

  bool get _fits => !_overflows;

  int get _index {
    final index = widget.tabs.indexWhere((tab) => tab.value == widget.value);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _left = CapsuleSpring(this, 0, rest: 0.05);
    _width = CapsuleSpring(this, 0, rest: 0.05);
    _pillIndex = _index;
  }

  @override
  void didUpdateWidget(covariant CapsuleTabStrip<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) {
      _keys = _newKeys(widget.tabs.length);
      _itemWidths = const [];
      _pillPlaced = false;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _left.dispose();
    _width.dispose();
    super.dispose();
  }

  static List<GlobalKey> _newKeys(int count) =>
      List<GlobalKey>.generate(count, (_) => GlobalKey());

  Rect? _rectOf(int index) {
    if (index < 0 || index >= _itemWidths.length) return null;
    var left = 0.0;
    for (var i = 0; i < index; i++) {
      left += _itemWidths[i];
    }
    return Rect.fromLTWH(left, 0, _itemWidths[index], 0);
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measure();
    });
  }

  void _measure() {
    if (_viewportWidth <= 0 || _keys.isEmpty) return;
    final widths = <double>[];
    for (final key in _keys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      widths.add(box.size.width);
    }
    if (widths.length != _keys.length) return;

    final widthsChanged =
        widths.length != _itemWidths.length ||
        [
          for (var i = 0; i < widths.length; i++) widths[i] != _itemWidths[i],
        ].any((changed) => changed);
    _itemWidths = widths;

    final contentWidth = widths.fold<double>(0, (sum, w) => sum + w);
    final overflows =
        contentWidth > _viewportWidth - CapsuleTabStrip.inset * 2 + 0.5;
    if (overflows != _overflows) {
      _overflows = overflows;
      setState(() {});
    }

    if (!_pillPlaced) {
      _pillPlaced = true;
      _pillIndex = _index;
      _placePillAt(_index, animate: false);
    } else if (widthsChanged || _pillIndex != _index) {
      _pillIndex = _index;
      _placePillAt(_index, animate: true);
    }

    if (_revealedIndex != _index) {
      _revealedIndex = _index;
      _revealSelection();
    }
  }

  /// 把滑块挪到第 [index] 项：第一次直接落位，之后交给弹簧。
  void _placePillAt(int index, {required bool animate, double? velocity}) {
    final rect = _rectOf(index);
    if (rect == null) return;
    if (!animate || context.disableAnimations) {
      _left.jumpTo(rect.left);
      _width.jumpTo(rect.width);
      return;
    }
    _left.springTo(rect.left, _travelSpring, initialVelocity: velocity);
    _width.springTo(rect.width, _travelSpring, initialVelocity: velocity);
  }

  /// 让当前标签完整落在可视区里，切换后不会被裁在边缘。
  void _revealSelection() {
    if (!_scroll.hasClients || _itemWidths.isEmpty) return;
    final rect = _rectOf(_index);
    if (rect == null) return;
    final position = _scroll.position;
    const lead = CapsuleTabStrip._lead;
    final visibleLeft = position.pixels + lead;
    final visibleRight = position.pixels + position.viewportDimension - lead;
    final double target;
    if (rect.left < visibleLeft) {
      target = rect.left - lead;
    } else if (rect.right > visibleRight) {
      target = rect.right - position.viewportDimension + lead;
    } else {
      return;
    }
    final clamped = target.clamp(0.0, position.maxScrollExtent);
    if ((clamped - position.pixels).abs() < 0.5) return;
    if (context.disableAnimations) {
      _scroll.jumpTo(clamped);
    } else {
      _scroll.animateTo(
        clamped,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// 手指所在的分数位置（第几项 + 项内比例），用于跟手拖拽求插值。
  double _positionAt(double x) {
    if (_itemWidths.isEmpty) return 0;
    var acc = 0.0;
    for (var i = 0; i < _itemWidths.length; i++) {
      final width = _itemWidths[i];
      if (x <= acc + width || i == _itemWidths.length - 1) {
        final t = ((x - acc) / width).clamp(0.0, 1.0);
        return i + t;
      }
      acc += width;
    }
    return 0;
  }

  void _dragTo(double x) {
    final count = widget.tabs.length;
    if (count <= 1 || _itemWidths.isEmpty) return;
    final maxPosition = (count - 1).toDouble();
    final raw = _positionAt(x);
    _dragPosition = raw < 0
        ? -capsuleRubberBand(-raw, 0.3)
        : raw > maxPosition
        ? maxPosition + capsuleRubberBand(raw - maxPosition, 0.3)
        : raw;

    final base = _dragPosition.floor().clamp(0, count - 1);
    final next = math.min(base + 1, count - 1);
    final t = (_dragPosition - base).clamp(0.0, 1.0);
    final from = _rectOf(base);
    final to = _rectOf(next);
    if (from == null || to == null) return;
    _left.jumpTo(lerpDouble(from.left, to.left, t)!);
    _width.jumpTo(lerpDouble(from.width, to.width, t)!);

    final hovered = _dragPosition.round().clamp(0, count - 1);
    if (hovered != _dragIndex) {
      _dragIndex = hovered;
      HapticFeedback.selectionClick();
    }
  }

  void _onSelect(int index) {
    if (index < 0 || index >= widget.tabs.length) return;
    final tab = widget.tabs[index];
    if (tab.value == widget.value) {
      final menu = tab.onMenuTap;
      if (menu != null) {
        HapticFeedback.selectionClick();
        menu();
      }
      return;
    }
    HapticFeedback.selectionClick();
    _pillIndex = index;
    _placePillAt(index, animate: true);
    widget.onChanged(tab.value);
  }

  void _onDragStart(DragStartDetails details) {
    if (!_fits || widget.tabs.length <= 1) return;
    _dragging = true;
    _dragIndex = _index;
    _dragTo(details.localPosition.dx);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _dragTo(details.localPosition.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final count = widget.tabs.length;
    final averageWidth = _itemWidths.isEmpty
        ? 1.0
        : _itemWidths.fold<double>(0, (sum, w) => sum + w) / _itemWidths.length;
    final velocity =
        (details.primaryVelocity ?? 0) / math.max(1.0, averageWidth);
    final projected = (_dragPosition + velocity * 0.06).round().clamp(
      0,
      count - 1,
    );
    final tab = widget.tabs[projected];
    _pillIndex = projected;
    _placePillAt(projected, animate: true);
    if (tab.value != widget.value) {
      widget.onChanged(tab.value);
    }
  }

  void _onDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _pillIndex = _index;
    _placePillAt(_index, animate: true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final baseStyle = AppTextStyle.subheadline.of(context);
    final index = _index;
    _scheduleMeasure();

    Widget strip = LayoutBuilder(
      builder: (context, constraints) {
        _viewportWidth = constraints.maxWidth;
        final trackHeight = CapsuleTabStrip.height - CapsuleTabStrip.inset * 2;
        return Container(
          height: CapsuleTabStrip.height,
          padding: const EdgeInsets.all(CapsuleTabStrip.inset),
          decoration: ShapeDecoration(
            color: context.raisedSurfaceLevel.colorOf(colorScheme),
            shape: AppShape.full,
          ),
          child: ClipPath(
            clipper: const ShapeBorderClipper(shape: AppShape.full),
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              physics: _fits
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              child: AnimatedBuilder(
                animation: Listenable.merge([_left, _width]),
                builder: (context, _) {
                  final pillWidth = _width.value;
                  final pillLeft = _left.value;
                  final hasPill = pillWidth > 0.5;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (hasPill)
                        Positioned(
                          left: pillLeft,
                          top: 0,
                          width: pillWidth,
                          height: trackHeight,
                          child: DecoratedBox(
                            key: CapsuleTabStrip.pillKey,
                            decoration: ShapeDecoration(
                              color: colorScheme.primary,
                              shape: AppShape.full,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          for (var i = 0; i < widget.tabs.length; i++)
                            _buildItem(
                              i,
                              index: index,
                              baseStyle: baseStyle,
                              colorScheme: colorScheme,
                              focus: hasPill
                                  ? _overlapFocus(
                                      i,
                                      pillLeft: pillLeft,
                                      pillRight: pillLeft + pillWidth,
                                    )
                                  : (i == index ? 1.0 : 0.0),
                              trackHeight: trackHeight,
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    if (_fits) {
      strip = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: _onDragCancel,
        child: strip,
      );
    }
    return strip;
  }

  /// 滑块与该项的重叠比例：滑块划过时文字由灰转亮。
  double _overlapFocus(
    int i, {
    required double pillLeft,
    required double pillRight,
  }) {
    final rect = _rectOf(i);
    if (rect == null || rect.width <= 0) return 0;
    final overlap =
        math.min(pillRight, rect.right) - math.max(pillLeft, rect.left);
    return (overlap / rect.width).clamp(0.0, 1.0);
  }

  Widget _buildItem(
    int i, {
    required int index,
    required TextStyle baseStyle,
    required ColorScheme colorScheme,
    required double focus,
    required double trackHeight,
  }) {
    final tab = widget.tabs[i];
    final selected = i == index;
    final color = Color.lerp(
      colorScheme.onSurfaceVariant,
      colorScheme.onPrimary,
      focus,
    )!;
    final weight = FontWeight.lerp(FontWeight.w400, FontWeight.w600, focus);

    return KeyedSubtree(
      key: _keys[i],
      child: PressSurface(
        fill: const Color(0x00000000),
        shape: AppShape.full,
        look: selected ? PressLook.none : PressLook.ink,
        ringStandsOff: selected,
        selected: selected,
        childFills: true,
        onPressed: () => _onSelect(i),
        child: SizedBox(
          height: trackHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CapsuleTabStrip._lead,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tab.label,
                  maxLines: 1,
                  style: baseStyle.copyWith(color: color, fontWeight: weight),
                ),
                if (tab.onMenuTap != null) ...[
                  const SizedBox(width: 2),
                  _TabChevron(color: color, subtle: !selected),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 排序菜单的小 ▾：未选中时只留一点轮廓，选中后发亮。
class _TabChevron extends StatelessWidget {
  const _TabChevron({required this.color, required this.subtle});

  final Color color;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: subtle ? 0 : 1,
      duration: context.motionDuration(const Duration(milliseconds: 160)),
      child: CustomPaint(
        size: const Size(14, 14),
        painter: _ChevronPainter(color: color),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.2, h * 0.38)
      ..lineTo(w * 0.5, h * 0.66)
      ..lineTo(w * 0.8, h * 0.38);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.color != color;
}
