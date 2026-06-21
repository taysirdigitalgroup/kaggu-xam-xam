// lib/services/connectivity_service.dart
//
// Service léger pour vérifier la connectivité réseau avant de tenter
// une lecture en streaming ou un téléchargement.
//
// Note : connectivity_plus détecte la présence d'une interface réseau
// (WiFi/mobile), pas nécessairement l'accès à Internet.
// Pour nos besoins (lecture GitHub Raw), c'est suffisant.

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Retourne true si au moins une interface réseau est disponible.
  Future<bool> hasConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  /// Stream des changements de connectivité (pour réagir en temps réel).
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;
}
