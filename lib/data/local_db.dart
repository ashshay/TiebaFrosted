import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 本地数据库条目模型（对应 TiebaLite Room 6 张表：accounts / blocks / drafts / history / search_history / top_forums）。
class AccountRecord {
  const AccountRecord({
    required this.uid,
    required this.name,
    this.nameShow = '',
    this.portrait = '',
    required this.bduss,
    this.stoken = '',
    this.tbs = '',
    this.cookie = '',
    this.zid = '',
    this.baiduId = '',
    this.updatedAt = 0,
  });

  final String uid;
  final String name;
  final String nameShow;
  final String portrait;
  final String bduss;
  final String stoken;
  final String tbs;
  final String cookie;
  final String zid;
  final String baiduId;
  final int updatedAt;

  String get displayName => nameShow.isNotEmpty ? nameShow : name;

  /// 写操作（回帖、收藏、点赞…）需要的凭据是否齐全。
  ///
  /// 贴吧的写接口同时校验 BDUSS、STOKEN 与 tbs，缺任一项都会回
  /// `用户未登录或登录失败`；浏览接口只认 BDUSS，所以「能看不能发」正是
  /// 半套凭据的典型表现。
  bool get canWrite => bduss.isNotEmpty && stoken.isNotEmpty && tbs.isNotEmpty;

  /// 缺哪一块凭据（空字符串表示不缺），用于提示用户怎么补。
  String get writeBlockReason {
    final missing = <String>[
      if (stoken.isEmpty) 'STOKEN',
      if (tbs.isEmpty) 'tbs',
      if (bduss.isEmpty) 'BDUSS',
    ];
    return missing.isEmpty ? '' : missing.join(' / ');
  }

  AccountRecord copyWith({
    String? name,
    String? nameShow,
    String? portrait,
    String? bduss,
    String? stoken,
    String? tbs,
    String? cookie,
    String? zid,
    String? baiduId,
    int? updatedAt,
  }) => AccountRecord(
    uid: uid,
    name: name ?? this.name,
    nameShow: nameShow ?? this.nameShow,
    portrait: portrait ?? this.portrait,
    bduss: bduss ?? this.bduss,
    stoken: stoken ?? this.stoken,
    tbs: tbs ?? this.tbs,
    cookie: cookie ?? this.cookie,
    zid: zid ?? this.zid,
    baiduId: baiduId ?? this.baiduId,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toMap() => {
    'uid': uid,
    'name': name,
    'name_show': nameShow,
    'portrait': portrait,
    'bduss': bduss,
    'stoken': stoken,
    'tbs': tbs,
    'cookie': cookie,
    'zid': zid,
    'baidu_id': baiduId,
    'updated_at': updatedAt,
  };

  factory AccountRecord.fromMap(Map<String, Object?> m) => AccountRecord(
    uid: (m['uid'] ?? '').toString(),
    name: (m['name'] ?? '').toString(),
    nameShow: (m['name_show'] ?? '').toString(),
    portrait: (m['portrait'] ?? '').toString(),
    bduss: (m['bduss'] ?? '').toString(),
    stoken: (m['stoken'] ?? '').toString(),
    tbs: (m['tbs'] ?? '').toString(),
    cookie: (m['cookie'] ?? '').toString(),
    zid: (m['zid'] ?? '').toString(),
    baiduId: (m['baidu_id'] ?? '').toString(),
    updatedAt: (m['updated_at'] as num?)?.toInt() ?? 0,
  );
}

enum BlockRuleType { keyword, user, forum }

class BlockRule {
  const BlockRule({
    this.id = 0,
    required this.type,
    required this.value,
    this.isRegex = false,
    this.isWhitelist = false,
    this.createdAt = 0,
  });

  final int id;
  final BlockRuleType type;
  final String value;
  final bool isRegex;
  final bool isWhitelist;
  final int createdAt;

  Map<String, Object?> toMap() => {
    if (id > 0) 'id': id,
    'type': type.index,
    'value': value,
    'is_regex': isRegex ? 1 : 0,
    'is_whitelist': isWhitelist ? 1 : 0,
    'created_at': createdAt,
  };

  factory BlockRule.fromMap(Map<String, Object?> m) {
    final idx = (m['type'] as num?)?.toInt() ?? 0;
    return BlockRule(
      id: (m['id'] as num?)?.toInt() ?? 0,
      type: BlockRuleType.values[idx.clamp(0, BlockRuleType.values.length - 1)],
      value: (m['value'] ?? '').toString(),
      isRegex: ((m['is_regex'] as num?)?.toInt() ?? 0) != 0,
      isWhitelist: ((m['is_whitelist'] as num?)?.toInt() ?? 0) != 0,
      createdAt: (m['created_at'] as num?)?.toInt() ?? 0,
    );
  }
}

class HistoryRecord {
  const HistoryRecord({
    required this.type, // 1=forum, 2=thread
    required this.itemId,
    required this.title,
    this.subtitle = '',
    this.avatar = '',
    this.extra = '',
    required this.timestamp,
  });

  final int type;
  final String itemId;
  final String title;
  final String subtitle;
  final String avatar;
  final String extra;
  final int timestamp;

  Map<String, Object?> toMap() => {
    'type': type,
    'item_id': itemId,
    'title': title,
    'subtitle': subtitle,
    'avatar': avatar,
    'extra': extra,
    'timestamp': timestamp,
  };

  factory HistoryRecord.fromMap(Map<String, Object?> m) => HistoryRecord(
    type: (m['type'] as num?)?.toInt() ?? 2,
    itemId: (m['item_id'] ?? '').toString(),
    title: (m['title'] ?? '').toString(),
    subtitle: (m['subtitle'] ?? '').toString(),
    avatar: (m['avatar'] ?? '').toString(),
    extra: (m['extra'] ?? '').toString(),
    timestamp: (m['timestamp'] as num?)?.toInt() ?? 0,
  );
}

class DraftRecord {
  const DraftRecord({
    required this.key,
    required this.content,
    this.title = '',
    required this.updatedAt,
  });

  final String key;
  final String content;
  final String title;
  final int updatedAt;

  Map<String, Object?> toMap() => {
    'draft_key': key,
    'content': content,
    'title': title,
    'updated_at': updatedAt,
  };

  factory DraftRecord.fromMap(Map<String, Object?> m) => DraftRecord(
    key: (m['draft_key'] ?? '').toString(),
    content: (m['content'] ?? '').toString(),
    title: (m['title'] ?? '').toString(),
    updatedAt: (m['updated_at'] as num?)?.toInt() ?? 0,
  );
}

/// 本地 SQLite 数据库（附带纯内存模式用于 Dart 单测）。
class LocalDb {
  LocalDb._(this._db);

  final Database? _db;
  bool get _isMemory => _db == null;

  final Map<String, AccountRecord> _memAccounts = {};
  final List<BlockRule> _memBlocks = [];
  int _memBlockSeq = 1;
  final Map<String, DraftRecord> _memDrafts = {};
  final List<HistoryRecord> _memHistory = [];
  final List<String> _memSearch = [];
  final Set<String> _memTopForums = {};

  static Future<LocalDb> open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'tieba_frosted.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE accounts (
            uid TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            name_show TEXT NOT NULL DEFAULT '',
            portrait TEXT NOT NULL DEFAULT '',
            bduss TEXT NOT NULL,
            stoken TEXT NOT NULL DEFAULT '',
            tbs TEXT NOT NULL DEFAULT '',
            cookie TEXT NOT NULL DEFAULT '',
            zid TEXT NOT NULL DEFAULT '',
            baidu_id TEXT NOT NULL DEFAULT '',
            updated_at INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE blocks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type INTEGER NOT NULL,
            value TEXT NOT NULL,
            is_regex INTEGER NOT NULL DEFAULT 0,
            is_whitelist INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE drafts (
            draft_key TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            updated_at INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE history (
            type INTEGER NOT NULL,
            item_id TEXT NOT NULL,
            title TEXT NOT NULL,
            subtitle TEXT NOT NULL DEFAULT '',
            avatar TEXT NOT NULL DEFAULT '',
            extra TEXT NOT NULL DEFAULT '',
            timestamp INTEGER NOT NULL,
            PRIMARY KEY (type, item_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE search_history (
            keyword TEXT PRIMARY KEY,
            timestamp INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE top_forums (
            forum_name TEXT PRIMARY KEY,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return LocalDb._(db);
  }

  factory LocalDb.inMemory() => LocalDb._(null);

  // ---- Accounts ----

  Future<List<AccountRecord>> getAccounts() async {
    if (_isMemory) {
      return _memAccounts.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    final rows = await _db!.query('accounts', orderBy: 'updated_at DESC');
    return rows.map(AccountRecord.fromMap).toList();
  }

  Future<void> upsertAccount(AccountRecord record) async {
    if (_isMemory) {
      _memAccounts[record.uid] = record;
      return;
    }
    await _db!.insert(
      'accounts',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAccount(String uid) async {
    if (_isMemory) {
      _memAccounts.remove(uid);
      return;
    }
    await _db!.delete('accounts', where: 'uid = ?', whereArgs: [uid]);
  }

  // ---- Blocks ----

  Future<List<BlockRule>> getBlocks() async {
    if (_isMemory) return List.unmodifiable(_memBlocks);
    final rows = await _db!.query('blocks', orderBy: 'created_at DESC');
    return rows.map(BlockRule.fromMap).toList();
  }

  Future<int> addBlock(BlockRule rule) async {
    if (_isMemory) {
      final id = _memBlockSeq++;
      _memBlocks.insert(
        0,
        BlockRule(
          id: id,
          type: rule.type,
          value: rule.value,
          isRegex: rule.isRegex,
          isWhitelist: rule.isWhitelist,
          createdAt: rule.createdAt,
        ),
      );
      return id;
    }
    return _db!.insert('blocks', rule.toMap());
  }

  Future<void> deleteBlock(int id) async {
    if (_isMemory) {
      _memBlocks.removeWhere((b) => b.id == id);
      return;
    }
    await _db!.delete('blocks', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Drafts ----

  Future<DraftRecord?> getDraft(String key) async {
    if (_isMemory) return _memDrafts[key];
    final rows = await _db!.query(
      'drafts',
      where: 'draft_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DraftRecord.fromMap(rows.first);
  }

  Future<void> saveDraft(DraftRecord draft) async {
    if (_isMemory) {
      _memDrafts[draft.key] = draft;
      return;
    }
    await _db!.insert(
      'drafts',
      draft.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDraft(String key) async {
    if (_isMemory) {
      _memDrafts.remove(key);
      return;
    }
    await _db!.delete('drafts', where: 'draft_key = ?', whereArgs: [key]);
  }

  // ---- History ----

  Future<List<HistoryRecord>> getHistory({int? type, int limit = 200}) async {
    if (_isMemory) {
      final list = type == null
          ? _memHistory
          : _memHistory.where((h) => h.type == type).toList();
      return list.take(limit).toList();
    }
    final rows = await _db!.query(
      'history',
      where: type == null ? null : 'type = ?',
      whereArgs: type == null ? null : [type],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(HistoryRecord.fromMap).toList();
  }

  Future<void> upsertHistory(HistoryRecord record) async {
    if (_isMemory) {
      _memHistory.removeWhere(
        (h) => h.type == record.type && h.itemId == record.itemId,
      );
      _memHistory.insert(0, record);
      if (_memHistory.length > 300) _memHistory.removeLast();
      return;
    }
    await _db!.insert(
      'history',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteHistory(int type, String itemId) async {
    if (_isMemory) {
      _memHistory.removeWhere((h) => h.type == type && h.itemId == itemId);
      return;
    }
    await _db!.delete(
      'history',
      where: 'type = ? AND item_id = ?',
      whereArgs: [type, itemId],
    );
  }

  Future<void> clearHistory({int? type}) async {
    if (_isMemory) {
      if (type == null) {
        _memHistory.clear();
      } else {
        _memHistory.removeWhere((h) => h.type == type);
      }
      return;
    }
    if (type == null) {
      await _db!.delete('history');
    } else {
      await _db!.delete('history', where: 'type = ?', whereArgs: [type]);
    }
  }

  // ---- Search History ----

  Future<List<String>> getSearchHistory({int limit = 30}) async {
    if (_isMemory) return _memSearch.take(limit).toList();
    final rows = await _db!.query(
      'search_history',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map((r) => (r['keyword'] ?? '').toString()).toList();
  }

  Future<void> addSearchHistory(String keyword) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return;
    if (_isMemory) {
      _memSearch.remove(clean);
      _memSearch.insert(0, clean);
      if (_memSearch.length > 30) _memSearch.removeLast();
      return;
    }
    await _db!.insert(
      'search_history',
      {
        'keyword': clean,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSearchHistory(String keyword) async {
    if (_isMemory) {
      _memSearch.remove(keyword);
      return;
    }
    await _db!.delete(
      'search_history',
      where: 'keyword = ?',
      whereArgs: [keyword],
    );
  }

  Future<void> clearSearchHistory() async {
    if (_isMemory) {
      _memSearch.clear();
      return;
    }
    await _db!.delete('search_history');
  }

  // ---- Top Forums ----

  Future<Set<String>> getTopForums() async {
    if (_isMemory) return Set.unmodifiable(_memTopForums);
    final rows = await _db!.query('top_forums', orderBy: 'created_at ASC');
    return rows.map((r) => (r['forum_name'] ?? '').toString()).toSet();
  }

  Future<void> setTopForum(String forumName, bool isTop) async {
    if (_isMemory) {
      if (isTop) {
        _memTopForums.add(forumName);
      } else {
        _memTopForums.remove(forumName);
      }
      return;
    }
    if (isTop) {
      await _db!.insert(
        'top_forums',
        {
          'forum_name': forumName,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await _db!.delete(
        'top_forums',
        where: 'forum_name = ?',
        whereArgs: [forumName],
      );
    }
  }
}
