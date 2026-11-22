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

enum Capacity {
  field('Field plots', 'plot', 'Plot'),
  orchard('Apple trees', 'tree', 'Tree'),
  dairy('Cow stalls', 'cow stall', 'Cow'),
  chickens('Chicken nests', 'chicken nest', 'Nest'),
  sheep('Sheep spaces', 'sheep space', 'Sheep'),
  bees('Beehives', 'beehive', 'Hive'),
  tables('Order tables', 'table', 'Table');

  const Capacity(this.label, this.purchaseLabel, this.targetLabel);
  final String label;
  final String purchaseLabel;
  final String targetLabel;
}

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
  orchardWhistle('Orchard Whistle'),
  feed('Feed'),
  brush('Brush'),
  milk('Milk'),
  cleanNest('Clean Nest'),
  collectEggs('Collect Eggs'),
  shear('Shear'),
  plantFlowers('Plant Flowers'),
  smokeHive('Smoke Hive'),
  collectHoney('Collect Honey'),
  lasso('Lasso'),
  farmDog('Farm Dog'),
  shepherdsCrook('Shepherd’s Crook'),
  takeOrder('Take Order'),
  gather('Gather Products'),
  weigh('Weigh'),
  pack('Pack'),
  deliver('Deliver'),
  collectMoney('Collect Money'),
  broom('Broom'),
  tarp('Tarp');

  const Tool(this.label);
  final String label;
}

enum Stage { bare, prepared, tended, growing, ready }

typedef HazardRule = ({String label, Tool tool, Stage setback});
typedef Production = ({
  Duration growth,
  int value,
  Capacity capacity,
  (Tool, Tool, Tool, Tool) actions,
  HazardRule hazard,
});

enum Goods {
  wheat('Wheat'),
  corn('Corn'),
  carrots('Carrots'),
  apples('Apples'),
  milk('Milk'),
  eggs('Eggs'),
  wool('Wool'),
  honey('Honey');

  const Goods(this.label);
  final String label;
}

enum OrderSetback { loseProduct, rewind }

typedef OrderRules = ({
  int value,
  List<Tool> steps,
  List<List<Goods>> templates,
  ({String label, Tool tool}) hazard,
  OrderSetback setback,
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
  static const _producerCapacity = (start: 2, increment: 2, price: 35);
  static const _fieldActions = (
    Tool.plow,
    Tool.plant,
    Tool.water,
    Tool.harvest,
  );
  static const _capacities = {
    Capacity.field: (start: 4, increment: 4, price: 20),
    Capacity.orchard: (start: 2, increment: 2, price: 30),
    Capacity.dairy: _producerCapacity,
    Capacity.chickens: _producerCapacity,
    Capacity.sheep: _producerCapacity,
    Capacity.bees: _producerCapacity,
    Capacity.tables: (start: 1, increment: 1, price: 50),
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
      actions: _fieldActions,
      hazard: (label: 'Mole', tool: Tool.hammer, setback: Stage.bare),
    ),
    Activity.corn => (
      growth: const Duration(seconds: 5),
      value: 3,
      capacity: Capacity.field,
      actions: _fieldActions,
      hazard: (label: 'Crow', tool: Tool.noisemaker, setback: Stage.prepared),
    ),
    Activity.carrots => (
      growth: const Duration(seconds: 4),
      value: 3,
      capacity: Capacity.field,
      actions: _fieldActions,
      hazard: (label: 'Rabbit', tool: Tool.dogWhistle, setback: Stage.prepared),
    ),
    Activity.apples => (
      growth: const Duration(seconds: 5),
      value: 5,
      capacity: Capacity.orchard,
      actions: (Tool.prune, Tool.fertilize, Tool.water, Tool.pick),
      hazard: (
        label: 'Squirrel',
        tool: Tool.orchardWhistle,
        setback: Stage.bare,
      ),
    ),
    Activity.dairy => (
      growth: const Duration(seconds: 4),
      value: 6,
      capacity: Capacity.dairy,
      actions: (Tool.feed, Tool.water, Tool.brush, Tool.milk),
      hazard: (label: 'Loose cow', tool: Tool.lasso, setback: Stage.bare),
    ),
    Activity.chickens => (
      growth: const Duration(seconds: 4),
      value: 4,
      capacity: Capacity.chickens,
      actions: (Tool.feed, Tool.water, Tool.cleanNest, Tool.collectEggs),
      hazard: (label: 'Fox', tool: Tool.farmDog, setback: Stage.bare),
    ),
    Activity.sheep => (
      growth: const Duration(seconds: 5),
      value: 7,
      capacity: Capacity.sheep,
      actions: (Tool.feed, Tool.water, Tool.brush, Tool.shear),
      hazard: (
        label: 'Escaped sheep',
        tool: Tool.shepherdsCrook,
        setback: Stage.bare,
      ),
    ),
    Activity.bees => (
      growth: const Duration(seconds: 5),
      value: 6,
      capacity: Capacity.bees,
      actions: (
        Tool.plantFlowers,
        Tool.water,
        Tool.smokeHive,
        Tool.collectHoney,
      ),
      hazard: (label: 'Bear', tool: Tool.noisemaker, setback: Stage.bare),
    ),
    _ => null,
  };

  static const _market = (
    value: 8,
    steps: [
      Tool.takeOrder,
      Tool.gather,
      Tool.pack,
      Tool.deliver,
      Tool.collectMoney,
    ],
    templates: [
      [Goods.wheat, Goods.eggs],
      [Goods.corn, Goods.milk],
      [Goods.carrots, Goods.honey],
      [Goods.apples, Goods.wool],
    ],
    hazard: (label: 'Raccoon', tool: Tool.broom),
    setback: OrderSetback.loseProduct,
  );

  static const _fair = (
    value: 12,
    steps: [
      Tool.takeOrder,
      Tool.gather,
      Tool.weigh,
      Tool.pack,
      Tool.deliver,
      Tool.collectMoney,
    ],
    templates: [
      [Goods.wheat, Goods.carrots, Goods.eggs],
      [Goods.corn, Goods.apples, Goods.milk, Goods.honey],
      [Goods.wool, Goods.eggs, Goods.apples],
      [Goods.milk, Goods.wheat, Goods.carrots, Goods.wool],
      [Goods.apples, Goods.corn, Goods.honey, Goods.eggs],
    ],
    hazard: (label: 'Rain', tool: Tool.tarp),
    setback: OrderSetback.rewind,
  );

  OrderRules? orders(Activity activity) => switch (activity) {
    Activity.market => _market,
    Activity.fair => _fair,
    _ => null,
  };

  BigInt expansionPrice(int expansion) {
    _checkExpansion(expansion);
    return BigInt.from(100) * BigInt.two.pow(expansion - 1);
  }

  int firstLevel(int expansion) {
    _checkExpansion(expansion);
    return (expansion - 1) * Activity.values.length + 1;
  }

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
    final order = orders(activity);
    final value = work?.value ?? order?.value;
    return LevelDefinition(
      number: firstLevel(expansion) + activityNumber - 1,
      activity: activity,
      objective:
          baseTargets[activity.index] + objectiveGrowth * (expansion - 1),
      production: work,
      orders: order,
      unitValue: value == null
          ? null
          : _scale(value, _earningsScale, expansion),
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
    required this.orders,
    required this.unitValue,
  });

  final int number;
  final Activity activity;
  final int objective;
  final Production? production;
  final OrderRules? orders;
  final BigInt? unitValue;

  bool get playable => production != null || orders != null;
  Capacity get capacity => production?.capacity ?? Capacity.tables;
  ({String label, Tool tool}) get hazard {
    if (production case final work?) {
      return (label: work.hazard.label, tool: work.hazard.tool);
    }
    return orders!.hazard;
  }

  bool get orchard => production?.capacity == Capacity.orchard;
  bool get field => production?.capacity == Capacity.field;
  String get objectiveLabel => switch (activity) {
    Activity.apples => 'Pick $objective harvests',
    Activity.dairy => 'Collect milk $objective times',
    Activity.chickens => 'Collect $objective egg batches',
    Activity.sheep => 'Shear $objective times',
    Activity.bees => 'Collect $objective jars of honey',
    Activity.market || Activity.fair => 'Fill $objective orders',
    _ => 'Harvest $objective crops',
  };
  Tool get prepare => production!.actions.$1;
  Tool get tend => production!.actions.$2;
  Tool get beginProduction => production!.actions.$3;
  Tool get collect => orders?.steps.last ?? production!.actions.$4;
}
