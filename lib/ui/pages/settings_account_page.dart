import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/repo.dart';
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
    final repo = context.read<TiebaRepo>();
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
                              if (!acc.canWrite)
                                FrostedChoice(
                                  value: 'relogin',
                                  label: '补全发言凭据（缺 ${acc.writeBlockReason}）',
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
                          } else if (picked == 'relogin' && context.mounted) {
                            final ok = await showFrostedConfirm(
                              context,
                              title: '补全发言凭据',
                              message:
                                  '将会清空旧 Cookie 并重新登录：旧的百度会话还在时，'
                                  'passport 会复用那份已经失效的 STOKEN。',
                              confirmText: '去登录',
                            );
                            if (ok == true && context.mounted) {
                              await openLogin(context, fresh: true);
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
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    store.canWrite
                        ? '当前账号可以正常回帖、收藏。'
                        : '当前账号只能浏览：缺少 ${store.writeBlockReason}，'
                              '回帖 / 收藏会被服务端判成未登录。请用「网页登录」重新登录，'
                              '或粘贴含 STOKEN 的完整 Cookie。',
                    style: AppTextStyle.footnote.of(context).copyWith(
                      color: store.canWrite
                          ? scheme.onSurfaceVariant
                          : scheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => openLogin(context),
                  child: const Text('添加其他账号'),
                ),
                if (repo.lastWriteDiagnostic.isNotEmpty ||
                    repo.api.replyProbe.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  FrostedCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '最近一次发言失败（反馈时请附上）',
                          style: AppTextStyle.footnote.of(context).copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          [
                            if (repo.lastWriteDiagnostic.isNotEmpty)
                              repo.lastWriteDiagnostic,
                            if (repo.api.replyProbe.isNotEmpty)
                              '回复列表探测：${repo.api.replyProbe}',
                          ].join('\n'),
                          style: AppTextStyle.caption1.of(context).copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
