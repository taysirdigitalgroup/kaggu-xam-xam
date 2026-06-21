// lib/widgets/sidebar_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../screens/info_screen.dart';
import '../utils/app_theme.dart';
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
                  ...provider.professors.map(
                    (prof) => _ProfessorTile(prof: prof),
                  ),
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
    final provider = context.watch<AppProvider>();
    final isExpanded = provider.expandedProfs.contains(prof.key);
    final isSelected = provider.selectedProfessor?.key == prof.key;

    return Column(
      children: [
        InkWell(
          onTap: () => provider.toggleProfExpand(prof.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? kGold.withOpacity(0.15)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
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
                            prof.name.substring(0, 2).toUpperCase(),
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
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: kGoldLight,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _ThemesList(prof: prof),
          crossFadeState: isExpanded
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
          final isSelected = provider.selectedTheme?.name == theme.name &&
              provider.selectedProfessor?.key == prof.key;
          final isDownloading = provider.isThemeDownloading(theme);
          final isRefreshing = provider.isThemeRefreshing(theme);

          return InkWell(
            onTap: () {
              // IMPORTANT : sélectionner le thème AVANT de fermer le drawer.
              // selectTheme() notifie immédiatement (affichage liste/lecteur)
              // puis charge l'audio en tâche de fond. Fermer le drawer
              // d'abord (comme avant) pouvait avaler ce premier
              // notifyListeners() pendant la transition de fermeture,
              // obligeant l'utilisateur à taper une 2ème fois pour voir
              // la page liste/lecteur apparaître.
              provider.selectTheme(prof, theme);
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected
                    ? kGold.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
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
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Bouton action : Rafraîchir / Télécharger / Badge
                  _ThemeActionButton(
                    theme: theme,
                    prof: prof,
                    isDownloading: isDownloading,
                    isRefreshing: isRefreshing,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Bouton icône contextuel à droite du nom de thème dans la sidebar
class _ThemeActionButton extends StatelessWidget {
  final AudioTheme theme;
  final Professor prof;
  final bool isDownloading;
  final bool isRefreshing;

  const _ThemeActionButton({
    required this.theme,
    required this.prof,
    required this.isDownloading,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    // Thème sans aucun audio (liste vide dans le JSON) → pas de bouton
    // télécharger/rafraîchir, rien à gérer pour ce thème.
    if (theme.tracks.isEmpty) {
      return const SizedBox.shrink();
    }

    // En cours de traitement → spinner
    if (isDownloading || isRefreshing) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(kGold),
        ),
      );
    }

    // Thème avec des audios locaux téléchargés → bouton Rafraîchir
    if (theme.hasLocalDownloads) {
      return Tooltip(
        message: 'Synchroniser avec le dépôt',
        child: GestureDetector(
          onTap: () => _onRefreshTap(context, provider),
          child: Icon(
            Icons.sync_rounded,
            color: Colors.green.shade400,
            size: 18,
          ),
        ),
      );
    }

    // Aucun audio local (peut être bundled ou rien) → bouton Télécharger
    // Afficher seulement si le thème n'est pas uniquement bundled
    // (si bundled, les assets embarqués suffisent mais on permet quand même le dl)
    return Tooltip(
      message: theme.isBundledOnly
          ? 'Télécharger pour usage hors-ligne amélioré'
          : 'Télécharger les audios',
      child: GestureDetector(
        onTap: () => _onDownloadTap(context, provider),
        child: Icon(
          Icons.download_rounded,
          color: theme.isBundledOnly
              ? kGold.withOpacity(0.6)
              : kGold,
          size: 18,
        ),
      ),
    );
  }

  void _onDownloadTap(BuildContext context, AppProvider provider) {
    showDownloadSheet(context, theme, prof);
  }

  void _onRefreshTap(BuildContext context, AppProvider provider) {
    showRefreshSheet(context, theme, prof);
  }
}

/// Badge d'état du thème (nombre de pistes / téléchargées)
class _ThemeBadge extends StatelessWidget {
  final AudioTheme theme;
  const _ThemeBadge({required this.theme});

  @override
  Widget build(BuildContext context) {
    final count = theme.tracks.length;
    final available = theme.availableOfflineCount;

    Color bg;
    String label;

    if (theme.isFullyAvailableOffline) {
      bg = Colors.green.shade700;
      label = '$count';
    } else if (available > 0) {
      bg = Colors.orange.shade700;
      label = '$available/$count';
    } else {
      bg = Colors.white.withOpacity(0.12);
      label = '$count';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
              child: Icon(Icons.info_outline, color: kGoldLight, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Infos & À propos',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
