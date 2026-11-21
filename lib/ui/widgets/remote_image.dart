import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import 'glyphs.dart';

const Map<String, String> tiebaImageHeaders = {
  'User-Agent': 'bdtb for Android 12.64.1.1',
  'Referer': 'https://tieba.baidu.com/',
  'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
};

const Map<String, String> _tiebaNoRefererHeaders = {
  'User-Agent': 'bdtb for Android 12.64.1.1',
  'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
};

String normalizeTiebaImageUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('//')) return 'https:$trimmed';
  return trimmed;
}

/// 根据 portrait 拼装贴吧用户头像 URL（与 TiebaLite StringUtil.getAvatarUrl 一致）。
String tiebaAvatarUrl(String portrait) {
  final p = portrait.trim();
  if (p.isEmpty) return '';
  if (p.startsWith('http://') || p.startsWith('https://')) return p;
  if (p.startsWith('//')) return 'https:$p';
  return 'https://gss0.bdstatic.com/6LZ1dD3d1sgCo2Kml5_Y_D3/sys/portrait/item/$p';
}

bool _looksAnimated(String url) {
  final lower = url.toLowerCase();
  return lower.contains('.gif') || lower.contains('format=gif');
}

class RemoteImage extends StatefulWidget {
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

  @override
  State<RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<RemoteImage> {
  bool _fallbackWithoutReferer = false;

  @override
  void didUpdateWidget(covariant RemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _fallbackWithoutReferer = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.transparentPlaceholder
        ? const Color(0x00000000)
        : widget.placeholderColor ??
            context.surfaceLevel.next.colorOf(context.colorScheme);
    final normalized = normalizeTiebaImageUrl(widget.url);

    Widget child;
    if (normalized.isEmpty) {
      child = ColoredBox(color: bg);
    } else {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final allowResize = widget.resizeCache && !_looksAnimated(normalized);
      final targetCacheW = allowResize
          ? (widget.cacheWidth ??
                (widget.width != null && widget.width!.isFinite
                    ? (widget.width! * dpr).round().clamp(64, 1440)
                    : null))
          : null;
      final headers = _fallbackWithoutReferer
          ? _tiebaNoRefererHeaders
          : tiebaImageHeaders;

      child = Image.network(
        normalized,
        key: ValueKey('$normalized|${_fallbackWithoutReferer ? 1 : 0}'),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        headers: headers,
        cacheWidth: targetCacheW,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) {
          if (!_fallbackWithoutReferer) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_fallbackWithoutReferer) {
                setState(() => _fallbackWithoutReferer = true);
              }
            });
            return ColoredBox(color: bg);
          }
          return ColoredBox(
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
          );
        },
        frameBuilder: (context, img, frame, wasSync) {
          if (wasSync || frame != null) return img;
          return ColoredBox(color: bg);
        },
      );
    }
    if (widget.radius > 0) {
      child = ClipRSuperellipse(
        borderRadius: BorderRadius.circular(widget.radius),
        child: child,
      );
    }
    if (widget.width != null || widget.height != null) {
      return SizedBox(width: widget.width, height: widget.height, child: child);
    }
    return child;
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
