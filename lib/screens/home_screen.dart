// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/playback_persistence_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/string_utils.dart';
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
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kGold.withOpacity(0.6), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/kxx_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: kNavy,
                    child: Center(
                      child: Text('K',
                          style: TextStyle(color: kGold,
                              fontWeight: FontWeight.bold, fontSize: 16)),
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
                  const Text(AppConstants.appName,
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w600, color: Colors.white)),
                  if (provider.selectedTheme != null)
                    Text(
                      '${provider.selectedTheme!.name} · ${provider.selectedProfessor?.name ?? ''}',
                      style: TextStyle(fontSize: 10,
                          color: Colors.white.withOpacity(0.55)),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
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
          Expanded(
            child: provider.selectedTheme != null &&
                    provider.selectedProfessor != null
                ? AudioTrackList(
                    theme: provider.selectedTheme!,
                    prof:  provider.selectedProfessor!,
                  )
                : const _WelcomePane(),
          ),
          const AudioPlayerWidget(),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

// ── Écran d'accueil ──────────────────────────────────────────────────────────

class _WelcomePane extends StatelessWidget {
  const _WelcomePane();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final last     = provider.lastPlaybackState;
    final hasResume = last != null && !last.completed;

    return Column(
      children: [
        // Partie centrale scrollable
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
            child: Column(
              children: [
                // Logo
                Image.asset(
                  'assets/images/kxx_icon.png',
                  width: 90, height: 90,
                  errorBuilder: (_, __, ___) => Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      color: kNavy.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.library_music_rounded,
                        size: 48, color: kNavy.withOpacity(0.4)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppConstants.appName,
                    style: TextStyle(fontSize: 22,
                        fontWeight: FontWeight.w800, color: kNavy)),
                const SizedBox(height: 8),
                Text(
                  'Ouvrez le menu ☰ et sélectionnez\nun professeur puis un thème',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13,
                      color: Colors.grey.shade500, height: 1.5),
                ),
                const SizedBox(height: 20),

                // Bouton Parcourir
                Builder(
                  builder: (ctx) => OutlinedButton.icon(
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    icon: Icon(Icons.menu_book_rounded, color: kNavy),
                    label: Text('Parcourir la bibliothèque',
                        style: TextStyle(color: kNavy)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: kNavy.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                // Bloc Reprendre (uniquement si lecture non terminée)
                if (hasResume) ...[
                  const SizedBox(height: 24),
                  _ResumeCard(last: last),
                ],
              ],
            ),
          ),
        ),

        // Copyright — toujours en bas, hors du scroll
        const _CopyrightBlock(),
      ],
    );
  }
}

// ── Bloc Reprendre ────────────────────────────────────────────────────────────

class _ResumeCard extends StatelessWidget {
  final PlaybackState last;
  const _ResumeCard({required this.last});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final pos      = Duration(milliseconds: last.positionMs);
    final posStr   =
        '${pos.inMinutes.toString().padLeft(2, '0')}:${(pos.inSeconds % 60).toString().padLeft(2, '0')}';

    Professor? prof;
    AudioTheme? theme;
    for (final p in provider.professors) {
      if (p.key == last.profKey) {
        prof = p;
        for (final t in p.themes) {
          if (t.name == last.themeName) { theme = t; break; }
        }
        break;
      }
    }

    final trackName = (theme != null && last.trackIndex < theme.tracks.length)
        ? formatAudioTitle(theme.tracks[last.trackIndex].filename)
        : 'Piste ${last.trackIndex + 1}';

    return Container(
      decoration: BoxDecoration(
        color: kNavy.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNavy.withOpacity(0.12)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 14,
                  color: kNavy.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text('Reprendre la lecture',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: kNavy.withOpacity(0.55), letterSpacing: 0.5,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (prof != null)
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: kGold, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset(prof.imagePath, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: kNavy,
                        child: Center(child: Text(
                          prof!.name.substring(0, 2).toUpperCase(),
                          style: TextStyle(color: kGold,
                              fontWeight: FontWeight.bold, fontSize: 12),
                        )),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(last.themeName,
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w700, color: kNavy)),
                    const SizedBox(height: 2),
                    Text(last.profName,
                        style: TextStyle(fontSize: 11,
                            color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    Text('« $trackName »  ·  $posStr',
                        style: TextStyle(fontSize: 11,
                            color: Colors.grey.shade600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (prof != null && theme != null) {
                  provider.confirmResume(
                      prof, theme!, last.trackIndex, last.positionMs);
                }
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text('Reprendre à $posStr'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Copyright — toujours en bas ───────────────────────────────────────────────

class _CopyrightBlock extends StatelessWidget {
  const _CopyrightBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Icon(Icons.copyright_rounded, size: 14, color: Colors.grey.shade400),
          const SizedBox(height: 4),
          Text('© 2026 Taysir Digital Group (TDG)',
              style: TextStyle(fontSize: 11,
                  color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
          Text('Tous droits réservés',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade300)),
        ],
      ),
    );
  }
}
