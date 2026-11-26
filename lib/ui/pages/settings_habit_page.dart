import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/settings.dart';
import '../widgets/common.dart';
import '../widgets/segmented_capsule.dart';

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
          const FrostedSectionTitle('动态默认页'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: FrostedCard(
              child: FrostedSegmentedControl<int>(
                value: settings.defaultFeedTab,
                onChanged: settings.setDefaultFeedTab,
                segments: const [
                  (0, '推荐'),
                  (1, '关注'),
                  (2, '热榜'),
                ],
              ),
            ),
          ),
          const FrostedSectionTitle('吧内默认排序'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: FrostedCard(
              child: FrostedSegmentedControl<int>(
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
                onPressed: () =>
                    settings.setLoadOriginImage(!settings.loadOriginImage),
              ),
              FrostedListRow(
                title: const Text('卡片显示正文摘要'),
                trailing: Switch(
                  value: settings.showThreadAbstract,
                  onChanged: settings.setShowThreadAbstract,
                ),
                onPressed: () => settings.setShowThreadAbstract(
                  !settings.showThreadAbstract,
                ),
              ),
              FrostedListRow(
                title: const Text('单行显示帖子标题'),
                trailing: Switch(
                  value: settings.showSingleLineTitle,
                  onChanged: settings.setShowSingleLineTitle,
                ),
                onPressed: () => settings.setShowSingleLineTitle(
                  !settings.showSingleLineTitle,
                ),
              ),
              FrostedListRow(
                title: const Text('点赞前二次确认'),
                subtitle: const Text('防止滑动信息流误触点赞'),
                trailing: Switch(
                  value: settings.confirmBeforeLike,
                  onChanged: settings.setConfirmBeforeLike,
                ),
                onPressed: () =>
                    settings.setConfirmBeforeLike(!settings.confirmBeforeLike),
              ),
              FrostedListRow(
                title: const Text('首页显示「经过贴吧」'),
                subtitle: const Text('顶部横滑展示最近进过的吧'),
                trailing: Switch(
                  value: settings.homeShowHistoryForum,
                  onChanged: settings.setHomeShowHistoryForum,
                ),
                onPressed: () => settings.setHomeShowHistoryForum(
                  !settings.homeShowHistoryForum,
                ),
              ),
              FrostedListRow(
                title: const Text('左右滑动切换动态页'),
                subtitle: const Text('在推荐、关注、热榜之间横滑切换'),
                trailing: Switch(
                  value: settings.swipeSwitchFeed,
                  onChanged: settings.setSwipeSwitchFeed,
                ),
                onPressed: () =>
                    settings.setSwipeSwitchFeed(!settings.swipeSwitchFeed),
              ),
              FrostedListRow(
                title: const Text('长按底栏「我的」快速切号'),
                trailing: Switch(
                  value: settings.quickSwitchAccount,
                  onChanged: settings.setQuickSwitchAccount,
                ),
                onPressed: () => settings.setQuickSwitchAccount(
                  !settings.quickSwitchAccount,
                ),
              ),
              FrostedListRow(
                title: const Text('预测性返回手势'),
                subtitle: const Text('从左边缘滑动时先预览上一页，松手才返回（Android 13+）'),
                trailing: Switch(
                  value: settings.predictiveBack,
                  onChanged: settings.setPredictiveBack,
                ),
                onPressed: () =>
                    settings.setPredictiveBack(!settings.predictiveBack),
              ),
              FrostedListRow(
                title: const Text('底栏「我的」显示头像'),
                trailing: Switch(
                  value: settings.profileTabAvatar,
                  onChanged: settings.setProfileTabAvatar,
                ),
                onPressed: () =>
                    settings.setProfileTabAvatar(!settings.profileTabAvatar),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
