import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:provider/provider.dart';

import '../../data/settings.dart';
import '../../data/store.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';

/// 设置总入口页（prism 分组列表）。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FrostedSettings>();
    final store = context.watch<FrostedStore>();

    final themeSummary = switch (settings.darkMode) {
      1 => '浅色',
      2 => '深色',
      _ => '跟随系统',
    };
    final glassSummary = switch (settings.liquidGlass) {
      LiquidGlassLevel.off => '关闭',
      LiquidGlassLevel.standard => '标准',
      LiquidGlassLevel.ultra => '超高',
    };

    return FrostedPage(
      title: '设置',
      body: ListView(
        padding: EdgeInsets.only(
          top: pageTopInset(context) + 4,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          const FrostedSectionTitle('界面与外观'),
          FrostedSettingsGroup(
            children: [
              FrostedListRow(
                leading: const GlyphIcon(FrostedGlyphs.palette, size: 19),
                title: const Text('外观与液态玻璃'),
                subtitle: Text('$themeSummary · 玻璃$glassSummary'),
                trailing: const GlyphIcon(Glyphs.chevronForward, size: 16),
                onPressed: () => openSettingsTheme(context),
              ),
              FrostedListRow(
                leading: const GlyphIcon(FrostedGlyphs.edit, size: 19),
                title: const Text('自定义显示'),
                subtitle: const Text('无图模式、隐藏回复、双昵称显示'),
                trailing: const GlyphIcon(Glyphs.chevronForward, size: 16),
                onPressed: () => openSettingsCustom(context),
              ),
            ],
          ),
          const FrostedSectionTitle('账号与内容'),
          FrostedSettingsGroup(
            children: [
              FrostedListRow(
                leading: const GlyphIcon(FrostedGlyphs.person, size: 19),
                title: const Text('账号管理'),
                subtitle: Text(
                  store.isLoggedIn
                      ? '当前：${store.currentAccount!.displayName}（共 ${store.accounts.length} 个）'
                      : '未登录',
                ),
                trailing: const GlyphIcon(Glyphs.chevronForward, size: 16),
                onPressed: () => openSettingsAccount(context),
              ),
              FrostedListRow(
                leading: const GlyphIcon(FrostedGlyphs.calendarCheck, size: 19),
                title: const Text('自动签到与一键全签'),
                subtitle: Text(settings.autoSign ? '已开启定时提醒' : '支持 mSign 批量全签'),
                trailing: const GlyphIcon(Glyphs.chevronForward, size: 16),
                onPressed: () => openSettingsOkSign(context),
              ),
              FrostedListRow(
                leading: const GlyphIcon(FrostedGlyphs.shield, size: 19),
                title: const Text('屏蔽设置'),
                subtitle: Text('已配置 ${store.blocks.length} 条规则'),
                trailing: const GlyphIcon(Glyphs.chevronForward, size: 16),
                onPressed: () => openSettingsBlock(context),
              ),
            ],
          ),
          const FrostedSectionTitle('偏好与系统'),
          FrostedSettingsGroup(
            children: [
              FrostedListRow(
                leading: const GlyphIcon(FrostedGlyphs.sort, size: 19),
                title: const Text('使用习惯'),
                subtitle: const Text('动态默认页、吧内排序、原图策略、交互手势'),
                trailing: const GlyphIcon(Glyphs.chevronForward, size: 16),
                onPressed: () => openSettingsHabit(context),
              ),
              FrostedListRow(
                leading: const GlyphIcon(FrostedGlyphs.wrench, size: 19),
                title: const Text('更多设置'),
                subtitle: const Text('缓存清理、历史管理、网络选项'),
                trailing: const GlyphIcon(Glyphs.chevronForward, size: 16),
                onPressed: () => openSettingsMore(context),
              ),
              FrostedListRow(
                leading: const GlyphIcon(FrostedGlyphs.info, size: 19),
                title: const Text('关于 TiebaFrosted'),
                subtitle: const Text('版本信息与 GPL-3.0 开源许可'),
                trailing: const GlyphIcon(Glyphs.chevronForward, size: 16),
                onPressed: () => openAbout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
