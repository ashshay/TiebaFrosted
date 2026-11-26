import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../core/emoticons.dart';
import '../../data/local_db.dart';
import '../../data/repo.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/press_scale.dart';
import '../widgets/remote_image.dart';

enum ReplyMode { reply, newThread }

/// 回复与发帖编辑器：支持表情面板、最多 9 图上传进度与 SQLite 草稿持久化。
class ReplyPage extends StatefulWidget {
  const ReplyPage({
    super.key,
    required this.mode,
    required this.forumId,
    required this.forumName,
    this.threadId = 0,
    this.quotePostId,
    this.subPostId,
    this.replyUid,
    this.replyUserName,
    this.tbs = '',
  });

  final ReplyMode mode;
  final int forumId;
  final String forumName;
  final int threadId;
  final int? quotePostId;
  final int? subPostId;
  final int? replyUid;
  final String? replyUserName;
  final String tbs;

  @override
  State<ReplyPage> createState() => _ReplyPageState();
}

class _ReplyPageState extends State<ReplyPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  final List<File> _images = [];
  bool _showEmojis = false;
  bool _submitting = false;
  String _statusText = '';

  String get _draftKey => widget.mode == ReplyMode.newThread
      ? 'thread_${widget.forumId}'
      : 'reply_${widget.threadId}_${widget.quotePostId ?? 0}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreDraft());
    });
  }

  @override
  void dispose() {
    _saveDraftSync();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final draft = await context.read<LocalDb>().getDraft(_draftKey);
    if (!mounted || draft == null) return;
    if (_title.text.isEmpty && draft.title.isNotEmpty) {
      _title.text = draft.title;
    }
    if (_content.text.isEmpty && draft.content.isNotEmpty) {
      _content.text = draft.content;
    }
  }

  void _saveDraftSync() {
    if (_submitting) return;
    final content = _content.text.trim();
    final title = _title.text.trim();
    final db = context.read<LocalDb>();
    if (content.isEmpty && title.isEmpty) {
      unawaited(db.deleteDraft(_draftKey));
    } else {
      unawaited(
        db.saveDraft(
          DraftRecord(
            key: _draftKey,
            title: title,
            content: content,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ),
      );
    }
  }

  Future<void> _pickImages() async {
    if (_images.length >= 9) {
      showFrostedToast(context, '最多选择 9 张图片');
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(limit: 9 - _images.length);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      for (final x in picked) {
        if (_images.length < 9) _images.add(File(x.path));
      }
    });
  }

  void _insertEmoji(TiebaEmoticon emo) {
    final text = _content.text;
    final sel = _content.selection;
    final insert = emo.insertText;
    if (sel.isValid && sel.start >= 0 && sel.end >= 0) {
      final next = text.replaceRange(sel.start, sel.end, insert);
      _content.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start + insert.length),
      );
    } else {
      _content.text = '$text$insert';
    }
  }

  Future<void> _submit() async {
    final text = _content.text.trim();
    final title = _title.text.trim();
    if (text.isEmpty && _images.isEmpty) {
      showFrostedToast(context, '请输入内容或选择图片');
      return;
    }
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _statusText = '准备发送...';
    });

    try {
      final repo = context.read<TiebaRepo>();
      final buffer = StringBuffer(text);

      for (var i = 0; i < _images.length; i++) {
        if (mounted) {
          setState(
            () => _statusText = '上传图片 ${i + 1}/${_images.length}...',
          );
        }
        final uploaded = await repo.uploadImage(
          file: _images[i],
          forumName: widget.forumName,
          onProgress: (p) {
            if (mounted) {
              setState(
                () => _statusText =
                    '上传图片 ${i + 1}/${_images.length} (${(p * 100).round()}%)',
              );
            }
          },
        );
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(uploaded.insertTag);
      }

      if (mounted) setState(() => _statusText = '提交中...');
      if (widget.mode == ReplyMode.newThread) {
        await repo.createThread(
          forumId: widget.forumId,
          forumName: widget.forumName,
          title: title,
          content: buffer.toString(),
          tbsOverride: widget.tbs,
        );
      } else {
        await repo.reply(
          forumId: widget.forumId,
          forumName: widget.forumName,
          threadId: widget.threadId,
          content: buffer.toString(),
          quotePostId: widget.quotePostId,
          subPostId: widget.subPostId,
          replyUid: widget.replyUid,
          tbsOverride: widget.tbs,
        );
      }

      if (!mounted) return;
      await context.read<LocalDb>().deleteDraft(_draftKey);
      if (!mounted) return;
      showFrostedToast(
        context,
        widget.mode == ReplyMode.newThread ? '发帖成功' : '回复成功',
      );
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _statusText = '';
      });
      // 正文还在草稿里，登录态问题直接给一个去登录的入口，回来重发即可。
      await handleWriteFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final isThread = widget.mode == ReplyMode.newThread;
    final pageTitle = isThread
        ? '发帖到 ${widget.forumName}吧'
        : (widget.replyUserName != null && widget.replyUserName!.isNotEmpty
            ? '回复 ${widget.replyUserName}'
            : '回复帖子');
    final bottom = MediaQuery.paddingOf(context).bottom;

    return FrostedPage(
      title: pageTitle,
      resizeToAvoidBottomInset: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? '发送中' : '发送'),
          ),
        ),
      ],
      foot: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FrostedBlurBar(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                10,
                6,
                14,
                _showEmojis ? 6 : bottom + 6,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _showEmojis = !_showEmojis),
                    tooltip: '表情',
                    icon: GlyphIcon(
                      FrostedGlyphs.emoji,
                      size: 22,
                      color: _showEmojis ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting ? null : _pickImages,
                    tooltip: '添加图片',
                    icon: const GlyphIcon(FrostedGlyphs.image, size: 22),
                  ),
                  const Spacer(),
                  if (_statusText.isNotEmpty)
                    Text(
                      _statusText,
                      style: AppTextStyle.caption1
                          .of(context)
                          .copyWith(color: scheme.primary),
                    )
                  else
                    Text(
                      '${_images.length}/9 图',
                      style: AppTextStyle.caption1
                          .of(context)
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: context.disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _showEmojis
                ? Container(
                    height: 220 + bottom,
                    color: SurfaceLevel.card.colorOf(scheme),
                    padding: EdgeInsets.fromLTRB(12, 10, 12, bottom + 10),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: TiebaEmoticons.all.length,
                      itemBuilder: (context, idx) {
                        final emo = TiebaEmoticons.all[idx];
                        return PressScale(
                          scale: 0.9,
                          child: FrostedTapSurface(
                            onPressed: () => _insertEmoji(emo),
                            radius: AppCorner.sm,
                            child: Center(
                              child: RemoteImage(
                                url: emo.imageUrl,
                                width: 28,
                                height: 28,
                                cacheWidth: 160,
                                fit: BoxFit.contain,
                                transparentPlaceholder: true,
                                fadeIn: false,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          14,
          pageTopInset(context) + 8,
          14,
          bottom + 120,
        ),
        children: [
          if (isThread) ...[
            FrostedCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                controller: _title,
                decoration: const InputDecoration(hintText: '标题（可选）'),
              ),
            ),
            const SizedBox(height: 10),
          ],
          FrostedCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _content,
              autofocus: !isThread,
              minLines: 6,
              maxLines: 14,
              decoration: InputDecoration(
                hintText: isThread ? '正文内容...' : '文明发言，友善交流...',
              ),
            ),
          ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  Stack(
                    children: [
                      ClipRSuperellipse(
                        borderRadius: BorderRadius.circular(AppCorner.sm + 4),
                        child: Image.file(
                          _images[i],
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(i)),
                          child: Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: const ShapeDecoration(
                              color: Color(0x99000000),
                              shape: AppShape.full,
                            ),
                            child: const GlyphIcon(
                              FrostedGlyphs.delete,
                              size: 13,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
