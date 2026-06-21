// lib/models/models.dart

class AudioTrack {
  final String filename;
  final String profKey;
  final String themeKey;
  bool isDownloaded;
  bool isBundled;
  double downloadProgress;

  AudioTrack({
    required this.filename,
    required this.profKey,
    required this.themeKey,
    this.isDownloaded     = false,
    this.isBundled        = false,
    this.downloadProgress = 0.0,
  });

  bool get isAvailableLocally => isDownloaded || isBundled;
}

class AudioTheme {
  final String name;
  final String profKey;
  final List<AudioTrack> tracks;

  AudioTheme({
    required this.name,
    required this.profKey,
    required this.tracks,
  });

  int get downloadedCount       => tracks.where((t) => t.isDownloaded).length;
  int get bundledCount          => tracks.where((t) => t.isBundled).length;
  int get availableOfflineCount => tracks.where((t) => t.isAvailableLocally).length;

  bool get hasLocalDownloads         => downloadedCount > 0;
  bool get isBundledOnly             => bundledCount == tracks.length && downloadedCount == 0;
  bool get isFullyAvailableOffline   => tracks.isNotEmpty && tracks.every((t) => t.isAvailableLocally);
  bool get isPartiallyAvailableOffline => availableOfflineCount > 0 && !isFullyAvailableOffline;
  bool get isFullyDownloaded         => tracks.isNotEmpty && tracks.every((t) => t.isDownloaded);
  bool get isPartiallyDownloaded     => downloadedCount > 0 && !isFullyDownloaded;
  bool get hasEmbeddedTracks         => bundledCount > 0;
  bool get isFullyEmbedded           => tracks.isNotEmpty && tracks.every((t) => t.isBundled);

  List<AudioTrack> get downloadableTracks    => tracks.where((t) => !t.isAvailableLocally).toList();
  List<AudioTrack> get notYetDownloadedTracks => tracks.where((t) => !t.isDownloaded).toList();
}

class Professor {
  final String name;
  final String key;
  final String imagePath; // chemin asset local : assets/images/<slug>.jpg
  final String role;      // ex: "Enseignements", "Histoires", "Conférences"
  final List<AudioTheme> themes;

  Professor({
    required this.name,
    required this.key,
    required this.imagePath,
    required this.role,
    required this.themes,
  });
}
