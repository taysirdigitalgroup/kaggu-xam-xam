// lib/utils/constants.dart
class AppConstants {
  // ══════════════════════════════════════════════════════════════════════
  // DÉPÔT DISTANT  — seul endroit à modifier pour changer le dépôt
  // ══════════════════════════════════════════════════════════════════════
  static const String repoOwner  = 'taysirdigitalgroup';
  static const String repoName   = 'kaggu-xam-xam-data';
  static const String repoBranch = 'main';

  static const String repoBaseUrl =
      'https://raw.githubusercontent.com/$repoOwner/$repoName/$repoBranch';

  static const String bibliothequeRemoteUrl = '$repoBaseUrl/bibliotheque.json';

  /// URL racine des audios : $audioBaseUrl/<profKey>/<themeKey>/<filename>
  static const String audioBaseUrl = '$repoBaseUrl/audios';

  // ══════════════════════════════════════════════════════════════════════
  // ASSETS EMBARQUÉS & STOCKAGE LOCAL
  // ══════════════════════════════════════════════════════════════════════

  /// Préfixe assets audio dans le bundle Flutter : assets/audios/…
  static const String bundledAudioPrefix = 'assets/audios';

  /// Sous-dossier dans Documents pour les audios téléchargés : audios/…
  static const String audioLocalDir = 'audios';

  /// Nom du fichier catalogue sauvegardé localement
  static const String localBiblioFilename = 'bibliotheque.json';

  // ══════════════════════════════════════════════════════════════════════
  // ADMOB  (IDs de test — remplacer par les vrais en production)
  // ══════════════════════════════════════════════════════════════════════
  static const String admobAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  // ══════════════════════════════════════════════════════════════════════
  // TIMINGS & RÉSEAU
  // ══════════════════════════════════════════════════════════════════════
  static const int interstitialCooldownSeconds = 180; // 3 min entre 2 pubs

  static const int connectTimeoutSec      = 15;  // timeout connexion
  static const int biblioReceiveTimeoutSec = 20; // timeout réception JSON
  static const int audioReceiveTimeoutMin  = 15; // timeout réception audio
  static const int downloadMaxRetries      = 3;  // tentatives avant abandon

  // ══════════════════════════════════════════════════════════════════════
  // CLÉS SHAREDPREFERENCES
  // ══════════════════════════════════════════════════════════════════════
  static const String prefBiblioHash      = 'biblio_hash';
  static const String prefLastAdTime      = 'last_interstitial_time';
  static const String prefDeployedVersion = 'assets_deployed_version';

  // ══════════════════════════════════════════════════════════════════════
  // INFORMATIONS APP
  // ══════════════════════════════════════════════════════════════════════
  static const String appName      = 'Kaggu Xam Xam';
  static const String appVersion   = '1.0.0';
  static const String appDeveloper = 'Aliou Mbengue';
  static const String appCompany   = 'Taysir Digital Group (TDG)';
  static const String appSlogan    = 'Vos rêves, nos défis';

  static const String contactPhone1    = '+221 76 455 03 58';
  static const String contactPhone1Raw = '+221764550358';
  static const String contactPhone2    = '+221 77 664 70 80';
  static const String contactPhone2Raw = '+221776647080';
  static const String contactEmail     = 'taysirdigitalgroup@gmail.com';
  static const String paypalUrl        = 'https://paypal.me/MBENGUE28';
  static const String waveUrl =
      'https://pay.wave.com/m/M_sn_DoZfd98ruV_6/c/sn/';

  // ══════════════════════════════════════════════════════════════════════
  // COULEURS
  // ══════════════════════════════════════════════════════════════════════
  static const int colorNavy      = 0xFF0D2B5E;
  static const int colorGold      = 0xFFC8982A;
  static const int colorGoldLight = 0xFFF0C84A;
}
