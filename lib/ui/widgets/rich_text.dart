import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../core/emoticons.dart';
import '../../core/html_text.dart';
import 'glyphs.dart';
import 'press_scale.dart';
import 'remote_image.dart';

/// 贴吧富文本渲染器：支持纯文本、表情、@提及、超链接、图片网格与视频卡片。
class TiebaRichContent extends StatelessWidget {
  const TiebaRichContent({
    super.key,
    required this.nodes,
    this.style,
    this.maxLines,
    this.hideMedia = false,
    this.onLinkTap,
    this.onAtTap,
    this.onImageTap,
    this.onVideoTap,
  });

  final List<TiebaRichNode> nodes;
  final TextStyle? style;
  final int? maxLines;
  final bool hideMedia;
  final void Function(String url)? onLinkTap;
  final void Function(int uid, String name)? onAtTap;
  final void Function(List<RichImageNode> images, int index)? onImageTap;
  final void Function(RichVideoNode video)? onVideoTap;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) return const SizedBox.shrink();
    final baseStyle = style ??
        AppTextStyle.body
            .of(context)
            .copyWith(color: context.colorScheme.onSurface);

    // 将行内节点与块级媒体按顺序分段渲染
    final blocks = <Widget>[];
    final inlineBuf = <TiebaRichNode>[];
    final allImages = nodes.whereType<RichImageNode>().toList();

    void flushInline() {
      if (inlineBuf.isEmpty) return;
      final copy = List<TiebaRichNode>.of(inlineBuf);
      inlineBuf.clear();
      final trimmed = _trimInlineNodes(copy);
      if (trimmed.isEmpty) return;
      blocks.add(
        _InlineRichText(
          nodes: trimmed,
          style: baseStyle,
          maxLines: maxLines,
          onLinkTap: onLinkTap,
          onAtTap: onAtTap,
        ),
      );
    }

    for (final node in nodes) {
      if (node is RichImageNode) {
        if (hideMedia) continue;
        flushInline();
        final idx = allImages.indexOf(node);
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _SingleRichImage(
              image: node,
              onTap: onImageTap == null
                  ? null
                  : () => onImageTap!(allImages, idx < 0 ? 0 : idx),
            ),
          ),
        );
      } else if (node is RichVideoNode) {
        if (hideMedia) continue;
        flushInline();
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _RichVideoBox(
              video: node,
              onTap: onVideoTap == null ? null : () => onVideoTap!(node),
            ),
          ),
        );
      } else if (node is RichVoiceNode) {
        flushInline();
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: ShapeDecoration(
                color: context.surfaceLevel.next.colorOf(context.colorScheme),
                shape: AppShape.md,
              ),
              child: Text(
                '语音消息 ${(node.durationMs / 1000).ceil()}″',
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: context.colorScheme.primary),
              ),
            ),
          ),
        );
      } else {
        inlineBuf.add(node);
      }
    }
    flushInline();

    if (blocks.isEmpty) return const SizedBox.shrink();
    if (blocks.length == 1) return blocks.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          blocks[i],
        ],
      ],
    );
  }

  List<TiebaRichNode> _trimInlineNodes(List<TiebaRichNode> input) {
    final result = List<TiebaRichNode>.of(input);
    while (result.isNotEmpty &&
        result.first is RichTextNode &&
        (result.first as RichTextNode).text.trim().isEmpty) {
      result.removeAt(0);
    }
    while (result.isNotEmpty &&
        result.last is RichTextNode &&
        (result.last as RichTextNode).text.trim().isEmpty) {
      result.removeLast();
    }
    return result;
  }
}

class _InlineRichText extends StatefulWidget {
  const _InlineRichText({
    required this.nodes,
    required this.style,
    this.maxLines,
    this.onLinkTap,
    this.onAtTap,
  });

  final List<TiebaRichNode> nodes;
  final TextStyle style;
  final int? maxLines;
  final void Function(String url)? onLinkTap;
  final void Function(int uid, String name)? onAtTap;

  @override
  State<_InlineRichText> createState() => _InlineRichTextState();
}

class _InlineRichTextState extends State<_InlineRichText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _makeTap(VoidCallback onTap) {
    final r = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(r);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final accent = context.colorScheme.primary;
    final emoSize = (widget.style.fontSize ?? 16.0) * 1.25;
    final spans = <InlineSpan>[];

    for (final node in widget.nodes) {
      switch (node) {
        case RichTextNode(:final text):
          spans.add(TextSpan(text: text));
        case RichLinkNode(:final label, :final url):
          spans.add(
            TextSpan(
              text: label.isNotEmpty ? label : url,
              style: widget.style.copyWith(color: accent),
              recognizer: widget.onLinkTap == null
                  ? null
                  : _makeTap(() => widget.onLinkTap!(url)),
            ),
          );
        case RichAtNode(:final text, :final uid):
          spans.add(
            TextSpan(
              text: text,
              style: widget.style.copyWith(
                color: accent,
                fontWeight: FontWeight.w500,
              ),
              recognizer: widget.onAtTap == null
                  ? null
                  : _makeTap(() => widget.onAtTap!(uid, text)),
            ),
          );
        case RichEmoticonNode(:final id, :final name):
          final url = TiebaEmoticons.urlForId(id);
          if (url.isEmpty) {
            spans.add(TextSpan(text: '#($name)'));
          } else {
            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: TiebaEmoticonImage(
                    url: url,
                    size: emoSize,
                    fallbackName: name,
                    fallbackStyle: widget.style,
                  ),
                ),
              ),
            );
          }
        case RichImageNode():
        case RichVideoNode():
        case RichVoiceNode():
          break;
      }
    }

    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null
          ? TextOverflow.clip
          : TextOverflow.ellipsis,
    );
  }
}

class _SingleRichImage extends StatelessWidget {
  const _SingleRichImage({required this.image, this.onTap});

  final RichImageNode image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final aspect = (image.width > 0 && image.height > 0)
        ? (image.width / image.height).clamp(0.45, 2.2)
        : 1.5;
    final box = LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        final w = maxW;
        final h = (w / aspect).clamp(120.0, 420.0);
        return RemoteImage(
          url: image.url,
          width: w,
          height: h,
          fit: BoxFit.cover,
          radius: AppCorner.md,
        );
      },
    );
    if (onTap == null) return box;
    return PressScale(
      scale: 0.97,
      child: GestureDetector(onTap: onTap, child: box),
    );
  }
}

class _RichVideoBox extends StatelessWidget {
  const _RichVideoBox({required this.video, this.onTap});

  final RichVideoNode video;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final aspect = (video.width > 0 && video.height > 0)
        ? (video.width / video.height).clamp(0.6, 2.0)
        : 16 / 9;
    final child = ClipRSuperellipse(
      borderRadius: BorderRadius.circular(AppCorner.md),
      child: AspectRatio(
        aspectRatio: aspect,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RemoteImage(url: video.coverUrl, fit: BoxFit.cover),
            const ColoredBox(color: Color(0x3D000000)),
            Center(
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const ShapeDecoration(
                  color: Color(0x99000000),
                  shape: AppShape.full,
                ),
                child: const GlyphIcon(
                  FrostedGlyphs.play,
                  size: 24,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
            if (video.duration > 0)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: const ShapeDecoration(
                    color: Color(0x99000000),
                    shape: AppShape.xs,
                  ),
                  child: Text(
                    _formatDuration(video.duration),
                    style: AppTextStyle.caption2
                        .of(context)
                        .copyWith(color: const Color(0xFFFFFFFF)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return child;
    return PressScale(
      scale: 0.97,
      child: GestureDetector(onTap: onTap, child: child),
    );
  }

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s < 10 ? '0$s' : '$s'}';
  }
}

/// 帖子卡片九宫格/多图展示（最多显示 3/6/9 张，单图按比例，多图网格）。
class TiebaImageGrid extends StatelessWidget {
  const TiebaImageGrid({
    super.key,
    required this.images,
    this.maxDisplay = 3,
    this.onTap,
  });

  final List<RichImageNode> images;
  final int maxDisplay;
  final void Function(int index)? onTap;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    final shown = images.take(maxDisplay).toList();
    if (shown.length == 1) {
      final img = shown.first;
      final aspect = (img.width > 0 && img.height > 0)
          ? (img.width / img.height).clamp(0.7, 2.2)
          : 16 / 10;
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = (constraints.maxWidth * 0.78).clamp(160.0, 320.0);
          final h = (w / aspect).clamp(110.0, 220.0);
          return PressScale(
            scale: 0.97,
            child: GestureDetector(
              onTap: onTap == null ? null : () => onTap!(0),
              child: RemoteImage(
                url: img.url,
                width: w,
                height: h,
                fit: BoxFit.cover,
                radius: AppCorner.md,
              ),
            ),
          );
        },
      );
    }

    final cols = shown.length == 2 ? 2 : 3;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final itemW = (constraints.maxWidth - gap * (cols - 1)) / cols;
        final itemH = cols == 2 ? itemW * 0.78 : itemW;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < shown.length; i++)
              PressScale(
                scale: 0.97,
                child: GestureDetector(
                  onTap: onTap == null ? null : () => onTap!(i),
                  child: Stack(
                    children: [
                      RemoteImage(
                        url: shown[i].url,
                        width: itemW,
                        height: itemH,
                        fit: BoxFit.cover,
                        radius: AppCorner.sm + 4,
                      ),
                      if (i == shown.length - 1 && images.length > shown.length)
                        Positioned.fill(
                          child: Container(
                            alignment: Alignment.center,
                            decoration: ShapeDecoration(
                              color: const Color(0x66000000),
                              shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(
                                  AppCorner.sm + 4,
                                ),
                              ),
                            ),
                            child: Text(
                              '+${images.length - shown.length}',
                              style: AppTextStyle.headline
                                  .of(context)
                                  .copyWith(
                                    color: const Color(0xFFFFFFFF),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
