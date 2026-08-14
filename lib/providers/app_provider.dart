// lib/providers/app_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import '../models/models.dart';
import '../services/bibliotheque_service.dart';
import '../services/download_service.dart';
import '../services/audio_service.dart';
import '../services/permission_service.dart';
import '../services/connectivity_service.dart';
import '../services/playback_persistence_service.dart';
import '../utils/string_utils.dart';

enum AppState { loading, ready, error }

class DownloadState {
  final bool isDownloading;
  final bool isRefreshing;
  final int currentTrackIndex;
  final int totalTracks;
  final double currentTrackProgress;
  final CancelToken? cancelToken;

  const DownloadState({
    this.isDownloading        = false,
    this.isRefreshing         = false,
    this.currentTrackIndex    = 0,
    this.totalTracks          = 0,
    this.currentTrackProgress = 0,
    this.cancelToken,
  });

  double get overallProgress {
    if (totalTracks == 0) return 0;
    return (currentTrackIndex + currentTrackProgress) / totalTracks;
  }
}

class AppProvider extends ChangeNotifier {
  final BibliothequeService        _biblioService      = BibliothequeService();
  final DownloadService            _downloadService    = DownloadService();
  final AudioPlayerService         audioService        = AudioPlayerService();
  final PermissionService          permissionService   = PermissionService();
  final ConnectivityService        connectivityService = ConnectivityService();
  final PlaybackPersistenceService _persistence        = PlaybackPersistenceService();

  AppState state      = AppState.loading;
  String errorMessage = '';
  List<Professor> professors = [];

  Professor?  selectedProfessor;
  AudioTheme? selectedTheme;
  int         currentTrackIndex = 0;

  // Dernier thème lu (pour WelcomePane)
  PlaybackState? lastPlaybackState;

  final Set<String> expandedProfs = {};
  final Map<String, DownloadState> downloadStates = {};

  double playbackSpeed = 1.0;
  bool   isLooping     = false;
  double volume        = 1.0;

  // Compteur anti-bounce pour la save de position (toutes les ~5s)
  int _positionSaveTick = 0;

  StreamSubscription<int?>?     _currentIndexSub;
  StreamSubscription<Duration>? _positionSub;

  // ── Init ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      await audioService.init();

      _currentIndexSub?.cancel();
      _currentIndexSub = audioService.currentIndexStream.listen((index) {
        if (index != null && index != currentTrackIndex) {
          currentTrackIndex = index;
          _savePosition(positionMs: 0);
          notifyListeners();
        }
      });

      _positionSub?.cancel();
      _positionSub = audioService.positionStream.listen((pos) {
        _positionSaveTick++;
        // Sauvegarder toutes les ~5 secondes (positionStream émet ~1/s)
        if (_positionSaveTick % 5 == 0) {
          _savePosition(positionMs: pos.inMilliseconds);
        }
        _checkCompletion(pos);
      });

      await permissionService.requestStorageIfNeeded();
      professors = await _biblioService.loadBibliotheque();
      await _downloadService.ensureCatalogDirectories(professors);

      for (final prof in professors) {
        for (final theme in prof.themes) {
          await _downloadService.refreshDownloadStatus(theme);
        }
      }

      lastPlaybackState = await _persistence.loadLast();
      state = AppState.ready;
    } catch (e) {
      state        = AppState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  // ── Persistance ───────────────────────────────────────────────────────

  void _savePosition({int? positionMs}) {
    final prof  = selectedProfessor;
    final theme = selectedTheme;
    if (prof == null || theme == null) return;
    _persistence.save(
      profKey:    prof.key,
      profName:   prof.name,
      themeName:  theme.name,
      trackIndex: currentTrackIndex,
      positionMs: positionMs ?? audioService.position.inMilliseconds,
    );
  }

  void _checkCompletion(Duration pos) {
    final theme = selectedTheme;
    final prof  = selectedProfessor;
    if (theme == null || prof == null) return;
    final dur = audioService.duration;
    if (dur == null || dur.inSeconds == 0) return;
    final isLastTrack = currentTrackIndex == theme.tracks.length - 1;
    final nearEnd     = pos.inMilliseconds >= (dur.inMilliseconds * 0.95).toInt();
    if (isLastTrack && nearEnd) {
      _persistence.markCompleted(prof.key, theme.name);
    }
  }

  // ── Expand sidebar ────────────────────────────────────────────────────

  void toggleProfExpand(String profKey) {
    if (expandedProfs.contains(profKey)) {
      expandedProfs.remove(profKey);
    } else {
      expandedProfs.add(profKey);
    }
    notifyListeners();
  }

  // ── Sélection thème ───────────────────────────────────────────────────

  /// Retourne :
  ///   null              → lecture lancée (pas de dialog nécessaire)
  ///   'offline_theme'   → hors-ligne, aucun audio local
  ///   'resume:N:P'      → reprise possible (trackIndex=N, positionMs=P)
  Future<String?> selectTheme(
    Professor prof,
    AudioTheme theme, {
    bool forceNew = false,
  }) async {
    final alreadySelected = selectedProfessor?.key == prof.key &&
        selectedTheme?.name == theme.name;
    if (alreadySelected && !forceNew) return null;

    // Vérification hors-ligne
    if (!theme.isFullyAvailableOffline) {
      final hasAnyLocal = theme.tracks.any((t) => t.isAvailableLocally);
      if (!hasAnyLocal) {
        final connected = await connectivityService.hasConnection();
        if (!connected) return 'offline_theme';
      }
    }

    // Vérification reprise (par thème)
    if (!forceNew) {
      final saved = await _persistence.loadForTheme(prof.key, theme.name);
      if (saved != null && !saved.completed && saved.hasProgress) {
        return 'resume:${saved.trackIndex}:${saved.positionMs}';
      }
    }

    await _doLoadTheme(prof, theme, trackIndex: 0, positionMs: 0);
    return null;
  }

  Future<void> confirmResume(
      Professor prof, AudioTheme theme, int trackIndex, int positionMs) async {
    await _doLoadTheme(prof, theme, trackIndex: trackIndex, positionMs: positionMs);
  }

  Future<void> startFresh(Professor prof, AudioTheme theme) async {
    // Réinitialiser la sauvegarde de ce thème
    await _persistence.save(
      profKey: prof.key, profName: prof.name,
      themeName: theme.name, trackIndex: 0, positionMs: 0,
    );
    await _doLoadTheme(prof, theme, trackIndex: 0, positionMs: 0);
  }

  Future<void> _doLoadTheme(
    Professor prof,
    AudioTheme theme, {
    required int trackIndex,
    required int positionMs,
  }) async {
    selectedProfessor = prof;
    selectedTheme     = theme;
    currentTrackIndex = trackIndex;
    notifyListeners();

    if (theme.tracks.isNotEmpty) {
      await audioService.loadTheme(
        theme,
        startIndex: trackIndex,
        startPosition: Duration(milliseconds: positionMs),
        professor: prof,
      );
    }

    lastPlaybackState = await _persistence.loadLast();
    notifyListeners();
  }

  // ── Sélection piste ──────────────────────────────────────────────────

  Future<String?> selectTrack(int index) async {
    final theme = selectedTheme;
    if (theme == null) return null;
    final track = theme.tracks[index];

    if (!track.isAvailableLocally) {
      final connected = await connectivityService.hasConnection();
      if (!connected) {
        return 'Pas de connexion internet.\n'
            'Téléchargez les audios pour les écouter hors-ligne.';
      }
    }

    if (currentTrackIndex == index) return null;
    currentTrackIndex = index;
    await audioService.seekToIndex(index);
    _savePosition(positionMs: 0);
    notifyListeners();
    return null;
  }

  Future<void> togglePlayPause() async {
    if (audioService.isPlaying) {
      await audioService.pause();
    } else {
      // Utilise play() robuste (gère le cas completed)
      await audioService.play();
    }
    notifyListeners();
  }

  // ── Téléchargement ────────────────────────────────────────────────────

  String _themeKey(AudioTheme t) {
    if (t.tracks.isEmpty) return '${t.profKey}_${toSlug(t.name)}';
    return '${t.profKey}_${t.tracks.first.themeKey}';
  }

  bool isThemeDownloading(AudioTheme theme) =>
      downloadStates[_themeKey(theme)]?.isDownloading == true;

  bool isThemeRefreshing(AudioTheme theme) =>
      downloadStates[_themeKey(theme)]?.isRefreshing == true;

  DownloadState? getDownloadState(AudioTheme theme) =>
      downloadStates[_themeKey(theme)];

  Future<void> downloadTheme(AudioTheme theme) async {
    final key         = _themeKey(theme);
    final cancelToken = CancelToken();
    final total       = theme.tracks.where((t) => !t.isDownloaded).length;
    if (total == 0) return;

    downloadStates[key] = DownloadState(
      isDownloading: true, currentTrackIndex: 0,
      totalTracks: total, cancelToken: cancelToken,
    );
    notifyListeners();

    int doneCount = 0;
    await _downloadService.downloadTheme(
      theme: theme, cancelToken: cancelToken,
      onTrackProgress: (track, progress) {
        downloadStates[key] = DownloadState(
          isDownloading: true, currentTrackIndex: doneCount,
          totalTracks: total, currentTrackProgress: progress,
          cancelToken: cancelToken,
        );
        track.downloadProgress = progress;
        notifyListeners();
      },
      onTrackDone: (track) {
        doneCount++;
        downloadStates[key] = DownloadState(
          isDownloading: true, currentTrackIndex: doneCount,
          totalTracks: total, cancelToken: cancelToken,
        );
        notifyListeners();
      },
      onError: (err) => debugPrint('Download error: $err'),
    );

    downloadStates.remove(key);
    if (selectedTheme?.name == theme.name && selectedProfessor != null) {
      await _reloadCurrentThemeLocally();
    }
    notifyListeners();
  }

  Future<void> _reloadCurrentThemeLocally() async {
    final prof  = selectedProfessor;
    final theme = selectedTheme;
    if (prof == null || theme == null) return;

    final wasPlaying      = audioService.isPlaying;
    final savedIndex      = currentTrackIndex;
    final savedPositionMs = audioService.position.inMilliseconds;

    await _downloadService.refreshDownloadStatus(theme);
    await audioService.loadTheme(
      theme,
      startIndex: savedIndex,
      startPosition: Duration(milliseconds: savedPositionMs),
      professor: prof,
    );
    if (!wasPlaying) await audioService.pause();
  }

  Future<void> refreshTheme(AudioTheme theme) async {
    final key          = _themeKey(theme);
    final cancelToken  = CancelToken();
    final localMissing = theme.tracks.where((t) => !t.isDownloaded).length;

    downloadStates[key] = DownloadState(
      isDownloading: true, isRefreshing: true,
      currentTrackIndex: 0, totalTracks: localMissing,
      cancelToken: cancelToken,
    );
    notifyListeners();

    int doneCount = 0;
    await _downloadService.refreshTheme(
      theme: theme, cancelToken: cancelToken,
      onTrackProgress: (track, progress) {
        downloadStates[key] = DownloadState(
          isDownloading: true, isRefreshing: true,
          currentTrackIndex: doneCount, totalTracks: localMissing,
          currentTrackProgress: progress, cancelToken: cancelToken,
        );
        track.downloadProgress = progress;
        notifyListeners();
      },
      onTrackDone: (track) {
        doneCount++;
        downloadStates[key] = DownloadState(
          isDownloading: true, isRefreshing: true,
          currentTrackIndex: doneCount, totalTracks: localMissing,
          cancelToken: cancelToken,
        );
        notifyListeners();
      },
      onTrackDeleted: (f)   => debugPrint('Deleted: $f'),
      onError:        (err) => debugPrint('Refresh error: $err'),
    );

    downloadStates.remove(key);
    if (selectedTheme?.name == theme.name && selectedProfessor != null) {
      await _reloadCurrentThemeLocally();
    }
    notifyListeners();
  }

  Future<void> cancelDownload(AudioTheme theme) async {
    downloadStates[_themeKey(theme)]?.cancelToken?.cancel();
    downloadStates.remove(_themeKey(theme));
    notifyListeners();
  }

  Future<void> deleteTheme(AudioTheme theme) async {
    await _downloadService.deleteTheme(theme);
    notifyListeners();
  }

  // ── Contrôles lecteur ─────────────────────────────────────────────────

  Future<void> setSpeed(double speed) async {
    playbackSpeed = speed;
    await audioService.setSpeed(speed);
    notifyListeners();
  }

  Future<void> toggleLoop() async {
    isLooping = !isLooping;
    await audioService.setLoopMode(isLooping ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    volume = v;
    await audioService.setVolume(v);
    notifyListeners();
  }

  @override
  void dispose() {
    _currentIndexSub?.cancel();
    _positionSub?.cancel();
    audioService.dispose();
    super.dispose();
  }
}
