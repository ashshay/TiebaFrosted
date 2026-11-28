import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_frosted/core/html_text.dart';
import 'package:tieba_frosted/data/media_saver.dart';
import 'package:tieba_frosted/data/settings.dart';
import 'package:tieba_frosted/ui/pages/image_viewer_page.dart';
import 'package:tieba_frosted/ui/theme.dart';
import 'package:tieba_frosted/ui/widgets/remote_image.dart';

const _images = [
  RichImageNode(
    url: '',
    originUrl: 'https://example.com/origin.jpg',
    width: 300,
    height: 200,
  ),
  RichImageNode(url: '', originUrl: '', width: 300, height: 200),
];

/// 把看图页压在一个两层 Navigator 上，这样下拉关闭能真的 pop 掉这页。
Future<void> _pumpViewer(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final settings = FrostedSettings(await SharedPreferences.getInstance());
  final base = frostedTheme(
    brightness: Brightness.light,
    accentArgb: defaultAccent.toARGB32(),
  );
  await tester.binding.setSurfaceSize(const Size(400, 800));
  await tester.pumpWidget(
    ChangeNotifierProvider<FrostedSettings>.value(
      value: settings,
      child: Provider<MediaSaver>.value(
        value: MediaSaver(Dio()),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: Theme(
              data: base,
              child: Navigator(
                onGenerateRoute: (_) => PageRouteBuilder<dynamic>(
                  pageBuilder: (_, _, _) => const SizedBox.expand(),
                ),
                onGenerateInitialRoutes: (_, _) => <Route<dynamic>>[
                  PageRouteBuilder<dynamic>(
                    pageBuilder: (_, _, _) => const SizedBox.expand(),
                  ),
                  PageRouteBuilder<dynamic>(
                    pageBuilder: (_, _, _) =>
                        const ImageViewerPage(images: _images),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

InteractiveViewer _viewer(WidgetTester tester) =>
    tester.widget<InteractiveViewer>(find.byType(InteractiveViewer).last);

PageController _pager(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView).last).controller!;

Future<void> _doubleTap(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(const Duration(milliseconds: 80));
  await tester.tapAt(at);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('双指放大实时显示倍率并锁住翻页', (tester) async {
    await _pumpViewer(tester);
    final viewer = find.byType(InteractiveViewer).last;
    final controller = _viewer(tester).transformationController!;
    final center = tester.getCenter(viewer);

    final first = await tester.startGesture(center - const Offset(40, 0));
    final second = await tester.startGesture(center + const Offset(40, 0));
    await tester.pump();
    await first.moveBy(const Offset(-60, -30));
    await second.moveBy(const Offset(60, 30));
    await tester.pump();

    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.2));
    final badge = tester.widgetList<Text>(find.textContaining('×')).first;
    expect(badge.data, isNot('1.0×'));
    expect(_pager(tester).page, 0);

    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.2));
  });

  testWidgets('双击放大到 2.4x 并自动换原图，再双击复原', (tester) async {
    await _pumpViewer(tester);
    final controller = _viewer(tester).transformationController!;
    final center = tester.getCenter(find.byType(InteractiveViewer).last);

    await _doubleTap(tester, center);
    expect(
      controller.value.getMaxScaleOnAxis(),
      closeTo(2.4, 0.01),
    );
    expect(
      tester
          .widgetList<RemoteImage>(find.byType(RemoteImage))
          .map((img) => img.url),
      contains('https://example.com/origin.jpg'),
    );

    await _doubleTap(tester, center);
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1.0, 0.001));
  });

  testWidgets('竖向捏合也能放大，不会被下拉关闭抢走', (tester) async {
    await _pumpViewer(tester);
    final viewer = find.byType(InteractiveViewer).last;
    final controller = _viewer(tester).transformationController!;
    final center = tester.getCenter(viewer);

    final top = await tester.startGesture(center - const Offset(0, 60));
    final bottom = await tester.startGesture(center + const Offset(0, 60));
    await tester.pump();
    await top.moveBy(const Offset(0, -70));
    await bottom.moveBy(const Offset(0, 70));
    await tester.pump();

    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.2));
    expect(find.byType(ImageViewerPage), findsOneWidget);
    await top.up();
    await bottom.up();
    await tester.pumpAndSettle();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.2));
  });

  testWidgets('第一根手指先移动、第二根后落下也能捏合', (tester) async {
    await _pumpViewer(tester);
    final viewer = find.byType(InteractiveViewer).last;
    final controller = _viewer(tester).transformationController!;
    final center = tester.getCenter(viewer);

    final first = await tester.startGesture(center - const Offset(50, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await first.moveBy(const Offset(0, -30));
    await tester.pump(const Duration(milliseconds: 16));
    final second = await tester.startGesture(center + const Offset(50, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await first.moveBy(const Offset(-50, -30));
    await second.moveBy(const Offset(50, 30));
    await tester.pump();

    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.1));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
  });

  testWidgets('第一根手指先横向移动、第二根后落下也能捏合', (tester) async {
    await _pumpViewer(tester);
    final viewer = find.byType(InteractiveViewer).last;
    final controller = _viewer(tester).transformationController!;
    final center = tester.getCenter(viewer);

    final first = await tester.startGesture(center - const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await first.moveBy(const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final second = await tester.startGesture(center + const Offset(50, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await first.moveBy(const Offset(-50, 0));
    await second.moveBy(const Offset(50, 0));
    await tester.pump();

    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.2));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(_pager(tester).page, closeTo(0, 0.001));
  });

  testWidgets('未放大时横滑翻页、上下拖关闭看图页', (tester) async {
    await _pumpViewer(tester);

    await tester.drag(
      find.byType(InteractiveViewer).last,
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(_pager(tester).page, 1);

    await tester.drag(
      find.byType(InteractiveViewer).last,
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerPage), findsNothing);
  });
}
