import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/rich_text.dart';

/// 吧规详情页。
class ForumRulePage extends StatefulWidget {
  const ForumRulePage({
    super.key,
    required this.forumId,
    required this.forumName,
  });

  final int forumId;
  final String forumName;

  @override
  State<ForumRulePage> createState() => _ForumRulePageState();
}

class _ForumRulePageState extends State<ForumRulePage> {
  ForumRuleDetailInfo? _rule;
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
      final res = await context.read<TiebaRepo>().getForumRule(widget.forumId);
      if (!mounted) return;
      setState(() {
        _rule = res;
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
      title: '${widget.forumName}吧规',
      body: _loading
          ? const FrostedLoading(label: '加载吧规...')
          : _error != null
              ? FrostedEmpty(
                  title: '加载失败',
                  message: _error,
                  icon: FrostedGlyphs.rule,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('重试'),
                  ),
                )
              : (_rule == null ||
                      (_rule!.rules.isEmpty && _rule!.preface.isEmpty))
                  ? const FrostedEmpty(
                      title: '暂无吧规',
                      message: '该贴吧暂未发布吧规细则',
                      icon: FrostedGlyphs.rule,
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        pageTopInset(context) + 10,
                        14,
                        MediaQuery.paddingOf(context).bottom + 24,
                      ),
                      children: [
                        if (_rule!.title.isNotEmpty ||
                            _rule!.preface.isNotEmpty) ...[
                          FrostedCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_rule!.title.isNotEmpty)
                                  Text(
                                    _rule!.title,
                                    style: AppTextStyle.title3
                                        .of(context)
                                        .copyWith(fontWeight: FontWeight.w700),
                                  ),
                                if (_rule!.publishTime.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '发布时间：${_rule!.publishTime}',
                                    style: AppTextStyle.caption1
                                        .of(context)
                                        .copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                                if (_rule!.preface.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _rule!.preface,
                                    style: AppTextStyle.subheadline.of(context),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        for (var i = 0; i < _rule!.rules.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          FrostedCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_rule!.rules[i].title.isNotEmpty) ...[
                                  Text(
                                    '${i + 1}. ${_rule!.rules[i].title}',
                                    style: AppTextStyle.headline
                                        .of(context)
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                TiebaRichContent(
                                  nodes: _rule!.rules[i].content,
                                  style: AppTextStyle.subheadline.of(context),
                                  onLinkTap: (u) => openTiebaUrl(context, u),
                                  onImageTap: (imgs, idx) => openImageViewer(
                                    context,
                                    images: imgs,
                                    initialIndex: idx,
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
