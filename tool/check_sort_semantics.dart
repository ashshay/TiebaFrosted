// 验证服务端「倒序」的分页语义：最后一页是不是最新回复。
// 只读，不登录。
// ignore_for_file: avoid_print

import 'package:tieba_frosted/core/device.dart';
import 'package:tieba_frosted/data/api.dart';

Future<void> main() async {
  final api = TiebaApi(
    device: TiebaDevice.ephemeral(),
    credentialProvider: () => (
      bduss: '',
      stoken: '',
      tbs: '',
      uid: '',
      zid: '',
      webCookie: '',
    ),
  );
  await api.syncDevice();

  final hot = await api.hotThreadList();
  final big = hot.threads.firstWhere((t) => t.replyNum > 500);
  print('thread: ${big.effectiveId} [${big.forumName}] replies=${big.replyNum}');

  final asc1 = await api.pbPage(
    threadId: big.effectiveId,
    forumId: big.forumId,
    page: 1,
    sortType: 0,
  );
  final total = asc1.page.effectiveTotalPage;
  print('totalPage = $total');

  Future<void> dump(String label, int page, int sortType) async {
    final r = await api.pbPage(
      threadId: big.effectiveId,
      forumId: big.forumId,
      page: page,
      sortType: sortType,
    );
    final floors = r.posts.where((p) => p.floor != 1).toList();
    if (floors.isEmpty) {
      print('$label page=$page sort=$sortType -> 0 posts');
      return;
    }
    final times = floors.map((p) => p.time).toList();
    final descending = List.generate(
      times.length - 1,
      (i) => times[i] >= times[i + 1],
    ).every((x) => x);
    final ascending = List.generate(
      times.length - 1,
      (i) => times[i] <= times[i + 1],
    ).every((x) => x);
    print(
      '$label page=$page sort=$sortType -> ${floors.length} posts '
      '| 首 ${floors.first.floor}F t=${floors.first.time} '
      '| 末 ${floors.last.floor}F t=${floors.last.time} '
      '| 页内${descending ? "时间递减(新→旧)" : ascending ? "时间递增(旧→新)" : "无序"}',
    );
  }

  await dump('A 正序第1页', 1, 0);
  await dump('B 正序末页', total, 0);
  await dump('C 倒序第1页', 1, 1);
  await dump('D 倒序末页', total, 1);
  await dump('E 倒序第2页', 2, 1);
}
