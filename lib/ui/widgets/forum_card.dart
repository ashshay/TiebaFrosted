import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../theme.dart';
import 'common.dart';
import 'glyphs.dart';
import 'remote_image.dart';

/// 贴吧卡片（关注列表、搜索吧、他人关注的吧通用）。
///
/// [compact] 供「进吧」多列网格使用：没有头像和副标题，只留吧名与等级徽章，
/// 与 TiebaLite 网格模式（`showAvatar = listSingle`）的信息密度一致。
class ForumCard extends StatelessWidget {
  const ForumCard({
    super.key,
    required this.name,
    this.avatar = '',
    this.subtitle = '',
    this.levelId = 0,
    this.isSigned = false,
    this.isPinned = false,
    this.compact = false,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  final String name;
  final String avatar;
  final String subtitle;
  final int levelId;
  final bool isSigned;
  final bool isPinned;
  final bool compact;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    if (compact) {
      return FrostedCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        onPressed: onTap,
        onLongPress: onLongPress,
        child: Row(
          children: [
            if (isPinned) ...[
              GlyphIcon(
                FrostedGlyphs.pin,
                size: 12,
                color: scheme.primary,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                '$name吧',
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
            if (levelId > 0) ...[
              const SizedBox(width: 6),
              FrostedTag(
                label: 'Lv.$levelId',
                color: isSigned ? context.success : scheme.primary,
              ),
            ],
          ],
        ),
      );
    }
    return FrostedCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onPressed: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          RemoteImage(
            url: avatar,
            width: 44,
            height: 44,
            radius: AppCorner.sm + 4,
            placeholderColor: scheme.surfaceContainerHighest,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$name吧',
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
                    if (isPinned) ...[
                      const SizedBox(width: 6),
                      const FrostedTag(label: '置顶'),
                    ],
                    if (levelId > 0) ...[
                      const SizedBox(width: 6),
                      FrostedTag(
                        label: 'Lv.$levelId',
                        color: isSigned ? context.success : scheme.primary,
                      ),
                    ],
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (isSigned) ...[
            const SizedBox(width: 8),
            FrostedTag(label: '已签', color: context.success),
          ],
        ],
      ),
    );
  }
}
