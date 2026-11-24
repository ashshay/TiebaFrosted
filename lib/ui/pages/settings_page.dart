import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/settings.dart';
import '../../data/store.dart';
import '../../data/updater.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/update_dialog.dart';

/// 设置总入口页（prism 分组列表）。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FrostedSettings>();
    final store = context.watch<FrostedStore>();
    final updater = context.watch<FrostedUpdater>();
    final scheme = Theme.of(context).colorScheme;

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
              FrostedListRow(
                leading: const GlyphIcon(FrostedGlyphs.person, size: 19),
                title: const Text('同时显示用户名与昵称'),
                subtitle: const Text('第二行开头显示 @用户名，昵称仍占标题行'),
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
                leading: const GlyphIcon(FrostedGlyphs.download, size: 19),
                title: const Text('检查更新'),
                subtitle: Text(
                  updater.checking
                      ? '正在检查…'
                      : updater.hasUpdate
                      ? '发现新版本 v${updater.latest!.version}'
                      : updater.currentVersion.isEmpty
                      ? '从 GitHub Releases 获取最新版本'
                      : '当前版本 v${updater.currentVersion}',
                ),
                trailing: updater.hasUpdate
                    ? FrostedTag(label: '新', color: scheme.error)
                    : const GlyphIcon(Glyphs.chevronForward, size: 16),
                onPressed: () => _checkForUpdate(context),
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
          const FrostedSectionTitle('支持'),
          FrostedSettingsGroup(
            children: [
              FrostedListRow(
                leading: const GlyphIcon(FrostedGlyphs.like, size: 19),
                title: const Text('捐赠'),
                subtitle: const Text('赞赏码 · 完全自愿的赠予，感谢支持'),
                trailing: const GlyphIcon(Glyphs.chevronForward, size: 16),
                onPressed: () => showFloatingDialog<void>(
                  context: context,
                  child: const _DonationDialog(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 手动检查更新：有新版就弹说明，点「去更新」打开 Release 页（或 APK 直链）。
Future<void> _checkForUpdate(BuildContext context) async {
  final updater = context.read<FrostedUpdater>();
  await updater.check(force: true);
  if (!context.mounted) return;

  final info = updater.latest;
  if (info == null) {
    if (updater.error != null) {
      showFrostedToast(context, updater.error!, level: BannerLevel.error);
    } else {
      final version = updater.currentVersion;
      showFrostedToast(
        context,
        version.isEmpty ? '已经是最新版本' : '已经是最新版本 v$version',
      );
    }
    return;
  }

  final go = await showUpdateDialog(
    context,
    info,
    currentVersion: updater.currentVersion,
  );
  if (go == true && context.mounted) {
    await openWeb(context, info.downloadUrl, title: '下载 v${info.version}');
  }
}

/// 赞赏码弹窗：微信扫一扫即可赞赏，并注明捐赠是自愿赠予。
class _DonationDialog extends StatelessWidget {
  const _DonationDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: '赞赏码',
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Semantics(
              image: true,
              label: '赞赏码',
              child: ClipRSuperellipse(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/donate/donate_qr.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '微信扫一扫，感谢支持',
            textAlign: TextAlign.center,
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            '赞赏完全出于自愿，属于对作者的无偿赠予，不换取任何服务或权益。',
            textAlign: TextAlign.center,
            style: AppTextStyle.caption2
                .of(context)
                .copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
