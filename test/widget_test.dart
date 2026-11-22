import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forward_growers/balance.dart';
import 'package:forward_growers/game.dart';
import 'package:forward_growers/main.dart';
import 'package:forward_growers/progress.dart';
import 'package:forward_growers/screens.dart';

import 'game_test.dart' show MemoryStore;

void main() {
  const balance = GameBalance(spawnChance: 0);
  for (final size in [const Size(568, 320), const Size(844, 390)]) {
    testWidgets('map, wheat playthrough, results and relaunch at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemoryStore();
      Future<({Farm farm, String? notice})> load() async => (
        farm: Farm(
          progress: await store.load(balance) ?? FarmProgress.fresh(balance),
          store: store,
          balance: balance,
          clock: clock.stopwatch(),
        ),
        notice: null,
      );
      await tester.pumpWidget(ForwardGrowers(loadFarm: load));
      await tester.pumpAndSettle();
      expect(find.text('Farm Map · Expansion 1'), findsOneWidget);
      expect(find.text('County Fair'), findsOneWidget);
      expect(find.text('Field plots: 4 / 8'), findsOneWidget);
      expect(find.text('Relaxed Mode'), findsWidgets);
      await tester.tap(find.text('Play'));
      await tester.pump();
      final plots = find.byType(PlotTile);
      expect(plots, findsNWidgets(4));
      expect(find.text('TIME'), findsNothing);

      Future<void> apply(String action) async {
        await tester.tap(find.text(action).last);
        await tester.pump();
        for (var i = 0; i < balance.level(1, 1).objective; i++) {
          await tester.tap(plots.at(i));
          await tester.pump();
        }
      }

      await apply('Plow');
      await apply('Wheat');
      await apply('Water');
      await tester.pump(balance.level(1, 1).production!.growth);
      expect(find.text('Ready to harvest'), findsNWidgets(3));
      await apply('Harvest');
      expect(find.text('Objective completed'), findsOneWidget);
      expect(find.text('First completion'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Level 2'), findsOneWidget);
      expect(find.text(r'Wallet $6'), findsOneWidget);
      await tester.tap(find.text('Wheat').first);
      await tester.pump();
      expect(find.text('Replay'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(ForwardGrowers(loadFarm: load));
      await tester.pumpAndSettle();
      expect(find.text('Level 2'), findsOneWidget);
      expect(find.text(r'Wallet $6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact landscape orchard has all tools and separate capacity', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(568, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryStore();
    await tester.pumpWidget(
      ForwardGrowers(
        loadFarm: () async => (
          farm: Farm(
            progress: FarmProgress.fresh(balance)
                .copyWith(completed: {1, 2, 3}, mode: Mode.timed),
            store: store,
            balance: balance,
            clock: clock.stopwatch(),
          ),
          notice: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Apple trees: 2 / 4'), findsOneWidget);
    expect(find.text('Pick 4 harvests'), findsOneWidget);
    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(find.text('2:00'), findsOneWidget);
    expect(find.byType(PlotTile), findsNWidgets(2));
    for (final tool in [
      'Prune',
      'Fertilize',
      'Water',
      'Pick',
      'Orchard Whistle',
    ]) {
      expect(find.text(tool).hitTestable(), findsWidgets);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'debug expansion and full-field preview isolate the original farm',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(844, 390));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemoryStore();
      await tester.pumpWidget(
        ForwardGrowers(
          loadFarm: () async => (
            farm: Farm(
              progress: FarmProgress.fresh(balance),
              store: store,
              balance: balance,
            ),
            notice: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Preview Expansion 2'));
      await tester.tap(find.text('Preview Expansion 2'));
      await tester.pumpAndSettle();
      expect(find.text('Farm Map · Expansion 2'), findsOneWidget);
      await tester.tap(find.text('Wheat').first);
      await tester.pump();
      expect(find.text('Level 11'), findsOneWidget);
      expect(find.text('Field plots: 4 / 12'), findsOneWidget);
      await tester.ensureVisible(find.text('Exit Debug Expansion'));
      await tester.tap(find.text('Exit Debug Expansion'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Preview 16 × 16 Field'));
      await tester.tap(find.text('Preview 16 × 16 Field'));
      await tester.pumpAndSettle();

      final tiles = find.byType(PlotTile);
      expect(tiles, findsNWidgets(256));
      final point = tester.getCenter(tiles.at(119));
      final first = await tester.startGesture(point - const Offset(20, 0));
      final second = await tester.startGesture(point + const Offset(20, 0));
      await first.moveBy(const Offset(-55, 0));
      await second.moveBy(const Offset(55, 0));
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(find.text('Full Field'), findsOneWidget);
      expect(tester.widget<PlotTile>(tiles.at(119)).plot.stage, Stage.bare);
      await tester.tap(tiles.at(119));
      await tester.pump();
      expect(tester.widget<PlotTile>(tiles.at(119)).plot.stage, Stage.prepared);
      await tester.tap(find.text('Exit Preview'));
      await tester.pumpAndSettle();
      expect(find.text('Farm Map · Expansion 1'), findsOneWidget);
      expect(find.text('Field plots: 4 / 8'), findsOneWidget);
      expect(store.saved, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'mode selection persists and timed expiration returns to the map',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(568, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemoryStore();
      await tester.pumpWidget(
        ForwardGrowers(
          loadFarm: () async => (
            farm: Farm(
              progress: FarmProgress.fresh(balance),
              store: store,
              balance: balance,
              clock: clock.stopwatch(),
            ),
            notice: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<Mode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timed Challenge').last);
      await tester.pumpAndSettle();
      expect(store.saved?.mode, Mode.timed);
      await tester.tap(find.text('Play'));
      await tester.pump();
      await tester.pump(balance.timedDuration);
      expect(find.text('Time expired'), findsOneWidget);
      expect(find.text('No completion bonus'), findsOneWidget);
      expect(find.text('Level remains incomplete'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Farm Map · Expansion 1'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
