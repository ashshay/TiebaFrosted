import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/local_db.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/remote_image.dart';
import '../widgets/segmented_capsule.dart';

/// 本地浏览历史页（帖子 / 贴吧分类，支持单条删除与一键清空）。
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _filterType = 2; // 2=帖子, 1=贴吧
  List<HistoryRecord> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await context.read<LocalDb>().getHistory(type: _filterType);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    final ok = await showFrostedConfirm(
      context,
      title: '清空浏览历史',
      message: '确定清空当前分类的全部浏览历史？',
      destructive: true,
    );
    if (ok != true || !mounted) return;
    await context.read<LocalDb>().clearHistory(type: _filterType);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return FrostedPage(
      title: '浏览历史',
      actions: [
        if (_items.isNotEmpty)
          IconButton(
            onPressed: _clearAll,
            tooltip: '清空',
            icon: const GlyphIcon(FrostedGlyphs.delete, size: 19),
          ),
      ],
      body: Padding(
        padding: EdgeInsets.only(top: pageTopInset(context)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: FrostedSegmentedControl<int>(
                value: _filterType,
                onChanged: (v) {
                  if (v == _filterType) return;
                  setState(() => _filterType = v);
                  unawaited(_load());
                },
                segments: const [
                  (2, '帖子'),
                  (1, '贴吧'),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const FrostedLoading()
                  : _items.isEmpty
                      ? const FrostedEmpty(
                          title: '暂无浏览历史',
                          icon: FrostedGlyphs.clock,
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            14,
                            4,
                            14,
                            MediaQuery.paddingOf(context).bottom + 24,
                          ),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final item = _items[idx];
                            return FrostedCard(
                              onPressed: () {
                                if (item.type == 1) {
                                  openForum(context, item.itemId);
                                } else {
                                  final tid = int.tryParse(item.itemId) ?? 0;
                                  if (tid > 0) {
                                    openThread(
                                      context,
                                      threadId: tid,
                                      forumName: item.extra,
                                      initialTitle: item.title,
                                    );
                                  }
                                }
                              },
                              onLongPress: () async {
                                await context.read<LocalDb>().deleteHistory(
                                  item.type,
                                  item.itemId,
                                );
                                await _load();
                              },
                              child: Row(
                                children: [
                                  if (item.type == 1)
                                    RemoteImage(
                                      url: item.avatar,
                                      width: 40,
                                      height: 40,
                                      radius: AppCorner.sm + 2,
                                    )
                                  else
                                    Avatar(url: item.avatar, size: 36),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyle.subheadline
                                              .of(context)
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          joinMeta([
                                            item.subtitle,
                                            formatTiebaTime(item.timestamp),
                                          ]),
                                          style: AppTextStyle.caption1
                                              .of(context)
                                              .copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
