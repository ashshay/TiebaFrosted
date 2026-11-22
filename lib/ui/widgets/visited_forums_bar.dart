import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../data/local_db.dart';
import 'common.dart';
import 'remote_image.dart';

/// 首页顶部的「经过贴吧」：最近进过的吧横滑胶囊条，可折叠。
///
/// 数据来自本地 `history` 表的 type=1 记录，进吧时由 [TiebaRepo.getForumPage]
/// 写入，所以这里只负责读和展示。
class VisitedForumsBar extends StatefulWidget {
  const VisitedForumsBar({
    super.key,
    required this.forums,
    required this.onForumTap,
    this.onOpenAll,
  });

  final List<HistoryRecord> forums;
  final ValueChanged<HistoryRecord> onForumTap;

  /// 点标题右侧的箭头：进完整的浏览历史页。
  final VoidCallback? onOpenAll;

  @override
  State<VisitedForumsBar> createState() => _VisitedForumsBarState();
}

class _VisitedForumsBarState extends State<VisitedForumsBar> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.forums.isEmpty) return const SizedBox.shrink();
    final scheme = context.colorScheme;
    final disabled = context.disableAnimations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FrostedTapSurface(
          onPressed: () => setState(() => _expanded = !_expanded),
          radius: AppCorner.sm,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Text(
                  '经过贴吧',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: disabled
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: GlyphIcon(
                    Glyphs.chevronDown,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: disabled
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    itemCount: widget.forums.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final f = widget.forums[idx];
                      return _VisitedForumChip(
                        record: f,
                        onTap: () => widget.onForumTap(f),
                      );
                    },
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _VisitedForumChip extends StatelessWidget {
  const _VisitedForumChip({required this.record, required this.onTap});

  final HistoryRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return FrostedTapSurface(
      onPressed: onTap,
      pill: true,
      fill: context.surfaceLevel.next.colorOf(scheme),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RemoteImage(
              url: record.avatar,
              width: 24,
              height: 24,
              radius: 12,
              placeholderColor: scheme.surfaceContainerHighest,
            ),
            const SizedBox(width: 6),
            Text(
              record.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
