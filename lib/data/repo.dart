import 'dart:io';

import 'api.dart';
import 'cookie_vault.dart';
import 'local_db.dart';
import 'media_saver.dart';
import 'models.dart';
import 'settings.dart';
import 'store.dart';

/// 业务仓库：聚合网络接口、屏蔽规则、本地历史/草稿与写操作封装。
class TiebaRepo {
  TiebaRepo({
    required this.api,
    required this.store,
    required this.settings,
    required this.db,
    required this.mediaSaver,
  });

  final TiebaApi api;
  final FrostedStore store;
  final FrostedSettings settings;
  final LocalDb db;
  final MediaSaver mediaSaver;

  bool get isLoggedIn => store.isLoggedIn;
  AccountRecord? get currentAccount => store.currentAccount;

  Future<void> syncDevice() async {
    try {
      await api.syncDevice();
    } on Object {
      // 同步失败不影响正常浏览
    }
  }

  List<TiebaThread> filterThreads(List<TiebaThread> list) {
    if (!settings.enableBlock && !settings.blockVideoThread) return list;
    return [
      for (final t in list)
        if (!_isThreadBlocked(t)) t,
    ];
  }

  bool _isThreadBlocked(TiebaThread t) {
    if (settings.blockVideoThread && t.video != null) return true;
    if (!settings.enableBlock) return false;
    return store.shouldBlock(
      text: '${t.displayTitle} ${t.abstractText}',
      userName: t.author.displayName,
      userUid: t.author.id > 0 ? '${t.author.id}' : '',
      forumName: t.forumName,
    );
  }

  List<TiebaPost> filterPosts(List<TiebaPost> list) {
    if (!settings.enableBlock) return list;
    return [
      for (final p in list)
        if (!store.shouldBlock(
          text: p.title,
          userName: p.author.displayName,
          userUid: p.author.id > 0 ? '${p.author.id}' : '',
        ))
          p,
    ];
  }

  // ---- Feeds ----

  Future<List<FollowedForum>> getFollowedForums() async {
    final list = await api.followedForums();
    final tops = store.topForums;
    // 接口用 sort_type=3 请求，服务端已按等级排好；本地只把置顶提到最前，
    // 其余保持服务端顺序。接口不下发 cur_score（原版 LikeForum 也没有这个字段），
    // 所以「按经验值排」在客户端无从实现。
    final sorted = List<FollowedForum>.of(list)
      ..sort((a, b) {
        final at = tops.contains(a.forumName) ? 0 : 1;
        final bt = tops.contains(b.forumName) ? 0 : 1;
        return at.compareTo(bt);
      });
    return sorted;
  }

  Future<List<TiebaThread>> getPersonalized({
    int loadType = 1,
    int page = 1,
  }) async {
    final res = await api.personalized(loadType: loadType, page: page);
    return filterThreads(res.threads);
  }

  Future<ConcernPageResult> getConcernFeed({
    String pageTag = '',
    int lastRequestUnix = 0,
    int loadType = 1,
  }) async {
    final res = await api.userLikeFeed(
      pageTag: pageTag,
      lastRequestUnix: lastRequestUnix,
      loadType: loadType,
    );
    return ConcernPageResult(
      threads: filterThreads(res.threads),
      pageTag: res.pageTag,
      hasMore: res.hasMore,
      requestUnix: res.requestUnix,
    );
  }

  Future<HotThreadPageResult> getHotThreads({
    String tabCode = 'all',
    String tabId = '1',
  }) async {
    final res = await api.hotThreadList(tabCode: tabCode, tabId: tabId);
    return HotThreadPageResult(
      topics: res.topics,
      threads: filterThreads(res.threads),
      tabs: res.tabs,
    );
  }

  Future<List<HotTopicItem>> getHotTopics() => api.topicList();

  Future<HotTopicDetailResult> getHotTopicDetail({
    required int topicId,
    required String topicName,
    int page = 1,
    int offset = 0,
    String lastId = '',
  }) => api.topicDetail(
    topicId: topicId,
    topicName: topicName,
    page: page,
    offset: offset,
    lastId: lastId,
  );

  // ---- Forum ----

  Future<ForumPageResult> getForumPage({
    required String forumName,
    int page = 1,
    int loadType = 1,
    int sortType = 0,
    int? goodClassifyId,
  }) async {
    final res = await api.frsPage(
      forumName: forumName,
      page: page,
      loadType: loadType,
      sortType: sortType,
      goodClassifyId: goodClassifyId,
    );
    if (page == 1 && res.forum.name.isNotEmpty) {
      store.recordForumHistory(
        forumName: res.forum.name,
        avatar: res.forum.avatar,
      );
    }
    return ForumPageResult(
      forum: res.forum,
      page: res.page,
      threads: filterThreads(res.threads),
      threadIds: res.threadIds,
      tabs: res.tabs,
      navTabs: res.navTabs,
      tbs: res.tbs,
    );
  }

  Future<List<TiebaThread>> getForumThreadsByIds({
    required int forumId,
    required String forumName,
    required List<int> threadIds,
    int page = 1,
    int sortType = 0,
  }) async {
    final list = await api.frsThreadList(
      forumId: forumId,
      forumName: forumName,
      threadIds: threadIds,
      page: page,
      sortType: sortType,
    );
    return filterThreads(list);
  }

  /// 吧内分区（红框里的「吧友互助 / 交流专区」等）的一页帖子。
  Future<ForumTabThreadResult> getForumTabThreads({
    required int forumId,
    required ForumTab tab,
    int sortType = -1,
    int page = 1,
    int lastThreadId = 0,
  }) async {
    final res = await api.forumTabThreads(
      forumId: forumId,
      tab: tab,
      sortType: sortType,
      page: page,
      lastThreadId: lastThreadId,
    );
    return ForumTabThreadResult(
      threads: filterThreads(res.threads),
      hasMore: res.hasMore,
      lastThreadId: res.lastThreadId,
      sortType: res.sortType,
    );
  }

  Future<ForumDetailInfo> getForumDetail(int forumId) =>
      api.forumDetail(forumId);

  Future<ForumRuleDetailInfo> getForumRule(int forumId) =>
      api.forumRuleDetail(forumId);

  Future<void> toggleLikeForum({
    required int forumId,
    required String forumName,
    required bool like,
    String? tbsOverride,
  }) => api.toggleLikeForum(
    forumId: forumId,
    forumName: forumName,
    like: like,
    tbsOverride: tbsOverride,
  );

  Future<SignResult> signForum({
    required int forumId,
    required String forumName,
    String? tbsOverride,
  }) => api.signForum(
    forumId: forumId,
    forumName: forumName,
    tbsOverride: tbsOverride,
  );

  /// 一键全签：优先尝试 mSign 批量签到，剩余未签逐吧低频签到并实时汇报进度。
  Future<({int total, int signed, int skipped, int failed})> okSignAll({
    void Function(int current, int total, String forumName, String status)?
        onProgress,
  }) async {
    final forums = await getFollowedForums();
    final unsigned = forums.where((f) => !f.isSign).toList();
    final skipped = forums.length - unsigned.length;
    if (unsigned.isEmpty) {
      return (total: forums.length, signed: 0, skipped: skipped, failed: 0);
    }

    var signed = 0;
    var failed = 0;
    final remaining = <FollowedForum>[];

    if (settings.okSignUseOfficial) {
      final eligible = unsigned.where((f) => f.levelId >= 7).toList();
      if (eligible.isNotEmpty) {
        try {
          onProgress?.call(0, unsigned.length, '批量一键签到', '请求 mSign...');
          final mCount = await api.mSignForums(
            eligible.map((e) => e.forumId).toList(),
          );
          signed += mCount;
          if (mCount < eligible.length) {
            remaining.addAll(unsigned);
          } else {
            remaining.addAll(unsigned.where((f) => f.levelId < 7));
          }
        } on Object {
          remaining.addAll(unsigned);
        }
      } else {
        remaining.addAll(unsigned);
      }
    } else {
      remaining.addAll(unsigned);
    }

    var idx = 0;
    for (final f in remaining) {
      idx++;
      onProgress?.call(idx, remaining.length, f.forumName, '签到中...');
      try {
        await api.signForum(forumId: f.forumId, forumName: f.forumName);
        signed++;
        onProgress?.call(idx, remaining.length, f.forumName, '成功');
      } on TiebaApiException catch (e) {
        if (e.code == 160002 || e.message.contains('已签')) {
          signed++;
          onProgress?.call(idx, remaining.length, f.forumName, '已签到');
        } else {
          failed++;
          onProgress?.call(idx, remaining.length, f.forumName, e.message);
        }
      } on Object catch (e) {
        failed++;
        onProgress?.call(idx, remaining.length, f.forumName, '$e');
      }
      if (idx < remaining.length) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }
    }

    return (
      total: forums.length,
      signed: signed,
      skipped: skipped,
      failed: failed,
    );
  }

  // ---- Thread & SubPosts ----

  Future<ThreadPageResult> getThreadPage({
    required int threadId,
    int page = 1,
    int postId = 0,
    bool seeLz = false,
    int sortType = 0,
    bool back = false,
    int forumId = 0,
    int lastPid = 0,
    bool mark = false,
  }) async {
    final res = await api.pbPage(
      threadId: threadId,
      page: page,
      postId: postId,
      seeLz: seeLz,
      sortType: sortType,
      back: back,
      forumId: forumId,
      lastPid: lastPid,
      mark: mark,
    );
    if (page == 1 && res.thread.effectiveId > 0) {
      store.recordThreadHistory(
        threadId: res.thread.effectiveId,
        title: res.thread.displayTitle,
        forumName: res.forum.name.isNotEmpty
            ? res.forum.name
            : res.thread.forumName,
        avatar: res.thread.author.portrait,
      );
    }
    return ThreadPageResult(
      thread: res.thread,
      forum: res.forum,
      page: res.page,
      firstFloorPost: res.firstFloorPost,
      posts: filterPosts(res.posts),
      sortOptions: res.sortOptions,
      sortType: res.sortType,
      tbs: res.tbs,
      hasFloor: res.hasFloor,
    );
  }

  Future<SubPostsPageResult> getSubPosts({
    required int threadId,
    required int postId,
    int subPostId = 0,
    int page = 1,
    int forumId = 0,
  }) => api.pbFloor(
    threadId: threadId,
    postId: postId,
    subPostId: subPostId,
    page: page,
    forumId: forumId,
  );

  // ---- Likes / Store / Reply / Post / Vote ----

  Future<void> opAgree({
    required int threadId,
    int postId = 0,
    required bool agree,
    int objType = 3,
  }) => api.opAgree(
    threadId: threadId,
    postId: postId,
    opType: agree ? 0 : 1,
    objType: objType,
  );

  Future<List<ThreadStoreItem>> getThreadStore({
    int pageSize = 20,
    int offset = 0,
  }) => api.threadStore(pageSize: pageSize, offset: offset);

  Future<void> toggleThreadStore({
    required int threadId,
    int postId = 0,
    int? forumId,
    required bool collect,
  }) {
    if (collect) {
      return api.addThreadStore(threadId: threadId, postId: postId);
    }
    return api.removeThreadStore(threadId: threadId, forumId: forumId);
  }

  Future<void> reply({
    required int forumId,
    required String forumName,
    required int threadId,
    required String content,
    int? quotePostId,
    int? subPostId,
    int? replyUid,
    String? tbsOverride,
  }) => api.addPost(
    forumId: forumId,
    forumName: forumName,
    threadId: threadId,
    content: content,
    nameShow: store.currentAccount?.displayName ?? '',
    quotePostId: quotePostId,
    subPostId: subPostId,
    replyUid: replyUid,
    tbsOverride: tbsOverride,
  );

  Future<void> createThread({
    required int forumId,
    required String forumName,
    required String title,
    required String content,
    String? tbsOverride,
  }) => api.addThread(
    forumId: forumId,
    forumName: forumName,
    title: title,
    content: content,
    nameShow: store.currentAccount?.displayName ?? '',
    tbsOverride: tbsOverride,
  );

  Future<UploadPicResult> uploadImage({
    required File file,
    required String forumName,
    void Function(double progress)? onProgress,
  }) => api.uploadPicture(
    file: file,
    forumName: forumName,
    saveOrigin: settings.loadOriginImage,
    onProgress: onProgress,
  );

  Future<void> votePoll({
    required int forumId,
    required int threadId,
    required List<int> optionIds,
  }) => api.votePoll(
    forumId: forumId,
    threadId: threadId,
    optionIds: optionIds,
  );

  Future<void> deletePost({
    required int forumId,
    required String forumName,
    required int threadId,
    required int postId,
    bool isFloor = false,
  }) => api.deletePost(
    forumId: forumId,
    forumName: forumName,
    threadId: threadId,
    postId: postId,
    isFloor: isFloor,
  );

  // ---- User & Social ----

  Future<UserProfileResult> getUserProfile({
    int? targetUid,
    String targetPortrait = '',
    int page = 1,
  }) => api.userProfile(
    targetUid: targetUid,
    targetPortrait: targetPortrait,
    page: page,
  );

  Future<List<UserPostItem>> getUserPosts({
    required int uid,
    int page = 1,
    bool isThread = true,
  }) => api.userPosts(uid: uid, page: page, isThread: isThread);

  Future<({List<FollowedForum> items, bool hasMore})> getUserLikeForums({
    required int uid,
    int page = 1,
  }) => api.userLikeForums(uid: uid, page: page);

  Future<({List<TiebaUser> items, bool hasMore})> getFollowList({
    int? uid,
    int page = 1,
  }) => api.followList(uid: uid, page: page);

  Future<void> toggleFollowUser({
    required String portrait,
    required bool follow,
    String? tbsOverride,
  }) => api.toggleFollowUser(
    portrait: portrait,
    follow: follow,
    tbsOverride: tbsOverride,
  );

  Future<void> modifyProfile({
    required String nickName,
    required String intro,
    required int sex,
  }) => api.modifyProfile(nickName: nickName, intro: intro, sex: sex);

  // ---- Notifications ----

  Future<({List<NotificationItem> items, bool hasMore})> getReplyMe({
    int page = 1,
  }) => api.replyMe(page: page);

  Future<({List<NotificationItem> items, bool hasMore})> getAtMe({
    int page = 1,
  }) => api.atMe(page: page);

  // ---- Search ----

  Future<SearchSugResult> getSearchSuggestions(String keyword) =>
      api.searchSuggestions(keyword);

  Future<({SearchForumItem? exact, List<SearchForumItem> fuzzy})> searchForum(
    String keyword,
  ) => api.searchForum(keyword);

  Future<({List<SearchThreadItem> items, bool hasMore})> searchThread({
    required String keyword,
    int page = 1,
    int order = 2,
    int filter = 1,
    String? forumName,
  }) => api.searchThread(
    keyword: keyword,
    page: page,
    order: order,
    filter: filter,
    forumName: forumName,
  );

  Future<List<SearchUserItem>> searchUser(String keyword) =>
      api.searchUser(keyword);

  // ---- Auth ----

  /// 使用抓取或手动粘贴的 Cookie（至少含 BDUSS）完成校验并落盘账号。
  Future<AccountRecord> loginWithCookieString(String rawCookie) async {
    final vault = CookieVault()..loadFromRaw(rawCookie);
    final bduss = vault.bduss;
    if (bduss.isEmpty) {
      throw const TiebaApiException(-1, 'Cookie 中未找到 BDUSS');
    }
    final stoken = vault.stoken;
    final info = await api.verifyLogin(bduss: bduss, stoken: stoken);
    if (info.uid.isEmpty) {
      throw const TiebaApiException(-1, 'BDUSS 校验失败，请重新登录');
    }
    final record = AccountRecord(
      uid: info.uid,
      name: info.name,
      nameShow: info.nameShow,
      portrait: info.portrait,
      bduss: bduss,
      stoken: stoken,
      tbs: info.tbs,
      cookie: vault.rawHeader,
      baiduId: vault.baiduId,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await store.saveAccount(record, activate: true);
    if (vault.baiduId.isNotEmpty) {
      await api.device.updateBaiduId(vault.baiduId);
    }
    return record;
  }
}
