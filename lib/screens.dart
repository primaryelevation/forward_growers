import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game.dart';

const grass = Color(0xff80ad61);
const cream = Color(0xfffff2d2);
const ink = Color(0xff263c28);
const gold = Color(0xffffca55);
const soil = Color(0xff805033);

class GameplayScreen extends StatelessWidget {
  const GameplayScreen({super.key, required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context) {
    final time = farm.remaining;
    final seconds = (time % 60).toString().padLeft(2, '0');
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
                    Expanded(child: HudItem('LEVEL', '${farm.level}')),
                    Expanded(
                      flex: 2,
                      child: HudItem(
                        'OBJECTIVE',
                        'Harvest ${farm.harvested} / ${farm.target}',
                      ),
                    ),
                    Expanded(child: HudItem('TIME', '${time ~/ 60}:$seconds')),
                    Expanded(child: HudItem('CASH', '\$${farm.cash}')),
                    IconButton(
                      tooltip: 'Pause',
                      onPressed: farm.pause,
                      icon: const Icon(Icons.pause_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ActionRail(
                      title: 'Seeds',
                      actions: [
                        for (final crop in Crop.values)
                          if (farm.owns(crop))
                            ActionTile(
                              farm: farm,
                              action: crop,
                              label: crop.label,
                              icon: cropIcon(crop),
                            ),
                      ],
                    ),
                    Expanded(child: PlotGrid(farm: farm)),
                    ActionRail(
                      title: 'Tools',
                      actions: [
                        for (final (action, label, icon) in const [
                          (Tool.plow, 'Plow', Icons.grass),
                          (Tool.water, 'Water', Icons.water_drop),
                          (Tool.harvest, 'Harvest', Icons.shopping_basket),
                          (Tool.hammer, 'Hammer', Icons.hardware),
                        ])
                          ActionTile(
                            farm: farm,
                            action: action,
                            label: label,
                            icon: icon,
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

IconData cropIcon(Crop crop) => crop == Crop.wheat ? Icons.grass : Icons.eco;

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
    width: 92,
    child: Material(
      color: cream,
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileHeight = ((constraints.maxHeight - 30) / actions.length)
              .clamp(44.0, 57.0);
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
  final Object action;
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

class PlotGrid extends StatelessWidget {
  const PlotGrid({super.key, required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context) {
    final plots = farm.plots;
    final columns = plots.length == 4 ? 2 : 3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: LayoutBuilder(
        builder: (context, box) {
          final width = math.min(620.0, box.maxWidth);
          final tileWidth = (width - (columns - 1) * 8) / columns;
          final tileHeight = (box.maxHeight - 8) / 2;
          return Center(
            child: SizedBox(
              width: width,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < plots.length; i++)
                    SizedBox(
                      width: tileWidth,
                      height: tileHeight,
                      child: PlotTile(
                        index: i,
                        plot: plots[i],
                        mole: farm.mole == i,
                        onTap: () => farm.tap(i),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PlotTile extends StatelessWidget {
  const PlotTile({
    super.key,
    required this.index,
    required this.plot,
    required this.mole,
    required this.onTap,
  });
  final int index;
  final Plot plot;
  final bool mole;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, icon, tint) = switch (plot.stage) {
      Stage.unplowed => ('Unplowed', Icons.landscape, const Color(0xffffdfac)),
      Stage.plowed => (
        'Plowed',
        Icons.reorder_rounded,
        const Color(0xffffdfac),
      ),
      Stage.seeded => (
        '${plot.crop!.label} seeded',
        Icons.more_horiz,
        const Color(0xffffdfac),
      ),
      Stage.growing => (
        '${plot.crop!.label} growing',
        Icons.water_drop,
        const Color(0xffa8e2ff),
      ),
      Stage.ready => ('${plot.crop!.label} ready', cropIcon(plot.crop!), gold),
    };
    return Semantics(
      label: 'Plot ${index + 1}',
      button: true,
      child: Material(
        color: plot.stage == Stage.unplowed ? soil : const Color(0xff603b2b),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: mole ? gold : const Color(0xffa5744e),
            width: 3,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: Furrows(plowed: plot.stage != Stage.unplowed),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      children: [
                        Icon(
                          mole ? Icons.pets : icon,
                          color: mole ? gold : tint,
                          size: 29,
                        ),
                        Text(
                          mole ? 'Mole! Use Hammer' : label,
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
    final (title, message, button, onPressed) = switch (farm.phase) {
      Phase.instructions => (
        'Forward Growers',
        'Plow, plant, water, and harvest 3 crops before time runs out. If a mole appears, select the hammer and tap it.',
        'Start Level 1',
        farm.resume,
      ),
      Phase.failed => (
        'Time’s up',
        'Harvested ${farm.harvested} / ${farm.target}. You keep the cash you earned.',
        'Retry Level ${farm.level}',
        farm.restart,
      ),
      _ => ('Paused', 'Your farm is waiting.', 'Resume', farm.resume),
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(dismissible: false, color: Color(0xaa273b27)),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                color: cream,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: onPressed, child: Text(button)),
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

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 940),
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: cream,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level ${farm.level} Complete',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              'Harvested ${farm.harvested} / ${farm.target}',
                            ),
                          ],
                        ),
                      ),
                      HudItem('CASH', '\$${farm.cash}'),
                      const SizedBox(width: 12),
                      HudItem('PLOTS', '${farm.plots.length} / 6'),
                    ],
                  ),
                ),
              ),
              if (farm.hasNext) ...[
                const SizedBox(height: 8),
                Text(
                  'Farm Shop',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                            ShopCard(
                              title: 'New plot',
                              icon: Icons.grid_view,
                              detail: 'One more growing plot',
                              button: farm.plots.length == 6
                                  ? 'Plot limit'
                                  : 'Buy · \$20',
                              onBuy: farm.canBuyPlot ? farm.buyPlot : null,
                            ),
                            const ShopCard(
                              title: 'Wheat',
                              icon: Icons.grass,
                              detail: 'Unlimited seeds',
                              button: 'Owned',
                            ),
                            ShopCard(
                              title: 'Corn',
                              icon: Icons.eco,
                              detail: 'Permanent seed unlock',
                              button: farm.owns(Crop.corn)
                                  ? 'Owned'
                                  : 'Buy · \$${Crop.corn.price}',
                              onBuy: farm.canBuyCrop(Crop.corn)
                                  ? () => farm.buyCrop(Crop.corn)
                                  : null,
                            ),
                            const ShopCard(
                              title: 'Carrots',
                              icon: Icons.lock_outline,
                              detail: 'Unlocks at Level 5',
                              button: 'Locked',
                            ),
                          ]
                          .map(
                            (card) => SizedBox(
                              width: box.maxWidth >= 520
                                  ? (box.maxWidth - 48) / 4
                                  : (box.maxWidth - 32) / 2,
                              child: card,
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Next objective · Harvest ${levels[farm.level]} crops',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                FilledButton(
                  onPressed: farm.restart,
                  child: Text('Play Level ${farm.level + 1}'),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Text(
                  'Prototype Complete',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class ShopCard extends StatelessWidget {
  const ShopCard({
    super.key,
    required this.title,
    required this.icon,
    required this.detail,
    required this.button,
    this.onBuy,
  });
  final String title;
  final IconData icon;
  final String detail;
  final String button;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) => Material(
    color: cream,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: ink),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          Text(detail, style: const TextStyle(fontSize: 12)),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onBuy, child: Text(button)),
          ),
        ],
      ),
    ),
  );
}
