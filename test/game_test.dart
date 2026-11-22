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

  for (final useHammer in [true, false]) {
    test(
      useHammer
          ? 'hammer preserves the crop'
          : 'ignored mole destroys the crop',
      () {
        final threatened = Farm(moleInterval: 10)..resume();
        addTearDown(threatened.dispose);
        act(threatened, Tool.plow);
        act(threatened, Crop.wheat);
        advance(threatened, 10);
        expect(threatened.mole, 0);
        act(threatened, Tool.water);
        expect(threatened.plots.first.stage, Stage.seeded);
        advance(threatened, 3);
        expect(threatened.mole, 0);
        if (useHammer) act(threatened, Tool.hammer);
        threatened.tick();
        expect(threatened.mole, isNull);
        expect(
          threatened.plots.first.stage,
          useHammer ? Stage.seeded : Stage.unplowed,
        );
      },
    );
  }

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

  test('purchases share cash, cap plots at six, and carry into Level 2', () {
    for (var i = 0; i < 8; i++) {
      failWithTwoHarvests(farm);
    }
    for (var i = 0; i < 3; i++) {
      harvest(farm);
    }
    expect(farm.cash, 76);
    farm.buyPlot();
    farm.buyPlot();
    farm.buyPlot();
    farm.buyCrop(Crop.corn);
    farm.buyCrop(Crop.corn);
    expect(farm.cash, 24);
    farm.restart();
    expect(farm.level, 2);
    expect(farm.target, 5);
    expect(farm.remaining, 120);
    expect(farm.cash, 24);
    expect(farm.owns(Crop.corn), true);
    expect(farm.plots.length, 6);
    expect(farm.plots, everyElement(emptyPlot));
    for (var i = 0; i < 5; i++) {
      harvest(farm, crop: Crop.corn);
    }
    expect(farm.cash, 59);
    expect(farm.phase, Phase.results);
    expect(farm.hasNext, false);
  });
}
