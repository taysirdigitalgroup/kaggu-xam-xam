// lib/services/audio_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../utils/string_utils.dart';
import 'download_service.dart';

class AudioPlayerService {
  final AudioPlayer     _player          = AudioPlayer();
  final DownloadService _downloadService = DownloadService();
  final Map<String, String> _artworkCache = {};

  // Callback appelé par AppProvider pour re-play après interruption
  VoidCallback? onResumeRequested;

  AudioPlayer get player => _player;

  Stream<PlayerState>    get playerStateStream   => _player.playerStateStream;
  Stream<Duration>       get positionStream      => _player.positionStream;
  Stream<Duration?>      get durationStream      => _player.durationStream;
  Stream<int?>           get currentIndexStream  => _player.currentIndexStream;
  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  bool            get isPlaying       => _player.playing;
  Duration        get position        => _player.position;
  Duration?       get duration        => _player.duration;
  int?            get currentIndex    => _player.currentIndex;
  ProcessingState get processingState => _player.processingState;

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Gestion des interruptions audio (appel entrant, autre app, etc.)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        // Interruption commencée → toujours pause
        switch (event.type) {
          case AudioInterruptionType.duck:
            // Baisser le volume temporairement si duck, pas pause
            _player.setVolume(0.3);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            _player.pause();
            break;
        }
      } else {
        // Interruption terminée → reprendre
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            // Reprendre seulement si le player était en train de jouer
            // avant l'interruption (processingState indique s'il y a
            // une source chargée)
            if (_player.processingState == ProcessingState.ready) {
              _player.play();
            }
            break;
        }
      }
    });

    // Gestion des événements de transport Android (boutons notification,
    // écouteurs, Bluetooth) — just_audio_background gère déjà la plupart
    // mais on s'assure que le bouton Play sur notification fonctionne
    // même après une interruption.
    session.becomingNoisyEventStream.listen((_) {
      // Câble débranché / Bluetooth déconnecté → pause obligatoire
      _player.pause();
    });
  }

  /// Charge le thème et démarre à [startIndex].
  Future<void> loadTheme(
    AudioTheme theme, {
    int startIndex = 0,
    Professor? professor,
  }) async {
    Uri? artworkUri;
    if (professor != null && professor.imagePath.isNotEmpty) {
      artworkUri = await _resolveArtworkUri(professor.imagePath);
    }

    final sources = <AudioSource>[];
    for (final track in theme.tracks) {
      final uri = await _downloadService.getPlayableUri(track);
      sources.add(_buildSource(uri, track, theme, artworkUri));
    }

    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex:    startIndex,
      initialPosition: Duration.zero,
    );
    await _player.play();
  }

  AudioSource _buildSource(
    String uri,
    AudioTrack track,
    AudioTheme theme,
    Uri? artworkUri,
  ) {
    final tag = MediaItem(
      id:     track.filename,
      title:  formatAudioTitle(track.filename),
      artist: theme.profKey
          .replaceAll('_', ' ')
          .split(' ')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' '),
      album:  theme.name,
      artUri: artworkUri,
    );
    return AudioSource.uri(Uri.parse(uri), tag: tag);
  }

  /// Copie l'asset image dans un fichier cache pour la notification Android.
  Future<Uri?> _resolveArtworkUri(String assetPath) async {
    if (_artworkCache.containsKey(assetPath)) {
      final p = _artworkCache[assetPath]!;
      if (File(p).existsSync()) return Uri.file(p);
    }
    try {
      final data     = await rootBundle.load(assetPath);
      final bytes    = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final cacheDir = await getTemporaryDirectory();
      final filename = assetPath.replaceAll('/', '_').replaceAll(' ', '_');
      final file     = File('${cacheDir.path}/artwork_$filename');
      await file.writeAsBytes(bytes, flush: true);
      _artworkCache[assetPath] = file.path;
      return Uri.file(file.path);
    } catch (e) {
      debugPrint('[AudioService] Artwork non résolu: $e');
      return null;
    }
  }

  // ── Contrôles ────────────────────────────────────────────────────────

  /// Play robuste : si le player est en idle/completed mais a une source,
  /// tente de seek à la position courante d'abord pour le "réveiller".
  Future<void> play() async {
    if (_player.processingState == ProcessingState.completed) {
      // Fin de playlist → retour au début
      await _player.seek(Duration.zero, index: 0);
    }
    await _player.play();
  }

  Future<void> pause() => _player.pause();
  Future<void> stop()  => _player.stop();

  Future<void> seekTo(Duration position) => _player.seek(position);
  Future<void> seekToIndex(int index)    => _player.seek(Duration.zero, index: index);

  Future<void> skipForward() async {
    final newPos = _player.position + const Duration(seconds: 10);
    final dur    = _player.duration;
    if (dur != null && newPos < dur) await _player.seek(newPos);
  }

  Future<void> skipBackward() async {
    final newPos = _player.position - const Duration(seconds: 10);
    await _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  Future<void> skipToNext() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  Future<void> setSpeed(double speed)      => _player.setSpeed(speed);
  Future<void> setLoopMode(LoopMode mode)  => _player.setLoopMode(mode);
  Future<void> setVolume(double volume)    => _player.setVolume(volume);

  void dispose() => _player.dispose();
}
