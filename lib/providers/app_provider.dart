// lib/providers/app_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import '../models/models.dart';
import '../services/bibliotheque_service.dart';
import '../services/professors_service.dart';
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
  final ProfessorsService          _professorsService  = ProfessorsService();
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

  /// Position (ms) à utiliser pour la reprise en mode "aperçu" (thème
  /// sélectionné mais PAS chargé dans le lecteur — voir [isSelectedThemeLoaded]).
  /// Non pertinent en mode "live" (la position réelle vient du lecteur).
  int previewPositionMs = 0;

  // Thème RÉELLEMENT chargé dans le lecteur audio (celui qui joue ou est en
  // pause dans le moteur `just_audio`). Peut différer de [selectedTheme] :
  // ouvrir/parcourir un thème dans le sidebar ne fait que changer la
  // sélection affichée (aperçu), sans jamais toucher au lecteur — celui-ci
  // n'est chargé/remplacé qu'au moment où l'utilisateur appuie sur Play
  // (voir [commitAndPlay]). Ainsi une lecture en cours n'est jamais coupée
  // par la simple consultation d'un autre thème.
  Professor?  _loadedProfessor;
  AudioTheme? _loadedTheme;

  /// true si le thème actuellement AFFICHÉ ([selectedTheme]) est bien celui
  /// RÉELLEMENT chargé dans le lecteur (potentiellement en cours de
  /// lecture). Piloté par l'UI pour savoir si elle doit afficher l'état
  /// "live" (flux réels du lecteur : position, durée, play/pause) ou un
  /// simple "aperçu" statique (piste 1 ou reprise, à 0 ou à la position
  /// sauvegardée, sans lecture).
  bool get isSelectedThemeLoaded {
    if (selectedProfessor == null || selectedTheme == null) return false;
    if (_loadedProfessor == null || _loadedTheme == null) return false;
    return selectedProfessor!.key == _loadedProfessor!.key &&
        selectedTheme!.name == _loadedTheme!.name;
  }

  // Dernier thème lu (pour WelcomePane)
  PlaybackState? lastPlaybackState;

  final Set<String> expandedProfs = {};
  final Map<String, DownloadState> downloadStates = {};

  double playbackSpeed = 1.0;
  double volume        = 1.0;

  /// État de la boucle du lecteur, cycle à 3 positions (voir [toggleLoop]) :
  ///   off → une seule piste ne se répète pas, la lecture avance normalement
  ///   one → la piste en cours se répète en boucle
  ///   all → tout le thème (toutes ses pistes) se répète en boucle
  LoopMode loopMode = LoopMode.off;

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
        if (index == null) return;
        // Ne synchroniser le pointeur affiché QUE si le thème affiché est
        // bien celui réellement chargé (mode "live") — sinon on écraserait
        // le pointeur d'aperçu d'un thème simplement consulté à l'écran.
        if (isSelectedThemeLoaded && index != currentTrackIndex) {
          currentTrackIndex = index;
          notifyListeners();
        }
        // La sauvegarde de position suit TOUJOURS le thème réellement
        // chargé dans le lecteur (_savePosition s'appuie sur
        // _loadedProfessor/_loadedTheme, pas sur la sélection affichée).
        _savePosition(positionMs: 0);
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

      await _syncProfessorsInfo();

      lastPlaybackState = await _persistence.loadLast();
      state = AppState.ready;
    } catch (e) {
      state        = AppState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  // ── Professeurs (infos + photos dynamiques) ─────────────────────────────

  /// Récupère profs_infos.json, télécharge les photos manquantes, et — si
  /// le catalogue a changé depuis la dernière fois (nouveau prof, rôle
  /// modifié, photo remplacée) — resynchronise entièrement les photos.
  /// Fusionne ensuite le tout sur [professors] et trie par ordre défini.
  Future<void> _syncProfessorsInfo() async {
    try {
      final result = await _professorsService.loadProfessorsInfo();

      if (result.changed) {
        await _professorsService.refreshImages(result.infos);
      } else {
        await _professorsService.ensureImages(result.infos);
      }

      await _professorsService.applyInfos(professors, result.infos);
      professors.sort((a, b) => a.order != b.order
          ? a.order.compareTo(b.order)
          : a.name.compareTo(b.name));
    } catch (e) {
      // Non bloquant : les profs gardent leurs valeurs par défaut
      // (rôle "Enseignements", photo embarquée) si la synchronisation échoue.
      debugPrint('[AppProvider] Synchronisation profs_infos.json échouée: $e');
    }
  }

  /// Force une resynchronisation complète des infos + photos profs
  /// (ex : bouton "Actualiser" dans l'UI). Contrairement au flux normal
  /// d'[init], ceci retélécharge toutes les photos même si le hash du
  /// catalogue n'a pas changé.
  Future<void> refreshProfessorsInfo() async {
    try {
      final result = await _professorsService.loadProfessorsInfo();
      await _professorsService.refreshImages(result.infos);
      await _professorsService.applyInfos(professors, result.infos);
      professors.sort((a, b) => a.order != b.order
          ? a.order.compareTo(b.order)
          : a.name.compareTo(b.name));
    } catch (e) {
      debugPrint('[AppProvider] Actualisation profs_infos.json échouée: $e');
    }
    notifyListeners();
  }

  // ── Persistance ───────────────────────────────────────────────────────

  void _savePosition({int? positionMs}) {
    // Toujours le thème RÉELLEMENT chargé dans le lecteur (celui qui joue),
    // jamais celui simplement affiché/consulté (aperçu) — voir
    // [isSelectedThemeLoaded].
    final prof  = _loadedProfessor;
    final theme = _loadedTheme;
    if (prof == null || theme == null) return;
    _persistence.save(
      profKey:    prof.key,
      profName:   prof.name,
      themeName:  theme.name,
      // Utiliser l'index RÉEL du lecteur (pas `currentTrackIndex`, qui peut
      // refléter le pointeur d'aperçu d'un thème différent actuellement
      // consulté à l'écran) pour ne jamais corrompre la sauvegarde du
      // thème réellement en train de jouer.
      trackIndex: audioService.currentIndex ?? currentTrackIndex,
      positionMs: positionMs ?? audioService.position.inMilliseconds,
    );
  }

  void _checkCompletion(Duration pos) {
    final theme = _loadedTheme;
    final prof  = _loadedProfessor;
    if (theme == null || prof == null) return;
    final dur = audioService.duration;
    if (dur == null || dur.inSeconds == 0) return;
    final isLastTrack = (audioService.currentIndex ?? currentTrackIndex) ==
        theme.tracks.length - 1;
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

  // ── Sélection thème (aperçu — ne touche jamais au lecteur) ─────────────
  //
  // Ouvrir un thème depuis le sidebar (ou ailleurs) ne fait QUE changer ce
  // qui est affiché à l'écran : piste 1 (si aucune reprise possible) ou
  // dernière piste/position sauvegardée (si reprise possible), SANS jamais
  // charger ni lire quoi que ce soit dans le lecteur. Une lecture en cours
  // continue donc sans interruption tant que l'utilisateur n'appuie pas
  // explicitement sur Play ([commitAndPlay]).
  //
  // Exception : si le thème ouvert est justement celui déjà chargé dans le
  // lecteur (potentiellement en cours de lecture), on se "raccroche" à son
  // état réel (piste courante réelle) au lieu de recalculer un aperçu —
  // l'utilisateur retrouve alors sa lecture intacte (position, état,
  // sélection).

  Future<void> selectTheme(Professor prof, AudioTheme theme) async {
    final alreadySelected = selectedProfessor?.key == prof.key &&
        selectedTheme?.name == theme.name;
    if (alreadySelected) return;

    selectedProfessor = prof;
    selectedTheme     = theme;

    final isLoadedTheme = _loadedProfessor?.key == prof.key &&
        _loadedTheme?.name == theme.name;

    if (isLoadedTheme) {
      // Thème déjà chargé dans le lecteur → on affiche son état réel.
      currentTrackIndex = audioService.currentIndex ?? 0;
      previewPositionMs = 0; // non utilisé en mode live
    } else {
      // Nouveau thème : calcule le point de départ (reprise ou piste 1)
      // SANS toucher au lecteur.
      final saved = await _persistence.loadForTheme(prof.key, theme.name);
      if (saved != null && !saved.completed && saved.hasProgress) {
        currentTrackIndex = saved.trackIndex.clamp(0, theme.tracks.isEmpty ? 0 : theme.tracks.length - 1);
        previewPositionMs = saved.positionMs;
      } else {
        currentTrackIndex = 0;
        previewPositionMs = 0;
      }
    }

    notifyListeners();
  }

  /// Réinitialise la progression du thème AFFICHÉ (piste 1, position 0),
  /// sans démarrer la lecture. Si ce thème est celui réellement chargé
  /// (potentiellement en cours de lecture), le lecteur est repositionné en
  /// direct au tout début — sans couper la lecture si elle tournait.
  Future<void> restartTheme() async {
    final prof  = selectedProfessor;
    final theme = selectedTheme;
    if (prof == null || theme == null) return;

    await _persistence.save(
      profKey: prof.key, profName: prof.name,
      themeName: theme.name, trackIndex: 0, positionMs: 0,
    );

    currentTrackIndex = 0;
    previewPositionMs = 0;

    if (isSelectedThemeLoaded) {
      await audioService.seekToIndex(0);
      await audioService.seekTo(Duration.zero);
    }

    lastPlaybackState = await _persistence.loadLast();
    notifyListeners();
  }

  // ── Lecture (seul point d'entrée qui charge/démarre le lecteur) ────────

  /// Démarre (ou reprend) la lecture du thème actuellement AFFICHÉ, à la
  /// piste/position déjà déterminée par [selectTheme] (ou par
  /// [selectTrack]).
  ///
  /// Retourne :
  ///   null              → lecture démarrée/reprise avec succès
  ///   'offline_theme'   → hors-ligne, aucun audio local pour ce thème
  Future<String?> commitAndPlay() async {
    final prof  = selectedProfessor;
    final theme = selectedTheme;
    if (prof == null || theme == null) return null;

    // Déjà chargé (typiquement en pause) → simple reprise, pas de rechargement.
    if (isSelectedThemeLoaded) {
      await audioService.play();
      notifyListeners();
      return null;
    }

    // Vérification hors-ligne (seulement au moment de vraiment charger/lire)
    if (!theme.isFullyAvailableOffline) {
      final hasAnyLocal = theme.tracks.any((t) => t.isAvailableLocally);
      if (!hasAnyLocal) {
        final connected = await connectivityService.hasConnection();
        if (!connected) return 'offline_theme';
      }
    }

    _loadedProfessor = prof;
    _loadedTheme     = theme;

    if (theme.tracks.isNotEmpty) {
      await audioService.loadTheme(
        theme,
        startIndex: currentTrackIndex,
        startPosition: Duration(milliseconds: previewPositionMs),
        professor: prof,
      );
    }

    lastPlaybackState = await _persistence.loadLast();
    notifyListeners();
    return null;
  }

  /// Sélectionne un thème à une piste/position précises PUIS démarre
  /// immédiatement la lecture — utilisé par les actions explicites de type
  /// "Reprendre à HH:MM" (ex: carte de reprise sur l'écran d'accueil), où
  /// l'intention de lecture immédiate est déjà exprimée par le bouton.
  Future<String?> confirmResume(
      Professor prof, AudioTheme theme, int trackIndex, int positionMs) async {
    selectedProfessor = prof;
    selectedTheme     = theme;
    currentTrackIndex = trackIndex;
    previewPositionMs = positionMs;
    notifyListeners();
    return commitAndPlay();
  }

  // ── Sélection piste ──────────────────────────────────────────────────

  /// Change la piste du thème AFFICHÉ.
  /// - Mode "live" (thème affiché = thème réellement chargé) : comportement
  ///   inchangé — vérifie la disponibilité hors-ligne puis "seek" en direct
  ///   dans le lecteur.
  /// - Mode "aperçu" (thème pas encore chargé) : déplace uniquement le
  ///   pointeur d'aperçu, sans vérification ni action sur le lecteur —
  ///   rien n'est chargé, donc rien à interrompre ni à streamer.
  /// Change/lance la piste du thème AFFICHÉ. Taper sur une piste de la
  /// liste est TOUJOURS synonyme de Play — y compris en mode "live" :
  /// - Mode "live" (thème déjà chargé) : seek vers la piste (si différente
  ///   de l'actuelle) puis s'assure que la lecture tourne (reprend si en
  ///   pause). Taper la piste déjà courante relance juste la lecture si
  ///   elle était en pause.
  /// - Mode "aperçu" (thème pas encore chargé) : sélectionne cette piste
  ///   PUIS démarre réellement la lecture via [commitAndPlay] (c'est cet
  ///   appel qui charge le lecteur, vérifie la disponibilité hors-ligne,
  ///   etc.).
  Future<String?> selectTrack(int index) async {
    final theme = selectedTheme;
    final prof  = selectedProfessor;
    if (theme == null || prof == null) return null;
    if (index < 0 || index >= theme.tracks.length) return null;

    if (isSelectedThemeLoaded) {
      if (currentTrackIndex != index) {
        final track = theme.tracks[index];
        if (!track.isAvailableLocally) {
          final connected = await connectivityService.hasConnection();
          if (!connected) {
            return 'Pas de connexion internet.\n'
                'Téléchargez les audios pour les écouter hors-ligne.';
          }
        }
        currentTrackIndex = index;
        await audioService.seekToIndex(index);
        _savePosition(positionMs: 0);
      }
      if (!audioService.isPlaying) {
        await audioService.play();
      }
      notifyListeners();
      return null;
    }

    // Aperçu : sélectionner cette piste puis démarrer réellement la
    // lecture (commitAndPlay gère le chargement + la vérif hors-ligne).
    currentTrackIndex = index;
    previewPositionMs = 0;
    notifyListeners();
    return commitAndPlay();
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
    // Ne recharger le lecteur EN DIRECT que si ce thème est vraiment celui
    // chargé dans le lecteur (potentiellement en cours de lecture) — pas
    // seulement celui affiché/consulté à l'écran (aperçu).
    if (isSelectedThemeLoaded && selectedTheme?.name == theme.name) {
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
    // Cf. downloadTheme() : seulement si réellement chargé dans le lecteur.
    if (isSelectedThemeLoaded && selectedTheme?.name == theme.name) {
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

  /// Fait avancer la boucle d'un cran dans le cycle à 3 positions :
  /// off → one (piste courante) → all (thème complet) → off → ...
  Future<void> toggleLoop() async {
    loopMode = switch (loopMode) {
      LoopMode.off => LoopMode.one,
      LoopMode.one => LoopMode.all,
      LoopMode.all => LoopMode.off,
      _            => LoopMode.off,
    };
    await audioService.setLoopMode(loopMode);
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
