import 'dart:math';

import 'package:flutter/foundation.dart';

import 'balance.dart';
import 'progress.dart';

enum Phase { map, playing, paused, results }

typedef Plot = ({Stage stage, Duration? readyAt});
const emptyPlot = (stage: Stage.bare, readyAt: null);
typedef ActiveHazard = ({int index, Duration startedAt});
typedef AttemptResult = ({
  bool completed,
  bool replay,
  BigInt earnings,
  BigInt bonus,
});

class Farm extends ChangeNotifier {
  Farm({
    required this._progress,
    required this._store,
    this.balance = GameBalance.standard,
    Random? random,
    this._clock,
  }) : _random = random ?? Random();

  final GameBalance balance;
  final ProgressStore _store;
  final Random _random;
  final Stopwatch? _clock;
  FarmProgress _progress;
  List<Plot> _plots = [];
  Phase _phase = Phase.map;
  LevelDefinition? _level;
  Mode? _attemptMode;
  Tool? _selection;
  int _harvested = 0;
  BigInt _earnings = BigInt.zero;
  Duration _elapsed = Duration.zero;
  Duration _nextHazard = Duration.zero;
  ActiveHazard? _hazard;
  AttemptResult? _result;
  String? _feedback;
  Duration? _feedbackUntil;
  bool _saving = false;
  bool _disposed = false;

  // The viewport supplies this check while the gameplay grid is mounted.
  bool Function(int index)? targetVisible;

  FarmProgress get progress => _progress;
  List<Plot> get plots => List.unmodifiable(_plots);
  Phase get phase => _phase;
  LevelDefinition get level => _level!;
  Mode get mode => _attemptMode ?? progress.mode;
  Tool? get selection => _selection;
  int get harvested => _harvested;
  ActiveHazard? get hazard => _hazard;
  AttemptResult get result => _result!;
  String? get feedback => _feedback;
  bool get saving => _saving;
  BigInt get cash => progress.money;

  int? get remaining {
    final limit = balance.timeLimit(mode);
    return limit == null ? null : max(0, limit.inSeconds - _elapsed.inSeconds);
  }

  LevelDefinition definition(Activity activity) =>
      balance.level(progress.expansion, activity.index + 1);

  bool canPlay(Activity activity) =>
      balance.production(activity) != null &&
      activity.index < progress.highestUnlocked;

  bool isComplete(Activity activity) =>
      progress.completed.contains(activity.index + 1);

  int capacityLimit(Capacity kind) =>
      balance.capacityLimit(kind, progress.expansion);
  BigInt price(Capacity kind) => balance.price(kind, progress.expansion);

  bool canBuy(Capacity kind) =>
      phase == Phase.map &&
      !saving &&
      progress.capacity(kind) < capacityLimit(kind) &&
      cash >= price(kind);

  Future<void> buy(Capacity kind) async {
    if (!canBuy(kind)) return;
    final count = progress.capacity(kind) + 1;
    await _commit(progress.withPurchase(kind, count, cash - price(kind)));
  }

  Future<void> setMode(Mode next) async {
    if (phase != Phase.map || saving || mode == next) return;
    await _commit(progress.copyWith(mode: next));
  }

  Future<void> resetForDebug() async {
    if (!kDebugMode || phase != Phase.map || saving) return;
    await _commit(FarmProgress.fresh(balance));
  }

  void start(Activity activity) {
    if (phase != Phase.map || saving || !canPlay(activity)) return;
    final definition = this.definition(activity);
    _begin(definition, progress.capacity(definition.production!.capacity));
  }

  void startPreviewForDebug(int count) {
    if (!kDebugMode || phase != Phase.map) return;
    _begin(definition(Activity.wheat), count);
    _plots[1] = (stage: Stage.prepared, readyAt: null);
    _plots[2] = (stage: Stage.tended, readyAt: null);
    _plots[3] = (stage: Stage.growing, readyAt: level.production!.growth);
    _plots[4] = (stage: Stage.ready, readyAt: null);
  }

  void _begin(LevelDefinition definition, int count) {
    _level = definition;
    _attemptMode = progress.mode;
    _plots = List.filled(count, emptyPlot);
    _selection = level.prepare;
    _harvested = 0;
    _earnings = BigInt.zero;
    _elapsed = Duration.zero;
    _nextHazard = balance.safePeriod;
    _hazard = null;
    _result = null;
    _feedback = null;
    _feedbackUntil = null;
    _phase = Phase.playing;
    _clock?.reset();
    _clock?.start();
    _notify();
  }

  void pause() {
    if (phase != Phase.playing) return;
    if (_clock case final clock?) tick(clock.elapsed);
    if (phase != Phase.playing) return;
    _clock?.stop();
    _phase = Phase.paused;
    _notify();
  }

  void resume() {
    if (phase != Phase.paused) return;
    _clock?.start();
    _phase = Phase.playing;
    _notify();
  }

  void returnToMap() {
    if (saving || (phase != Phase.results && phase != Phase.paused)) return;
    _phase = Phase.map;
    _attemptMode = null;
    _hazard = null;
    _feedback = null;
    _notify();
  }

  void select(Tool tool) {
    if (phase != Phase.playing) return;
    _selection = tool;
    _notify();
  }

  Future<void> tap(int index) async {
    if (_clock case final clock?) tick(clock.elapsed);
    if (phase != Phase.playing ||
        saving ||
        index < 0 ||
        index >= _plots.length) {
      return;
    }
    final plot = _plots[index];
    final rule = level.production!.hazard;
    if (hazard case (index: final affected, startedAt: final start)
        when index == affected) {
      if (selection != rule.tool) {
        _hint('Use ${rule.tool.label} on the ${rule.label}.');
        return;
      }
      if (balance.hazardDeadline(mode) == null && plot.readyAt != null) {
        _plots[index] = (
          stage: plot.stage,
          readyAt: plot.readyAt! + (_elapsed - start),
        );
      }
      _clearHazard();
    } else if (plot.stage == Stage.bare && selection == level.prepare) {
      _plots[index] = (stage: Stage.prepared, readyAt: null);
    } else if (plot.stage == Stage.prepared && selection == level.tend) {
      _plots[index] = (stage: Stage.tended, readyAt: null);
    } else if (plot.stage == Stage.tended &&
        selection == level.beginProduction) {
      _plots[index] = (
        stage: Stage.growing,
        readyAt: _elapsed + level.production!.growth,
      );
    } else if (plot.stage == Stage.ready && selection == level.collect) {
      await _harvest(index);
      return;
    } else {
      _hint(switch (plot.stage) {
        Stage.bare => '${level.prepare.label} first.',
        Stage.prepared =>
          level.field
              ? 'Select ${level.activity.label} and plant.'
              : 'Select ${level.tend.label}.',
        Stage.tended => 'Select ${level.beginProduction.label}.',
        Stage.growing => 'Still growing.',
        Stage.ready => 'Select ${level.collect.label}.',
      });
      return;
    }
    _feedback = null;
    _notify();
  }

  Future<void> _harvest(int index) async {
    final earnings = _earnings + level.unitValue!;
    final completed = harvested + 1 == level.objective;
    final replay = isComplete(level.activity);
    final bonus = completed
        ? balance.completionBonus(mode, earnings)
        : BigInt.zero;
    await _commit(
      progress.copyWith(
        money: cash + level.unitValue! + bonus,
        completed: completed
            ? {...progress.completed, level.activity.index + 1}
            : null,
      ),
      onSaved: () {
        _plots[index] = emptyPlot;
        _earnings = earnings;
        _harvested++;
        _feedback = null;
        if (completed) _finish(completed: true, replay: replay, bonus: bonus);
      },
    );
  }

  void tick([Duration? elapsed]) {
    if (phase != Phase.playing || saving) return;
    final now = elapsed ?? _clock?.elapsed ?? _elapsed;
    if (now < _elapsed) return;
    final lastRemaining = remaining;
    _elapsed = now;
    final limit = balance.timeLimit(mode);
    if (limit != null && now >= limit) {
      _finish(
        completed: false,
        replay: isComplete(level.activity),
        bonus: BigInt.zero,
      );
      _notify();
      return;
    }

    var changed = remaining != lastRemaining;
    final deadline = balance.hazardDeadline(mode);
    if (hazard case (index: final index, startedAt: final start)
        when deadline != null && now - start >= deadline) {
      _plots[index] = (stage: level.production!.hazard.setback, readyAt: null);
      _clearHazard();
      changed = true;
    }
    for (var i = 0; i < _plots.length; i++) {
      if (hazard?.index == i && deadline == null) continue;
      final readyAt = _plots[i].readyAt;
      if (readyAt != null && now >= readyAt) {
        _plots[i] = (stage: Stage.ready, readyAt: null);
        changed = true;
      }
    }
    if (hazard == null && now >= _nextHazard) {
      _nextHazard = now + balance.spawnInterval;
      final candidates = [
        for (var i = 0; i < _plots.length; i++)
          if ((_plots[i].stage == Stage.tended ||
                  _plots[i].stage == Stage.growing) &&
              (targetVisible?.call(i) ?? true))
            i,
      ];
      if (candidates.isNotEmpty && _random.nextDouble() < balance.spawnChance) {
        _hazard = (
          index: candidates[_random.nextInt(candidates.length)],
          startedAt: now,
        );
        changed = true;
      }
    }
    if (_feedbackUntil case final until? when now >= until) {
      _feedbackUntil = null;
      if (_feedback != null) {
        _feedback = null;
        changed = true;
      }
    }
    if (changed) _notify();
  }

  void _clearHazard() {
    _hazard = null;
    _nextHazard = _elapsed + balance.cooldown;
  }

  void _finish({
    required bool completed,
    required bool replay,
    required BigInt bonus,
  }) {
    _clock?.stop();
    _hazard = null;
    _phase = Phase.results;
    _result = (
      completed: completed,
      replay: replay,
      earnings: _earnings,
      bonus: bonus,
    );
  }

  void _hint(String message) {
    _feedback = message;
    _feedbackUntil = _elapsed + GameBalance.feedbackDuration;
    _notify();
  }

  Future<void> _commit(FarmProgress next, {VoidCallback? onSaved}) async {
    _saving = true;
    _feedback = null;
    _notify();
    try {
      await _store.save(next);
      _progress = next;
      onSaved?.call();
    } on Exception {
      _feedback = 'Could not save progress. Please try again.';
      _feedbackUntil = null;
    } finally {
      _saving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clock?.stop();
    super.dispose();
  }
}
