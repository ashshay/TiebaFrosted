import 'package:flutter_test/flutter_test.dart';
import 'package:tieba_frosted/data/updater.dart';

Map<String, dynamic> release({
  required String tag,
  String? body,
  String? htmlUrl = 'https://github.com/ashshay/TiebaFrosted/releases/tag/v1.2.0',
  List<Map<String, dynamic>> assets = const [],
}) => {
  'tag_name': tag,
  'name': tag,
  'body': body ?? '',
  'html_url': htmlUrl,
  'assets': assets,
};

void main() {
  group('版本号比较', () {
    test('按段数值比较，不以字符串字典序为准', () {
      expect(compareVersions('1.1.10', '1.1.9'), greaterThan(0));
      expect(compareVersions('1.2.0', '1.10.0'), lessThan(0));
      expect(compareVersions('1.1.2', '1.1.2'), 0);
    });

    test('缺失的段按 0 算', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.2.1', '1.2'), greaterThan(0));
    });
  });

  group('tag 归一化', () {
    test('去掉 v 前缀与预发布后缀', () {
      expect(normalizeVersionTag('v1.1.2'), '1.1.2');
      expect(normalizeVersionTag('1.1.2'), '1.1.2');
      expect(normalizeVersionTag('v1.2.0-rc1'), '1.2.0');
    });

    test('不是版本号时返回空串', () {
      expect(normalizeVersionTag('nightly'), '');
      expect(normalizeVersionTag(''), '');
    });

    test('老版两位写法 v1.02 按 1.0.2 解释，不会盖过 1.1.2', () {
      expect(normalizeVersionTag('v1.02'), '1.0.2');
      expect(normalizeVersionTag('v1.01'), '1.0.1');
      expect(compareVersions(normalizeVersionTag('v1.02'), '1.1.2'), lessThan(0));
      // 正常的两段号不受影响
      expect(normalizeVersionTag('v1.10'), '1.10');
    });
  });

  group('Release 解析', () {
    test('有 APK 附件时用附件地址与体积', () {
      final info = updateInfoFromRelease(
        release(
          tag: 'v1.2.0',
          assets: [
            {
              'name': 'TiebaFrosted-1.2.0-arm64.apk',
              'browser_download_url': 'https://example.com/a.apk',
              'size': 21 * 1024 * 1024,
            },
          ],
        ),
      );
      expect(info, isNotNull);
      expect(info!.version, '1.2.0');
      expect(info.downloadUrl, 'https://example.com/a.apk');
      expect(info.sizeLabel, '21 MB');
    });

    test('没有 APK 附件时退回 Release 页面', () {
      final info = updateInfoFromRelease(release(tag: 'v1.2.0'));
      expect(info!.downloadUrl, contains('/releases/tag/v1.2.0'));
      expect(info.sizeLabel, '');
    });

    test('拿不到版本号时为 null', () {
      expect(updateInfoFromRelease(release(tag: 'latest')), isNull);
    });
  });

  group('挑选待更新版本', () {
    test('只挑比当前版本新的最高版本', () {
      final releases = [
        updateInfoFromRelease(release(tag: 'v1.0.0'))!,
        updateInfoFromRelease(release(tag: 'v1.3.0'))!,
        updateInfoFromRelease(release(tag: 'v1.2.0'))!,
        updateInfoFromRelease(release(tag: 'v1.1.2'))!,
      ];
      expect(pickLatestUpdate(releases, '1.1.2')!.version, '1.3.0');
    });

    test('当前已是最新时返回 null', () {
      final releases = [updateInfoFromRelease(release(tag: 'v1.1.2'))!];
      expect(pickLatestUpdate(releases, '1.1.2'), isNull);
      expect(pickLatestUpdate(releases, '1.10.0'), isNull);
    });
  });

  group('Release 说明转纯文本', () {
    test('去掉标题井号与粗体标记，列表换成点号', () {
      final text = plainReleaseNotes(
        '# v1.2.0\n\n- **修复**：讨论列表\n- 新增检查更新\n',
      );
      expect(text, contains('v1.2.0'));
      expect(text, contains('修复：讨论列表'));
      expect(text, contains('· 新增检查更新'));
      expect(text, isNot(contains('**')));
      expect(text, isNot(contains('#')));
    });

    test('按行数截断', () {
      final raw = List.generate(30, (i) => '- 第 $i 行').join('\n');
      expect(plainReleaseNotes(raw, maxLines: 5).split('\n'), hasLength(5));
    });
  });
}
