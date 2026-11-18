import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'screens/history.dart';
import 'screens/home.dart';
import 'screens/measure.dart';
import 'screens/profile_form.dart';
import 'screens/settings.dart';
import 'services/screen_time.dart';
import 'services/storage.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (Store.onboarded && Store.breakAlerts) {
    unawaited(ScreenTime.start(name: Store.profile.name));
  }
  WebUsage.startTicking();
  runApp(const BiyoOdakApp());
}

class BiyoOdakApp extends StatelessWidget {
  const BiyoOdakApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, brightness: b),
          useMaterial3: true,
        );
    return MaterialApp(
      title: 'BiyoOdak',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const RootGate(),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});
  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  @override
  Widget build(BuildContext context) {
    if (!Store.onboarded) {
      return Scaffold(
        body: SafeArea(
          child: ProfileForm(firstRun: true, onDone: () => setState(() {})),
        ),
      );
    }
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;
  StreamSubscription<int>? webAlerts;

  @override
  void initState() {
    super.initState();
    webAlerts = WebUsage.alerts.listen((min) {
      if (!mounted) return;
      final msg = switch (min) {
        30 => '30 dakikadır ekrandasın 👀 Gözlerini 20 saniye uzağa odakla.',
        45 => '45 dakika oldu ⏳ Kalk, bir bardak su iç ve biraz esne.',
        _ => '1 saat doldu! 🛑 Telefonu bırakıp mola verme zamanı.',
      };
      showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
                title: const Text('Akıllı Mola Bildirimi'),
                content: Text(msg),
                actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tamam'))],
              ));
    });
  }

  @override
  void dispose() {
    webAlerts?.cancel();
    super.dispose();
  }

  Future<void> _openMeasure() async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const MeasureScreen()));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(key: ValueKey('home${Store.history.length}'), onMeasure: _openMeasure),
      const SizedBox.shrink(),
      HistoryScreen(key: ValueKey('hist${Store.history.length}')),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const DisclaimerBar(),
        NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) {
            if (i == 1) {
              _openMeasure();
              return;
            }
            setState(() => tab = i);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Ana Sayfa'),
            NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Ölçüm'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Geçmiş'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ayarlar'),
          ],
        ),
      ]),
    );
  }
}
