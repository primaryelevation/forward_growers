import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forward_growers/game.dart';

void advance(Farm farm, int seconds) {
  for (var i = 0; i < seconds; i++) {
    farm.tick();
  }
}

void act(Farm farm, Object action, [int index = 0]) {
  farm.select(action);
  farm.tap(index);
}

void harvest(Farm farm, {Crop crop = Crop.wheat}) {
  act(farm, Tool.plow);
  act(farm, crop);
  act(farm, Tool.water);
  advance(farm, crop.seconds);
  act(farm, Tool.harvest);
}

void failWithTwoHarvests(Farm farm) {
  harvest(farm);
  harvest(farm);
  advance(farm, farm.remaining);
  farm.restart();
}

void main() {
  late Farm farm;
  setUp(() => farm = Farm(moleInterval: 121)..resume());
  tearDown(() => farm.dispose());

  test('plot requires plow, seed, water, growth, and harvest in order', () {
    act(farm, Crop.wheat);
    expect(farm.plots.first, emptyPlot);
    act(farm, Tool.plow);
    expect(farm.plots.first.stage, Stage.plowed);
    act(farm, Tool.water);
    expect(farm.plots.first.stage, Stage.plowed);
    act(farm, Crop.corn);
    expect(farm.plots.first.stage, Stage.plowed);
    act(farm, Crop.wheat);
    expect(farm.plots.first.stage, Stage.seeded);
    act(farm, Tool.water);
    advance(farm, 4);
    act(farm, Tool.harvest);
    expect(farm.plots.first.stage, Stage.growing);
    expect(farm.cash, 0);
    farm.tick();
    expect(farm.plots.first.stage, Stage.ready);
    farm.tap(0);
    expect(farm.plots.first, emptyPlot);
    expect(farm.cash, 4);
    expect(farm.harvested, 1);
  });

  test('completion freezes timer and crops', () {
    for (var i = 0; i < 2; i++) {
      harvest(farm);
    }
    act(farm, Tool.plow, 1);
    act(farm, Crop.wheat, 1);
    act(farm, Tool.plow);
    act(farm, Crop.wheat);
    act(farm, Tool.water);
    advance(farm, 4);
    act(farm, Tool.water, 1);
    farm.tick();
    act(farm, Tool.harvest);
    final remaining = farm.remaining;
    advance(farm, 120);
    expect(farm.phase, Phase.results);
    expect(farm.remaining, remaining);
    expect(farm.plots[1].stage, Stage.growing);
    expect(farm.harvested, 3);
    expect(farm.cash, 12);
  });

  test(
    'pause freezes the clock and failure allows a cash-preserving retry',
    () {
      harvest(farm);
      farm.pause();
      advance(farm, 120);
      expect(farm.remaining, 115);
      farm.resume();
      advance(farm, 114);
      expect(farm.phase, Phase.playing);
      farm.tick();
      expect(farm.phase, Phase.failed);
      farm.restart();
      expect(farm.level, 1);
      expect(farm.remaining, 120);
      expect(farm.harvested, 0);
      expect(farm.cash, 4);
      expect(farm.plots, everyElement(emptyPlot));
    },
  );

  for (final offset in [1999, 2000]) {
    test('hammer at ${offset}ms respects the mole deadline', () {
      var milliseconds = 0;
      final stopwatch = Clock(
        () => DateTime.fromMillisecondsSinceEpoch(milliseconds),
      ).stopwatch();
      final threatened = Farm.timed(stopwatch)..resume();
      addTearDown(threatened.dispose);
      act(threatened, Tool.plow);
      act(threatened, Crop.wheat);
      milliseconds = 21000;
      act(threatened, Tool.water);
      milliseconds = 22000;
      threatened.tick();
      expect(threatened.mole, 0);
      milliseconds += offset;
      // The hammer tap must sample time even before the next scheduled tick.
      act(threatened, Tool.hammer);
      expect(threatened.mole, isNull);
      expect(threatened.cash, 0);
      expect(threatened.harvested, 0);
      milliseconds = 26000;
      threatened.tick();
      expect(
        threatened.plots.first.stage,
        offset == 1999 ? Stage.ready : Stage.unplowed,
      );
    });
  }

  test('damaged mole blocks tools and new moles until hammered', () {
    final threatened = Farm(moleInterval: 10)..resume();
    addTearDown(threatened.dispose);
    act(threatened, Tool.plow);
    act(threatened, Crop.wheat);
    threatened.tick(const Duration(seconds: 10));
    act(threatened, Tool.water);
    expect(threatened.plots.first.stage, Stage.seeded);
    act(threatened, Tool.plow, 1);
    act(threatened, Crop.wheat, 1);
    threatened.tick(const Duration(seconds: 22));
    expect(threatened.mole, 0);
    expect(threatened.moleRuined, true);
    for (final action in [Tool.plow, Crop.wheat, Tool.water, Tool.harvest]) {
      act(threatened, action);
      expect(threatened.plots.first, emptyPlot);
    }
    expect(threatened.plots[1].stage, Stage.seeded);
    act(threatened, Tool.hammer);
    act(threatened, Crop.wheat);
    expect(threatened.plots.first, emptyPlot);
    act(threatened, Tool.plow);
    act(threatened, Crop.wheat);
    expect(threatened.plots.first.stage, Stage.seeded);
  });

  test('timeout and retry clear a mole that has ruined its crop', () {
    final threatened = Farm(moleInterval: 10)..resume();
    addTearDown(threatened.dispose);
    act(threatened, Tool.plow);
    act(threatened, Crop.wheat);
    threatened.tick(const Duration(seconds: 10));
    threatened.tick(const Duration(seconds: 12));
    expect(threatened.moleRuined, true);
    threatened.tick(roundDuration);
    expect(threatened.mole, isNull);
    expect(threatened.phase, Phase.failed);
    threatened.restart();
    expect(threatened.mole, isNull);
    expect(threatened.plots, everyElement(emptyPlot));
  });

  test('shop rejects insufficient cash, then sells corn once', () {
    farm.buyCrop(Crop.corn);
    expect(farm.owns(Crop.corn), false);
    for (var i = 0; i < 3; i++) {
      harvest(farm);
    }
    farm.buyPlot();
    expect(farm.plots.length, 4);
    expect(farm.cash, 12);
    farm.buyCrop(Crop.corn);
    farm.buyCrop(Crop.corn);
    expect(farm.owns(Crop.corn), true);
    expect(farm.canBuyCrop(Crop.corn), false);
    expect(farm.cash, 0);
  });

  test('plot price stays flat across repeated buys, levels, and retries', () {
    for (var i = 0; i < 8; i++) {
      failWithTwoHarvests(farm);
    }
    for (var i = 0; i < 3; i++) {
      harvest(farm);
    }
    expect(farm.cash, 76);
    for (var i = 0; i < 3; i++) {
      farm.buyPlot();
      expect(farm.cash, 76 - 20 * (i + 1));
      expect(farm.plots.length, 5 + i);
    }
    farm.buyPlot();
    farm.buyCrop(Crop.corn);
    expect(farm.cash, 4);
    farm.restart();
    expect(farm.level, 2);
    expect(farm.remaining, 120);
    expect(farm.plots.length, 7);
    expect(farm.plots, everyElement(emptyPlot));
    harvest(farm, crop: Crop.corn);
    farm.tick(roundDuration);
    farm.restart();
    expect(farm.level, 2);
    expect(farm.cash, 11);
    expect(farm.owns(Crop.corn), true);
    expect(farm.plots.length, 7);
    expect(farm.plots, everyElement(emptyPlot));
    for (var i = 0; i < 5; i++) {
      harvest(farm, crop: Crop.corn);
    }
    farm.buyPlot();
    expect(farm.cash, 26);
    farm.restart();
    expect(farm.level, 3);
    expect(farm.target, 7);
    expect(farm.plots.length, 8);
    expect(farm.owns(Crop.corn), true);
  });

  test('plot purchases stop at 256 even with cash left', () {
    for (var i = 0; i < 631; i++) {
      harvest(farm);
      harvest(farm);
      farm.tick(roundDuration);
      farm.restart();
    }
    for (var i = 0; i < 3; i++) {
      harvest(farm);
    }
    for (var i = 0; i < 260; i++) {
      farm.buyPlot();
    }
    expect(farm.plots.length, 256);
    expect(farm.cash, 20);
    expect(farm.canBuyPlot, false);
    farm.restart();
    expect(farm.plots.length, 256);
  });

  test(
    'all 32 objectives advance in order and the final result stays open',
    () {
      for (var level = 1; level <= 32; level++) {
        expect(farm.level, level);
        expect(farm.target, 3 + (level - 1) * 2);
        expect(farm.remaining, 120);
        var toHarvest = farm.target;
        while (toHarvest > 0) {
          final batch = toHarvest >= 4 ? 4 : toHarvest;
          for (final action in [Tool.plow, Crop.wheat, Tool.water]) {
            farm.select(action);
            for (var i = 0; i < batch; i++) {
              farm.tap(i);
            }
          }
          advance(farm, 5);
          farm.select(Tool.harvest);
          for (var i = 0; i < batch; i++) {
            farm.tap(i);
          }
          toHarvest -= batch;
        }
        expect(farm.phase, Phase.results);
        expect(farm.hasNext, level < 32);
        farm.restart();
      }
      expect(farm.level, 32);
      expect(farm.harvested, 65);
      expect(farm.phase, Phase.results);
    },
  );
}
