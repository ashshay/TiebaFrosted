import 'dart:typed_data';

import '../core/device.dart';
import '../core/html_text.dart';
import '../core/proto_wire.dart';
import 'models.dart';

/// 贴吧 Protobuf 协议编解码器（字段号严格对照 `TiebaLite/app/src/main/protos/*.proto`）。
abstract final class TiebaProtoCodec {
  // ===========================================================================
  // CommonRequest & Shared Request Builders
  // ===========================================================================

  static Uint8List encodeCommonRequest({
    required TiebaDevice device,
    required String clientVersion,
    String bduss = '',
    String stoken = '',
    String tbs = '',
    String zid = '',
    bool isPost = false,
  }) {
    final w = ProtoWriter();
    w.writeInt32(1, 2); // _client_type = 2 (Android)
    w.writeString(2, clientVersion);
    w.writeString(3, device.effectiveClientId);
    w.writeString(5, device.imei);
    w.writeString(
      6,
      clientVersion == TiebaClientVersion.v11 ? '1024324o' : '1020031h',
    );
    w.writeString(7, device.newCuid);
    w.writeInt64(8, DateTime.now().millisecondsSinceEpoch);
    w.writeString(9, device.model);
    if (bduss.isNotEmpty) w.writeString(10, bduss);
    if (tbs.isNotEmpty && clientVersion != TiebaClientVersion.v22) {
      w.writeString(11, tbs);
    }
    w.writeInt32(12, 1); // net_type = 1
    w.writeString(24, '1.0.3'); // pversion
    w.writeString(25, device.osVersion);
    w.writeString(26, device.brand);
    w.writeString(28, '3.0.0'); // lego_lib_version
    if (isPost) w.writeString(29, '', emitEmpty: true); // applist
    if (stoken.isNotEmpty) w.writeString(30, stoken);
    if (zid.isNotEmpty) w.writeString(31, zid);
    w.writeString(32, device.newCuid);
    w.writeString(33, '', emitEmpty: true); // cuid_gid
    if (clientVersion == TiebaClientVersion.v11) {
      w.writeString(34, device.oaidJson);
    } else {
      w.writeString(34, '', emitEmpty: true);
    }
    w.writeString(35, device.aid);
    if (device.sampleId.isNotEmpty) w.writeString(36, device.sampleId);

    if (clientVersion != TiebaClientVersion.v11) {
      w.writeInt32(37, device.screenWidth);
      w.writeInt32(38, device.screenHeight);
      w.writeDouble(39, device.screenDensity);
      w.writeInt32(40, 0, emitZero: true); // q_type
      w.writeInt32(41, 0, emitZero: true); // is_teenager
      if (clientVersion == TiebaClientVersion.v22) {
        w.writeString(42, '3.36.0');
        w.writeString(43, '4220001');
        w.writeString(44, '2035000');
      } else {
        w.writeString(42, '2.34.0');
        w.writeString(43, '3340042');
        w.writeString(44, '1038000');
      }
      w.writeInt64(49, device.activeTimestamp);
      w.writeInt64(50, device.firstInstallTime);
      w.writeInt64(51, device.lastUpdateTime);
      w.writeString(53, device.eventDay);
      w.writeString(54, isPost ? device.androidId : device.base64AndroidId);
      w.writeInt32(55, 1); // cmode
      w.writeString(56, '', emitEmpty: true); // start_scheme
      w.writeInt32(57, 1); // start_type
      w.writeString(61, '', emitEmpty: true); // extra
      w.writeString(62, device.userAgent('tieba/$clientVersion'));
      w.writeInt32(63, 1); // personalized_rec_switch
      if (isPost) w.writeString(70, device.deviceScore);
    } else {
      w.writeInt32(41, 0, emitZero: true); // is_teenager
    }

    return w.toBytes();
  }

  static Uint8List encodeAppPosInfo() {
    final w = ProtoWriter();
    w.writeString(1, '02:00:00:00:00:00');
    w.writeBool(2, true);
    w.writeString(3, 'BD09LL');
    w.writeInt64(6, 0, emitZero: true);
    w.writeString(7, '', emitEmpty: true);
    return w.toBytes();
  }

  static Uint8List encodePbAdParam() {
    final w = ProtoWriter();
    w.writeInt32(1, 0, emitZero: true); // load_count
    w.writeInt32(2, 1); // refresh_count
    w.writeInt32(4, 1); // is_req_ad
    return w.toBytes();
  }

  static Uint8List _wrapRequestData(Uint8List dataBytes) {
    final outer = ProtoWriter();
    outer.writeMessage(1, dataBytes, emitEmpty: true);
    return outer.toBytes();
  }

  // ===========================================================================
  // Response Envelope Checker (Error = 1, Data = 2)
  // ===========================================================================

  static Uint8List unwrapResponse(Uint8List rawBytes) {
    int errCode = 0;
    String errMsg = '';
    String userMsg = '';
    Uint8List data = Uint8List(0);

    ProtoReader(rawBytes).forEachField((tag, wire, r) {
      if (tag == 1 && wire == WireType.lengthDelimited) {
        r.readSubReader().forEachField((et, ew, er) {
          if (et == 1 && ew == WireType.varint) {
            errCode = er.readInt32();
            return true;
          }
          if (et == 2 && ew == WireType.lengthDelimited) {
            errMsg = er.readString();
            return true;
          }
          if (et == 3 && ew == WireType.lengthDelimited) {
            userMsg = er.readString();
            return true;
          }
          return false;
        });
        return true;
      }
      if (tag == 2 && wire == WireType.lengthDelimited) {
        data = r.readBytes();
        return true;
      }
      return false;
    });

    if (errCode != 0) {
      final msg = userMsg.isNotEmpty ? userMsg : errMsg;
      throw TiebaApiException(errCode, msg);
    }
    return data;
  }

  // ===========================================================================
  // 1. PbPage (帖子详情, cmd=302001)
  // ===========================================================================

  static Uint8List encodePbPageRequest({
    required TiebaDevice device,
    required int threadId,
    int page = 1,
    int postId = 0,
    bool seeLz = false,
    int sortType = 0,
    bool back = false,
    int forumId = 0,
    int lastPid = 0,
    String stType = '',
    bool mark = false,
    String bduss = '',
    String stoken = '',
    String tbs = '',
    String zid = '',
    int jumpFloorNum = 0,
  }) {
    final w = ProtoWriter();
    w.writeInt32(2, mark ? 1 : 0, emitZero: true); // mark
    w.writeInt32(3, back ? 1 : 0, emitZero: true); // back
    w.writeInt64(4, threadId); // kz
    w.writeInt32(5, seeLz ? 1 : 0, emitZero: true); // lz
    w.writeInt32(6, sortType, emitZero: true); // r
    if (postId > 0) w.writeInt64(7, postId); // pid
    w.writeInt32(8, 1); // with_floor
    w.writeInt32(9, 4); // floor_rn
    w.writeInt32(13, 15); // rn
    w.writeInt32(14, device.screenWidth);
    w.writeInt32(15, device.screenHeight);
    w.writeDouble(16, device.screenDensity);
    w.writeInt32(17, 2); // q_type
    w.writeInt32(18, page); // pn
    // pid 在 pb/page 里是「从这条之后开始」的游标，不是定位；要定位到某楼
    // 必须用 is_jumpfloor + jumpfloor_num。
    if (jumpFloorNum > 0) {
      w.writeInt32(34, 1, emitZero: true); // is_jumpfloor
      w.writeInt32(35, jumpFloorNum, emitZero: true); // jumpfloor_num
    }
    if (stType.isNotEmpty) w.writeString(19, stType);
    w.writeMessage(
      25,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v12,
        bduss: bduss,
        stoken: stoken,
        tbs: tbs,
        zid: zid,
      ),
    );
    w.writeString(52, '10'); // obj_param1
    w.writeMessage(53, encodeAppPosInfo());
    if (forumId > 0) w.writeInt64(56, forumId);
    w.writeMessage(58, encodePbAdParam());
    w.writeInt32(74, 1); // floor_sort_type
    w.writeInt32(75, 2); // source_type
    if (lastPid > 0) w.writeInt64(81, lastPid);
    return _wrapRequestData(w.toBytes());
  }

  static ThreadPageResult decodePbPageResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    TiebaForum forum = const TiebaForum();
    TiebaPageInfo page = const TiebaPageInfo();
    String tbs = '';
    final posts = <TiebaPost>[];
    bool hasFloor = false;
    TiebaThread thread = const TiebaThread(id: 0);
    final usersById = <int, TiebaUser>{};
    TiebaPost? firstFloorPost;
    final sortOptions = <TiebaSortOption>[];
    int sortType = 0;

    ProtoReader(data).forEachField((tag, wire, r) {
      switch (tag) {
        case 2: // forum (SimpleForum)
          forum = _decodeSimpleForum(r.readSubReader());
          return true;
        case 3: // page
          page = _decodePage(r.readSubReader());
          return true;
        case 4: // anti
          tbs = _decodeAntiTbs(r.readSubReader());
          return true;
        case 6: // repeated Post post_list
          posts.add(_decodePost(r.readSubReader()));
          return true;
        case 7: // has_floor
          hasFloor = r.readInt32() != 0;
          return true;
        case 8: // thread
          thread = _decodeThreadInfo(r.readSubReader());
          return true;
        case 13: // repeated User user_list
          final u = _decodeUser(r.readSubReader());
          if (u.id > 0) usersById[u.id] = u;
          return true;
        case 38: // first_floor_post
          firstFloorPost = _decodePost(r.readSubReader());
          return true;
        case 49: // repeated PbSortType pb_sort_info
          sortOptions.add(_decodeSortOption(r.readSubReader()));
          return true;
        case 50: // sort_type
          sortType = r.readInt32();
          return true;
        default:
          return false;
      }
    });

    /// 楼层把作者内嵌在 `Post.author` 时那份资料常缺 `ip_address`，
    /// `user_list` 里同一 uid 才带发帖地；缺的字段从后者补。
    TiebaUser resolveAuthor(TiebaUser author, int authorId) {
      final known = usersById[author.id > 0 ? author.id : authorId];
      final resolved = author.id > 0 ? author : (known ?? author);
      if (known != null && resolved.ipAddress.isEmpty) {
        return resolved.copyWith(ipAddress: known.ipAddress);
      }
      return resolved;
    }

    TiebaPost hydratePost(TiebaPost p) {
      final resolvedAuthor = resolveAuthor(p.author, p.authorId);
      final resolvedSubs = [
        for (final s in p.subPosts)
          s.copyWith(author: resolveAuthor(s.author, s.authorId)),
      ];
      return p.copyWith(author: resolvedAuthor, subPosts: resolvedSubs);
    }

    final hydratedPosts = [for (final p in posts) hydratePost(p)];
    TiebaPost? hydratedFirst =
        firstFloorPost != null ? hydratePost(firstFloorPost!) : null;
    if (hydratedFirst == null) {
      for (final p in hydratedPosts) {
        if (p.floor == 1) {
          hydratedFirst = p;
          break;
        }
      }
    }

    final resolvedThreadAuthor = thread.author.id > 0
        ? thread.author
        : (usersById[thread.authorId] ??
              hydratedFirst?.author ??
              thread.author);

    return ThreadPageResult(
      thread: thread.copyWith(author: resolvedThreadAuthor),
      forum: forum,
      page: page,
      firstFloorPost: hydratedFirst,
      posts: hydratedPosts,
      sortOptions: sortOptions,
      sortType: sortType,
      tbs: tbs,
      hasFloor: hasFloor,
    );
  }

  // ===========================================================================
  // 2. PbFloor (楼中楼, cmd=302002)
  // ===========================================================================

  static Uint8List encodePbFloorRequest({
    required TiebaDevice device,
    required int threadId,
    required int postId,
    int subPostId = 0,
    int page = 1,
    int forumId = 0,
    String bduss = '',
    String stoken = '',
    String zid = '',
  }) {
    final w = ProtoWriter();
    w.writeInt64(1, threadId);
    if (postId > 0) w.writeInt64(2, postId);
    if (subPostId > 0) w.writeInt64(3, subPostId);
    w.writeInt32(4, page);
    w.writeInt32(5, device.screenWidth);
    w.writeInt32(6, device.screenHeight);
    w.writeDouble(7, device.screenDensity);
    w.writeMessage(
      9,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v22,
        bduss: bduss,
        stoken: stoken,
        zid: zid,
      ),
    );
    w.writeInt32(10, 0, emitZero: true); // is_comm_reverse
    if (forumId > 0) w.writeInt64(11, forumId);
    w.writeInt32(15, 0, emitZero: true); // ori_ugc_type
    return _wrapRequestData(w.toBytes());
  }

  static SubPostsPageResult decodePbFloorResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    TiebaPageInfo page = const TiebaPageInfo();
    String tbs = '';
    TiebaPost? post;
    final subPosts = <TiebaSubPost>[];
    TiebaThread? thread;
    TiebaForum? forum;

    ProtoReader(data).forEachField((tag, wire, r) {
      switch (tag) {
        case 1:
          page = _decodePage(r.readSubReader());
          return true;
        case 2:
          tbs = _decodeAntiTbs(r.readSubReader());
          return true;
        case 3:
          post = _decodePost(r.readSubReader());
          return true;
        case 4:
          subPosts.add(_decodeSubPost(r.readSubReader()));
          return true;
        case 5:
          thread = _decodeThreadInfo(r.readSubReader());
          return true;
        case 6:
          forum = _decodeSimpleForum(r.readSubReader());
          return true;
        default:
          return false;
      }
    });

    return SubPostsPageResult(
      page: page,
      post: post,
      subPosts: subPosts,
      thread: thread,
      forum: forum,
      tbs: tbs,
    );
  }

  // ===========================================================================
  // 3. FrsPage (吧主页, cmd=301001) & ThreadList (cmd=301002)
  // ===========================================================================

  static Uint8List encodeFrsPageRequest({
    required TiebaDevice device,
    required String forumName,
    int page = 1,
    int loadType = 1,
    int sortType = 0,
    int? goodClassifyId,
    String bduss = '',
    String stoken = '',
    String tbs = '',
    String zid = '',
  }) {
    final w = ProtoWriter();
    w.writeString(1, forumName);
    w.writeInt32(2, 90); // rn
    w.writeInt32(3, 30); // rn_need
    final isGood = goodClassifyId != null;
    w.writeInt32(4, isGood ? 1 : 0, emitZero: true); // is_good
    w.writeInt32(5, goodClassifyId ?? 0, emitZero: true); // cid
    w.writeInt32(8, 1); // with_group
    w.writeInt32(11, device.screenWidth);
    w.writeInt32(12, device.screenHeight);
    w.writeDouble(13, device.screenDensity);
    w.writeInt32(14, 2); // q_type
    w.writeInt32(15, page); // pn
    w.writeString(16, 'recom_flist'); // st_type
    w.writeMessage(
      39,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v12,
        bduss: bduss,
        stoken: stoken,
        tbs: tbs,
        zid: zid,
      ),
    );
    w.writeInt32(47, sortType, emitZero: true);
    w.writeInt32(49, loadType);
    w.writeMessage(50, encodeAppPosInfo());
    w.writeMessage(51, encodePbAdParam());
    return _wrapRequestData(w.toBytes());
  }

  static ForumPageResult decodeFrsPageResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    TiebaForum forum = const TiebaForum();
    TiebaPageInfo page = const TiebaPageInfo();
    String tbs = '';
    final threads = <TiebaThread>[];
    final threadIds = <int>[];
    final usersById = <int, TiebaUser>{};
    final tabs = <ForumTab>[];
    final navTabs = <ForumTab>[];

    ProtoReader(data).forEachField((tag, wire, r) {
      switch (tag) {
        case 2: // ForumInfo
          forum = _decodeForumInfo(r.readSubReader());
          return true;
        case 4: // Page
          page = _decodePage(r.readSubReader());
          return true;
        case 5: // Anti
          tbs = _decodeAntiTbs(r.readSubReader());
          return true;
        case 7: // repeated ThreadInfo
          threads.add(_decodeThreadInfo(r.readSubReader()));
          return true;
        case 8: // repeated int64 thread_id_list
          r.readPackedVarints(wire, threadIds);
          return true;
        case 17: // repeated User user_list
          final u = _decodeUser(r.readSubReader());
          if (u.id > 0) usersById[u.id] = u;
          return true;
        case 22: // repeated FrsTabInfo frs_tab_info
          tabs.add(_decodeFrsTabInfo(r.readSubReader()));
          return true;
        case 37: // NavTabInfo nav_tab_info { repeated FrsTabInfo tab = 1; }
          r.readSubReader().forEachField((nt, nw, nr) {
            if (nt == 1 && nw == WireType.lengthDelimited) {
              navTabs.add(_decodeFrsTabInfo(nr.readSubReader()));
              return true;
            }
            return false;
          });
          return true;
        default:
          return false;
      }
    });

    final hydrated = <TiebaThread>[];
    for (final t in threads) {
      if (t.isLive) continue;
      final author = t.author.id > 0
          ? t.author
          : (usersById[t.authorId] ?? t.author);
      hydrated.add(
        t.copyWith(author: author),
      );
    }

    return ForumPageResult(
      forum: forum,
      page: page,
      threads: hydrated,
      threadIds: threadIds,
      tabs: tabs,
      navTabs: navTabs,
      tbs: tbs,
    );
  }

  /// 吧内分区帖子流（Protobuf V12 `frs/generalTabList?cmd=309622`）。
  ///
  /// 老版本客户端才有这条链路：按 `FrsTabInfo` 的 `tab_id` / `tab_type` /
  /// `sort_type` 拉取该分区的一页帖子，用于红框里的「吧友互助 / 交流专区」等分区。
  static Uint8List encodeGeneralTabListRequest({
    required TiebaDevice device,
    required int forumId,
    required ForumTab tab,
    int sortType = -1,
    int page = 1,
    int lastThreadId = 0,
    String bduss = '',
    String stoken = '',
    String tbs = '',
    String zid = '',
  }) {
    final w = ProtoWriter();
    w.writeMessage(
      1,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v12,
        bduss: bduss,
        stoken: stoken,
        tbs: tbs,
        zid: zid,
      ),
    );
    w.writeInt32(2, tab.tabId);
    w.writeUint64(3, forumId);
    w.writeInt32(4, page); // pn
    w.writeInt32(5, 30); // rn
    w.writeInt32(6, device.screenWidth);
    w.writeInt32(7, device.screenHeight);
    w.writeInt32(8, device.screenDensity.round());
    w.writeUint64(9, lastThreadId, emitZero: true);
    w.writeInt32(10, tab.isDefault ? 1 : 0); // is_default_navtab
    w.writeString(11, tab.tabName);
    w.writeInt32(12, tab.isGeneralTab ? 1 : 0); // is_general_tab
    w.writeInt32(13, sortType, emitZero: true);
    w.writeInt32(14, tab.tabType);
    w.writeString(15, '', emitEmpty: true); // ad_ext_params
    w.writeString(16, '', emitEmpty: true); // ad_bear_context
    w.writeInt32(17, 0, emitZero: true); // has_ad_bear
    w.writeString(18, '', emitEmpty: true); // ad_bear_sid
    w.writeDouble(19, 0, emitZero: true); // ad_bear_sid_price
    w.writeInt32(20, 0, emitZero: true); // request_times
    w.writeString(21, '', emitEmpty: true); // frs_common_info
    w.writeInt32(22, 1); // is_newfrs
    w.writeInt32(23, 0, emitZero: true); // is_video_doublerow
    return _wrapRequestData(w.toBytes());
  }

  static ForumTabThreadResult decodeGeneralTabListResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    final threads = <TiebaThread>[];
    final usersById = <int, TiebaUser>{};
    var hasMore = false;
    var sortType = -1;

    ProtoReader(data).forEachField((tag, wire, r) {
      switch (tag) {
        case 1: // repeated ThreadInfo general_list
          threads.add(_decodeThreadInfo(r.readSubReader()));
          return true;
        case 2: // int32 has_more
          hasMore = r.readInt32() != 0;
          return true;
        case 3: // repeated User user_list
          final u = _decodeUser(r.readSubReader());
          if (u.id > 0) usersById[u.id] = u;
          return true;
        case 7: // int32 sort_type
          sortType = r.readInt32();
          return true;
        default:
          return false;
      }
    });

    final hydrated = <TiebaThread>[];
    for (final t in threads) {
      if (t.isLive) continue;
      hydrated.add(
        t.copyWith(
          author: t.author.id > 0
              ? t.author
              : (usersById[t.authorId] ?? t.author),
        ),
      );
    }

    return ForumTabThreadResult(
      threads: hydrated,
      hasMore: hasMore,
      // 游标用 ThreadInfo.id（tid），与 TiebaLite 的 last_thread_id 一致。
      lastThreadId: hydrated.isEmpty ? 0 : hydrated.last.id,
      sortType: sortType,
    );
  }

  static Uint8List encodeThreadListRequest({
    required TiebaDevice device,
    required int forumId,
    required String forumName,
    required List<int> threadIds,
    int page = 1,
    int sortType = 0,
    String bduss = '',
    String stoken = '',
    String tbs = '',
    String zid = '',
  }) {
    final w = ProtoWriter();
    w.writeString(1, threadIds.join(','));
    w.writeUint64(2, forumId);
    w.writeUint32(3, 1); // need_abstract
    w.writeUint32(4, 1); // st_type
    w.writeUint32(5, device.screenWidth);
    w.writeUint32(6, device.screenHeight);
    w.writeUint32(7, 2); // q_type
    w.writeMessage(
      8,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v12,
        bduss: bduss,
        stoken: stoken,
        tbs: tbs,
        zid: zid,
      ),
    );
    w.writeDouble(12, device.screenDensity);
    w.writeInt32(13, page);
    w.writeString(14, forumName);
    w.writeInt32(16, sortType, emitZero: true);
    w.writeMessage(17, encodeAppPosInfo());
    return _wrapRequestData(w.toBytes());
  }

  static List<TiebaThread> decodeThreadListResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    final threads = <TiebaThread>[];
    final usersById = <int, TiebaUser>{};

    ProtoReader(data).forEachField((tag, wire, r) {
      if (tag == 1 && wire == WireType.lengthDelimited) {
        threads.add(_decodeThreadInfo(r.readSubReader()));
        return true;
      }
      if (tag == 2 && wire == WireType.lengthDelimited) {
        final u = _decodeUser(r.readSubReader());
        if (u.id > 0) usersById[u.id] = u;
        return true;
      }
      return false;
    });

    return [
      for (final t in threads)
        if (!t.isLive)
          t.copyWith(
            author: t.author.id > 0
                ? t.author
                : (usersById[t.authorId] ?? t.author),
          ),
    ];
  }

  // ===========================================================================
  // 4. Personalized (首页推荐流, cmd=309264)
  // ===========================================================================

  static Uint8List encodePersonalizedRequest({
    required TiebaDevice device,
    int loadType = 1,
    int page = 1,
    String bduss = '',
    String stoken = '',
    String tbs = '',
    String zid = '',
  }) {
    final w = ProtoWriter();
    w.writeMessage(
      1,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v12,
        bduss: bduss,
        stoken: stoken,
        tbs: tbs,
        zid: zid,
      ),
    );
    w.writeUint32(2, 0, emitZero: true); // tag_code
    w.writeUint32(3, 0, emitZero: true); // need_tags
    w.writeUint32(4, loadType);
    w.writeUint32(5, 15); // page_thread_count
    w.writeUint32(6, page); // pn
    w.writeUint32(7, 0, emitZero: true); // sug_count
    w.writeInt32(8, device.screenWidth);
    w.writeInt32(9, device.screenHeight);
    w.writeDouble(10, device.screenDensity);
    w.writeInt32(11, 1); // q_type
    w.writeUint32(22, 0, emitZero: true); // need_forumlist
    w.writeUint32(23, 1); // new_net_type
    w.writeInt32(26, 0, emitZero: true); // pre_ad_thread_count
    w.writeInt32(27, 0, emitZero: true); // new_install
    w.writeInt32(28, 0, emitZero: true); // request_times
    w.writeMessage(36, encodeAppPosInfo());
    return _wrapRequestData(w.toBytes());
  }

  static PersonalizedPageResult decodePersonalizedResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    final threads = <TiebaThread>[];
    ProtoReader(data).forEachField((tag, wire, r) {
      if (tag == 2 && wire == WireType.lengthDelimited) {
        final t = _decodeThreadInfo(r.readSubReader());
        if (!t.isLive) threads.add(t);
        return true;
      }
      return false;
    });
    return PersonalizedPageResult(threads: threads);
  }

  // ===========================================================================
  // 5. UserLike (关注动态流, cmd=309474, V11)
  // ===========================================================================

  static Uint8List encodeUserLikeRequest({
    required TiebaDevice device,
    String pageTag = '',
    int lastRequestUnix = 0,
    int loadType = 1,
    String bduss = '',
    String stoken = '',
  }) {
    final w = ProtoWriter();
    w.writeMessage(
      1,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v11,
        bduss: bduss,
        stoken: stoken,
      ),
    );
    w.writeString(2, pageTag, emitEmpty: true);
    w.writeUint64(3, lastRequestUnix, emitZero: true);
    w.writeInt32(4, 1); // followType
    w.writeInt32(5, loadType);
    return _wrapRequestData(w.toBytes());
  }

  static ConcernPageResult decodeUserLikeResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    final threads = <TiebaThread>[];
    String pageTag = '';
    bool hasMore = false;
    int requestUnix = 0;

    ProtoReader(data).forEachField((tag, wire, r) {
      switch (tag) {
        case 1:
          // ConcernData { ThreadInfo threadList = 1; }
          r.readSubReader().forEachField((ct, cw, cr) {
            if (ct == 1 && cw == WireType.lengthDelimited) {
              final t = _decodeThreadInfo(cr.readSubReader());
              if (!t.isLive && t.effectiveId > 0) threads.add(t);
              return true;
            }
            return false;
          });
          return true;
        case 2:
          pageTag = r.readString();
          return true;
        case 4:
          hasMore = r.readInt32() != 0;
          return true;
        case 10:
          requestUnix = r.readInt64();
          return true;
        default:
          return false;
      }
    });

    return ConcernPageResult(
      threads: threads,
      pageTag: pageTag,
      hasMore: hasMore,
      requestUnix: requestUnix,
    );
  }

  // ===========================================================================
  // 6. HotThreadList (发现-热议, cmd=309661, V11) & TopicList (cmd=309289, V11)
  // ===========================================================================

  static Uint8List encodeHotThreadListRequest({
    required TiebaDevice device,
    String tabCode = 'all',
    String tabId = '1',
    String bduss = '',
    String stoken = '',
  }) {
    final w = ProtoWriter();
    w.writeMessage(
      1,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v11,
        bduss: bduss,
        stoken: stoken,
      ),
    );
    w.writeString(2, tabId);
    w.writeString(3, tabCode);
    return _wrapRequestData(w.toBytes());
  }

  static HotThreadPageResult decodeHotThreadListResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    final topics = <HotTopicItem>[];
    final threads = <TiebaThread>[];
    final tabs = <ForumTab>[];

    ProtoReader(data).forEachField((tag, wire, r) {
      switch (tag) {
        case 1:
          topics.add(_decodeRecommendTopic(r.readSubReader()));
          return true;
        case 2:
          final t = _decodeThreadInfo(r.readSubReader());
          if (!t.isLive) threads.add(t);
          return true;
        case 3:
          tabs.add(_decodeFrsTabInfo(r.readSubReader()));
          return true;
        default:
          return false;
      }
    });

    return HotThreadPageResult(topics: topics, threads: threads, tabs: tabs);
  }

  static Uint8List encodeTopicListRequest({
    required TiebaDevice device,
    String bduss = '',
    String stoken = '',
  }) {
    final w = ProtoWriter();
    w.writeMessage(
      1,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v11,
        bduss: bduss,
        stoken: stoken,
      ),
    );
    w.writeString(2, 'newbang');
    w.writeString(3, 'all');
    w.writeString(4, '0');
    w.writeInt64(5, 0, emitZero: true);
    return _wrapRequestData(w.toBytes());
  }

  static List<HotTopicItem> decodeTopicListResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    final topics = <HotTopicItem>[];

    void parseModule(ProtoReader mr) {
      mr.forEachField((mt, mw, r) {
        if (mt == 2 && mw == WireType.lengthDelimited) {
          topics.add(_decodeTopicListItem(r.readSubReader()));
          return true;
        }
        return false;
      });
    }

    ProtoReader(data).forEachField((tag, wire, r) {
      switch (tag) {
        case 1: // topic_bang
        case 2: // topic_manual
          parseModule(r.readSubReader());
          return true;
        case 8: // repeated NewTopicList topic_list
          topics.add(_decodeNewTopicItem(r.readSubReader()));
          return true;
        default:
          return false;
      }
    });
    return topics;
  }

  // ===========================================================================
  // 7. Profile (用户主页, cmd=303012), UserPost (cmd=303002), GetUserInfo (303024)
  // ===========================================================================

  static Uint8List encodeProfileRequest({
    required TiebaDevice device,
    int? selfUid,
    int? targetUid,
    String targetPortrait = '',
    int page = 1,
    String bduss = '',
    String stoken = '',
    String tbs = '',
    String zid = '',
  }) {
    final isGuest = targetUid != null && targetUid != selfUid;
    final w = ProtoWriter();
    if (selfUid != null && selfUid > 0) w.writeInt64(1, selfUid);
    w.writeUint32(2, 1); // need_post_count
    if (targetUid != null && targetUid > 0) w.writeInt64(3, targetUid);
    w.writeUint32(4, isGuest ? 1 : 0, emitZero: true);
    w.writeUint32(6, page);
    w.writeUint32(7, 20);
    w.writeUint32(8, 1); // has_plist
    w.writeMessage(
      9,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v12,
        bduss: bduss,
        stoken: stoken,
        tbs: tbs,
        zid: zid,
      ),
    );
    w.writeUint32(10, device.screenWidth);
    w.writeUint32(11, device.screenHeight);
    w.writeUint32(12, 0, emitZero: true);
    w.writeDouble(13, device.screenDensity);
    w.writeInt32(14, 1); // is_from_usercenter
    w.writeInt32(15, page);
    if (targetPortrait.isNotEmpty) w.writeString(16, targetPortrait);
    return _wrapRequestData(w.toBytes());
  }

  static UserProfileResult decodeProfileResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    TiebaUser user = const TiebaUser();
    String tbs = '';
    final posts = <UserPostItem>[];

    ProtoReader(data).forEachField((tag, wire, r) {
      switch (tag) {
        case 1:
          user = _decodeUser(r.readSubReader());
          return true;
        case 2:
          tbs = _decodeAntiTbs(r.readSubReader());
          return true;
        case 4:
          posts.add(_decodePostInfoList(r.readSubReader()));
          return true;
        default:
          return false;
      }
    });

    return UserProfileResult(user: user, tbs: tbs, posts: posts);
  }

  /// 用户帖子 / 回复列表。
  ///
  /// [shape] 用来试不同的请求形状——「回复」列表在不同账号上对
  /// `stoken` / `is_view_card` 的判定不一致（见 [TiebaApi.userPosts]）：
  /// - 0：默认（不带 stoken，带 is_thread / subtype / is_view_card / q_type）
  /// - 1：与 TiebaLite 一致（带 stoken，其余同 0）
  /// - 2：与 aiotieba 一致（只带 uid / need_content / pn / rn）
  static Uint8List encodeUserPostRequest({
    required TiebaDevice device,
    required int uid,
    int page = 1,
    bool isThread = true,
    String bduss = '',
    String stoken = '',
    String tbs = '',
    String zid = '',
    int shape = 0,
  }) {
    final w = ProtoWriter();
    w.writeInt64(1, uid);
    w.writeUint32(2, 20); // rn
    if (shape != 2) {
      w.writeUint32(4, isThread ? 1 : 0, emitZero: true); // is_thread
    }
    w.writeUint32(5, 1); // need_content
    if (shape != 2 && !isThread) w.writeUint32(9, 0, emitZero: true); // subtype
    w.writeUint32(26, page); // pn
    w.writeMessage(
      27,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v12,
        bduss: bduss,
        // 「回复」列表带 stoken 有时会被服务端当成「视频」页签、只回空列表，
        // 帖子列表则相反，必须带 stoken 才是本人的帖。
        stoken: (isThread || shape == 1) ? stoken : '',
        tbs: tbs,
        zid: zid,
      ),
    );
    if (shape != 2) {
      w.writeInt32(29, device.screenWidth);
      w.writeInt32(30, device.screenHeight);
      w.writeDouble(31, device.screenDensity);
      w.writeInt32(32, 1); // q_type
      // is_view_card 是非 optional 字段，0 不写（与 TiebaLite 的报文一致）。
      if (isThread) w.writeInt32(33, 1);
    }
    return _wrapRequestData(w.toBytes());
  }

  static List<UserPostItem> decodeUserPostResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    final list = <UserPostItem>[];
    ProtoReader(data).forEachField((tag, wire, r) {
      if (tag == 1 && wire == WireType.lengthDelimited) {
        list.add(_decodePostInfoList(r.readSubReader()));
        return true;
      }
      return false;
    });
    return list;
  }

  static Uint8List encodeGetUserInfoRequest({
    required TiebaDevice device,
    required int uid,
    String bduss = '',
    String stoken = '',
    String zid = '',
  }) {
    final w = ProtoWriter();
    w.writeMessage(
      1,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v12,
        bduss: bduss,
        stoken: stoken,
        zid: zid,
      ),
    );
    w.writeInt64(2, uid);
    w.writeInt32(3, device.screenWidth);
    return _wrapRequestData(w.toBytes());
  }

  static TiebaUser decodeGetUserInfoResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    TiebaUser user = const TiebaUser();
    ProtoReader(data).forEachField((tag, wire, r) {
      if (tag == 1 && wire == WireType.lengthDelimited) {
        user = _decodeUser(r.readSubReader());
        return true;
      }
      return false;
    });
    return user;
  }

  // ===========================================================================
  // 8. GetForumDetail (cmd=303021), ForumRuleDetail (cmd=309690), SearchSug (cmd=309438)
  // ===========================================================================

  static Uint8List encodeForumIdRequest({
    required TiebaDevice device,
    required int forumId,
    String bduss = '',
    String stoken = '',
    String tbs = '',
    String zid = '',
  }) {
    final w = ProtoWriter();
    w.writeInt64(1, forumId);
    w.writeMessage(
      2,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v12,
        bduss: bduss,
        stoken: stoken,
        tbs: tbs,
        zid: zid,
      ),
    );
    return _wrapRequestData(w.toBytes());
  }

  static ForumDetailInfo decodeGetForumDetailResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    int forumId = 0;
    String forumName = '';
    String avatar = '';
    String slogan = '';
    int memberCount = 0;
    int threadCount = 0;
    bool isLike = false;
    String lv1 = '';
    String lv2 = '';
    final introBuf = StringBuffer();

    ProtoReader(data).forEachField((tag, wire, r) {
      if (tag == 1 && wire == WireType.lengthDelimited) {
        r.readSubReader().forEachField((ft, fw, fr) {
          switch (ft) {
            case 1:
              avatar = fr.readString();
              return true;
            case 2:
              forumId = fr.readInt64();
              return true;
            case 3:
              forumName = fr.readString();
              return true;
            case 4:
              isLike = fr.readUint32() != 0;
              return true;
            case 5:
              memberCount = fr.readUint32();
              return true;
            case 6:
              threadCount = fr.readUint32();
              return true;
            case 7:
              slogan = fr.readString();
              return true;
            case 8:
              final node = _decodePbContent(fr.readSubReader());
              if (node is RichTextNode) introBuf.write(node.text);
              return true;
            case 18:
              lv1 = fr.readString();
              return true;
            case 19:
              lv2 = fr.readString();
              return true;
            default:
              return false;
          }
        });
        return true;
      }
      return false;
    });

    return ForumDetailInfo(
      forumId: forumId,
      forumName: forumName,
      avatar: avatar,
      slogan: slogan,
      memberCount: memberCount,
      threadCount: threadCount,
      isLike: isLike,
      lv1Name: lv1,
      lv2Name: lv2,
      intro: introBuf.toString().trim(),
    );
  }

  static ForumRuleDetailInfo decodeForumRuleDetailResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    String title = '';
    String preface = '';
    String publishTime = '';
    final rules = <ForumRuleEntry>[];

    ProtoReader(data).forEachField((tag, wire, r) {
      switch (tag) {
        case 3:
          title = r.readString();
          return true;
        case 4:
          preface = r.readString();
          return true;
        case 5:
          String rt = '';
          final nodes = <TiebaRichNode>[];
          r.readSubReader().forEachField((ft, fw, fr) {
            if (ft == 1) {
              rt = fr.readString();
              return true;
            }
            if (ft == 2) {
              final n = _decodePbContent(fr.readSubReader());
              if (n != null) nodes.add(n);
              return true;
            }
            return false;
          });
          rules.add(ForumRuleEntry(title: rt, content: nodes));
          return true;
        case 10:
          publishTime = r.readString();
          return true;
        default:
          return false;
      }
    });

    return ForumRuleDetailInfo(
      title: title,
      preface: preface,
      publishTime: publishTime,
      rules: rules,
    );
  }

  static Uint8List encodeSearchSugRequest({
    required TiebaDevice device,
    required String keyword,
    bool isForum = false,
    String bduss = '',
    String stoken = '',
    String zid = '',
  }) {
    final w = ProtoWriter();
    w.writeMessage(
      1,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v12,
        bduss: bduss,
        stoken: stoken,
        zid: zid,
      ),
    );
    w.writeString(2, keyword);
    w.writeString(3, isForum ? '1' : '0');
    return _wrapRequestData(w.toBytes());
  }

  static SearchSugResult decodeSearchSugResponse(Uint8List rawBytes) {
    final data = unwrapResponse(rawBytes);
    final suggestions = <String>[];
    SearchForumItem? forumCard;

    ProtoReader(data).forEachField((tag, wire, r) {
      if (tag == 2 && wire == WireType.lengthDelimited) {
        final s = r.readString();
        if (s.isNotEmpty) suggestions.add(s);
        return true;
      }
      if (tag == 4 && wire == WireType.lengthDelimited) {
        int fid = 0;
        String fname = '';
        String avatar = '';
        String slogan = '';
        int mCount = 0;
        int tCount = 0;
        bool liked = false;
        r.readSubReader().forEachField((ft, fw, fr) {
          switch (ft) {
            case 1:
              avatar = fr.readString();
              return true;
            case 2:
              fid = fr.readInt64();
              return true;
            case 3:
              fname = fr.readString();
              return true;
            case 4:
              liked = fr.readUint32() != 0;
              return true;
            case 5:
              mCount = fr.readUint32();
              return true;
            case 6:
              tCount = fr.readUint32();
              return true;
            case 7:
              slogan = fr.readString();
              return true;
            default:
              return false;
          }
        });
        if (fname.isNotEmpty) {
          forumCard = SearchForumItem(
            forumId: fid,
            forumName: fname,
            avatar: avatar,
            slogan: slogan,
            concernNum: '$mCount',
            postNum: '$tCount',
            isLiked: liked,
          );
        }
        return true;
      }
      return false;
    });

    return SearchSugResult(suggestions: suggestions, forumCard: forumCard);
  }

  // ===========================================================================
  // 9. Write Ops: AddPost (cmd=309731), AddThread (cmd=309730), AddPollPost (cmd=309006)
  // ===========================================================================

  static Uint8List encodeAddPostRequest({
    required TiebaDevice device,
    required int forumId,
    required String forumName,
    required int threadId,
    required String content,
    required String tbs,
    required String bduss,
    required String stoken,
    String zid = '',
    String nameShow = '',
    int? quotePostId,
    int? subPostId,
    int? replyUid,
  }) {
    final w = ProtoWriter();
    w.writeMessage(
      1,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v12Post,
        bduss: bduss,
        stoken: stoken,
        tbs: tbs,
        zid: zid,
        isPost: true,
      ),
    );
    w.writeString(4, tbs);
    w.writeString(6, '1'); // anonymous
    w.writeString(7, '0'); // can_no_forum
    w.writeString(8, '0'); // is_feedback
    w.writeString(9, '0'); // takephoto_num
    w.writeString(10, '0'); // entrance_type
    w.writeString(16, '12'); // vcode_tag
    w.writeString(18, '1'); // new_vcode
    w.writeString(19, content);
    if (replyUid != null && replyUid > 0) w.writeString(20, '$replyUid');
    w.writeString(26, '$forumId');
    w.writeString(28, '', emitEmpty: true); // v_fid
    w.writeString(29, '', emitEmpty: true); // v_fname
    w.writeString(30, forumName);
    w.writeString(31, '0'); // is_barrage
    w.writeString(32, '0'); // barrage_time
    w.writeString(45, '$threadId');
    if (quotePostId != null && quotePostId > 0) {
      w.writeString(46, '$quotePostId'); // quote_id
      w.writeString(49, '$quotePostId'); // repostid
    }
    w.writeString(47, '0'); // is_twzhibo_thread
    w.writeString(48, '0'); // floor_num
    if (subPostId != null && subPostId > 0) {
      w.writeString(50, '$subPostId');
    }
    w.writeString(51, '0'); // is_ad
    w.writeString(52, '0'); // is_addition
    w.writeString(53, '0'); // is_giftpost
    if (subPostId == null || subPostId <= 0) {
      w.writeString(55, quotePostId != null && quotePostId > 0 ? '0' : '13');
    }
    if (nameShow.isNotEmpty) w.writeString(58, nameShow);
    w.writeString(60, '0'); // is_pictxt
    w.writeInt32(64, 0, emitZero: true); // show_custom_figure
    w.writeInt32(67, 0, emitZero: true); // is_show_bless
    return _wrapRequestData(w.toBytes());
  }

  static Uint8List encodeAddThreadRequest({
    required TiebaDevice device,
    required int forumId,
    required String forumName,
    required String title,
    required String content,
    required String tbs,
    required String bduss,
    required String stoken,
    String zid = '',
    String nameShow = '',
  }) {
    final w = ProtoWriter();
    w.writeMessage(
      1,
      encodeCommonRequest(
        device: device,
        clientVersion: TiebaClientVersion.v12Post,
        bduss: bduss,
        stoken: stoken,
        tbs: tbs,
        zid: zid,
        isPost: true,
      ),
    );
    w.writeString(4, tbs);
    w.writeString(6, '1'); // anonymous
    w.writeString(7, '0'); // can_no_forum
    w.writeString(8, '0'); // is_feedback
    w.writeString(9, '0'); // takephoto_num
    w.writeString(10, '0'); // entrance_type
    w.writeString(16, '12'); // vcode_tag
    w.writeString(18, '1'); // new_vcode
    w.writeString(19, content);
    w.writeString(26, '$forumId');
    w.writeString(27, forumName);
    w.writeString(29, '1'); // is_hide
    w.writeString(38, title);
    w.writeString(41, title.trim().isEmpty ? '1' : '0'); // is_ntitle
    if (nameShow.isNotEmpty) w.writeString(75, nameShow);
    w.writeString(77, '0'); // is_pictxt
    w.writeInt32(80, 0, emitZero: true);
    w.writeInt32(87, 0, emitZero: true);
    return _wrapRequestData(w.toBytes());
  }

  static Uint8List encodeAddPollPostRequest({
    required int forumId,
    required int threadId,
    required List<int> optionIds,
  }) {
    final w = ProtoWriter();
    w.writeUint64(1, threadId);
    w.writeString(2, optionIds.join(','));
    w.writeUint64(4, forumId);
    return _wrapRequestData(w.toBytes());
  }

  // ===========================================================================
  // Internal Message Decoders
  // ===========================================================================

  static String _decodeAntiTbs(ProtoReader r) {
    String tbs = '';
    r.forEachField((tag, wire, reader) {
      if (tag == 1 && wire == WireType.lengthDelimited) {
        tbs = reader.readString();
        return true;
      }
      return false;
    });
    return tbs;
  }

  static TiebaPageInfo _decodePage(ProtoReader r) {
    int pageSize = 30;
    int offset = 0;
    int currentPage = 1;
    int totalCount = 0;
    int totalPage = 1;
    bool hasMore = false;
    bool hasPrev = false;
    int newTotalPage = 0;

    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          pageSize = reader.readInt32();
          return true;
        case 2:
          offset = reader.readInt32();
          return true;
        case 3:
          currentPage = reader.readInt32();
          return true;
        case 4:
          totalCount = reader.readInt32();
          return true;
        case 5:
          totalPage = reader.readInt32();
          return true;
        case 6:
          hasMore = reader.readInt32() != 0;
          return true;
        case 7:
          hasPrev = reader.readInt32() != 0;
          return true;
        case 14:
          newTotalPage = reader.readInt32();
          return true;
        default:
          return false;
      }
    });

    return TiebaPageInfo(
      pageSize: pageSize,
      offset: offset,
      currentPage: currentPage,
      totalCount: totalCount,
      totalPage: totalPage,
      hasMore: hasMore,
      hasPrev: hasPrev,
      newTotalPage: newTotalPage,
    );
  }

  static TiebaForum _decodeSimpleForum(ProtoReader r) {
    int id = 0;
    String name = '';
    String avatar = '';
    int memberNum = 0;
    int postNum = 0;
    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          id = reader.readInt64();
          return true;
        case 2:
          name = reader.readString();
          return true;
        case 4:
          avatar = reader.readString();
          return true;
        case 12:
          memberNum = reader.readInt32();
          return true;
        case 13:
          postNum = reader.readInt32();
          return true;
        default:
          return false;
      }
    });
    return TiebaForum(
      id: id,
      name: name,
      avatar: avatar,
      memberNum: memberNum,
      postNum: postNum,
    );
  }

  static TiebaForum _decodeForumInfo(ProtoReader r) {
    int id = 0;
    String name = '';
    String firstClass = '';
    String secondClass = '';
    bool isLike = false;
    bool isSign = false;
    int userLevel = 0;
    String levelName = '';
    int memberNum = 0;
    int threadNum = 0;
    int postNum = 0;
    int curScore = 0;
    int levelUpScore = 0;
    int contSignNum = 0;
    int signRank = 0;
    String avatar = '';
    String slogan = '';
    final classifies = <ForumClassify>[];

    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          id = reader.readInt64();
          return true;
        case 2:
          name = reader.readString();
          return true;
        case 3:
          firstClass = reader.readString();
          return true;
        case 4:
          secondClass = reader.readString();
          return true;
        case 6:
          isLike = reader.readInt32() != 0;
          return true;
        case 7:
          userLevel = reader.readInt32();
          return true;
        case 8:
          levelName = reader.readString();
          return true;
        case 9:
          memberNum = reader.readInt32();
          return true;
        case 10:
          threadNum = reader.readInt32();
          return true;
        case 11:
          postNum = reader.readInt32();
          return true;
        case 13:
          curScore = reader.readInt32();
          return true;
        case 14:
          levelUpScore = reader.readInt32();
          return true;
        case 15: // SignInfo { SignUser user_info = 1; }
          reader.readSubReader().forEachField((st, sw, sr) {
            if (st == 1 && sw == WireType.lengthDelimited) {
              sr.readSubReader().forEachField((ut, uw, ur) {
                switch (ut) {
                  case 2:
                    isSign = ur.readInt32() != 0;
                    return true;
                  case 3:
                    signRank = ur.readInt32();
                    return true;
                  case 5:
                    contSignNum = ur.readInt32();
                    return true;
                  default:
                    return false;
                }
              });
              return true;
            }
            return false;
          });
          return true;
        case 21: // repeated Classify good_classify
          String cname = '';
          int cid = 0;
          reader.readSubReader().forEachField((ct, cw, cr) {
            if (ct == 1) {
              cname = cr.readString();
              return true;
            }
            if (ct == 2) {
              cid = cr.readInt64();
              return true;
            }
            return false;
          });
          if (cname.isNotEmpty) {
            classifies.add(ForumClassify(id: cid, name: cname));
          }
          return true;
        case 24:
          avatar = reader.readString();
          return true;
        case 25:
          slogan = reader.readString();
          return true;
        default:
          return false;
      }
    });

    return TiebaForum(
      id: id,
      name: name,
      avatar: avatar,
      slogan: slogan,
      firstClass: firstClass,
      secondClass: secondClass,
      isLike: isLike,
      isSign: isSign,
      userLevel: userLevel,
      levelName: levelName,
      memberNum: memberNum,
      threadNum: threadNum,
      postNum: postNum,
      curScore: curScore,
      levelUpScore: levelUpScore,
      contSignNum: contSignNum,
      signRank: signRank,
      goodClassifies: classifies,
    );
  }

  static TiebaUser _decodeUser(ProtoReader r) {
    int id = 0;
    String name = '';
    String nameShow = '';
    String portrait = '';
    int levelId = 0;
    String levelName = '';
    bool isBawu = false;
    String bawuType = '';
    String ipAddress = '';
    String tiebaUid = '';
    int sex = 0;
    String intro = '';
    int fansNum = 0;
    int concernNum = 0;
    int postNum = 0;
    int threadNum = 0;
    int myLikeNum = 0;
    int totalAgreeNum = 0;
    bool hasConcerned = false;
    bool isFans = false;
    String tbAge = '';
    String bgPic = '';
    bool isDefaultAvatar = false;

    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 2:
          id = reader.readInt64();
          return true;
        case 3:
          name = reader.readString();
          return true;
        case 4:
          nameShow = reader.readString();
          return true;
        case 5:
          portrait = reader.readString();
          return true;
        case 23:
          levelId = reader.readInt32();
          return true;
        case 25:
          isBawu = reader.readInt32() != 0;
          return true;
        case 26:
          bawuType = reader.readString();
          return true;
        case 30:
          fansNum = reader.readInt32();
          return true;
        case 31:
          concernNum = reader.readInt32();
          return true;
        case 32:
          sex = reader.readInt32();
          return true;
        case 33:
          myLikeNum = reader.readInt32();
          return true;
        case 34:
          intro = reader.readString();
          return true;
        case 35:
          hasConcerned = reader.readInt32() != 0;
          return true;
        case 37:
          postNum = reader.readInt32();
          return true;
        case 38:
          tbAge = reader.readString();
          return true;
        case 42:
          if (sex == 0) sex = reader.readInt32();
          return true;
        case 58:
          bgPic = reader.readString();
          return true;
        case 87:
          threadNum = reader.readInt32();
          return true;
        case 91:
          isFans = reader.readInt32() != 0;
          return true;
        case 106:
          isDefaultAvatar = reader.readInt32() != 0;
          return true;
        case 118:
          totalAgreeNum = reader.readUint32();
          return true;
        case 120:
          tiebaUid = reader.readString();
          return true;
        case 125:
          levelName = reader.readString();
          return true;
        case 127:
          ipAddress = reader.readString();
          return true;
        default:
          return false;
      }
    });

    return TiebaUser(
      id: id,
      name: name,
      nameShow: nameShow,
      portrait: portrait,
      levelId: levelId,
      levelName: levelName,
      isBawu: isBawu,
      bawuType: bawuType,
      ipAddress: ipAddress,
      tiebaUid: tiebaUid,
      sex: sex,
      intro: intro,
      fansNum: fansNum,
      concernNum: concernNum,
      postNum: postNum,
      threadNum: threadNum,
      myLikeNum: myLikeNum,
      totalAgreeNum: totalAgreeNum,
      hasConcerned: hasConcerned,
      isFans: isFans,
      tbAge: tbAge,
      bgPic: bgPic,
      isDefaultAvatar: isDefaultAvatar,
    );
  }

  static TiebaAgree _decodeAgree(ProtoReader r) {
    int agreeNum = 0;
    int hasAgree = 0;
    int agreeType = 0;
    int disagreeNum = 0;
    int diffAgreeNum = 0;
    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          agreeNum = reader.readInt64();
          return true;
        case 2:
          hasAgree = reader.readInt32();
          return true;
        case 3:
          agreeType = reader.readInt32();
          return true;
        case 4:
          disagreeNum = reader.readInt64();
          return true;
        case 5:
          diffAgreeNum = reader.readInt64();
          return true;
        default:
          return false;
      }
    });
    return TiebaAgree(
      agreeNum: agreeNum,
      disagreeNum: disagreeNum,
      diffAgreeNum: diffAgreeNum,
      hasAgree: hasAgree,
      agreeType: agreeType,
    );
  }

  static TiebaVideo _decodeVideoInfo(ProtoReader r) {
    String md5 = '';
    String url = '';
    int duration = 0;
    int width = 0;
    int height = 0;
    String thumb = '';
    int thumbW = 0;
    int thumbH = 0;
    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          md5 = reader.readString();
          return true;
        case 2:
          url = reader.readString();
          return true;
        case 3:
          duration = reader.readUint32();
          return true;
        case 4:
          width = reader.readUint32();
          return true;
        case 5:
          height = reader.readUint32();
          return true;
        case 6:
          thumb = reader.readString();
          return true;
        case 7:
          thumbW = reader.readUint32();
          return true;
        case 8:
          thumbH = reader.readUint32();
          return true;
        default:
          return false;
      }
    });
    return TiebaVideo(
      md5: md5,
      videoUrl: url,
      duration: duration,
      width: width,
      height: height,
      thumbnailUrl: thumb,
      thumbnailWidth: thumbW,
      thumbnailHeight: thumbH,
    );
  }

  static TiebaPoll _decodePollInfo(ProtoReader r) {
    int type = 0;
    bool isMulti = false;
    int totalNum = 0;
    bool isPolled = false;
    String polledValue = '';
    String tips = '';
    int endTime = 0;
    int status = 0;
    int totalPoll = 0;
    String title = '';
    final options = <TiebaPollOption>[];

    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          type = reader.readInt32();
          return true;
        case 2:
          isMulti = reader.readInt32() != 0;
          return true;
        case 3:
          totalNum = reader.readInt64();
          return true;
        case 5:
          isPolled = reader.readInt32() != 0;
          return true;
        case 6:
          polledValue = reader.readString();
          return true;
        case 7:
          tips = reader.readString();
          return true;
        case 8:
          endTime = reader.readInt32();
          return true;
        case 9:
          int oid = 0;
          int onum = 0;
          String otext = '';
          String oimg = '';
          reader.readSubReader().forEachField((ot, ow, or) {
            switch (ot) {
              case 1:
                oid = or.readInt32();
                return true;
              case 2:
                onum = or.readInt64();
                return true;
              case 3:
                otext = or.readString();
                return true;
              case 4:
                oimg = or.readString();
                return true;
              default:
                return false;
            }
          });
          options.add(
            TiebaPollOption(id: oid, text: otext, num: onum, image: oimg),
          );
          return true;
        case 10:
          status = reader.readInt32();
          return true;
        case 11:
          totalPoll = reader.readInt64();
          return true;
        case 12:
          title = reader.readString();
          return true;
        default:
          return false;
      }
    });

    return TiebaPoll(
      type: type,
      isMulti: isMulti,
      totalNum: totalNum,
      totalPoll: totalPoll,
      isPolled: isPolled,
      polledValue: polledValue,
      tips: tips,
      title: title,
      endTime: endTime,
      status: status,
      options: options,
    );
  }

  static RichImageNode? _decodeMedia(ProtoReader r) {
    int type = 0;
    String bigPic = '';
    String srcPic = '';
    int width = 0;
    int height = 0;
    String originPic = '';
    int originSize = 0;
    String dynamicPic = '';
    bool showOriginal = false;

    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          type = reader.readInt32();
          return true;
        case 3:
          bigPic = reader.readString();
          return true;
        case 8:
          srcPic = reader.readString();
          return true;
        case 10:
          width = reader.readUint32();
          return true;
        case 11:
          height = reader.readUint32();
          return true;
        case 15:
          originPic = reader.readString();
          return true;
        case 16:
          originSize = reader.readUint32();
          return true;
        case 18:
          dynamicPic = reader.readString();
          return true;
        case 20:
          showOriginal = reader.readUint32() != 0;
          return true;
        default:
          return false;
      }
    });

    if (type != 3 && type != 20 && srcPic.isEmpty && bigPic.isEmpty && originPic.isEmpty) {
      return null;
    }
    final display = _firstNonEmpty([bigPic, srcPic, dynamicPic, originPic]);
    final origin = _firstNonEmpty([originPic, bigPic, srcPic, dynamicPic]);
    if (display.isEmpty) return null;
    return RichImageNode(
      url: display,
      originUrl: origin,
      width: width,
      height: height,
      originSize: originSize,
      showOriginal: showOriginal,
    );
  }

  static TiebaRichNode? _decodePbContent(ProtoReader r) {
    int type = 0;
    String text = '';
    String link = '';
    String src = '';
    String bsize = '';
    String bigSrc = '';
    String cdnSrc = '';
    String bigCdnSrc = '';
    String c = '';
    String voiceMd5 = '';
    int duringTime = 0;
    int uid = 0;
    String dynamic = '';
    int width = 0;
    int height = 0;
    String originSrc = '';
    int originSize = 0;
    bool showOriginal = false;
    String cdnSrcActive = '';

    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          type = reader.readInt32();
          return true;
        case 2:
          text = reader.readString();
          return true;
        case 3:
          link = reader.readString();
          return true;
        case 4:
          src = reader.readString();
          return true;
        case 5:
          bsize = reader.readString();
          return true;
        case 6:
          bigSrc = reader.readString();
          return true;
        case 8:
          cdnSrc = reader.readString();
          return true;
        case 9:
          bigCdnSrc = reader.readString();
          return true;
        case 11:
          c = reader.readString();
          return true;
        case 12:
          voiceMd5 = reader.readString();
          return true;
        case 13:
          duringTime = reader.readUint32();
          return true;
        case 15:
          uid = reader.readInt64();
          return true;
        case 16:
          dynamic = reader.readString();
          return true;
        case 18:
          width = reader.readUint32();
          return true;
        case 19:
          height = reader.readUint32();
          return true;
        case 25:
          originSrc = reader.readString();
          return true;
        case 27:
          originSize = reader.readUint32();
          return true;
        case 35:
          showOriginal = reader.readUint32() != 0;
          return true;
        case 36:
          cdnSrcActive = reader.readString();
          return true;
        default:
          return false;
      }
    });

    final (bw, bh) = parseBsize(bsize);
    final w = width > 0 ? width : bw;
    final h = height > 0 ? height : bh;

    switch (type) {
      case 0:
      case 9:
      case 27:
      case 35:
      case 40:
        return text.isEmpty ? null : RichTextNode(text);
      case 1:
        return RichLinkNode(
          label: text.isNotEmpty ? text : link,
          url: link.isNotEmpty ? link : text,
        );
      case 2:
        return RichEmoticonNode(id: text, name: c.isNotEmpty ? c : text);
      case 3:
      case 20:
        final display = _firstNonEmpty([
          bigCdnSrc,
          cdnSrcActive,
          cdnSrc,
          bigSrc,
          dynamic,
          originSrc,
          src,
        ]);
        final origin = _firstNonEmpty([
          originSrc,
          bigCdnSrc,
          bigSrc,
          dynamic,
          cdnSrc,
          cdnSrcActive,
          src,
        ]);
        if (display.isEmpty) return null;
        return RichImageNode(
          url: display,
          originUrl: origin,
          width: w,
          height: h,
          originSize: originSize,
          showOriginal: showOriginal,
        );
      case 4:
        return RichAtNode(text: text, uid: uid);
      case 5:
        return RichVideoNode(
          coverUrl: src.isNotEmpty ? src : link,
          videoUrl: link,
          webUrl: text,
          width: w,
          height: h,
        );
      case 10:
        return RichVoiceNode(md5: voiceMd5, durationMs: duringTime);
      default:
        if (text.isNotEmpty) return RichTextNode(text);
        return null;
    }
  }

  static TiebaThread _decodeThreadInfo(ProtoReader r) {
    int id = 0;
    int threadId = 0;
    String title = '';
    int replyNum = 0;
    int viewNum = 0;
    String lastTimeStr = '';
    int lastTimeInt = 0;
    bool isTop = false;
    bool isGood = false;
    TiebaUser author = const TiebaUser();
    final absTextBuf = StringBuffer();
    final images = <RichImageNode>[];
    int forumId = 0;
    String forumName = '';
    String forumAvatar = '';
    bool isNoTitle = false;
    int firstPostId = 0;
    int createTime = 0;
    int collectStatus = 0;
    int authorId = 0;
    String pids = '';
    TiebaPoll? poll;
    TiebaVideo? video;
    final richTitle = <TiebaRichNode>[];
    final richAbstract = <TiebaRichNode>[];
    bool isLive = false;
    int agreeNum = 0;
    TiebaAgree? agree;
    int shareNum = 0;
    int hotNum = 0;

    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          id = reader.readInt64();
          return true;
        case 2:
          threadId = reader.readInt64();
          return true;
        case 3:
          title = reader.readString();
          return true;
        case 4:
          replyNum = reader.readInt32();
          return true;
        case 5:
          viewNum = reader.readInt32();
          return true;
        case 6:
          lastTimeStr = reader.readString();
          return true;
        case 7:
          lastTimeInt = reader.readInt32();
          return true;
        case 9:
          isTop = reader.readInt32() != 0;
          return true;
        case 10:
          isGood = reader.readInt32() != 0;
          return true;
        case 18:
          author = _decodeUser(reader.readSubReader());
          return true;
        case 21: // repeated Abstract _abstract
          reader.readSubReader().forEachField((at, aw, ar) {
            if (at == 2) {
              absTextBuf.write(ar.readString());
              return true;
            }
            return false;
          });
          return true;
        case 22: // repeated Media
          final img = _decodeMedia(reader.readSubReader());
          if (img != null) images.add(img);
          return true;
        case 27:
          forumId = reader.readInt64();
          return true;
        case 28:
          forumName = reader.readString();
          return true;
        case 38:
          isNoTitle = reader.readInt32() != 0;
          return true;
        case 40:
          firstPostId = reader.readInt64();
          return true;
        case 45:
          createTime = reader.readInt32();
          return true;
        case 50:
          collectStatus = reader.readInt32();
          return true;
        case 56:
          authorId = reader.readInt64();
          return true;
        case 61:
          pids = reader.readString();
          return true;
        case 74:
          poll = _decodePollInfo(reader.readSubReader());
          return true;
        case 79:
          video = _decodeVideoInfo(reader.readSubReader());
          return true;
        case 111:
          final n = _decodePbContent(reader.readSubReader());
          if (n != null) richTitle.add(n);
          return true;
        case 112:
        case 142:
          final n = _decodePbContent(reader.readSubReader());
          if (n != null) {
            richAbstract.add(n);
            if (n is RichImageNode && images.isEmpty) images.add(n);
          }
          return true;
        case 113: // ala_info (直播贴过滤)
          final sub = reader.readBytes();
          if (sub.isNotEmpty) isLive = true;
          return true;
        case 124:
          agreeNum = reader.readInt32();
          return true;
        case 126:
          agree = _decodeAgree(reader.readSubReader());
          return true;
        case 135:
          shareNum = reader.readInt64();
          return true;
        case 155: // SimpleForum forumInfo
          final sf = _decodeSimpleForum(reader.readSubReader());
          if (forumId == 0) forumId = sf.id;
          if (forumName.isEmpty) forumName = sf.name;
          forumAvatar = sf.avatar;
          return true;
        case 182:
          hotNum = reader.readInt32();
          return true;
        default:
          return false;
      }
    });

    final finalAgree = agree ?? TiebaAgree(agreeNum: agreeNum);

    return TiebaThread(
      id: id,
      threadId: threadId > 0 ? threadId : id,
      title: title,
      abstractText: absTextBuf.toString().trim(),
      richTitle: richTitle,
      richAbstract: richAbstract,
      images: images,
      video: video?.isValid == true ? video : null,
      poll: poll,
      author: author,
      authorId: authorId > 0 ? authorId : author.id,
      forumId: forumId,
      forumName: forumName,
      forumAvatar: forumAvatar,
      replyNum: replyNum,
      viewNum: viewNum,
      shareNum: shareNum,
      agree: finalAgree,
      createTime: createTime,
      lastTimeInt: lastTimeInt,
      lastTimeStr: lastTimeStr,
      isTop: isTop,
      isGood: isGood,
      isNoTitle: isNoTitle,
      firstPostId: firstPostId,
      pids: pids,
      collectStatus: collectStatus,
      isLive: isLive,
      hotNum: hotNum,
    );
  }

  static TiebaSubPost _decodeSubPost(ProtoReader r) {
    int id = 0;
    final content = <TiebaRichNode>[];
    int time = 0;
    int authorId = 0;
    TiebaUser author = const TiebaUser();
    TiebaAgree agree = const TiebaAgree();

    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          id = reader.readInt64();
          return true;
        case 2:
          final n = _decodePbContent(reader.readSubReader());
          if (n != null) content.add(n);
          return true;
        case 3:
          time = reader.readUint32();
          return true;
        case 4:
          authorId = reader.readInt64();
          return true;
        case 7:
          author = _decodeUser(reader.readSubReader());
          return true;
        case 9:
          agree = _decodeAgree(reader.readSubReader());
          return true;
        default:
          return false;
      }
    });

    return TiebaSubPost(
      id: id,
      content: content,
      time: time,
      authorId: authorId > 0 ? authorId : author.id,
      author: author,
      agree: agree,
    );
  }

  static TiebaPost _decodePost(ProtoReader r) {
    int id = 0;
    String title = '';
    int floor = 0;
    int time = 0;
    final content = <TiebaRichNode>[];
    int subPostNumber = 0;
    final subPosts = <TiebaSubPost>[];
    int authorId = 0;
    TiebaUser author = const TiebaUser();
    TiebaAgree agree = const TiebaAgree();
    bool isHotPost = false;
    bool isFold = false;
    String foldTip = '';

    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          id = reader.readInt64();
          return true;
        case 2:
          title = reader.readString();
          return true;
        case 3:
          floor = reader.readUint32();
          return true;
        case 4:
          time = reader.readUint32();
          return true;
        case 5:
          final n = _decodePbContent(reader.readSubReader());
          if (n != null) content.add(n);
          return true;
        case 13:
          subPostNumber = reader.readUint32();
          return true;
        case 15: // SubPost { repeated SubPostList sub_post_list = 2; }
          reader.readSubReader().forEachField((st, sw, sr) {
            if (st == 2 && sw == WireType.lengthDelimited) {
              subPosts.add(_decodeSubPost(sr.readSubReader()));
              return true;
            }
            return false;
          });
          return true;
        case 19:
          authorId = reader.readInt64();
          return true;
        case 23:
          author = _decodeUser(reader.readSubReader());
          return true;
        case 31:
          isHotPost = reader.readInt32() != 0;
          return true;
        case 37:
          agree = _decodeAgree(reader.readSubReader());
          return true;
        case 43:
          isFold = reader.readInt32() != 0;
          return true;
        case 44:
          foldTip = reader.readString();
          return true;
        default:
          return false;
      }
    });

    return TiebaPost(
      id: id,
      title: title,
      floor: floor,
      time: time,
      content: content,
      subPostNumber: subPostNumber,
      subPosts: subPosts,
      authorId: authorId > 0 ? authorId : author.id,
      author: author,
      agree: agree,
      isFold: isFold,
      foldTip: foldTip,
      isHotPost: isHotPost,
    );
  }

  static TiebaSortOption _decodeSortOption(ProtoReader r) {
    int st = 0;
    String name = '';
    r.forEachField((tag, wire, reader) {
      if (tag == 1) {
        st = reader.readInt32();
        return true;
      }
      if (tag == 2) {
        name = reader.readString();
        return true;
      }
      return false;
    });
    return TiebaSortOption(sortType: st, sortName: name);
  }

  static ForumTab _decodeFrsTabInfo(ProtoReader r) {
    int tabId = 0;
    int tabType = 0;
    String tabName = '';
    bool isGeneral = false;
    String tabCode = '';
    bool isDefault = false;
    final sortMenu = <TiebaSortOption>[];
    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          tabId = reader.readInt32();
          return true;
        case 2:
          tabType = reader.readInt32();
          return true;
        case 3:
          tabName = reader.readString();
          return true;
        case 7:
          isGeneral = reader.readInt32() != 0;
          return true;
        case 8:
          tabCode = reader.readString();
          return true;
        case 10:
          isDefault = reader.readInt32() != 0;
          return true;
        case 19: // repeated SortButton sort_menu
          final sort = _decodeSortButton(reader.readSubReader());
          if (sort.sortName.isNotEmpty) sortMenu.add(sort);
          return true;
        default:
          return false;
      }
    });
    return ForumTab(
      tabId: tabId,
      tabType: tabType,
      tabName: tabName,
      tabCode: tabCode,
      isGeneralTab: isGeneral,
      isDefault: isDefault,
      sortMenu: sortMenu,
    );
  }

  /// `SortButton { string text = 1; int32 source_id = 2; }`
  static TiebaSortOption _decodeSortButton(ProtoReader r) {
    int sortType = 0;
    String name = '';
    r.forEachField((tag, wire, reader) {
      if (tag == 1) {
        name = reader.readString();
        return true;
      }
      if (tag == 2) {
        sortType = reader.readInt32();
        return true;
      }
      return false;
    });
    return TiebaSortOption(sortType: sortType, sortName: name);
  }

  static HotTopicItem _decodeRecommendTopic(ProtoReader r) {
    int id = 0;
    String name = '';
    int discuss = 0;
    int tagVal = 0;
    String desc = '';
    String pic = '';
    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          id = reader.readInt64();
          return true;
        case 2:
          name = reader.readString();
          return true;
        case 4:
          discuss = reader.readInt64();
          return true;
        case 5:
          tagVal = reader.readUint32();
          return true;
        case 6:
          desc = reader.readString();
          return true;
        case 7:
          pic = reader.readString();
          return true;
        default:
          return false;
      }
    });
    return HotTopicItem(
      topicId: id,
      topicName: name,
      topicDesc: desc,
      discussNum: discuss,
      tag: tagVal,
      topicPic: pic,
    );
  }

  static HotTopicItem _decodeTopicListItem(ProtoReader r) {
    int id = 0;
    String name = '';
    int discuss = 0;
    int tagVal = 0;
    String desc = '';
    String pic = '';
    String h5 = '';
    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          id = reader.readInt64();
          return true;
        case 2:
          name = reader.readString();
          return true;
        case 3:
          discuss = reader.readInt64();
          return true;
        case 4:
          tagVal = reader.readInt32();
          return true;
        case 5:
          desc = reader.readString();
          return true;
        case 6:
          pic = reader.readString();
          return true;
        case 11:
          h5 = reader.readString();
          return true;
        default:
          return false;
      }
    });
    return HotTopicItem(
      topicId: id,
      topicName: name,
      topicDesc: desc,
      discussNum: discuss,
      tag: tagVal,
      topicPic: pic,
      h5Url: h5,
    );
  }

  static HotTopicItem _decodeNewTopicItem(ProtoReader r) {
    int id = 0;
    String name = '';
    String desc = '';
    int discuss = 0;
    String pic = '';
    int tagVal = 0;
    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          id = reader.readInt64();
          return true;
        case 2:
          name = reader.readString();
          return true;
        case 3:
          desc = reader.readString();
          return true;
        case 4:
          discuss = reader.readInt64();
          return true;
        case 5:
          pic = reader.readString();
          return true;
        case 6:
          tagVal = reader.readInt32();
          return true;
        default:
          return false;
      }
    });
    return HotTopicItem(
      topicId: id,
      topicName: name,
      topicDesc: desc,
      discussNum: discuss,
      tag: tagVal,
      topicPic: pic,
    );
  }

  static UserPostItem _decodePostInfoList(ProtoReader r) {
    int forumId = 0;
    int threadId = 0;
    int postId = 0;
    bool isThread = true;
    int createTime = 0;
    String forumName = '';
    String title = '';
    String abs = '';
    String userName = '';
    String nameShow = '';
    int userId = 0;
    String portrait = '';
    int replyNum = 0;
    int agreeNum = 0;
    final images = <RichImageNode>[];
    final replyBuf = StringBuffer();

    r.forEachField((tag, wire, reader) {
      switch (tag) {
        case 1:
          forumId = reader.readInt64();
          return true;
        case 2:
          threadId = reader.readInt64();
          return true;
        case 3:
          postId = reader.readInt64();
          return true;
        case 4:
          isThread = reader.readUint32() != 0;
          return true;
        case 5:
          createTime = reader.readUint32();
          return true;
        case 6:
          forumName = reader.readString();
          return true;
        case 7:
          title = reader.readString();
          return true;
        case 8: // repeated PostInfoContent
          reader.readSubReader().forEachField((ct, cw, cr) {
            if (ct == 1) {
              cr.readSubReader().forEachField((at, aw, ar) {
                if (at == 2) {
                  replyBuf.write(ar.readString());
                  return true;
                }
                return false;
              });
              return true;
            }
            if (ct == 4 && postId == 0) {
              postId = cr.readInt64();
              return true;
            }
            return false;
          });
          return true;
        case 10:
          userName = reader.readString();
          return true;
        case 14:
          abs = reader.readString();
          return true;
        case 16:
          final img = _decodeMedia(reader.readSubReader());
          if (img != null) images.add(img);
          return true;
        case 17:
          replyNum = reader.readUint32();
          return true;
        case 18:
          userId = reader.readInt64();
          return true;
        case 19:
          portrait = reader.readString();
          return true;
        case 35:
          nameShow = reader.readString();
          return true;
        case 37:
          agreeNum = reader.readInt32();
          return true;
        default:
          return false;
      }
    });

    final summary = replyBuf.isNotEmpty ? replyBuf.toString().trim() : abs;
    return UserPostItem(
      forumId: forumId,
      threadId: threadId,
      postId: postId,
      isThread: isThread,
      createTime: createTime,
      forumName: forumName,
      title: title,
      abstractText: summary,
      userName: userName,
      nameShow: nameShow,
      userId: userId,
      userPortrait: portrait,
      replyNum: replyNum,
      agreeNum: agreeNum,
      images: images,
    );
  }

  static String _firstNonEmpty(List<String> values) {
    for (final v in values) {
      if (v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }
}
