import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../core/emoticons.dart';
import '../../core/html_text.dart';
import '../../data/models.dart';
import '../../data/settings.dart';
import '../theme.dart';
import 'common.dart';
import 'glyphs.dart';
import 'press_scale.dart';
import 'remote_image.dart';
import 'rich_text.dart';

/// 帖子详情页单个楼层组件（支持楼主/吧务标签、富文本、楼中楼预览块、点赞 L2 动效与操作栏）。
class PostTile extends StatelessWidget {
  const PostTile({
    super.key,
    required this.post,
    this.lzUserId = 0,
    this.isFirstFloor = false,
    this.onAuthorTap,
    this.onAgreeTap,
    this.onReplyTap,
    this.onSubPostsTap,
    this.onMoreTap,
    this.onLinkTap,
    this.onAtTap,
    this.onImageTap,
    this.onVideoTap,
  });

  final TiebaPost post;
  final int lzUserId;
  final bool isFirstFloor;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onAgreeTap;
  final VoidCallback? onReplyTap;
  final VoidCallback? onSubPostsTap;
  final VoidCallback? onMoreTap;
  final void Function(String url)? onLinkTap;
  final void Function(int uid, String name)? onAtTap;
  final void Function(List<RichImageNode> images, int index)? onImageTap;
  final void Function(RichVideoNode video)? onVideoTap;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FrostedSettings>();
    final scheme = context.colorScheme;
    final isLz = lzUserId > 0 && post.author.id == lzUserId;
    final meta = joinMeta([
      if (post.floor > 0) '${post.floor}楼',
      if (post.time > 0) formatTiebaTime(post.time),
      if (post.author.ipAddress.isNotEmpty) post.author.ipAddress,
    ]);

    return FrostedCard(
      onLongPress: onMoreTap == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onMoreTap!();
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onAuthorTap,
                child: Avatar(url: post.author.portrait, size: 36),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onAuthorTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.author.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.headline
                                  .of(context)
                                  .copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (isLz) ...[
                            const SizedBox(width: 6),
                            const FrostedTag(label: '楼主'),
                          ],
                          if (post.author.isBawu) ...[
                            const SizedBox(width: 6),
                            FrostedTag(label: '吧务', color: context.warning),
                          ],
                          if (post.author.levelId > 0) ...[
                            const SizedBox(width: 6),
                            FrostedTag(
                              label: 'Lv.${post.author.levelId}',
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.footnote
                              .of(context)
                              .copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ),
              if (onMoreTap != null)
                IconButton(
                  onPressed: onMoreTap,
                  tooltip: '更多操作',
                  icon: GlyphIcon(
                    FrostedGlyphs.more,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TiebaRichContent(
            nodes: post.content,
            hideMedia: settings.hideMedia,
            style: AppTextStyle.body
                .of(context)
                .copyWith(color: scheme.onSurface),
            onLinkTap: onLinkTap,
            onAtTap: onAtTap,
            onImageTap: onImageTap,
            onVideoTap: onVideoTap,
          ),
          if (!isFirstFloor &&
              (post.subPosts.isNotEmpty || post.subPostNumber > 0)) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (innerContext) {
                final blockLevel = innerContext.surfaceLevel.next;
                final blockBg = blockLevel.colorOf(scheme);
                return FrostedTapSurface(
                  onPressed: onSubPostsTap,
                  radius: AppCorner.md,
                  fill: blockBg,
                  child: SurfaceScope(
                    level: blockLevel,
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < post.subPosts.length; i++) ...[
                              if (i > 0) const SizedBox(height: 6),
                              _SubPostPreviewLine(
                                sub: post.subPosts[i],
                                lzUserId: lzUserId,
                              ),
                            ],
                            if (post.subPostNumber > post.subPosts.length ||
                                post.subPosts.isEmpty) ...[
                              if (post.subPosts.isNotEmpty)
                                const SizedBox(height: 6),
                              Text(
                                '查看全部 ${post.subPostNumber} 条回复',
                                style: AppTextStyle.footnote
                                    .of(innerContext)
                                    .copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              PressScale(
                scale: 0.94,
                enabled: onAgreeTap != null,
                child: FrostedTapSurface(
                  onPressed: onAgreeTap == null
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          onAgreeTap!();
                        },
                  pill: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (context.disableAnimations)
                          GlyphIcon(
                            FrostedGlyphs.thumbUp,
                            size: 16,
                            color: post.agree.isAgreed
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                            fill: post.agree.isAgreed ? 1 : 0,
                          )
                        else
                          IconTheme(
                            data: IconThemeData(
                              size: 16,
                              color: post.agree.isAgreed
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                            child: AnimatedGlyph(
                              glyph: FrostedGlyphs.thumbUp,
                              filled: post.agree.isAgreed,
                            ),
                          ),
                        const SizedBox(width: 5),
                        CountRoll(
                          text: post.agree.displayCount > 0
                              ? formatCount(post.agree.displayCount)
                              : '赞',
                          style: AppTextStyle.footnote.of(context).copyWith(
                            color: post.agree.isAgreed
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (onReplyTap != null)
                PressScale(
                  scale: 0.94,
                  child: FrostedTapSurface(
                    onPressed: onReplyTap,
                    pill: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GlyphIcon(
                            FrostedGlyphs.comment,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            post.subPostNumber > 0
                                ? formatCount(post.subPostNumber)
                                : '回复',
                            style: AppTextStyle.footnote
                                .of(context)
                                .copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubPostPreviewLine extends StatelessWidget {
  const _SubPostPreviewLine({required this.sub, required this.lzUserId});

  final TiebaSubPost sub;
  final int lzUserId;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final style = AppTextStyle.callout
        .of(context)
        .copyWith(color: scheme.onSurface);
    final emoSize = (style.fontSize ?? 16.0) * 1.25;

    // 楼中楼预览曾经把富文本压成纯串，表情会露出 `#(滑稽)` 这种标记；
    // 这里按节点逐个拼，表情走内联图，拿不到图才退回标记文本。
    final preview = <InlineSpan>[];
    for (final node in sub.content) {
      switch (node) {
        case RichTextNode(:final text):
          preview.add(TextSpan(text: text));
        case RichAtNode(:final text):
          preview.add(TextSpan(text: text));
        case RichLinkNode(:final label):
          preview.add(TextSpan(text: label));
        case RichImageNode():
          preview.add(const TextSpan(text: '[图片]'));
        case RichVideoNode():
          preview.add(const TextSpan(text: '[视频]'));
        case RichVoiceNode():
          preview.add(const TextSpan(text: '[语音]'));
        case RichEmoticonNode(:final id, :final name):
          final url = TiebaEmoticons.urlForId(id);
          if (url.isEmpty) {
            preview.add(TextSpan(text: '#($name)'));
          } else {
            preview.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Image.network(
                    url,
                    width: emoSize,
                    height: emoSize,
                    fit: BoxFit.contain,
                    headers: tiebaImageHeaders,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Text('#($name)', style: style),
                  ),
                ),
              ),
            );
          }
      }
    }

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: sub.author.displayName,
            style: AppTextStyle.callout.of(context).copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (lzUserId > 0 && sub.author.id == lzUserId)
            TextSpan(
              text: ' [楼主]',
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: scheme.primary),
            ),
          const TextSpan(text: '：'),
          ...preview,
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
