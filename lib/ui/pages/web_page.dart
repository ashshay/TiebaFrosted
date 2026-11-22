import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/links.dart';
import '../../data/native_channels.dart';
import '../../data/settings.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';

/// 内置浏览器页（支持刷新、复制当前链接、系统浏览器打开）。
///
/// 页面里的链接分三种去处：贴吧自己的链接留在本页继续加载；站外链接按
/// 「使用内置浏览器」设置决定留在本页还是交给系统浏览器；非 http(s) 的
/// （`mailto:`、`tg:` 之类）一律交给系统，WebView 处理不了。
class WebPage extends StatefulWidget {
  const WebPage({
    super.key,
    required this.url,
    this.initialTitle,
  });

  final String url;
  final String? initialTitle;

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  late final WebViewController _controller;
  late String _currentUrl = widget.url;
  late String _title = widget.initialTitle ?? '网页';
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onUrlChange: (change) {
            final u = change.url;
            if (u != null && u.isNotEmpty) _currentUrl = u;
          },
          onPageFinished: (url) async {
            _currentUrl = url;
            final t = await _controller.getTitle();
            if (mounted && t != null && t.trim().isNotEmpty) {
              setState(() => _title = t.trim());
            }
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (request.isMainFrame && _shouldLeaveWebView(url)) {
              unawaited(_handOff(url));
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// 站外链接且设置要求交给系统浏览器时，本页不该继续加载它。
  bool _shouldLeaveWebView(String url) {
    if (context.read<FrostedSettings>().useWebView) return false;
    final parsed = parseTiebaLink(url);
    return parsed is TiebaWebLink;
  }

  Future<void> _handOff(String url) async {
    final ok = await NativeChannels.openInBrowser(url);
    if (!ok && mounted) {
      showFrostedToast(context, '没有找到可用的系统浏览器');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrostedPage(
      title: _title,
      actions: [
        IconButton(
          onPressed: () => _controller.reload(),
          tooltip: '刷新',
          icon: const GlyphIcon(FrostedGlyphs.refresh, size: 19),
        ),
        IconButton(
          onPressed: () => _handOff(_currentUrl),
          tooltip: '用浏览器打开',
          icon: const GlyphIcon(FrostedGlyphs.openExternal, size: 19),
        ),
        IconButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _currentUrl));
            if (context.mounted) showFrostedToast(context, '已复制链接');
          },
          tooltip: '复制链接',
          icon: const GlyphIcon(FrostedGlyphs.link, size: 19),
        ),
      ],
      body: Padding(
        padding: EdgeInsets.only(top: pageTopInset(context)),
        child: Column(
          children: [
            if (_progress > 0 && _progress < 100)
              LinearProgressIndicator(value: _progress / 100.0),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
