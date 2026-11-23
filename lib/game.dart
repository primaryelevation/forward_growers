import 'dart:math';

import 'package:flutter/foundation.dart';

import 'balance.dart';
import 'orders.dart';
import 'progress.dart';

enum Phase { map, playing, paused, results }

typedef Plot = ({Stage stage, Duration? readyAt});
const emptyPlot = (stage: Stage.bare, readyAt: null);
typedef ActiveHazard = ({int index, Duration startedAt});
typedef AttemptResult = ({
  bool completed,
  bool replay,
  bool awardedRibbon,
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
  List<TableOrder?> _orders = [];
  int _nextTemplate = 0;
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
  int get spaceCount => _plots.length + _orders.length;
  TableOrder? orderAt(int index) => _orders[index];
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

  LevelDefinition definition(Activity activity, {int? expansion}) =>
      balance.level(expansion ?? progress.expansion, activity.index + 1);

  bool canPlay(Activity activity, {int? expansion}) {
    final chosen = expansion ?? progress.expansion;
    return chosen >= GameBalance.firstExpansion &&
        chosen <= progress.expansion &&
        definition(activity, expansion: chosen).playable &&
        activity.index < progress.unlockedIn(chosen);
  }

  bool isComplete(Activity activity, {int? expansion}) => progress.completed
      .contains(definition(activity, expansion: expansion).number);

  BigInt get nextExpansionPrice => balance.expansionPrice(progress.expansion);

  bool get canExpand =>
      phase == Phase.map &&
      !saving &&
      progress.hasBlueRibbon &&
      cash >= nextExpansionPrice;

  Future<void> buyNextExpansion(int expectedExpansion) async {
    if (expectedExpansion != progress.expansion || !canExpand) return;
    await _commit(
      progress.copyWith(
        expansion: progress.expansion + 1,
        money: cash - nextExpansionPrice,
      ),
    );
  }

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

  void start(Activity activity, {int? expansion}) {
    if (phase != Phase.map ||
        saving ||
        !canPlay(activity, expansion: expansion)) {
      return;
    }
    final definition = this.definition(activity, expansion: expansion);
    _begin(definition, progress.capacity(definition.capacity));
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
    final rules = level.orders;
    _plots = rules == null ? List.filled(count, emptyPlot) : [];
    _orders = rules == null ? [] : List.filled(count, null);
    _nextTemplate = 0;
    _selection = rules?.steps.first ?? level.prepare;
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

  Tool? nextAction(int index) {
    if (index < 0 || index >= spaceCount) return null;
    if (hazard?.index == index) return level.hazard.tool;
    if (level.orders case final rules?) {
      return _orders[index]?.next(rules) ?? rules.steps.first;
    }
    return switch (_plots[index].stage) {
      Stage.bare => level.prepare,
      Stage.prepared => level.tend,
      Stage.tended => level.beginProduction,
      Stage.growing => null,
      Stage.ready => level.collect,
    };
  }

  bool canApply(int index) =>
      phase == Phase.playing &&
      !saving &&
      selection != null &&
      selection == nextAction(index);

  double? growthProgress(int index) {
    final readyAt = _plots[index].readyAt;
    if (readyAt == null) return null;
    final work = level.production!.growth.inMicroseconds;
    final elapsed =
        hazard?.index == index && balance.hazardDeadline(mode) == null
        ? hazard!.startedAt
        : _elapsed;
    return (1 - (readyAt - elapsed).inMicroseconds / work).clamp(0.0, 1.0);
  }

  Future<void> tap(int index) async {
    if (_clock case final clock?) tick(clock.elapsed);
    if (phase != Phase.playing || saving || index < 0 || index >= spaceCount) {
      return;
    }
    if (!canApply(index)) {
      final next = nextAction(index);
      _hint(
        hazard?.index == index
            ? 'Use ${level.hazard.tool.label} on the ${level.hazard.label}.'
            : next == null
            ? 'Still growing.'
            : level.field && next == Tool.plant
            ? 'Select ${level.activity.label} and plant.'
            : level.orders == null && next == level.prepare
            ? '${next.label} first.'
            : 'Select ${next.label}.',
      );
      return;
    }
    if (hazard case (index: final affected, startedAt: final start)
        when index == affected) {
      if (level.orders == null && balance.hazardDeadline(mode) == null) {
        final plot = _plots[index];
        if (plot.readyAt case final readyAt?) {
          _plots[index] = (
            stage: plot.stage,
            readyAt: readyAt + (_elapsed - start),
          );
        }
      }
      _clearHazard();
    } else if (level.orders case final rules?) {
      final order = _orders[index];
      if (selection == Tool.collectMoney) {
        await _collect(() => _orders[index] = null);
        return;
      }
      _orders[index] = order == null
          ? TableOrder(
              rules.templates[_nextTemplate++ % rules.templates.length],
            )
          : order.advance(rules);
    } else {
      final plot = _plots[index];
      switch (plot.stage) {
        case Stage.bare:
          _plots[index] = (stage: Stage.prepared, readyAt: null);
        case Stage.prepared:
          _plots[index] = (stage: Stage.tended, readyAt: null);
        case Stage.tended:
          _plots[index] = (
            stage: Stage.growing,
            readyAt: _elapsed + level.production!.growth,
          );
        case Stage.growing:
          return;
        case Stage.ready:
          await _collect(() => _plots[index] = emptyPlot);
          return;
      }
    }
    _feedback = null;
    _notify();
  }

  Future<void> _collect(VoidCallback resetSpace) async {
    final earnings = _earnings + level.unitValue!;
    final completed = harvested + 1 == level.objective;
    final replay = progress.completed.contains(level.number);
    final awardedRibbon =
        completed && level.activity == Activity.fair && !progress.hasBlueRibbon;
    final bonus = completed
        ? balance.completionBonus(mode, earnings)
        : BigInt.zero;
    await _commit(
      progress.copyWith(
        money: cash + level.unitValue! + bonus,
        completed: completed ? {...progress.completed, level.number} : null,
      ),
      onSaved: () {
        resetSpace();
        _earnings = earnings;
        _harvested++;
        _feedback = null;
        if (completed) {
          _finish(
            completed: true,
            replay: replay,
            bonus: bonus,
            awardedRibbon: awardedRibbon,
          );
        }
      },
    );
  }

  void tick([Duration? elapsed]) {
    if (phase != Phase.playing || saving) return;
    final now = elapsed ?? _clock?.elapsed ?? _elapsed;
    if (now < _elapsed) return;
    final lastRemaining = remaining;
    final progressChanged =
        now.inMilliseconds ~/ 100 != _elapsed.inMilliseconds ~/ 100;
    _elapsed = now;
    final limit = balance.timeLimit(mode);
    if (limit != null && now >= limit) {
      _finish(
        completed: false,
        replay: progress.completed.contains(level.number),
        bonus: BigInt.zero,
      );
      _notify();
      return;
    }

    var changed = remaining != lastRemaining;
    final deadline = balance.hazardDeadline(mode);
    if (hazard case (index: final index, startedAt: final start)
        when deadline != null && now - start >= deadline) {
      if (level.orders case final rules?) {
        _orders[index] = _orders[index]!.setback(rules);
        _feedback = null;
      } else {
        _plots[index] = (
          stage: level.production!.hazard.setback,
          readyAt: null,
        );
      }
      _clearHazard();
      changed = true;
    }
    for (var i = 0; i < _plots.length; i++) {
      if (hazard?.index == i && deadline == null) continue;
      final readyAt = _plots[i].readyAt;
      if (readyAt != null && now >= readyAt) {
        _plots[i] = (stage: Stage.ready, readyAt: null);
        changed = true;
      } else if (readyAt != null && progressChanged) {
        changed = true;
      }
    }
    if (hazard == null && now >= _nextHazard) {
      _nextHazard = now + balance.spawnInterval;
      final candidates = [
        for (var i = 0; i < spaceCount; i++)
          if (_hazardTarget(i) && (targetVisible?.call(i) ?? true)) i,
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

  bool _hazardTarget(int index) {
    if (level.orders != null) return (_orders[index]?.gathered ?? 0) > 0;
    final stage = _plots[index].stage;
    return stage == Stage.tended || stage == Stage.growing;
  }

  void _clearHazard() {
    _hazard = null;
    _nextHazard = _elapsed + balance.cooldown;
  }

  void _finish({
    required bool completed,
    required bool replay,
    required BigInt bonus,
    bool awardedRibbon = false,
  }) {
    _clock?.stop();
    _hazard = null;
    _phase = Phase.results;
    _result = (
      completed: completed,
      replay: replay,
      awardedRibbon: awardedRibbon,
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
