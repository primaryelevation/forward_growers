import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'balance.dart';
import 'game.dart';
import 'orders.dart';

const grass = Color(0xff80ad61);
const cream = Color(0xfffff2d2);
const ink = Color(0xff263c28);
const gold = Color(0xffffca55);
const soil = Color(0xff805033);

class GameplayScreen extends StatelessWidget {
  const GameplayScreen({super.key, required this.farm, this.onExitPreview});
  final Farm farm;
  final VoidCallback? onExitPreview;

  @override
  Widget build(BuildContext context) {
    final level = farm.level;
    final rule = level.hazard;
    final orderRules = level.orders;
    final time = farm.remaining;
    final hazard = farm.hazard;
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Material(
                color: cream,
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    Expanded(child: HudItem('LEVEL', '${level.number}')),
                    Expanded(
                      flex: 2,
                      child: HudItem(
                        'OBJECTIVE',
                        '${level.collect.label} ${farm.harvested} / ${level.objective}',
                      ),
                    ),
                    Expanded(flex: 2, child: HudItem('MODE', farm.mode.label)),
                    if (time != null)
                      Expanded(
                        child: HudItem(
                          'TIME',
                          '${time ~/ 60}:${(time % 60).toString().padLeft(2, '0')}',
                        ),
                      ),
                    Expanded(child: HudItem('CASH', '\$${farm.cash}')),
                    if (onExitPreview != null)
                      TextButton(
                        onPressed: onExitPreview,
                        child: const Text('Exit Preview'),
                      )
                    else
                      IconButton(
                        tooltip: 'Pause',
                        onPressed: farm.pause,
                        icon: const Icon(Icons.pause_rounded),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 24,
                child: Center(
                  child: Text(
                    farm.feedback ??
                        (hazard == null
                            ? ''
                            : '${rule.label} on ${level.capacity.targetLabel.toLowerCase()} ${hazard.index + 1} · Use ${rule.tool.label}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ActionRail(
                      title: orderRules != null
                          ? 'Orders'
                          : level.orchard
                          ? 'Orchard'
                          : level.field
                          ? 'Seeds'
                          : 'Supplies',
                      actions: [
                        if (orderRules != null) ...[
                          for (final tool in orderRules.steps.take(2))
                            ActionTile(
                              farm: farm,
                              action: tool,
                              label: tool.label,
                              icon: toolIcon(tool),
                            ),
                        ] else if (level.orchard)
                          const Center(child: Icon(Icons.park, color: ink))
                        else
                          ActionTile(
                            farm: farm,
                            action: level.field ? level.tend : level.prepare,
                            label: level.field
                                ? level.activity.label
                                : level.prepare.label,
                            icon: level.field
                                ? activityIcon(level.activity)
                                : toolIcon(level.prepare),
                          ),
                      ],
                    ),
                    Expanded(child: PlotGrid(farm: farm)),
                    ActionRail(
                      title: 'Tools',
                      actions: [
                        for (final tool in [
                          if (orderRules != null)
                            ...orderRules.steps.skip(2)
                          else ...[
                            if (level.field || level.orchard) level.prepare,
                            if (!level.field) level.tend,
                            level.beginProduction,
                            level.collect,
                          ],
                          rule.tool,
                        ])
                          ActionTile(
                            farm: farm,
                            action: tool,
                            label: tool.label,
                            icon: toolIcon(tool),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (farm.phase != Phase.playing) RoundOverlay(farm: farm),
      ],
    );
  }
}

IconData activityIcon(Activity activity) => switch (activity) {
  Activity.wheat => Icons.grass,
  Activity.corn => Icons.eco,
  Activity.carrots => Icons.local_florist,
  Activity.apples => Icons.park,
  Activity.dairy => Icons.warehouse,
  Activity.chickens => Icons.egg_alt,
  Activity.sheep => Icons.landscape,
  Activity.bees => Icons.hexagon,
  Activity.market => Icons.storefront,
  Activity.fair => Icons.celebration,
};

IconData toolIcon(Tool tool) => switch (tool) {
  Tool.plow => Icons.grass,
  Tool.prune => Icons.content_cut,
  Tool.plant || Tool.fertilize || Tool.plantFlowers => Icons.eco,
  Tool.water => Icons.water_drop,
  Tool.pick || Tool.harvest => Icons.shopping_basket,
  Tool.feed => Icons.restaurant,
  Tool.brush => Icons.brush,
  Tool.milk => Icons.local_drink,
  Tool.cleanNest => Icons.cleaning_services,
  Tool.collectEggs => Icons.egg_alt,
  Tool.shear => Icons.content_cut,
  Tool.smokeHive => Icons.air,
  Tool.collectHoney => Icons.hexagon,
  Tool.lasso => Icons.loop,
  Tool.farmDog => Icons.pets,
  Tool.shepherdsCrook => Icons.assistant_navigation,
  Tool.takeOrder => Icons.receipt_long,
  Tool.gather => Icons.shopping_basket,
  Tool.weigh => Icons.scale,
  Tool.pack => Icons.inventory_2,
  Tool.deliver => Icons.local_shipping,
  Tool.collectMoney => Icons.payments,
  Tool.broom => Icons.cleaning_services,
  Tool.tarp => Icons.umbrella,
  Tool.hammer => Icons.hardware,
  _ => Icons.campaign,
};

class HudItem extends StatelessWidget {
  const HudItem(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class ActionRail extends StatelessWidget {
  const ActionRail({super.key, required this.title, required this.actions});
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: MediaQuery.sizeOf(context).width < 650 ? 96 : 110,
    child: Material(
      color: cream,
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileHeight = ((constraints.maxHeight - 30) / actions.length)
              .clamp(36.0, 57.0);
          return ListView(
            padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              for (final action in actions)
                SizedBox(height: tileHeight, child: action),
            ],
          );
        },
      ),
    ),
  );
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.farm,
    required this.action,
    required this.label,
    required this.icon,
  });
  final Farm farm;
  final Tool action;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final selected = action == farm.selection;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        selected: selected,
        child: Material(
          color: selected ? const Color(0xff285333) : const Color(0xffe2ecc9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected ? gold : Colors.transparent,
              width: 3,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => farm.select(action),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: selected ? gold : ink),
                    const SizedBox(width: 3),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlotGrid extends StatefulWidget {
  const PlotGrid({super.key, required this.farm});
  final Farm farm;

  @override
  State<PlotGrid> createState() => _PlotGridState();
}

class _PlotGridState extends State<PlotGrid> {
  final _transform = TransformationController();
  final _viewport = GlobalKey();
  late final _cells = List.generate(widget.farm.spaceCount, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    widget.farm.targetVisible = _isVisible;
  }

  bool _isVisible(int index) {
    final viewport = _viewport.currentContext?.findRenderObject() as RenderBox?;
    final cell = _cells[index].currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null ||
        cell == null ||
        !viewport.hasSize ||
        !cell.hasSize) {
      return false;
    }
    final center = cell.localToGlobal(
      cell.size.center(Offset.zero),
      ancestor: viewport,
    );
    return (Offset.zero & viewport.size).contains(center);
  }

  final _pointers = <int>{};
  Offset? _tapOrigin;
  bool _isGesture = false;

  @override
  void dispose() {
    widget.farm.targetVisible = null;
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farm = widget.farm;
    final plots = farm.plots;
    final count = farm.spaceCount;
    final columns = math.sqrt(count).ceil();
    final rows = (count / columns).ceil();
    final dense = columns >= 8;
    final gap = dense
        ? 1.5
        : columns >= 4
        ? 4.0
        : 8.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ClipRect(
        child: Stack(
          key: _viewport,
          fit: StackFit.expand,
          children: [
            Listener(
              onPointerDown: (event) {
                if (_pointers.isEmpty) {
                  _tapOrigin = event.position;
                  _isGesture = false;
                } else {
                  _isGesture = true;
                }
                _pointers.add(event.pointer);
              },
              onPointerMove: (event) {
                if ((event.position - _tapOrigin!).distance > 8) {
                  _isGesture = true;
                }
              },
              onPointerUp: (event) => _pointers.remove(event.pointer),
              onPointerCancel: (event) {
                _isGesture = true;
                _pointers.remove(event.pointer);
              },
              child: InteractiveViewer(
                transformationController: _transform,
                maxScale: 8,
                child: Column(
                  children: [
                    for (var row = 0; row < rows; row++) ...[
                      if (row > 0) SizedBox(height: gap),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (
                              var column = 0;
                              column < columns;
                              column++
                            ) ...[
                              if (column > 0) SizedBox(width: gap),
                              Expanded(
                                child: _cell(
                                  farm,
                                  plots,
                                  row * columns + column,
                                  dense,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: ValueListenableBuilder(
                valueListenable: _transform,
                builder: (context, matrix, _) {
                  if (matrix.isIdentity()) return const SizedBox.shrink();
                  return FilledButton(
                    onPressed: () => _transform.value = Matrix4.identity(),
                    child: const Text('Full Field'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(Farm farm, List<Plot> plots, int index, bool dense) {
    if (index >= farm.spaceCount) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0x25325230),
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
      );
    }
    void tap() {
      if (!_isGesture) farm.tap(index);
    }

    if (farm.level.orders case final rules?) {
      return OrderTile(
        key: _cells[index],
        index: index,
        order: farm.orderAt(index),
        rules: rules,
        hazard: farm.hazard?.index == index,
        onTap: tap,
      );
    }
    return PlotTile(
      key: _cells[index],
      index: index,
      plot: plots[index],
      level: farm.level,
      hazard: farm.hazard?.index == index,
      dense: dense,
      onTap: tap,
    );
  }
}

class OrderTile extends StatelessWidget {
  const OrderTile({
    super.key,
    required this.index,
    required this.order,
    required this.rules,
    required this.hazard,
    required this.onTap,
  });

  final int index;
  final TableOrder? order;
  final OrderRules rules;
  final bool hazard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = order;
    final next = current?.next(rules) ?? rules.steps.first;
    return Material(
      color: hazard ? const Color(0xff833a29) : cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: hazard ? gold : ink, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: DefaultTextStyle(
                style: TextStyle(
                  color: hazard ? Colors.white : ink,
                  fontSize: 14,
                ),
                child: Column(
                  children: [
                    Text(
                      'Table ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (hazard)
                      Text(
                        '${rules.hazard.label} · Use ${rules.hazard.tool.label}',
                      ),
                    Text(
                      'Next: ${next.label}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (current != null)
                      for (var i = 0; i < current.products.length; i++)
                        Text(
                          '${i < current.gathered ? '✓' : '○'} ${current.products[i].label}',
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlotTile extends StatelessWidget {
  const PlotTile({
    super.key,
    required this.index,
    required this.plot,
    required this.level,
    required this.hazard,
    required this.dense,
    required this.onTap,
  });

  final int index;
  final Plot plot;
  final LevelDefinition level;
  final bool hazard;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final orchard = level.orchard;
    final (label, icon, tint) = !level.field && !orchard
        ? switch (plot.stage) {
            Stage.bare => (
              'Next: ${level.prepare.label}',
              activityIcon(level.activity),
              cream,
            ),
            Stage.prepared => (
              'Next: ${level.tend.label}',
              toolIcon(level.tend),
              cream,
            ),
            Stage.tended => (
              'Next: ${level.beginProduction.label}',
              toolIcon(level.beginProduction),
              cream,
            ),
            Stage.growing => (
              'Producing…',
              Icons.hourglass_top,
              const Color(0xffa8e2ff),
            ),
            Stage.ready => (
              'Ready: ${level.collect.label}',
              toolIcon(level.collect),
              gold,
            ),
          }
        : switch (plot.stage) {
            Stage.bare => (
              orchard ? 'Needs pruning' : 'Unplowed',
              orchard ? Icons.park : Icons.landscape,
              cream,
            ),
            Stage.prepared => (
              orchard ? 'Pruned' : 'Plowed',
              orchard ? Icons.content_cut : Icons.reorder,
              cream,
            ),
            Stage.tended => (
              orchard ? 'Fertilized' : 'Planted',
              Icons.eco,
              cream,
            ),
            Stage.growing => (
              'Growing',
              Icons.water_drop,
              const Color(0xffa8e2ff),
            ),
            Stage.ready => (
              orchard ? 'Ready to pick' : 'Ready to harvest',
              orchard ? Icons.circle : activityIcon(level.activity),
              gold,
            ),
          };
    final idleColor = switch (level.capacity) {
      Capacity.field => soil,
      Capacity.orchard => const Color(0xff325533),
      Capacity.dairy => const Color(0xff714c49),
      Capacity.chickens => const Color(0xff754b2b),
      Capacity.sheep => const Color(0xff3e5e51),
      Capacity.bees => const Color(0xff675221),
      Capacity.tables => ink,
    };
    final rule = level.production!.hazard;
    final status = hazard ? '${rule.label} · ${rule.tool.label}' : label;
    return Semantics(
      label: '${level.capacity.targetLabel} ${index + 1}, $status',
      button: true,
      child: Material(
        color: hazard
            ? const Color(0xff833a29)
            : switch (plot.stage) {
                Stage.bare => idleColor,
                Stage.growing => const Color(0xff426140),
                Stage.ready => const Color(0xff80602a),
                _ => level.field ? const Color(0xff603b2b) : idleColor,
              },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dense ? 2 : 10),
          side: BorderSide(
            color: hazard ? gold : const Color(0xffa5744e),
            width: dense ? 1 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!dense && level.field)
                CustomPaint(painter: Furrows(plowed: plot.stage != Stage.bare)),
              Center(
                child: Padding(
                  padding: EdgeInsets.all(dense ? 1 : 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      children: [
                        Icon(
                          hazard ? Icons.warning_rounded : icon,
                          color: hazard ? gold : tint,
                          size: 29,
                        ),
                        if (!dense)
                          Text(
                            status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Furrows extends CustomPainter {
  const Furrows({required this.plowed});
  final bool plowed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x24eec589)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (plowed) {
      for (var i = 1; i < 5; i++) {
        final y = size.height * i / 5;
        canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), paint);
      }
    } else {
      for (var i = 1; i < 8; i++) {
        canvas.drawCircle(
          Offset(size.width * i / 8, size.height * (i.isEven ? .25 : .74)),
          2,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(Furrows oldDelegate) => oldDelegate.plowed != plowed;
}

class RoundOverlay extends StatelessWidget {
  const RoundOverlay({super.key, required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context) {
    final paused = farm.phase == Phase.paused;
    final level = farm.level;
    final result = paused ? null : farm.result;
    final timeExpired = result?.completed == false;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(dismissible: false, color: Color(0xaa273b27)),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: 450,
              child: Card(
                color: cream,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        paused
                            ? 'Paused'
                            : timeExpired
                            ? 'Time expired'
                            : 'Objective completed',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text('Level ${level.number} · ${level.activity.label}'),
                      if (result != null) ...[
                        Text(
                          '${level.collect.label} ${farm.harvested} / ${level.objective}',
                        ),
                        if (result.awardedRibbon)
                          const Text(
                            'Blue Ribbon awarded!',
                            style: TextStyle(
                              color: Color(0xff155398),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        Text('Product earnings: \$${result.earnings}'),
                        if (farm.mode == Mode.timed)
                          Text(
                            timeExpired
                                ? 'No completion bonus'
                                : 'Timed bonus: \$${result.bonus}',
                          ),
                        Text(
                          'Attempt total: \$${result.earnings + result.bonus} · Wallet: \$${farm.cash}',
                        ),
                        Text(
                          timeExpired
                              ? (result.replay
                                    ? 'Previous completion retained'
                                    : 'Level remains incomplete')
                              : result.replay
                              ? 'Replay completed'
                              : 'First completion',
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (paused)
                            FilledButton(
                              onPressed: farm.resume,
                              child: const Text('Resume'),
                            ),
                          FilledButton(
                            onPressed: farm.saving ? null : farm.returnToMap,
                            child: Text(paused ? 'Leave Attempt' : 'Continue'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FarmMap extends StatefulWidget {
  const FarmMap({
    super.key,
    required this.farm,
    this.onPreview,
    this.onExpansionPreview,
    this.onExitPreview,
    this.notice,
  });

  final Farm farm;
  final VoidCallback? onPreview;
  final VoidCallback? onExpansionPreview;
  final VoidCallback? onExitPreview;
  final String? notice;

  @override
  State<FarmMap> createState() => _FarmMapState();
}

class _FarmMapState extends State<FarmMap> {
  Activity? _selected;
  int? _viewedExpansion;

  @override
  Widget build(BuildContext context) {
    final farm = widget.farm;
    final expansion = _viewedExpansion ?? farm.progress.expansion;
    final selected =
        _selected ?? Activity.values[farm.progress.unlockedIn(expansion) - 1];
    final level = farm.definition(selected, expansion: expansion);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Farm Map · Expansion $expansion',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (farm.progress.expansion > GameBalance.firstExpansion)
                PopupMenuButton<int>(
                  tooltip: 'Choose Expansion',
                  icon: const Icon(Icons.map_outlined),
                  onSelected: (number) => setState(() {
                    _viewedExpansion = number == farm.progress.expansion
                        ? null
                        : number;
                    _selected = null;
                  }),
                  itemBuilder: (context) => [
                    for (
                      var number = GameBalance.firstExpansion;
                      number <= farm.progress.expansion;
                      number++
                    )
                      PopupMenuItem(
                        value: number,
                        child: Text('Expansion $number'),
                      ),
                  ],
                ),
              if (farm.progress.hasBlueRibbon)
                const Tooltip(
                  message: 'Blue Ribbon',
                  child: Icon(
                    Icons.workspace_premium,
                    color: Color(0xff144f94),
                  ),
                ),
              TextButton(
                onPressed: farm.saving ? null : () => _showExpansionOffer(farm),
                child: const Text('Expand'),
              ),
              Flexible(
                child: Text(
                  'Wallet \$${farm.cash}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<Mode>(
                value: farm.mode,
                onChanged: farm.saving
                    ? null
                    : (mode) {
                        if (mode != null) farm.setMode(mode);
                      },
                items: [
                  for (final mode in Mode.values)
                    DropdownMenuItem(value: mode, child: Text(mode.label)),
                ],
              ),
            ],
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: LayoutBuilder(
                    builder: (context, box) => GridView(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: math.max(39, (box.maxHeight - 20) / 5),
                        crossAxisSpacing: 5,
                        mainAxisSpacing: 5,
                      ),
                      children: [
                        for (final activity in Activity.values)
                          _location(
                            farm,
                            activity,
                            selected == activity,
                            expansion,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Material(
                    color: cream,
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Level ${level.number}',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                Text(
                                  selected.label,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                if (level.playable) ...[
                                  Text(level.objectiveLabel),
                                  Text(farm.mode.label),
                                  Text(
                                    farm.isComplete(
                                          selected,
                                          expansion: expansion,
                                        )
                                        ? 'Completed'
                                        : farm.canPlay(
                                            selected,
                                            expansion: expansion,
                                          )
                                        ? 'Available'
                                        : 'Complete the previous activity to unlock',
                                  ),
                                  if (farm.canPlay(
                                    selected,
                                    expansion: expansion,
                                  )) ...[
                                    _capacityPanel(farm, level.capacity),
                                  ],
                                ] else
                                  const Text(
                                    'This activity is not yet available.',
                                  ),
                                if (farm.feedback case final message?)
                                  Text(message),
                                if (widget.notice case final notice?)
                                  Text(notice),
                                if (kDebugMode) ...[
                                  if (widget.onExitPreview case final exit?)
                                    TextButton(
                                      onPressed: exit,
                                      child: const Text('Exit Debug Expansion'),
                                    )
                                  else ...[
                                    if (widget.onPreview case final preview?)
                                      TextButton(
                                        onPressed: preview,
                                        child: const Text(
                                          'Preview 16 × 16 Field',
                                        ),
                                      ),
                                    if (widget.onExpansionPreview
                                        case final preview?)
                                      TextButton(
                                        onPressed: preview,
                                        child: const Text(
                                          'Preview Expansion 2',
                                        ),
                                      ),
                                    TextButton(
                                      onPressed: farm.saving
                                          ? null
                                          : () async {
                                              final reset =
                                                  await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                          title: const Text(
                                                            'Reset saved farm?',
                                                          ),
                                                          content: const Text(
                                                            'This clears the wallet, purchases, and completed levels.',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    false,
                                                                  ),
                                                              child: const Text(
                                                                'Cancel',
                                                              ),
                                                            ),
                                                            FilledButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    true,
                                                                  ),
                                                              child: const Text(
                                                                'Reset',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                  );
                                              if (reset == true && mounted) {
                                                await farm.resetForDebug();
                                                if (mounted) {
                                                  setState(
                                                    () => _selected = null,
                                                  );
                                                }
                                              }
                                            },
                                      child: const Text('Reset Save (Debug)'),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (farm.canPlay(selected, expansion: expansion))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: FilledButton(
                              onPressed: farm.saving
                                  ? null
                                  : () => farm.start(
                                      selected,
                                      expansion: expansion,
                                    ),
                              child: Text(
                                farm.isComplete(selected, expansion: expansion)
                                    ? 'Replay'
                                    : 'Play',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExpansionOffer(Farm farm) async {
    final current = farm.progress.expansion;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Expansion ${current + 1}'),
        content: Text(
          'Price: \$${farm.nextExpansionPrice}\n'
          'Unlock requirements: Blue Ribbon and enough money.\n'
          '${farm.progress.hasBlueRibbon ? 'Blue Ribbon earned' : 'Earn the ribbon at County Fair'}'
          ' · Wallet \$${farm.cash}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: farm.canExpand
                ? () => Navigator.pop(context, true)
                : null,
            child: const Text('Buy Expansion'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await farm.buyNextExpansion(current);
    if (mounted && farm.progress.expansion != current) {
      setState(() {
        _selected = null;
        _viewedExpansion = null;
      });
    }
  }

  Widget _location(Farm farm, Activity activity, bool selected, int expansion) {
    final status = farm.isComplete(activity, expansion: expansion)
        ? 'Completed'
        : farm.canPlay(activity, expansion: expansion)
        ? 'Available'
        : !farm.definition(activity, expansion: expansion).playable
        ? 'Unavailable'
        : 'Locked';
    return Material(
      color: selected ? cream : const Color(0xffcee2a8),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selected = activity),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              Icon(activityIcon(activity), color: ink, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(status, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _capacityPanel(Farm farm, Capacity kind) {
    final count = farm.progress.capacity(kind);
    final limit = farm.capacityLimit(kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${kind.label}: $count / $limit'),
        OutlinedButton(
          onPressed: farm.canBuy(kind) ? () => farm.buy(kind) : null,
          child: Text(
            count >= limit
                ? 'Capacity reached'
                : 'Buy ${kind.purchaseLabel} · \$${farm.price(kind)}',
          ),
        ),
      ],
    );
  }
}
