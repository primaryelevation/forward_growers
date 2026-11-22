import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'balance.dart';
import 'game.dart';
import 'progress.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(ForwardGrowers(loadFarm: loadFarm));
}

Future<({Farm farm, String? notice})> loadFarm() async {
  const balance = GameBalance.standard;
  final directory = await getApplicationSupportDirectory();
  final file = File.fromUri(directory.uri.resolve('farm-v1.json'));
  final store = FileProgressStore(file);
  String? notice;
  FarmProgress? progress;
  try {
    progress = await store.load(balance);
  } on FormatException {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    await file.rename('${file.path}.invalid-$stamp');
    notice = 'The unreadable save was backed up. A new farm is ready.';
  }
  return (
    farm: Farm(
      progress: progress ?? FarmProgress.fresh(balance),
      store: store,
      clock: Stopwatch(),
    ),
    notice: notice,
  );
}

typedef FarmLoader = Future<({Farm farm, String? notice})> Function();

class ForwardGrowers extends StatelessWidget {
  const ForwardGrowers({super.key, required this.loadFarm});
  final FarmLoader loadFarm;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Forward Growers',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff31613d)),
      scaffoldBackgroundColor: grass,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xff245232),
          foregroundColor: Colors.white,
        ),
      ),
    ),
    home: FarmStartup(loader: loadFarm),
  );
}

class FarmStartup extends StatefulWidget {
  const FarmStartup({super.key, required this.loader});
  final FarmLoader loader;

  @override
  State<FarmStartup> createState() => _FarmStartupState();
}

class _FarmStartupState extends State<FarmStartup> {
  late var loading = widget.loader();

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: loading,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => setState(() => loading = widget.loader()),
              child: const Text('Could not open the farm. Retry'),
            ),
          ),
        );
      }
      final session = snapshot.data;
      if (session == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return FarmSession(farm: session.farm, notice: session.notice);
    },
  );
}

class FarmSession extends StatefulWidget {
  const FarmSession({
    super.key,
    required this.farm,
    this.notice,
    this.preview = false,
    this.densityPreview = false,
  });

  final Farm farm;
  final String? notice;
  final bool preview;
  final bool densityPreview;

  @override
  State<FarmSession> createState() => _FarmSessionState();
}

class _FarmSessionState extends State<FarmSession> with WidgetsBindingObserver {
  Farm get farm => widget.farm;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    farm.addListener(syncClock);
    syncClock();
  }

  void syncClock() {
    if (farm.phase == Phase.playing && !widget.densityPreview) {
      timer ??= Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => farm.tick(),
      );
    } else {
      timer?.cancel();
      timer = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !widget.densityPreview) {
      farm.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    farm.dispose();
    super.dispose();
  }

  void openPreview({required bool dense}) {
    if (!kDebugMode || farm.saving) return;
    final progress = FarmProgress.fresh(farm.balance);
    final preview = Farm(
      progress: dense
          ? progress
          : progress.copyWith(expansion: 2, completed: {1, 2, 3, 4}),
      store: _PreviewStore(),
      balance: farm.balance,
      clock: dense ? null : Stopwatch(),
    );
    if (dense) preview.startPreviewForDebug(16 * 16);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            FarmSession(farm: preview, preview: true, densityPreview: dense),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: farm,
        builder: (context, _) => farm.phase == Phase.map
            ? FarmMap(
                farm: farm,
                notice: widget.notice,
                onPreview: kDebugMode && !widget.preview
                    ? () => openPreview(dense: true)
                    : null,
                onExpansionPreview: kDebugMode && !widget.preview
                    ? () => openPreview(dense: false)
                    : null,
                onExitPreview: kDebugMode && widget.preview
                    ? () => Navigator.of(context).pop()
                    : null,
              )
            : GameplayScreen(
                farm: farm,
                onExitPreview: kDebugMode && widget.densityPreview
                    ? () => Navigator.of(context).pop()
                    : null,
              ),
      ),
    ),
  );
}

class _PreviewStore implements ProgressStore {
  @override
  Future<FarmProgress?> load(GameBalance balance) async => null;

  @override
  Future<void> save(FarmProgress progress) async {}
}
