import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/settings.dart';
import '../chrome.dart';
import 'glyphs.dart';
import 'press_scale.dart';

/// 去掉 Dart 异常的英文前缀，展示干净中文。
String cleanError(Object error) {
  var s = error.toString().trim();
  for (final prefix in const [
    'Bad state: ',
    'Invalid argument(s): ',
    'FormatException: ',
    'Exception: ',
  ]) {
    if (s.startsWith(prefix)) {
      s = s.substring(prefix.length).trim();
    }
  }
  return s;
}

void showFrostedToast(
  BuildContext context,
  String message, {
  BannerLevel level = BannerLevel.info,
}) {
  if (message.trim().isEmpty) return;
  BannerHost.maybeOf(context)?.show(message, level: level);
}

Future<bool?> showFrostedConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmText = '确定',
  String cancelText = '取消',
  bool destructive = false,
}) {
  return showFloatingDialog<bool>(
    context: context,
    child: AlertDialog(
      title: title,
      destructive: destructive,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmText),
        ),
      ],
      child: message == null
          ? null
          : Text(
              message,
              style: AppTextStyle.subheadline
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
    ),
  );
}

Future<String?> showFrostedInputDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  bool multiline = false,
  String confirmText = '确定',
}) {
  return showFloatingDialog<String>(
    context: context,
    child: _FrostedInputDialog(
      title: title,
      initial: initial,
      hint: hint,
      multiline: multiline,
      confirmText: confirmText,
    ),
  );
}

class _FrostedInputDialog extends StatefulWidget {
  const _FrostedInputDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.multiline,
    required this.confirmText,
  });

  final String title;
  final String initial;
  final String hint;
  final bool multiline;
  final String confirmText;

  @override
  State<_FrostedInputDialog> createState() => _FrostedInputDialogState();
}

class _FrostedInputDialogState extends State<_FrostedInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.title,
      hasFields: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirmText)),
      ],
      child: TextField(
        controller: _controller,
        autofocus: true,
        minLines: widget.multiline ? 3 : 1,
        maxLines: widget.multiline ? 6 : 1,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => _submit(),
      ),
    );
  }
}

class FrostedChoice<T> {
  const FrostedChoice({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.selected = false,
    this.destructive = false,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final bool destructive;
}

/// 统一超椭圆按压面：封装 prism_ui 的 PressSurface。
class FrostedTapSurface extends StatelessWidget {
  const FrostedTapSurface({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.radius = AppCorner.md,
    this.fill = const Color(0x00000000),
    this.pill = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double radius;
  final Color fill;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final shape = pill
        ? AppShape.full
        : RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(radius),
          );
    Widget inner = PressSurface(
      fill: fill,
      shape: shape,
      onPressed: onPressed,
      child: child,
    );
    if (onLongPress != null) {
      inner = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: inner,
      );
    }
    return inner;
  }
}

/// 可点击的列表行：严格使用超椭圆形状，无裸 Material Border。
class FrostedListRow extends StatelessWidget {
  const FrostedListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onPressed,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final row = ListRow(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
    if (onPressed == null) return row;
    return PressSurface(
      fill: const Color(0x00000000),
      shape: AppShape.none,
      onPressed: onPressed,
      child: row,
    );
  }
}

/// 选项列表弹窗（绕过 SnapSheet 高内容 hold 缺陷，走 showFloatingDialog）。
Future<T?> showFrostedChoices<T>(
  BuildContext context, {
  required String title,
  required List<FrostedChoice<T>> choices,
}) {
  return showFloatingDialog<T>(
    context: context,
    child: AlertDialog(
      title: title,
      showRim: false,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in choices)
            FrostedTapSurface(
              onPressed: () => Navigator.of(context).pop(c.value),
              radius: AppCorner.md,
              fill: c.selected
                  ? context.colorScheme.primary.withValues(alpha: 0.12)
                  : const Color(0x00000000),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    if (c.leading != null) ...[
                      c.leading!,
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.label,
                            style: AppTextStyle.body
                                .of(context)
                                .copyWith(
                                  color: c.destructive
                                      ? context.colorScheme.error
                                      : context.colorScheme.onSurface,
                                  fontWeight: c.selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                          ),
                          if (c.subtitle != null &&
                              c.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              c.subtitle!,
                              style: AppTextStyle.caption1
                                  .of(context)
                                  .copyWith(
                                    color: context
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (c.selected)
                      GlyphIcon(
                        Glyphs.check,
                        size: 18,
                        color: context.colorScheme.primary,
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

class FrostedBlurBar extends StatelessWidget {
  const FrostedBlurBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final tint = SurfaceLevel.page.colorOf(scheme);
    final blur = context.select<FrostedSettings, bool>((s) => s.blurEffects);
    if (!blur) return ColoredBox(color: tint, child: child);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: ColoredBox(
          color: tint.withValues(
            alpha: scheme.brightness == Brightness.dark ? 0.65 : 0.68,
          ),
          child: child,
        ),
      ),
    );
  }
}

class FrostedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FrostedAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.titleTextStyle,
    this.toolbarHeight,
    this.centerTitle = false,
    this.hidden = false,
    this.bindChrome = false,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget> actions;
  final TextStyle? titleTextStyle;
  final double? toolbarHeight;
  final bool centerTitle;
  final bool hidden;

  /// 为 true 时内部自动订阅 [ChromeController.hidden]，避免主页面滚动隐藏顶栏时重建整个列表树。
  final bool bindChrome;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight ?? pageToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final disabled = context.disableAnimations;
    final isHidden = bindChrome
        ? context.select<ChromeController, bool>((c) => c.hidden)
        : hidden;
    return IgnorePointer(
      ignoring: isHidden,
      child: AnimatedSlide(
        offset: isHidden ? const Offset(0, -1) : Offset.zero,
        duration: disabled ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: isHidden ? 0 : 1,
          duration: disabled
              ? Duration.zero
              : const Duration(milliseconds: 160),
          child: FrostedBlurBar(
            child: AppBar(
              leading: leading,
              title: title,
              actions: actions,
              centerTitle: centerTitle,
              titleTextStyle: titleTextStyle,
              toolbarHeight: toolbarHeight,
              clipBehavior: Clip.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// 上下栏滑动隐藏触发器（复刻 Hobo/Bifu 手感）。
class ChromeScrollListener extends StatefulWidget {
  const ChromeScrollListener({
    super.key,
    required this.onHiddenChanged,
    required this.child,
    this.hideAfterPixels = 240.0,
    this.enabled = true,
  });

  final ValueChanged<bool> onHiddenChanged;
  final Widget child;
  final double hideAfterPixels;

  /// 关闭后不再随滚动收起顶栏与底栏（设置里的「滚动时自动隐藏顶栏与底栏」）。
  final bool enabled;

  @override
  State<ChromeScrollListener> createState() => _ChromeScrollListenerState();
}

class _ChromeScrollListenerState extends State<ChromeScrollListener> {
  double _lastPixels = 0;

  @override
  void didUpdateWidget(ChromeScrollListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 开关一关就立刻把栏放回来，不用等下一次滚动。
    if (oldWidget.enabled && !widget.enabled) widget.onHiddenChanged(false);
  }

  bool _onNotification(ScrollNotification notification) {
    if (!widget.enabled) {
      widget.onHiddenChanged(false);
      return false;
    }
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollUpdateNotification) {
      final pixels = notification.metrics.pixels;
      final delta = pixels - _lastPixels;
      _lastPixels = pixels;
      if (pixels <= 8) {
        widget.onHiddenChanged(false);
      } else if (delta > 0.5 && pixels > widget.hideAfterPixels) {
        widget.onHiddenChanged(true);
      } else if (delta < -0.5) {
        widget.onHiddenChanged(false);
      }
    } else if (notification is ScrollEndNotification) {
      if (notification.metrics.pixels <= 8) {
        widget.onHiddenChanged(false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: widget.child,
    );
  }
}

class FrostedPage extends StatelessWidget {
  const FrostedPage({
    super.key,
    required this.title,
    required this.body,
    this.titleWidget,
    this.actions = const [],
    this.leading,
    this.foot,
    this.footActions,
    this.footHidden = false,
    this.centerTitle = false,
    this.hidden = false,
    this.resizeToAvoidBottomInset,
  });

  final String title;

  /// 顶栏标题的富版本（如帖子页可点击的吧名胶囊）；给了就不再用 [title] 起纯文本。
  final Widget? titleWidget;
  final Widget body;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? foot;
  final Widget? footActions;

  /// 把 [foot] 移出视野而不改变 body 的布局位置（滚动隐藏用）。
  final bool footHidden;
  final bool centerTitle;
  final bool hidden;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return PrismScaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      bar: FrostedAppBar(
        leading: leading ?? const FrostedBackButton(),
        title:
            titleWidget ??
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        titleTextStyle: AppTextStyle.title3
            .of(context)
            .copyWith(
              color: context.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
        actions: actions,
        centerTitle: centerTitle,
        hidden: hidden,
      ),
      body: body,
      foot: foot,
      footHidden: footHidden,
      footActions: footActions,
    );
  }
}

class FrostedBackButton extends StatelessWidget {
  const FrostedBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      tooltip: '返回',
      icon: const GlyphIcon(Glyphs.chevronBack, size: 24),
    );
  }
}

double pageTopInset(BuildContext context) => context.appBarInset + 8;

double pageBottomInset(BuildContext context) =>
    NavigationDock.insetOf(context) + 24;

/// 遵循 SurfaceLevel 递增规则的超椭圆卡片。
class FrostedCard extends StatelessWidget {
  const FrostedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onPressed,
    this.onLongPress,
    this.fill,
    this.radius = AppCorner.lg,
    this.pressScale = 0.985,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Color? fill;
  final double radius;
  final double pressScale;

  @override
  Widget build(BuildContext context) {
    final nextLevel = context.surfaceLevel.next;
    final bg = fill ?? nextLevel.colorOf(context.colorScheme);
    final padded = SurfaceScope(
      level: nextLevel,
      child: Padding(padding: padding, child: child),
    );
    final inner = RepaintBoundary(
      child: onPressed != null || onLongPress != null
          ? FrostedTapSurface(
              fill: bg,
              radius: radius,
              onPressed: onPressed,
              onLongPress: onLongPress,
              child: padded,
            )
          : Container(
              decoration: ShapeDecoration(
                color: bg,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
              child: padded,
            ),
    );
    if (onPressed == null && onLongPress == null) return inner;
    return PressScale(scale: pressScale, child: inner);
  }
}

class FrostedTag extends StatelessWidget {
  const FrostedTag({
    super.key,
    required this.label,
    this.color,
    this.backgroundColor,
  });

  final String label;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final fg = color ?? scheme.primary;
    final bg = backgroundColor ?? fg.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: ShapeDecoration(color: bg, shape: AppShape.xs),
      child: Text(
        label,
        maxLines: 1,
        style: AppTextStyle.caption2
            .of(context)
            .copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class FrostedEmpty extends StatelessWidget {
  const FrostedEmpty({
    super.key,
    required this.title,
    this.message,
    this.icon = FrostedGlyphs.home,
    this.action,
  });

  final String title;
  final String? message;
  final Glyph icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlyphIcon(
              icon,
              size: 40,
              color: context.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyle.headline
                  .of(context)
                  .copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class FrostedLoading extends StatelessWidget {
  const FrostedLoading({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ActivityIndicator(size: 24),
          if (label != null) ...[
            const SizedBox(height: 10),
            Text(
              label!,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class FrostedSectionTitle extends StatelessWidget {
  const FrostedSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Text(
        text,
        style: AppTextStyle.footnote
            .of(context)
            .copyWith(
              color: context.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class FrostedSettingsGroup extends StatelessWidget {
  const FrostedSettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: FrostedCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Container(
                    height: 0.5,
                    color: context.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
