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

  /// Image de repli embarquée dans l'APK : assets/images/<key>.jpg
  /// Utilisée tant que la photo distante n'a pas encore été téléchargée,
  /// ou si le prof n'a pas (ou plus) d'entrée dans profs_infos.json.
  final String imagePath;

  /// Chemin du fichier local téléchargé depuis professors/profils/
  /// (prioritaire sur [imagePath] si non nul et existant sur le disque).
  /// Renseigné dynamiquement par ProfessorsService après synchronisation.
  String? localImagePath;

  /// Rôle affiché sous le nom, ex: "Enseignements", "Histoires", "Conférences".
  /// Valeur par défaut si le prof est absent de profs_infos.json.
  String role;

  /// Ordre d'affichage dans la liste (plus petit = affiché en premier).
  /// Valeur par défaut élevée pour reléguer en fin de liste les profs
  /// non (encore) décrits dans profs_infos.json.
  int order;

  final List<AudioTheme> themes;

  Professor({
    required this.name,
    required this.key,
    required this.imagePath,
    this.localImagePath,
    this.role = 'Enseignements',
    this.order = 999,
    required this.themes,
  });
}
