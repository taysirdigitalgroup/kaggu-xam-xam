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

  /// URL du catalogue distant des informations professeurs
  /// (nom, rôle, photo, ordre d'affichage) : dossier "professors/" du dépôt.
  static const String professorsInfosRemoteUrl =
      '$repoBaseUrl/professors/profs_infos.json';

  /// URL racine des photos de profs : $professorsProfilsBaseUrl/<filename>
  static const String professorsProfilsBaseUrl =
      '$repoBaseUrl/professors/profils';

  // ══════════════════════════════════════════════════════════════════════
  // ASSETS EMBARQUÉS & STOCKAGE LOCAL
  // ══════════════════════════════════════════════════════════════════════

  /// Préfixe assets audio dans le bundle Flutter : assets/audios/…
  static const String bundledAudioPrefix = 'assets/audios';

  /// Sous-dossier dans Documents pour les audios téléchargés : audios/…
  static const String audioLocalDir = 'audios';

  /// Nom du fichier catalogue sauvegardé localement
  static const String localBiblioFilename = 'bibliotheque.json';

  /// Sous-dossier dans Documents pour les photos de profs téléchargées
  static const String professorsImagesLocalDir = 'professors/profils';

  /// Nom du fichier catalogue profs_infos sauvegardé localement
  static const String localProfsInfosFilename = 'profs_infos.json';

  // ══════════════════════════════════════════════════════════════════════
  // TIMINGS & RÉSEAU
  // ══════════════════════════════════════════════════════════════════════
  static const int connectTimeoutSec      = 15;  // timeout connexion
  static const int biblioReceiveTimeoutSec = 20; // timeout réception JSON
  static const int audioReceiveTimeoutMin  = 15; // timeout réception audio
  static const int downloadMaxRetries      = 3;  // tentatives avant abandon

  // ══════════════════════════════════════════════════════════════════════
  // CLÉS SHAREDPREFERENCES
  // ══════════════════════════════════════════════════════════════════════
  static const String prefBiblioHash      = 'biblio_hash';
  static const String prefDeployedVersion = 'assets_deployed_version';
  static const String prefProfsInfosHash  = 'profs_infos_hash';

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
