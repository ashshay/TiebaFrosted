import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/local_db.dart';
import '../../data/settings.dart';
import '../../data/store.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';

/// 屏蔽设置页：关键词 / 正则 / 用户 / 贴吧 屏蔽与白名单规则管理。
class SettingsBlockPage extends StatelessWidget {
  const SettingsBlockPage({super.key});

  Future<void> _addRule(BuildContext context) async {
    final type = await showFrostedChoices<BlockRuleType>(
      context,
      title: '选择规则类型',
      choices: const [
        FrostedChoice(value: BlockRuleType.keyword, label: '关键词 / 正则'),
        FrostedChoice(value: BlockRuleType.user, label: '用户昵称或 UID'),
        FrostedChoice(value: BlockRuleType.forum, label: '贴吧名称'),
      ],
    );
    if (type == null || !context.mounted) return;

    final value = await showFrostedInputDialog(
      context,
      title: switch (type) {
        BlockRuleType.keyword => '输入屏蔽关键词',
        BlockRuleType.user => '输入要屏蔽的用户名或 UID',
        BlockRuleType.forum => '输入要屏蔽的吧名（不含「吧」字）',
      },
      hint: type == BlockRuleType.keyword ? '支持正则（前缀 re:）' : '输入内容',
    );
    if (value == null || value.trim().isEmpty || !context.mounted) return;

    var actual = value.trim();
    var isRegex = false;
    if (type == BlockRuleType.keyword && actual.startsWith('re:')) {
      isRegex = true;
      actual = actual.substring(3).trim();
    }
    if (actual.isEmpty) return;

    await context.read<FrostedStore>().addBlockRule(
      type: type,
      value: actual,
      isRegex: isRegex,
    );
    if (context.mounted) showFrostedToast(context, '已添加屏蔽规则');
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FrostedSettings>();
    final store = context.watch<FrostedStore>();
    final scheme = context.colorScheme;

    String typeLabel(BlockRule r) => switch (r.type) {
      BlockRuleType.keyword => r.isRegex ? '正则' : '关键词',
      BlockRuleType.user => '用户',
      BlockRuleType.forum => '贴吧',
    };

    return FrostedPage(
      title: '屏蔽设置',
      actions: [
        IconButton(
          onPressed: () => _addRule(context),
          tooltip: '添加规则',
          icon: const GlyphIcon(FrostedGlyphs.add, size: 22),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.only(
          top: pageTopInset(context) + 4,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          const FrostedSectionTitle('总开关'),
          FrostedSettingsGroup(
            children: [
              FrostedListRow(
                title: const Text('启用屏蔽规则'),
                trailing: Switch(
                  value: settings.enableBlock,
                  onChanged: settings.setEnableBlock,
                ),
              ),
              FrostedListRow(
                title: const Text('屏蔽视频贴'),
                subtitle: const Text('在信息流与吧主页自动隐藏视频帖子'),
                trailing: Switch(
                  value: settings.blockVideoThread,
                  onChanged: settings.setBlockVideoThread,
                ),
              ),
            ],
          ),
          const FrostedSectionTitle('屏蔽规则列表（点击删除）'),
          if (store.blocks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: FrostedEmpty(
                title: '暂无屏蔽规则',
                message: '点击右上角「+」添加关键词、正则（re:前缀）、用户或贴吧规则',
                icon: FrostedGlyphs.shield,
              ),
            )
          else
            FrostedSettingsGroup(
              children: [
                for (final rule in store.blocks)
                  FrostedListRow(
                    leading: FrostedTag(
                      label: typeLabel(rule),
                      color: rule.isWhitelist
                          ? scheme.primary
                          : scheme.error,
                    ),
                    title: Text(rule.value),
                    trailing: GlyphIcon(
                      FrostedGlyphs.delete,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    onPressed: () async {
                      await store.removeBlockRule(rule.id);
                      if (context.mounted) showFrostedToast(context, '已删除规则');
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
