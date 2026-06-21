// lib/widgets/audio_track_list.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/string_utils.dart';
import 'download_sheet.dart';

class AudioTrackList extends StatelessWidget {
  final AudioTheme theme;
  final Professor prof;

  const AudioTrackList({
    super.key,
    required this.theme,
    required this.prof,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDownloading = provider.isThemeDownloading(theme);
    final dlState = provider.getDownloadState(theme);

    return Column(
      children: [
        // Header du thème avec bouton download
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Info thème
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kNavy,
                      ),
                    ),
                    Text(
                      prof.name,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              // Bouton téléchargement (masqué si le thème n'a aucun audio)
              if (theme.tracks.isEmpty)
                const SizedBox.shrink()
              else if (isDownloading && dlState != null) ...[
                // Progression compacte
                Column(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        value: dlState.overallProgress,
                        strokeWidth: 3,
                        color: kGold,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(dlState.overallProgress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ] else ...[
                IconButton(
                  onPressed: () =>
                      showDownloadSheet(context, theme, prof),
                  icon: Icon(
                    theme.isFullyDownloaded
                        ? Icons.download_done_rounded
                        : theme.isPartiallyDownloaded
                            ? Icons.downloading_rounded
                            : Icons.download_rounded,
                    color: theme.isFullyDownloaded
                        ? Colors.green.shade700
                        : theme.isPartiallyDownloaded
                            ? Colors.orange.shade700
                            : kNavy,
                    size: 24,
                  ),
                  tooltip: theme.isFullyDownloaded
                      ? 'Téléchargé'
                      : 'Télécharger',
                ),
              ],
            ],
          ),
        ),

        const Divider(height: 1),

        // Liste des pistes (ou message si le thème n'a pas encore d'audio)
        Expanded(
          child: theme.tracks.isEmpty
              ? _EmptyThemeMessage(themeName: theme.name)
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: theme.tracks.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 64),
                  itemBuilder: (ctx, index) {
                    final track = theme.tracks[index];
                    final isCurrent = provider.currentTrackIndex == index &&
                        provider.selectedTheme?.name == theme.name;

                    return _TrackTile(
                      track: track,
                      index: index,
                      isCurrent: isCurrent,
                      // Le tap sur la ligne sélectionne la piste, sauf si
                      // c'est déjà la piste en cours : dans ce cas
                      // selectTrack() ne fait rien (cf. AppProvider), et le
                      // toggle play/pause se fait uniquement via le bouton
                      // rond dédié (voir _TrackTile ci-dessous).
                      onTap: () async {
                        final error = await provider.selectTrack(index);
                        if (error != null && ctx.mounted) {
                          _showOfflineDialog(ctx, error);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptyThemeMessage extends StatelessWidget {
  final String themeName;
  const _EmptyThemeMessage({required this.themeName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty_rounded,
                size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Aucun audio disponible pour\n« $themeName » pour le moment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final AudioTrack track;
  final int index;
  final bool isCurrent;
  final VoidCallback onTap;

  const _TrackTile({
    required this.track,
    required this.index,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: isCurrent ? kGold.withOpacity(0.06) : Colors.transparent,
        child: Row(
          children: [
            // Numéro / icône lecture (bouton toggle play/pause si en cours)
            SizedBox(
              width: 36,
              height: 36,
              child: isCurrent
                  ? StreamBuilder<PlayerState>(
                      stream: provider.audioService.playerStateStream,
                      builder: (_, snap) {
                        final playing = snap.data?.playing == true;
                        // InkWell imbriqué : intercepte le tap avant qu'il
                        // ne remonte au InkWell parent de la ligne, donc
                        // taper ce cercle fait UNIQUEMENT un toggle
                        // play/pause et ne déclenche pas onTap() (qui
                        // appellerait selectTrack et pourrait sembler
                        // "réinitialiser" la lecture).
                        return Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () => provider.togglePlayPause(),
                            customBorder: const CircleBorder(),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kNavy,
                              ),
                              child: Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF0F4FF),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kNavy,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Titre
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatAudioTitle(track.filename),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isCurrent ? kNavy : Colors.black87,
                    ),
                  ),
                  if (isCurrent)
                    Text(
                      'En lecture',
                      style: TextStyle(
                        fontSize: 10,
                        color: kGold,
                      ),
                    ),
                ],
              ),
            ),

            // Icône statut téléchargement
            if (track.isDownloaded)
              Icon(Icons.offline_pin_rounded,
                  size: 14, color: Colors.green.shade600)
            else
              Icon(Icons.cloud_outlined,
                  size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ── Dialog hors-ligne ────────────────────────────────────────────────────

void _showOfflineDialog(BuildContext context, String message) {
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
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        // Bouton fermer
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Fermer', style: TextStyle(color: Colors.grey.shade600)),
        ),
        // Bouton télécharger → ouvre le bottom sheet de téléchargement
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            // Récupérer le provider et ouvrir le sheet de download
            final provider = ctx.read<AppProvider>();
            final theme    = provider.selectedTheme;
            final prof     = provider.selectedProfessor;
            if (theme != null && prof != null) {
              showDownloadSheet(ctx, theme, prof);
            }
          },
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Télécharger'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    ),
  );
}
