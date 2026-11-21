// The live probe prints its findings to a terminal; that is its whole output
// channel, so the production-code print ban does not apply here.
// ignore_for_file: avoid_print

import 'package:tieba_frosted/core/device.dart';
import 'package:tieba_frosted/data/api.dart';

Future<void> main() async {
  final device = TiebaDevice.ephemeral();
  final api = TiebaApi(
    device: device,
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

  // 1. Hot threads + large thread pbPage + pbFloor
  final hot = await api.hotThreadList();
  final big = hot.threads.isNotEmpty
      ? hot.threads.first
      : (await api.personalized()).threads.first;
  print('Big thread: tid=${big.effectiveId} [${big.forumName}吧] "${big.displayTitle}" (replies=${big.replyNum})');

  final pb = await api.pbPage(threadId: big.effectiveId, forumId: big.forumId);
  print('pbPage: posts=${pb.posts.length}, totalPage=${pb.page.effectiveTotalPage}, sorts=${pb.sortOptions.map((s) => s.sortName).toList()}');
  for (final p in pb.posts.take(4)) {
    print('  [${p.floor}F] ${p.author.displayName} lv.${p.author.levelId} ip=${p.author.ipAddress} nodes=${p.content.length} subs=${p.subPostNumber} agree=${p.agree.displayCount}');
  }

  final withSub = pb.posts.where((p) => p.subPostNumber > 0).toList();
  if (withSub.isNotEmpty) {
    final floor = await api.pbFloor(
      threadId: big.effectiveId,
      postId: withSub.first.id,
      forumId: pb.forum.id,
    );
    print('pbFloor: pid=${withSub.first.id} subPosts=${floor.subPosts.length}/${floor.page.totalCount}');
    if (floor.subPosts.isNotEmpty) {
      print('  sub[0]: ${floor.subPosts.first.author.displayName} nodes=${floor.subPosts.first.content.length}');
    }
  }

  // 2. ForumDetail + ForumRuleDetail
  if (pb.forum.id > 0) {
    final detail = await api.forumDetail(pb.forum.id);
    print('forumDetail: ${detail.forumName} members=${detail.memberCount} slogan="${detail.slogan}"');
    final rule = await api.forumRuleDetail(pb.forum.id);
    print('forumRuleDetail: title="${rule.title}" rules=${rule.rules.length}');
  }

  // 3. TopicList
  final topics = await api.topicList();
  print('topicList: count=${topics.length}, first=${topics.isNotEmpty ? topics.first.topicName : "none"}');

  // 4. UserProfile + UserPosts
  final uid = pb.firstFloorPost?.author.id ?? pb.posts.first.author.id;
  if (uid > 0) {
    final prof = await api.userProfile(targetUid: uid);
    print('userProfile: ${prof.user.displayName} fans=${prof.user.fansNum} posts=${prof.posts.length}');
    final up = await api.userPosts(uid: uid, isThread: true);
    print('userPosts: count=${up.length}');
  }

  // 5. SearchSug + SearchThread + SearchUser
  final sug = await api.searchSuggestions('flutter');
  print('searchSug: ${sug.suggestions.take(3).toList()} card=${sug.forumCard?.forumName}');
  final st = await api.searchThread(keyword: 'flutter');
  print('searchThread: count=${st.items.length} hasMore=${st.hasMore}');
  final su = await api.searchUser('flutter');
  print('searchUser: count=${su.length}');

  print('\nALL EXTENDED LIVE CHECKS PASSED!');
}
