// lib/widgets/audio_player_widget.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/audio_service.dart';
import '../utils/app_theme.dart';
import '../utils/string_utils.dart';
import 'offline_dialog.dart';

class AudioPlayerWidget extends StatelessWidget {
  const AudioPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final audioSvc = provider.audioService;
    final theme = provider.selectedTheme;

    if (theme == null) {
      return _EmptyPlayer();
    }

    // Mode "live" : le thème AFFICHÉ est bien celui RÉELLEMENT chargé dans
    // le lecteur (potentiellement en cours de lecture) → tout vient des
    // flux réels (position, durée, play/pause).
    // Mode "aperçu" : thème simplement consulté, pas encore chargé → état
    // statique (piste 1 ou reprise, à la position sauvegardée), rien ne
    // joue, et une éventuelle lecture d'un AUTRE thème continue intacte en
    // arrière-plan (le lecteur n'est pas touché tant qu'on n'appuie pas
    // sur Play).
    final isLive = provider.isSelectedThemeLoaded;

    return Container(
      color: kNavy,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre en cours (live) ou sélectionné (aperçu)
          isLive
              ? _LiveTitleBlock(theme: theme, provider: provider, audioSvc: audioSvc)
              : _PreviewTitleBlock(theme: theme, provider: provider),

          const SizedBox(height: 12),

          // Barre de progression (live) ou info de reprise statique (aperçu)
          isLive
              ? _LiveProgressBar(audioSvc: audioSvc)
              : _PreviewProgressBar(positionMs: provider.previewPositionMs),

          const SizedBox(height: 8),

          // Contrôles principaux
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Reculer 10s
              _ControlBtn(
                icon: Icons.replay_10,
                size: 26,
                onTap: isLive ? audioSvc.skipBackward : null,
              ),
              // Piste précédente
              _ControlBtn(
                icon: Icons.skip_previous_rounded,
                size: 30,
                onTap: isLive ? audioSvc.skipToPrevious : null,
              ),
              // Play / Pause
              isLive
                  ? _LivePlayPauseButton(audioSvc: audioSvc)
                  : _PreviewPlayButton(provider: provider, theme: theme),
              // Piste suivante
              _ControlBtn(
                icon: Icons.skip_next_rounded,
                size: 30,
                onTap: isLive ? audioSvc.skipToNext : null,
              ),
              // Avancer 10s
              _ControlBtn(
                icon: Icons.forward_10,
                size: 26,
                onTap: isLive ? audioSvc.skipForward : null,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Contrôles secondaires — réglages globaux du lecteur (vitesse,
          // volume, boucle), toujours actifs : ils s'appliquent au moteur
          // audio directement (à la lecture en cours s'il y en a une, ou à
          // la prochaine lecture démarrée sinon).
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Boucle
              _LoopButton(),

              // Volume
              Row(
                children: [
                  Icon(
                    Icons.volume_down,
                    size: 14,
                    color: Colors.white.withOpacity(0.45),
                  ),
                  SizedBox(
                    width: 80,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5),
                        activeTrackColor: Colors.white.withOpacity(0.6),
                        inactiveTrackColor:
                            Colors.white.withOpacity(0.15),
                        thumbColor: Colors.white,
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: provider.volume,
                        onChanged: (v) => provider.setVolume(v),
                        min: 0,
                        max: 1,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.volume_up,
                    size: 14,
                    color: Colors.white.withOpacity(0.45),
                  ),
                ],
              ),

              // Vitesse
              _SpeedButton(),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Titre : mode live (flux réel) ───────────────────────────────────────

class _LiveTitleBlock extends StatelessWidget {
  final AudioTheme theme;
  final AppProvider provider;
  final AudioPlayerService audioSvc;

  const _LiveTitleBlock({
    required this.theme,
    required this.provider,
    required this.audioSvc,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SequenceState?>(
      stream: audioSvc.sequenceStateStream,
      builder: (_, snap) {
        final currentIndex = snap.data?.currentIndex ?? 0;
        if (currentIndex < theme.tracks.length) {
          provider.currentTrackIndex = currentIndex;
        }
        final title = currentIndex < theme.tracks.length
            ? formatAudioTitle(theme.tracks[currentIndex].filename)
            : theme.name;

        return Column(
          children: [
            Text(
              'En lecture',
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withOpacity(0.45),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 22,
              child: title.length > 35
                  ? Marquee(
                      text: title,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      scrollAxis: Axis.horizontal,
                      velocity: 35,
                      pauseAfterRound: const Duration(seconds: 2),
                      blankSpace: 60,
                    )
                  : Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            const SizedBox(height: 2),
            Text(
              '${provider.selectedProfessor?.name ?? ''} · ${theme.name}',
              style: TextStyle(fontSize: 10, color: kGoldLight),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

// ── Titre : mode aperçu (statique, rien ne joue) ────────────────────────

class _PreviewTitleBlock extends StatelessWidget {
  final AudioTheme theme;
  final AppProvider provider;

  const _PreviewTitleBlock({required this.theme, required this.provider});

  @override
  Widget build(BuildContext context) {
    final idx = provider.currentTrackIndex;
    final title = idx >= 0 && idx < theme.tracks.length
        ? formatAudioTitle(theme.tracks[idx].filename)
        : theme.name;

    return Column(
      children: [
        Text(
          provider.previewPositionMs > 0 ? 'Reprise disponible' : 'Sélectionné',
          style: TextStyle(
            fontSize: 9,
            color: Colors.white.withOpacity(0.45),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 22,
          child: title.length > 35
              ? Marquee(
                  text: title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  scrollAxis: Axis.horizontal,
                  velocity: 35,
                  pauseAfterRound: const Duration(seconds: 2),
                  blankSpace: 60,
                )
              : Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
        const SizedBox(height: 2),
        Text(
          '${provider.selectedProfessor?.name ?? ''} · ${theme.name}',
          style: TextStyle(fontSize: 10, color: kGoldLight),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Barre de progression : mode live (flux réels) ───────────────────────

class _LiveProgressBar extends StatelessWidget {
  final AudioPlayerService audioSvc;
  const _LiveProgressBar({required this.audioSvc});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: audioSvc.positionStream,
      builder: (_, posSnap) {
        return StreamBuilder<Duration?>(
          stream: audioSvc.durationStream,
          builder: (_, durSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final dur = durSnap.data ?? Duration.zero;
            final progress = dur.inMilliseconds > 0
                ? pos.inMilliseconds / dur.inMilliseconds
                : 0.0;

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: kGold,
                    inactiveTrackColor: Colors.white.withOpacity(0.15),
                    thumbColor: Colors.white,
                    overlayColor: kGold.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (v) {
                      if (dur.inMilliseconds > 0) {
                        audioSvc.seekTo(Duration(
                            milliseconds: (v * dur.inMilliseconds).toInt()));
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDuration(pos),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.45),
                        ),
                      ),
                      Text(
                        formatDuration(dur),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Barre de progression : mode aperçu (statique) ───────────────────────
//
// Sans chargement dans le lecteur, la durée réelle n'est pas connue —
// pas de fausse barre de progression trompeuse : on affiche simplement le
// point de reprise (ou "Prêt à démarrer" s'il n'y en a pas).

class _PreviewProgressBar extends StatelessWidget {
  final int positionMs;
  const _PreviewProgressBar({required this.positionMs});

  @override
  Widget build(BuildContext context) {
    final hasResume = positionMs > 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasResume ? Icons.history_rounded : Icons.play_circle_outline_rounded,
            size: 14,
            color: Colors.white.withOpacity(0.4),
          ),
          const SizedBox(width: 6),
          Text(
            hasResume
                ? 'Reprendra à ${formatDuration(Duration(milliseconds: positionMs))}'
                : 'Prêt à démarrer',
            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}

// ── Bouton Play/Pause : mode live ────────────────────────────────────────

class _LivePlayPauseButton extends StatelessWidget {
  final AudioPlayerService audioSvc;
  const _LivePlayPauseButton({required this.audioSvc});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: audioSvc.playerStateStream,
      builder: (_, snap) {
        final playing = snap.data?.playing == true;
        final loading = snap.data?.processingState == ProcessingState.loading ||
            snap.data?.processingState == ProcessingState.buffering;

        return GestureDetector(
          onTap: playing
              ? audioSvc.pause
              : context.read<AppProvider>().togglePlayPause,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kGold,
              boxShadow: [
                BoxShadow(
                  color: kGold.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: loading
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                : Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: kNavy,
                    size: 28,
                  ),
          ),
        );
      },
    );
  }
}

// ── Bouton Play : mode aperçu ────────────────────────────────────────────
//
// Seul point d'entrée (avec l'icône ronde d'une piste dans AudioTrackList)
// qui déclenche réellement AppProvider.commitAndPlay() — donc qui charge
// le lecteur et démarre la lecture. Toujours un simple triangle Play
// statique (rien ne joue tant qu'on ne l'a pas pressé).

class _PreviewPlayButton extends StatelessWidget {
  final AppProvider provider;
  final AudioTheme theme;
  const _PreviewPlayButton({required this.provider, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final error = await provider.commitAndPlay();
        if (error == 'offline_theme' && context.mounted) {
          final prof = provider.selectedProfessor;
          if (prof != null) showOfflineThemeDialog(context, theme, prof);
        }
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kGold,
          boxShadow: [
            BoxShadow(
              color: kGold.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(Icons.play_arrow_rounded, color: kNavy, size: 28),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;

  const _ControlBtn({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white.withOpacity(enabled ? 0.75 : 0.25), size: size),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}

class _LoopButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return GestureDetector(
      onTap: provider.toggleLoop,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            provider.isLooping ? Icons.repeat_one : Icons.repeat,
            size: 16,
            color: provider.isLooping
                ? kGoldLight
                : Colors.white.withOpacity(0.45),
          ),
          const SizedBox(width: 3),
          Text(
            'Boucle',
            style: TextStyle(
              fontSize: 10,
              color: provider.isLooping
                  ? kGoldLight
                  : Colors.white.withOpacity(0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  static const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return GestureDetector(
      onTap: () => _showSpeedSheet(context, provider),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed, size: 14, color: Colors.white.withOpacity(0.45)),
          const SizedBox(width: 3),
          Text(
            '${provider.playbackSpeed}×',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.45),
            ),
          ),
        ],
      ),
    );
  }

  void _showSpeedSheet(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Vitesse de lecture',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kNavy,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: speeds.map((s) {
                final isSelected = provider.playbackSpeed == s;
                return GestureDetector(
                  onTap: () {
                    provider.setSpeed(s);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? kNavy : const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${s}×',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : kNavy,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: kNavy,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.library_music_outlined,
            color: Colors.white.withOpacity(0.2),
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            'Sélectionnez un thème pour commencer',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
