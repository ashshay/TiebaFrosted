import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import 'common.dart';

/// 贴吧列表骨架屏（基于 prism_ui SurfaceLevel 与超椭圆）。
class ThreadCardSkeleton extends StatelessWidget {
  const ThreadCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final barColor = context.colorScheme.surfaceContainerHighest;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: ShapeDecoration(color: barColor, shape: AppShape.xs),
    );

    return FrostedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: ShapeDecoration(
                  color: barColor,
                  shape: AppShape.full,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(96, 12),
                  const SizedBox(height: 6),
                  bar(64, 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          bar(double.infinity, 16),
          const SizedBox(height: 8),
          bar(220, 14),
          const SizedBox(height: 12),
          Row(
            children: [
              bar(48, 12),
              const SizedBox(width: 16),
              bar(48, 12),
              const SizedBox(width: 16),
              bar(48, 12),
            ],
          ),
        ],
      ),
    );
  }
}

class FeedSkeletonList extends StatelessWidget {
  const FeedSkeletonList({super.key, this.count = 5, this.topInset = 0});

  final int count;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(14, topInset + 12, 14, pageBottomInset(context)),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => const ThreadCardSkeleton(),
    );
  }
}
