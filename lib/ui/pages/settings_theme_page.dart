import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 外观设置页：深浅色 / 强调色（含 Monet 与色相循环）/ 4 档 ColorStyle / 3 档液态玻璃 / 字体缩放。
class SettingsThemePage extends StatelessWidget {
  const SettingsThemePage({super.key});

  static const _accentPresets = <(int, String)>[
    (0, '跟随壁纸 (Monet) / 贴吧蓝'),
    (0xFF4E9EF5, '贴吧蓝'),
    (0xFF0A84FF, '海蓝'),
    (0xFF30D158, '翠绿'),
    (0xFFFF9F0A, '琥珀'),
    (0xFFFF375F, '玫红'),
    (0xFFBF5AF2, '紫罗兰'),
    (accentHueCycle, '色相循环'),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FrostedSettings>();
    final scheme = context.colorScheme;

    String accentLabel() {
      for (final (v, label) in _accentPresets) {
        if (v == settings.accentColor) return label;
      }
      return '自定义';
    }

    String styleLabel(ColorStyle style) => switch (style) {
      ColorStyle.vivid => '鲜明 (Vivid)',
      ColorStyle.tinted => '微染 (Tinted)',
      ColorStyle.soft => '柔和 (Soft)',
      ColorStyle.monochrome => '单色 (Monochrome)',
    };

    String styleSubtitle(ColorStyle style) => switch (style) {
      ColorStyle.vivid => '高饱和强调色，界面底色保持中性',
      ColorStyle.tinted => '高饱和强调色，卡片与页面带主题色微染',
      ColorStyle.soft => '克制柔和色调，护眼耐看',
      ColorStyle.monochrome => '纯黑白灰极简单色',
    };

    String glassLabel(LiquidGlassLevel level) => switch (level) {
      LiquidGlassLevel.off => '关闭',
      LiquidGlassLevel.standard => '标准',
      LiquidGlassLevel.ultra => '超高',
    };

    final scalePercent = (settings.fontScale * 100).round();

    return FrostedPage(
      title: '外观与液态玻璃',
      body: ListView(
        padding: EdgeInsets.only(
          top: pageTopInset(context) + 4,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          const FrostedSectionTitle('主题模式'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: FrostedCard(
              child: SegmentedControl<int>(
                value: settings.darkMode,
                onChanged: settings.setDarkMode,
                segments: const [
                  (0, '跟随系统'),
                  (1, '浅色'),
                  (2, '深色'),
                ],
              ),
            ),
          ),
          const FrostedSectionTitle('色彩与材质'),
          FrostedSettingsGroup(
            children: [
              FrostedListRow(
                title: const Text('主题强调色'),
                subtitle: Text(accentLabel()),
                trailing: Container(
                  width: 22,
                  height: 22,
                  decoration: ShapeDecoration(
                    color: scheme.primary,
                    shape: AppShape.full,
                  ),
                ),
                onPressed: () async {
                  final picked = await showFrostedChoices<int>(
                    context,
                    title: '选择主题强调色',
                    choices: [
                      for (final (argb, label) in _accentPresets)
                        FrostedChoice(
                          value: argb,
                          label: label,
                          selected: settings.accentColor == argb,
                          leading: Container(
                            width: 18,
                            height: 18,
                            decoration: ShapeDecoration(
                              color: Color(
                                accentArgbAt(argb, dark: context.isDark),
                              ),
                              shape: AppShape.full,
                            ),
                          ),
                        ),
                    ],
                  );
                  if (picked != null) await settings.setAccentColor(picked);
                },
              ),
              FrostedListRow(
                title: const Text('配色风格 (ColorStyle)'),
                subtitle: Text(styleLabel(settings.colorStyle)),
                trailing: const GlyphIcon(Glyphs.chevronForward, size: 16),
                onPressed: () async {
                  final picked = await showFrostedChoices<ColorStyle>(
                    context,
                    title: '配色风格',
                    choices: [
                      for (final style in ColorStyle.values)
                        FrostedChoice(
                          value: style,
                          label: styleLabel(style),
                          subtitle: styleSubtitle(style),
                          selected: settings.colorStyle == style,
                        ),
                    ],
                  );
                  if (picked != null) await settings.setColorStyle(picked);
                },
              ),
              FrostedListRow(
                title: const Text('底栏液态玻璃'),
                subtitle: Text('当前档位：${glassLabel(settings.liquidGlass)}'),
                trailing: const GlyphIcon(Glyphs.chevronForward, size: 16),
                onPressed: () async {
                  final picked = await showFrostedChoices<LiquidGlassLevel>(
                    context,
                    title: '液态玻璃档位',
                    choices: const [
                      FrostedChoice(
                        value: LiquidGlassLevel.off,
                        label: '关闭',
                        subtitle: '最低开销，适合低端设备',
                      ),
                      FrostedChoice(
                        value: LiquidGlassLevel.standard,
                        label: '标准（推荐）',
                        subtitle: '兼顾液态玻璃质感与流畅帧率',
                      ),
                      FrostedChoice(
                        value: LiquidGlassLevel.ultra,
                        label: '超高',
                        subtitle: '完整实时折射与层次模糊细节',
                      ),
                    ]
                        .map(
                          (c) => FrostedChoice(
                            value: c.value,
                            label: c.label,
                            subtitle: c.subtitle,
                            selected: settings.liquidGlass == c.value,
                          ),
                        )
                        .toList(),
                  );
                  if (picked != null) await settings.setLiquidGlass(picked);
                },
              ),
              FrostedListRow(
                title: const Text('顶栏毛玻璃模糊'),
                subtitle: const Text('顶栏与底部输入栏背景实时模糊'),
                trailing: Switch(
                  value: settings.blurEffects,
                  onChanged: settings.setBlurEffects,
                ),
                onPressed: () => settings.setBlurEffects(!settings.blurEffects),
              ),
            ],
          ),
          const FrostedSectionTitle('排版缩放'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: FrostedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('全局字体缩放', style: AppTextStyle.subheadline.of(context)),
                      const Spacer(),
                      if (scalePercent != 100) ...[
                        FrostedTapSurface(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            settings.setFontScale(1.0);
                          },
                          pill: true,
                          fill: scheme.primary.withValues(alpha: 0.12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            child: Text(
                              '重置 100%',
                              style: AppTextStyle.caption2
                                  .of(context)
                                  .copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '$scalePercent%',
                        style: AppTextStyle.footnote
                            .of(context)
                            .copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: settings.fontScale.clamp(0.85, 1.3),
                    min: 0.85,
                    max: 1.3,
                    divisions: 9,
                    label: '$scalePercent%',
                    onChanged: settings.setFontScale,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
