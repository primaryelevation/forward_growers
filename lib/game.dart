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

const levels = [3, 5];

typedef Plot = ({Stage stage, Crop? crop, int? readyAt});
const Plot emptyPlot = (stage: Stage.unplowed, crop: null, readyAt: null);

class Farm extends ChangeNotifier {
  Farm({Random? random, this.moleInterval = 22}) : _random = random ?? Random();

  final Random _random;
  final int moleInterval;
  final _plots = List<Plot>.filled(4, emptyPlot, growable: true);
  final _owned = {Crop.wheat};

  int _elapsed = 0;
  int _moleDeadline = 0;
  int? _mole;
  int _level = 1;
  int _cash = 0;
  int _harvested = 0;
  Object _selection = Tool.plow;
  Phase _phase = Phase.instructions;

  List<Plot> get plots => List.unmodifiable(_plots);
  int get level => _level;
  int get cash => _cash;
  int get harvested => _harvested;
  int get target => levels[level - 1];
  int get remaining => 120 - _elapsed;
  int? get mole => _mole;
  Object get selection => _selection;
  Phase get phase => _phase;
  bool get hasNext => level < levels.length;
  bool owns(Crop crop) => _owned.contains(crop);

  void resume() {
    if (phase != Phase.instructions && phase != Phase.paused) return;
    _phase = Phase.playing;
    notifyListeners();
  }

  void pause() {
    if (phase != Phase.playing) return;
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
    _elapsed = 0;
    _harvested = 0;
    _mole = null;
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
    if (phase != Phase.playing) return;
    final plot = _plots[index];
    final action = selection;
    if (mole == index) {
      if (action != Tool.hammer) return;
      _mole = null;
    } else if (action == Tool.plow && plot.stage == Stage.unplowed) {
      _plots[index] = (stage: Stage.plowed, crop: null, readyAt: null);
    } else if (action is Crop && plot.stage == Stage.plowed) {
      _plots[index] = (stage: Stage.seeded, crop: action, readyAt: null);
    } else if (action == Tool.water && plot.stage == Stage.seeded) {
      _plots[index] = (
        stage: Stage.growing,
        crop: plot.crop,
        readyAt: _elapsed + plot.crop!.seconds,
      );
    } else if (action == Tool.harvest && plot.stage == Stage.ready) {
      _cash += plot.crop!.reward;
      _harvested++;
      _plots[index] = emptyPlot;
      if (harvested == target) {
        _phase = Phase.results;
        _mole = null;
      }
    } else {
      return;
    }
    notifyListeners();
  }

  void tick() {
    if (phase != Phase.playing) return;
    _elapsed++;
    if (remaining == 0) {
      _phase = Phase.failed;
      _mole = null;
      notifyListeners();
      return;
    }

    final affected = mole;
    if (affected != null && _elapsed >= _moleDeadline) {
      _plots[affected] = emptyPlot;
      _mole = null;
    }
    for (var i = 0; i < _plots.length; i++) {
      final plot = _plots[i];
      if (plot.readyAt == _elapsed) {
        _plots[i] = (stage: Stage.ready, crop: plot.crop, readyAt: null);
      }
    }
    if (mole == null && _elapsed % moleInterval == 0) {
      final candidates = [
        for (var i = 0; i < _plots.length; i++)
          if (_plots[i].stage == Stage.seeded ||
              _plots[i].stage == Stage.growing)
            i,
      ];
      if (candidates.isNotEmpty) {
        _mole = candidates[_random.nextInt(candidates.length)];
        _moleDeadline = _elapsed + 4;
      }
    }
    notifyListeners();
  }

  bool get canBuyPlot =>
      phase == Phase.results && hasNext && _plots.length < 6 && cash >= 20;

  bool canBuyCrop(Crop crop) =>
      phase == Phase.results && hasNext && !owns(crop) && cash >= crop.price;

  void buyPlot() {
    if (!canBuyPlot) return;
    _cash -= 20;
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
