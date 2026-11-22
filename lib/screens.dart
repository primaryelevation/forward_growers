import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'game.dart';

const grass = Color(0xff80ad61);
const cream = Color(0xfffff2d2);
const ink = Color(0xff263c28);
const gold = Color(0xffffca55);
const soil = Color(0xff805033);

class GameplayScreen extends StatelessWidget {
  const GameplayScreen({
    super.key,
    required this.farm,
    this.onPreview,
    this.onExitPreview,
  });
  final Farm farm;
  final VoidCallback? onPreview;
  final VoidCallback? onExitPreview;

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
                    if (onExitPreview != null)
                      TextButton.icon(
                        onPressed: onExitPreview,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Exit Preview'),
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
        if (farm.phase != Phase.playing)
          RoundOverlay(farm: farm, onPreview: onPreview),
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
    width: MediaQuery.sizeOf(context).width < 650 ? 80 : 92,
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

class PlotGrid extends StatefulWidget {
  const PlotGrid({super.key, required this.farm});
  final Farm farm;

  @override
  State<PlotGrid> createState() => _PlotGridState();
}

class _PlotGridState extends State<PlotGrid> {
  final _transform = TransformationController();
  final _pointers = <int>{};
  Offset? _tapOrigin;
  bool _isGesture = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farm = widget.farm;
    final plots = farm.plots;
    final columns = math.sqrt(plots.length).ceil();
    final rows = (plots.length / columns).ceil();
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
    if (index >= plots.length) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0x25325230),
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
      );
    }
    final mole = farm.mole == index;
    return PlotTile(
      key: ValueKey(index),
      index: index,
      plot: plots[index],
      mole: mole,
      ruined: mole && farm.moleRuined,
      dense: dense,
      onTap: () {
        if (!_isGesture) farm.tap(index);
      },
    );
  }
}

class PlotTile extends StatelessWidget {
  const PlotTile({
    super.key,
    required this.index,
    required this.plot,
    required this.mole,
    required this.ruined,
    required this.dense,
    required this.onTap,
  });
  final int index;
  final Plot plot;
  final bool mole;
  final bool ruined;
  final bool dense;
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
    final status = ruined
        ? 'Crop ruined · Hammer'
        : mole
        ? 'Mole threat · Hammer'
        : label;
    final moleColor = ruined ? const Color(0xffffa194) : gold;
    return Semantics(
      label: 'Plot ${index + 1}, $status',
      button: true,
      child: Material(
        color: ruined
            ? const Color(0xff733833)
            : switch (plot.stage) {
                Stage.unplowed => soil,
                Stage.growing => const Color(0xff426140),
                Stage.ready => const Color(0xff80602a),
                _ => const Color(0xff603b2b),
              },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dense ? 2 : 10),
          side: BorderSide(
            color: mole ? moleColor : const Color(0xffa5744e),
            width: dense ? 1 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!dense)
                CustomPaint(
                  painter: Furrows(plowed: plot.stage != Stage.unplowed),
                ),
              Center(
                child: Padding(
                  padding: EdgeInsets.all(dense ? 1 : 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      children: [
                        Icon(
                          ruined
                              ? Icons.warning_rounded
                              : mole
                              ? Icons.pets
                              : icon,
                          color: mole ? moleColor : tint,
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
  const RoundOverlay({super.key, required this.farm, this.onPreview});
  final Farm farm;
  final VoidCallback? onPreview;

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
                      if (kDebugMode && onPreview != null)
                        PreviewButton(onPressed: onPreview!),
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
  const ResultsScreen({super.key, required this.farm, this.onPreview});
  final Farm farm;
  final VoidCallback? onPreview;

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
                      HudItem('PLOTS', '${farm.plotCount} / $maxPlots'),
                    ],
                  ),
                ),
              ),
              if (!farm.hasNext) ...[
                const SizedBox(height: 8),
                Text(
                  'All $finalLevel Levels Complete',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
              const SizedBox(height: 8),
              Text('Farm Shop', style: Theme.of(context).textTheme.titleLarge),
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
                            button: farm.plotCount == maxPlots
                                ? 'Plot limit'
                                : 'Buy Plot · \$$plotPrice',
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
                            detail: 'Unavailable',
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
              if (farm.hasNext) ...[
                const SizedBox(height: 8),
                Text(
                  'Next objective · Harvest ${harvestTarget(farm.level + 1)} crops',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                FilledButton(
                  onPressed: farm.restart,
                  child: Text('Play Level ${farm.level + 1}'),
                ),
              ],
              if (kDebugMode && onPreview != null)
                PreviewButton(onPressed: onPreview!),
            ],
          ),
        ),
      ),
    ),
  );
}

class PreviewButton extends StatelessWidget {
  const PreviewButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    child: const Text('Preview 16 × 16 Field'),
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
