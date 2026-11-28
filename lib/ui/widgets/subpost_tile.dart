import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../core/html_text.dart';
import '../../data/models.dart';
import '../../data/settings.dart';
import '../theme.dart';
import 'common.dart';
import 'glyphs.dart';
import 'press_scale.dart';
import 'remote_image.dart';
import 'rich_text.dart';

/// 楼中楼单条回复项。排版跟随「评论区样式」：卡片或融合。
class SubPostTile extends StatelessWidget {
  const SubPostTile({
    super.key,
    required this.subPost,
    this.lzUserId = 0,
    this.onAuthorTap,
    this.onReplyTap,
    this.onLongPress,
    this.onAgreeTap,
    this.onLinkTap,
    this.onAtTap,
    this.onImageTap,
  });

  final TiebaSubPost subPost;
  final int lzUserId;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onReplyTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAgreeTap;
  final void Function(String url)? onLinkTap;
  final void Function(int uid, String name)? onAtTap;
  final void Function(List<RichImageNode> images, int index)? onImageTap;

  bool get _isLz => lzUserId > 0 && subPost.author.id == lzUserId;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FrostedSettings>();
    if (settings.commentStyle == CommentStyle.merged) {
      return _buildMerged(context);
    }
    return _buildCard(context);
  }

  Widget _buildCard(BuildContext context) {
    final scheme = context.colorScheme;
    final showUsername = context.select<FrostedSettings, bool>(
      (s) => s.showBothUsernameAndNickname,
    );
    final meta = joinMeta([
      if (showUsername) subPost.author.atUserName,
      if (subPost.time > 0) formatTiebaTime(subPost.time),
      if (subPost.author.ipAddress.isNotEmpty) subPost.author.ipAddress,
    ]);

    return FrostedCard(
      onPressed: onReplyTap,
      onLongPress: onLongPress,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onAuthorTap,
            child: Avatar(url: subPost.author.portrait, size: 32),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: onAuthorTap,
                        child: Text(
                          subPost.author.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.subheadline
                              .of(context)
                              .copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                    if (_isLz) ...[
                      const SizedBox(width: 6),
                      const FrostedTag(label: '楼主'),
                    ],
                    if (subPost.author.levelId > 0) ...[
                      const SizedBox(width: 6),
                      FrostedTag(
                        label: 'Lv.${subPost.author.levelId}',
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                TiebaRichContent(
                  nodes: subPost.content,
                  style: AppTextStyle.subheadline
                      .of(context)
                      .copyWith(color: scheme.onSurface),
                  onLinkTap: onLinkTap,
                  onAtTap: onAtTap,
                  onImageTap: onImageTap,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      meta,
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    if (onAgreeTap != null)
                      PressScale(
                        scale: 0.94,
                        child: FrostedTapSurface(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            onAgreeTap!();
                          },
                          pill: true,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: _buildAgreeGlyph(context, scheme, size: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 融合样式：与楼层一致，去掉卡片底，时间·发帖地与点赞同排。
  Widget _buildMerged(BuildContext context) {
    final scheme = context.colorScheme;
    final showUsername = context.select<FrostedSettings, bool>(
      (s) => s.showBothUsernameAndNickname,
    );
    final meta = joinMeta([
      if (showUsername) subPost.author.atUserName,
      if (subPost.time > 0) formatTiebaDay(subPost.time),
      if (subPost.author.ipAddress.isNotEmpty) subPost.author.ipAddress,
    ]);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onReplyTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onAuthorTap,
              child: Avatar(url: subPost.author.portrait, size: 34),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: onAuthorTap,
                          child: Text(
                            subPost.author.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.subheadline
                                .of(context)
                                .copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                      if (_isLz) ...[
                        const SizedBox(width: 6),
                        const FrostedTag(label: '楼主'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  TiebaRichContent(
                    nodes: subPost.content,
                    style: AppTextStyle.body
                        .of(context)
                        .copyWith(color: scheme.onSurface),
                    onLinkTap: onLinkTap,
                    onAtTap: onAtTap,
                    onImageTap: onImageTap,
                  ),
                  if (meta.isNotEmpty || onAgreeTap != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (meta.isNotEmpty)
                          Expanded(
                            child: Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.footnote
                                  .of(context)
                                  .copyWith(color: scheme.onSurfaceVariant),
                            ),
                          )
                        else
                          const Spacer(),
                        if (onAgreeTap != null)
                          PressScale(
                            scale: 0.94,
                            child: FrostedTapSurface(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                onAgreeTap!();
                              },
                              pill: true,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '赞',
                                      style: AppTextStyle.footnote
                                          .of(context)
                                          .copyWith(
                                            color: subPost.agree.isAgreed
                                                ? scheme.error
                                                : scheme.onSurfaceVariant,
                                          ),
                                    ),
                                    if (subPost.agree.displayCount > 0) ...[
                                      const SizedBox(width: 4),
                                      CountRoll(
                                        text: formatCount(
                                          subPost.agree.displayCount,
                                        ),
                                        style: AppTextStyle.footnote
                                            .of(context)
                                            .copyWith(
                                              color: subPost.agree.isAgreed
                                                  ? scheme.error
                                                  : scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                    const SizedBox(width: 5),
                                    _buildAgreeGlyph(context, scheme, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgreeGlyph(
    BuildContext context,
    ColorScheme scheme, {
    required double size,
  }) {
    final color = subPost.agree.isAgreed
        ? scheme.error
        : scheme.onSurfaceVariant;
    if (context.disableAnimations) {
      return GlyphIcon(
        FrostedGlyphs.thumbUp,
        size: size,
        color: color,
        fill: subPost.agree.isAgreed ? 1 : 0,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTheme(
          data: IconThemeData(size: size, color: color),
          child: AnimatedGlyph(
            glyph: FrostedGlyphs.thumbUp,
            filled: subPost.agree.isAgreed,
          ),
        ),
        if (subPost.agree.displayCount > 0) ...[
          const SizedBox(width: 4),
          CountRoll(
            text: formatCount(subPost.agree.displayCount),
            style: AppTextStyle.caption1.of(context).copyWith(color: color),
          ),
        ],
      ],
    );
  }
}
