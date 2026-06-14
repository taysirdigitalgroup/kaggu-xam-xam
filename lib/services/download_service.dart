// lib/services/download_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../utils/constants.dart';

typedef ProgressCallback = void Function(int downloaded, int total);

class DownloadService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 10),
  ));

  // ── Chemins ───────────────────────────────────────────────────────────

  /// Répertoire racine des audios téléchargés (stockage local permanent)
  Future<Directory> get audioRootDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/${AppConstants.audioLocalDir}');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Chemin local complet pour un track (dans documents)
  Future<String> localPathFor(AudioTrack track) async {
    final root = await audioRootDir;
    return '${root.path}/${track.profKey}/${track.themeKey}/${track.filename}';
  }

  /// Chemin asset embarqué pour un track
  /// Structure : assets/audios/<prof_key>/<theme_key>/<filename>
  String bundledAssetPathFor(AudioTrack track) {
    return '${AppConstants.bundledAudioPrefix}/${track.profKey}/${track.themeKey}/${track.filename}';
  }

  // ── Vérifications de disponibilité ────────────────────────────────────

  /// Vérifie si un track est présent dans le stockage local (documents)
  Future<bool> isDownloaded(AudioTrack track) async {
    final path = await localPathFor(track);
    return File(path).existsSync();
  }

  /// Vérifie si un track est disponible dans les assets embarqués
  Future<bool> isBundled(AudioTrack track) async {
    try {
      await rootBundle.load(bundledAssetPathFor(track));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Vérifie et met à jour le statut complet de tous les tracks d'un thème
  Future<void> refreshDownloadStatus(AudioTheme theme) async {
    for (final track in theme.tracks) {
      track.isDownloaded = await isDownloaded(track);
      if (!track.isDownloaded) {
        track.isBundled = await isBundled(track);
      } else {
        // Si téléchargé en local, la version bundled est secondaire
        track.isBundled = await isBundled(track);
      }
    }
  }

  // ── URLs et URI de lecture ─────────────────────────────────────────────

  /// URL distante d'un fichier audio
  String remoteUrlFor(AudioTrack track) {
    return '${AppConstants.audioBaseUrl}/${track.profKey}/${track.themeKey}/${track.filename}';
  }

  /// Retourne l'URI utilisable par just_audio selon la priorité :
  /// 1. Stockage local (téléchargé) → file://
  /// 2. Asset embarqué              → asset://
  /// 3. Streaming distant           → https://
  Future<String> getPlayableUri(AudioTrack track) async {
    // Priorité 1 : audio téléchargé en local
    if (await isDownloaded(track)) {
      return 'file://${await localPathFor(track)}';
    }
    // Priorité 2 : audio embarqué dans le bundle
    if (await isBundled(track)) {
      return 'asset:///${bundledAssetPathFor(track)}';
    }
    // Priorité 3 : streaming distant
    return remoteUrlFor(track);
  }

  // ── Téléchargement ────────────────────────────────────────────────────

  /// Télécharge tous les audios manquants d'un thème
  Future<void> downloadTheme({
    required AudioTheme theme,
    required void Function(AudioTrack track, double progress) onTrackProgress,
    required void Function(AudioTrack track) onTrackDone,
    required void Function(String error) onError,
    CancelToken? cancelToken,
  }) async {
    for (final track in theme.tracks) {
      if (track.isDownloaded) continue; // déjà en local → skip
      if (cancelToken?.isCancelled == true) break;

      final localPath = await localPathFor(track);
      final localFile = File(localPath);
      await localFile.parent.create(recursive: true);

      try {
        await _dio.download(
          remoteUrlFor(track),
          localPath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              onTrackProgress(track, received / total);
            }
          },
        );
        track.isDownloaded = true;
        track.downloadProgress = 1.0;
        onTrackDone(track);
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) break;
        onError('Erreur téléchargement ${track.filename}: ${e.message}');
      }
    }
  }

  // ── Rafraîchissement (delete-diff) ────────────────────────────────────

  /// Rafraîchit les audios locaux d'un thème depuis le dépôt distant.
  ///
  /// Règle delete-diff :
  /// - Les fichiers présents en local mais absents de [theme.tracks] (liste distante)
  ///   sont supprimés.
  /// - Les fichiers présents dans [theme.tracks] mais absents en local sont téléchargés.
  /// - Les fichiers identiques (même nom) sont ignorés (pas de re-téléchargement).
  Future<void> refreshTheme({
    required AudioTheme theme,
    required void Function(AudioTrack track, double progress) onTrackProgress,
    required void Function(AudioTrack track) onTrackDone,
    required void Function(String deletedFilename) onTrackDeleted,
    required void Function(String error) onError,
    CancelToken? cancelToken,
  }) async {
    final root = await audioRootDir;
    final themeLocalDir = Directory(
        '${root.path}/${theme.profKey}/${theme.tracks.first.themeKey}');

    // 1. Liste des fichiers actuellement en local pour ce thème
    final Set<String> localFiles = {};
    if (await themeLocalDir.exists()) {
      await for (final entity in themeLocalDir.list()) {
        if (entity is File) {
          localFiles.add(entity.uri.pathSegments.last);
        }
      }
    }

    // 2. Liste des fichiers attendus (depuis la bibliothèque distante)
    final Set<String> expectedFiles =
        theme.tracks.map((t) => t.filename).toSet();

    // 3. Supprimer les fichiers locaux qui ne sont plus dans la liste distante
    final toDelete = localFiles.difference(expectedFiles);
    for (final filename in toDelete) {
      final f = File('${themeLocalDir.path}/$filename');
      try {
        await f.delete();
        onTrackDeleted(filename);
      } catch (e) {
        onError('Erreur suppression $filename: $e');
      }
    }

    // 4. Télécharger les fichiers manquants
    final toDownload =
        theme.tracks.where((t) => !localFiles.contains(t.filename)).toList();

    for (final track in toDownload) {
      if (cancelToken?.isCancelled == true) break;

      final localPath = await localPathFor(track);
      final localFile = File(localPath);
      await localFile.parent.create(recursive: true);

      try {
        await _dio.download(
          remoteUrlFor(track),
          localPath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              onTrackProgress(track, received / total);
            }
          },
        );
        track.isDownloaded = true;
        track.downloadProgress = 1.0;
        onTrackDone(track);
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) break;
        onError('Erreur téléchargement ${track.filename}: ${e.message}');
      }
    }

    // 5. Mettre à jour les tracks déjà en local (qui n'ont pas été re-téléchargés)
    for (final track in theme.tracks) {
      if (!toDownload.contains(track)) {
        track.isDownloaded = expectedFiles.contains(track.filename) &&
            localFiles.contains(track.filename);
      }
    }
  }

  // ── Suppression ───────────────────────────────────────────────────────

  /// Supprime tous les audios locaux d'un thème
  Future<void> deleteTheme(AudioTheme theme) async {
    final root = await audioRootDir;
    if (theme.tracks.isEmpty) return;
    final themeDir = Directory(
        '${root.path}/${theme.profKey}/${theme.tracks.first.themeKey}');
    if (await themeDir.exists()) {
      await themeDir.delete(recursive: true);
    }
    for (final track in theme.tracks) {
      track.isDownloaded = false;
      track.downloadProgress = 0.0;
    }
  }
}
