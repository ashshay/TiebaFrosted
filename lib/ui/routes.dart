import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../core/html_text.dart';
import '../core/links.dart';
import '../data/local_db.dart';
import '../data/models.dart';
import '../data/native_channels.dart';
import '../data/oksign_notifier.dart';
import '../data/repo.dart';
import '../data/settings.dart';
import '../data/store.dart';
import 'nav.dart';
import 'pages/about_page.dart';
import 'pages/edit_profile_page.dart';
import 'pages/follow_list_page.dart';
import 'pages/forum_detail_page.dart';
import 'pages/forum_page.dart';
import 'pages/forum_rule_page.dart';
import 'pages/history_page.dart';
import 'pages/hot_topic_detail_page.dart';
import 'pages/hot_topic_list_page.dart';
import 'pages/image_viewer_page.dart';
import 'pages/login_page.dart';
import 'pages/reply_page.dart';
import 'pages/search_forum_page.dart';
import 'pages/search_page.dart';
import 'pages/search_thread_page.dart';
import 'pages/search_user_page.dart';
import 'pages/settings_account_page.dart';
import 'pages/settings_block_page.dart';
import 'pages/settings_custom_page.dart';
import 'pages/settings_habit_page.dart';
import 'pages/settings_more_page.dart';
import 'pages/settings_oksign_page.dart';
import 'pages/settings_page.dart';
import 'pages/settings_theme_page.dart';
import 'pages/subposts_page.dart';
import 'pages/thread_page.dart';
import 'pages/thread_store_page.dart';
import 'pages/user_like_forum_page.dart';
import 'pages/user_post_page.dart';
import 'pages/user_profile_page.dart';
import 'pages/video_page.dart';
import 'pages/web_page.dart';
import 'widgets/common.dart';

Future<void> openForum(
  BuildContext context,
  String forumName, {
  String initialAvatar = '',
}) {
  if (forumName.trim().isEmpty) return Future.value();
  return pushPage(
    context,
    ForumPage(forumName: forumName.trim(), initialAvatar: initialAvatar),
  );
}

Future<void> openForumDetail(
  BuildContext context, {
  required int forumId,
  required String forumName,
}) => pushPage(
  context,
  ForumDetailPage(forumId: forumId, forumName: forumName),
);

Future<void> openForumRule(
  BuildContext context, {
  required int forumId,
  required String forumName,
}) => pushPage(
  context,
  ForumRulePage(forumId: forumId, forumName: forumName),
);

/// 打开官方吧务后台（删帖、封禁、申诉都在里面）。非吧务打开会被网站提示无权限。
Future<void> openBawuConsole(BuildContext context, String forumName) {
  final name = forumName.trim();
  if (name.isEmpty) return Future.value();
  return openWeb(
    context,
    'https://tieba.baidu.com/bawu2/platform/index'
    '?word=${Uri.encodeQueryComponent(name)}',
    title: '$name吧 · 吧务管理',
  );
}

Future<void> openThread(
  BuildContext context, {
  required int threadId,
  int forumId = 0,
  String forumName = '',
  String forumAvatar = '',
  int? postId,
  int? subPostId,
  String initialTitle = '',
  bool fromStore = false,
  bool focusReplies = false,
}) => pushPage(
  context,
  ThreadPage(
    threadId: threadId,
    forumId: forumId,
    forumName: forumName,
    forumAvatar: forumAvatar,
    focusReplies: focusReplies,
    initialPostId: postId,
    initialSubPostId: subPostId,
    initialTitle: initialTitle,
    fromStore: fromStore,
  ),
);

Future<void> openSubPosts(
  BuildContext context, {
  required int threadId,
  required int postId,
  int forumId = 0,
  String forumName = '',
  int lzUserId = 0,
  int subPostId = 0,
  String tbs = '',
  TiebaPost? initialPost,
}) => pushPage(
  context,
  SubPostsPage(
    threadId: threadId,
    postId: postId,
    forumId: forumId,
    forumName: forumName,
    lzUserId: lzUserId,
    subPostId: subPostId,
    tbs: tbs,
    initialPost: initialPost,
  ),
);

Future<bool?> openReply(
  BuildContext context, {
  required int forumId,
  required String forumName,
  required int threadId,
  int? quotePostId,
  int? subPostId,
  int? replyUid,
  String? replyUserName,
  String tbs = '',
}) => pushPage<bool>(
  context,
  ReplyPage(
    mode: ReplyMode.reply,
    forumId: forumId,
    forumName: forumName,
    threadId: threadId,
    quotePostId: quotePostId,
    subPostId: subPostId,
    replyUid: replyUid,
    replyUserName: replyUserName,
    tbs: tbs,
  ),
);

Future<bool?> openComposeThread(
  BuildContext context, {
  required int forumId,
  required String forumName,
  String tbs = '',
}) => pushPage<bool>(
  context,
  ReplyPage(
    mode: ReplyMode.newThread,
    forumId: forumId,
    forumName: forumName,
    tbs: tbs,
  ),
);

Future<void> openSearch(
  BuildContext context, {
  String initialQuery = '',
  String? forumName,
}) => pushPage(
  context,
  SearchPage(initialQuery: initialQuery, forumName: forumName),
);

Future<void> openSearchForum(BuildContext context, String keyword) =>
    pushPage(context, SearchForumPage(keyword: keyword));

Future<void> openSearchThread(
  BuildContext context,
  String keyword, {
  String? forumName,
}) => pushPage(
  context,
  SearchThreadPage(keyword: keyword, forumName: forumName),
);

Future<void> openSearchUser(BuildContext context, String keyword) =>
    pushPage(context, SearchUserPage(keyword: keyword));

Future<void> openUserProfile(
  BuildContext context, {
  int? uid,
  String portrait = '',
  String initialName = '',
}) => pushPage(
  context,
  UserProfilePage(
    uid: uid,
    portrait: portrait,
    initialName: initialName,
  ),
);

Future<void> openFollowList(
  BuildContext context, {
  int? uid,
  String title = '关注列表',
  bool isFans = false,
}) => pushPage(
  context,
  FollowListPage(uid: uid, title: title, isFans: isFans),
);

Future<void> openUserPost(
  BuildContext context, {
  required int uid,
  String title = '帖子与回复',
  bool initialThreads = true,
}) => pushPage(
  context,
  UserPostPage(uid: uid, title: title, initialThreads: initialThreads),
);

Future<void> openUserLikeForum(
  BuildContext context, {
  required int uid,
  String title = '关注的吧',
}) => pushPage(context, UserLikeForumPage(uid: uid, title: title));

Future<bool?> openEditProfile(
  BuildContext context, {
  required TiebaUser user,
}) => pushPage<bool>(context, EditProfilePage(user: user));

Future<void> openHistory(BuildContext context) =>
    pushPage(context, const HistoryPage());

Future<void> openThreadStore(BuildContext context) =>
    pushPage(context, const ThreadStorePage());

Future<void> openHotTopicList(BuildContext context) =>
    pushPage(context, const HotTopicListPage());

Future<void> openHotTopicDetail(
  BuildContext context, {
  required int topicId,
  required String topicName,
}) => pushPage(
  context,
  HotTopicDetailPage(topicId: topicId, topicName: topicName),
);

Future<void> openImageViewer(
  BuildContext context, {
  required List<RichImageNode> images,
  int initialIndex = 0,
}) => pushLightboxPage(
  context,
  ImageViewerPage(images: images, initialIndex: initialIndex),
);

Future<void> openVideoPlayer(
  BuildContext context, {
  required String videoUrl,
  String title = '视频播放',
}) => pushPage(context, VideoPage(videoUrl: videoUrl, title: title));

Future<bool?> openLogin(BuildContext context) =>
    pushPage<bool>(context, const LoginPage());

Future<void> openWeb(
  BuildContext context,
  String url, {
  String? title,
}) => pushPage(context, WebPage(url: url, initialTitle: title));

Future<void> openSettings(BuildContext context) =>
    pushPage(context, const SettingsPage());

Future<void> openSettingsTheme(BuildContext context) =>
    pushPage(context, const SettingsThemePage());

Future<void> openSettingsAccount(BuildContext context) =>
    pushPage(context, const SettingsAccountPage());

Future<void> openSettingsBlock(BuildContext context) =>
    pushPage(context, const SettingsBlockPage());

Future<void> openSettingsHabit(BuildContext context) =>
    pushPage(context, const SettingsHabitPage());

Future<void> openSettingsOkSign(BuildContext context) =>
    pushPage(context, const SettingsOkSignPage());

Future<void> openSettingsMore(BuildContext context) =>
    pushPage(context, const SettingsMorePage());

Future<void> openSettingsCustom(BuildContext context) =>
    pushPage(context, const SettingsCustomPage());

Future<void> openAbout(BuildContext context) =>
    pushPage(context, const AboutPage());

/// 统一贴吧链接分发器（支持帖子、贴吧、用户与外部网页）。
///
/// 站外链接按「使用内置浏览器」设置决定去处：开着进 [WebPage]，关掉交给系统浏览器。
Future<void> openTiebaUrl(BuildContext context, String rawUrl) {
  final parsed = parseTiebaLink(rawUrl);
  return switch (parsed) {
    TiebaThreadLink(:final threadId, :final postId, :final subPostId) =>
      openThread(
        context,
        threadId: threadId,
        postId: postId,
        subPostId: subPostId,
      ),
    TiebaForumLink(:final forumName) => openForum(context, forumName),
    TiebaUserLink(:final uid, :final portrait) => openUserProfile(
      context,
      uid: uid,
      portrait: portrait ?? '',
    ),
    TiebaWebLink(:final url) => openExternalUrl(context, url),
  };
}

/// 打开站外链接：内置浏览器或系统浏览器，取决于设置。
Future<void> openExternalUrl(BuildContext context, String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;
  final scheme = Uri.tryParse(trimmed)?.scheme.toLowerCase() ?? '';
  // 非 http(s) 的（mailto:、tg: 之类）只有系统能处理。
  if (scheme != 'http' && scheme != 'https') {
    await NativeChannels.openInBrowser(trimmed);
    return;
  }
  if (context.read<FrostedSettings>().useWebView) {
    await openWeb(context, trimmed);
    return;
  }
  final ok = await NativeChannels.openInBrowser(trimmed);
  if (!ok && context.mounted) {
    showFrostedToast(context, '没有找到可用的系统浏览器');
  }
}

/// 帖子卡片长按快捷操作菜单。返回 true 表示列表里的这条帖子已被删除。
Future<bool> showThreadContextMenu(
  BuildContext context,
  TiebaThread thread,
) async {
  final store = context.read<FrostedStore>();
  final repo = context.read<TiebaRepo>();
  final myUid = int.tryParse(store.uid) ?? 0;
  final mine =
      myUid > 0 &&
      (thread.authorId == myUid || thread.author.id == myUid);
  final choices = <FrostedChoice<String>>[
    const FrostedChoice(value: 'copy_link', label: '复制帖子链接'),
    const FrostedChoice(value: 'share', label: '分享帖子'),
    if (thread.forumName.isNotEmpty)
      FrostedChoice(value: 'open_forum', label: '进入 ${thread.forumName}吧'),
    const FrostedChoice(value: 'report_thread', label: '举报帖子'),
    if (mine)
      const FrostedChoice(
        value: 'delete_thread',
        label: '删除我的帖子',
        destructive: true,
      ),
    if (thread.author.id > 0)
      FrostedChoice(
        value: 'block_user',
        label: '屏蔽作者 ${thread.author.displayName}',
        destructive: true,
      ),
    if (thread.forumName.isNotEmpty)
      FrostedChoice(
        value: 'block_forum',
        label: '屏蔽 ${thread.forumName}吧',
        destructive: true,
      ),
  ];
  final picked = await showFrostedChoices<String>(
    context,
    title: thread.displayTitle.isNotEmpty ? thread.displayTitle : '帖子操作',
    choices: choices,
  );
  if (picked == null || !context.mounted) return false;
  final url = 'https://tieba.baidu.com/p/${thread.effectiveId}';
  switch (picked) {
    case 'copy_link':
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) showFrostedToast(context, '已复制链接');
    case 'share':
      await NativeChannels.shareText(
        '${thread.displayTitle}\n$url',
        subject: thread.displayTitle,
      );
    case 'open_forum':
      await openForum(context, thread.forumName);
    case 'report_thread':
      if (thread.firstPostId <= 0) {
        if (context.mounted) {
          showFrostedToast(
            context,
            '需要先打开帖子才能举报',
            level: BannerLevel.error,
          );
        }
        return false;
      }
      try {
        final reportUrl = await repo.reportUrl(postId: thread.firstPostId);
        if (!context.mounted) return false;
        if (reportUrl.isEmpty) {
          showFrostedToast(context, '举报页暂不可用', level: BannerLevel.error);
          return false;
        }
        await openWeb(context, reportUrl, title: '举报');
      } on Object catch (e) {
        if (context.mounted) {
          showFrostedToast(context, cleanError(e), level: BannerLevel.error);
        }
      }
    case 'delete_thread':
      final ok = await showFrostedConfirm(
        context,
        title: '删除主题帖？',
        message: '删除后无法恢复',
        confirmText: '删除',
        destructive: true,
      );
      if (ok != true || !context.mounted) return false;
      try {
        await repo.deleteThread(
          forumId: thread.forumId,
          forumName: thread.forumName,
          threadId: thread.effectiveId,
          mine: true,
        );
        if (context.mounted) showFrostedToast(context, '已删除');
        return true;
      } on Object catch (e) {
        if (context.mounted) {
          showFrostedToast(context, cleanError(e), level: BannerLevel.error);
        }
      }
    case 'block_user':
      await store.addBlockRule(
        type: BlockRuleType.user,
        value: thread.author.displayName,
      );
      if (context.mounted) {
        showFrostedToast(
          context,
          '已屏蔽 ${thread.author.displayName}',
          level: BannerLevel.info,
        );
      }
    case 'block_forum':
      await store.addBlockRule(
        type: BlockRuleType.forum,
        value: thread.forumName,
      );
      if (context.mounted) {
        showFrostedToast(
          context,
          '已屏蔽 ${thread.forumName}吧',
          level: BannerLevel.info,
        );
      }
  }
  return false;
}

/// 辅助检查登录态，未登录时引导前往登录页。
Future<bool> ensureLoggedIn(BuildContext context, {String? reason}) async {
  if (context.read<TiebaRepo>().isLoggedIn) return true;
  final ok = await showFrostedConfirm(
    context,
    title: '需要登录',
    message: reason ?? '请先登录百度贴吧账号以继续此操作',
    confirmText: '去登录',
  );
  if (ok == true && context.mounted) {
    final loggedIn = await openLogin(context);
    return loggedIn == true;
  }
  return false;
}

bool _okSignRunning = false;

/// 顶栏「一键签到」：点一下直接全签，进度与结果落在通知栏，
/// 与 TiebaLite 的 `OKSignService` 一致。
///
/// 设置 → 账号与内容 →「自动签到与一键全签」仍是同一能力的可视化版本
/// （带逐吧日志与定时设置），这里是它的快捷入口。
Future<void> runOneClickOkSign(BuildContext context) async {
  if (_okSignRunning) {
    showFrostedToast(context, '签到正在进行中…');
    return;
  }
  if (!await ensureLoggedIn(context, reason: '登录后即可一键全签')) return;
  if (!context.mounted) return;

  final repo = context.read<TiebaRepo>();
  final accent = context.colorScheme.primary;

  _okSignRunning = true;
  await okSignNotifier.show(
    title: '一键签到',
    text: '正在获取关注贴吧列表…',
    accent: accent,
    ongoing: true,
  );

  try {
    final result = await repo.okSignAll(
      onProgress: (current, total, forum, status) {
        // 回调是同步的，通知更新不必阻塞签到节奏。
        unawaited(
          okSignNotifier.show(
            title: total > 0 ? '一键签到 $current/$total' : '一键签到',
            text: '$forum · $status',
            accent: accent,
            ongoing: true,
          ),
        );
      },
    );
    final summary = result.total == 0
        ? '还没有关注任何贴吧'
        : '共 ${result.total} 吧：成功 ${result.signed}，'
              '已签跳过 ${result.skipped}，失败 ${result.failed}';
    await okSignNotifier.show(
      title: result.total == 0 ? '一键签到' : '签到完成',
      text: summary,
      accent: accent,
    );
    if (context.mounted) showFrostedToast(context, summary);
  } on Object catch (e) {
    final message = cleanError(e);
    await okSignNotifier.show(
      title: '签到失败',
      text: message,
      accent: accent,
    );
    if (context.mounted) {
      showFrostedToast(context, message, level: BannerLevel.error);
    }
  } finally {
    _okSignRunning = false;
  }
}
