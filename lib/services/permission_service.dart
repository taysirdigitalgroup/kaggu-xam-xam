// lib/services/permission_service.dart
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// Gère la demande de permissions de stockage nécessaires pour télécharger
/// et organiser les audios dans des dossiers locaux (prof/thème).
///
/// Sur Android 13+ (API 33+), l'accès aux fichiers audio applicatifs dans
/// getApplicationDocumentsDirectory() ne nécessite techniquement aucune
/// permission runtime (stockage privé à l'app). On demande néanmoins
/// Permission.storage de façon proactive pour couvrir les anciennes
/// versions d'Android (≤ 12 / API 32) où l'écriture peut être restreinte,
/// et pour anticiper un usage futur du stockage partagé.
class PermissionService {
  /// Demande la permission de stockage si nécessaire (Android ≤ 12).
  /// Sur Android 13+, retourne directement true (non requis pour le
  /// stockage privé de l'app utilisé ici).
  Future<bool> requestStorageIfNeeded() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.storage.status;
    if (status.isGranted) return true;

    final result = await Permission.storage.request();
    return result.isGranted;
  }

  /// Vrai si la permission de stockage a déjà été accordée
  Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;
    return (await Permission.storage.status).isGranted;
  }

  /// Vrai si l'utilisateur a définitivement refusé (ne plus demander)
  Future<bool> isPermanentlyDenied() async {
    if (!Platform.isAndroid) return false;
    return (await Permission.storage.status).isPermanentlyDenied;
  }

  /// Ouvre les paramètres de l'application (si refus permanent)
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
