import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import 'common.dart';

/// 贴吧列表骨架屏（复用 prism_ui 墙钟同步呼吸骨架条，零全屏滤镜开销）。
class ThreadCardSkeleton extends StatelessWidget {
  const ThreadCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const FrostedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonPill(width: 32, height: 32),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonPill(width: 96, height: 12),
                  SizedBox(height: 6),
                  SkeletonPill(width: 64, height: 10),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          SkeletonPill(width: double.infinity, height: 16),
          SizedBox(height: 8),
          SkeletonPill(width: 220, height: 14),
          SizedBox(height: 12),
          Row(
            children: [
              SkeletonPill(width: 48, height: 12),
              SizedBox(width: 16),
              SkeletonPill(width: 48, height: 12),
              SizedBox(width: 16),
              SkeletonPill(width: 48, height: 12),
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
      padding: EdgeInsets.fromLTRB(
        14,
        topInset + 12,
        14,
        pageBottomInset(context),
      ),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => const ThreadCardSkeleton(),
    );
  }
}
