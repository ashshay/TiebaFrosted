import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import 'remote_image.dart';

/// 折叠头顶栏按钮定义。
typedef ProfileHeaderAction = ({
  Glyph glyph,
  String tooltip,
  VoidCallback onPressed,
});

/// 折叠头在任意滚动进度 `progress ∈ [0, 1]` 下的纯函数几何布局。
///
/// 供吧主页与个人主页复用，并可通过单元测试全区间扫描验证永不越界裁切。
@immutable
class ProfileHeaderLayout {
  const ProfileHeaderLayout({
    required this.extent,
    required this.coverBottom,
    required this.avatarTop,
    required this.avatarLeft,
    required this.avatarSize,
    required this.nameTop,
    required this.nameLeft,
    required this.nameScale,
    required this.nameHeight,
    required this.barFill,
    required this.buttonTint,
  });

  final double extent;
  final double coverBottom;
  final double avatarTop;
  final double avatarLeft;
  final double avatarSize;
  final double nameTop;
  final double nameLeft;
  final double nameScale;
  final double nameHeight;
  final double barFill;
  final Color buttonTint;

  static ProfileHeaderLayout at({
    required double progress,
    required double topInset,
    required double nameLine,
    required double textScale,
    required bool showBack,
    required Color onSurface,
  }) {
    final p = progress.clamp(0.0, 1.0);
    final maxExtent = ProfileHeaderDelegate.expandedExtent(topInset, nameLine);
    final minExtent = ProfileHeaderDelegate.collapsedExtent(topInset);
    final extent = maxExtent - (maxExtent - minExtent) * p;

    const cover = ProfileHeaderDelegate.coverHeight;
    const bar = ProfileHeaderDelegate.barHeight;
    const outer = ProfileHeaderDelegate.avatarOuter;
    const small = ProfileHeaderDelegate.avatarSmall;
    const overlap = ProfileHeaderDelegate.overlap;

    final ease = Curves.easeInOutCubic.transform(p);
    final barCenter = topInset + bar / 2;

    final coverT = (p / ProfileHeaderDelegate.coverRange).clamp(0.0, 1.0);
    final coverBottom = (topInset + cover) * (1 - coverT);

    final avatarSize = lerpDouble(outer, small, ease)!;
    final avatarLeft = lerpDouble(16, showBack ? 50 : 14, ease)!;
    final avatarTop = math.max(
      coverBottom - overlap * (1 - ease),
      barCenter - avatarSize / 2,
    );

    final nameScale = lerpDouble(1.0, 17.0 / 22.0, ease)!;
    final nameHeight = textScale * 22.0 * nameScale * 1.3;
    final nameShift = Curves.easeOutCubic.transform(
      ((p - 0.40) / 0.45).clamp(0.0, 1.0),
    );
    final nameRise = Curves.easeInOutCubic.transform(
      ((p - 0.45) / 0.50).clamp(0.0, 1.0),
    );
    final nameTop = math.min(
      lerpDouble(
        avatarTop + avatarSize + 6,
        barCenter - nameHeight / 2,
        nameRise,
      )!,
      extent - nameHeight - 4,
    );
    final nameLeft = lerpDouble(16, avatarLeft + avatarSize + 8, nameShift)!;

    // 封面在 p≈0.34 就滑出栏的范围了，底色必须在那之前填满：
    // 之前要到 0.62 才不透明，中间那段窗口里栏是半透的，
    // 栏内图标和滑过的内容会糊在一起（折叠过程中「字被遮住」就是这段）。
    final barFill = ((p - 0.28) / 0.16).clamp(0.0, 1.0);

    return ProfileHeaderLayout(
      extent: extent,
      coverBottom: coverBottom,
      avatarTop: avatarTop,
      avatarLeft: avatarLeft,
      avatarSize: avatarSize,
      nameTop: nameTop,
      nameLeft: nameLeft,
      nameScale: nameScale,
      nameHeight: nameHeight,
      barFill: barFill,
      // 图标在封面之上要白，在实底栏上要深；跟着底色一起切，别留在浅灰的中间态。
      buttonTint: Color.lerp(
        const Color(0xFFFFFFFF),
        onSurface,
        math.max(ease, barFill),
      )!,
    );
  }
}

/// 吧主页 / 个人主页通用的 Sliver 折叠头（逐帧跟手计算，不挂 AnimationController）。
class ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  ProfileHeaderDelegate({
    required this.topInset,
    required this.nameLine,
    required this.title,
    required this.avatarUrl,
    this.coverUrl = '',
    this.subtitle,
    this.showBack = true,
    required this.onBack,
    this.actions = const [],
    this.avatarRoundedSquare = false,
  });

  final double topInset;
  final double nameLine;
  final String title;
  final String avatarUrl;
  final String coverUrl;
  final String? subtitle;
  final bool showBack;
  final VoidCallback onBack;
  final List<ProfileHeaderAction> actions;
  final bool avatarRoundedSquare;

  static const coverHeight = 152.0;
  static const barHeight = 56.0;
  static const avatarOuter = 68.0;
  static const avatarSmall = 32.0;
  static const overlap = 26.0;
  static const _nameGap = 6.0;
  static const coverRange = 0.62;
  static const actionWidth = 44.0;

  static double nameLineOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(22.0) * 1.3;

  static double expandedExtent(double topInset, double nameLine) =>
      topInset + coverHeight + avatarOuter - overlap + _nameGap + nameLine + 10;

  static double collapsedExtent(double topInset) => topInset + barHeight;

  @override
  double get minExtent => collapsedExtent(topInset);

  @override
  double get maxExtent => expandedExtent(topInset, nameLine);

  double get _range => maxExtent - minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = _range <= 0 ? 1.0 : (shrinkOffset / _range).clamp(0.0, 1.0);
    return _ProfileHeaderView(
      progress: t,
      topInset: topInset,
      nameLine: nameLine,
      title: title,
      avatarUrl: avatarUrl,
      coverUrl: coverUrl,
      showBack: showBack,
      onBack: onBack,
      actions: actions,
      avatarRoundedSquare: avatarRoundedSquare,
    );
  }

  @override
  bool shouldRebuild(covariant ProfileHeaderDelegate old) =>
      old.topInset != topInset ||
      old.nameLine != nameLine ||
      old.title != title ||
      old.avatarUrl != avatarUrl ||
      old.coverUrl != coverUrl ||
      old.showBack != showBack ||
      old.actions != actions ||
      old.avatarRoundedSquare != avatarRoundedSquare;
}

class _ProfileHeaderView extends StatelessWidget {
  const _ProfileHeaderView({
    required this.progress,
    required this.topInset,
    required this.nameLine,
    required this.title,
    required this.avatarUrl,
    required this.coverUrl,
    required this.showBack,
    required this.onBack,
    required this.actions,
    required this.avatarRoundedSquare,
  });

  final double progress;
  final double topInset;
  final double nameLine;
  final String title;
  final String avatarUrl;
  final String coverUrl;
  final bool showBack;
  final VoidCallback onBack;
  final List<ProfileHeaderAction> actions;
  final bool avatarRoundedSquare;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final surface = SurfaceLevel.page.colorOf(scheme);
    const bar = ProfileHeaderDelegate.barHeight;
    const cover = ProfileHeaderDelegate.coverHeight;
    const outer = ProfileHeaderDelegate.avatarOuter;
    const action = ProfileHeaderDelegate.actionWidth;

    final m = ProfileHeaderLayout.at(
      progress: progress,
      topInset: topInset,
      nameLine: nameLine,
      textScale: MediaQuery.textScalerOf(context).scale(1),
      showBack: showBack,
      onSurface: scheme.onSurface,
    );
    final coverVisible =
        m.coverBottom <= 0 ? 0.0 : (m.coverBottom / (topInset + cover));
    final buttonTop = topInset + (bar - action) / 2;
    final actionsWidth = action * actions.length + 8;
    final barBottom = topInset + bar;

    return ClipRect(
      child: Stack(
        children: [
          if (m.coverBottom > 0)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: m.coverBottom,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: topInset + cover,
                  maxHeight: topInset + cover,
                  child: coverUrl.isNotEmpty
                      ? RemoteImage(
                          url: coverUrl,
                          width: MediaQuery.sizeOf(context).width,
                          height: topInset + cover,
                          fit: BoxFit.cover,
                          placeholderColor: scheme.primaryContainer,
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                scheme.primary.withValues(alpha: 0.78),
                                scheme.primaryContainer,
                              ],
                            ),
                          ),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width,
                            height: topInset + cover,
                          ),
                        ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: barBottom,
            child: ColoredBox(
              color: surface.withValues(alpha: m.barFill),
              child: const SizedBox.expand(),
            ),
          ),
          if (m.barFill > 0)
            Positioned(
              left: 0,
              right: 0,
              top: barBottom - 0.5,
              height: 0.5,
              child: ColoredBox(
                color: scheme.outlineVariant.withValues(alpha: 0.5 * m.barFill),
              ),
            ),
          if (coverVisible > 0)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: barBottom + 16,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(0, 0, 0, 0.30 * coverVisible),
                        const Color(0x00000000),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: m.avatarLeft,
            top: m.avatarTop,
            width: m.avatarSize,
            height: m.avatarSize,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: outer,
                height: outer,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: ShapeDecoration(
                    color: surface,
                    shape: avatarRoundedSquare ? AppShape.md : AppShape.full,
                  ),
                  child: avatarRoundedSquare
                      ? RemoteImage(
                          url: avatarUrl,
                          width: outer - 6,
                          height: outer - 6,
                          radius: AppCorner.sm + 4,
                          placeholderColor: scheme.surfaceContainerHighest,
                        )
                      : Avatar(url: avatarUrl, size: outer - 6),
                ),
              ),
            ),
          ),
          Positioned(
            left: m.nameLeft,
            right: actionsWidth,
            top: m.nameTop,
            height: m.nameHeight,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Transform.scale(
                  scale: m.nameScale,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.title2.of(context).copyWith(
                      fontWeight: FontWeight.lerp(
                        FontWeight.w700,
                        FontWeight.w600,
                        Curves.easeInOutCubic.transform(progress),
                      ),
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showBack)
            Positioned(
              left: 4,
              top: buttonTop,
              width: action,
              height: action,
              child: IconButton(
                onPressed: onBack,
                tooltip: '返回',
                icon: GlyphIcon(
                  Glyphs.chevronBack,
                  size: 24,
                  color: m.buttonTint,
                ),
              ),
            ),
          for (var i = 0; i < actions.length; i++)
            Positioned(
              right: 8 + action * (actions.length - 1 - i),
              top: buttonTop,
              width: action,
              height: action,
              child: IconButton(
                onPressed: actions[i].onPressed,
                tooltip: actions[i].tooltip,
                icon: GlyphIcon(
                  actions[i].glyph,
                  size: 22,
                  color: m.buttonTint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 零高度顶栏占位（供折叠头页面挂给 PrismScaffold）。
class ZeroAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ZeroAppBar({super.key});

  @override
  Size get preferredSize => Size.zero;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
