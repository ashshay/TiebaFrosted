import '../core/html_text.dart';
import 'json.dart';

class TiebaApiException implements Exception {
  const TiebaApiException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => message.isNotEmpty ? message : '贴吧接口错误 ($code)';
}

class TiebaUser {
  const TiebaUser({
    this.id = 0,
    this.name = '',
    this.nameShow = '',
    this.portrait = '',
    this.levelId = 0,
    this.levelName = '',
    this.isBawu = false,
    this.bawuType = '',
    this.ipAddress = '',
    this.tiebaUid = '',
    this.sex = 0,
    this.intro = '',
    this.fansNum = 0,
    this.concernNum = 0,
    this.postNum = 0,
    this.threadNum = 0,
    this.myLikeNum = 0,
    this.totalAgreeNum = 0,
    this.hasConcerned = false,
    this.isFans = false,
    this.tbAge = '',
    this.bgPic = '',
    this.isDefaultAvatar = false,
  });

  final int id;
  final String name;
  final String nameShow;
  final String portrait;
  final int levelId;
  final String levelName;
  final bool isBawu;
  final String bawuType;
  final String ipAddress;
  final String tiebaUid;
  final int sex;
  final String intro;
  final int fansNum;
  final int concernNum;
  final int postNum;
  final int threadNum;
  final int myLikeNum;
  final int totalAgreeNum;
  final bool hasConcerned;
  final bool isFans;
  final String tbAge;
  final String bgPic;
  final bool isDefaultAvatar;

  String get displayName =>
      nameShow.isNotEmpty ? nameShow : (name.isNotEmpty ? name : '贴吧用户');

  TiebaUser copyWith({
    bool? hasConcerned,
    int? fansNum,
    String? intro,
    String? nameShow,
    int? sex,
  }) => TiebaUser(
    id: id,
    name: name,
    nameShow: nameShow ?? this.nameShow,
    portrait: portrait,
    levelId: levelId,
    levelName: levelName,
    isBawu: isBawu,
    bawuType: bawuType,
    ipAddress: ipAddress,
    tiebaUid: tiebaUid,
    sex: sex ?? this.sex,
    intro: intro ?? this.intro,
    fansNum: fansNum ?? this.fansNum,
    concernNum: concernNum,
    postNum: postNum,
    threadNum: threadNum,
    myLikeNum: myLikeNum,
    totalAgreeNum: totalAgreeNum,
    hasConcerned: hasConcerned ?? this.hasConcerned,
    isFans: isFans,
    tbAge: tbAge,
    bgPic: bgPic,
    isDefaultAvatar: isDefaultAvatar,
  );

  factory TiebaUser.fromJson(Map<String, dynamic> j) => TiebaUser(
    id: j.intOf('id', j.intOf('uid')),
    name: j.str('name', j.str('user_name')),
    nameShow: j.str('name_show', j.str('show_nickname', j.str('nickname'))),
    portrait: j.str('portrait'),
    levelId: j.intOf('level_id'),
    levelName: j.str('level_name'),
    isBawu: j.boolean('is_bawu'),
    bawuType: j.str('bawu_type'),
    ipAddress: j.str('ip_address'),
    tiebaUid: j.str('tieba_uid'),
    sex: j.intOf('sex', j.intOf('gender')),
    intro: j.str('intro'),
    fansNum: j.count('fans_num'),
    concernNum: j.count('concern_num'),
    postNum: j.count('post_num'),
    threadNum: j.count('thread_num'),
    myLikeNum: j.count('my_like_num'),
    totalAgreeNum: j.count('total_agree_num'),
    hasConcerned: j.boolean('has_concerned', j.boolean('is_followed')),
    isFans: j.boolean('is_fans'),
    tbAge: j.str('tb_age'),
    bgPic: j.str('bg_pic'),
  );
}

class TiebaAgree {
  const TiebaAgree({
    this.agreeNum = 0,
    this.disagreeNum = 0,
    this.diffAgreeNum = 0,
    this.hasAgree = 0,
    this.agreeType = 0,
  });

  final int agreeNum;
  final int disagreeNum;
  final int diffAgreeNum;
  final int hasAgree; // 1 = agreed, 2 = disagreed, 0 = none
  final int agreeType;

  bool get isAgreed => hasAgree == 1;
  int get displayCount => agreeNum > 0 ? agreeNum : (diffAgreeNum > 0 ? diffAgreeNum : 0);

  TiebaAgree toggleAgree() {
    final nextAgreed = !isAgreed;
    final delta = nextAgreed ? 1 : -1;
    return TiebaAgree(
      agreeNum: (agreeNum + delta).clamp(0, 1 << 30),
      disagreeNum: disagreeNum,
      diffAgreeNum: diffAgreeNum + delta,
      hasAgree: nextAgreed ? 1 : 0,
      agreeType: agreeType,
    );
  }
}

class TiebaVideo {
  const TiebaVideo({
    this.md5 = '',
    this.videoUrl = '',
    this.duration = 0,
    this.width = 0,
    this.height = 0,
    this.thumbnailUrl = '',
    this.thumbnailWidth = 0,
    this.thumbnailHeight = 0,
  });

  final String md5;
  final String videoUrl;
  final int duration;
  final int width;
  final int height;
  final String thumbnailUrl;
  final int thumbnailWidth;
  final int thumbnailHeight;

  bool get isValid => videoUrl.isNotEmpty || thumbnailUrl.isNotEmpty;
}

class TiebaPollOption {
  const TiebaPollOption({
    required this.id,
    required this.text,
    this.num = 0,
    this.image = '',
  });

  final int id;
  final String text;
  final int num;
  final String image;
}

class TiebaPoll {
  const TiebaPoll({
    this.type = 0,
    this.isMulti = false,
    this.totalNum = 0,
    this.totalPoll = 0,
    this.isPolled = false,
    this.polledValue = '',
    this.tips = '',
    this.title = '',
    this.endTime = 0,
    this.status = 0,
    this.options = const [],
  });

  final int type;
  final bool isMulti;
  final int totalNum;
  final int totalPoll;
  final bool isPolled;
  final String polledValue;
  final String tips;
  final String title;
  final int endTime;
  final int status;
  final List<TiebaPollOption> options;
}

class TiebaPageInfo {
  const TiebaPageInfo({
    this.pageSize = 30,
    this.offset = 0,
    this.currentPage = 1,
    this.totalCount = 0,
    this.totalPage = 1,
    this.hasMore = false,
    this.hasPrev = false,
    this.newTotalPage = 0,
  });

  final int pageSize;
  final int offset;
  final int currentPage;
  final int totalCount;
  final int totalPage;
  final bool hasMore;
  final bool hasPrev;
  final int newTotalPage;

  int get effectiveTotalPage => newTotalPage > 0 ? newTotalPage : totalPage;
}

class ForumClassify {
  const ForumClassify({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;
}

class ForumTab {
  const ForumTab({
    required this.tabId,
    required this.tabType,
    required this.tabName,
    this.tabCode = '',
    this.isGeneralTab = false,
    this.isDefault = false,
  });

  final int tabId;
  final int tabType;
  final String tabName;
  final String tabCode;
  final bool isGeneralTab;
  final bool isDefault;
}

class TiebaForum {
  const TiebaForum({
    this.id = 0,
    this.name = '',
    this.avatar = '',
    this.slogan = '',
    this.firstClass = '',
    this.secondClass = '',
    this.isLike = false,
    this.isSign = false,
    this.userLevel = 0,
    this.levelName = '',
    this.memberNum = 0,
    this.threadNum = 0,
    this.postNum = 0,
    this.curScore = 0,
    this.levelUpScore = 0,
    this.contSignNum = 0,
    this.signRank = 0,
    this.goodClassifies = const [],
  });

  final int id;
  final String name;
  final String avatar;
  final String slogan;
  final String firstClass;
  final String secondClass;
  final bool isLike;
  final bool isSign;
  final int userLevel;
  final String levelName;
  final int memberNum;
  final int threadNum;
  final int postNum;
  final int curScore;
  final int levelUpScore;
  final int contSignNum;
  final int signRank;
  final List<ForumClassify> goodClassifies;

  TiebaForum copyWith({
    bool? isLike,
    bool? isSign,
    int? userLevel,
    int? memberNum,
    int? curScore,
    int? contSignNum,
    int? signRank,
  }) => TiebaForum(
    id: id,
    name: name,
    avatar: avatar,
    slogan: slogan,
    firstClass: firstClass,
    secondClass: secondClass,
    isLike: isLike ?? this.isLike,
    isSign: isSign ?? this.isSign,
    userLevel: userLevel ?? this.userLevel,
    levelName: levelName,
    memberNum: memberNum ?? this.memberNum,
    threadNum: threadNum,
    postNum: postNum,
    curScore: curScore ?? this.curScore,
    levelUpScore: levelUpScore,
    contSignNum: contSignNum ?? this.contSignNum,
    signRank: signRank ?? this.signRank,
    goodClassifies: goodClassifies,
  );
}

class FollowedForum {
  const FollowedForum({
    required this.forumId,
    required this.forumName,
    this.avatar = '',
    this.levelId = 0,
    this.levelName = '',
    this.isSign = false,
    this.hotNum = 0,
    this.curScore = 0,
    this.levelUpScore = 0,
  });

  final int forumId;
  final String forumName;
  final String avatar;
  final int levelId;
  final String levelName;
  final bool isSign;
  final int hotNum;
  final int curScore;
  final int levelUpScore;

  FollowedForum copyWith({bool? isSign}) => FollowedForum(
    forumId: forumId,
    forumName: forumName,
    avatar: avatar,
    levelId: levelId,
    levelName: levelName,
    isSign: isSign ?? this.isSign,
    hotNum: hotNum,
    curScore: curScore,
    levelUpScore: levelUpScore,
  );

  factory FollowedForum.fromJson(Map<String, dynamic> j) => FollowedForum(
    forumId: j.intOf('forum_id', j.intOf('id')),
    forumName: j.str('forum_name', j.str('name')),
    avatar: j.str('avatar'),
    levelId: j.intOf('level_id'),
    levelName: j.str('level_name'),
    isSign: j.boolean('is_sign'),
    hotNum: j.count('hot_num'),
    curScore: j.intOf('cur_score'),
    levelUpScore: j.intOf('levelup_score'),
  );
}

class TiebaThread {
  const TiebaThread({
    required this.id,
    this.threadId = 0,
    this.title = '',
    this.abstractText = '',
    this.richTitle = const [],
    this.richAbstract = const [],
    this.images = const [],
    this.video,
    this.poll,
    this.author = const TiebaUser(),
    this.authorId = 0,
    this.forumId = 0,
    this.forumName = '',
    this.forumAvatar = '',
    this.replyNum = 0,
    this.viewNum = 0,
    this.shareNum = 0,
    this.agree = const TiebaAgree(),
    this.createTime = 0,
    this.lastTimeInt = 0,
    this.lastTimeStr = '',
    this.isTop = false,
    this.isGood = false,
    this.isNoTitle = false,
    this.firstPostId = 0,
    this.pids = '',
    this.collectStatus = 0,
    this.isLive = false,
    this.hotNum = 0,
  });

  final int id;
  final int threadId;
  final String title;
  final String abstractText;
  final List<TiebaRichNode> richTitle;
  final List<TiebaRichNode> richAbstract;
  final List<RichImageNode> images;
  final TiebaVideo? video;
  final TiebaPoll? poll;
  final TiebaUser author;
  final int authorId;
  final int forumId;
  final String forumName;
  final String forumAvatar;
  final int replyNum;
  final int viewNum;
  final int shareNum;
  final TiebaAgree agree;
  final int createTime;
  final int lastTimeInt;
  final String lastTimeStr;
  final bool isTop;
  final bool isGood;
  final bool isNoTitle;
  final int firstPostId;
  final String pids;
  final int collectStatus;
  final bool isLive;
  final int hotNum;

  int get effectiveId => threadId > 0 ? threadId : id;
  bool get isCollected => collectStatus != 0;

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (abstractText.trim().isNotEmpty) return abstractText.trim();
    final text = richTitle
        .whereType<RichTextNode>()
        .map((e) => e.text)
        .join()
        .trim();
    if (text.isNotEmpty) return text;
    return richAbstract
        .whereType<RichTextNode>()
        .map((e) => e.text)
        .join()
        .trim();
  }

  TiebaThread copyWith({
    TiebaUser? author,
    TiebaAgree? agree,
    int? collectStatus,
    int? replyNum,
  }) => TiebaThread(
    id: id,
    threadId: threadId,
    title: title,
    abstractText: abstractText,
    richTitle: richTitle,
    richAbstract: richAbstract,
    images: images,
    video: video,
    poll: poll,
    author: author ?? this.author,
    authorId: authorId,
    forumId: forumId,
    forumName: forumName,
    forumAvatar: forumAvatar,
    replyNum: replyNum ?? this.replyNum,
    viewNum: viewNum,
    shareNum: shareNum,
    agree: agree ?? this.agree,
    createTime: createTime,
    lastTimeInt: lastTimeInt,
    lastTimeStr: lastTimeStr,
    isTop: isTop,
    isGood: isGood,
    isNoTitle: isNoTitle,
    firstPostId: firstPostId,
    pids: pids,
    collectStatus: collectStatus ?? this.collectStatus,
    isLive: isLive,
    hotNum: hotNum,
  );
}

class TiebaSubPost {
  const TiebaSubPost({
    required this.id,
    this.content = const [],
    this.time = 0,
    this.authorId = 0,
    this.author = const TiebaUser(),
    this.agree = const TiebaAgree(),
  });

  final int id;
  final List<TiebaRichNode> content;
  final int time;
  final int authorId;
  final TiebaUser author;
  final TiebaAgree agree;

  TiebaSubPost copyWith({
    TiebaUser? author,
    TiebaAgree? agree,
  }) => TiebaSubPost(
    id: id,
    content: content,
    time: time,
    authorId: authorId,
    author: author ?? this.author,
    agree: agree ?? this.agree,
  );
}

class TiebaPost {
  const TiebaPost({
    required this.id,
    this.title = '',
    this.floor = 0,
    this.time = 0,
    this.content = const [],
    this.subPostNumber = 0,
    this.subPosts = const [],
    this.authorId = 0,
    this.author = const TiebaUser(),
    this.agree = const TiebaAgree(),
    this.isFold = false,
    this.foldTip = '',
    this.isHotPost = false,
  });

  final int id;
  final String title;
  final int floor;
  final int time;
  final List<TiebaRichNode> content;
  final int subPostNumber;
  final List<TiebaSubPost> subPosts;
  final int authorId;
  final TiebaUser author;
  final TiebaAgree agree;
  final bool isFold;
  final String foldTip;
  final bool isHotPost;

  TiebaPost copyWith({
    TiebaUser? author,
    TiebaAgree? agree,
    List<TiebaSubPost>? subPosts,
    int? subPostNumber,
  }) => TiebaPost(
    id: id,
    title: title,
    floor: floor,
    time: time,
    content: content,
    subPostNumber: subPostNumber ?? this.subPostNumber,
    subPosts: subPosts ?? this.subPosts,
    authorId: authorId,
    author: author ?? this.author,
    agree: agree ?? this.agree,
    isFold: isFold,
    foldTip: foldTip,
    isHotPost: isHotPost,
  );
}

class TiebaSortOption {
  const TiebaSortOption({required this.sortType, required this.sortName});

  final int sortType;
  final String sortName;
}

class ThreadPageResult {
  const ThreadPageResult({
    required this.thread,
    required this.forum,
    required this.page,
    this.firstFloorPost,
    this.posts = const [],
    this.sortOptions = const [],
    this.sortType = 0,
    this.tbs = '',
    this.hasFloor = false,
  });

  final TiebaThread thread;
  final TiebaForum forum;
  final TiebaPageInfo page;
  final TiebaPost? firstFloorPost;
  final List<TiebaPost> posts;
  final List<TiebaSortOption> sortOptions;
  final int sortType;
  final String tbs;
  final bool hasFloor;
}

class SubPostsPageResult {
  const SubPostsPageResult({
    required this.page,
    this.post,
    this.subPosts = const [],
    this.thread,
    this.forum,
    this.tbs = '',
  });

  final TiebaPageInfo page;
  final TiebaPost? post;
  final List<TiebaSubPost> subPosts;
  final TiebaThread? thread;
  final TiebaForum? forum;
  final String tbs;
}

class ForumPageResult {
  const ForumPageResult({
    required this.forum,
    required this.page,
    this.threads = const [],
    this.threadIds = const [],
    this.tabs = const [],
    this.tbs = '',
  });

  final TiebaForum forum;
  final TiebaPageInfo page;
  final List<TiebaThread> threads;
  final List<int> threadIds;
  final List<ForumTab> tabs;
  final String tbs;
}

class PersonalizedPageResult {
  const PersonalizedPageResult({this.threads = const []});
  final List<TiebaThread> threads;
}

class ConcernPageResult {
  const ConcernPageResult({
    this.threads = const [],
    this.pageTag = '',
    this.hasMore = false,
    this.requestUnix = 0,
  });

  final List<TiebaThread> threads;
  final String pageTag;
  final bool hasMore;
  final int requestUnix;
}

class HotTopicItem {
  const HotTopicItem({
    required this.topicId,
    required this.topicName,
    this.topicDesc = '',
    this.discussNum = 0,
    this.tag = 0,
    this.topicPic = '',
    this.h5Url = '',
  });

  final int topicId;
  final String topicName;
  final String topicDesc;
  final int discussNum;
  final int tag;
  final String topicPic;
  final String h5Url;
}

class HotThreadPageResult {
  const HotThreadPageResult({
    this.topics = const [],
    this.threads = const [],
    this.tabs = const [],
  });

  final List<HotTopicItem> topics;
  final List<TiebaThread> threads;
  final List<ForumTab> tabs;
}

class HotTopicDetailResult {
  const HotTopicDetailResult({
    required this.topicId,
    required this.topicName,
    this.topicDesc = '',
    this.topicImage = '',
    this.discussNum = 0,
    this.threads = const [],
    this.hasMore = false,
  });

  final int topicId;
  final String topicName;
  final String topicDesc;
  final String topicImage;
  final int discussNum;
  final List<TiebaThread> threads;
  final bool hasMore;
}

class UserPostItem {
  const UserPostItem({
    required this.forumId,
    required this.threadId,
    required this.postId,
    this.isThread = true,
    this.createTime = 0,
    this.forumName = '',
    this.title = '',
    this.abstractText = '',
    this.userName = '',
    this.nameShow = '',
    this.userId = 0,
    this.userPortrait = '',
    this.replyNum = 0,
    this.agreeNum = 0,
    this.images = const [],
  });

  final int forumId;
  final int threadId;
  final int postId;
  final bool isThread;
  final int createTime;
  final String forumName;
  final String title;
  final String abstractText;
  final String userName;
  final String nameShow;
  final int userId;
  final String userPortrait;
  final int replyNum;
  final int agreeNum;
  final List<RichImageNode> images;
}

class UserProfileResult {
  const UserProfileResult({
    required this.user,
    this.tbs = '',
    this.posts = const [],
  });

  final TiebaUser user;
  final String tbs;
  final List<UserPostItem> posts;
}

class ForumDetailInfo {
  const ForumDetailInfo({
    required this.forumId,
    required this.forumName,
    this.avatar = '',
    this.slogan = '',
    this.memberCount = 0,
    this.threadCount = 0,
    this.isLike = false,
    this.lv1Name = '',
    this.lv2Name = '',
    this.intro = '',
  });

  final int forumId;
  final String forumName;
  final String avatar;
  final String slogan;
  final int memberCount;
  final int threadCount;
  final bool isLike;
  final String lv1Name;
  final String lv2Name;
  final String intro;
}

class ForumRuleEntry {
  const ForumRuleEntry({required this.title, required this.content});

  final String title;
  final List<TiebaRichNode> content;
}

class ForumRuleDetailInfo {
  const ForumRuleDetailInfo({
    this.title = '',
    this.preface = '',
    this.publishTime = '',
    this.rules = const [],
  });

  final String title;
  final String preface;
  final String publishTime;
  final List<ForumRuleEntry> rules;
}

class SearchSugResult {
  const SearchSugResult({
    this.suggestions = const [],
    this.forumCard,
  });

  final List<String> suggestions;
  final SearchForumItem? forumCard;
}

class SearchForumItem {
  const SearchForumItem({
    required this.forumId,
    required this.forumName,
    this.avatar = '',
    this.slogan = '',
    this.concernNum = '',
    this.postNum = '',
    this.isLiked = false,
  });

  final int forumId;
  final String forumName;
  final String avatar;
  final String slogan;
  final String concernNum;
  final String postNum;
  final bool isLiked;

  factory SearchForumItem.fromJson(Map<String, dynamic> j) => SearchForumItem(
    forumId: j.intOf('forum_id', j.intOf('id')),
    forumName: j.str('forum_name', j.str('forum_name_show', j.str('name'))),
    avatar: j.str('avatar'),
    slogan: j.str('slogan', j.str('intro')),
    concernNum: j.str('concern_num', j.str('concern_num_ori')),
    postNum: j.str('post_num', j.str('post_num_ori')),
    isLiked: j.boolean('has_concerned', j.boolean('is_like')),
  );
}

class SearchThreadItem {
  const SearchThreadItem({
    required this.threadId,
    this.postId = 0,
    required this.title,
    this.content = '',
    this.forumName = '',
    this.forumId = 0,
    this.authorName = '',
    this.authorPortrait = '',
    this.authorId = 0,
    this.time = 0,
    this.replyNum = 0,
    this.agreeNum = 0,
  });

  final int threadId;
  final int postId;
  final String title;
  final String content;
  final String forumName;
  final int forumId;
  final String authorName;
  final String authorPortrait;
  final int authorId;
  final int time;
  final int replyNum;
  final int agreeNum;

  factory SearchThreadItem.fromJson(Map<String, dynamic> j) {
    final user = j.obj('user');
    final forum = j.obj('forum_info');
    return SearchThreadItem(
      threadId: j.intOf('tid', j.intOf('thread_id')),
      postId: j.intOf('pid', j.intOf('post_id')),
      title: _stripEm(j.str('title')),
      content: _stripEm(j.str('content')),
      forumName: j.str('fname', forum?.str('forum_name') ?? ''),
      forumId: j.intOf('fid', forum?.intOf('forum_id') ?? 0),
      authorName: user?.str('user_nickname', user.str('user_name')) ??
          j.str('author_name'),
      authorPortrait: user?.str('portrait') ?? '',
      authorId: user?.intOf('user_id') ?? 0,
      time: j.intOf('time'),
      replyNum: j.count('post_num', j.count('reply_num')),
      agreeNum: j.count('like_num', j.count('agree_num')),
    );
  }
}

class SearchUserItem {
  const SearchUserItem({
    required this.uid,
    required this.name,
    this.showNickname = '',
    this.portrait = '',
    this.intro = '',
    this.fansNum = '',
  });

  final int uid;
  final String name;
  final String showNickname;
  final String portrait;
  final String intro;
  final String fansNum;

  String get displayName => showNickname.isNotEmpty ? showNickname : name;

  factory SearchUserItem.fromJson(Map<String, dynamic> j) => SearchUserItem(
    uid: j.intOf('id', j.intOf('user_id')),
    name: j.str('name', j.str('user_name')),
    showNickname: j.str('show_nickname', j.str('name_show')),
    portrait: j.str('portrait', j.str('user_portrait')),
    intro: j.str('intro'),
    fansNum: j.str('fans_num'),
  );
}

class NotificationItem {
  const NotificationItem({
    required this.threadId,
    required this.postId,
    required this.title,
    required this.content,
    this.quoteContent = '',
    this.forumName = '',
    this.userName = '',
    this.userPortrait = '',
    this.userId = 0,
    this.time = 0,
    this.isFloor = false,
  });

  final int threadId;
  final int postId;
  final String title;
  final String content;
  final String quoteContent;
  final String forumName;
  final String userName;
  final String userPortrait;
  final int userId;
  final int time;
  final bool isFloor;

  factory NotificationItem.fromJson(Map<String, dynamic> j) {
    final replyer = j.obj('replyer');
    return NotificationItem(
      threadId: j.intOf('thread_id'),
      postId: j.intOf('post_id'),
      title: j.str('title'),
      content: j.str('content'),
      quoteContent: j.str('quote_content'),
      forumName: j.str('fname'),
      userName: replyer?.str('name_show', replyer.str('name')) ?? '',
      userPortrait: replyer?.str('portrait') ?? '',
      userId: replyer?.intOf('id') ?? 0,
      time: j.intOf('time'),
      isFloor: j.boolean('is_floor'),
    );
  }
}

class ThreadStoreItem {
  const ThreadStoreItem({
    required this.threadId,
    required this.title,
    this.forumName = '',
    this.authorName = '',
    this.authorPortrait = '',
    this.markPid = 0,
    this.isDeleted = false,
    this.count = 0,
  });

  final int threadId;
  final String title;
  final String forumName;
  final String authorName;
  final String authorPortrait;
  final int markPid;
  final bool isDeleted;
  final int count;

  factory ThreadStoreItem.fromJson(Map<String, dynamic> j) {
    final author = j.obj('author');
    return ThreadStoreItem(
      threadId: j.intOf('thread_id'),
      title: j.str('title'),
      forumName: j.str('forum_name'),
      authorName: author?.str('name_show', author.str('name')) ?? '',
      authorPortrait: author?.str('user_portrait', author.str('portrait')) ?? '',
      markPid: j.intOf('mark_pid'),
      isDeleted: j.boolean('is_deleted'),
      count: j.intOf('count'),
    );
  }
}

class SignResult {
  const SignResult({
    required this.success,
    this.message = '',
    this.signBonusPoint = 0,
    this.contSignNum = 0,
    this.userSignRank = 0,
  });

  final bool success;
  final String message;
  final int signBonusPoint;
  final int contSignNum;
  final int userSignRank;
}

class UploadPicResult {
  const UploadPicResult({
    required this.picId,
    required this.width,
    required this.height,
  });

  final String picId;
  final int width;
  final int height;

  String get insertTag => '#(pic,$picId,$width,$height)';
}

String _stripEm(String raw) =>
    raw.replaceAll(RegExp(r'</?em>', caseSensitive: false), '').trim();
