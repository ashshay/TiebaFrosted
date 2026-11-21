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

/// 贴吧帖子卡片（支持按压缩放 L1、点赞动效 L2、计数滚动 L3、长按菜单与无障碍语义）。
class ThreadCard extends StatelessWidget {
  const ThreadCard({
    super.key,
    required this.thread,
    this.showForumBadge = true,
    this.compact = false,
    this.onTap,
    this.onLongPress,
    this.onForumTap,
    this.onAuthorTap,
    this.onAgreeTap,
    this.onImageTap,
  });

  final TiebaThread thread;
  final bool showForumBadge;

  /// 单行精简：只留角标与标题，不画作者、摘要、图片和操作栏。
  /// 吧页的置顶帖（公告、吧规一类）用它，避免置顶内容占掉半屏。
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onForumTap;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onAgreeTap;
  final void Function(List<RichImageNode> images, int index)? onImageTap;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FrostedSettings>();
    final scheme = context.colorScheme;
    final title = thread.displayTitle;
    final abstractText = thread.abstractText.trim();
    final showAbs = settings.showThreadAbstract &&
        abstractText.isNotEmpty &&
        abstractText != title;
    final metaParts = <String>[
      if (thread.createTime > 0)
        formatTiebaTime(thread.createTime)
      else if (thread.lastTimeInt > 0)
        formatTiebaTime(thread.lastTimeInt)
      else if (thread.lastTimeStr.isNotEmpty)
        thread.lastTimeStr,
      if (thread.author.ipAddress.isNotEmpty) thread.author.ipAddress,
    ];

    if (compact) {
      return Semantics(
        button: true,
        label: '${thread.isTop ? "置顶 " : ""}$title',
        child: FrostedCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onPressed: onTap,
          onLongPress: onLongPress == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onLongPress!();
                },
          child: Row(
            children: [
              if (thread.isTop) ...[
                FrostedTag(label: '置顶', color: scheme.error),
                const SizedBox(width: 8),
              ],
              if (thread.isGood) ...[
                FrostedTag(label: '精', color: context.warning),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title.isNotEmpty ? title : '（无标题）',
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
            ],
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: '${thread.forumName.isNotEmpty ? "${thread.forumName}吧 " : ""}$title',
      child: FrostedCard(
        onPressed: onTap,
        onLongPress: onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onLongPress!();
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onAuthorTap,
                  child: Avatar(url: thread.author.portrait, size: 32),
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
                                thread.author.displayName,
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
                            if (thread.author.levelId > 0) ...[
                              const SizedBox(width: 6),
                              FrostedTag(label: 'Lv.${thread.author.levelId}'),
                            ],
                          ],
                        ),
                        if (metaParts.isNotEmpty)
                          Text(
                            joinMeta(metaParts),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.caption1
                                .of(context)
                                .copyWith(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ),
                if (showForumBadge && thread.forumName.isNotEmpty)
                  FrostedTapSurface(
                    onPressed: onForumTap,
                    pill: true,
                    fill: context.surfaceLevel.next.colorOf(scheme),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        '${thread.forumName}吧',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.caption1
                            .of(context)
                            .copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (thread.isTop) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 3, right: 6),
                    child: FrostedTag(
                      label: '置顶',
                      color: scheme.error,
                    ),
                  ),
                ],
                if (thread.isGood) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 3, right: 6),
                    child: FrostedTag(
                      label: '精',
                      color: context.warning,
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    title.isNotEmpty ? title : '（无标题）',
                    maxLines: settings.showSingleLineTitle ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.headline
                        .of(context)
                        .copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            if (showAbs) ...[
              const SizedBox(height: 6),
              Text(
                abstractText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (!settings.hideMedia && thread.video != null) ...[
              const SizedBox(height: 10),
              ClipRSuperellipse(
                borderRadius: BorderRadius.circular(AppCorner.md),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RemoteImage(
                        url: thread.video!.thumbnailUrl,
                        fit: BoxFit.cover,
                      ),
                      const ColoredBox(color: Color(0x3D000000)),
                      Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: const ShapeDecoration(
                            color: Color(0x99000000),
                            shape: AppShape.full,
                          ),
                          child: const GlyphIcon(
                            FrostedGlyphs.play,
                            size: 22,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (!settings.hideMedia && thread.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              TiebaImageGrid(
                images: thread.images,
                maxDisplay: 3,
                onTap: onImageTap == null
                    ? null
                    : (idx) => onImageTap!(thread.images, idx),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _ActionPill(
                  tooltip: thread.agree.isAgreed ? '取消点赞' : '点赞',
                  active: thread.agree.isAgreed,
                  activeColor: scheme.error,
                  glyph: FrostedGlyphs.thumbUp,
                  animated: true,
                  label: thread.agree.displayCount > 0
                      ? formatCount(thread.agree.displayCount)
                      : '赞',
                  onTap: onAgreeTap,
                ),
                const SizedBox(width: 14),
                _ActionPill(
                  tooltip: '回复数',
                  glyph: FrostedGlyphs.comment,
                  label: thread.replyNum > 0
                      ? formatCount(thread.replyNum)
                      : '回复',
                  onTap: onTap,
                ),
                if (thread.viewNum > 0) ...[
                  const Spacer(),
                  Text(
                    '${formatCount(thread.viewNum)} 浏览',
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.tooltip,
    required this.glyph,
    required this.label,
    this.active = false,
    this.activeColor,
    this.animated = false,
    this.onTap,
  });

  final String tooltip;
  final Glyph glyph;
  final String label;
  final bool active;
  final Color? activeColor;
  final bool animated;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final color = active
        ? (activeColor ?? scheme.primary)
        : scheme.onSurfaceVariant;
    final iconWidget = animated && !context.disableAnimations
        ? IconTheme(
            data: IconThemeData(size: 16, color: color),
            child: AnimatedGlyph(glyph: glyph, filled: active),
          )
        : GlyphIcon(glyph, size: 16, color: color, fill: active ? 1 : 0);

    return Semantics(
      button: onTap != null,
      label: '$tooltip $label',
      child: PressScale(
        scale: 0.94,
        enabled: onTap != null,
        child: FrostedTapSurface(
          onPressed: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          pill: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 34, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  const SizedBox(width: 5),
                  CountRoll(
                    text: label,
                    style: AppTextStyle.footnote.of(context).copyWith(
                      color: color,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
