import 'dart:async';

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
  const ForwardGrowers({super.key});

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
    home: const FarmSession(),
  );
}

class FarmSession extends StatefulWidget {
  const FarmSession({super.key});

  @override
  State<FarmSession> createState() => _FarmSessionState();
}

class _FarmSessionState extends State<FarmSession> with WidgetsBindingObserver {
  final farm = Farm();
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    farm.addListener(syncClock);
  }

  void syncClock() {
    if (farm.phase == Phase.playing) {
      timer ??= Timer.periodic(const Duration(seconds: 1), (_) => farm.tick());
    } else {
      timer?.cancel();
      timer = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) farm.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    farm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: farm,
        builder: (context, _) => farm.phase == Phase.results
            ? ResultsScreen(farm: farm)
            : GameplayScreen(farm: farm),
      ),
    ),
  );
}
