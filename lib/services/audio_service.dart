// lib/services/audio_service.dart
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import '../models/models.dart';
import '../utils/string_utils.dart';
import 'download_service.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final DownloadService _downloadService = DownloadService();

  AudioPlayer get player => _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  int? get currentIndex => _player.currentIndex;
  ProcessingState get processingState => _player.processingState;

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  /// Charge un thème complet dans la playlist et démarre la piste [startIndex].
  ///
  /// Priorité de lecture pour chaque piste :
  /// 1. Stockage local (file://)
  /// 2. Asset embarqué (asset:///)
  /// 3. Streaming distant (https://)
  Future<void> loadTheme(AudioTheme theme, {int startIndex = 0}) async {
    final sources = <AudioSource>[];

    for (final track in theme.tracks) {
      final uri = await _downloadService.getPlayableUri(track);
      final source = _buildAudioSource(uri, track, theme);
      sources.add(source);
    }

    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: startIndex,
      initialPosition: Duration.zero,
    );
    await _player.play();
  }

  AudioSource _buildAudioSource(
      String uri, AudioTrack track, AudioTheme theme) {
    final tag = MediaItem(
      id: track.filename,
      title: formatAudioTitle(track.filename),
      artist: track.profKey.replaceAll('_', ' '),
      album: theme.name,
    );

    // Les assets embarqués utilisent la syntaxe asset:/// reconnue par just_audio
    if (uri.startsWith('asset:///')) {
      final assetPath = uri.replaceFirst('asset:///', '');
      return AudioSource.uri(Uri.parse('asset:///$assetPath'), tag: tag);
    }

    return AudioSource.uri(Uri.parse(uri), tag: tag);
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();

  Future<void> seekTo(Duration position) => _player.seek(position);
  Future<void> seekToIndex(int index) =>
      _player.seek(Duration.zero, index: index);

  Future<void> skipForward() async {
    final newPos = _player.position + const Duration(seconds: 10);
    final dur = _player.duration;
    if (dur != null && newPos < dur) {
      await _player.seek(newPos);
    }
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

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  Future<void> setLoopMode(LoopMode mode) => _player.setLoopMode(mode);
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  void dispose() => _player.dispose();
}
