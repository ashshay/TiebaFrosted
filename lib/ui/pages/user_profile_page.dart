import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/local_db.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../data/store.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/press_scale.dart';
import '../widgets/profile_header.dart';
import '../widgets/refresh.dart';

/// 他人 / 个人主页（折叠头 + 关注按钮 + TA 的帖子/回复/关注的吧入口）。
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    this.uid,
    this.portrait = '',
    this.initialName = '',
  });

  final int? uid;
  final String portrait;
  final String initialName;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  TiebaUser _user = const TiebaUser();
  List<UserPostItem> _recentPosts = [];
  String _tbs = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _user = TiebaUser(
      id: widget.uid ?? 0,
      nameShow: widget.initialName,
      portrait: widget.portrait,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<TiebaRepo>().getUserProfile(
        targetUid: widget.uid,
        targetPortrait: widget.portrait,
      );
      if (!mounted) return;
      setState(() {
        _user = res.user;
        _tbs = res.tbs;
        _recentPosts = res.posts;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = cleanError(e);
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (!await ensureLoggedIn(context, reason: '登录后即可关注吧友')) return;
    if (!mounted || _user.portrait.isEmpty) return;
    final next = !_user.hasConcerned;
    final prev = _user;
    setState(() {
      _user = _user.copyWith(
        hasConcerned: next,
        fansNum: (_user.fansNum + (next ? 1 : -1)).clamp(0, 1 << 30),
      );
    });
    try {
      await context.read<TiebaRepo>().toggleFollowUser(
        portrait: _user.portrait,
        follow: next,
        tbsOverride: _tbs,
      );
      if (mounted) showFrostedToast(context, next ? '已关注' : '已取消关注');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _user = prev);
      showFrostedToast(context, cleanError(e), level: BannerLevel.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final scheme = context.colorScheme;
    final store = context.watch<FrostedStore>();
    final isSelf = store.uid.isNotEmpty && store.uid == '${_user.id}';

    return PrismScaffold(
      bar: const ZeroAppBar(),
      body: FrostedRefresh(
        topInset: topInset + ProfileHeaderDelegate.barHeight,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: ProfileHeaderDelegate(
                topInset: topInset,
                nameLine: ProfileHeaderDelegate.nameLineOf(context),
                title: _user.displayName,
                avatarUrl: _user.portrait,
                coverUrl: _user.bgPic,
                showBack: true,
                onBack: () => Navigator.of(context).maybePop(),
                actions: [
                  if (isSelf)
                    (
                      glyph: FrostedGlyphs.edit,
                      tooltip: '编辑资料',
                      onPressed: () async {
                        final ok = await openEditProfile(context, user: _user);
                        if (ok == true && mounted) unawaited(_load());
                      },
                    )
                  else
                    (
                      glyph: FrostedGlyphs.more,
                      tooltip: '更多',
                      onPressed: () async {
                        final picked = await showFrostedChoices<String>(
                          context,
                          title: _user.displayName,
                          choices: const [
                            FrostedChoice(
                              value: 'block',
                              label: '屏蔽该用户',
                              destructive: true,
                            ),
                          ],
                        );
                        if (picked == 'block' && context.mounted) {
                          await context.read<FrostedStore>().addBlockRule(
                            type: BlockRuleType.user,
                            value: _user.displayName,
                          );
                          if (context.mounted) {
                            showFrostedToast(
                              context,
                              '已屏蔽 ${_user.displayName}',
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  4,
                  14,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            joinMeta([
                              if (_user.tiebaUid.isNotEmpty)
                                'ID ${_user.tiebaUid}',
                              if (_user.tbAge.isNotEmpty) '吧龄 ${_user.tbAge}年',
                              if (_user.ipAddress.isNotEmpty)
                                'IP ${_user.ipAddress}',
                            ]),
                            style: AppTextStyle.caption1
                                .of(context)
                                .copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        if (!isSelf && _user.portrait.isNotEmpty)
                          PressScale(
                            scale: 0.94,
                            child: FrostedTapSurface(
                              onPressed: _toggleFollow,
                              pill: true,
                              fill: _user.hasConcerned
                                  ? SurfaceLevel.card.colorOf(scheme)
                                  : scheme.primary,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                child: Text(
                                  _user.hasConcerned ? '已关注' : '关注',
                                  style: AppTextStyle.footnote
                                      .of(context)
                                      .copyWith(
                                        color: _user.hasConcerned
                                            ? scheme.onSurface
                                            : scheme.onPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_user.intro.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _user.intro,
                        style: AppTextStyle.subheadline
                            .of(context)
                            .copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FrostedCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Metric('关注', formatCount(_user.concernNum)),
                          _Metric('粉丝', formatCount(_user.fansNum)),
                          _Metric('获赞', formatCount(_user.totalAgreeNum)),
                          _Metric('贴吧', formatCount(_user.myLikeNum)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_user.id > 0)
                      FrostedSettingsGroup(
                        children: [
                          FrostedListRow(
                            leading: const GlyphIcon(
                              FrostedGlyphs.forum,
                              size: 19,
                            ),
                            title: const Text('TA 关注的吧'),
                            trailing: const GlyphIcon(
                              Glyphs.chevronForward,
                              size: 16,
                            ),
                            onPressed: () => openUserLikeForum(
                              context,
                              uid: _user.id,
                              title: '${_user.displayName}关注的吧',
                            ),
                          ),
                          FrostedListRow(
                            leading: const GlyphIcon(
                              FrostedGlyphs.comment,
                              size: 19,
                            ),
                            title: const Text('TA 的帖子与回复'),
                            trailing: const GlyphIcon(
                              Glyphs.chevronForward,
                              size: 16,
                            ),
                            onPressed: () => openUserPost(
                              context,
                              uid: _user.id,
                              title: '${_user.displayName}的帖子',
                            ),
                          ),
                          FrostedListRow(
                            leading: const GlyphIcon(
                              FrostedGlyphs.follow,
                              size: 19,
                            ),
                            title: const Text('TA 的关注'),
                            trailing: const GlyphIcon(
                              Glyphs.chevronForward,
                              size: 16,
                            ),
                            onPressed: () => openFollowList(
                              context,
                              uid: _user.id,
                              title: '${_user.displayName}的关注',
                            ),
                          ),
                        ],
                      ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: FrostedLoading(),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: FrostedEmpty(
                          title: '加载失败',
                          message: _error,
                          icon: FrostedGlyphs.person,
                          action: FilledButton(
                            onPressed: _load,
                            child: const Text('重试'),
                          ),
                        ),
                      )
                    else if (_recentPosts.isNotEmpty) ...[
                      const FrostedSectionTitle('近期动态'),
                      for (var i = 0; i < _recentPosts.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        FrostedCard(
                          onPressed: () => openThread(
                            context,
                            threadId: _recentPosts[i].threadId,
                            forumId: _recentPosts[i].forumId,
                            forumName: _recentPosts[i].forumName,
                            initialTitle: _recentPosts[i].title,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _recentPosts[i].title.isNotEmpty
                                    ? _recentPosts[i].title
                                    : _recentPosts[i].abstractText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyle.headline
                                    .of(context)
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (_recentPosts[i].abstractText.isNotEmpty &&
                                  _recentPosts[i].abstractText !=
                                      _recentPosts[i].title) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _recentPosts[i].abstractText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyle.subheadline
                                      .of(context)
                                      .copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                joinMeta([
                                  if (_recentPosts[i].forumName.isNotEmpty)
                                    '${_recentPosts[i].forumName}吧',
                                  if (_recentPosts[i].createTime > 0)
                                    formatTiebaTime(_recentPosts[i].createTime),
                                ]),
                                style: AppTextStyle.caption1
                                    .of(context)
                                    .copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
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
              .copyWith(color: context.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
