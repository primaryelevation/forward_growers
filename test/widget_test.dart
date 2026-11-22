import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forward_growers/game.dart';
import 'package:forward_growers/main.dart';
import 'package:forward_growers/screens.dart';

void main() {
  for (final size in [const Size(568, 320), const Size(844, 390)]) {
    testWidgets(
      'plays Level 1 and opens Level 2 at ${size.width} × ${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(ForwardGrowers(roundClock: clock.stopwatch()));
        await tester.tap(find.text('Start Level 1'));
        await tester.pump();

        Future<void> use(String label) async {
          await tester.tap(find.text(label));
          await tester.pump();
          for (var i = 0; i < 3; i++) {
            await tester.tap(find.byType(PlotTile).at(i));
            await tester.pump();
          }
        }

        expect(find.byType(PlotTile), findsNWidgets(4));
        await use('Plow');
        await use('Wheat');
        await use('Water');
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('Wheat ready'), findsNWidgets(3));
        await use('Harvest');
        expect(find.byType(ResultsScreen), findsOneWidget);
        expect(find.text('Harvested 3 / 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final buyCorn = size.width > 600;
        if (buyCorn) {
          await tester.tap(find.text(r'Buy · $12'));
          await tester.pump();
        }
        final play = find.text('Play Level 2');
        await tester.ensureVisible(play);
        await tester.tap(play);
        await tester.pump();
        expect(find.text('Harvest 0 / 5'), findsOneWidget);
        expect(find.text(buyCorn ? r'$0' : r'$12'), findsOneWidget);
        expect(find.text('Corn'), buyCorn ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final size in [const Size(568, 320), const Size(844, 390)]) {
    testWidgets('preview fits 256 plots and isolates the farm at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ForwardGrowers(roundClock: clock.stopwatch()));
      await tester.tap(find.text('Start Level 1'));
      await tester.pump();
      await tester.tap(find.byType(PlotTile).first);
      await tester.pump();
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await tester.tap(find.text('Preview 16 × 16 Field'));
      await tester.pumpAndSettle();

      final tiles = find.byType(PlotTile);
      expect(tiles, findsNWidgets(256));
      final viewer = find.byType(InteractiveViewer);
      final field = tester.getRect(viewer);
      for (var i = 0; i < 256; i++) {
        final tile = tester.getRect(tiles.at(i));
        expect(field.inflate(.01).contains(tile.topLeft), isTrue);
        expect(field.inflate(.01).contains(tile.bottomRight), isTrue);
        expect(tile.left, closeTo(tester.getTopLeft(tiles.at(i % 16)).dx, .01));
        expect(
          tile.top,
          closeTo(tester.getTopLeft(tiles.at(i ~/ 16 * 16)).dy, .01),
        );
      }
      List<Stage> stages() => tester
          .widgetList<PlotTile>(tiles)
          .map((tile) => tile.plot.stage)
          .toList();

      final before = stages();
      final nearCenter = tester.getCenter(tiles.at(119));
      final first = await tester.startGesture(nearCenter - const Offset(20, 0));
      final second = await tester.startGesture(
        nearCenter + const Offset(20, 0),
      );
      await first.moveBy(const Offset(-65, 0));
      await second.moveBy(const Offset(65, 0));
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(find.text('Full Field'), findsOneWidget);
      expect(stages(), before);
      final centerAfterZoom = tester.getCenter(tiles.at(119));
      await tester.dragFrom(centerAfterZoom, const Offset(40, 28));
      await tester.pumpAndSettle();
      expect(stages(), before);
      expect(tester.getCenter(tiles.at(119)), isNot(centerAfterZoom));

      final visible = tiles.at(119);
      await tester.tap(visible);
      await tester.pump();
      final expected = before.toList()..[119] = Stage.plowed;
      expect(stages(), expected);
      await tester.tap(find.text('Full Field'));
      await tester.pump();
      expect(tester.getRect(viewer), field);
      expect(find.text('Full Field'), findsNothing);
      await tester.tap(find.text('Exit Preview'));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);
      expect(find.byType(PlotTile), findsNWidgets(4));
      expect(tester.widget<PlotTile>(tiles.first).plot.stage, Stage.plowed);
      expect(find.text('\$0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
