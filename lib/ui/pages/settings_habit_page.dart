import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/settings.dart';
import '../widgets/common.dart';

/// 使用习惯设置页。
class SettingsHabitPage extends StatelessWidget {
  const SettingsHabitPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FrostedSettings>();

    return FrostedPage(
      title: '使用习惯',
      body: ListView(
        padding: EdgeInsets.only(
          top: pageTopInset(context) + 4,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          const FrostedSectionTitle('启动默认页'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: FrostedCard(
              child: SegmentedControl<int>(
                value: settings.startTab,
                onChanged: settings.setStartTab,
                segments: const [
                  (0, '首页'),
                  (1, '动态'),
                  (2, '消息'),
                  (3, '我的'),
                ],
              ),
            ),
          ),
          const FrostedSectionTitle('吧内默认排序'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: FrostedCard(
              child: SegmentedControl<int>(
                value: settings.defaultSortType,
                onChanged: settings.setDefaultSortType,
                segments: const [
                  (0, '最新回复'),
                  (1, '最新发布'),
                ],
              ),
            ),
          ),
          const FrostedSectionTitle('浏览与交互'),
          FrostedSettingsGroup(
            children: [
              FrostedListRow(
                title: const Text('默认加载原图'),
                subtitle: const Text('上传与看图时优先使用原图'),
                trailing: Switch(
                  value: settings.loadOriginImage,
                  onChanged: settings.setLoadOriginImage,
                ),
              ),
              FrostedListRow(
                title: const Text('卡片显示正文摘要'),
                trailing: Switch(
                  value: settings.showThreadAbstract,
                  onChanged: settings.setShowThreadAbstract,
                ),
              ),
              FrostedListRow(
                title: const Text('单行显示帖子标题'),
                trailing: Switch(
                  value: settings.showSingleLineTitle,
                  onChanged: settings.setShowSingleLineTitle,
                ),
              ),
              FrostedListRow(
                title: const Text('点赞前二次确认'),
                subtitle: const Text('防止滑动信息流误触点赞'),
                trailing: Switch(
                  value: settings.confirmBeforeLike,
                  onChanged: settings.setConfirmBeforeLike,
                ),
              ),
              FrostedListRow(
                title: const Text('首页显示「经过贴吧」'),
                subtitle: const Text('顶部横滑展示最近进过的吧'),
                trailing: Switch(
                  value: settings.homeShowHistoryForum,
                  onChanged: settings.setHomeShowHistoryForum,
                ),
              ),
              FrostedListRow(
                title: const Text('左右滑动切换动态页'),
                subtitle: const Text('在推荐、关注、热榜之间横滑切换'),
                trailing: Switch(
                  value: settings.swipeSwitchFeed,
                  onChanged: settings.setSwipeSwitchFeed,
                ),
              ),
              FrostedListRow(
                title: const Text('长按底栏「我的」快速切号'),
                trailing: Switch(
                  value: settings.quickSwitchAccount,
                  onChanged: settings.setQuickSwitchAccount,
                ),
              ),
              FrostedListRow(
                title: const Text('底栏「我的」显示头像'),
                trailing: Switch(
                  value: settings.profileTabAvatar,
                  onChanged: settings.setProfileTabAvatar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
