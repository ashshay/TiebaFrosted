import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/html_text.dart';
import 'models.dart';

/// 主壳四个一级页面（首页 / 动态 / 消息 / 我的）的本地数据快照缓存。
///
/// 按账号隔离持久化在临时目录 `tieba_tab_cache/` 中：
/// - 启动或首次切换 Tab 时优先瞬时恢复本地快照，不主动触发网络重载；
/// - 仅在本地尚无快照时首次拉取，或在用户手动下拉刷新 / 双击底栏刷新时更新。
class TabSnapshotCache {
  TabSnapshotCache({Future<Directory?> Function()? cacheDirProvider})
    : _cacheDirProvider = cacheDirProvider;

  static final TabSnapshotCache instance = TabSnapshotCache();

  Future<Directory?> Function()? _cacheDirProvider;
  final Map<String, Map<String, dynamic>> _mem = {};
  Future<Directory?>? _dirFuture;
  int _tmpSeq = 0;

  /// 允许测试替换缓存目录提供器（传 `() async => null` 可在 Widget 测试中走纯内存模式）。
  void configureForTesting(Future<Directory?> Function()? cacheDirProvider) {
    _cacheDirProvider = cacheDirProvider;
    _dirFuture = null;
    _mem.clear();
  }

  String _key(String accountKey, String slot) {
    final safeAcc = accountKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '${safeAcc}_$slot';
  }

  Future<Map<String, dynamic>?> _readJson(String accountKey, String slot) async {
    final key = _key(accountKey, slot);
    final memHit = _mem[key];
    if (memHit != null) return memHit;
    final file = await _fileForKey(key);
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _mem[key] = decoded;
        return decoded;
      }
    } on Object {
      // 损坏快照忽略，回退网络拉取
    }
    return null;
  }

  Future<void> _writeJson(
    String accountKey,
    String slot,
    Map<String, dynamic> data,
  ) async {
    final key = _key(accountKey, slot);
    _mem[key] = data;
    final file = await _fileForKey(key);
    if (file == null) return;
    final tmp = File('${file.path}.${_tmpSeq++}.tmp');
    try {
      await tmp.writeAsString(jsonEncode(data), flush: false);
      if (await file.exists()) {
        try {
          await file.delete();
        } on Object {
          // Windows 覆盖前先删
        }
      }
      await tmp.rename(file.path);
    } on Object {
      try {
        if (await tmp.exists()) await tmp.delete();
      } on Object {
        // 忽略临时文件清理异常
      }
    }
  }

  Future<Directory?> _resolveDir() => _dirFuture ??= _initDir();

  Future<Directory?> _initDir() async {
    try {
      final provider = _cacheDirProvider;
      final base = provider != null
          ? await provider()
          : await getTemporaryDirectory();
      if (base == null) return null;
      final dir = Directory(p.join(base.path, 'tieba_tab_cache'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } on Object {
      return null;
    }
  }

  Future<File?> _fileForKey(String key) async {
    final dir = await _resolveDir();
    if (dir == null) return null;
    return File(p.join(dir.path, '$key.json'));
  }

  Future<void> clear() async {
    _mem.clear();
    final dir = await _resolveDir();
    if (dir == null || !await dir.exists()) return;
    try {
      await for (final e in dir.list(followLinks: false)) {
        if (e is File) {
          try {
            await e.delete();
          } on Object {
            // 忽略单文件清理失败
          }
        }
      }
    } on Object {
      // 忽略遍历异常
    }
  }

  // ---- 首页：关注贴吧 ----

  Future<List<FollowedForum>?> readFollowedForums(String accountKey) async {
    final json = await _readJson(accountKey, 'home_forums');
    if (json == null) return null;
    final raw = json['items'];
    if (raw is! List) return null;
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) _decodeFollowedForum(item),
    ];
  }

  Future<void> saveFollowedForums(
    String accountKey,
    List<FollowedForum> forums,
  ) => _writeJson(accountKey, 'home_forums', {
    'items': [for (final f in forums) _encodeFollowedForum(f)],
  });

  // ---- 动态：推荐 ----

  Future<List<TiebaThread>?> readFeedRec(String accountKey) async {
    final json = await _readJson(accountKey, 'feed_rec');
    if (json == null) return null;
    final raw = json['items'];
    if (raw is! List) return null;
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) _decodeThread(item),
    ];
  }

  Future<void> saveFeedRec(String accountKey, List<TiebaThread> threads) =>
      _writeJson(accountKey, 'feed_rec', {
        'items': [for (final t in threads.take(60)) _encodeThread(t)],
      });

  // ---- 动态：关注 ----

  Future<ConcernPageResult?> readFeedConcern(String accountKey) async {
    final json = await _readJson(accountKey, 'feed_concern');
    if (json == null) return null;
    final raw = json['items'];
    if (raw is! List) return null;
    return ConcernPageResult(
      threads: [
        for (final item in raw)
          if (item is Map<String, dynamic>) _decodeThread(item),
      ],
      pageTag: (json['pageTag'] ?? '').toString(),
      hasMore: json['hasMore'] == true,
      requestUnix: (json['requestUnix'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> saveFeedConcern(
    String accountKey,
    ConcernPageResult result,
  ) => _writeJson(accountKey, 'feed_concern', {
    'items': [for (final t in result.threads.take(60)) _encodeThread(t)],
    'pageTag': result.pageTag,
    'hasMore': result.hasMore,
    'requestUnix': result.requestUnix,
  });

  // ---- 动态：热榜 ----

  Future<({HotThreadPageResult data, String tabCode, String tabId})?>
  readFeedHot(String accountKey) async {
    final json = await _readJson(accountKey, 'feed_hot');
    if (json == null) return null;
    final rawTopics = json['topics'];
    final rawThreads = json['threads'];
    final rawTabs = json['tabs'];
    if (rawTopics is! List || rawThreads is! List || rawTabs is! List) {
      return null;
    }
    return (
      data: HotThreadPageResult(
        topics: [
          for (final t in rawTopics)
            if (t is Map<String, dynamic>) _decodeHotTopic(t),
        ],
        threads: [
          for (final t in rawThreads)
            if (t is Map<String, dynamic>) _decodeThread(t),
        ],
        tabs: [
          for (final t in rawTabs)
            if (t is Map<String, dynamic>) _decodeForumTab(t),
        ],
      ),
      tabCode: (json['tabCode'] ?? 'all').toString(),
      tabId: (json['tabId'] ?? '1').toString(),
    );
  }

  Future<void> saveFeedHot(
    String accountKey, {
    required HotThreadPageResult data,
    required String tabCode,
    required String tabId,
  }) => _writeJson(accountKey, 'feed_hot', {
    'topics': [for (final t in data.topics) _encodeHotTopic(t)],
    'threads': [for (final t in data.threads.take(60)) _encodeThread(t)],
    'tabs': [for (final t in data.tabs) _encodeForumTab(t)],
    'tabCode': tabCode,
    'tabId': tabId,
  });

  // ---- 消息：回复我 / @提到 ----

  Future<({List<NotificationItem> items, bool hasMore})?> readNotifications(
    String accountKey, {
    required int tab,
  }) async {
    final json = await _readJson(accountKey, tab == 0 ? 'msg_reply' : 'msg_at');
    if (json == null) return null;
    final raw = json['items'];
    if (raw is! List) return null;
    return (
      items: [
        for (final item in raw)
          if (item is Map<String, dynamic>) _decodeNotification(item),
      ],
      hasMore: json['hasMore'] == true,
    );
  }

  Future<void> saveNotifications(
    String accountKey, {
    required int tab,
    required List<NotificationItem> items,
    required bool hasMore,
  }) => _writeJson(accountKey, tab == 0 ? 'msg_reply' : 'msg_at', {
    'items': [for (final n in items.take(50)) _encodeNotification(n)],
    'hasMore': hasMore,
  });

  // ---- 我的：个人资料 ----

  Future<TiebaUser?> readMeProfile(String accountKey) async {
    final json = await _readJson(accountKey, 'me_profile');
    if (json == null) return null;
    final user = json['user'];
    if (user is! Map<String, dynamic>) return null;
    return _decodeUser(user);
  }

  Future<void> saveMeProfile(String accountKey, TiebaUser user) =>
      _writeJson(accountKey, 'me_profile', {'user': _encodeUser(user)});
}

// =============================================================================
// 轻量 JSON 编解码
// =============================================================================

int _intOf(Map<String, dynamic> m, String key) => (m[key] as num?)?.toInt() ?? 0;
String _strOf(Map<String, dynamic> m, String key) => (m[key] ?? '').toString();
bool _boolOf(Map<String, dynamic> m, String key) => m[key] == true;

Map<String, dynamic> _encodeFollowedForum(FollowedForum f) => {
  'forumId': f.forumId,
  'forumName': f.forumName,
  'avatar': f.avatar,
  'levelId': f.levelId,
  'levelName': f.levelName,
  'isSign': f.isSign,
  'hotNum': f.hotNum,
  'curScore': f.curScore,
  'levelUpScore': f.levelUpScore,
};

FollowedForum _decodeFollowedForum(Map<String, dynamic> m) => FollowedForum(
  forumId: _intOf(m, 'forumId'),
  forumName: _strOf(m, 'forumName'),
  avatar: _strOf(m, 'avatar'),
  levelId: _intOf(m, 'levelId'),
  levelName: _strOf(m, 'levelName'),
  isSign: _boolOf(m, 'isSign'),
  hotNum: _intOf(m, 'hotNum'),
  curScore: _intOf(m, 'curScore'),
  levelUpScore: _intOf(m, 'levelUpScore'),
);

Map<String, dynamic> _encodeUser(TiebaUser u) => {
  'id': u.id,
  'name': u.name,
  'nameShow': u.nameShow,
  'portrait': u.portrait,
  'levelId': u.levelId,
  'levelName': u.levelName,
  'isBawu': u.isBawu,
  'bawuType': u.bawuType,
  'ipAddress': u.ipAddress,
  'tiebaUid': u.tiebaUid,
  'sex': u.sex,
  'intro': u.intro,
  'fansNum': u.fansNum,
  'concernNum': u.concernNum,
  'postNum': u.postNum,
  'threadNum': u.threadNum,
  'myLikeNum': u.myLikeNum,
  'totalAgreeNum': u.totalAgreeNum,
  'hasConcerned': u.hasConcerned,
  'isFans': u.isFans,
  'tbAge': u.tbAge,
  'bgPic': u.bgPic,
  'isDefaultAvatar': u.isDefaultAvatar,
};

TiebaUser _decodeUser(Map<String, dynamic> m) => TiebaUser(
  id: _intOf(m, 'id'),
  name: _strOf(m, 'name'),
  nameShow: _strOf(m, 'nameShow'),
  portrait: _strOf(m, 'portrait'),
  levelId: _intOf(m, 'levelId'),
  levelName: _strOf(m, 'levelName'),
  isBawu: _boolOf(m, 'isBawu'),
  bawuType: _strOf(m, 'bawuType'),
  ipAddress: _strOf(m, 'ipAddress'),
  tiebaUid: _strOf(m, 'tiebaUid'),
  sex: _intOf(m, 'sex'),
  intro: _strOf(m, 'intro'),
  fansNum: _intOf(m, 'fansNum'),
  concernNum: _intOf(m, 'concernNum'),
  postNum: _intOf(m, 'postNum'),
  threadNum: _intOf(m, 'threadNum'),
  myLikeNum: _intOf(m, 'myLikeNum'),
  totalAgreeNum: _intOf(m, 'totalAgreeNum'),
  hasConcerned: _boolOf(m, 'hasConcerned'),
  isFans: _boolOf(m, 'isFans'),
  tbAge: _strOf(m, 'tbAge'),
  bgPic: _strOf(m, 'bgPic'),
  isDefaultAvatar: _boolOf(m, 'isDefaultAvatar'),
);

Map<String, dynamic> _encodeThread(TiebaThread t) => {
  'id': t.id,
  'threadId': t.threadId,
  'title': t.title,
  'abstractText': t.abstractText,
  'images': [
    for (final img in t.images)
      {
        'url': img.url,
        'originUrl': img.originUrl,
        'width': img.width,
        'height': img.height,
        'originSize': img.originSize,
        'showOriginal': img.showOriginal,
      },
  ],
  if (t.video != null)
    'video': {
      'md5': t.video!.md5,
      'videoUrl': t.video!.videoUrl,
      'duration': t.video!.duration,
      'width': t.video!.width,
      'height': t.video!.height,
      'thumbnailUrl': t.video!.thumbnailUrl,
      'thumbnailWidth': t.video!.thumbnailWidth,
      'thumbnailHeight': t.video!.thumbnailHeight,
    },
  'author': _encodeUser(t.author),
  'authorId': t.authorId,
  'forumId': t.forumId,
  'forumName': t.forumName,
  'forumAvatar': t.forumAvatar,
  'replyNum': t.replyNum,
  'viewNum': t.viewNum,
  'shareNum': t.shareNum,
  'agree': {
    'agreeNum': t.agree.agreeNum,
    'disagreeNum': t.agree.disagreeNum,
    'diffAgreeNum': t.agree.diffAgreeNum,
    'hasAgree': t.agree.hasAgree,
    'agreeType': t.agree.agreeType,
  },
  'createTime': t.createTime,
  'lastTimeInt': t.lastTimeInt,
  'lastTimeStr': t.lastTimeStr,
  'isTop': t.isTop,
  'isGood': t.isGood,
  'isNoTitle': t.isNoTitle,
  'firstPostId': t.firstPostId,
  'pids': t.pids,
  'collectStatus': t.collectStatus,
  'isLive': t.isLive,
  'hotNum': t.hotNum,
};

TiebaThread _decodeThread(Map<String, dynamic> m) {
  final rawImages = m['images'];
  final rawVideo = m['video'];
  final rawAuthor = m['author'];
  final rawAgree = m['agree'];
  return TiebaThread(
    id: _intOf(m, 'id'),
    threadId: _intOf(m, 'threadId'),
    title: _strOf(m, 'title'),
    abstractText: _strOf(m, 'abstractText'),
    images: [
      if (rawImages is List)
        for (final img in rawImages)
          if (img is Map<String, dynamic>)
            RichImageNode(
              url: _strOf(img, 'url'),
              originUrl: _strOf(img, 'originUrl'),
              width: _intOf(img, 'width'),
              height: _intOf(img, 'height'),
              originSize: _intOf(img, 'originSize'),
              showOriginal: _boolOf(img, 'showOriginal'),
            ),
    ],
    video: rawVideo is Map<String, dynamic>
        ? TiebaVideo(
            md5: _strOf(rawVideo, 'md5'),
            videoUrl: _strOf(rawVideo, 'videoUrl'),
            duration: _intOf(rawVideo, 'duration'),
            width: _intOf(rawVideo, 'width'),
            height: _intOf(rawVideo, 'height'),
            thumbnailUrl: _strOf(rawVideo, 'thumbnailUrl'),
            thumbnailWidth: _intOf(rawVideo, 'thumbnailWidth'),
            thumbnailHeight: _intOf(rawVideo, 'thumbnailHeight'),
          )
        : null,
    author: rawAuthor is Map<String, dynamic>
        ? _decodeUser(rawAuthor)
        : const TiebaUser(),
    authorId: _intOf(m, 'authorId'),
    forumId: _intOf(m, 'forumId'),
    forumName: _strOf(m, 'forumName'),
    forumAvatar: _strOf(m, 'forumAvatar'),
    replyNum: _intOf(m, 'replyNum'),
    viewNum: _intOf(m, 'viewNum'),
    shareNum: _intOf(m, 'shareNum'),
    agree: rawAgree is Map<String, dynamic>
        ? TiebaAgree(
            agreeNum: _intOf(rawAgree, 'agreeNum'),
            disagreeNum: _intOf(rawAgree, 'disagreeNum'),
            diffAgreeNum: _intOf(rawAgree, 'diffAgreeNum'),
            hasAgree: _intOf(rawAgree, 'hasAgree'),
            agreeType: _intOf(rawAgree, 'agreeType'),
          )
        : const TiebaAgree(),
    createTime: _intOf(m, 'createTime'),
    lastTimeInt: _intOf(m, 'lastTimeInt'),
    lastTimeStr: _strOf(m, 'lastTimeStr'),
    isTop: _boolOf(m, 'isTop'),
    isGood: _boolOf(m, 'isGood'),
    isNoTitle: _boolOf(m, 'isNoTitle'),
    firstPostId: _intOf(m, 'firstPostId'),
    pids: _strOf(m, 'pids'),
    collectStatus: _intOf(m, 'collectStatus'),
    isLive: _boolOf(m, 'isLive'),
    hotNum: _intOf(m, 'hotNum'),
  );
}

Map<String, dynamic> _encodeHotTopic(HotTopicItem t) => {
  'topicId': t.topicId,
  'topicName': t.topicName,
  'topicDesc': t.topicDesc,
  'discussNum': t.discussNum,
  'tag': t.tag,
  'topicPic': t.topicPic,
  'h5Url': t.h5Url,
};

HotTopicItem _decodeHotTopic(Map<String, dynamic> m) => HotTopicItem(
  topicId: _intOf(m, 'topicId'),
  topicName: _strOf(m, 'topicName'),
  topicDesc: _strOf(m, 'topicDesc'),
  discussNum: _intOf(m, 'discussNum'),
  tag: _intOf(m, 'tag'),
  topicPic: _strOf(m, 'topicPic'),
  h5Url: _strOf(m, 'h5Url'),
);

Map<String, dynamic> _encodeForumTab(ForumTab t) => {
  'tabId': t.tabId,
  'tabType': t.tabType,
  'tabName': t.tabName,
  'tabCode': t.tabCode,
  'isGeneralTab': t.isGeneralTab,
  'isDefault': t.isDefault,
};

ForumTab _decodeForumTab(Map<String, dynamic> m) => ForumTab(
  tabId: _intOf(m, 'tabId'),
  tabType: _intOf(m, 'tabType'),
  tabName: _strOf(m, 'tabName'),
  tabCode: _strOf(m, 'tabCode'),
  isGeneralTab: _boolOf(m, 'isGeneralTab'),
  isDefault: _boolOf(m, 'isDefault'),
);

Map<String, dynamic> _encodeNotification(NotificationItem n) => {
  'threadId': n.threadId,
  'postId': n.postId,
  'title': n.title,
  'content': n.content,
  'quoteContent': n.quoteContent,
  'forumName': n.forumName,
  'userName': n.userName,
  'userPortrait': n.userPortrait,
  'userId': n.userId,
  'time': n.time,
  'isFloor': n.isFloor,
};

NotificationItem _decodeNotification(Map<String, dynamic> m) =>
    NotificationItem(
      threadId: _intOf(m, 'threadId'),
      postId: _intOf(m, 'postId'),
      title: _strOf(m, 'title'),
      content: _strOf(m, 'content'),
      quoteContent: _strOf(m, 'quoteContent'),
      forumName: _strOf(m, 'forumName'),
      userName: _strOf(m, 'userName'),
      userPortrait: _strOf(m, 'userPortrait'),
      userId: _intOf(m, 'userId'),
      time: _intOf(m, 'time'),
      isFloor: _boolOf(m, 'isFloor'),
    );
