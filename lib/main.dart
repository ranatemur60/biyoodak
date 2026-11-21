import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'screens/history.dart';
import 'screens/home.dart';
import 'screens/measure_center.dart';
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
    unawaited(ScreenTime.start(name: Store.profile.name, student: Store.profile.isStudent, exam: Store.profile.examName));
  }
  WebUsage.startTicking();
  runApp(const NeuroVibeApp());
}

class NeuroVibeApp extends StatelessWidget {
  const NeuroVibeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: kPrimary, brightness: Brightness.light)
        .copyWith(primary: kPrimary, surface: Colors.white, onSurface: kNavy);
    return MaterialApp(
      title: 'NeuroVibe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: kNavy,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleTextStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kNavy)),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kPrimary,
            minimumSize: const Size.fromHeight(60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kPrimary,
            minimumSize: const Size.fromHeight(56),
            side: const BorderSide(color: Color(0xFF8A8799), width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFEAE4FF),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

/// Açılış ekranı: beyin, kalp ritmi çizgisi ve "Uygulamaya Gir".
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget ring(double size, double alpha, Widget? child) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kPrimary.withValues(alpha: alpha)),
          alignment: Alignment.center,
          child: child,
        );
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            const Spacer(flex: 3),
            Stack(alignment: Alignment.center, children: [
              ring(250, 0.03, ring(200, 0.05, ring(150, 0.08, const Text('🧠', style: TextStyle(fontSize: 96))))),
              const Positioned(bottom: 6, child: EcgLine(width: 270)),
            ]),
            const SizedBox(height: 36),
            const Text('NeuroVibe',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: kNavy)),
            const SizedBox(height: 12),
            const Text('Bilişsel Yorgunluk Karnesi\nGöz • Nabız • Dikkat',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, height: 1.5, fontWeight: FontWeight.w600, color: kMuted)),
            const Spacer(flex: 3),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(builder: (_) => const RootGate())),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Uygulamaya Gir'),
            ),
            const SizedBox(height: 16),
            const Text('Araştırma prototipi • Tıbbi tanı aracı değildir.',
                style: TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 16),
          ]),
        ),
      ),
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
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int tab = 0;
  StreamSubscription<int>? webAlerts;

  @override
  void initState() {
    super.initState();
    webAlerts = WebUsage.alerts.listen((min) {
      if (!mounted) return;
      final st = Store.profile.isStudent;
      final msg = st
          ? switch (min) {
              30 => '30 dakikadır telefondasın 📚 Bu yaklaşık 1 ders saati demek. Kitabına dönmeye ne dersin?',
              45 => '45 dakika oldu ⏱️ Bu sürede bir Pomodoro bloğu yapabilirdin: 25 dk ders + 5 dk mola. Hemen başlayalım mı?',
              _ => '1 saat doldu! 🛑 Telefonu kenara koy ve 30 dakika ders çalış.',
            }
          : switch (min) {
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

  void go(int i) => setState(() => tab = i);
  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final n = Store.history.length;
    final pages = [
      HomeScreen(key: ValueKey('home$n'), shell: this),
      MeasureCenterScreen(shell: this),
      HistoryScreen(key: ValueKey('hist$n')),
      SettingsScreen(key: ValueKey('set$n')),
    ];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Ana Sayfa'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Ölçüm'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Geçmiş'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Ayarlar'),
        ],
      ),
    );
  }
}
