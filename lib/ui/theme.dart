import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import '../data/settings.dart';

/// 贴吧蓝作为默认强调色种子（支持 Android 12+ Monet 覆盖）。
const defaultAccent = Color(0xFF4E9EF5);

const _hueCyclePeriodMs = 36000;

int accentArgbAt(int configured, {required bool dark, DateTime? now}) {
  if (configured == accentHueCycle) {
    final millis =
        (now ?? DateTime.now()).millisecondsSinceEpoch % _hueCyclePeriodMs;
    final hue = millis / _hueCyclePeriodMs * 360;
    return _hsvToArgb(hue, dark ? 0.78 : 0.82, dark ? 0.94 : 0.88);
  }
  if (configured == 0) return defaultAccent.toARGB32();
  return configured | 0xFF000000;
}

int _hsvToArgb(double hue, double saturation, double value) {
  final h = ((hue % 360) + 360) % 360;
  final c = value * saturation;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = value - c;
  final (double r, double g, double b) = switch (h ~/ 60) {
    0 => (c, x, 0),
    1 => (x, c, 0),
    2 => (0, c, x),
    3 => (0, x, c),
    4 => (x, 0, c),
    _ => (c, 0, x),
  };
  int channel(double v) => ((v + m) * 255).round().clamp(0, 255);
  return (0xFF << 24) | (channel(r) << 16) | (channel(g) << 8) | channel(b);
}

ThemeData frostedTheme({
  required Brightness brightness,
  required int accentArgb,
  ColorStyle style = ColorStyle.soft,
  Color? exactAccent,
}) {
  var scheme = seededColorScheme(
    seedColor: Color(accentArgb),
    brightness: brightness,
    style: style,
  );
  if (exactAccent != null && style != ColorStyle.monochrome) {
    scheme = scheme.copyWith(
      primary: exactAccent,
      onPrimary: exactAccent.computeLuminance() > 0.55
          ? const Color(0xE6000000)
          : const Color(0xFFFFFFFF),
      surfaceTint: exactAccent,
    );
  }
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: SurfaceLevel.page.colorOf(scheme),
    fontFamilyFallback: const [
      'PingFang SC',
      'Noto Sans CJK SC',
      'Source Han Sans SC',
      'Microsoft YaHei',
      'sans-serif',
    ],
  );
}

extension FrostedColors on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
  Color get ink => scheme.onSurface;
  Color get inkSecondary => scheme.onSurfaceVariant;
  Color get inkTertiary => scheme.onSurfaceVariant.withValues(alpha: 0.7);
  Color get accent => scheme.primary;
  Color get danger => scheme.error;
  Color get success => const Color(0xFF30D158);
  Color get warning => const Color(0xFFFF9F0A);
  Color get cardFill => surfaceLevel.next.colorOf(scheme);
  Color get pageFill => SurfaceLevel.page.colorOf(scheme);
  bool get isDark => scheme.brightness == Brightness.dark;
}

String formatCount(int value) {
  if (value < 0) return '0';
  if (value < 10000) return '$value';
  if (value < 100000000) {
    final wan = value / 10000;
    return '${_trim(wan)}万';
  }
  final yi = value / 100000000;
  return '${_trim(yi)}亿';
}

String _trim(double value) {
  final text = value >= 100
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

String joinMeta(List<String> parts) =>
    parts.where((part) => part.trim().isNotEmpty).join(' · ');

String formatTiebaTime(int timestampSec, {DateTime? now}) {
  if (timestampSec <= 0) return '';
  final ms = timestampSec > 100000000000 ? timestampSec : timestampSec * 1000;
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final current = now ?? DateTime.now();
  final diff = current.difference(dt);
  if (diff.inSeconds < 60 && diff.inSeconds >= 0) return '刚刚';
  if (diff.inMinutes < 60 && diff.inMinutes >= 0) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24 && diff.inHours >= 0 && dt.day == current.day) {
    return '${diff.inHours}小时前';
  }
  String two(int n) => n < 10 ? '0$n' : '$n';
  if (dt.year == current.year) {
    return '${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
  return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
}
