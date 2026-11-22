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
        await tester.pumpWidget(const ForwardGrowers());
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
        final play = find.text('Play Level 2');
        await tester.ensureVisible(play);
        await tester.tap(play);
        await tester.pump();
        expect(find.text('Harvest 0 / 5'), findsOneWidget);
        expect(find.text('\$12'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('six plots fit inside a compact landscape safe area', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(568, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final farm = Farm(moleInterval: 121)..resume();
    addTearDown(farm.dispose);
    void harvest() {
      for (final action in [Tool.plow, Crop.wheat, Tool.water]) {
        farm.select(action);
        farm.tap(0);
      }
      for (var i = 0; i < Crop.wheat.seconds; i++) {
        farm.tick();
      }
      farm.select(Tool.harvest);
      farm.tap(0);
    }

    for (var i = 0; i < 5; i++) {
      harvest();
      harvest();
      while (farm.phase == Phase.playing) {
        farm.tick();
      }
      farm.restart();
    }
    harvest();
    harvest();
    harvest();
    farm.buyPlot();
    farm.buyPlot();
    farm.buyCrop(Crop.corn);
    farm.restart();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.fromLTRB(28, 0, 28, 18),
            ),
            child: SafeArea(child: GameplayScreen(farm: farm)),
          ),
        ),
      ),
    );
    expect(find.byType(PlotTile), findsNWidgets(6));
    expect(find.text('Corn'), findsOneWidget);
    for (final plot in find.byType(PlotTile).evaluate()) {
      final bounds = tester.getRect(find.byWidget(plot.widget));
      expect(bounds.left, greaterThanOrEqualTo(28));
      expect(bounds.bottom, lessThanOrEqualTo(302));
    }
    expect(tester.takeException(), isNull);
  });
}
