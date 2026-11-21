import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/refresh.dart';
import '../widgets/remote_image.dart';

/// 热门话题总榜页。
class HotTopicListPage extends StatefulWidget {
  const HotTopicListPage({super.key});

  @override
  State<HotTopicListPage> createState() => _HotTopicListPageState();
}

class _HotTopicListPageState extends State<HotTopicListPage> {
  List<HotTopicItem> _topics = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  Future<void> _load() async {
    setState(() {
      _loading = _topics.isEmpty;
      _error = null;
    });
    try {
      final list = await context.read<TiebaRepo>().getHotTopics();
      if (!mounted) return;
      setState(() {
        _topics = list;
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
      title: '贴吧热议榜',
      body: FrostedRefresh(
        topInset: pageTopInset(context),
        onRefresh: _load,
        child: _loading && _topics.isEmpty
            ? const FrostedLoading(label: '加载热议榜...')
            : _error != null && _topics.isEmpty
                ? FrostedEmpty(
                    title: '加载失败',
                    message: _error,
                    icon: FrostedGlyphs.flame,
                    action: FilledButton(
                      onPressed: _load,
                      child: const Text('重试'),
                    ),
                  )
                : _topics.isEmpty
                    ? const FrostedEmpty(
                        title: '暂无热议话题',
                        icon: FrostedGlyphs.flame,
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          pageTopInset(context) + 8,
                          14,
                          MediaQuery.paddingOf(context).bottom + 24,
                        ),
                        itemCount: _topics.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final item = _topics[idx];
                          return FrostedCard(
                            onPressed: () => openHotTopicDetail(
                              context,
                              topicId: item.topicId,
                              topicName: item.topicName,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 26,
                                  child: Text(
                                    '${idx + 1}',
                                    style: AppTextStyle.title3
                                        .of(context)
                                        .copyWith(
                                          color: idx < 3
                                              ? scheme.error
                                              : scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.topicName,
                                        style: AppTextStyle.headline
                                            .of(context)
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      if (item.topicDesc.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.topicDesc,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyle.footnote
                                              .of(context)
                                              .copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                      if (item.discussNum > 0) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          '${formatCount(item.discussNum)} 实时讨论',
                                          style: AppTextStyle.caption1
                                              .of(context)
                                              .copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (item.topicPic.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  RemoteImage(
                                    url: item.topicPic,
                                    width: 64,
                                    height: 64,
                                    radius: AppCorner.sm + 4,
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
