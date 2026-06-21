// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Verrouiller l'orientation en portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialiser just_audio_background (notification de lecture)
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Kaggu Xam Xam',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: const KagguXamXamApp(),
    ),
  );
}

class KagguXamXamApp extends StatelessWidget {
  const KagguXamXamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _SplashOrHome(),
    );
  }
}

class _SplashOrHome extends StatelessWidget {
  const _SplashOrHome();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    switch (provider.state) {
      case AppState.loading:
        return const _SplashScreen();
      case AppState.error:
        return _ErrorScreen(message: provider.errorMessage);
      case AppState.ready:
        return const HomeScreen();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/kxx_icon.png',
              width: 110,
              height: 110,
              errorBuilder: (_, __, ___) => Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kGold, width: 3),
                ),
                child: Center(
                  child: Text(
                    'K',
                    style: TextStyle(
                      color: kGold,
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppConstants.appCompany,
              style: TextStyle(
                color: kGoldLight,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: kGold,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Chargement de la bibliothèque…',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, color: kGold, size: 52),
              const SizedBox(height: 16),
              const Text(
                'Impossible de charger la bibliothèque',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<AppProvider>().init(),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kNavy,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
