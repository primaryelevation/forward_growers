import 'dart:convert';
import 'dart:io';

import 'balance.dart';

class FarmProgress {
  FarmProgress({
    required this.money,
    required this.expansion,
    required Map<Capacity, int> capacities,
    required this.mode,
    required Set<int> completed,
  }) : _capacities = Map.unmodifiable(capacities),
       completed = Set.unmodifiable(completed);

  factory FarmProgress.fresh(GameBalance balance) => FarmProgress(
    money: BigInt.zero,
    expansion: GameBalance.firstExpansion,
    capacities: {
      for (final kind in Capacity.values) kind: balance.startingCapacity(kind),
    },
    mode: GameBalance.defaultMode,
    completed: {},
  );

  static const schemaVersion = 2;
  static const _legacyVersion = 1;
  static final _decimalWallet = RegExp(r'^[0-9]+$');
  final BigInt money;
  final int expansion;
  final Map<Capacity, int> _capacities;
  int get fieldPlots => capacity(Capacity.field);
  int get appleTrees => capacity(Capacity.orchard);
  final Mode mode;
  final Set<int> completed;

  int capacity(Capacity kind) => _capacities[kind]!;

  FarmProgress withPurchase(Capacity kind, int count, BigInt remaining) =>
      FarmProgress(
        money: remaining,
        expansion: expansion,
        capacities: {..._capacities, kind: count},
        mode: mode,
        completed: completed,
      );

  int get highestUnlocked {
    for (var position = 1; position <= Activity.values.length; position++) {
      if (!completed.contains(position)) return position;
    }
    return Activity.values.length;
  }

  FarmProgress copyWith({
    BigInt? money,
    int? expansion,
    int? fieldPlots,
    int? appleTrees,
    Mode? mode,
    Set<int>? completed,
  }) => FarmProgress(
    money: money ?? this.money,
    expansion: expansion ?? this.expansion,
    capacities: {
      ..._capacities,
      Capacity.field: ?fieldPlots,
      Capacity.orchard: ?appleTrees,
    },
    mode: mode ?? this.mode,
    completed: completed ?? this.completed,
  );

  static bool _isLegacyCapacity(Capacity kind) =>
      kind == Capacity.field || kind == Capacity.orchard;

  String encode() => jsonEncode({
    'version': schemaVersion,
    'money': money.toString(),
    'expansion': expansion,
    'fieldPlots': fieldPlots,
    'appleTrees': appleTrees,
    'producers': {
      for (final kind in Capacity.values)
        if (!_isLegacyCapacity(kind)) kind.name: capacity(kind),
    },
    'mode': mode.name,
    'completed': completed.toList()..sort(),
    'highestUnlocked': highestUnlocked,
  });

  factory FarmProgress.decode(String contents, GameBalance balance) {
    final data = jsonDecode(contents);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid farm save');
    }
    final version = data['version'];
    if (version != schemaVersion && version != _legacyVersion) {
      throw const FormatException('Unsupported save version');
    }
    final wallet = data['money'];
    final money = wallet is String && _decimalWallet.hasMatch(wallet)
        ? BigInt.tryParse(wallet)
        : null;
    final expansion = data['expansion'];
    final field = data['fieldPlots'];
    final trees = data['appleTrees'];
    final producers = data['producers'];
    final activities = data['completed'];
    final mode = Mode.values
        .where((mode) => mode.name == data['mode'])
        .firstOrNull;
    if (money == null ||
        money.isNegative ||
        expansion is! int ||
        field is! int ||
        trees is! int ||
        (version == schemaVersion && producers is! Map<String, dynamic>) ||
        activities is! List ||
        mode == null) {
      throw const FormatException('Invalid farm progress');
    }
    final capacities = <Capacity, int>{};
    try {
      for (final kind in Capacity.values) {
        final count = switch (kind) {
          Capacity.field => field,
          Capacity.orchard => trees,
          _ when version == _legacyVersion => balance.startingCapacity(kind),
          _ => (producers as Map<String, dynamic>)[kind.name],
        };
        if (count is! int) throw const FormatException('Invalid farm capacity');
        capacities[kind] = RangeError.checkValueInInterval(
          count,
          balance.startingCapacity(kind),
          balance.capacityLimit(kind, expansion),
        );
      }
    } on RangeError {
      throw const FormatException('Invalid farm capacity');
    }
    final completed = <int>{};
    for (final activity in activities) {
      if (activity is! int ||
          activity < 1 ||
          activity > Activity.values.length ||
          !completed.add(activity)) {
        throw const FormatException('Invalid completed activities');
      }
    }
    final progress = FarmProgress(
      money: money,
      expansion: expansion,
      capacities: capacities,
      mode: mode,
      completed: completed,
    );
    final sequential =
        completed.length == Activity.values.length ||
        completed.length == progress.highestUnlocked - 1;
    if (!sequential || data['highestUnlocked'] != progress.highestUnlocked) {
      throw const FormatException('Invalid activity sequence');
    }
    return progress;
  }
}

abstract interface class ProgressStore {
  Future<FarmProgress?> load(GameBalance balance);
  Future<void> save(FarmProgress progress);
}

class FileProgressStore implements ProgressStore {
  FileProgressStore(this.file);
  final File file;

  @override
  Future<FarmProgress?> load(GameBalance balance) async {
    if (!await file.exists()) return null;
    return FarmProgress.decode(await file.readAsString(), balance);
  }

  @override
  Future<void> save(FarmProgress progress) async {
    await file.parent.create(recursive: true);
    final pending = File('${file.path}.pending');
    await pending.writeAsString(progress.encode(), flush: true);
    // Both files are in the same directory, so Android and iOS replace atomically.
    await pending.rename(file.path);
  }
}
