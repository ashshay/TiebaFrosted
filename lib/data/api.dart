import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../core/device.dart';
import '../core/signer.dart';
import 'json.dart';
import 'models.dart';
import 'proto_codec.dart';

/// 贴吧全协议网络层：按 TiebaLite 实测链路分组（pb / official / mini / new / hybrid）。
class TiebaApi {
  TiebaApi({
    required this.device,
    required this.credentialProvider,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(seconds: 30),
                responseType: ResponseType.plain,
                validateStatus: (status) => status != null && status < 500,
              ),
            );

  static const _boundary = '--------7da3d81520810*';
  static const _pbHost = 'https://tiebac.baidu.com';
  static const _officialHost = 'https://c.tieba.baidu.com';
  static const _hybridHost = 'https://tieba.baidu.com';

  final TiebaDevice device;
  final ({
    String bduss,
    String stoken,
    String tbs,
    String uid,
    String zid,
    String webCookie,
  }) Function() credentialProvider;
  final Dio _dio;
  final Random _random = Random();

  Dio get rawDio => _dio;

  // ===========================================================================
  // Protobuf Transport (V11 / V12 / V22 / V12_POST)
  // ===========================================================================

  Future<Uint8List> _postProto({
    required String path,
    required Uint8List protoBytes,
    required String clientVersion,
    bool signed = false,
    bool isPost = false,
    bool needStokenPart = true,
    Map<String, String> extraHeaders = const {},
  }) async {
    final cred = credentialProvider();
    final headers = <String, String>{
      'Charset': 'UTF-8',
      if (!isPost) 'client_type': '2',
      if (clientVersion == TiebaClientVersion.v12 && !isPost)
        'client_logid': '${device.initTimeMs}',
      if (cred.uid.isNotEmpty) 'client_user_token': cred.uid,
      'cookie': clientVersion == TiebaClientVersion.v11
          ? 'CUID=${device.newCuid};ka=open;TBBRAND=${device.model};'
          : _colonCookie({
              if (isPost && cred.zid.isNotEmpty) 'BAIDUZID': cred.zid,
              'ka': 'open',
              'CUID': device.newCuid,
              'TBBRAND': device.model,
            }),
      'cuid': device.newCuid,
      'cuid_galaxy2': device.newCuid,
      'cuid_gid': '',
      'c3_aid': device.aid,
      'User-Agent': clientVersion == TiebaClientVersion.v11
          ? 'bdtb for Android $clientVersion'
          : device.userAgent('tieba/$clientVersion'),
      'x_bd_data_type': 'protobuf',
      'Content-Type': 'multipart/form-data; boundary=$_boundary',
      ...extraHeaders,
    };

    final textParts = <String, String>{};
    if (signed) {
      textParts.addAll(_baseCommonParams(cred.bduss));
      textParts.remove('_os_version');
      textParts['_client_version'] = clientVersion;
      textParts['cuid'] = device.newCuid;
      textParts['cuid_galaxy2'] = device.newCuid;
      textParts['cuid_gid'] = '';
      textParts['c3_aid'] = device.aid;
      textParts['from'] = 'tieba';
      textParts['oaid'] = device.oaidJson;
      if (isPost) {
        textParts['active_timestamp'] = '${device.activeTimestamp}';
        textParts['android_id'] = device.base64AndroidId;
        if (device.baiduId.isNotEmpty) textParts['baiduid'] = device.baiduId;
        textParts['brand'] = device.brand;
        textParts['cmode'] = '1';
        textParts['device_score'] = device.deviceScore;
        textParts['event_day'] = device.eventDay;
        textParts['extra'] = '';
        textParts['first_install_time'] = '${device.firstInstallTime}';
        textParts['framework_ver'] = '3340042';
        textParts['is_teenager'] = '0';
        textParts['last_update_time'] = '${device.lastUpdateTime}';
        textParts['mac'] = '02:00:00:00:00:00';
        textParts['naws_game_ver'] = '1038000';
        textParts['personalized_rec_switch'] = '1';
        if (device.sampleId.isNotEmpty) {
          textParts['sample_id'] = device.sampleId;
        }
        textParts['sdk_ver'] = '2.34.0';
        textParts['start_scheme'] = '';
        textParts['start_type'] = '1';
        if (cred.stoken.isNotEmpty) textParts['stoken'] = cred.stoken;
        textParts['z_id'] = cred.zid;
      }
    }
    if (needStokenPart && cred.stoken.isNotEmpty) {
      textParts.putIfAbsent('stoken', () => cred.stoken);
    }

    final bodyBytes = _buildTiebaMultipart(
      fields: textParts,
      signed: signed,
      fileNameField: 'data',
      fileBytes: protoBytes,
    );

    final resp = await _dio.post<List<int>>(
      '$_pbHost$path',
      data: Stream.fromIterable([bodyBytes]),
      options: Options(
        headers: {...headers, 'Content-Length': '${bodyBytes.length}'},
        responseType: ResponseType.bytes,
      ),
    );
    _captureBaiduId(resp.headers['set-cookie']);
    final bytes = Uint8List.fromList(resp.data ?? const []);
    if (bytes.isEmpty) {
      throw const TiebaApiException(-1, '服务端返回空响应');
    }
    return bytes;
  }

  // ===========================================================================
  // JSON Transports (Official / Mini / New / Hybrid)
  // ===========================================================================

  Future<Map<String, dynamic>> _postOfficialJson(
    String path,
    Map<String, String> params, {
    String? clientVersion,
    Set<String> dropParams = const {},
    Map<String, String> extraHeaders = const {},
    bool includeSt = true,
  }) async {
    final cred = credentialProvider();
    final ver = clientVersion ?? TiebaClientVersion.v12;
    final merged = <String, String>{
      ..._baseCommonParams(cred.bduss),
      'active_timestamp': '${device.activeTimestamp}',
      'android_id': device.base64AndroidId,
      if (device.baiduId.isNotEmpty) 'baiduid': device.baiduId,
      'brand': device.brand,
      'cmode': '1',
      'cuid': device.newCuid,
      'cuid_galaxy2': device.newCuid,
      'cuid_gid': '',
      'c3_aid': device.aid,
      'event_day': device.eventDay,
      'extra': '',
      'first_install_time': '${device.firstInstallTime}',
      'framework_ver': '3340042',
      'from': 'tieba',
      'is_teenager': '0',
      'last_update_time': '${device.lastUpdateTime}',
      'mac': '02:00:00:00:00:00',
      if (device.sampleId.isNotEmpty) 'sample_id': device.sampleId,
      'sdk_ver': '2.34.0',
      'start_scheme': '',
      'start_type': '1',
      'swan_game_ver': '1038000',
      '_client_version': ver,
      'oaid': device.oaidJson,
      ...params,
    };
    for (final k in dropParams) {
      merged.remove(k);
    }
    if (includeSt) merged.addAll(_stParams());

    final headers = <String, String>{
      'User-Agent': 'bdtb for Android $ver',
      'cookie':
          'CUID=${device.newCuid};ka=open;TBBRAND=${device.model};BAIDUID=${device.baiduId};',
      'cuid': device.newCuid,
      'cuid_galaxy2': device.newCuid,
      'cuid_gid': '',
      'c3_aid': device.aid,
      'client_logid': '${device.initTimeMs}',
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      ...extraHeaders,
    };

    final body = encodeSignedFormBody(merged);
    final resp = await _dio.post<String>(
      '$_officialHost$path',
      data: body,
      options: Options(headers: headers, responseType: ResponseType.plain),
    );
    _captureBaiduId(resp.headers['set-cookie']);
    return _decodeJsonChecked(resp.data);
  }

  Future<Map<String, dynamic>> _postMiniJson(
    String path,
    Map<String, String> params, {
    String clientVersion = TiebaClientVersion.mini,
    Map<String, String> extraHeaders = const {},
  }) async {
    final cred = credentialProvider();
    final merged = <String, String>{
      ..._baseCommonParams(cred.bduss),
      'cuid': device.finalCuid,
      'cuid_galaxy2': device.finalCuid,
      'from': '1021636m',
      '_client_version': clientVersion,
      'subapp_type': 'mini',
      ..._stParams(),
      ...params,
    };

    final headers = <String, String>{
      'cookie': 'ka=open',
      'Pragma': 'no-cache',
      'User-Agent': 'bdtb for Android $clientVersion',
      'cuid': device.finalCuid,
      'cuid_galaxy2': device.finalCuid,
      'client_logid': '${device.initTimeMs}',
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      ...extraHeaders,
    };

    final resp = await _dio.post<String>(
      '$_officialHost$path',
      data: encodeSignedFormBody(merged),
      options: Options(headers: headers, responseType: ResponseType.plain),
    );
    return _decodeJsonChecked(resp.data);
  }

  Future<Map<String, dynamic>> _postNewJson(
    String path,
    Map<String, String> params,
  ) async {
    final cred = credentialProvider();
    final merged = <String, String>{
      ..._baseCommonParams(cred.bduss),
      'cuid': device.finalCuid,
      'from': 'baidu_appstore',
      '_client_version': TiebaClientVersion.legacyNew,
      ..._stParams(),
      ...params,
    };
    final headers = <String, String>{
      'cookie': 'ka=open',
      'Pragma': 'no-cache',
      'User-Agent': 'bdtb for Android ${TiebaClientVersion.legacyNew}',
      'cuid': device.finalCuid,
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    };
    final resp = await _dio.post<String>(
      '$_officialHost$path',
      data: encodeSignedFormBody(merged),
      options: Options(headers: headers, responseType: ResponseType.plain),
    );
    return _decodeJsonChecked(resp.data);
  }

  Future<Map<String, dynamic>> _getHybridJson(
    String path,
    Map<String, String> query, {
    String? referer,
    bool includeAuthParams = false,
  }) async {
    final cred = credentialProvider();
    final q = <String, String>{
      if (includeAuthParams && cred.bduss.isNotEmpty) 'BDUSS': cred.bduss,
      if (includeAuthParams && cred.stoken.isNotEmpty) 'stoken': cred.stoken,
      ...query,
    };
    final headers = <String, String>{
      'User-Agent': device.userAgent('tieba/${TiebaClientVersion.v12} skin/default'),
      'Host': 'tieba.baidu.com',
      'Pragma': 'no-cache',
      'Cache-Control': 'no-cache',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'X-Requested-With': 'com.baidu.tieba',
      'Sec-Fetch-Site': 'same-origin',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Dest': 'empty',
      'Referer': ?referer,
      if (cred.webCookie.isNotEmpty) 'cookie': cred.webCookie,
    };
    final resp = await _dio.get<String>(
      '$_hybridHost$path',
      queryParameters: q,
      options: Options(headers: headers, responseType: ResponseType.plain),
    );
    return _decodeJsonChecked(resp.data);
  }

  // ===========================================================================
  // Public Endpoints — P0/P1 Read Paths
  // ===========================================================================

  /// 客户端初始化同步（获取 client_id 与 sample_id）。
  Future<void> syncDevice() async {
    final cred = credentialProvider();
    final j = await _postOfficialJson(
      '/c/s/sync',
      {
        if (device.clientId != null && device.clientId!.isNotEmpty)
          '_client_id': device.clientId!,
        '_msg_status': '1',
        '_phone_screen': '${device.screenWidth},${device.screenHeight}',
        '_pic_quality': '0',
        'board': device.brand,
        'brand': device.brand,
        'cam': base64Encode(utf8.encode('02:00:00:00:00:00')),
        'di_diordna': device.base64AndroidId,
        'iemi': base64Encode(utf8.encode(device.imei)),
        'incremental': '1',
        'md5': 'F86F4C238491AB3BEBFA33AC42C1582B',
        'signmd5': '225172691',
        'package': 'com.baidu.tieba',
        'versioncode': '202965248',
        'running_abi': '64',
        'support_abi': '64',
        'scr_dip': '${device.screenDensity}',
        'scr_h': '${device.screenHeight}',
        'scr_w': '${device.screenWidth}',
        if (cred.stoken.isNotEmpty) 'stoken': cred.stoken,
      },
      dropParams: const {
        'oaid',
        'mac',
        '_phone_imei',
        'android_id',
        'swan_game_ver',
        'sdk_ver',
      },
      extraHeaders: {
        'cookie': device.baiduId.isNotEmpty
            ? 'ka=open;BAIDUID=${device.baiduId}'
            : 'ka=open',
      },
    );
    final newClientId = j.obj('client')?.str('client_id');
    final newSampleId = j.obj('wl_config')?.str('sample_id');
    await device.updateSync(
      newClientId: newClientId,
      newSampleId: newSampleId,
    );
  }

  /// 帖子详情（Protobuf V12 `pb/page?cmd=302001&format=protobuf`）。
  Future<ThreadPageResult> pbPage({
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
    final cred = credentialProvider();
    final reqBytes = TiebaProtoCodec.encodePbPageRequest(
      device: device,
      threadId: threadId,
      page: page,
      postId: postId,
      seeLz: seeLz,
      sortType: sortType,
      back: back,
      forumId: forumId,
      lastPid: lastPid,
      mark: mark,
      bduss: cred.bduss,
      stoken: cred.stoken,
      tbs: cred.tbs,
      zid: cred.zid,
    );
    final respBytes = await _postProto(
      path: '/c/f/pb/page?cmd=302001&format=protobuf',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v12,
    );
    return TiebaProtoCodec.decodePbPageResponse(respBytes);
  }

  /// 楼中楼详情（Protobuf V22 `pb/floor?cmd=302002&format=protobuf`）。
  Future<SubPostsPageResult> pbFloor({
    required int threadId,
    required int postId,
    int subPostId = 0,
    int page = 1,
    int forumId = 0,
  }) async {
    final cred = credentialProvider();
    final reqBytes = TiebaProtoCodec.encodePbFloorRequest(
      device: device,
      threadId: threadId,
      postId: postId,
      subPostId: subPostId,
      page: page,
      forumId: forumId,
      bduss: cred.bduss,
      stoken: cred.stoken,
      zid: cred.zid,
    );
    final respBytes = await _postProto(
      path: '/c/f/pb/floor?cmd=302002&format=protobuf',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v22,
      needStokenPart: false,
    );
    return TiebaProtoCodec.decodePbFloorResponse(respBytes);
  }

  /// 吧主页（Protobuf V12 `frs/page?cmd=301001`）。
  Future<ForumPageResult> frsPage({
    required String forumName,
    int page = 1,
    int loadType = 1,
    int sortType = 0,
    int? goodClassifyId,
  }) async {
    final cred = credentialProvider();
    final reqBytes = TiebaProtoCodec.encodeFrsPageRequest(
      device: device,
      forumName: forumName,
      page: page,
      loadType: loadType,
      sortType: sortType,
      goodClassifyId: goodClassifyId,
      bduss: cred.bduss,
      stoken: cred.stoken,
      tbs: cred.tbs,
      zid: cred.zid,
    );
    final respBytes = await _postProto(
      path: '/c/f/frs/page?cmd=301001',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v12,
      extraHeaders: {'forum_name': Uri.encodeComponent(forumName)},
    );
    return TiebaProtoCodec.decodeFrsPageResponse(respBytes);
  }

  /// 吧内按 thread_id 批次加载更多（Protobuf V12 `frs/threadlist?cmd=301002`）。
  Future<List<TiebaThread>> frsThreadList({
    required int forumId,
    required String forumName,
    required List<int> threadIds,
    int page = 1,
    int sortType = 0,
  }) async {
    final cred = credentialProvider();
    final reqBytes = TiebaProtoCodec.encodeThreadListRequest(
      device: device,
      forumId: forumId,
      forumName: forumName,
      threadIds: threadIds,
      page: page,
      sortType: sortType,
      bduss: cred.bduss,
      stoken: cred.stoken,
      tbs: cred.tbs,
      zid: cred.zid,
    );
    final respBytes = await _postProto(
      path: '/c/f/frs/threadlist?cmd=301002',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v12,
    );
    return TiebaProtoCodec.decodeThreadListResponse(respBytes);
  }

  /// 个性化推荐流（Protobuf V12 `excellent/personalized?cmd=309264`）。
  Future<PersonalizedPageResult> personalized({
    int loadType = 1,
    int page = 1,
  }) async {
    final cred = credentialProvider();
    final reqBytes = TiebaProtoCodec.encodePersonalizedRequest(
      device: device,
      loadType: loadType,
      page: page,
      bduss: cred.bduss,
      stoken: cred.stoken,
      tbs: cred.tbs,
      zid: cred.zid,
    );
    final respBytes = await _postProto(
      path: '/c/f/excellent/personalized?cmd=309264',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v12,
    );
    return TiebaProtoCodec.decodePersonalizedResponse(respBytes);
  }

  /// 关注流（Protobuf V11 `concern/userlike?cmd=309474`）。
  Future<ConcernPageResult> userLikeFeed({
    String pageTag = '',
    int lastRequestUnix = 0,
    int loadType = 1,
  }) async {
    final cred = credentialProvider();
    final reqBytes = TiebaProtoCodec.encodeUserLikeRequest(
      device: device,
      pageTag: pageTag,
      lastRequestUnix: lastRequestUnix,
      loadType: loadType,
      bduss: cred.bduss,
      stoken: cred.stoken,
    );
    final respBytes = await _postProto(
      path: '/c/f/concern/userlike?cmd=309474',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v11,
      signed: true,
    );
    return TiebaProtoCodec.decodeUserLikeResponse(respBytes);
  }

  /// 发现-热议榜（Protobuf V11 `forum/hotThreadList?cmd=309661`）。
  Future<HotThreadPageResult> hotThreadList({
    String tabCode = 'all',
    String tabId = '1',
  }) async {
    final cred = credentialProvider();
    final reqBytes = TiebaProtoCodec.encodeHotThreadListRequest(
      device: device,
      tabCode: tabCode,
      tabId: tabId,
      bduss: cred.bduss,
      stoken: cred.stoken,
    );
    final respBytes = await _postProto(
      path: '/c/f/forum/hotThreadList?cmd=309661',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v11,
      signed: true,
    );
    return TiebaProtoCodec.decodeHotThreadListResponse(respBytes);
  }

  /// 热门话题榜（Protobuf V11 `recommend/topicList?cmd=309289`）。
  Future<List<HotTopicItem>> topicList() async {
    final cred = credentialProvider();
    final reqBytes = TiebaProtoCodec.encodeTopicListRequest(
      device: device,
      bduss: cred.bduss,
      stoken: cred.stoken,
    );
    final respBytes = await _postProto(
      path: '/c/f/recommend/topicList?cmd=309289',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v11,
      signed: true,
    );
    return TiebaProtoCodec.decodeTopicListResponse(respBytes);
  }

  /// 话题详情（Hybrid JSON `/mo/q/newtopic/topicDetail`）。
  Future<HotTopicDetailResult> topicDetail({
    required int topicId,
    required String topicName,
    int page = 1,
    int offset = 0,
    String lastId = '',
  }) async {
    final j = await _getHybridJson(
      '/mo/q/newtopic/topicDetail',
      {
        'topic_id': '$topicId',
        'topic_name': topicName,
        'is_new': '1',
        'is_share': '1',
        'pn': '$page',
        'rn': '15',
        'offset': '$offset',
        if (lastId.isNotEmpty) 'last_id': lastId,
      },
      includeAuthParams: false,
    );
    final data = j.obj('data') ?? j;
    final info = data.obj('topic_info');
    final relate = data.obj('relate_thread');
    final list = relate?.objList('thread_list') ?? const [];
    final threads = [
      for (final item in list)
        TiebaThread(
          id: item.intOf('tid', item.intOf('thread_id')),
          threadId: item.intOf('tid', item.intOf('thread_id')),
          title: item.str('title'),
          abstractText: item.str('abstract'),
          forumId: item.intOf('forum_id'),
          forumName: item.str('forum_name'),
          replyNum: item.count('reply_num'),
          agree: TiebaAgree(agreeNum: item.count('agree_num')),
          createTime: item.intOf('create_time'),
          author: item.obj('author') != null
              ? TiebaUser.fromJson(item.obj('author')!)
              : const TiebaUser(),
        ),
    ];
    return HotTopicDetailResult(
      topicId: info?.intOf('topic_id', topicId) ?? topicId,
      topicName: info?.str('topic_name', topicName) ?? topicName,
      topicDesc: info?.str('topic_desc') ?? '',
      topicImage: info?.str('topic_image') ?? '',
      discussNum: info?.count('discuss_num') ?? 0,
      threads: threads,
      hasMore: relate?.boolean('has_more') ?? false,
    );
  }

  /// 用户资料（Protobuf V12 `user/profile?cmd=303012&format=protobuf`）。
  Future<UserProfileResult> userProfile({
    int? targetUid,
    String targetPortrait = '',
    int page = 1,
  }) async {
    final cred = credentialProvider();
    final selfUid = int.tryParse(cred.uid);
    final reqBytes = TiebaProtoCodec.encodeProfileRequest(
      device: device,
      selfUid: selfUid,
      targetUid: targetUid,
      targetPortrait: targetPortrait,
      page: page,
      bduss: cred.bduss,
      stoken: cred.stoken,
      tbs: cred.tbs,
      zid: cred.zid,
    );
    final respBytes = await _postProto(
      path: '/c/u/user/profile?cmd=303012&format=protobuf',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v12,
    );
    return TiebaProtoCodec.decodeProfileResponse(respBytes);
  }

  /// 用户帖子/回复列表（Protobuf V12 `feed/userpost?cmd=303002&format=protobuf`）。
  Future<List<UserPostItem>> userPosts({
    required int uid,
    int page = 1,
    bool isThread = true,
  }) async {
    final cred = credentialProvider();
    final reqBytes = TiebaProtoCodec.encodeUserPostRequest(
      device: device,
      uid: uid,
      page: page,
      isThread: isThread,
      bduss: cred.bduss,
      stoken: cred.stoken,
      tbs: cred.tbs,
      zid: cred.zid,
    );
    final respBytes = await _postProto(
      path: '/c/u/feed/userpost?cmd=303002&format=protobuf',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v12,
    );
    return TiebaProtoCodec.decodeUserPostResponse(respBytes);
  }

  /// 吧资料（Protobuf V12 `forum/getforumdetail?cmd=303021&format=protobuf`）。
  Future<ForumDetailInfo> forumDetail(int forumId) async {
    final cred = credentialProvider();
    final reqBytes = TiebaProtoCodec.encodeForumIdRequest(
      device: device,
      forumId: forumId,
      bduss: cred.bduss,
      stoken: cred.stoken,
      tbs: cred.tbs,
      zid: cred.zid,
    );
    final respBytes = await _postProto(
      path: '/c/f/forum/getforumdetail?cmd=303021&format=protobuf',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v12,
    );
    return TiebaProtoCodec.decodeGetForumDetailResponse(respBytes);
  }

  /// 吧规（Protobuf V12 `forum/forumRuleDetail?cmd=309690&format=protobuf`）。
  Future<ForumRuleDetailInfo> forumRuleDetail(int forumId) async {
    final cred = credentialProvider();
    final reqBytes = TiebaProtoCodec.encodeForumIdRequest(
      device: device,
      forumId: forumId,
      bduss: cred.bduss,
      stoken: cred.stoken,
      tbs: cred.tbs,
      zid: cred.zid,
    );
    final respBytes = await _postProto(
      path: '/c/f/forum/forumRuleDetail?cmd=309690&format=protobuf',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v12,
    );
    return TiebaProtoCodec.decodeForumRuleDetailResponse(respBytes);
  }

  // ===========================================================================
  // Search Endpoints
  // ===========================================================================

  Future<SearchSugResult> searchSuggestions(String keyword) async {
    final cred = credentialProvider();
    final reqBytes = TiebaProtoCodec.encodeSearchSugRequest(
      device: device,
      keyword: keyword,
      bduss: cred.bduss,
      stoken: cred.stoken,
      zid: cred.zid,
    );
    final respBytes = await _postProto(
      path: '/c/s/searchSug?cmd=309438&format=protobuf',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v12,
    );
    return TiebaProtoCodec.decodeSearchSugResponse(respBytes);
  }

  Future<({SearchForumItem? exact, List<SearchForumItem> fuzzy})> searchForum(
    String keyword,
  ) async {
    final j = await _getHybridJson(
      '/mo/q/search/forum',
      {'word': keyword},
      referer:
          'https://tieba.baidu.com/mo/q/searchpage?word=${Uri.encodeComponent(keyword)}',
    );
    final data = j.obj('data') ?? j;
    final exactObj = data.obj('exactMatch');
    final exact = (exactObj != null && exactObj.str('forum_name').isNotEmpty)
        ? SearchForumItem.fromJson(exactObj)
        : null;
    final fuzzyRaw = data.opt('fuzzyMatch');
    final fuzzyList = <SearchForumItem>[];
    if (fuzzyRaw is List) {
      for (final item in fuzzyRaw) {
        final m = jObj(item);
        if (m != null) fuzzyList.add(SearchForumItem.fromJson(m));
      }
    } else if (fuzzyRaw is Map) {
      for (final item in fuzzyRaw.values) {
        final m = jObj(item);
        if (m != null) fuzzyList.add(SearchForumItem.fromJson(m));
      }
    }
    return (exact: exact, fuzzy: fuzzyList);
  }

  Future<({List<SearchThreadItem> items, bool hasMore})> searchThread({
    required String keyword,
    int page = 1,
    int order = 2, // 0=old, 1=new, 2=relevant
    int filter = 1, // 1=only thread, 2=all
    String? forumName,
  }) async {
    final inForum = forumName != null && forumName.isNotEmpty;
    final j = await _getHybridJson(
      '/mo/q/search/thread',
      {
        'word': keyword,
        'pn': '$page',
        'st': '$order',
        'tt': '$filter',
        'ct': inForum ? '2' : '1',
        if (!inForum) 'is_use_zonghe': '1',
        'cv': inForum ? TiebaClientVersion.v12 : '99.9.101',
        if (inForum) 'fname': forumName,
        if (inForum) 'rn': '20',
      },
      referer: inForum
          ? 'https://tieba.baidu.com/f?kw=${Uri.encodeComponent(forumName)}'
          : 'https://tieba.baidu.com/mo/q/searchpage?word=${Uri.encodeComponent(keyword)}',
    );
    final data = j.obj('data') ?? j;
    final rawList = data.objList('post_list');
    return (
      items: [for (final item in rawList) SearchThreadItem.fromJson(item)],
      hasMore: data.intOf('has_more') != 0 || rawList.length >= 10,
    );
  }

  Future<List<SearchUserItem>> searchUser(String keyword) async {
    final j = await _getHybridJson(
      '/mo/q/search/user',
      {'word': keyword},
      referer:
          'https://tieba.baidu.com/mo/q/searchpage?word=${Uri.encodeComponent(keyword)}',
    );
    final data = j.obj('data') ?? j;
    final result = <SearchUserItem>[];
    final exact = data.obj('exactMatch');
    if (exact != null && exact.str('name').isNotEmpty) {
      result.add(SearchUserItem.fromJson(exact));
    }
    final fuzzyRaw = data.opt('fuzzyMatch');
    if (fuzzyRaw is List) {
      for (final item in fuzzyRaw) {
        final m = jObj(item);
        if (m != null) result.add(SearchUserItem.fromJson(m));
      }
    } else if (fuzzyRaw is Map) {
      for (final item in fuzzyRaw.values) {
        final m = jObj(item);
        if (m != null) result.add(SearchUserItem.fromJson(m));
      }
    }
    return result;
  }

  // ===========================================================================
  // Account, Followed Forums, Sign-in, Notifications, Favorites, Write Ops
  // ===========================================================================

  /// 用 BDUSS + STOKEN 拉取账号基础信息（uid / name / portrait / tbs）。
  Future<({String uid, String name, String nameShow, String portrait, String tbs})>
  verifyLogin({
    required String bduss,
    required String stoken,
  }) async {
    final j = await _postOfficialJson(
      '/c/s/login',
      {
        'bdusstoken': '$bduss|null',
        'stoken': stoken,
        'channel_id': '',
        'channel_uid': '',
        'authsid': 'null',
      },
      clientVersion: TiebaClientVersion.v11,
      dropParams: const {'BDUSS'},
      extraHeaders: const {'cookie': 'ka=open'},
    );
    final user = j.obj('user') ?? const {};
    final anti = j.obj('anti') ?? const {};
    final uid = user.str('id');
    final name = user.str('name');
    final portrait = user.str('portrait');
    final tbs = anti.str('tbs');
    var nameShow = user.str('name_show', name);

    // 尝试再走一次 getUserInfo 拿最新昵称和头像
    final uidInt = int.tryParse(uid);
    if (uidInt != null && uidInt > 0) {
      try {
        final req = TiebaProtoCodec.encodeGetUserInfoRequest(
          device: device,
          uid: uidInt,
          bduss: bduss,
          stoken: stoken,
        );
        final resp = await _postProto(
          path: '/c/u/user/getuserinfo?cmd=303024&format=protobuf',
          protoBytes: req,
          clientVersion: TiebaClientVersion.v12,
        );
        final detail = TiebaProtoCodec.decodeGetUserInfoResponse(resp);
        if (detail.nameShow.isNotEmpty) nameShow = detail.nameShow;
      } on Object {
        // 降级保留 /c/s/login 返回值
      }
    }
    return (
      uid: uid,
      name: name,
      nameShow: nameShow,
      portrait: portrait,
      tbs: tbs,
    );
  }

  /// 获取当前登录用户关注的全部贴吧（自动分页拉完 `forumGuide`）。
  Future<List<FollowedForum>> followedForums() async {
    final cred = credentialProvider();
    if (cred.bduss.isEmpty) return const [];
    final all = <FollowedForum>[];
    var pageNo = 1;
    while (pageNo <= 20) {
      final j = await _postOfficialJson(
        '/c/f/forum/forumGuide',
        {
          'sort_type': '3',
          'call_from': '4',
          'page_no': '$pageNo',
          'res_num': '50',
          'top_forum_num': '0',
          if (cred.tbs.isNotEmpty) 'tbs': cred.tbs,
          if (cred.stoken.isNotEmpty) 'stoken': cred.stoken,
        },
      );
      final list = j.objList('like_forum');
      for (final item in list) {
        all.add(FollowedForum.fromJson(item));
      }
      final hasMore = j.intOf('like_forum_has_more') != 0;
      if (!hasMore || list.isEmpty) break;
      pageNo++;
    }
    return all;
  }

  /// 获取他人的关注贴吧列表。
  Future<({List<FollowedForum> items, bool hasMore})> userLikeForums({
    required int uid,
    int page = 1,
  }) async {
    final cred = credentialProvider();
    final isGuest = cred.uid.isNotEmpty && cred.uid != '$uid';
    final j = await _postOfficialJson(
      '/c/f/forum/like',
      {
        'page_no': '$page',
        'page_size': '50',
        'uid': cred.uid.isNotEmpty ? cred.uid : '$uid',
        if (isGuest) 'friend_uid': '$uid',
        if (isGuest) 'is_guest': '1',
      },
    );
    final forumListObj = j.obj('forum_list');
    final nonGcon = forumListObj?.objList('non-gconforum') ?? const [];
    final gcon = forumListObj?.objList('gconforum') ?? const [];
    final combined = [...nonGcon, ...gcon];
    return (
      items: [for (final item in combined) FollowedForum.fromJson(item)],
      hasMore: j.intOf('has_more') != 0,
    );
  }

  /// 获取关注/粉丝列表。
  Future<({List<TiebaUser> items, bool hasMore})> followList({
    int? uid,
    int page = 1,
  }) async {
    final j = await _postOfficialJson(
      '/c/u/follow/followList',
      {
        'pn': '$page',
        if (uid != null && uid > 0) 'uid': '$uid',
      },
    );
    final raw = j.objList('follow_list');
    return (
      items: [for (final item in raw) TiebaUser.fromJson(item)],
      hasMore: j.intOf('has_more') != 0,
    );
  }

  /// 点赞 / 取消点赞（`objType`: 3=主题, 1=楼层, 2=楼中楼; `opType`: 0=赞, 1=取消）。
  Future<void> opAgree({
    required int threadId,
    int postId = 0,
    int opType = 0,
    int objType = 3,
  }) async {
    final cred = credentialProvider();
    await _postMiniJson(
      '/c/c/agree/opAgree',
      {
        'thread_id': '$threadId',
        'post_id': '$postId',
        'op_type': '$opType',
        'obj_type': '$objType',
        'agree_type': '2',
        'cuid_gid': '',
        if (cred.tbs.isNotEmpty) 'tbs': cred.tbs,
        if (cred.stoken.isNotEmpty) 'stoken': cred.stoken,
      },
      clientVersion: TiebaClientVersion.miniAlt,
      extraHeaders: {
        if (cred.uid.isNotEmpty) 'client_user_token': cred.uid,
      },
    );
  }

  /// 关注 / 取关贴吧。
  Future<void> toggleLikeForum({
    required int forumId,
    required String forumName,
    required bool like,
    String? tbsOverride,
  }) async {
    final cred = credentialProvider();
    final tbs = (tbsOverride != null && tbsOverride.isNotEmpty)
        ? tbsOverride
        : cred.tbs;
    if (like) {
      await _postMiniJson('/c/c/forum/like', {
        'fid': '$forumId',
        'kw': forumName,
        'tbs': tbs,
      });
    } else {
      await _postOfficialJson(
        '/c/c/forum/unfavolike',
        {
          'fid': '$forumId',
          'kw': forumName,
          'tbs': tbs,
          if (cred.stoken.isNotEmpty) 'stoken': cred.stoken,
        },
        clientVersion: TiebaClientVersion.v11,
        dropParams: const {'oaid'},
        extraHeaders: {
          'cookie': 'ka=open',
          if (cred.uid.isNotEmpty) 'client_user_token': cred.uid,
        },
      );
    }
  }

  /// 单吧签到。
  Future<SignResult> signForum({
    required int forumId,
    required String forumName,
    String? tbsOverride,
  }) async {
    final cred = credentialProvider();
    final tbs = (tbsOverride != null && tbsOverride.isNotEmpty)
        ? tbsOverride
        : cred.tbs;
    final j = await _postOfficialJson(
      '/c/c/forum/sign',
      {
        'fid': '$forumId',
        'kw': forumName,
        'tbs': tbs,
      },
      clientVersion: TiebaClientVersion.v11,
      dropParams: const {'oaid'},
      extraHeaders: {
        'cookie': 'ka=open',
        if (cred.uid.isNotEmpty) 'client_user_token': cred.uid,
      },
    );
    final info = j.obj('user_info');
    return SignResult(
      success: true,
      message: '签到成功',
      signBonusPoint: info?.intOf('sign_bonus_point') ?? 0,
      contSignNum: info?.intOf('cont_sign_num') ?? 0,
      userSignRank: info?.intOf('user_sign_rank') ?? 0,
    );
  }

  /// 一键批量签到（mSign）。
  Future<int> mSignForums(List<int> forumIds) async {
    if (forumIds.isEmpty) return 0;
    final cred = credentialProvider();
    final j = await _postOfficialJson(
      '/c/c/forum/msign',
      {
        'forum_ids': forumIds.join(','),
        'tbs': cred.tbs,
        'authsid': 'null',
        'stoken': cred.stoken,
        'user_id': cred.uid,
      },
      clientVersion: TiebaClientVersion.v11,
    );
    final info = j.objList('info');
    return info.where((e) => e.intOf('signed') == 1).length;
  }

  /// 收藏列表 / 收藏 / 取消收藏。
  Future<List<ThreadStoreItem>> threadStore({
    int pageSize = 20,
    int offset = 0,
  }) async {
    final cred = credentialProvider();
    final j = await _postOfficialJson(
      '/c/f/post/threadstore',
      {
        'rn': '$pageSize',
        'offset': '$offset',
        'stoken': cred.stoken,
        'user_id': cred.uid,
      },
      clientVersion: TiebaClientVersion.v11,
      dropParams: const {'oaid'},
      extraHeaders: {
        'cookie': 'ka=open',
        if (cred.uid.isNotEmpty) 'client_user_token': cred.uid,
      },
    );
    return [for (final item in j.objList('store_thread')) ThreadStoreItem.fromJson(item)];
  }

  Future<void> addThreadStore({
    required int threadId,
    int postId = 0,
  }) async {
    final cred = credentialProvider();
    final payload = jsonEncode([
      {'tid': '$threadId', 'pid': '$postId', 'status': 1},
    ]);
    await _postOfficialJson(
      '/c/c/post/addstore',
      {'data': payload, 'stoken': cred.stoken},
      dropParams: const {'oaid'},
      extraHeaders: {
        'cookie': 'ka=open',
        if (cred.uid.isNotEmpty) 'client_user_token': cred.uid,
      },
    );
  }

  Future<void> removeThreadStore({
    required int threadId,
    int? forumId,
  }) async {
    final cred = credentialProvider();
    await _postOfficialJson(
      '/c/c/post/rmstore',
      {
        'tid': '$threadId',
        'fid': forumId != null && forumId > 0 ? '$forumId' : 'null',
        'tbs': cred.tbs,
        'stoken': cred.stoken,
        'user_id': cred.uid,
      },
      dropParams: const {'oaid'},
      extraHeaders: {
        'cookie': 'ka=open',
        if (cred.uid.isNotEmpty) 'client_user_token': cred.uid,
      },
    );
  }

  /// 关注 / 取关用户。
  Future<void> toggleFollowUser({
    required String portrait,
    required bool follow,
    String? tbsOverride,
  }) async {
    final cred = credentialProvider();
    final tbs = (tbsOverride != null && tbsOverride.isNotEmpty)
        ? tbsOverride
        : cred.tbs;
    await _postOfficialJson(
      follow ? '/c/c/user/follow' : '/c/c/user/unfollow',
      {
        'portrait': portrait,
        'tbs': tbs,
        'authsid': 'null',
        'stoken': cred.stoken,
        'from_type': '2',
        'in_live': '0',
      },
      clientVersion: TiebaClientVersion.v11,
    );
  }

  /// 修改个人资料。
  Future<void> modifyProfile({
    required String nickName,
    required String intro,
    required int sex,
    String birthdayTime = '0',
    String birthdayShowStatus = '1',
  }) async {
    final cred = credentialProvider();
    await _postOfficialJson(
      '/c/c/profile/modify',
      {
        'birthday_show_status': birthdayShowStatus,
        'birthday_time': birthdayTime,
        'intro': intro,
        'sex': '$sex',
        'nick_name': nickName,
        'stoken': cred.stoken,
        'cam': '',
        'need_cam_decrypt': '1',
        'need_keep_nickname_flag': '0',
      },
      extraHeaders: const {'cookie': 'ka=open'},
    );
  }

  /// 通知中心（回复我的 / @我的）。
  Future<({List<NotificationItem> items, bool hasMore})> replyMe({
    int page = 1,
  }) async {
    final j = await _postNewJson('/c/u/feed/replyme', {'pn': '$page'});
    final list = j.objList('reply_list');
    final pageObj = j.obj('page');
    return (
      items: [for (final item in list) NotificationItem.fromJson(item)],
      hasMore: pageObj?.boolean('has_more') ?? false,
    );
  }

  Future<({List<NotificationItem> items, bool hasMore})> atMe({
    int page = 1,
  }) async {
    final j = await _postNewJson('/c/u/feed/atme', {'pn': '$page'});
    final list = j.objList('at_list');
    final pageObj = j.obj('page');
    return (
      items: [for (final item in list) NotificationItem.fromJson(item)],
      hasMore: pageObj?.boolean('has_more') ?? false,
    );
  }

  /// 回复帖子 / 楼层 / 楼中楼（Protobuf V12_POST `post/add?cmd=309731`）。
  Future<void> addPost({
    required int forumId,
    required String forumName,
    required int threadId,
    required String content,
    String nameShow = '',
    int? quotePostId,
    int? subPostId,
    int? replyUid,
    String? tbsOverride,
  }) async {
    final cred = credentialProvider();
    final tbs = (tbsOverride != null && tbsOverride.isNotEmpty)
        ? tbsOverride
        : cred.tbs;
    final reqBytes = TiebaProtoCodec.encodeAddPostRequest(
      device: device,
      forumId: forumId,
      forumName: forumName,
      threadId: threadId,
      content: content,
      tbs: tbs,
      bduss: cred.bduss,
      stoken: cred.stoken,
      zid: cred.zid,
      nameShow: nameShow,
      quotePostId: quotePostId,
      subPostId: subPostId,
      replyUid: replyUid,
    );
    final respBytes = await _postProto(
      path: '/c/c/post/add?cmd=309731&format=protobuf',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v12Post,
      signed: true,
      isPost: true,
    );
    TiebaProtoCodec.unwrapResponse(respBytes);
  }

  /// 发新帖（Protobuf V12_POST `thread/add?cmd=309730`）。
  Future<void> addThread({
    required int forumId,
    required String forumName,
    required String title,
    required String content,
    String nameShow = '',
    String? tbsOverride,
  }) async {
    final cred = credentialProvider();
    final tbs = (tbsOverride != null && tbsOverride.isNotEmpty)
        ? tbsOverride
        : cred.tbs;
    final reqBytes = TiebaProtoCodec.encodeAddThreadRequest(
      device: device,
      forumId: forumId,
      forumName: forumName,
      title: title,
      content: content,
      tbs: tbs,
      bduss: cred.bduss,
      stoken: cred.stoken,
      zid: cred.zid,
      nameShow: nameShow,
    );
    final respBytes = await _postProto(
      path: '/c/c/thread/add?cmd=309730&format=protobuf',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v12Post,
      signed: true,
      isPost: true,
    );
    TiebaProtoCodec.unwrapResponse(respBytes);
  }

  /// 投票（Protobuf V12_POST `post/addPollPost?cmd=309006`）。
  Future<void> votePoll({
    required int forumId,
    required int threadId,
    required List<int> optionIds,
  }) async {
    final reqBytes = TiebaProtoCodec.encodeAddPollPostRequest(
      forumId: forumId,
      threadId: threadId,
      optionIds: optionIds,
    );
    final respBytes = await _postProto(
      path: '/c/c/post/addPollPost?cmd=309006&format=protobuf',
      protoBytes: reqBytes,
      clientVersion: TiebaClientVersion.v12Post,
      signed: true,
      isPost: true,
    );
    TiebaProtoCodec.unwrapResponse(respBytes);
  }

  /// 删帖 / 删楼层。
  Future<void> deletePost({
    required int forumId,
    required String forumName,
    required int threadId,
    required int postId,
    bool isFloor = false,
  }) async {
    final cred = credentialProvider();
    await _postOfficialJson('/c/c/bawu/delpost', {
      'fid': '$forumId',
      'word': forumName,
      'z': '$threadId',
      'pid': '$postId',
      'isfloor': isFloor ? '1' : '0',
      'src': isFloor ? '3' : '1',
      'is_vipdel': '0',
      'delete_my_post': '1',
      'tbs': cred.tbs,
    });
  }

  /// 分片上传图片（与 TiebaLite `ImageUploader` 协议一致，单分片 512KB）。
  Future<UploadPicResult> uploadPicture({
    required File file,
    required String forumName,
    int width = 1080,
    int height = 1080,
    bool saveOrigin = false,
    void Function(double progress)? onProgress,
  }) async {
    final cred = credentialProvider();
    final allBytes = await file.readAsBytes();
    final fileMd5 = md5.convert(allBytes).toString().toLowerCase();
    const chunkSize = 512000;
    final totalChunks = max(1, (allBytes.length + chunkSize - 1) ~/ chunkSize);
    Map<String, dynamic> lastResp = const {};

    for (var i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = min(allBytes.length, start + chunkSize);
      final chunkBytes = Uint8List.sublistView(allBytes, start, end);
      final isFinish = i == totalChunks - 1;
      final fields = <String, String>{
        ..._baseCommonParams(cred.bduss),
        '_client_version': TiebaClientVersion.v12,
        'active_timestamp': '${device.activeTimestamp}',
        'android_id': device.base64AndroidId,
        if (device.baiduId.isNotEmpty) 'baiduid': device.baiduId,
        'brand': device.brand,
        'cmode': '1',
        'cuid': device.newCuid,
        'cuid_galaxy2': device.newCuid,
        'cuid_gid': '',
        'c3_aid': device.aid,
        'event_day': device.eventDay,
        'extra': '',
        'first_install_time': '${device.firstInstallTime}',
        'framework_ver': '3340042',
        'from': 'tieba',
        'is_teenager': '0',
        'last_update_time': '${device.lastUpdateTime}',
        'mac': '02:00:00:00:00:00',
        if (device.sampleId.isNotEmpty) 'sample_id': device.sampleId,
        'start_scheme': '',
        'start_type': '1',
        'oaid': device.oaidJson,
        'alt': 'json',
        'chunkNo': '${i + 1}',
        'forum_name': forumName,
        'groupId': '1',
        'height': '$height',
        'width': '$width',
        'isFinish': isFinish ? '1' : '0',
        'is_bjh': '0',
        'pic_water_type': '0',
        'resourceId': '$fileMd5$chunkSize',
        'saveOrigin': saveOrigin ? '1' : '0',
        'size': '${allBytes.length}',
        'small_flow_fname': forumName,
      };
      final bodyBytes = _buildTiebaMultipart(
        fields: fields,
        signed: true,
        fileNameField: 'chunk',
        fileBytes: chunkBytes,
      );
      final resp = await _dio.post<String>(
        '$_officialHost/c/s/uploadPicture',
        data: Stream.fromIterable([bodyBytes]),
        options: Options(
          headers: {
            'User-Agent': 'bdtb for Android ${TiebaClientVersion.v12}',
            'cookie': device.baiduId.isNotEmpty
                ? 'ka=open;BAIDUID=${device.baiduId}'
                : 'ka=open',
            'Content-Type': 'multipart/form-data; boundary=$_boundary',
            'Content-Length': '${bodyBytes.length}',
          },
          responseType: ResponseType.plain,
        ),
      );
      lastResp = _decodeJsonChecked(resp.data);
      onProgress?.call((i + 1) / totalChunks);
    }

    final info = lastResp.obj('info') ?? lastResp;
    final originPic = info.obj('origin_pic') ?? info;
    final picId = info.str('pic_id_encode', info.str('pic_id'));
    if (picId.isEmpty) throw const TiebaApiException(-1, '上传图片未返回 pic_id');
    return UploadPicResult(
      picId: picId,
      width: originPic.intOf('width', width),
      height: originPic.intOf('height', height),
    );
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  Map<String, String> _baseCommonParams(String bduss) => {
    if (bduss.isNotEmpty) 'BDUSS': bduss,
    if (device.clientId != null && device.clientId!.isNotEmpty)
      '_client_id': device.clientId!,
    '_client_type': '2',
    '_os_version': device.osVersion,
    'model': device.model,
    'net_type': '1',
    '_phone_imei': device.imei,
    'timestamp': '${DateTime.now().millisecondsSinceEpoch}',
  };

  Map<String, String> _stParams() {
    final num = 100 + _random.nextInt(750);
    if (num <= 120) return {'stErrorNums': '0'};
    final size = ((_random.nextDouble() * 8 + 0.4) * num).round();
    return {
      'stErrorNums': '1',
      'stMethod': '1',
      'stMode': '1',
      'stTimesNum': '1',
      'stTime': '$num',
      'stSize': '$size',
    };
  }

  String _colonCookie(Map<String, String> pairs) =>
      pairs.entries.map((e) => '${e.key}:${e.value}').join('; ');

  Uint8List _buildTiebaMultipart({
    required Map<String, String> fields,
    required bool signed,
    required String fileNameField,
    required Uint8List fileBytes,
  }) {
    final builder = BytesBuilder(copy: false);
    const crlf = '\r\n';

    void writeTextPart(String name, String value) {
      builder.add(
        utf8.encode(
          '--$_boundary$crlf'
          'Content-Disposition: form-data; name="$name"$crlf'
          '$crlf'
          '$value$crlf',
        ),
      );
    }

    if (signed) {
      final signedRes = signMultipartFields(fields);
      for (final e in signedRes.sorted) {
        writeTextPart(e.key, e.value);
      }
      writeTextPart('sign', signedRes.sign);
    } else {
      for (final e in fields.entries) {
        writeTextPart(e.key, e.value);
      }
    }

    // 文件分片永远排在最后（与 SortAndSignInterceptor / MyMultipartBody 严格一致）
    builder.add(
      utf8.encode(
        '--$_boundary$crlf'
        'Content-Disposition: form-data; name="$fileNameField"; filename="file"$crlf'
        '$crlf',
      ),
    );
    builder.add(fileBytes);
    builder.add(utf8.encode('$crlf--$_boundary--$crlf'));
    return builder.toBytes();
  }

  void _captureBaiduId(List<String>? setCookies) {
    if (setCookies == null || setCookies.isEmpty) return;
    if (device.baiduId.isNotEmpty) return;
    for (final line in setCookies) {
      final first = line.split(';').first.trim();
      final idx = first.indexOf('=');
      if (idx <= 0) continue;
      final k = first.substring(0, idx).trim();
      final v = first.substring(idx + 1).trim();
      if (k.toUpperCase() == 'BAIDUID' && v.isNotEmpty) {
        device.updateBaiduId(v);
        break;
      }
    }
  }

  Map<String, dynamic> _decodeJsonChecked(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      throw const TiebaApiException(-1, '服务端返回空响应');
    }
    final decoded = jsonDecode(raw);
    final map = jObj(decoded);
    if (map == null) {
      throw const TiebaApiException(-2, '响应格式异常');
    }
    final code = map.intOrNull('error_code') ??
        map.intOrNull('errno') ??
        map.intOrNull('no') ??
        0;
    if (code != 0) {
      final errField = map.opt('error');
      String msg = map.str('error_msg', map.str('errmsg'));
      if (msg.isEmpty) {
        if (errField is String) {
          msg = errField;
        } else if (errField is Map) {
          msg = jObj(errField)?.str('errmsg', jObj(errField)?.str('usermsg') ?? '') ?? '';
        }
      }
      throw TiebaApiException(code, msg);
    }
    return map;
  }
}
