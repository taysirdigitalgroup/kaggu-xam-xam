// lib/services/download_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/string_utils.dart';

class DownloadService {
  late final Dio _dio;

  DownloadService() {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(seconds: AppConstants.connectTimeoutSec),
      receiveTimeout: Duration(minutes: AppConstants.audioReceiveTimeoutMin),
      followRedirects: true,
      maxRedirects: 5,
      headers: {
        'User-Agent': 'KagguXamXam/${AppConstants.appVersion}',
        'Cache-Control': 'no-cache',
      },
    ));
  }

  // ── Répertoires ──────────────────────────────────────────────────────

  Future<Directory> get _audioRootDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/${AppConstants.audioLocalDir}');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Chemins ──────────────────────────────────────────────────────────

  /// Chemin local complet : <docs>/audios/<profKey>/<themeKey>/<filename>
  Future<String> localPathFor(AudioTrack track) async {
    final root = await _audioRootDir;
    return '${root.path}/${track.profKey}/${track.themeKey}/${track.filename}';
  }

  /// Chemin asset embarqué : assets/audios/<profKey>/<themeKey>/<filename>
  String bundledAssetPathFor(AudioTrack track) =>
      '${AppConstants.bundledAudioPrefix}'
      '/${track.profKey}/${track.themeKey}/${track.filename}';

  /// URL GitHub Raw : .../audios/<profKey>/<themeKey>/<filename>
  String remoteUrlFor(AudioTrack track) =>
      '${AppConstants.audioBaseUrl}'
      '/${track.profKey}/${track.themeKey}/${track.filename}';

  // ── Vérifications de disponibilité ──────────────────────────────────

  Future<bool> isDownloaded(AudioTrack track) async {
    final path = await localPathFor(track);
    return File(path).existsSync();
  }

  Future<bool> isBundled(AudioTrack track) async {
    try {
      await rootBundle.load(bundledAssetPathFor(track));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refreshDownloadStatus(AudioTheme theme) async {
    for (final track in theme.tracks) {
      track.isDownloaded = await isDownloaded(track);
      track.isBundled    = await isBundled(track);
    }
  }

  // ── URI de lecture ───────────────────────────────────────────────────

  /// Retourne l'URI à passer à just_audio :
  ///   1. file:///   → téléchargé dans Documents
  ///   2. asset:///  → embarqué dans l'APK
  ///   3. https://   → streaming GitHub Raw
  Future<String> getPlayableUri(AudioTrack track) async {
    if (await isDownloaded(track)) {
      return 'file://${await localPathFor(track)}';
    }
    if (await isBundled(track)) {
      return 'asset:///${bundledAssetPathFor(track)}';
    }
    return remoteUrlFor(track);
  }

  // ── Création des dossiers ────────────────────────────────────────────

  Future<void> ensureCatalogDirectories(List<Professor> professors) async {
    final root = await _audioRootDir;
    for (final prof in professors) {
      for (final theme in prof.themes) {
        final themeKey = theme.tracks.isNotEmpty
            ? theme.tracks.first.themeKey
            : toSlug(theme.name);
        final dir = Directory('${root.path}/${prof.key}/$themeKey');
        if (!await dir.exists()) await dir.create(recursive: true);
      }
    }
  }

  // ── Téléchargement avec retry ────────────────────────────────────────

  Future<void> _downloadOneTrack({
    required AudioTrack track,
    required CancelToken? cancelToken,
    required void Function(AudioTrack, double) onProgress,
    required void Function(AudioTrack) onDone,
    required void Function(String) onError,
  }) async {
    final localPath = await localPathFor(track);
    final localFile = File(localPath);
    await localFile.parent.create(recursive: true);

    for (int attempt = 1; attempt <= AppConstants.downloadMaxRetries; attempt++) {
      if (cancelToken?.isCancelled == true) return;
      try {
        await _dio.download(
          remoteUrlFor(track),
          localPath,
          cancelToken: cancelToken,
          deleteOnError: true,
          onReceiveProgress: (received, total) {
            if (total > 0) onProgress(track, received / total);
          },
        );
        // Vérification fichier non vide (GitHub renvoie une page HTML sur 404)
        if (await localFile.exists() && await localFile.length() > 0) {
          track.isDownloaded     = true;
          track.downloadProgress = 1.0;
          onDone(track);
          return;
        } else {
          if (await localFile.exists()) await localFile.delete();
          throw Exception('Fichier vide ou absent après téléchargement');
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) return;
        if (attempt == AppConstants.downloadMaxRetries) {
          onError('${track.filename}: ${e.response?.statusCode ?? e.type.name}');
        } else {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      } catch (e) {
        if (attempt == AppConstants.downloadMaxRetries) {
          onError('${track.filename}: $e');
        }
      }
    }
    if (await localFile.exists()) await localFile.delete();
  }

  Future<void> downloadTheme({
    required AudioTheme theme,
    required void Function(AudioTrack track, double progress) onTrackProgress,
    required void Function(AudioTrack track) onTrackDone,
    required void Function(String error) onError,
    CancelToken? cancelToken,
  }) async {
    for (final track in theme.tracks) {
      if (track.isDownloaded) continue;
      if (cancelToken?.isCancelled == true) break;
      await _downloadOneTrack(
        track: track,
        cancelToken: cancelToken,
        onProgress: onTrackProgress,
        onDone: onTrackDone,
        onError: onError,
      );
    }
  }

  // ── Rafraîchissement (delete-diff) ───────────────────────────────────

  Future<void> refreshTheme({
    required AudioTheme theme,
    required void Function(AudioTrack track, double progress) onTrackProgress,
    required void Function(AudioTrack track) onTrackDone,
    required void Function(String deletedFilename) onTrackDeleted,
    required void Function(String error) onError,
    CancelToken? cancelToken,
  }) async {
    final root = await _audioRootDir;
    final themeKey = theme.tracks.isNotEmpty
        ? theme.tracks.first.themeKey
        : toSlug(theme.name);
    final themeDir = Directory('${root.path}/${theme.profKey}/$themeKey');

    // 1. Fichiers actuellement en local
    final Set<String> localFiles = {};
    if (await themeDir.exists()) {
      await for (final entity in themeDir.list()) {
        if (entity is File) localFiles.add(entity.uri.pathSegments.last);
      }
    }

    // 2. Fichiers attendus selon le catalogue
    final Set<String> expectedFiles = theme.tracks.map((t) => t.filename).toSet();

    // 3. Supprimer les fichiers obsolètes
    final toDelete = localFiles.difference(expectedFiles);
    for (final filename in toDelete) {
      final f = File('${themeDir.path}/$filename');
      try {
        await f.delete();
        onTrackDeleted(filename);
      } catch (e) {
        onError('Erreur suppression $filename: $e');
      }
    }

    // 4. Télécharger les manquants
    for (final track in theme.tracks) {
      if (localFiles.contains(track.filename)) continue;
      if (cancelToken?.isCancelled == true) break;
      await _downloadOneTrack(
        track: track,
        cancelToken: cancelToken,
        onProgress: onTrackProgress,
        onDone: onTrackDone,
        onError: onError,
      );
    }

    // 5. Mettre à jour isDownloaded pour toutes les pistes
    await refreshDownloadStatus(theme);
  }

  // ── Suppression ──────────────────────────────────────────────────────

  /// Supprime les audios téléchargés. Les assets embarqués sont protégés.
  Future<void> deleteTheme(AudioTheme theme) async {
    for (final track in theme.tracks) {
      if (track.isBundled) continue;
      final path = await localPathFor(track);
      final file = File(path);
      if (await file.exists()) await file.delete();
      track.isDownloaded     = false;
      track.downloadProgress = 0.0;
    }
  }
}
