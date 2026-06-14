// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/sidebar_drawer.dart';
import '../widgets/audio_track_list.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/banner_ad_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      drawer: const SidebarDrawer(),
      appBar: AppBar(
        backgroundColor: kNavy,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            // Icône app
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: kGold.withOpacity(0.6), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/kxx_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: kNavy,
                    child: Center(
                      child: Text(
                        'K',
                        style: TextStyle(
                          color: kGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (provider.selectedTheme != null)
                    Text(
                      '${provider.selectedTheme!.name} · ${provider.selectedProfessor?.name ?? ''}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        titleSpacing: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.7)),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Zone principale
          Expanded(
            child: provider.selectedTheme != null &&
                    provider.selectedProfessor != null
                ? AudioTrackList(
                    theme: provider.selectedTheme!,
                    prof: provider.selectedProfessor!,
                  )
                : _WelcomePane(),
          ),

          // Lecteur audio
          const AudioPlayerWidget(),

          // Bannière AdMob
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

class _WelcomePane extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/kxx_icon.png',
              width: 100,
              height: 100,
              errorBuilder: (_, __, ___) => Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: kNavy.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.library_music_rounded,
                  size: 52,
                  color: kNavy.withOpacity(0.4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: kNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ouvrez le menu ☰ et sélectionnez\nun professeur puis un thème',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (ctx) => OutlinedButton.icon(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                icon: Icon(Icons.menu_book_rounded, color: kNavy),
                label: Text(
                  'Parcourir la bibliothèque',
                  style: TextStyle(color: kNavy),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: kNavy.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
