import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:tieba_frosted/ui/theme.dart';
import 'package:tieba_frosted/ui/widgets/capsule_tab_strip.dart';
import 'package:tieba_frosted/ui/widgets/segmented_capsule.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(size: Size(400, 800)),
    child: Theme(
      data: frostedTheme(
        brightness: Brightness.light,
        accentArgb: defaultAccent.toARGB32(),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 320, child: child),
      ),
    ),
  ),
);

void main() {
  group('CapsulePillGeometry', () {
    test('never leaves the rounded track, even far past both ends', () {
      const count = 4;
      const trackWidth = 320.0;
      const trackHeight = 36.0;
      for (var p = -0.35; p <= count - 1 + 0.35; p += 0.05) {
        for (var stretch = -0.1; stretch <= 0.15; stretch += 0.025) {
          final g = CapsulePillGeometry.compute(
            position: p,
            stretch: stretch,
            pressBoost: 1,
            count: count,
            trackWidth: trackWidth,
            trackHeight: trackHeight,
          );
          expect(g.left, greaterThanOrEqualTo(-0.001));
          expect(g.left + g.width, lessThanOrEqualTo(trackWidth + 0.001));
          expect(g.top, greaterThanOrEqualTo(-0.001));
          expect(g.top + g.height, lessThanOrEqualTo(trackHeight + 0.001));
        }
      }
    });

    test('a middle rest position is a plain slot, not stretched', () {
      final g = CapsulePillGeometry.compute(
        position: 1,
        stretch: 0,
        pressBoost: 0,
        count: 3,
        trackWidth: 300,
        trackHeight: 36,
      );
      expect(g.left, closeTo(100, 0.001));
      expect(g.width, closeTo(100, 0.001));
      expect(g.top, closeTo(0, 0.001));
      expect(g.height, closeTo(36, 0.001));
    });

    test('a fast slide stretches horizontally and squeezes vertically', () {
      final g = CapsulePillGeometry.compute(
        position: 0.5,
        stretch: 0.16,
        pressBoost: 0,
        count: 3,
        trackWidth: 300,
        trackHeight: 36,
      );
      expect(g.width, greaterThan(100));
      expect(g.height, lessThan(36));
    });

    test(
      'overshooting an end wall compresses instead of leaving the track',
      () {
        final g = CapsulePillGeometry.compute(
          position: 2.35,
          stretch: 0,
          pressBoost: 0,
          count: 3,
          trackWidth: 300,
          trackHeight: 36,
        );
        expect(g.left + g.width, closeTo(300, 0.001));
        expect(g.width, lessThan(100));
        expect(g.height, greaterThan(36 * 0.999));
      },
    );
  });

  group('FrostedSegmentedControl', () {
    testWidgets('tapping a segment reports the new value', (tester) async {
      var value = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _host(
            FrostedSegmentedControl<int>(
              value: value,
              onChanged: (next) => setState(() => value = next),
              segments: const [(0, '推荐'), (1, '关注'), (2, '热榜')],
            ),
          ),
        ),
      );
      await tester.tap(find.text('热榜'));
      await tester.pumpAndSettle();
      expect(value, 2);
    });

    testWidgets('a horizontal drag across two slots switches', (tester) async {
      var value = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _host(
            FrostedSegmentedControl<int>(
              value: value,
              onChanged: (next) => setState(() => value = next),
              segments: const [(0, '推荐'), (1, '关注'), (2, '热榜')],
            ),
          ),
        ),
      );
      // 320 宽的轨道，3 段各约 106：从中间往右拖两格。
      await tester.drag(
        find.byType(FrostedSegmentedControl<int>),
        const Offset(210, 0),
      );
      await tester.pumpAndSettle();
      expect(value, 2);
    });

    testWidgets('an in-place tap on the selected segment keeps the value', (
      tester,
    ) async {
      var changes = 0;
      await tester.pumpWidget(
        _host(
          FrostedSegmentedControl<int>(
            value: 1,
            onChanged: (_) => changes++,
            segments: const [(0, '推荐'), (1, '关注')],
          ),
        ),
      );
      await tester.tap(find.text('关注'));
      await tester.pumpAndSettle();
      expect(changes, 0);
    });

    testWidgets('the pill stretches mid-flight and settles back to a slot', (
      tester,
    ) async {
      var value = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _host(
            FrostedSegmentedControl<int>(
              value: value,
              onChanged: (next) => setState(() => value = next),
              segments: const [(0, '推荐'), (1, '关注'), (2, '热榜')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rest = tester.getSize(find.byKey(FrostedSegmentedControl.pillKey));

      await tester.tap(find.text('热榜'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final mid = tester.getSize(find.byKey(FrostedSegmentedControl.pillKey));
      expect(mid.width, greaterThan(rest.width));

      await tester.pumpAndSettle();
      final settled = tester.getSize(
        find.byKey(FrostedSegmentedControl.pillKey),
      );
      expect(settled.width, closeTo(rest.width, 0.5));
    });
  });

  group('CapsuleTabStrip', () {
    testWidgets('renders every label and reports taps', (tester) async {
      var value = 'latest';
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _host(
            CapsuleTabStrip<String>(
              tabs: const [
                CapsuleTabItem(value: 'latest', label: '最新'),
                CapsuleTabItem(value: 'good', label: '精品'),
                CapsuleTabItem(value: 'tab-3', label: '吧友互助'),
                CapsuleTabItem(value: 'tab-4', label: '交流专区'),
              ],
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['最新', '精品', '吧友互助', '交流专区']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('精品'));
      await tester.pumpAndSettle();
      expect(value, 'good');
    });

    testWidgets('the pill follows the tapped tab', (tester) async {
      var value = 'latest';
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _host(
            CapsuleTabStrip<String>(
              tabs: const [
                CapsuleTabItem(value: 'latest', label: '最新'),
                CapsuleTabItem(value: 'good', label: '精品'),
                CapsuleTabItem(value: 'tab-3', label: '吧友互助'),
              ],
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(find.byKey(CapsuleTabStrip.pillKey));
      await tester.tap(find.text('吧友互助'));
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(find.byKey(CapsuleTabStrip.pillKey));
      expect(after.dx, greaterThan(before.dx + 1));
    });

    testWidgets('tapping the selected tab opens its sort menu', (tester) async {
      var menuOpened = 0;
      var value = 'latest';
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _host(
            CapsuleTabStrip<String>(
              tabs: [
                CapsuleTabItem(
                  value: 'latest',
                  label: '最新',
                  onMenuTap: () async => menuOpened++,
                ),
                const CapsuleTabItem(value: 'good', label: '精品'),
              ],
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('最新'));
      await tester.pumpAndSettle();
      expect(menuOpened, 1);
      expect(value, 'latest');
    });

    testWidgets('a horizontal drag over a fitting strip switches tabs', (
      tester,
    ) async {
      var value = 'latest';
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _host(
            CapsuleTabStrip<String>(
              tabs: const [
                CapsuleTabItem(value: 'latest', label: '最新'),
                CapsuleTabItem(value: 'good', label: '精品'),
              ],
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.text('最新'), const Offset(90, 0));
      await tester.pumpAndSettle();
      expect(value, 'good');
    });
  });
}
