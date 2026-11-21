import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/native_channels.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';

/// 内置浏览器页（支持刷新、复制当前链接、系统浏览器打开）。
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
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
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
          onPressed: () async {
            final ok = await NativeChannels.openInBrowser(_currentUrl);
            if (!ok && context.mounted) {
              showFrostedToast(context, '没有找到可用的系统浏览器');
            }
          },
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
