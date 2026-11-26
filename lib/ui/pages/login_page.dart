import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/native_channels.dart';
import '../../data/repo.dart';
import '../widgets/common.dart';
import '../widgets/segmented_capsule.dart';

/// 登录页：支持百度网页登录自动抓取 Cookie 与手动粘贴 Cookie/BDUSS 登录。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.fresh = false});

  /// 修登录态时置 true：进来先清空旧 Cookie 再登录。
  ///
  /// 旧的百度会话还在时，passport 会直接跳回贴吧、连 STOKEN 都原样复用，
  /// 于是「重新登录」并不能换掉那个已经被写接口判死的令牌。
  final bool fresh;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _loginUrl =
      'https://wappass.baidu.com/passport?login&u=https%3A%2F%2Ftieba.baidu.com%2Findex%2Ftbwise%2Fmine';

  /// 登录后落地的贴吧页：带 BDUSS 的会话访问它时，服务端会把 STOKEN 种进来。
  static const _sessionUrl = 'https://tieba.baidu.com/index/tbwise/mine';

  int _mode = 0; // 0=网页登录, 1=Cookie登录
  late final WebViewController _web;
  final TextEditingController _cookieInput = TextEditingController();
  bool _verifying = false;

  /// 防止 onPageFinished 连续触发时并发抓 Cookie。
  bool _capturing = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageFinished: (url) {
            if (url.contains('tieba.baidu.com/index/tbwise') ||
                url.contains('tiebac.baidu.com/index/tbwise')) {
              _tryCaptureFromWebView();
            }
          },
        ),
      );
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.fresh) await NativeChannels.clearCookies();
    if (!mounted) return;
    await _web.loadRequest(Uri.parse(_loginUrl));
  }

  @override
  void dispose() {
    _cookieInput.dispose();
    super.dispose();
  }

  /// 从 WebView 抓 Cookie 登录。
  ///
  /// 只读**贴吧域名**下的 Cookie（TiebaLite 也是取 tbwise 页面那一份）：passport /
  /// wappass 域名下也有同名的 STOKEN，但那份只对网页有效，拿去回帖 / 收藏会被判
  /// 成未登录。刚跳回贴吧时 STOKEN 往往还没种下来，所以这里重试几次，中途再访问
  /// 一次贴吧首页催一下；实在等不到也照样登录，只是把限制明确告诉用户。
  Future<void> _tryCaptureFromWebView() async {
    if (_verifying || _capturing) return;
    _capturing = true;
    try {
      var jar = <String, String>{};
      for (var attempt = 0; attempt < 8; attempt++) {
        jar = await NativeChannels.readTiebaCookies();
        if (!mounted) return;
        if ((jar['BDUSS'] ?? '').isEmpty) return;
        if ((jar['STOKEN'] ?? '').isNotEmpty) break;
        if (attempt == 2) {
          unawaited(_web.loadRequest(Uri.parse(_sessionUrl)));
        }
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
      }
      if ((jar['BDUSS'] ?? '').isEmpty) return;
      final raw = jar.entries.map((e) => '${e.key}=${e.value}').join('; ');
      await _finishLogin(raw);
    } finally {
      _capturing = false;
    }
  }

  Future<void> _finishLogin(String rawCookie) async {
    if (_verifying) return;
    setState(() => _verifying = true);
    try {
      final acc = await context.read<TiebaRepo>().loginWithCookieString(
        rawCookie,
      );
      if (!mounted) return;
      if (acc.canWrite) {
        showFrostedToast(context, '欢迎回来，${acc.displayName}');
      } else {
        showFrostedToast(
          context,
          '已登录 ${acc.displayName}，但凭据缺少 ${acc.writeBlockReason}：'
          '只能浏览，回帖 / 收藏需要含 STOKEN 的完整 Cookie。',
          level: BannerLevel.warning,
        );
      }
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      showFrostedToast(context, cleanError(e), level: BannerLevel.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return FrostedPage(
      title: '登录贴吧',
      actions: [
        if (_mode == 0)
          TextButton(
            onPressed: _verifying ? null : _tryCaptureFromWebView,
            child: const Text('读取登录'),
          ),
      ],
      body: Padding(
        padding: EdgeInsets.only(top: pageTopInset(context)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: FrostedSegmentedControl<int>(
                value: _mode,
                onChanged: (v) => setState(() => _mode = v),
                segments: const [
                  (0, '网页登录'),
                  (1, '粘贴 Cookie'),
                ],
              ),
            ),
            if (_verifying)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: FrostedLoading(label: '正在校验账号凭据...'),
              ),
            Expanded(
              child: _mode == 0
                  ? Column(
                      children: [
                        if (_progress > 0 && _progress < 100)
                          LinearProgressIndicator(value: _progress / 100.0),
                        Expanded(child: WebViewWidget(controller: _web)),
                      ],
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        8,
                        14,
                        MediaQuery.paddingOf(context).bottom + 24,
                      ),
                      children: [
                        FrostedCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '粘贴百度 Cookie（至少包含 BDUSS，推荐同时带 STOKEN）',
                                style: AppTextStyle.footnote
                                    .of(context)
                                    .copyWith(color: scheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _cookieInput,
                                minLines: 4,
                                maxLines: 8,
                                decoration: const InputDecoration(
                                  hintText: 'BDUSS=...; STOKEN=...; BAIDUID=...',
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _verifying
                                      ? null
                                      : () {
                                          var raw = _cookieInput.text.trim();
                                          if (raw.isEmpty) {
                                            showFrostedToast(
                                              context,
                                              '请先粘贴 Cookie 或 BDUSS',
                                            );
                                            return;
                                          }
                                          if (!raw.contains('=')) {
                                            raw = 'BDUSS=$raw';
                                          }
                                          _finishLogin(raw);
                                        },
                                  child: Text(
                                    _verifying ? '校验中...' : '验证并登录',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
