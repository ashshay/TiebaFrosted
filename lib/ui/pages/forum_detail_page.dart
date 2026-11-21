import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/remote_image.dart';

/// 吧资料页。
class ForumDetailPage extends StatefulWidget {
  const ForumDetailPage({
    super.key,
    required this.forumId,
    required this.forumName,
  });

  final int forumId;
  final String forumName;

  @override
  State<ForumDetailPage> createState() => _ForumDetailPageState();
}

class _ForumDetailPageState extends State<ForumDetailPage> {
  ForumDetailInfo? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await context.read<TiebaRepo>().getForumDetail(widget.forumId);
      if (!mounted) return;
      setState(() {
        _detail = d;
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

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return FrostedPage(
      title: '${widget.forumName}吧资料',
      body: _loading
          ? const FrostedLoading(label: '加载吧资料...')
          : _error != null
              ? FrostedEmpty(
                  title: '加载失败',
                  message: _error,
                  icon: FrostedGlyphs.info,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('重试'),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    pageTopInset(context) + 10,
                    14,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  children: [
                    FrostedCard(
                      child: Row(
                        children: [
                          RemoteImage(
                            url: _detail?.avatar ?? '',
                            width: 60,
                            height: 60,
                            radius: AppCorner.md,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_detail?.forumName.isNotEmpty == true ? _detail!.forumName : widget.forumName}吧',
                                  style: AppTextStyle.title3
                                      .of(context)
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (_detail != null &&
                                    _detail!.slogan.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _detail!.slogan,
                                    style: AppTextStyle.footnote
                                        .of(context)
                                        .copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const FrostedSectionTitle('基本信息'),
                    FrostedSettingsGroup(
                      children: [
                        FrostedListRow(
                          title: const Text('关注人数'),
                          trailing: Text(
                            formatCount(_detail?.memberCount ?? 0),
                            style: AppTextStyle.subheadline
                                .of(context)
                                .copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        FrostedListRow(
                          title: const Text('帖子总数'),
                          trailing: Text(
                            formatCount(_detail?.threadCount ?? 0),
                            style: AppTextStyle.subheadline
                                .of(context)
                                .copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        if (_detail != null &&
                            (_detail!.lv1Name.isNotEmpty ||
                                _detail!.lv2Name.isNotEmpty))
                          FrostedListRow(
                            title: const Text('分类目录'),
                            trailing: Text(
                              joinMeta([_detail!.lv1Name, _detail!.lv2Name]),
                              style: AppTextStyle.subheadline
                                  .of(context)
                                  .copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        FrostedListRow(
                          leading: const GlyphIcon(
                            FrostedGlyphs.rule,
                            size: 19,
                          ),
                          title: const Text('查看吧规'),
                          trailing: const GlyphIcon(
                            Glyphs.chevronForward,
                            size: 16,
                          ),
                          onPressed: () => openForumRule(
                            context,
                            forumId: widget.forumId,
                            forumName: widget.forumName,
                          ),
                        ),
                      ],
                    ),
                    if (_detail != null && _detail!.intro.isNotEmpty) ...[
                      const FrostedSectionTitle('简介'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: FrostedCard(
                          child: Text(
                            _detail!.intro,
                            style: AppTextStyle.body.of(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}
