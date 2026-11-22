import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../data/image_cache.dart';
import 'glyphs.dart';

export '../../data/image_cache.dart'
    show normalizeTiebaImageUrl, tiebaImageHeaders;

/// 根据 portrait 拼装贴吧用户头像 URL（与 TiebaLite StringUtil.getAvatarUrl 一致）。
String tiebaAvatarUrl(String portrait) {
  final p = portrait.trim();
  if (p.isEmpty) return '';
  if (p.startsWith('http://') || p.startsWith('https://')) return p;
  if (p.startsWith('//')) return 'https:$p';
  return 'https://gss0.bdstatic.com/6LZ1dD3d1sgCo2Kml5_Y_D3/sys/portrait/item/$p';
}

class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.cacheWidth,
    this.resizeCache = true,
    this.placeholderColor,
    this.transparentPlaceholder = false,
    this.fadeIn = true,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  final int? cacheWidth;
  final bool resizeCache;
  final Color? placeholderColor;
  final bool transparentPlaceholder;
  final bool fadeIn;

  @override
  Widget build(BuildContext context) {
    final bg = transparentPlaceholder
        ? const Color(0x00000000)
        : placeholderColor ??
              context.surfaceLevel.next.colorOf(context.colorScheme);
    final normalized = normalizeTiebaImageUrl(url);

    Widget child;
    if (normalized.isEmpty) {
      child = ColoredBox(color: bg);
    } else {
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
      final allowResize = resizeCache && !looksAnimatedImageUrl(normalized);
      final rawTargetW = allowResize
          ? (cacheWidth ??
                (width != null && width!.isFinite
                    ? (width! * dpr).round()
                    : null))
          : null;
      final quantizedW = rawTargetW == null
          ? null
          : quantizeImageCacheWidth(rawTargetW);
      final provider = TiebaCachedImageProvider(
        normalized,
        cacheWidth: quantizedW,
      );
      final disableAnim =
          !fadeIn || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

      child = Image(
        image: provider,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => ColoredBox(
          color: context.colorScheme.surfaceContainerHighest,
          child: Center(
            child: GlyphIcon(
              Glyphs.eyeOff,
              size: 18,
              color: context.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.45,
              ),
            ),
          ),
        ),
        frameBuilder: (context, img, frame, wasSync) {
          if (wasSync) return img;
          if (frame == null) return ColoredBox(color: bg);
          if (disableAnim) return img;
          return _FadeInImageFrame(child: img);
        },
      );
    }
    if (radius > 0) {
      child = ClipRSuperellipse(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      );
    }
    if (width != null || height != null) {
      return SizedBox(width: width, height: height, child: child);
    }
    return child;
  }
}

class _FadeInImageFrame extends StatefulWidget {
  const _FadeInImageFrame({required this.child});

  final Widget child;

  @override
  State<_FadeInImageFrame> createState() => _FadeInImageFrameState();
}

class _FadeInImageFrameState extends State<_FadeInImageFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  )..forward();
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    (_opacity as CurvedAnimation).dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

/// 贴吧内联表情图组件：统一走二级缓存，加载失败时优雅回退为 `#(表情名)` 文本。
class TiebaEmoticonImage extends StatelessWidget {
  const TiebaEmoticonImage({
    super.key,
    required this.url,
    required this.size,
    required this.fallbackName,
    required this.fallbackStyle,
  });

  final String url;
  final double size;
  final String fallbackName;
  final TextStyle fallbackStyle;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeTiebaImageUrl(url);
    if (normalized.isEmpty) {
      return Text('#($fallbackName)', style: fallbackStyle);
    }
    return Image(
      image: TiebaCachedImageProvider(normalized, cacheWidth: 160),
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) => Text('#($fallbackName)', style: fallbackStyle),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.url,
    this.size = 36,
    this.onTap,
  });

  final String url;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = tiebaAvatarUrl(url);
    final inner = ClipOval(
      child: resolved.isEmpty
          ? Container(
              width: size,
              height: size,
              color: context.colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: GlyphIcon(
                FrostedGlyphs.person,
                size: size * 0.56,
                color: context.colorScheme.onSurfaceVariant,
              ),
            )
          : RemoteImage(
              url: resolved,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholderColor: context.colorScheme.surfaceContainerHighest,
            ),
    );
    if (onTap == null) return inner;
    return GestureDetector(onTap: onTap, child: inner);
  }
}
