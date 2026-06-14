// lib/models/models.dart

/// Un fichier audio avec son état de téléchargement et sa source
class AudioTrack {
  final String filename;
  final String profKey;
  final String themeKey;
  bool isDownloaded;       // présent dans le stockage local (documents)
  bool isBundled;          // présent dans les assets embarqués
  double downloadProgress; // 0.0 → 1.0

  AudioTrack({
    required this.filename,
    required this.profKey,
    required this.themeKey,
    this.isDownloaded = false,
    this.isBundled = false,
    this.downloadProgress = 0.0,
  });

  String get localPath => '$profKey/$themeKey/$filename';

  /// Vrai si l'audio est disponible hors-ligne (local ou bundled)
  bool get isAvailableOffline => isDownloaded || isBundled;
}

/// Un thème (ensemble d'audios)
class AudioTheme {
  final String name;
  final String profKey;
  final List<AudioTrack> tracks;

  AudioTheme({
    required this.name,
    required this.profKey,
    required this.tracks,
  });

  bool get isFullyDownloaded =>
      tracks.isNotEmpty && tracks.every((t) => t.isDownloaded);

  bool get isPartiallyDownloaded =>
      tracks.any((t) => t.isDownloaded) && !isFullyDownloaded;

  bool get isFullyAvailableOffline =>
      tracks.isNotEmpty && tracks.every((t) => t.isAvailableOffline);

  bool get isFullyBundled =>
      tracks.isNotEmpty && tracks.every((t) => t.isBundled);

  int get downloadedCount => tracks.where((t) => t.isDownloaded).length;
  int get bundledCount => tracks.where((t) => t.isBundled).length;
  int get availableOfflineCount => tracks.where((t) => t.isAvailableOffline).length;

  /// Le thème a au moins un audio local (téléchargé, pas seulement bundled)
  bool get hasLocalDownloads => tracks.any((t) => t.isDownloaded);

  /// Thème entièrement géré via les assets embarqués (aucun téléchargement)
  bool get isBundledOnly => isFullyBundled && !hasLocalDownloads;
}

/// Un professeur avec ses thèmes
class Professor {
  final String name;
  final String key; // slug utilisé pour les chemins
  final String imagePath; // asset local
  final List<AudioTheme> themes;

  Professor({
    required this.name,
    required this.key,
    required this.imagePath,
    required this.themes,
  });
}
