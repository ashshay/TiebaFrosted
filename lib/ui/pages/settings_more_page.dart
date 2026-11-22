import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/local_db.dart';
import '../../data/settings.dart';
import '../widgets/common.dart';

/// 更多设置页：图片缓存清理、历史清理与网络选项。
class SettingsMorePage extends StatelessWidget {
  const SettingsMorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FrostedSettings>();

    return FrostedPage(
      title: '更多设置',
      body: ListView(
        padding: EdgeInsets.only(
          top: pageTopInset(context) + 4,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          const FrostedSectionTitle('网络'),
          FrostedSettingsGroup(
            children: [
              FrostedListRow(
                title: const Text('优先使用 HTTPS'),
                subtitle: const Text('对贴吧接口和图片链接优先启用加密连接'),
                trailing: Switch(
                  value: settings.useHttps,
                  onChanged: settings.setUseHttps,
                ),
              ),
              FrostedListRow(
                title: const Text('使用内置浏览器'),
                subtitle: Text(
                  settings.useWebView
                      ? '站外链接在应用内打开，可随时切到系统浏览器'
                      : '站外链接交给系统浏览器打开',
                ),
                trailing: Switch(
                  value: settings.useWebView,
                  onChanged: settings.setUseWebView,
                ),
              ),
            ],
          ),
          const FrostedSectionTitle('缓存与数据'),
          FrostedSettingsGroup(
            children: [
              FrostedListRow(
                title: const Text('清理内存图片缓存'),
                subtitle: const Text('释放已解码的图片缓存以降低内存占用'),
                onPressed: () {
                  PaintingBinding.instance.imageCache.clear();
                  PaintingBinding.instance.imageCache.clearLiveImages();
                  showFrostedToast(context, '已清理图片缓存');
                },
              ),
              FrostedListRow(
                title: const Text('清空全部浏览历史'),
                onPressed: () async {
                  final ok = await showFrostedConfirm(
                    context,
                    title: '清空浏览历史',
                    message: '确定清空所有帖子与贴吧的本地浏览历史？',
                    destructive: true,
                  );
                  if (ok == true && context.mounted) {
                    await context.read<LocalDb>().clearHistory();
                    if (context.mounted) showFrostedToast(context, '已清空浏览历史');
                  }
                },
              ),
              FrostedListRow(
                title: const Text('清空搜索历史'),
                onPressed: () async {
                  await context.read<LocalDb>().clearSearchHistory();
                  if (context.mounted) showFrostedToast(context, '已清空搜索历史');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
