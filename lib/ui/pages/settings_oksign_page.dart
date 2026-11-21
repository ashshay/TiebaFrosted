import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/repo.dart';
import '../../data/settings.dart';
import '../routes.dart';
import '../widgets/common.dart';

/// 一键全签与自动签到设置页。
class SettingsOkSignPage extends StatefulWidget {
  const SettingsOkSignPage({super.key});

  @override
  State<SettingsOkSignPage> createState() => _SettingsOkSignPageState();
}

class _SettingsOkSignPageState extends State<SettingsOkSignPage> {
  bool _running = false;
  int _current = 0;
  int _total = 0;
  String _currentForum = '';
  String _currentStatus = '';
  final List<String> _logs = [];

  Future<void> _startOkSign() async {
    if (_running) return;
    if (!await ensureLoggedIn(context, reason: '登录后即可使用一键全签')) return;
    if (!mounted) return;

    setState(() {
      _running = true;
      _current = 0;
      _total = 0;
      _currentForum = '';
      _currentStatus = '正在获取关注贴吧列表...';
      _logs.clear();
    });

    try {
      final result = await context.read<TiebaRepo>().okSignAll(
        onProgress: (cur, total, forum, status) {
          if (!mounted) return;
          setState(() {
            _current = cur;
            _total = total;
            _currentForum = forum;
            _currentStatus = status;
            if (status != '签到中...') {
              _logs.insert(0, '$forum：$status');
            }
          });
        },
      );
      if (!mounted) return;
      final summary =
          '签到完成：共 ${result.total} 吧，本次成功 ${result.signed}，已签跳过 ${result.skipped}，失败 ${result.failed}';
      setState(() {
        _running = false;
        _currentStatus = summary;
      });
      showFrostedToast(context, summary);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _currentStatus = '出错：${cleanError(e)}';
      });
      showFrostedToast(context, cleanError(e), level: BannerLevel.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FrostedSettings>();
    final scheme = context.colorScheme;
    final progress = _total > 0 ? (_current / _total).clamp(0.0, 1.0) : 0.0;

    return FrostedPage(
      title: '自动签到',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          14,
          pageTopInset(context) + 8,
          14,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          FrostedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '立即一键全签',
                  style: AppTextStyle.headline
                      .of(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  _currentStatus.isNotEmpty
                      ? _currentStatus
                      : '优先使用官方 mSign 批量签到，其余未签贴吧低频逐一签到',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
                if (_running) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress),
                  if (_currentForum.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '$_currentForum ($_current/$_total)',
                      style: AppTextStyle.caption1
                          .of(context)
                          .copyWith(color: scheme.primary),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _running ? null : _startOkSign,
                    child: Text(_running ? '正在签到...' : '开始一键全签'),
                  ),
                ),
              ],
            ),
          ),
          const FrostedSectionTitle('签到选项'),
          FrostedSettingsGroup(
            children: [
              FrostedListRow(
                title: const Text('优先使用官方批量签到 (mSign)'),
                subtitle: const Text('对符合等级条件的贴吧合并一次请求'),
                trailing: Switch(
                  value: settings.okSignUseOfficial,
                  onChanged: settings.setOkSignUseOfficial,
                ),
              ),
              FrostedListRow(
                title: const Text('每日定时签到计划'),
                subtitle: Text(
                  '每日 ${settings.autoSignHour.toString().padLeft(2, '0')}:${settings.autoSignMinute.toString().padLeft(2, '0')}',
                ),
                trailing: Switch(
                  value: settings.autoSign,
                  onChanged: settings.setAutoSign,
                ),
              ),
            ],
          ),
          if (_logs.isNotEmpty) ...[
            const FrostedSectionTitle('本次签到记录'),
            FrostedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in _logs.take(30))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        line,
                        style: AppTextStyle.footnote
                            .of(context)
                            .copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
