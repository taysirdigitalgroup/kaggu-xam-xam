// lib/widgets/sidebar_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../screens/info_screen.dart';
import '../utils/app_theme.dart';
import '../utils/string_utils.dart';
import 'download_sheet.dart';

class SidebarDrawer extends StatelessWidget {
  const SidebarDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Drawer(
      width: 300,
      backgroundColor: kNavy,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Text(
                      'PROFESSEURS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.4),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  ...provider.professors.map((prof) => _ProfessorTile(prof: prof)),
                ],
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.1), height: 1),
            _InfoTile(),
          ],
        ),
      ),
    );
  }
}

class _ProfessorTile extends StatelessWidget {
  final Professor prof;
  const _ProfessorTile({required this.prof});

  @override
  Widget build(BuildContext context) {
    final provider   = context.watch<AppProvider>();
    final isExpanded = provider.expandedProfs.contains(prof.key);
    final isSelected = provider.selectedProfessor?.key == prof.key;

    return Column(
      children: [
        InkWell(
          onTap: () => provider.toggleProfExpand(prof.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: isSelected ? kGold.withOpacity(0.15) : Colors.transparent,
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: kGold, width: 2.5),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      prof.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: kNavy,
                        child: Center(
                          child: Text(
                            prof.name.length >= 2
                                ? prof.name.substring(0, 2).toUpperCase()
                                : prof.name.toUpperCase(),
                            style: TextStyle(
                              color: kGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Nom + Rôle — N thèmes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prof.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: prof.role,
                              style: TextStyle(
                                color: kGoldLight.withOpacity(0.85),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: '  —  ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.25),
                                fontSize: 10,
                              ),
                            ),
                            TextSpan(
                              text: '${prof.themes.length} thème${prof.themes.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down, color: kGoldLight, size: 20),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild:      const SizedBox.shrink(),
          secondChild:     _ThemesList(prof: prof),
          crossFadeState:  isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
        Divider(
          color: Colors.white.withOpacity(0.07),
          height: 1,
          indent: 14,
          endIndent: 14,
        ),
      ],
    );
  }
}

class _ThemesList extends StatelessWidget {
  final Professor prof;
  const _ThemesList({required this.prof});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Container(
      margin: const EdgeInsets.only(left: 74, bottom: 6),
      child: Column(
        children: prof.themes.map((theme) {
          final isSelected    = provider.selectedTheme?.name == theme.name &&
              provider.selectedProfessor?.key == prof.key;
          final isDownloading = provider.isThemeDownloading(theme);
          final isRefreshing  = provider.isThemeRefreshing(theme);

          return InkWell(
            onTap: () => _onThemeTap(context, provider, prof, theme),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected ? kGold.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? kGold : kGold.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      theme.name,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.72),
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _ThemeActionButton(
                    theme: theme, prof: prof,
                    isDownloading: isDownloading, isRefreshing: isRefreshing,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Gère le tap sur un thème :
  ///   1. Vérifie hors-ligne → dialog "Télécharger"
  ///   2. Vérifie reprise possible → dialog "Continuer ?"
  ///   3. Sinon → sélectionne directement
  Future<void> _onThemeTap(
    BuildContext context,
    AppProvider provider,
    Professor prof,
    AudioTheme theme,
  ) async {
    Navigator.pop(context); // fermer le drawer d'abord

    final result = await provider.selectTheme(prof, theme);

    if (result == null) return; // tout bon

    if (result == 'offline_theme') {
      if (context.mounted) _showOfflineThemeDialog(context, provider, theme, prof);
      return;
    }

    if (result.startsWith('resume:')) {
      final parts      = result.split(':');
      final trackIndex = int.tryParse(parts[1]) ?? 0;
      final positionMs = int.tryParse(parts[2]) ?? 0;
      if (context.mounted) {
        _showResumeDialog(context, provider, prof, theme, trackIndex, positionMs);
      }
    }
  }
}

// ── Dialogs ──────────────────────────────────────────────────────────────────

void _showOfflineThemeDialog(
  BuildContext context,
  AppProvider provider,
  AudioTheme theme,
  Professor prof,
) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(Icons.wifi_off_rounded, color: kNavy, size: 40),
      title: const Text(
        'Hors-ligne',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: Text(
        'Aucun audio de « ${theme.name} » n\'est disponible hors-ligne.\n\n'
        'Connectez-vous à internet ou téléchargez les audios pour les écouter sans connexion.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Fermer', style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            showDownloadSheet(ctx, theme, prof);
          },
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Télécharger'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    ),
  );
}

void _showResumeDialog(
  BuildContext context,
  AppProvider provider,
  Professor prof,
  AudioTheme theme,
  int trackIndex,
  int positionMs,
) {
  final trackName = trackIndex < theme.tracks.length
      ? formatAudioTitle(theme.tracks[trackIndex].filename)
      : 'Piste ${trackIndex + 1}';
  final pos = Duration(milliseconds: positionMs);
  final posStr = '${pos.inMinutes.toString().padLeft(2, '0')}:${(pos.inSeconds % 60).toString().padLeft(2, '0')}';

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(Icons.play_circle_outline_rounded, color: kNavy, size: 40),
      title: const Text(
        'Continuer la lecture ?',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            theme.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '« $trackName »',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'à $posStr',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            provider.startFresh(prof, theme);
          },
          child: Text('Depuis le début',
              style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            provider.confirmResume(prof, theme, trackIndex, positionMs);
          },
          icon: const Icon(Icons.play_arrow_rounded, size: 16),
          label: const Text('Reprendre'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    ),
  );
}

class _ThemeActionButton extends StatelessWidget {
  final AudioTheme theme;
  final Professor  prof;
  final bool       isDownloading;
  final bool       isRefreshing;

  const _ThemeActionButton({
    required this.theme,
    required this.prof,
    required this.isDownloading,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    if (theme.tracks.isEmpty) return const SizedBox.shrink();

    if (isDownloading || isRefreshing) {
      return SizedBox(
        width: 18, height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(kGold),
        ),
      );
    }

    if (theme.hasLocalDownloads) {
      return Tooltip(
        message: 'Synchroniser avec le dépôt',
        child: GestureDetector(
          onTap: () => showRefreshSheet(context, theme, prof),
          child: Icon(Icons.sync_rounded, color: Colors.green.shade400, size: 18),
        ),
      );
    }

    return Tooltip(
      message: theme.isBundledOnly
          ? 'Télécharger pour usage hors-ligne'
          : 'Télécharger les audios',
      child: GestureDetector(
        onTap: () => showDownloadSheet(context, theme, prof),
        child: Icon(
          Icons.download_rounded,
          color: theme.isBundledOnly ? kGold.withOpacity(0.6) : kGold,
          size: 18,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InfoScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
              child: Icon(Icons.info_outline, color: kGoldLight, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Infos & À propos',
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
