import 'dart:io';

import 'api.dart';
import 'cookie_vault.dart';
import 'local_db.dart';
import 'media_saver.dart';
import 'models.dart';
import 'native_channels.dart';
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
    await _absorbTbs(res.tbs);
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
  }) => _write(
    (tbs) => api.toggleLikeForum(
      forumId: forumId,
      forumName: forumName,
      like: like,
      tbsOverride: tbs,
    ),
    tbsOverride: tbsOverride,
  );

  Future<SignResult> signForum({
    required int forumId,
    required String forumName,
    String? tbsOverride,
  }) => _write(
    (tbs) => api.signForum(
      forumId: forumId,
      forumName: forumName,
      tbsOverride: tbs,
    ),
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
    int jumpFloorNum = 0,
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
      jumpFloorNum: jumpFloorNum,
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
    await _absorbTbs(res.tbs);
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

  /// 最近一次写操作失败的现场信息（只记「字段在不在」，不含内容），
  /// 供用户在账号页自取，便于定位「凭据看着齐全、服务端仍判未登录」。
  String lastWriteDiagnostic = '';

  /// 最近一次 `/c/s/login` 自检结果：判断 BDUSS 本身是否还活着。
  String sessionCheck = '未检查';

  /// 包一层写调用：发请求前先补齐登录凭据，遇到登录态错误时自愈一次再重试。
  ///
  /// 贴吧的写接口（回帖、发帖、收藏、点赞、签到…）都要求 BDUSS + STOKEN + tbs
  /// 齐全；tbs 会随会话过期，STOKEN 也可能被抓错（网页登录那份只对网页有效），
  /// 所以失败后先按贴吧域名的 Cookie 纠一次再重试，比直接把错误丢给用户有用。
  /// 重试时丢掉调用方从帖子页带下来的旧 tbs，改用刚刷新到的账号 tbs。
  Future<T> _write<T>(
    Future<T> Function(String? tbsOverride) run, {
    String? tbsOverride,
  }) async {
    await ensureWritableSession();
    final inherited = (tbsOverride != null && tbsOverride.isNotEmpty)
        ? tbsOverride
        : null;
    try {
      return await run(inherited);
    } on TiebaApiException catch (e) {
      if (!e.isLoginFailure) rethrow;
      final healed = await _refreshSession();
      if (!healed) throw _sessionBroken(e);
      try {
        return await run(null);
      } on TiebaApiException catch (retryError) {
        if (!retryError.isLoginFailure) rethrow;
        throw _sessionBroken(retryError);
      }
    }
  }

  /// 把服务端那句笼统的「用户未登录或登录失败」换成能照着做的提示。
  ///
  /// 提示里带上「凭据齐不齐」这一层信息：齐了还失败说明是会话被服务端判死
  /// （多半得清 Cookie 重登），不齐则直接指出缺哪一项。
  TiebaApiException _sessionBroken(TiebaApiException cause) {
    final acc = store.currentAccount;
    lastWriteDiagnostic = _diagnose(cause);
    if (acc == null || acc.bduss.isEmpty) {
      return const TiebaApiException(-1, '账号登录信息已丢失，请重新登录。');
    }
    final missing = acc.writeBlockReason;
    if (missing.isNotEmpty) {
      return TiebaApiException(
        -1,
        '当前账号缺少 $missing，只能浏览、不能发言。'
        '请用「网页登录」重新登录，或粘贴含 STOKEN 的完整 Cookie。',
      );
    }
    return const TiebaSessionRejectedException(
      1,
      '登录态已失效（BDUSS / STOKEN / tbs 都在，服务端仍判未登录），'
      '需要清空旧 Cookie 重新登录。',
    );
  }

  /// 只记录字段是否存在，不写任何凭据内容。
  String _diagnose(TiebaApiException cause) {
    final acc = store.currentAccount;
    String has(String? v) => (v != null && v.isNotEmpty) ? '有' : '无';
    final fields = <String>[
      'BDUSS=${has(acc?.bduss)}',
      'STOKEN=${has(acc?.stoken)}',
      'tbs=${has(acc?.tbs)}',
      'z_id=${has(acc?.zid)}',
      'uid=${has(acc?.uid)}',
      'clientId=${has(api.device.clientId)}',
      'BAIDUID=${has(api.device.baiduId)}',
    ].join(' ');
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    return '$stamp code=${cause.code} msg=${cause.message}\n'
        '$fields\nsession=$sessionCheck';
  }

  /// 写操作前的登录态自检：补齐 STOKEN / z_id，缺 tbs 时重新取一次。
  ///
  /// 只粘贴 BDUSS、或网页登录时 Cookie 抓得太早，都会得到一个「能看不能写」的
  /// 半套会话——浏览接口只认 BDUSS，所以帖子照常能看，而任何写操作都会被服务端
  /// 回成 `用户未登录或登录失败`。这里尽量把缺的字段从 WebView 的 Cookie 罐补齐，
  /// 补不齐时抛一条能照着做的错误，而不是让服务端那句话直接甩给用户。
  ///
  /// STOKEN 一律以**贴吧域名**下那一份为准：passport / wappass 也种了同名 Cookie，
  /// 用错版本同样只会在写操作上失败（TiebaLite 的登录只读贴吧域名的 Cookie）。
  Future<void> ensureWritableSession() async {
    final acc = store.currentAccount;
    if (acc == null || acc.bduss.isEmpty) {
      throw const TiebaApiException(-1, '请先登录百度贴吧账号');
    }
    if (acc.canWrite && acc.zid.isNotEmpty) return;

    var next = acc;
    final jar = await NativeChannels.readTiebaCookies();
    // 罐里是别的账号时不要拿它的 STOKEN 覆盖当前账号。
    final jarBduss = jar['BDUSS'] ?? '';
    final trustJar = jarBduss.isEmpty || jarBduss == next.bduss;
    if (trustJar) {
      final stoken = jar['STOKEN'] ?? '';
      if (stoken.isNotEmpty && stoken != next.stoken) {
        next = next.copyWith(stoken: stoken);
      }
      final zid = jar['BAIDUZID'] ?? jar['ZID'] ?? '';
      if (zid.isNotEmpty && zid != next.zid) {
        next = next.copyWith(zid: zid);
      }
      final baiduId = jar['BAIDUID'] ?? '';
      if (next.baiduId.isEmpty && baiduId.isNotEmpty) {
        next = next.copyWith(baiduId: baiduId);
      }
    }
    if (next.tbs.isEmpty) {
      try {
        final info = await api.verifyLogin(
          bduss: next.bduss,
          stoken: next.stoken,
        );
        if (info.tbs.isNotEmpty) next = next.copyWith(tbs: info.tbs);
        if (info.nameShow.isNotEmpty) {
          next = next.copyWith(nameShow: info.nameShow);
        }
      } on Object {
        // 取不到 tbs 就先不拦，让真正发写请求时的服务端返回说了算。
      }
    }
    if (_accountChanged(acc, next)) {
      await store.saveAccount(next);
    }
    if (next.stoken.isEmpty && next.tbs.isEmpty) {
      throw TiebaApiException(
        -1,
        '当前账号只有 BDUSS（缺 ${next.writeBlockReason}），只能浏览、不能发言。'
        '请用「网页登录」重新登录，或粘贴含 STOKEN 的完整 Cookie。',
      );
    }
  }

  /// 写失败后的自愈：重读贴吧域名的 Cookie，用新的 STOKEN / z_id 换一次 tbs。
  ///
  /// 有变化才算成功（调用方据此决定要不要重试），没有变化说明这份会话确实死了。
  Future<bool> _refreshSession() async {
    final acc = store.currentAccount;
    if (acc == null || acc.bduss.isEmpty) return false;
    var next = acc;
    var changed = false;

    final jar = await NativeChannels.readTiebaCookies();
    final jarBduss = jar['BDUSS'] ?? '';
    if (jarBduss.isEmpty || jarBduss == next.bduss) {
      final stoken = jar['STOKEN'] ?? '';
      if (stoken.isNotEmpty && stoken != next.stoken) {
        next = next.copyWith(stoken: stoken);
        changed = true;
      }
      final zid = jar['BAIDUZID'] ?? jar['ZID'] ?? '';
      if (zid.isNotEmpty && zid != next.zid) {
        next = next.copyWith(zid: zid);
        changed = true;
      }
    }
    try {
      final info = await api.verifyLogin(bduss: next.bduss, stoken: next.stoken);
      sessionCheck = '通过';
      if (info.tbs.isNotEmpty && info.tbs != next.tbs) {
        next = next.copyWith(tbs: info.tbs);
        changed = true;
      }
    } on TiebaApiException catch (e) {
      sessionCheck = '失败(${e.code} ${e.message})';
    } on Object {
      sessionCheck = '异常';
    }
    if (!changed) return false;
    await store.saveAccount(next);
    return true;
  }

  bool _accountChanged(AccountRecord a, AccountRecord b) =>
      a.stoken != b.stoken ||
      a.tbs != b.tbs ||
      a.zid != b.zid ||
      a.baiduId != b.baiduId ||
      a.nameShow != b.nameShow;

  /// 帖子页 / 吧首页下发的 anti tbs 是当前会话的权威值，账号里的 tbs
  /// 缺失或过期时用它自愈（未登录时没有账号可写，直接跳过）。
  Future<void> _absorbTbs(String tbs) async {
    if (tbs.isEmpty) return;
    final acc = store.currentAccount;
    if (acc == null || acc.bduss.isEmpty || acc.tbs == tbs) return;
    await store.saveAccount(acc.copyWith(tbs: tbs));
  }

  Future<void> opAgree({
    required int threadId,
    int postId = 0,
    required bool agree,
    int objType = 3,
  }) => _write(
    (_) => api.opAgree(
      threadId: threadId,
      postId: postId,
      opType: agree ? 0 : 1,
      objType: objType,
    ),
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
  }) => _write(
    (tbs) => collect
        ? api.addThreadStore(
            threadId: threadId,
            postId: postId,
            tbsOverride: tbs,
          )
        : api.removeThreadStore(threadId: threadId, forumId: forumId),
  );

  Future<void> reply({
    required int forumId,
    required String forumName,
    required int threadId,
    required String content,
    int? quotePostId,
    int? subPostId,
    int? replyUid,
    String? tbsOverride,
  }) => _write(
    (tbs) => api.addPost(
      forumId: forumId,
      forumName: forumName,
      threadId: threadId,
      content: content,
      nameShow: store.currentAccount?.displayName ?? '',
      quotePostId: quotePostId,
      subPostId: subPostId,
      replyUid: replyUid,
      tbsOverride: tbs,
    ),
    tbsOverride: tbsOverride,
  );

  Future<void> createThread({
    required int forumId,
    required String forumName,
    required String title,
    required String content,
    String? tbsOverride,
  }) => _write(
    (tbs) => api.addThread(
      forumId: forumId,
      forumName: forumName,
      title: title,
      content: content,
      nameShow: store.currentAccount?.displayName ?? '',
      tbsOverride: tbs,
    ),
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
  }) => _write(
    (_) => api.votePoll(
      forumId: forumId,
      threadId: threadId,
      optionIds: optionIds,
    ),
  );

  Future<void> deletePost({
    required int forumId,
    required String forumName,
    required int threadId,
    required int postId,
    bool isFloor = false,
    bool mine = true,
    String? tbsOverride,
  }) => _write(
    (tbs) => api.deletePost(
      forumId: forumId,
      forumName: forumName,
      threadId: threadId,
      postId: postId,
      isFloor: isFloor,
      mine: mine,
      tbsOverride: tbs,
    ),
    tbsOverride: tbsOverride,
  );

  Future<void> deleteThread({
    required int forumId,
    required String forumName,
    required int threadId,
    bool mine = true,
    bool hide = false,
    String? tbsOverride,
  }) => _write(
    (tbs) => api.deleteThread(
      forumId: forumId,
      forumName: forumName,
      threadId: threadId,
      mine: mine,
      hide: hide,
      tbsOverride: tbs,
    ),
    tbsOverride: tbsOverride,
  );

  Future<String> reportUrl({required int postId}) =>
      api.reportUrl(postId: postId);

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
    bool isFans = false,
  }) => isFans
      ? api.fansList(uid: uid, page: page)
      : api.followList(uid: uid, page: page);

  Future<void> toggleFollowUser({
    required String portrait,
    required bool follow,
    String? tbsOverride,
  }) => _write(
    (tbs) => api.toggleFollowUser(
      portrait: portrait,
      follow: follow,
      tbsOverride: tbs,
    ),
    tbsOverride: tbsOverride,
  );

  Future<void> modifyProfile({
    required String nickName,
    required String intro,
    required int sex,
  }) => _write(
    (_) => api.modifyProfile(nickName: nickName, intro: intro, sex: sex),
  );

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
  ///
  /// 手动粘贴往往只带 BDUSS，而贴吧的写接口（回帖 / 收藏 / 点赞…）还要 STOKEN、
  /// tbs 与 z_id，缺一项就会得到「能看不能写」的半套会话。这里先用**贴吧域名**
  /// 下的 Cookie 把缺的字段补齐（与 TiebaLite 一致：它只读 tbwise 页面的 Cookie，
  /// 免得拿到 passport / wappass 那份对写接口无效的 STOKEN），再向 `/c/s/login`
  /// 换一次 tbs，尽量落一个完整会话。
  Future<AccountRecord> loginWithCookieString(String rawCookie) async {
    final vault = CookieVault()..loadFromRaw(rawCookie);
    final bduss = vault.bduss;
    if (bduss.isEmpty) {
      throw const TiebaApiException(-1, 'Cookie 中未找到 BDUSS');
    }
    final jar = await NativeChannels.readTiebaCookies();
    final jarBduss = jar['BDUSS'] ?? '';
    if (jarBduss.isEmpty || jarBduss == bduss) {
      vault.fillMissing(jar);
    } else {
      // 罐里是另一个账号的会话，只借与账号无关的字段。
      final baiduId = jar['BAIDUID'] ?? '';
      if (baiduId.isNotEmpty) vault.fillMissing({'BAIDUID': baiduId});
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
      zid: vault.zid,
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
