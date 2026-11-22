import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ForwardGrowers());
}

class ForwardGrowers extends StatelessWidget {
  const ForwardGrowers({super.key, this.roundClock});
  final Stopwatch? roundClock;

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
    home: FarmSession(roundClock: roundClock),
  );
}

class FarmSession extends StatefulWidget {
  const FarmSession({super.key, this.preview = false, this.roundClock});

  final bool preview;
  final Stopwatch? roundClock;

  @override
  State<FarmSession> createState() => _FarmSessionState();
}

class _FarmSessionState extends State<FarmSession> with WidgetsBindingObserver {
  late final Farm farm;
  Timer? timer;
  bool get isPreview => kDebugMode && widget.preview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    farm = isPreview
        ? Farm.preview()
        : Farm.timed(widget.roundClock ?? Stopwatch());
    if (!isPreview) farm.addListener(syncClock);
  }

  void syncClock() {
    if (farm.phase == Phase.playing) {
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
    if (!isPreview && state != AppLifecycleState.resumed) farm.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    farm.dispose();
    super.dispose();
  }

  void openPreview() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FarmSession(preview: true)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: farm,
        builder: (context, _) => farm.phase == Phase.results
            ? ResultsScreen(
                farm: farm,
                onPreview: kDebugMode ? openPreview : null,
              )
            : GameplayScreen(
                farm: farm,
                onPreview: kDebugMode && !isPreview ? openPreview : null,
                onExitPreview: isPreview
                    ? () => Navigator.of(context).pop()
                    : null,
              ),
      ),
    ),
  );
}
