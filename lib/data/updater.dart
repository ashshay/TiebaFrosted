import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 发布包里的一条可用更新。
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.tag,
    required this.name,
    required this.notes,
    required this.pageUrl,
    required this.downloadUrl,
    this.size = 0,
    this.publishedAt = '',
  });

  /// 去掉 `v` 前缀的版本号，例如 `1.1.2`。
  final String version;
  final String tag;
  final String name;

  /// Release 说明（原始 Markdown 文本）。
  final String notes;

  /// Release 页面。
  final String pageUrl;

  /// 直接下载地址：有 APK 附件时用附件，否则退回 Release 页面。
  final String downloadUrl;
  final int size;
  final String publishedAt;

  String get sizeLabel {
    if (size <= 0) return '';
    final mb = size / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  }
}

/// 按段比较版本号：`1.1.10` > `1.1.9`；缺失的段按 0 算。
int compareVersions(String left, String right) {
  final a = left
      .split('.')
      .map((s) => int.tryParse(s.trim()) ?? 0)
      .toList(growable: false);
  final b = right
      .split('.')
      .map((s) => int.tryParse(s.trim()) ?? 0)
      .toList(growable: false);
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// `v1.1.2`、`1.1.2-rc1` 都归一成 `1.1.2`；不是版本号时返回空串。
///
/// 老版本用过 `v1.02` / `v1.01` 这种两位写法（其实是 1.0.2 / 1.0.1），
/// 这里把「次版本带前导零」的两段号按 `1.0.x` 解释，否则它会被当成 1.2、
/// 误判比 1.1.2 还新。
String normalizeVersionTag(String tag) {
  var value = tag.trim();
  if (value.toLowerCase().startsWith('v')) value = value.substring(1);
  final dash = value.indexOf('-');
  if (dash > 0) value = value.substring(0, dash);
  if (!RegExp(r'^\d+(\.\d+)*$').hasMatch(value)) return '';
  final parts = value.split('.');
  if (parts.length == 2 && parts[1].length > 1 && parts[1].startsWith('0')) {
    return '${parts[0]}.0.${int.parse(parts[1])}';
  }
  return value;
}

/// 解析 GitHub Releases 里的一条记录；拿不到版本号时返回 null。
UpdateInfo? updateInfoFromRelease(Map<String, dynamic> release) {
  final tag = release['tag_name']?.toString() ?? '';
  final version = normalizeVersionTag(tag);
  if (version.isEmpty) return null;

  var downloadUrl = '';
  var size = 0;
  final assets = release['assets'];
  if (assets is List) {
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = asset['name']?.toString().toLowerCase() ?? '';
      if (!name.endsWith('.apk')) continue;
      final url = asset['browser_download_url']?.toString() ?? '';
      if (url.isEmpty) continue;
      downloadUrl = url;
      size = int.tryParse(asset['size']?.toString() ?? '') ?? 0;
      break;
    }
  }

  final pageUrl = release['html_url']?.toString() ?? '';
  if (downloadUrl.isEmpty) downloadUrl = pageUrl;
  if (downloadUrl.isEmpty) return null;

  return UpdateInfo(
    version: version,
    tag: tag,
    name: release['name']?.toString() ?? '',
    notes: release['body']?.toString() ?? '',
    pageUrl: pageUrl,
    downloadUrl: downloadUrl,
    size: size,
    publishedAt: release['published_at']?.toString() ?? '',
  );
}

/// 从一组发布记录里挑出比 [currentVersion] 新的最高版本。
UpdateInfo? pickLatestUpdate(
  Iterable<UpdateInfo> releases,
  String currentVersion,
) {
  UpdateInfo? best;
  for (final info in releases) {
    if (compareVersions(info.version, currentVersion) <= 0) continue;
    if (best == null || compareVersions(info.version, best.version) > 0) {
      best = info;
    }
  }
  return best;
}

/// 应用更新检查：拉 GitHub Releases、比对当前版本、节流与「已提醒过」记录。
class FrostedUpdater extends ChangeNotifier {
  FrostedUpdater(this._prefs);

  static const owner = 'ashshay';
  static const repository = 'TiebaFrosted';
  static const repoUrl = 'https://github.com/$owner/$repository';
  static const releasesPage = '$repoUrl/releases';
  static const releasesApiUrl =
      'https://api.github.com/repos/$owner/$repository/releases?per_page=20';

  /// 自动检查的间隔：一次冷启动最多每 12 小时问一次。
  static const _checkInterval = Duration(hours: 12);

  static const _checkedAtKey = 'update_checked_at';
  static const _notifiedKey = 'update_notified_version';

  final SharedPreferences _prefs;

  String currentVersion = '';
  String currentBuild = '';
  UpdateInfo? latest;
  bool checking = false;
  String? error;

  bool get hasUpdate => latest != null;

  /// 这个版本还没提醒过用户（避免每次启动都弹）。
  bool get shouldNotify =>
      latest != null && _prefs.getString(_notifiedKey) != latest!.version;

  Future<void> loadCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
      currentBuild = info.buildNumber;
      notifyListeners();
    } on Object {
      currentVersion = '';
    }
  }

  /// 检查更新。[force] 为 true 时忽略节流（手动点「检查更新」）。
  Future<void> check({bool force = false}) async {
    if (checking) return;
    if (currentVersion.isEmpty) await loadCurrentVersion();
    if (!force && !_due()) return;

    checking = true;
    error = null;
    notifyListeners();
    try {
      // 网络差或走代理时请求可能一直挂着，给整次检查一个总超时，
      // 免得设置页的「正在检查…」停在那里不动。
      final releases = await _fetchReleases().timeout(
        const Duration(seconds: 15),
      );
      latest = pickLatestUpdate(releases, currentVersion);
      if (latest == null) error = null;
      await _prefs.setInt(
        _checkedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } on Object {
      error = '检查更新失败，请稍后再试';
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  Future<void> markNotified() async {
    final version = latest?.version;
    if (version == null || version.isEmpty) return;
    await _prefs.setString(_notifiedKey, version);
  }

  bool _due() {
    final last = _prefs.getInt(_checkedAtKey);
    if (last == null) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed >= _checkInterval.inMilliseconds;
  }

  Future<List<UpdateInfo>> _fetchReleases() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..userAgent = 'TiebaFrosted';
    try {
      final request = await client.getUrl(Uri.parse(releasesApiUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw const SocketException('GitHub 返回了非 200');
      }
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            ?updateInfoFromRelease(Map<String, dynamic>.from(item)),
      ];
    } finally {
      client.close(force: true);
    }
  }
}

/// 把 Release 说明压成适合弹窗阅读的纯文本：去掉 Markdown 记号、限行。
String plainReleaseNotes(String raw, {int maxLines = 14}) {
  final lines = <String>[];
  for (final source in raw.split('\n')) {
    var line = source.trimRight();
    if (line.startsWith('#')) {
      line = line.replaceFirst(RegExp(r'^#+\s*'), '');
    }
    line = line.replaceAll(RegExp(r'`'), '').replaceAll('**', '');
    line = line.replaceFirst(RegExp(r'^[-*]\s+'), '· ');
    if (line.trim().isEmpty) continue;
    lines.add(line);
    if (lines.length >= maxLines) break;
  }
  return lines.join('\n');
}
