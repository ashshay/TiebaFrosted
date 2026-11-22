import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';

/// 关于页：版本信息、TiebaLite 致谢与 GPL-3.0 开源许可说明。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '0.1.0';

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    } on Object {
      // 测试环境保留默认版本
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return FrostedPage(
      title: '关于',
      body: ListView(
        padding: EdgeInsets.only(
          top: pageTopInset(context) + 12,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: FrostedCard(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: scheme.primary,
                      shape: AppShape.xl,
                    ),
                    child: GlyphIcon(
                      FrostedGlyphs.forum,
                      size: 34,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'TiebaFrosted',
                    style: AppTextStyle.title2
                        .of(context)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '版本 $_version',
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '贴吧的数据与容错 + prism_ui 液态玻璃设计语言',
                    textAlign: TextAlign.center,
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          const FrostedSectionTitle('开源与致谢'),
          FrostedSettingsGroup(
            children: [
              FrostedListRow(
                title: const Text('源工程 TiebaLite'),
                subtitle: const Text('GPL-3.0 · 协议与容错规则参照'),
                trailing: const GlyphIcon(Glyphs.chevronForward, size: 16),
                onPressed: () => openExternalUrl(
                  context,
                  'https://github.com/HuanCheng65/TiebaLite',
                ),
              ),
              FrostedListRow(
                title: const Text('界面引擎 prism_ui'),
                subtitle: const Text('GPL-3.0 · 来自 FlClash'),
                trailing: const GlyphIcon(Glyphs.chevronForward, size: 16),
                onPressed: () => openExternalUrl(
                  context,
                  'https://github.com/chen08209/FlClash',
                ),
              ),
              const FrostedListRow(
                title: Text('软件许可协议'),
                subtitle: Text('GNU General Public License v3.0'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
