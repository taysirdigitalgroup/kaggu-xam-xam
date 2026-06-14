// lib/utils/constants.dart

class AppConstants {
  // ── Dépôt distant ────────────────────────────────────────────────────
  /// URL racine du dépôt GitHub (raw) contenant les fichiers de données.
  static const String repoBaseUrl =
      'https://raw.githubusercontent.com/TaysirDigitalGroup/kaggu-xam-xam-data/main';

  /// URL du fichier catalogue JSON dans le dépôt
  static const String bibliothequeRemoteUrl = '$repoBaseUrl/bibliotheque.json';

  /// URL racine des fichiers audio dans le dépôt
  /// Structure : /audio/<prof_key>/<theme_key>/<fichier>.ogg
  static const String audioBaseUrl = '$repoBaseUrl/audio';

  // ── AdMob ─────────────────────────────────────────────────────────────
  static const String admobAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  // ── Timings ────────────────────────────────────────────────────────────
  static const int interstitialCooldownSeconds = 180;

  // ── Clés SharedPreferences ─────────────────────────────────────────────
  static const String prefBiblioHash = 'biblio_hash';
  static const String prefLastAdTime = 'last_interstitial_time';

  // ── Noms de fichiers locaux ────────────────────────────────────────────
  static const String localBiblioFilename = 'bibliotheque.json';

  // ── Répertoire audio local (dans getApplicationDocumentsDirectory) ─────
  static const String audioLocalDir = 'audio';

  // ── Préfixe assets audio embarqués ────────────────────────────────────
  /// Chemin asset embarqué : assets/audios/<prof_key>/<filename>
  /// Note : les thèmes ne sont PAS dans le sous-dossier du thème dans les assets
  /// pour garder une structure plate par prof dans le bundle.
  static const String bundledAudioPrefix = 'assets/audios';

  // ── App info ───────────────────────────────────────────────────────────
  static const String appName = 'Kaggu Xam Xam';
  static const String appVersion = '1.0.0';
  static const String appDeveloper = 'Aliou Mbengue';
  static const String appCompany = 'Taysir Digital Group (TDG)';
  static const String appSlogan = 'Vos rêves, nos défis';
  static const String contactPhone1 = '+221 76 455 03 58';
  static const String contactPhone1Raw = '+221764550358';
  static const String contactPhone2 = '+221 77 664 70 80';
  static const String contactPhone2Raw = '+221776647080';
  static const String contactEmail = 'taysirdigitalgroup@gmail.com';
  static const String paypalUrl = 'https://paypal.me/MBENGUE28';
  static const String waveUrl = 'https://pay.wave.com/m/M_sn_DoZfd98ruV_6/c/sn/';

  // ── Couleurs ───────────────────────────────────────────────────────────
  static const int colorNavy = 0xFF0D2B5E;
  static const int colorGold = 0xFFC8982A;
  static const int colorGoldLight = 0xFFF0C84A;
}
