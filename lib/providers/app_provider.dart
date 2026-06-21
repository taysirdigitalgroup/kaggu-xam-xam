// lib/providers/app_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import '../models/models.dart';
import '../services/bibliotheque_service.dart';
import '../services/download_service.dart';
import '../services/audio_service.dart';
import '../services/ad_service.dart';
import '../services/permission_service.dart';
import '../services/connectivity_service.dart';
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
    this.isDownloading = false,
    this.isRefreshing = false,
    this.currentTrackIndex = 0,
    this.totalTracks = 0,
    this.currentTrackProgress = 0,
    this.cancelToken,
  });

  double get overallProgress {
    if (totalTracks == 0) return 0;
    return (currentTrackIndex + currentTrackProgress) / totalTracks;
  }
}

class AppProvider extends ChangeNotifier {
  final BibliothequeService   _biblioService     = BibliothequeService();
  final DownloadService       _downloadService   = DownloadService();
  final AudioPlayerService    audioService       = AudioPlayerService();
  final AdService             adService          = AdService();
  final PermissionService     permissionService  = PermissionService();
  final ConnectivityService   connectivityService = ConnectivityService();

  AppState state       = AppState.loading;
  String errorMessage  = '';
  List<Professor> professors = [];

  // Sélection courante
  Professor?  selectedProfessor;
  AudioTheme? selectedTheme;
  int         currentTrackIndex = 0;

  // Sidebar expand state
  final Set<String> expandedProfs = {};

  // Téléchargements / rafraîchissements en cours par thème
  final Map<String, DownloadState> downloadStates = {};

  // Lecteur
  double playbackSpeed = 1.0;
  bool   isLooping     = false;
  double volume        = 1.0;

  StreamSubscription<int?>? _currentIndexSub;

  // ── Initialisation ────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      adService.initialize();
      await audioService.init();

      _currentIndexSub?.cancel();
      _currentIndexSub = audioService.currentIndexStream.listen((index) {
        if (index != null && index != currentTrackIndex) {
          currentTrackIndex = index;
          notifyListeners();
        }
      });

      await permissionService.requestStorageIfNeeded();

      professors = await _biblioService.loadBibliotheque();

      await _downloadService.ensureCatalogDirectories(professors);

      for (final prof in professors) {
        for (final theme in prof.themes) {
          await _downloadService.refreshDownloadStatus(theme);
        }
      }

      state = AppState.ready;
    } catch (e) {
      state  = AppState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  void toggleProfExpand(String profKey) {
    if (expandedProfs.contains(profKey)) {
      expandedProfs.remove(profKey);
    } else {
      expandedProfs.add(profKey);
    }
    notifyListeners();
  }

  // ── Sélection thème ───────────────────────────────────────────────────

  Future<void> selectTheme(Professor prof, AudioTheme theme) async {
    final alreadySelected = selectedProfessor?.key == prof.key &&
        selectedTheme?.name == theme.name;
    if (alreadySelected) return;

    selectedProfessor = prof;
    selectedTheme     = theme;
    currentTrackIndex = 0;
    notifyListeners();

    await adService.showInterstitialIfReady();

    if (theme.tracks.isNotEmpty) {
      // Passer le professeur pour l'artwork de la notification
      await audioService.loadTheme(
        theme,
        startIndex: 0,
        professor: prof,
      );
    }
    notifyListeners();
  }

  // ── Sélection piste avec vérification hors-ligne ─────────────────────

  /// Sélectionne une piste.
  /// Retourne un message d'erreur si la piste n'est pas disponible
  /// hors-ligne ET qu'il n'y a pas de connexion, null sinon.
  Future<String?> selectTrack(int index) async {
    final theme = selectedTheme;
    if (theme == null) return null;

    final track = theme.tracks[index];

    // Si la piste n'est pas disponible localement, vérifier la connexion
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
    notifyListeners();
    return null; // pas d'erreur
  }

  Future<void> togglePlayPause() async {
    if (audioService.isPlaying) {
      await audioService.pause();
    } else {
      await audioService.play();
    }
    notifyListeners();
  }

  // ── Clé de thème ──────────────────────────────────────────────────────

  String _themeKey(AudioTheme t) {
    if (t.tracks.isEmpty) return '${t.profKey}_${toSlug(t.name)}';
    return '${t.profKey}_${t.tracks.first.themeKey}';
  }

  // ── État des téléchargements ──────────────────────────────────────────

  bool isThemeDownloading(AudioTheme theme) =>
      downloadStates[_themeKey(theme)]?.isDownloading == true;

  bool isThemeRefreshing(AudioTheme theme) =>
      downloadStates[_themeKey(theme)]?.isRefreshing == true;

  DownloadState? getDownloadState(AudioTheme theme) =>
      downloadStates[_themeKey(theme)];

  // ── Téléchargement ────────────────────────────────────────────────────

  Future<void> downloadTheme(AudioTheme theme) async {
    final key = _themeKey(theme);
    final cancelToken = CancelToken();
    final total = theme.tracks.where((t) => !t.isDownloaded).length;
    if (total == 0) return;

    downloadStates[key] = DownloadState(
      isDownloading: true,
      currentTrackIndex: 0,
      totalTracks: total,
      cancelToken: cancelToken,
    );
    notifyListeners();

    int doneCount = 0;
    await _downloadService.downloadTheme(
      theme: theme,
      cancelToken: cancelToken,
      onTrackProgress: (track, progress) {
        downloadStates[key] = DownloadState(
          isDownloading: true,
          currentTrackIndex: doneCount,
          totalTracks: total,
          currentTrackProgress: progress,
          cancelToken: cancelToken,
        );
        track.downloadProgress = progress;
        notifyListeners();
      },
      onTrackDone: (track) {
        doneCount++;
        downloadStates[key] = DownloadState(
          isDownloading: true,
          currentTrackIndex: doneCount,
          totalTracks: total,
          cancelToken: cancelToken,
        );
        notifyListeners();
      },
      onError: (err) => debugPrint('Download error: $err'),
    );

    downloadStates.remove(key);
    notifyListeners();
  }

  // ── Rafraîchissement (delete-diff) ───────────────────────────────────

  Future<void> refreshTheme(AudioTheme theme) async {
    final key = _themeKey(theme);
    final cancelToken = CancelToken();
    final localMissing = theme.tracks.where((t) => !t.isDownloaded).length;

    downloadStates[key] = DownloadState(
      isDownloading: true,
      isRefreshing: true,
      currentTrackIndex: 0,
      totalTracks: localMissing,
      cancelToken: cancelToken,
    );
    notifyListeners();

    int doneCount = 0;

    await _downloadService.refreshTheme(
      theme: theme,
      cancelToken: cancelToken,
      onTrackProgress: (track, progress) {
        downloadStates[key] = DownloadState(
          isDownloading: true,
          isRefreshing: true,
          currentTrackIndex: doneCount,
          totalTracks: localMissing,
          currentTrackProgress: progress,
          cancelToken: cancelToken,
        );
        track.downloadProgress = progress;
        notifyListeners();
      },
      onTrackDone: (track) {
        doneCount++;
        downloadStates[key] = DownloadState(
          isDownloading: true,
          isRefreshing: true,
          currentTrackIndex: doneCount,
          totalTracks: localMissing,
          cancelToken: cancelToken,
        );
        notifyListeners();
      },
      onTrackDeleted: (filename) => debugPrint('Deleted: $filename'),
      onError:        (err)      => debugPrint('Refresh error: $err'),
    );

    downloadStates.remove(key);
    notifyListeners();
  }

  Future<void> cancelDownload(AudioTheme theme) async {
    final key = _themeKey(theme);
    downloadStates[key]?.cancelToken?.cancel();
    downloadStates.remove(key);
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
    audioService.dispose();
    adService.dispose();
    super.dispose();
  }
}
