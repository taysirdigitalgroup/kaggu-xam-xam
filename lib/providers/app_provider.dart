// lib/providers/app_provider.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/models.dart';
import '../services/bibliotheque_service.dart';
import '../services/download_service.dart';
import '../services/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../services/ad_service.dart';

enum AppState { loading, ready, error }

class DownloadState {
  final bool isDownloading;
  final bool isRefreshing; // true = mode rafraîchissement (delete-diff)
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
  final BibliothequeService _biblioService = BibliothequeService();
  final DownloadService _downloadService = DownloadService();
  final AudioPlayerService audioService = AudioPlayerService();
  final AdService adService = AdService();

  AppState state = AppState.loading;
  String errorMessage = '';
  List<Professor> professors = [];

  // Sélection courante
  Professor? selectedProfessor;
  AudioTheme? selectedTheme;
  int currentTrackIndex = 0;

  // Sidebar expand state
  final Set<String> expandedProfs = {};

  // Téléchargements / rafraîchissements en cours par thème
  final Map<String, DownloadState> downloadStates = {};

  // Lecteur
  double playbackSpeed = 1.0;
  bool isLooping = false;
  double volume = 1.0;

  Future<void> init() async {
    try {
      adService.initialize();
      await audioService.init();
      professors = await _biblioService.loadBibliotheque();

      // Vérifier disponibilité locale (local + bundled) pour chaque track
      for (final prof in professors) {
        for (final theme in prof.themes) {
          await _downloadService.refreshDownloadStatus(theme);
        }
      }

      state = AppState.ready;
    } catch (e) {
      state = AppState.error;
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

  Future<void> selectTheme(Professor prof, AudioTheme theme) async {
    selectedProfessor = prof;
    selectedTheme = theme;
    currentTrackIndex = 0;

    await adService.showInterstitialIfReady();
    await audioService.loadTheme(theme, startIndex: 0);
    notifyListeners();
  }

  Future<void> selectTrack(int index) async {
    currentTrackIndex = index;
    await audioService.seekToIndex(index);
    notifyListeners();
  }

  // ── Clé de thème ──────────────────────────────────────────────────────

  String _themeKey(AudioTheme t) {
    if (t.tracks.isEmpty) return '${t.profKey}_${toSlug(t.name)}';
    return '${t.profKey}_${t.tracks.first.themeKey}';
  }

  String toSlug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  // ── État des téléchargements ──────────────────────────────────────────

  bool isThemeDownloading(AudioTheme theme) =>
      downloadStates[_themeKey(theme)]?.isDownloading == true;

  bool isThemeRefreshing(AudioTheme theme) =>
      downloadStates[_themeKey(theme)]?.isRefreshing == true;

  DownloadState? getDownloadState(AudioTheme theme) =>
      downloadStates[_themeKey(theme)];

  // ── Téléchargement initial ────────────────────────────────────────────

  Future<void> downloadTheme(AudioTheme theme) async {
    final key = _themeKey(theme);
    final cancelToken = CancelToken();
    final total = theme.tracks.where((t) => !t.isDownloaded).length;
    if (total == 0) return;

    downloadStates[key] = DownloadState(
      isDownloading: true,
      isRefreshing: false,
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
          isRefreshing: false,
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
          isRefreshing: false,
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

    // Nombre de fichiers à télécharger = ceux absents en local
    final localMissing =
        theme.tracks.where((t) => !t.isDownloaded).length;

    downloadStates[key] = DownloadState(
      isDownloading: true,
      isRefreshing: true,
      currentTrackIndex: 0,
      totalTracks: localMissing,
      cancelToken: cancelToken,
    );
    notifyListeners();

    int doneCount = 0;
    int deletedCount = 0;

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
      onTrackDeleted: (filename) {
        deletedCount++;
        debugPrint('Deleted obsolete audio: $filename');
        notifyListeners();
      },
      onError: (err) => debugPrint('Refresh error: $err'),
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
    await audioService.setLoopMode(
        isLooping ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    volume = v;
    await audioService.setVolume(v);
    notifyListeners();
  }

  @override
  void dispose() {
    audioService.dispose();
    adService.dispose();
    super.dispose();
  }
}
