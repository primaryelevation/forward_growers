import 'dart:math';

import 'package:flutter/foundation.dart';

enum Stage { unplowed, plowed, seeded, growing, ready }

enum Tool { plow, water, harvest, hammer }

enum Phase { instructions, playing, paused, failed, results }

enum Crop {
  wheat('Wheat', 5, 4),
  corn('Corn', 8, 7, price: 12);

  const Crop(this.label, this.seconds, this.reward, {this.price = 0});
  final String label;
  final int seconds;
  final int reward;
  final int price;
}

const finalLevel = 32;
const maxPlots = 256;
const plotPrice = 20;
const roundDuration = Duration(minutes: 2);
const moleWindow = Duration(seconds: 2);

int harvestTarget(int level) => 2 * level + 1;

typedef Plot = ({Stage stage, Crop? crop, Duration? readyAt});
const Plot emptyPlot = (stage: Stage.unplowed, crop: null, readyAt: null);

class Farm extends ChangeNotifier {
  Farm({Random? random, this.moleInterval = 22})
    : assert(moleInterval > 0),
      _random = random ?? Random(),
      _clock = null;

  Farm.timed(this._clock) : _random = Random(), moleInterval = 22;

  factory Farm.preview() {
    final farm = Farm();
    farm._plots.addAll(List.filled(maxPlots - farm.plotCount, emptyPlot));
    farm._plots[1] = (stage: Stage.plowed, crop: null, readyAt: null);
    farm._plots[2] = (stage: Stage.seeded, crop: Crop.wheat, readyAt: null);
    farm._plots[3] = (
      stage: Stage.growing,
      crop: Crop.wheat,
      readyAt: const Duration(seconds: 5),
    );
    farm._plots[4] = (stage: Stage.ready, crop: Crop.wheat, readyAt: null);
    farm._phase = Phase.playing;
    return farm;
  }

  final Random _random;
  final Stopwatch? _clock;
  final int moleInterval;
  final _plots = List<Plot>.filled(4, emptyPlot, growable: true);
  final _owned = {Crop.wheat};

  Duration _elapsed = Duration.zero;
  Duration? _moleDeadline;
  int? _mole;
  int _level = 1;
  int _cash = 0;
  int _harvested = 0;
  Object _selection = Tool.plow;
  Phase _phase = Phase.instructions;

  List<Plot> get plots => List.unmodifiable(_plots);
  int get plotCount => _plots.length;
  int get level => _level;
  int get cash => _cash;
  int get harvested => _harvested;
  int get target => harvestTarget(level);
  int get remaining => roundDuration.inSeconds - _elapsed.inSeconds;
  int? get mole => _mole;
  Object get selection => _selection;
  Phase get phase => _phase;
  bool get moleRuined => _mole != null && _moleDeadline == null;
  bool get hasNext => level < finalLevel;
  bool owns(Crop crop) => _owned.contains(crop);

  void resume() {
    if (phase != Phase.instructions && phase != Phase.paused) return;
    _phase = Phase.playing;
    _clock?.start();
    notifyListeners();
  }

  void pause() {
    if (phase != Phase.playing) return;
    if (_clock case final clock?) tick(clock.elapsed);
    if (phase != Phase.playing) return;
    _clock?.stop();
    _phase = Phase.paused;
    notifyListeners();
  }

  void restart() {
    if (phase == Phase.results && hasNext) {
      _level++;
    } else if (phase != Phase.failed) {
      return;
    }
    _plots.fillRange(0, _plots.length, emptyPlot);
    _elapsed = Duration.zero;
    _clock?.reset();
    _clock?.start();
    _harvested = 0;
    _mole = null;
    _moleDeadline = null;
    _selection = Tool.plow;
    _phase = Phase.playing;
    notifyListeners();
  }

  void select(Object action) {
    if (phase != Phase.playing) return;
    if (action is! Tool && (action is! Crop || !owns(action))) return;
    _selection = action;
    notifyListeners();
  }

  void tap(int index) {
    // Resolve deadlines at input time even between display updates.
    if (_clock case final clock?) tick(clock.elapsed);
    if (phase != Phase.playing) return;
    final plot = _plots[index];
    final action = selection;
    if (mole == index) {
      if (action != Tool.hammer) return;
      _mole = null;
      _moleDeadline = null;
    } else if (action == Tool.plow && plot.stage == Stage.unplowed) {
      _plots[index] = (stage: Stage.plowed, crop: null, readyAt: null);
    } else if (action is Crop && plot.stage == Stage.plowed) {
      _plots[index] = (stage: Stage.seeded, crop: action, readyAt: null);
    } else if (action == Tool.water && plot.stage == Stage.seeded) {
      _plots[index] = (
        stage: Stage.growing,
        crop: plot.crop,
        readyAt: _elapsed + Duration(seconds: plot.crop!.seconds),
      );
    } else if (action == Tool.harvest && plot.stage == Stage.ready) {
      _cash += plot.crop!.reward;
      _harvested++;
      _plots[index] = emptyPlot;
      if (harvested == target) {
        _phase = Phase.results;
        _clock?.stop();
        _mole = null;
        _moleDeadline = null;
      }
    } else {
      return;
    }
    notifyListeners();
  }

  void tick([Duration? elapsed]) {
    if (phase != Phase.playing) return;
    final previous = _elapsed;
    final previousRemaining = remaining;
    final now =
        elapsed ?? _clock?.elapsed ?? previous + const Duration(seconds: 1);
    if (now <= previous) return;
    if (now >= roundDuration) {
      _elapsed = roundDuration;
      _phase = Phase.failed;
      _clock?.stop();
      _mole = null;
      _moleDeadline = null;
      notifyListeners();
      return;
    }

    _elapsed = now;
    var changed = remaining != previousRemaining;
    final deadline = _moleDeadline;
    if (deadline != null && now >= deadline) {
      _plots[mole!] = emptyPlot;
      _moleDeadline = null;
      changed = true;
    }
    for (var i = 0; i < _plots.length; i++) {
      final plot = _plots[i];
      final readyAt = plot.readyAt;
      if (readyAt != null && now >= readyAt) {
        _plots[i] = (stage: Stage.ready, crop: plot.crop, readyAt: null);
        changed = true;
      }
    }
    if (mole == null &&
        now.inSeconds ~/ moleInterval > previous.inSeconds ~/ moleInterval) {
      final candidates = [
        for (var i = 0; i < _plots.length; i++)
          if (_plots[i].stage == Stage.seeded ||
              _plots[i].stage == Stage.growing)
            i,
      ];
      if (candidates.isNotEmpty) {
        _mole = candidates[_random.nextInt(candidates.length)];
        _moleDeadline = now + moleWindow;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  bool get canBuyPlot =>
      phase == Phase.results && plotCount < maxPlots && cash >= plotPrice;

  bool canBuyCrop(Crop crop) =>
      phase == Phase.results && !owns(crop) && cash >= crop.price;

  void buyPlot() {
    if (!canBuyPlot) return;
    _cash -= plotPrice;
    _plots.add(emptyPlot);
    notifyListeners();
  }

  void buyCrop(Crop crop) {
    if (!canBuyCrop(crop)) return;
    _cash -= crop.price;
    _owned.add(crop);
    notifyListeners();
  }
}
