import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../core/html_text.dart';
import '../../data/media_saver.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/remote_image.dart';

/// 全屏看图页：支持多图左右翻页、双指缩放、切换原图与保存到相册。
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  final List<RichImageNode> images;
  final int initialIndex;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController _page = PageController(
    initialPage: widget.initialIndex.clamp(
      0,
      widget.images.isEmpty ? 0 : widget.images.length - 1,
    ),
  );
  late int _index = widget.initialIndex;
  final Set<int> _originIndexes = {};
  bool _saving = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  RichImageNode get _current => widget.images[_index];

  String _urlFor(int i) {
    final img = widget.images[i];
    if (_originIndexes.contains(i) && img.originUrl.isNotEmpty) {
      return img.originUrl;
    }
    return img.url.isNotEmpty ? img.url : img.originUrl;
  }

  Future<void> _saveCurrent() async {
    if (_saving || widget.images.isEmpty) return;
    setState(() => _saving = true);
    try {
      final url = _current.originUrl.isNotEmpty
          ? _current.originUrl
          : _current.url;
      await context.read<MediaSaver>().saveImageFromUrl(url);
      if (mounted) {
        HapticFeedback.lightImpact();
        showFrostedToast(context, '已保存到系统相册');
      }
    } on Object catch (e) {
      if (mounted) {
        showFrostedToast(context, cleanError(e), level: BannerLevel.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showActions() async {
    final picked = await showFrostedChoices<String>(
      context,
      title: '图片操作',
      choices: const [
        FrostedChoice(value: 'save', label: '保存到相册'),
        FrostedChoice(value: 'origin', label: '查看原图'),
        FrostedChoice(value: 'copy', label: '复制图片链接'),
      ],
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case 'save':
        await _saveCurrent();
      case 'origin':
        setState(() => _originIndexes.add(_index));
      case 'copy':
        final url = _current.originUrl.isNotEmpty
            ? _current.originUrl
            : _current.url;
        await Clipboard.setData(ClipboardData(text: url));
        if (mounted) showFrostedToast(context, '已复制图片链接');
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: const Color(0xFF000000),
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _page,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                return GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  onLongPress: _showActions,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: RemoteImage(
                        url: _urlFor(i),
                        fit: BoxFit.contain,
                        resizeCache: false,
                        transparentPlaceholder: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: top + 8,
            child: Row(
              children: [
                FrostedTapSurface(
                  onPressed: () => Navigator.of(context).maybePop(),
                  pill: true,
                  fill: const Color(0x66000000),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: GlyphIcon(
                      Glyphs.chevronBack,
                      size: 22,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: const ShapeDecoration(
                    color: Color(0x66000000),
                    shape: AppShape.full,
                  ),
                  child: Text(
                    '${_index + 1} / ${widget.images.length}',
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(color: const Color(0xFFFFFFFF)),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottom + 16,
            child: Row(
              children: [
                if (!_originIndexes.contains(_index) &&
                    _current.originUrl.isNotEmpty &&
                    _current.originUrl != _current.url)
                  FrostedTapSurface(
                    onPressed: () => setState(() => _originIndexes.add(_index)),
                    pill: true,
                    fill: const Color(0x77000000),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        '查看原图',
                        style: AppTextStyle.footnote
                            .of(context)
                            .copyWith(color: const Color(0xFFFFFFFF)),
                      ),
                    ),
                  ),
                const Spacer(),
                FrostedTapSurface(
                  onPressed: _saving ? null : _saveCurrent,
                  pill: true,
                  fill: const Color(0x77000000),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_saving)
                          const ActivityIndicator(size: 14)
                        else
                          const GlyphIcon(
                            FrostedGlyphs.download,
                            size: 16,
                            color: Color(0xFFFFFFFF),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _saving ? '保存中' : '保存',
                          style: AppTextStyle.footnote
                              .of(context)
                              .copyWith(color: const Color(0xFFFFFFFF)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
