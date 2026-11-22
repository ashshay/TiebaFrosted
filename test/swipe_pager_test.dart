import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tieba_frosted/ui/widgets/swipe_pager.dart';

void main() {
  group('SwipePager', () {
    Future<List<int>> pumpPager(
      WidgetTester tester, {
      int index = 1,
      int count = 3,
      bool enabled = true,
    }) async {
      final changes = <int>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SwipePager(
            index: index,
            count: count,
            enabled: enabled,
            onIndexChanged: changes.add,
            child: const SizedBox.expand(),
          ),
        ),
      );
      return changes;
    }

    testWidgets('a long left drag moves to the next page', (tester) async {
      final changes = await pumpPager(tester);
      await tester.drag(find.byType(SwipePager), const Offset(-260, 0));
      await tester.pump();
      expect(changes, [2]);
    });

    testWidgets('a long right drag moves to the previous page', (tester) async {
      final changes = await pumpPager(tester);
      await tester.drag(find.byType(SwipePager), const Offset(260, 0));
      await tester.pump();
      expect(changes, [0]);
    });

    testWidgets('a short slow drag stays put', (tester) async {
      final changes = await pumpPager(tester);
      await tester.drag(
        find.byType(SwipePager),
        const Offset(-24, 0),
        touchSlopX: 0,
      );
      await tester.pump();
      expect(changes, isEmpty);
    });

    testWidgets('a vertical drag never switches pages', (tester) async {
      final changes = await pumpPager(tester);
      await tester.drag(find.byType(SwipePager), const Offset(0, -400));
      await tester.pump();
      expect(changes, isEmpty);
    });

    testWidgets('the first page cannot swipe back past the start', (
      tester,
    ) async {
      final changes = await pumpPager(tester, index: 0);
      await tester.drag(find.byType(SwipePager), const Offset(260, 0));
      await tester.pump();
      expect(changes, isEmpty);
    });

    testWidgets('the last page cannot swipe on past the end', (tester) async {
      final changes = await pumpPager(tester, index: 2);
      await tester.drag(find.byType(SwipePager), const Offset(-260, 0));
      await tester.pump();
      expect(changes, isEmpty);
    });

    testWidgets('disabled leaves the drag alone', (tester) async {
      final changes = await pumpPager(tester, enabled: false);
      await tester.drag(
        find.byType(SwipePager),
        const Offset(-260, 0),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(changes, isEmpty);
    });
  });
}
