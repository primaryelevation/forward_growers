enum Activity {
  wheat('Wheat'),
  corn('Corn'),
  carrots('Carrots'),
  apples('Apple Orchard'),
  dairy('Dairy Barn'),
  chickens('Chicken Coop'),
  sheep('Sheep Pasture'),
  bees('Bee Yard'),
  market('Farmers Market'),
  fair('County Fair');

  const Activity(this.label);
  final String label;
}

enum Capacity { field, orchard }

enum Mode {
  relaxed('Relaxed Mode'),
  timed('Timed Challenge');

  const Mode(this.label);
  final String label;
}

enum Tool {
  plow('Plow'),
  plant('Plant'),
  water('Water'),
  harvest('Harvest'),
  prune('Prune'),
  fertilize('Fertilize'),
  pick('Pick'),
  hammer('Hammer'),
  noisemaker('Noisemaker'),
  dogWhistle('Dog Whistle'),
  orchardWhistle('Orchard Whistle');

  const Tool(this.label);
  final String label;
}

enum Stage { bare, prepared, tended, growing, ready }

typedef HazardRule = ({String label, Tool tool, Stage setback});
typedef Production = ({
  Duration growth,
  int value,
  Capacity capacity,
  HazardRule hazard,
});

class GameBalance {
  const GameBalance({
    this.wheatGrowth = const Duration(seconds: 3),
    this.objectiveGrowth = 2,
    this.safePeriod = const Duration(seconds: 5),
    this.cooldown = const Duration(seconds: 8),
    this.responseWindow = const Duration(seconds: 2),
    this.spawnInterval = const Duration(seconds: 5),
    this.spawnChance = .5,
    this.timedDuration = const Duration(minutes: 2),
  });

  static const standard = GameBalance();
  static const baseTargets = [3, 4, 5, 4, 4, 5, 4, 5, 4, 5];
  static const firstExpansion = 1;
  static const defaultMode = Mode.relaxed;
  static const _earningsScale = (5, 4);
  static const _priceScale = (27, 20);
  static const _bonus = (1, 4);
  static const _capacities = {
    Capacity.field: (start: 4, increment: 4, price: 20),
    Capacity.orchard: (start: 2, increment: 2, price: 30),
  };

  final Duration wheatGrowth;
  final int objectiveGrowth;
  final Duration safePeriod;
  final Duration cooldown;
  final Duration responseWindow;
  final Duration spawnInterval;
  final double spawnChance;
  final Duration timedDuration;

  Production? production(Activity activity) => switch (activity) {
    Activity.wheat => (
      growth: wheatGrowth,
      value: 2,
      capacity: Capacity.field,
      hazard: (label: 'Mole', tool: Tool.hammer, setback: Stage.bare),
    ),
    Activity.corn => (
      growth: const Duration(seconds: 5),
      value: 3,
      capacity: Capacity.field,
      hazard: (label: 'Crow', tool: Tool.noisemaker, setback: Stage.prepared),
    ),
    Activity.carrots => (
      growth: const Duration(seconds: 4),
      value: 3,
      capacity: Capacity.field,
      hazard: (label: 'Rabbit', tool: Tool.dogWhistle, setback: Stage.prepared),
    ),
    Activity.apples => (
      growth: const Duration(seconds: 5),
      value: 5,
      capacity: Capacity.orchard,
      hazard: (
        label: 'Squirrel',
        tool: Tool.orchardWhistle,
        setback: Stage.bare,
      ),
    ),
    _ => null,
  };

  int startingCapacity(Capacity capacity) => _capacities[capacity]!.start;

  int capacityLimit(Capacity capacity, int expansion) {
    _checkExpansion(expansion);
    final rule = _capacities[capacity]!;
    return rule.start + rule.increment * expansion;
  }

  BigInt price(Capacity capacity, int expansion) {
    _checkExpansion(expansion);
    return _scale(_capacities[capacity]!.price, _priceScale, expansion);
  }

  static const feedbackDuration = Duration(seconds: 2);

  Duration? timeLimit(Mode mode) => mode == Mode.timed ? timedDuration : null;
  Duration? hazardDeadline(Mode mode) =>
      mode == Mode.timed ? responseWindow : null;

  BigInt completionBonus(Mode mode, BigInt earnings) => mode == Mode.timed
      ? _round(earnings * BigInt.from(_bonus.$1), BigInt.from(_bonus.$2))
      : BigInt.zero;

  LevelDefinition level(int expansion, int activityNumber) {
    _checkExpansion(expansion);
    RangeError.checkValueInInterval(activityNumber, 1, Activity.values.length);
    final activity = Activity.values[activityNumber - 1];
    final work = production(activity);
    return LevelDefinition(
      number: (expansion - 1) * Activity.values.length + activityNumber,
      activity: activity,
      objective:
          baseTargets[activity.index] + objectiveGrowth * (expansion - 1),
      production: work,
      unitValue: work == null
          ? null
          : _scale(work.value, _earningsScale, expansion),
    );
  }

  // Keep generated level and capacity arithmetic inside the exact int range.
  void _checkExpansion(int expansion) => RangeError.checkValueInInterval(
    expansion,
    firstExpansion,
    900719925474099,
  );

  BigInt _scale(int base, (int, int) ratio, int expansion) {
    final exponent = expansion - 1;
    return _round(
      BigInt.from(base) * BigInt.from(ratio.$1).pow(exponent),
      BigInt.from(ratio.$2).pow(exponent),
    );
  }

  BigInt _round(BigInt numerator, BigInt denominator) =>
      (numerator + denominator ~/ BigInt.two) ~/ denominator;
}

class LevelDefinition {
  const LevelDefinition({
    required this.number,
    required this.activity,
    required this.objective,
    required this.production,
    required this.unitValue,
  });

  final int number;
  final Activity activity;
  final int objective;
  final Production? production;
  final BigInt? unitValue;

  bool get playable => production != null;
  bool get orchard => production?.capacity == Capacity.orchard;
  String get objectiveLabel =>
      orchard ? 'Pick $objective harvests' : 'Harvest $objective crops';
  Tool get prepare => orchard ? Tool.prune : Tool.plow;
  Tool get tend => orchard ? Tool.fertilize : Tool.plant;
  Tool get collect => orchard ? Tool.pick : Tool.harvest;
}
