// lib/services/audio_service.dart
import 'dart:io';
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

  // Cache des URI d'artwork déjà copiés en fichier temporaire
  // clé = assetPath, valeur = chemin fichier local
  final Map<String, String> _artworkCache = {};

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

    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        _player.pause();
      } else {
        if (event.type == AudioInterruptionType.pause ||
            event.type == AudioInterruptionType.duck) {
          _player.play();
        }
      }
    });
  }

  /// Charge le thème complet et démarre à [startIndex].
  /// [professor] est utilisé pour l'artwork de la notification.
  Future<void> loadTheme(
    AudioTheme theme, {
    int startIndex = 0,
    Professor? professor,
  }) async {
    // Préparer l'artwork AVANT de charger la playlist
    // (copier l'asset en fichier tmp si pas encore fait)
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

  /// Convertit un chemin asset en URI file:// utilisable par Android
  /// pour afficher l'image dans la notification du lecteur.
  ///
  /// Android ne peut pas lire les assets Flutter directement depuis
  /// la notification système. On copie l'image une seule fois dans
  /// le répertoire de cache de l'app, puis on passe son chemin file://.
  Future<Uri?> _resolveArtworkUri(String assetPath) async {
    // Cache hit → retourner directement
    if (_artworkCache.containsKey(assetPath)) {
      final cachedPath = _artworkCache[assetPath]!;
      if (File(cachedPath).existsSync()) {
        return Uri.file(cachedPath);
      }
    }

    try {
      // Lire l'image depuis le bundle Flutter
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      // Déterminer l'extension
      final ext = assetPath.split('.').last.toLowerCase();

      // Copier dans le répertoire de cache de l'app
      final cacheDir = await getTemporaryDirectory();
      // Nom de fichier stable basé sur l'asset (pas de timestamp)
      final filename = assetPath.replaceAll('/', '_').replaceAll(' ', '_');
      final file = File('${cacheDir.path}/artwork_$filename');
      await file.writeAsBytes(bytes, flush: true);

      _artworkCache[assetPath] = file.path;
      return Uri.file(file.path);
    } catch (e) {
      // Asset absent ou erreur lecture → pas d'artwork (pas grave)
      print('[AudioService] Artwork non résolu pour $assetPath : $e');
      return null;
    }
  }

  Future<void> play()  => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop()  => _player.stop();

  Future<void> seekTo(Duration position)  => _player.seek(position);
  Future<void> seekToIndex(int index)     => _player.seek(Duration.zero, index: index);

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
