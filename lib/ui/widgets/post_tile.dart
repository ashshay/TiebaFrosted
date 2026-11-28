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
///
/// 评论区有「卡片」与「融合」两种排版：卡片给每层一张 FrostedCard，融合把楼层
/// 直接铺在页面上（头像 + 正文 + 时间/发帖地 + 点赞一行到底，楼中楼收进底部圆角条）。
class PostTile extends StatelessWidget {
  const PostTile({
    super.key,
    required this.post,
    this.lzUserId = 0,
    this.isFirstFloor = false,
    this.replyCount,
    this.leadingTitle = '',
    this.onAuthorTap,
    this.onAgreeTap,
    this.onReplyTap,
    this.onCopyTap,
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

  /// 覆盖回复按钮上的计数。首楼用它显示整贴回复数（主楼本身没有楼中楼）。
  final int? replyCount;

  /// 正文首行的加粗标题；主楼用它承载帖子标题，不再单独占一块。
  final String leadingTitle;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onAgreeTap;
  final VoidCallback? onReplyTap;

  /// 长按正文：直接打开「复制」面板（可长按框选），不用先进菜单。
  final VoidCallback? onCopyTap;
  final VoidCallback? onSubPostsTap;
  final VoidCallback? onMoreTap;
  final void Function(String url)? onLinkTap;
  final void Function(int uid, String name)? onAtTap;
  final void Function(List<RichImageNode> images, int index)? onImageTap;
  final void Function(RichVideoNode video)? onVideoTap;

  bool get _isLz => lzUserId > 0 && post.author.id == lzUserId;

  /// 楼中楼总数：接口给的计数优先，缺失时退回已带下来的预览条数。
  int get _subPostTotal =>
      post.subPostNumber > 0 ? post.subPostNumber : post.subPosts.length;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FrostedSettings>();
    // 首楼（主楼）始终是一张卡片：融合样式只改回复区。楼中楼页顶部那块
    // 虽然也带 isFirstFloor，但它是被点开的普通楼层，仍跟随融合排版。
    final keepCard = isFirstFloor && post.floor <= 1;
    if (settings.commentStyle == CommentStyle.merged && !keepCard) {
      return _buildMerged(context, settings);
    }
    return _buildCard(context, settings);
  }

  Widget _buildCard(BuildContext context, FrostedSettings settings) {
    final scheme = context.colorScheme;
    final showUsername = context.select<FrostedSettings, bool>(
      (s) => s.showBothUsernameAndNickname,
    );
    final meta = joinMeta([
      // 昵称占标题行，用户名以 @ 形式排在第二行最前。
      if (showUsername) post.author.atUserName,
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
                          if (_isLz) ...[
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
          if (leadingTitle.isNotEmpty) ...[
            Text(
              leadingTitle,
              style: AppTextStyle.body
                  .of(context)
                  .copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
          ],
          _buildContent(context, settings, scheme, merged: false),
          if (!isFirstFloor &&
              (post.subPosts.isNotEmpty || post.subPostNumber > 0)) ...[
            const SizedBox(height: 10),
            // 卡片内层的底色要取卡片这一层的下一级，所以取内层 context。
            Builder(
              builder: (innerContext) =>
                  _buildCardSubPosts(innerContext, scheme),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _buildCardAgree(context, scheme),
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
                            (replyCount ?? post.subPostNumber) > 0
                                ? formatCount(replyCount ?? post.subPostNumber)
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

  /// 融合样式：没有卡片底、没有独立操作栏，楼层像官方客户端一样贴在页面底色上。
  Widget _buildMerged(BuildContext context, FrostedSettings settings) {
    final scheme = context.colorScheme;
    final showUsername = context.select<FrostedSettings, bool>(
      (s) => s.showBothUsernameAndNickname,
    );
    final meta = joinMeta([
      if (showUsername) post.author.atUserName,
      if (post.time > 0) formatTiebaDay(post.time),
      if (post.author.ipAddress.isNotEmpty) post.author.ipAddress,
    ]);
    final showSubPosts =
        !isFirstFloor && _subPostTotal > 0 && onSubPostsTap != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onMoreTap == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onMoreTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onAuthorTap,
              child: Avatar(url: post.author.portrait, size: 40),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: onAuthorTap,
                                child: Text(
                                  post.author.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyle.body
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
                            if (post.author.isBawu) ...[
                              const SizedBox(width: 6),
                              FrostedTag(label: '吧务', color: context.warning),
                            ],
                          ],
                        ),
                      ),
                      if (onMoreTap != null) ...[
                        const SizedBox(width: 4),
                        _MergedMoreButton(onPressed: onMoreTap!),
                      ],
                    ],
                  ),
                  if (leadingTitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      leadingTitle,
                      style: AppTextStyle.body
                          .of(context)
                          .copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _buildContent(context, settings, scheme, merged: true),
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
                      const SizedBox(width: 8),
                      _buildMergedAgree(context, scheme),
                    ],
                  ),
                  if (showSubPosts) ...[
                    const SizedBox(height: 10),
                    _buildMergedSubPosts(context, scheme),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    FrostedSettings settings,
    ColorScheme scheme, {
    required bool merged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: onCopyTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onCopyTap!();
            },
      child: TiebaRichContent(
        nodes: post.content,
        hideMedia: settings.hideMedia,
        style: (merged ? AppTextStyle.body : AppTextStyle.subheadline)
            .of(context)
            .copyWith(color: scheme.onSurface),
        onLinkTap: onLinkTap,
        onAtTap: onAtTap,
        onImageTap: onImageTap,
        onVideoTap: onVideoTap,
      ),
    );
  }

  Widget _buildCardSubPosts(BuildContext context, ColorScheme scheme) {
    final blockLevel = context.surfaceLevel.next;
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
                  if (post.subPosts.isNotEmpty) const SizedBox(height: 6),
                  Text(
                    '查看全部 ${post.subPostNumber} 条回复',
                    style: AppTextStyle.footnote
                        .of(context)
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
  }

  Widget _buildCardAgree(BuildContext context, ColorScheme scheme) {
    return PressScale(
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(
                      color: post.agree.isAgreed
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 融合样式的点赞：文字在前、拇指在后，贴在同一行的右端。
  Widget _buildMergedAgree(BuildContext context, ColorScheme scheme) {
    final color = post.agree.isAgreed ? scheme.error : scheme.onSurfaceVariant;
    return PressScale(
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '赞',
                style: AppTextStyle.footnote.of(context).copyWith(color: color),
              ),
              if (post.agree.displayCount > 0) ...[
                const SizedBox(width: 4),
                CountRoll(
                  text: formatCount(post.agree.displayCount),
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: color),
                ),
              ],
              const SizedBox(width: 5),
              if (context.disableAnimations)
                GlyphIcon(
                  FrostedGlyphs.thumbUp,
                  size: 17,
                  color: color,
                  fill: post.agree.isAgreed ? 1 : 0,
                )
              else
                IconTheme(
                  data: IconThemeData(size: 17, color: color),
                  child: AnimatedGlyph(
                    glyph: FrostedGlyphs.thumbUp,
                    filled: post.agree.isAgreed,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMergedSubPosts(BuildContext context, ColorScheme scheme) {
    return FrostedTapSurface(
      onPressed: onSubPostsTap,
      radius: AppCorner.md,
      fill: context.surfaceLevel.next.colorOf(scheme),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Text(
            '查看全部 $_subPostTotal 条回复',
            style: AppTextStyle.subheadline
                .of(context)
                .copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// 融合样式里紧凑的「…」按钮：图标外框只占 28dp，不把昵称行撑高。
class _MergedMoreButton extends StatelessWidget {
  const _MergedMoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: '更多操作',
      iconSize: 16,
      padding: EdgeInsets.zero,
      icon: GlyphIcon(
        FrostedGlyphs.more,
        size: 16,
        color: context.colorScheme.onSurfaceVariant,
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
    final showUsername = context.select<FrostedSettings, bool>(
      (s) => s.showBothUsernameAndNickname,
    );
    final style = AppTextStyle.subheadline
        .of(context)
        .copyWith(color: scheme.onSurface);
    final emoSize = (style.fontSize ?? 15.0) * 1.25;

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
                  child: TiebaEmoticonImage(
                    url: url,
                    size: emoSize,
                    fallbackName: name,
                    fallbackStyle: style,
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
            style: AppTextStyle.subheadline
                .of(context)
                .copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
          ),
          if (showUsername && sub.author.atUserName.isNotEmpty)
            TextSpan(
              text: ' ${sub.author.atUserName}',
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: scheme.onSurfaceVariant),
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
