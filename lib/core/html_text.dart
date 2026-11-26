import 'emoticons.dart';

/// 贴吧富文本 AST 节点类型（兼容 Protobuf `PbContent` 与纯文本 `#(滑稽)` 解析）。
sealed class TiebaRichNode {
  const TiebaRichNode();
}

final class RichTextNode extends TiebaRichNode {
  const RichTextNode(this.text);
  final String text;
}

final class RichLinkNode extends TiebaRichNode {
  const RichLinkNode({required this.label, required this.url});
  final String label;
  final String url;
}

final class RichEmoticonNode extends TiebaRichNode {
  const RichEmoticonNode({required this.id, required this.name});
  final String id;
  final String name;
}

final class RichAtNode extends TiebaRichNode {
  const RichAtNode({required this.text, required this.uid});
  final String text;
  final int uid;
}

final class RichImageNode extends TiebaRichNode {
  const RichImageNode({
    required this.url,
    required this.originUrl,
    this.width = 0,
    this.height = 0,
    this.originSize = 0,
    this.showOriginal = false,
  });

  final String url;
  final String originUrl;
  final int width;
  final int height;
  final int originSize;
  final bool showOriginal;
}

final class RichVideoNode extends TiebaRichNode {
  const RichVideoNode({
    required this.coverUrl,
    required this.videoUrl,
    this.webUrl = '',
    this.width = 0,
    this.height = 0,
    this.duration = 0,
  });

  final String coverUrl;
  final String videoUrl;
  final String webUrl;
  final int width;
  final int height;
  final int duration;
}

final class RichVoiceNode extends TiebaRichNode {
  const RichVoiceNode({required this.md5, required this.durationMs});
  final String md5;
  final int durationMs;
}

/// 解析纯文本中的 `#(表情)`、`[表情]` 与 HTTP/HTTPS 链接为富文本节点列表。
List<TiebaRichNode> parseTiebaPlainText(String text) {
  if (text.isEmpty) return const [];
  final pattern = RegExp(
    r'#\(([^()]{1,16})\)|\[([^\[\]]{1,16})\]|(https?://[^\s<>"]+)',
  );
  final nodes = <TiebaRichNode>[];
  var cursor = 0;

  for (final m in pattern.allMatches(text)) {
    if (m.start > cursor) {
      nodes.add(RichTextNode(text.substring(cursor, m.start)));
    }
    final hashEmo = m.group(1);
    final bracketEmo = m.group(2);
    final url = m.group(3);
    if (hashEmo != null || bracketEmo != null) {
      final name = (hashEmo ?? bracketEmo)!;
      final id = TiebaEmoticons.idForName(name);
      if (id != null) {
        nodes.add(RichEmoticonNode(id: id, name: name));
      } else {
        nodes.add(RichTextNode(m.group(0)!));
      }
    } else if (url != null) {
      nodes.add(RichLinkNode(label: url, url: url));
    }
    cursor = m.end;
  }

  if (cursor < text.length) {
    nodes.add(RichTextNode(text.substring(cursor)));
  }
  return nodes;
}

/// 解析贴吧 `bsize` 字段（形如 `"1080,1920"`）。
(int width, int height) parseBsize(String raw) {
  final parts = raw.split(',');
  if (parts.length != 2) return (0, 0);
  final w = int.tryParse(parts[0].trim()) ?? 0;
  final h = int.tryParse(parts[1].trim()) ?? 0;
  return (w, h);
}

/// 把富文本节点拼成可粘贴的纯文本，规则与 TiebaLite 的 `List<PbContent>.plainText` 对齐：
///
/// - 文字 / @ / 链接 / 表情连成一段：链接只留显示文字，表情还原成 `#(名字)`
///   （粘回贴吧仍会渲染成表情），@ 原样保留；
/// - 图片 / 视频 / 语音没有文字，各自单独成行，用 `[图片]` 这类占位标出来
///   （TiebaLite 里它们是独立的 render，`plainText` 用换行拼接）。
String richTextToPlainText(List<TiebaRichNode> nodes) {
  final segments = <String>[];
  final run = StringBuffer();

  void flushRun() {
    if (run.isEmpty) return;
    segments.add(run.toString());
    run.clear();
  }

  for (final node in nodes) {
    switch (node) {
      case RichTextNode():
        run.write(node.text);
      case RichAtNode():
        run.write(node.text);
      case RichLinkNode():
        run.write(node.label.isEmpty ? node.url : node.label);
      case RichEmoticonNode():
        run.write('#(${node.name})');
      case RichImageNode():
        flushRun();
        segments.add('[图片]');
      case RichVideoNode():
        flushRun();
        segments.add('[视频]');
      case RichVoiceNode():
        flushRun();
        segments.add('[语音]');
    }
  }
  flushRun();
  return segments.join('\n').trim();
}
