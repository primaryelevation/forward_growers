import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forward_growers/balance.dart';
import 'package:forward_growers/game.dart';
import 'package:forward_growers/screens.dart';

import 'tools_panel_test.dart' show openActivity;

Finder badgeIn(Finder tile) =>
    find.descendant(of: tile, matching: find.byType(ActionBadge));

Future<void> act(WidgetTester tester, Farm farm, Tool tool, Finder tile) async {
  final label = tool == Tool.plant
      ? 'Plant ${farm.level.activity.label}'
      : tool.label;
  final button = find.byTooltip(label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.tap(tile);
  await tester.pump();
}

Future<void> gather(WidgetTester tester, Goods product, Finder tile) async {
  final button = find.byTooltip(product.label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.tap(tile);
  await tester.pump();
}

void expectCue(WidgetTester tester, Finder tile, Tool tool, String file) {
  final badge = badgeIn(tile);
  expect(badge, findsOneWidget);
  expect(tester.widget<ActionBadge>(badge).action, tool);
  final art = tester.widget<Image>(
    find.descendant(of: badge, matching: find.byType(Image)),
  );
  expect((art.image as AssetImage).assetName, 'assets/tools/$file.png');
  expect(
    tester.getRect(tile).contains(tester.getRect(badge).bottomRight),
    true,
  );
}

void main() {
  testWidgets(
    'corn cues share artwork, highlight eligibility and never select tools',
    (tester) async {
      final farm = await openActivity(
        tester,
        Activity.corn,
        const Size(500, 280),
      );
      final first = find.byType(PlotTile).first;
      final second = find.byType(PlotTile).at(1);
      expectCue(tester, first, Tool.plow, 'plow');
      expect(tester.widget<PlotTile>(first).highlighted, true);
      await act(tester, farm, Tool.plow, first);
      expectCue(tester, first, Tool.plant, 'plant_corn');
      final rail = tester.widget<Image>(
        find.descendant(
          of: find.byTooltip('Plant Corn'),
          matching: find.byType(Image),
        ),
      );
      expect(
        (rail.image as AssetImage).assetName,
        'assets/tools/plant_corn.png',
      );
      expect(
        find.bySemanticsLabel(RegExp('Plot 1.*Next action: Plant Corn')),
        findsOneWidget,
      );
      expect(tester.widget<PlotTile>(first).highlighted, false);
      expect(tester.widget<PlotTile>(second).highlighted, true);
      await tester.tapAt(tester.getCenter(badgeIn(first)));
      await tester.pump();
      expect(farm.selection, Tool.plow);
      expect(farm.plots.first.stage, Stage.prepared);
      await act(tester, farm, Tool.plant, first);
      expectCue(tester, first, Tool.water, 'water');
      await act(tester, farm, Tool.water, first);
      expect(badgeIn(first), findsNothing);
      final progress = find.descendant(
        of: first,
        matching: find.byType(LinearProgressIndicator),
      );
      expect(tester.widget<LinearProgressIndicator>(progress).value, 0);
      final growth = farm.level.production!.growth;
      farm.tick(growth ~/ 2);
      await tester.pump();
      expect(tester.widget<LinearProgressIndicator>(progress).value, .5);
      farm.tick(growth);
      await tester.pump();
      expectCue(tester, first, Tool.harvest, 'harvest');
      await act(tester, farm, Tool.harvest, first);
      expectCue(tester, first, Tool.plow, 'plow');
      expect(farm.harvested, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (activity, images) in [
    (Activity.apples, ['prune', 'fertilize', 'water', 'pick']),
    (Activity.dairy, ['feed', 'water', 'brush', 'milk']),
    (Activity.bees, ['plant_flowers', 'water', 'smoke_hive', 'collect_honey']),
  ]) {
    testWidgets('${activity.label} spaces show their own cycle and readiness', (
      tester,
    ) async {
      final farm = await openActivity(tester, activity, const Size(568, 320));
      final first = find.byType(PlotTile).first;
      final second = find.byType(PlotTile).at(1);
      final tools = [
        farm.level.prepare,
        farm.level.tend,
        farm.level.beginProduction,
        farm.level.collect,
      ];
      for (var i = 0; i < 3; i++) {
        expectCue(tester, first, tools[i], images[i]);
        await act(tester, farm, tools[i], first);
      }
      expect(badgeIn(first), findsNothing);
      farm.tick(farm.level.production!.growth);
      await tester.pump();
      expectCue(tester, first, tools.last, images.last);
      expectCue(tester, second, tools.first, images.first);
      await tester.tap(find.byTooltip(tools.last.label));
      await tester.pump();
      expect(tester.widget<PlotTile>(first).highlighted, true);
      expect(tester.widget<PlotTile>(second).highlighted, false);
      await tester.tap(first);
      await tester.pump();
      expectCue(tester, first, tools.first, images.first);
    });
  }

  testWidgets(
    'two tables highlight only the orders needing the selected product',
    (tester) async {
      final farm = await openActivity(
        tester,
        Activity.market,
        const Size(500, 280),
        tables: 2,
      );
      final first = find.byType(OrderTile).first;
      final second = find.byType(OrderTile).at(1);
      expect(farm.canSelectProduct(Goods.eggs), false);
      await act(tester, farm, Tool.takeOrder, first);
      await act(tester, farm, Tool.takeOrder, second);
      await tester.tap(find.byTooltip('Milk'));
      await tester.pump();
      expect(tester.widget<OrderTile>(first).highlighted, false);
      expect(tester.widget<OrderTile>(second).highlighted, true);
      await tester.tap(first);
      await tester.pump();
      expect(farm.orderAt(0)!.gathered, 0);
      expect(farm.orderAt(1)!.gathered, 0);
      await tester.tap(second);
      await tester.pump();
      expect(farm.orderAt(1)!.gatheredProducts, [Goods.milk]);
      expect(farm.canSelectProduct(Goods.milk), false);
      await gather(tester, Goods.eggs, first);
      expect(farm.orderAt(0)!.gatheredProducts, [Goods.eggs]);
      expect(find.text('✓ Eggs'), findsOneWidget);
      expect(find.text('✓ Milk'), findsOneWidget);
    },
  );

  testWidgets('hazard response replaces and restores the usable field cue', (
    tester,
  ) async {
    final farm = await openActivity(
      tester,
      Activity.wheat,
      const Size(568, 320),
    );
    final tile = find.byType(PlotTile).first;
    await act(tester, farm, Tool.plow, tile);
    expectCue(tester, tile, Tool.plant, 'plant_wheat');
    await act(tester, farm, Tool.plant, tile);
    farm.tick(farm.balance.safePeriod);
    await tester.pump();
    expectCue(tester, tile, Tool.hammer, 'hammer');
    await act(tester, farm, Tool.hammer, tile);
    expectCue(tester, tile, Tool.water, 'water');
  });

  for (final (activity, hazard, toolFile, setback, setbackFile) in [
    (Activity.market, Tool.broom, 'broom', Tool.gather, 'gather'),
    (Activity.fair, Tool.tarp, 'tarp', Tool.weigh, 'weigh'),
  ]) {
    testWidgets(
      '${activity.label} keeps quantities and refreshes badges after timed setbacks',
      (tester) async {
        final farm = await openActivity(
          tester,
          activity,
          const Size(500, 280),
          mode: Mode.timed,
          expansion: activity == Activity.fair ? 2 : 1,
        );
        if (activity == Activity.fair) expect(farm.level.number, 20);
        final tile = find.byType(OrderTile).first;
        expectCue(tester, tile, Tool.takeOrder, 'take_order');
        await act(tester, farm, Tool.takeOrder, tile);
        final goods = farm.orderAt(0)!.products;
        expect(badgeIn(tile), findsNothing);
        expect(find.byTooltip('Gather Products'), findsNothing);
        for (final product in goods.reversed) {
          await gather(tester, product, tile);
        }
        if (activity == Activity.fair) {
          expectCue(tester, tile, Tool.weigh, 'weigh');
          await act(tester, farm, Tool.weigh, tile);
        }
        expectCue(tester, tile, Tool.pack, 'pack');
        await act(tester, farm, Tool.pack, tile);
        expectCue(tester, tile, Tool.deliver, 'deliver');
        farm.tick(farm.balance.safePeriod);
        await tester.pump();
        expectCue(tester, tile, hazard, toolFile);
        expect(
          find.text('Gathered ${goods.length} / ${goods.length}'),
          findsOneWidget,
        );
        farm.tick(farm.balance.safePeriod + farm.balance.responseWindow);
        await tester.pump();
        if (activity == Activity.market) {
          expect(badgeIn(tile), findsNothing);
          expect(find.text('○ ${goods.first.label}'), findsOneWidget);
          expect(farm.canSelectProduct(goods.first), true);
          expect(farm.canSelectProduct(goods.last), false);
          expect(
            find.text('Gathered ${goods.length - 1} / ${goods.length}'),
            findsOneWidget,
          );
          await gather(tester, goods.first, tile);
        } else {
          expectCue(tester, tile, setback, setbackFile);
          expect(
            find.text('Gathered ${goods.length} / ${goods.length}'),
            findsOneWidget,
          );
          await act(tester, farm, setback, tile);
        }
        await act(tester, farm, Tool.pack, tile);
        await act(tester, farm, Tool.deliver, tile);
        expectCue(tester, tile, Tool.collectMoney, 'collect_money');
        final payment = find.byTooltip('Collect Money');
        expect(payment.hitTestable(), findsOneWidget);
        final artwork = tester.widget<Image>(
          find.descendant(of: payment, matching: find.byType(Image)),
        );
        expect(
          (artwork.image as AssetImage).assetName,
          'assets/tools/collect_money.png',
        );
        expect(
          tester
              .getRect(find.byType(ToolsPanel))
              .contains(tester.getRect(payment).bottomRight),
          true,
        );
        await tester.tap(payment);
        await tester.pump();
        await tester.tap(tile);
        await tester.pump();
        expect(farm.harvested, 1);
        expectCue(tester, tile, Tool.takeOrder, 'take_order');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
