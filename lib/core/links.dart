/// 贴吧链接解析结果（帖子 / 贴吧 / 用户 / 楼中楼 / 外链）。
sealed class TiebaLink {
  const TiebaLink();
}

final class TiebaThreadLink extends TiebaLink {
  const TiebaThreadLink({
    required this.threadId,
    this.postId,
    this.subPostId,
  });

  final int threadId;
  final int? postId;
  final int? subPostId;
}

final class TiebaForumLink extends TiebaLink {
  const TiebaForumLink(this.forumName);

  final String forumName;
}

final class TiebaUserLink extends TiebaLink {
  const TiebaUserLink({this.uid, this.portrait});

  final int? uid;
  final String? portrait;
}

final class TiebaWebLink extends TiebaLink {
  const TiebaWebLink(this.url);

  final String url;
}

/// 解析贴吧 URL 或自定义 scheme（`tieba://...` / `https://tieba.baidu.com/...`）。
TiebaLink parseTiebaLink(String raw) {
  final trimmed = raw.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return TiebaWebLink(trimmed);

  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  final path = uri.path;

  // 贴吧客户端自己的跳转协议：preview_file 带真实地址，其余是客户端专有能力。
  // 实际链接形如 `tiebaclient://action/preview_file?url=…`，动作在路径里。
  if (scheme == 'tiebaclient') {
    final action = uri.queryParameters['action'] ??
        (path.startsWith('/') ? path.substring(1) : path);
    if (action == 'preview_file') {
      final real = uri.queryParameters['url'];
      if (real != null && real.isNotEmpty) return parseTiebaLink(real);
    }
    return TiebaWebLink(trimmed);
  }

  // 贴吧的跳转中转页，真实地址在 url 参数里，偶尔会被拼成 http://https://。
  if (path == '/mo/q/checkurl') {
    final real = uri.queryParameters['url'];
    if (real != null && real.isNotEmpty) {
      return parseTiebaLink(real.replaceFirst('http://https://', 'https://'));
    }
  }

  if (scheme == 'tieba') {
    final tid = int.tryParse(uri.queryParameters['tid'] ?? uri.queryParameters['kz'] ?? '');
    if (tid != null && tid > 0) {
      return TiebaThreadLink(
        threadId: tid,
        postId: int.tryParse(uri.queryParameters['pid'] ?? ''),
        subPostId: int.tryParse(uri.queryParameters['spid'] ?? uri.queryParameters['cid'] ?? ''),
      );
    }
    final kw = uri.queryParameters['kw'] ?? uri.queryParameters['forum'];
    if (kw != null && kw.isNotEmpty) {
      return TiebaForumLink(kw);
    }
    final uid = int.tryParse(uri.queryParameters['uid'] ?? '');
    if (uid != null && uid > 0) return TiebaUserLink(uid: uid);
  }

  final isTiebaHost = host == 'tieba.baidu.com' ||
      host == 'tiebac.baidu.com' ||
      host == 'wapp.baidu.com' ||
      host.endsWith('.tieba.baidu.com');

  if (isTiebaHost) {
    // /p/1234567890
    final pMatch = RegExp(r'^/p/(\d+)').firstMatch(path);
    if (pMatch != null) {
      final tid = int.tryParse(pMatch.group(1)!);
      if (tid != null && tid > 0) {
        return TiebaThreadLink(
          threadId: tid,
          postId: int.tryParse(
            uri.queryParameters['pid'] ?? uri.queryParameters['fid_pid'] ?? '',
          ),
          subPostId: int.tryParse(
            uri.queryParameters['cid'] ?? uri.queryParameters['spid'] ?? '',
          ),
        );
      }
    }

    // /f?kz=123456 或 /mo/q/m?kz=123456
    final kz = int.tryParse(uri.queryParameters['kz'] ?? uri.queryParameters['tid'] ?? '');
    if (kz != null && kz > 0) {
      return TiebaThreadLink(
        threadId: kz,
        postId: int.tryParse(uri.queryParameters['pid'] ?? ''),
        subPostId: int.tryParse(uri.queryParameters['cid'] ?? ''),
      );
    }

    // /f?kw=贴吧名
    final kw = uri.queryParameters['kw'];
    if (kw != null && kw.isNotEmpty) {
      return TiebaForumLink(kw);
    }

    // /home/main?id=tb.1.xxx 或 ?un=xxx 或 ?uid=123
    if (path.startsWith('/home/main')) {
      final uid = int.tryParse(uri.queryParameters['uid'] ?? '');
      final id = uri.queryParameters['id'];
      if (uid != null && uid > 0) return TiebaUserLink(uid: uid);
      if (id != null && id.isNotEmpty) return TiebaUserLink(portrait: id);
    }
  }

  return TiebaWebLink(trimmed);
}
