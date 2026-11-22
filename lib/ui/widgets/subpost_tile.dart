import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../core/html_text.dart';
import '../../data/models.dart';
import '../theme.dart';
import 'common.dart';
import 'glyphs.dart';
import 'press_scale.dart';
import 'remote_image.dart';
import 'rich_text.dart';

/// 楼中楼单条回复项。
class SubPostTile extends StatelessWidget {
  const SubPostTile({
    super.key,
    required this.subPost,
    this.lzUserId = 0,
    this.onAuthorTap,
    this.onReplyTap,
    this.onAgreeTap,
    this.onLinkTap,
    this.onAtTap,
    this.onImageTap,
  });

  final TiebaSubPost subPost;
  final int lzUserId;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onReplyTap;
  final VoidCallback? onAgreeTap;
  final void Function(String url)? onLinkTap;
  final void Function(int uid, String name)? onAtTap;
  final void Function(List<RichImageNode> images, int index)? onImageTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final isLz = lzUserId > 0 && subPost.author.id == lzUserId;

    return FrostedCard(
      onPressed: onReplyTap,
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
                    if (isLz) ...[
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
                      formatTiebaTime(subPost.time),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GlyphIcon(
                                  FrostedGlyphs.thumbUp,
                                  size: 14,
                                  color: subPost.agree.isAgreed
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                  fill: subPost.agree.isAgreed ? 1 : 0,
                                ),
                                if (subPost.agree.displayCount > 0) ...[
                                  const SizedBox(width: 4),
                                  CountRoll(
                                    text: formatCount(
                                      subPost.agree.displayCount,
                                    ),
                                    style: AppTextStyle.caption1
                                        .of(context)
                                        .copyWith(
                                          color: subPost.agree.isAgreed
                                              ? scheme.error
                                              : scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ],
                            ),
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
}
