import 'package:flutter/material.dart' as material;
import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter_test/flutter_test.dart';
import 'package:tieba_frosted/ui/widgets/common.dart';

material.Widget _host({
  required bool enabled,
  required ValueChanged<bool> onHiddenChanged,
}) => material.MaterialApp(
  home: ChromeScrollListener(
    enabled: enabled,
    onHiddenChanged: onHiddenChanged,
    child: material.ListView.builder(
      itemCount: 60,
      itemBuilder: (_, i) => material.SizedBox(
        height: 100,
        child: material.Text('第 $i 行'),
      ),
    ),
  ),
);

Future<void> _scrollUp(WidgetTester tester) async {
  await tester.drag(find.byType(material.ListView), const Offset(0, -900));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('开关打开时向下滚动会收起顶栏与底栏', (tester) async {
    final reports = <bool>[];
    await tester.pumpWidget(
      _host(enabled: true, onHiddenChanged: reports.add),
    );
    await tester.pumpAndSettle();

    await _scrollUp(tester);

    expect(reports, contains(true));
  });

  testWidgets('开关关闭后滚动不再收起', (tester) async {
    final reports = <bool>[];
    await tester.pumpWidget(
      _host(enabled: false, onHiddenChanged: reports.add),
    );
    await tester.pumpAndSettle();

    await _scrollUp(tester);

    expect(reports.contains(true), isFalse);
  });

  testWidgets('滚动中把开关关掉会立刻把栏放回来', (tester) async {
    final reports = <bool>[];
    await tester.pumpWidget(
      _host(enabled: true, onHiddenChanged: reports.add),
    );
    await tester.pumpAndSettle();
    await _scrollUp(tester);
    expect(reports, contains(true));

    reports.clear();
    await tester.pumpWidget(
      _host(enabled: false, onHiddenChanged: reports.add),
    );
    await tester.pumpAndSettle();

    expect(reports, contains(false));
    expect(reports.contains(true), isFalse);
  });

  testWidgets('回到顶部时栏重新出现', (tester) async {
    final reports = <bool>[];
    await tester.pumpWidget(
      _host(enabled: true, onHiddenChanged: reports.add),
    );
    await tester.pumpAndSettle();
    await _scrollUp(tester);
    expect(reports.last, isTrue);

    await tester.drag(find.byType(material.ListView), const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(reports.last, isFalse);
  });
}
