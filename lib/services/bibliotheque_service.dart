// lib/services/bibliotheque_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../models/models.dart';
import '../utils/string_utils.dart';

class BibliothequeService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Charge et synchronise la bibliothèque selon la règle :
  /// 1. Tente de récupérer le JSON distant
  /// 2. Si différent du cache → sauvegarde localement + met à jour le hash
  /// 3. En cas d'erreur réseau → utilise la version cache locale
  /// 4. Si pas de cache local → utilise l'asset embarqué (assets/bibliotheque.json)
  Future<List<Professor>> loadBibliotheque() async {
    final prefs = await SharedPreferences.getInstance();
    String jsonStr;

    try {
      final response = await _dio.get<String>(
        AppConstants.bibliothequeRemoteUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.data != null && response.data!.isNotEmpty) {
        final remoteJson = response.data!;
        final remoteHash = md5.convert(utf8.encode(remoteJson)).toString();
        final cachedHash = prefs.getString(AppConstants.prefBiblioHash) ?? '';

        if (remoteHash != cachedHash) {
          // Nouvelle version → sauvegarder en local
          await _saveLocalBiblio(remoteJson);
          await prefs.setString(AppConstants.prefBiblioHash, remoteHash);
        }
        jsonStr = remoteJson;
      } else {
        jsonStr = await _loadLocalBiblio();
      }
    } catch (_) {
      // Pas de réseau → version locale ou asset embarqué
      jsonStr = await _loadLocalBiblio();
    }

    return _parseBibliotheque(jsonStr);
  }

  Future<void> _saveLocalBiblio(String json) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${AppConstants.localBiblioFilename}');
    await file.writeAsString(json, encoding: utf8);
  }

  Future<String> _loadLocalBiblio() async {
    // 1. Cache local (documents) – version synchronisée précédemment
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${AppConstants.localBiblioFilename}');
      if (await file.exists()) {
        return await file.readAsString(encoding: utf8);
      }
    } catch (_) {}
    // 2. Asset embarqué (fallback absolu)
    return await rootBundle.loadString('assets/bibliotheque.json');
  }

  List<Professor> _parseBibliotheque(String jsonStr) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final List<Professor> professors = [];

    final Map<String, String> profImages = {
      'S Abdou Rahmane': 'assets/images/abdou_rahmane.jpg',
      'S Bass Khelcom': 'assets/images/bass_khelcom.jpg',
      'S Sam Mbaye': 'assets/images/sam_mbaye.jpg',
    };

    data.forEach((profName, themesData) {
      final profKey = toSlug(profName);
      final themes = <AudioTheme>[];

      if (themesData is Map<String, dynamic>) {
        themesData.forEach((themeName, audioFiles) {
          final themeKey = toSlug(themeName);
          final tracks = <AudioTrack>[];

          if (audioFiles is List) {
            for (final filename in audioFiles) {
              tracks.add(AudioTrack(
                filename: filename.toString(),
                profKey: profKey,
                themeKey: themeKey,
              ));
            }
          }

          themes.add(AudioTheme(
            name: themeName,
            profKey: profKey,
            tracks: tracks,
          ));
        });
      }

      professors.add(Professor(
        name: profName,
        key: profKey,
        imagePath: profImages[profName] ?? 'assets/images/default_prof.png',
        themes: themes,
      ));
    });

    return professors;
  }
}
