import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cookie_vault.dart';
import 'local_db.dart';

/// 会话、多账号、置顶吧与屏蔽规则统一状态管理（ChangeNotifier）。
class FrostedStore extends ChangeNotifier {
  FrostedStore({
    required this.db,
    required this.prefs,
    required this.cookies,
  });

  final LocalDb db;
  final SharedPreferences prefs;
  final CookieVault cookies;

  List<AccountRecord> _accounts = [];
  String? _activeUid;
  List<BlockRule> _blocks = [];
  Set<String> _topForums = {};
  List<HistoryRecord> _visitedForums = [];

  List<AccountRecord> get accounts => List.unmodifiable(_accounts);
  String? get activeUid => _activeUid;
  List<BlockRule> get blocks => List.unmodifiable(_blocks);
  Set<String> get topForums => Set.unmodifiable(_topForums);

  /// 最近进过的吧，首页「经过贴吧」横滑条用。进吧写入后自动刷新。
  List<HistoryRecord> get visitedForums => List.unmodifiable(_visitedForums);

  AccountRecord? get currentAccount {
    if (_activeUid == null || _activeUid!.isEmpty) return null;
    for (final acc in _accounts) {
      if (acc.uid == _activeUid) return acc;
    }
    return null;
  }

  bool get isLoggedIn =>
      currentAccount != null && currentAccount!.bduss.isNotEmpty;

  String get bduss => currentAccount?.bduss ?? '';
  String get stoken => currentAccount?.stoken ?? '';
  String get tbs => currentAccount?.tbs ?? '';
  String get uid => currentAccount?.uid ?? '';
  String get zid => currentAccount?.zid ?? '';
  String get webCookie => currentAccount?.cookie ?? cookies.rawHeader;

  Future<void> init() async {
    _accounts = await db.getAccounts();
    _blocks = await db.getBlocks();
    _topForums = await db.getTopForums();
    _visitedForums = await db.getHistory(type: 1, limit: 20);
    final savedUid = prefs.getString('active_account_uid');
    if (savedUid != null && _accounts.any((a) => a.uid == savedUid)) {
      _activeUid = savedUid;
    } else if (_accounts.isNotEmpty) {
      _activeUid = _accounts.first.uid;
    }
    _syncVaultFromActive();
    notifyListeners();
  }

  void _syncVaultFromActive() {
    final acc = currentAccount;
    if (acc == null) {
      cookies.clear();
      return;
    }
    cookies.loadFromRaw(acc.cookie);
    if (acc.bduss.isNotEmpty) cookies.set('BDUSS', acc.bduss);
    if (acc.stoken.isNotEmpty) cookies.set('STOKEN', acc.stoken);
    if (acc.baiduId.isNotEmpty) cookies.set('BAIDUID', acc.baiduId);
  }

  Future<void> saveAccount(AccountRecord account, {bool activate = true}) async {
    final updated = account.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await db.upsertAccount(updated);
    _accounts = await db.getAccounts();
    if (activate) {
      _activeUid = updated.uid;
      await prefs.setString('active_account_uid', updated.uid);
      _syncVaultFromActive();
      await cookies.pushToWebView();
    }
    notifyListeners();
  }

  Future<void> switchAccount(String uid) async {
    if (!_accounts.any((a) => a.uid == uid)) return;
    _activeUid = uid;
    await prefs.setString('active_account_uid', uid);
    _syncVaultFromActive();
    await cookies.pushToWebView();
    notifyListeners();
  }

  Future<void> removeAccount(String uid) async {
    await db.deleteAccount(uid);
    _accounts = await db.getAccounts();
    if (_activeUid == uid) {
      _activeUid = _accounts.isNotEmpty ? _accounts.first.uid : null;
      if (_activeUid != null) {
        await prefs.setString('active_account_uid', _activeUid!);
      } else {
        await prefs.remove('active_account_uid');
      }
      _syncVaultFromActive();
      if (_activeUid == null) {
        await cookies.clearWebView();
      } else {
        await cookies.pushToWebView();
      }
    }
    notifyListeners();
  }

  Future<void> logout() async {
    final cur = _activeUid;
    if (cur != null) {
      await removeAccount(cur);
    } else {
      cookies.clear();
      await cookies.clearWebView();
      notifyListeners();
    }
  }

  // ---- Top Forums ----

  bool isTopForum(String forumName) => _topForums.contains(forumName);

  Future<void> toggleTopForum(String forumName) async {
    final next = !_topForums.contains(forumName);
    await db.setTopForum(forumName, next);
    _topForums = await db.getTopForums();
    notifyListeners();
  }

  // ---- Blocks ----

  Future<void> addBlockRule({
    required BlockRuleType type,
    required String value,
    bool isRegex = false,
    bool isWhitelist = false,
  }) async {
    final clean = value.trim();
    if (clean.isEmpty) return;
    await db.addBlock(
      BlockRule(
        type: type,
        value: clean,
        isRegex: isRegex,
        isWhitelist: isWhitelist,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _blocks = await db.getBlocks();
    notifyListeners();
  }

  Future<void> removeBlockRule(int id) async {
    await db.deleteBlock(id);
    _blocks = await db.getBlocks();
    notifyListeners();
  }

  /// 检查内容/用户/贴吧是否命中屏蔽规则（白名单优先放行）。
  bool shouldBlock({
    String text = '',
    String userName = '',
    String userUid = '',
    String forumName = '',
  }) {
    if (_blocks.isEmpty) return false;
    final lowerText = text.toLowerCase();
    final lowerUser = userName.toLowerCase();
    final lowerForum = forumName.toLowerCase();

    bool matchesRule(BlockRule rule) {
      final val = rule.value.trim();
      if (val.isEmpty) return false;
      switch (rule.type) {
        case BlockRuleType.keyword:
          if (text.isEmpty) return false;
          if (rule.isRegex) {
            try {
              return RegExp(val, caseSensitive: false).hasMatch(text);
            } on FormatException {
              return false;
            }
          }
          return lowerText.contains(val.toLowerCase());
        case BlockRuleType.user:
          if (userUid.isNotEmpty && userUid == val) return true;
          return lowerUser.isNotEmpty && lowerUser == val.toLowerCase();
        case BlockRuleType.forum:
          return lowerForum.isNotEmpty && lowerForum == val.toLowerCase();
      }
    }

    for (final r in _blocks) {
      if (r.isWhitelist && matchesRule(r)) return false;
    }
    for (final r in _blocks) {
      if (!r.isWhitelist && matchesRule(r)) return true;
    }
    return false;
  }

  // ---- History & Drafts helpers ----

  Future<void> recordThreadHistory({
    required int threadId,
    required String title,
    required String forumName,
    String avatar = '',
  }) {
    return db.upsertHistory(
      HistoryRecord(
        type: 2,
        itemId: '$threadId',
        title: title.isNotEmpty ? title : '帖子 #$threadId',
        subtitle: forumName.isNotEmpty ? '$forumName吧' : '',
        avatar: avatar,
        extra: forumName,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> recordForumHistory({
    required String forumName,
    String avatar = '',
  }) async {
    await db.upsertHistory(
      HistoryRecord(
        type: 1,
        itemId: forumName,
        title: '$forumName吧',
        subtitle: '贴吧',
        avatar: avatar,
        extra: forumName,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _visitedForums = await db.getHistory(type: 1, limit: 20);
    notifyListeners();
  }
}
