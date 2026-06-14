// lib/widgets/download_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';

// ── Sheet de téléchargement ───────────────────────────────────────────────

Future<void> showDownloadSheet(
    BuildContext context, AudioTheme theme, Professor prof) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _DownloadSheet(theme: theme, prof: prof),
  );
}

class _DownloadSheet extends StatelessWidget {
  final AudioTheme theme;
  final Professor prof;
  const _DownloadSheet({required this.theme, required this.prof});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDownloading = provider.isThemeDownloading(theme);
    final dlState = provider.getDownloadState(theme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          const SizedBox(height: 16),
          _SheetHeader(
            theme: theme,
            prof: prof,
            icon: Icons.download_rounded,
            iconColor: kNavy,
          ),
          const SizedBox(height: 16),
          _StatsRow(theme: theme),
          const SizedBox(height: 20),

          // Barre de progression
          if (isDownloading && dlState != null) ...[
            _ProgressSection(
              dlState: dlState,
              label: 'Téléchargement en cours...',
            ),
            const SizedBox(height: 20),
          ],

          // Boutons
          if (isDownloading) ...[
            _ActionButton(
              label: 'Annuler le téléchargement',
              icon: Icons.cancel_outlined,
              color: Colors.red.shade700,
              onTap: () {
                provider.cancelDownload(theme);
                Navigator.pop(context);
              },
            ),
          ] else if (theme.isFullyDownloaded) ...[
            _InfoChip(
              label: 'Tous les audios sont déjà en local',
              icon: Icons.check_circle_outline,
              color: Colors.green.shade700,
            ),
            const SizedBox(height: 12),
            _ActionButton(
              label: 'Supprimer les audios locaux',
              icon: Icons.delete_outline,
              color: Colors.red.shade700,
              onTap: () async {
                Navigator.pop(context);
                await provider.deleteTheme(theme);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${theme.name} supprimé du stockage local'),
                    backgroundColor: kNavy,
                  ));
                }
              },
            ),
          ] else ...[
            // Info sur les audios bundled
            if (theme.bundledCount > 0) ...[
              _InfoChip(
                label:
                    '${theme.bundledCount} audio${theme.bundledCount > 1 ? 's' : ''} embarqué${theme.bundledCount > 1 ? 's' : ''} disponible${theme.bundledCount > 1 ? 's' : ''}',
                icon: Icons.inventory_2_outlined,
                color: Colors.blue.shade700,
              ),
              const SizedBox(height: 8),
            ],
            _ActionButton(
              label: theme.isPartiallyDownloaded
                  ? 'Continuer le téléchargement'
                  : 'Télécharger tous les audios',
              icon: Icons.download_rounded,
              color: kNavy,
              onTap: () {
                Navigator.pop(context);
                provider.downloadTheme(theme);
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sheet de rafraîchissement (delete-diff) ───────────────────────────────

Future<void> showRefreshSheet(
    BuildContext context, AudioTheme theme, Professor prof) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _RefreshSheet(theme: theme, prof: prof),
  );
}

class _RefreshSheet extends StatelessWidget {
  final AudioTheme theme;
  final Professor prof;
  const _RefreshSheet({required this.theme, required this.prof});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isRefreshing = provider.isThemeRefreshing(theme);
    final dlState = provider.getDownloadState(theme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          const SizedBox(height: 16),
          _SheetHeader(
            theme: theme,
            prof: prof,
            icon: Icons.sync_rounded,
            iconColor: Colors.green.shade700,
          ),
          const SizedBox(height: 12),

          // Explication de la règle delete-diff
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La synchronisation va :\n'
                    '• Supprimer les audios locaux absents du dépôt distant\n'
                    '• Télécharger les nouveaux audios manquants en local',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade800,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _StatsRow(theme: theme),
          const SizedBox(height: 20),

          // Barre de progression
          if (isRefreshing && dlState != null) ...[
            _ProgressSection(
              dlState: dlState,
              label: 'Synchronisation en cours...',
            ),
            const SizedBox(height: 20),
          ],

          // Boutons
          if (isRefreshing) ...[
            _ActionButton(
              label: 'Annuler la synchronisation',
              icon: Icons.cancel_outlined,
              color: Colors.red.shade700,
              onTap: () {
                provider.cancelDownload(theme);
                Navigator.pop(context);
              },
            ),
          ] else ...[
            _ActionButton(
              label: 'Synchroniser avec le dépôt',
              icon: Icons.sync_rounded,
              color: Colors.green.shade700,
              onTap: () {
                Navigator.pop(context);
                provider.refreshTheme(theme);
              },
            ),
            const SizedBox(height: 10),
            _ActionButton(
              label: 'Supprimer les audios locaux',
              icon: Icons.delete_outline,
              color: Colors.red.shade700,
              onTap: () async {
                Navigator.pop(context);
                await provider.deleteTheme(theme);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:
                        Text('${theme.name} supprimé du stockage local'),
                    backgroundColor: kNavy,
                  ));
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ── Composants partagés ───────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final AudioTheme theme;
  final Professor prof;
  final IconData icon;
  final Color iconColor;

  const _SheetHeader({
    required this.theme,
    required this.prof,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                theme.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kNavy,
                ),
              ),
              Text(
                prof.name,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final AudioTheme theme;
  const _StatsRow({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(
          icon: Icons.audiotrack,
          label:
              '${theme.tracks.length} audio${theme.tracks.length > 1 ? 's' : ''}',
          color: kNavy,
        ),
        if (theme.downloadedCount > 0)
          _StatChip(
            icon: Icons.download_done,
            label:
                '${theme.downloadedCount} local${theme.downloadedCount > 1 ? 'aux' : ''}',
            color: Colors.green.shade700,
          ),
        if (theme.bundledCount > 0)
          _StatChip(
            icon: Icons.inventory_2_outlined,
            label: '${theme.bundledCount} embarqué${theme.bundledCount > 1 ? 's' : ''}',
            color: Colors.blue.shade700,
          ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final DownloadState dlState;
  final String label;

  const _ProgressSection({required this.dlState, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              '${dlState.currentTrackIndex}/${dlState.totalTracks}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kNavy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: dlState.overallProgress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(kGold),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
