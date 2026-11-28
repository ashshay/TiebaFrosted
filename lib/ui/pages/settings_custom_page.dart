import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/settings.dart';
import '../widgets/common.dart';
import '../widgets/segmented_capsule.dart';

/// 自定义显示设置页。
class SettingsCustomPage extends StatelessWidget {
  const SettingsCustomPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FrostedSettings>();

    return FrostedPage(
      title: '自定义显示',
      body: ListView(
        padding: EdgeInsets.only(
          top: pageTopInset(context) + 4,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          const FrostedSectionTitle('内容精简'),
          FrostedSettingsGroup(
            children: [
              FrostedListRow(
                title: const Text('无图模式'),
                subtitle: const Text('列表与帖子正文不加载图片和视频'),
                trailing: Switch(
                  value: settings.hideMedia,
                  onChanged: settings.setHideMedia,
                ),
                onPressed: () => settings.setHideMedia(!settings.hideMedia),
              ),
              FrostedListRow(
                title: const Text('隐藏帖子回复区'),
                subtitle: const Text('进入帖子详情时只看主楼正文'),
                trailing: Switch(
                  value: settings.hideReply,
                  onChanged: settings.setHideReply,
                ),
                onPressed: () => settings.setHideReply(!settings.hideReply),
              ),
              FrostedListRow(
                title: const Text('同时显示用户名与昵称'),
                subtitle: const Text('昵称照常占标题行，第二行开头用 @用户名 标出贴吧 ID'),
                trailing: Switch(
                  value: settings.showBothUsernameAndNickname,
                  onChanged: settings.setShowBothUsernameAndNickname,
                ),
                onPressed: () => settings.setShowBothUsernameAndNickname(
                  !settings.showBothUsernameAndNickname,
                ),
              ),
            ],
          ),
          const FrostedSectionTitle('评论区样式'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: FrostedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FrostedSegmentedControl<CommentStyle>(
                    value: settings.commentStyle,
                    onChanged: settings.setCommentStyle,
                    segments: const [
                      (CommentStyle.card, '卡片'),
                      (CommentStyle.merged, '融合'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    settings.commentStyle == CommentStyle.merged
                        ? '主楼仍是一张卡片；回复区铺在页面底色上，头像、昵称、正文、时间与发帖所在地一眼看完，楼中楼收进底部圆角条。'
                        : '每条楼层独立成卡片，楼中楼预览、点赞与回复按钮都收在卡片里。',
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
