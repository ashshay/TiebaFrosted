import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/settings.dart';
import '../widgets/common.dart';

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
              ),
              FrostedListRow(
                title: const Text('隐藏帖子回复区'),
                subtitle: const Text('进入帖子详情时只看主楼正文'),
                trailing: Switch(
                  value: settings.hideReply,
                  onChanged: settings.setHideReply,
                ),
              ),
              FrostedListRow(
                title: const Text('同时显示用户名与昵称'),
                trailing: Switch(
                  value: settings.showBothUsernameAndNickname,
                  onChanged: settings.setShowBothUsernameAndNickname,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
