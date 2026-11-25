import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../../data/store.dart';
import '../../data/tab_cache.dart';
import '../chrome.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/profile_header.dart';
import '../widgets/refresh.dart';
import '../widgets/remote_image.dart';

/// 「我的」主标签页：已登录使用折叠头展示个人资料与功能分组，未登录提供登录引导与本地能力入口。
class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  TiebaUser? _profile;
  bool _loading = false;

  String get _accountKey => context.read<FrostedStore>().activeUid ?? 'guest';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<FrostedStore>().isLoggedIn) {
        unawaited(_restoreOrLoadProfile());
      }
    });
  }

  Future<void> _restoreOrLoadProfile() async {
    final cached = await TabSnapshotCache.instance.readMeProfile(_accountKey);
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _profile = cached;
        _loading = false;
      });
      return;
    }
    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    final repo = context.read<TiebaRepo>();
    if (!repo.isLoggedIn) return;
    setState(() => _loading = true);
    try {
      final res = await repo.getUserProfile();
      if (!mounted) return;
      setState(() {
        _profile = res.user;
        _loading = false;
      });
      unawaited(TabSnapshotCache.instance.saveMeProfile(_accountKey, res.user));
    } on Object {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FrostedStore>();
    final chrome = context.read<ChromeController>();

    if (!store.isLoggedIn) {
      return _GuestMeView(chrome: chrome);
    }

    final acc = store.currentAccount!;
    final user = _profile;
    final displayName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : acc.displayName;
    final avatar = user?.portrait.isNotEmpty == true
        ? user!.portrait
        : acc.portrait;
    final uid = int.tryParse(acc.uid) ?? user?.id ?? 0;
    final topInset = MediaQuery.paddingOf(context).top;
    final dockInset = NavigationDock.insetOf(context);

    return PrismScaffold(
      bar: const ZeroAppBar(),
      body: ChromeScrollListener(
        onHiddenChanged: chrome.setHidden,
        child: FrostedRefresh(
          topInset: topInset + 12,
          onRefresh: _loadProfile,
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              key: const ValueKey('me-page-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    topInset + 16,
                    14,
                    dockInset + 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        key: const ValueKey('me-page-content'),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 与下面 FrostedSettingsGroup 的左右留白对齐（组内另有 14）。
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: _ProfileCard(
                              displayName: displayName,
                              atUserName: user?.atUserName ?? '',
                              tbAge: user?.tbAge ?? '',
                              avatarUrl: avatar,
                              onEdit: user == null
                                  ? null
                                  : () async {
                                      final changed = await openEditProfile(
                                        context,
                                        user: user,
                                      );
                                      if (changed == true && mounted) {
                                        unawaited(_loadProfile());
                                      }
                                    },
                              stats: [
                                _ProfileStat(
                                  label: '关注',
                                  value: formatCount(user?.concernNum ?? 0),
                                  onTap: () => openFollowList(
                                    context,
                                    uid: uid,
                                    title: '我的关注',
                                  ),
                                ),
                                _ProfileStat(
                                  label: '粉丝',
                                  value: formatCount(user?.fansNum ?? 0),
                                  onTap: () => openFollowList(
                                    context,
                                    uid: uid,
                                    isFans: true,
                                    title: '我的粉丝',
                                  ),
                                ),
                                _ProfileStat(
                                  label: '贴吧',
                                  value: formatCount(user?.myLikeNum ?? 0),
                                  onTap: () => openUserLikeForum(
                                    context,
                                    uid: uid,
                                    title: '我关注的吧',
                                  ),
                                ),
                                _ProfileStat(
                                  label: '帖子',
                                  value: formatCount(user?.postNum ?? 0),
                                  onTap: () => openUserPost(
                                    context,
                                    uid: uid,
                                    title: '我的帖子',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_loading && user == null)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: FrostedLoading(),
                            ),
                          const FrostedSectionTitle('我的内容'),
                          FrostedSettingsGroup(
                            children: [
                              FrostedListRow(
                                leading: const GlyphIcon(
                                  FrostedGlyphs.bookmark,
                                  size: 19,
                                ),
                                title: const Text('我的收藏'),
                                trailing: const GlyphIcon(
                                  Glyphs.chevronForward,
                                  size: 16,
                                ),
                                onPressed: () => openThreadStore(context),
                              ),
                              FrostedListRow(
                                leading: const GlyphIcon(
                                  FrostedGlyphs.clock,
                                  size: 19,
                                ),
                                title: const Text('浏览历史'),
                                trailing: const GlyphIcon(
                                  Glyphs.chevronForward,
                                  size: 16,
                                ),
                                onPressed: () => openHistory(context),
                              ),
                              FrostedListRow(
                                leading: const GlyphIcon(
                                  FrostedGlyphs.calendarCheck,
                                  size: 19,
                                ),
                                title: const Text('一键签到'),
                                trailing: const GlyphIcon(
                                  Glyphs.chevronForward,
                                  size: 16,
                                ),
                                onPressed: () => openSettingsOkSign(context),
                              ),
                            ],
                          ),
                          const FrostedSectionTitle('账号与设置'),
                          FrostedSettingsGroup(
                            children: [
                              FrostedListRow(
                                leading: const GlyphIcon(
                                  FrostedGlyphs.person,
                                  size: 19,
                                ),
                                title: const Text('多账号管理'),
                                subtitle: Text(
                                  '已保存 ${store.accounts.length} 个账号',
                                ),
                                trailing: const GlyphIcon(
                                  Glyphs.chevronForward,
                                  size: 16,
                                ),
                                onPressed: () => openSettingsAccount(context),
                              ),
                              FrostedListRow(
                                leading: const GlyphIcon(
                                  FrostedGlyphs.palette,
                                  size: 19,
                                ),
                                title: const Text('外观与液态玻璃'),
                                trailing: const GlyphIcon(
                                  Glyphs.chevronForward,
                                  size: 16,
                                ),
                                onPressed: () => openSettingsTheme(context),
                              ),
                              FrostedListRow(
                                leading: const GlyphIcon(
                                  FrostedGlyphs.shield,
                                  size: 19,
                                ),
                                title: const Text('屏蔽规则'),
                                trailing: const GlyphIcon(
                                  Glyphs.chevronForward,
                                  size: 16,
                                ),
                                onPressed: () => openSettingsBlock(context),
                              ),
                              FrostedListRow(
                                leading: const GlyphIcon(
                                  FrostedGlyphs.wrench,
                                  size: 19,
                                ),
                                title: const Text('全部设置'),
                                trailing: const GlyphIcon(
                                  Glyphs.chevronForward,
                                  size: 16,
                                ),
                                onPressed: () => openSettings(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 主页头部的「液态玻璃」一体化名片：头像、昵称、@用户名、吧龄与四项计数。
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.displayName,
    required this.atUserName,
    required this.tbAge,
    required this.avatarUrl,
    required this.stats,
    this.onEdit,
  });

  final String displayName;
  final String atUserName;
  final String tbAge;
  final String avatarUrl;
  final List<_ProfileStat> stats;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final age = tbAge.trim();
    final ageText = age.isEmpty ? '' : (age.endsWith('年') ? age : '$age年');

    return FrostedCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(url: avatarUrl, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.title3
                          .of(context)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (atUserName.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: ShapeDecoration(
                              color: scheme.surfaceContainerHigh,
                              shape: AppShape.full,
                            ),
                            child: Text(
                              atUserName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.caption1
                                  .of(context)
                                  .copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (ageText.isNotEmpty)
                          Flexible(
                            child: Text(
                              '吧龄 $ageText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.caption1
                                  .of(context)
                                  .copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onEdit != null) ...[
                const SizedBox(width: 8),
                FrostedTapSurface(
                  onPressed: onEdit,
                  pill: true,
                  fill: scheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: GlyphIcon(
                      FrostedGlyphs.edit,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1),
          Row(
            children: [
              for (final stat in stats)
                Expanded(
                  child: _StatButton(
                    label: stat.label,
                    value: stat.value,
                    onTap: stat.onTap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStat {
  const _ProfileStat({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
}

class _StatButton extends StatelessWidget {
  const _StatButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return FrostedTapSurface(
      onPressed: onTap,
      radius: AppCorner.sm,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: AppTextStyle.headline
                  .of(context)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestMeView extends StatelessWidget {
  const _GuestMeView({required this.chrome});

  final ChromeController chrome;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return PrismScaffold(
      bar: FrostedAppBar(
        bindChrome: true,
        title: Text(
          '我的',
          style: AppTextStyle.title2
              .of(context)
              .copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => openSettings(context),
            tooltip: '设置',
            icon: const GlyphIcon(FrostedGlyphs.wrench, size: 20),
          ),
        ],
      ),
      body: ChromeScrollListener(
        onHiddenChanged: chrome.setHidden,
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            key: const ValueKey('guest-me-page-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight),
              child: Padding(
                padding: EdgeInsets.only(
                  top: context.appBarInset + 16,
                  bottom: NavigationDock.insetOf(context) + 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      key: const ValueKey('guest-me-page-content'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: FrostedCard(
                            child: Column(
                              children: [
                                const SizedBox(height: 8),
                                GlyphIcon(
                                  FrostedGlyphs.person,
                                  size: 42,
                                  color: scheme.primary,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '欢迎使用 TiebaFrosted',
                                  style: AppTextStyle.title3
                                      .of(context)
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '纯净贴吧体验，支持网页登录、Cookie 登录、多账号切换与一键全签',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyle.footnote
                                      .of(context)
                                      .copyWith(color: scheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: 180,
                                  child: FilledButton(
                                    onPressed: () => openLogin(context),
                                    child: const Text('登录贴吧'),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        ),
                        const FrostedSectionTitle('本地能力'),
                        FrostedSettingsGroup(
                          children: [
                            FrostedListRow(
                              leading: const GlyphIcon(
                                FrostedGlyphs.clock,
                                size: 19,
                              ),
                              title: const Text('浏览历史'),
                              trailing: const GlyphIcon(
                                Glyphs.chevronForward,
                                size: 16,
                              ),
                              onPressed: () => openHistory(context),
                            ),
                            FrostedListRow(
                              leading: const GlyphIcon(
                                FrostedGlyphs.shield,
                                size: 19,
                              ),
                              title: const Text('屏蔽词与内容过滤'),
                              trailing: const GlyphIcon(
                                Glyphs.chevronForward,
                                size: 16,
                              ),
                              onPressed: () => openSettingsBlock(context),
                            ),
                            FrostedListRow(
                              leading: const GlyphIcon(
                                FrostedGlyphs.palette,
                                size: 19,
                              ),
                              title: const Text('外观与液态玻璃'),
                              trailing: const GlyphIcon(
                                Glyphs.chevronForward,
                                size: 16,
                              ),
                              onPressed: () => openSettingsTheme(context),
                            ),
                            FrostedListRow(
                              leading: const GlyphIcon(
                                FrostedGlyphs.wrench,
                                size: 19,
                              ),
                              title: const Text('全部设置'),
                              trailing: const GlyphIcon(
                                Glyphs.chevronForward,
                                size: 16,
                              ),
                              onPressed: () => openSettings(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
