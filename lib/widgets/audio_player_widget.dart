// lib/widgets/audio_player_widget.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/string_utils.dart';

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

    return Container(
      color: kNavy,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre en cours avec défilement si long
          StreamBuilder<SequenceState?>(
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
                            pauseAfterRound:
                                const Duration(seconds: 2),
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
                    style: TextStyle(
                      fontSize: 10,
                      color: kGoldLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // Barre de progression
          StreamBuilder<Duration>(
            stream: audioSvc.positionStream,
            builder: (_, posSnap) {
              return StreamBuilder<Duration?>(
                stream: audioSvc.durationStream,
                builder: (_, durSnap) {
                  final pos = posSnap.data ?? Duration.zero;
                  final dur = durSnap.data ?? Duration.zero;
                  final progress =
                      dur.inMilliseconds > 0
                          ? pos.inMilliseconds / dur.inMilliseconds
                          : 0.0;

                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14),
                          activeTrackColor: kGold,
                          inactiveTrackColor:
                              Colors.white.withOpacity(0.15),
                          thumbColor: Colors.white,
                          overlayColor: kGold.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (v) {
                            if (dur.inMilliseconds > 0) {
                              audioSvc.seekTo(Duration(
                                  milliseconds:
                                      (v * dur.inMilliseconds).toInt()));
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatDuration(pos),
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    Colors.white.withOpacity(0.45),
                              ),
                            ),
                            Text(
                              formatDuration(dur),
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    Colors.white.withOpacity(0.45),
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
          ),

          const SizedBox(height: 8),

          // Contrôles principaux
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Reculer 10s
              _ControlBtn(
                icon: Icons.replay_10,
                size: 26,
                onTap: audioSvc.skipBackward,
              ),
              // Piste précédente
              _ControlBtn(
                icon: Icons.skip_previous_rounded,
                size: 30,
                onTap: audioSvc.skipToPrevious,
              ),
              // Play / Pause
              StreamBuilder<PlayerState>(
                stream: audioSvc.playerStateStream,
                builder: (_, snap) {
                  final playing = snap.data?.playing == true;
                  final loading = snap.data?.processingState ==
                          ProcessingState.loading ||
                      snap.data?.processingState ==
                          ProcessingState.buffering;

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
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: kNavy,
                              size: 28,
                            ),
                    ),
                  );
                },
              ),
              // Piste suivante
              _ControlBtn(
                icon: Icons.skip_next_rounded,
                size: 30,
                onTap: audioSvc.skipToNext,
              ),
              // Avancer 10s
              _ControlBtn(
                icon: Icons.forward_10,
                size: 26,
                onTap: audioSvc.skipForward,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Contrôles secondaires
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

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _ControlBtn({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white.withOpacity(0.75), size: size),
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
