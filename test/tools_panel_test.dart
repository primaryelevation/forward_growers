import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forward_growers/balance.dart';
import 'package:forward_growers/game.dart';
import 'package:forward_growers/progress.dart';
import 'package:forward_growers/screens.dart';

import 'game_test.dart' show MemoryStore;

Future<Farm> openActivity(
  WidgetTester tester,
  Activity activity,
  Size size, {
  Mode mode = Mode.relaxed,
  int expansion = 1,
  int tables = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  const balance = GameBalance(spawnChance: 1);
  final farm = Farm(
    progress: FarmProgress.fresh(balance)
        .copyWith(
          mode: mode,
          expansion: expansion,
          completed: {
            for (
              var i = 1;
              i < balance.firstLevel(expansion) + activity.index;
              i++
            )
              i,
          },
        )
        .withPurchase(Capacity.tables, tables, BigInt.zero),
    store: MemoryStore(),
    balance: balance,
  )..start(activity);
  addTearDown(farm.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: ListenableBuilder(
            listenable: farm,
            builder: (_, _) => GameplayScreen(farm: farm),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return farm;
}

void main() {
  for (final (activity, planting, seed, hazard, emergency) in const [
    (Activity.wheat, 'Plant Wheat', 'plant_wheat', 'Hammer', 'hammer'),
    (Activity.corn, 'Plant Corn', 'plant_corn', 'Noisemaker', 'noisemaker'),
    (
      Activity.carrots,
      'Plant Carrots',
      'plant_carrots',
      'Dog Whistle',
      'dog_whistle',
    ),
  ]) {
    testWidgets(
      '${activity.label} illustrates and applies its five standard tools',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final farm = await openActivity(tester, activity, const Size(568, 320));
        final plot = find.byType(PlotTile).first;
        final panel = find.byType(ToolsPanel);
        final buttons = find.descendant(
          of: panel,
          matching: find.byType(ActionTile),
        );
        expect(
          tester.widgetList<ActionTile>(buttons).map((tile) => tile.action),
          [
            Tool.plow,
            Tool.plant,
            Tool.water,
            Tool.harvest,
            farm.level.hazard.tool,
          ],
        );
        for (final other in ['Plant Wheat', 'Plant Corn', 'Plant Carrots']) {
          expect(
            find.byTooltip(other),
            other == planting ? findsOneWidget : findsNothing,
          );
        }
        expect(find.text('None'), findsOneWidget);
        expect(
          tester.getCenter(find.text('Standard')).dx,
          lessThan(tester.getCenter(find.text('Special')).dx),
        );
        expect(
          tester.getRect(find.byType(PlotGrid)).right,
          lessThanOrEqualTo(tester.getRect(panel).left),
        );
        expect(tester.getSize(find.byType(PlotGrid)).width, greaterThan(350));

        Future<void> use(String label, String file, Tool tool) async {
          final button = find.byTooltip(label);
          final image = tester.widget<Image>(
            find.descendant(of: button, matching: find.byType(Image)),
          );
          expect(
            (image.image as AssetImage).assetName,
            'assets/tools/$file.png',
          );
          expect(
            find.descendant(of: button, matching: find.text(label)),
            findsNothing,
          );
          expect(find.bySemanticsLabel(label), findsOneWidget);
          final size = tester.getSize(button);
          expect(size.width, size.height);
          expect(size.width, greaterThanOrEqualTo(40));
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pump();
          expect(farm.selection, tool);
          final material = tester.widget<Material>(
            find.descendant(of: button, matching: find.byType(Material)),
          );
          expect((material.shape! as RoundedRectangleBorder).side.width, 3);
          await tester.tap(plot);
          await tester.pump();
        }

        await use('Plow', 'plow', Tool.plow);
        expect(farm.plots.first.stage, Stage.prepared);
        await use(planting, seed, Tool.plant);
        expect(farm.plots.first.stage, Stage.tended);
        farm.tick(farm.balance.safePeriod);
        await tester.pump();
        expect(farm.hazard?.index, 0);
        await use(hazard, emergency, farm.level.hazard.tool);
        expect(farm.hazard, isNull);
        expect(farm.plots.first.stage, Stage.tended);
        await use('Water', 'water', Tool.water);
        expect(farm.plots.first.stage, Stage.growing);
        farm.tick(farm.balance.safePeriod + farm.level.production!.growth);
        await tester.pump();
        expect(farm.plots.first.stage, Stage.ready);
        await use('Harvest', 'harvest', Tool.harvest);
        expect(farm.harvested, 1);
        expect(farm.cash, farm.level.unitValue);
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'narrow Fair shows illustrated order controls and keeps Tarp visible while scrolling',
    (tester) async {
      final farm = await openActivity(
        tester,
        Activity.fair,
        const Size(500, 280),
      );
      final tile = find.byType(OrderTile);
      final tarp = find.byTooltip('Tarp');
      final takeOrder = find.byTooltip('Take Order');
      final collect = find.byTooltip('Collect Money');
      expect(
        find.descendant(of: takeOrder, matching: find.byType(Image)),
        findsOneWidget,
      );
      expect(tarp.hitTestable(), findsOneWidget);
      final pinned = tester.getRect(tarp);
      await tester.tap(takeOrder);
      await tester.tap(tile);
      await tester.pump();
      expect(farm.orderAt(0), isNotNull);
      await tester.ensureVisible(collect);
      await tester.pump();
      expect(collect.hitTestable(), findsOneWidget);
      expect(tester.getRect(tarp), pinned);
      expect(tarp.hitTestable(), findsOneWidget);
      expect(tester.getSize(tile).width, greaterThan(175));
      expect(tester.takeException(), isNull);
    },
  );
}
