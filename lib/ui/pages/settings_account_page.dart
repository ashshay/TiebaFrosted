import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/store.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/remote_image.dart';

/// 多账号管理页：查看、切换、添加与移除账号。
class SettingsAccountPage extends StatelessWidget {
  const SettingsAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FrostedStore>();
    final scheme = context.colorScheme;

    return FrostedPage(
      title: '账号管理',
      actions: [
        IconButton(
          onPressed: () => openLogin(context),
          tooltip: '添加账号',
          icon: const GlyphIcon(FrostedGlyphs.add, size: 22),
        ),
      ],
      body: store.accounts.isEmpty
          ? FrostedEmpty(
              title: '尚未登录账号',
              message: '支持多个百度贴吧账号快速切换',
              icon: FrostedGlyphs.person,
              action: FilledButton(
                onPressed: () => openLogin(context),
                child: const Text('添加账号'),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                14,
                pageTopInset(context) + 8,
                14,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                FrostedSettingsGroup(
                  children: [
                    for (final acc in store.accounts)
                      FrostedListRow(
                        leading: Avatar(url: acc.portrait, size: 36),
                        title: Text(acc.displayName),
                        subtitle: Text(
                          acc.uid == store.activeUid
                              ? '当前使用中 · UID ${acc.uid}'
                              : 'UID ${acc.uid}',
                        ),
                        trailing: acc.uid == store.activeUid
                            ? GlyphIcon(
                                Glyphs.check,
                                size: 18,
                                color: scheme.primary,
                              )
                            : const GlyphIcon(Glyphs.chevronForward, size: 16),
                        onPressed: () async {
                          final picked = await showFrostedChoices<String>(
                            context,
                            title: acc.displayName,
                            choices: [
                              if (acc.uid != store.activeUid)
                                const FrostedChoice(
                                  value: 'switch',
                                  label: '切换到此账号',
                                ),
                              const FrostedChoice(
                                value: 'delete',
                                label: '移除此账号',
                                destructive: true,
                              ),
                            ],
                          );
                          if (picked == 'switch' && context.mounted) {
                            await store.switchAccount(acc.uid);
                            if (context.mounted) {
                              showFrostedToast(
                                context,
                                '已切换到 ${acc.displayName}',
                              );
                            }
                          } else if (picked == 'delete' && context.mounted) {
                            await store.removeAccount(acc.uid);
                            if (context.mounted) {
                              showFrostedToast(
                                context,
                                '已移除 ${acc.displayName}',
                              );
                            }
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => openLogin(context),
                  child: const Text('添加其他账号'),
                ),
              ],
            ),
    );
  }
}
