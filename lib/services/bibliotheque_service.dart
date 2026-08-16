// lib/services/bibliotheque_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/string_utils.dart';
import '../models/models.dart';

class BibliothequeService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    followRedirects: true,
    maxRedirects: 5,
    headers: {
      'Cache-Control': 'no-cache',
      'User-Agent': 'KagguXamXam/${AppConstants.appVersion}',
    },
  ));

  // ══════════════════════════════════════════════════════════════════════
  // CONFIGURATION DES PROFESSEURS
  // ══════════════════════════════════════════════════════════════════════
  //
  // Ce service ne construit que le SQUELETTE des professeurs (nom, clé,
  // thèmes/pistes audio) à partir de bibliotheque.json. Le rôle affiché,
  // l'ordre d'affichage et la photo sont désormais entièrement dynamiques :
  // ils sont récupérés depuis professors/profs_infos.json par
  // ProfessorsService, puis fusionnés (ProfessorsService.applyInfos) sur
  // les objets Professor produits ici. Pour ajouter un nouveau professeur,
  // il suffit donc de :
  //   1. Ajouter son entrée dans bibliotheque.json (dépôt distant)
  //   2. Ajouter son entrée dans professors/profs_infos.json (nom, rôle,
  //      photo, ordre) — voir ProfessorsService pour le format.
  //   3. Déposer sa photo dans professors/profils/ du dépôt.
  // Aucune modification du code ni republication de l'app n'est nécessaire.
  //
  // ══════════════════════════════════════════════════════════════════════

  /// Extensions d'images acceptées (dans l'ordre de priorité)
  static const List<String> _imageExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  // ── Chargement ──────────────────────────────────────────────────────

  Future<List<Professor>> loadBibliotheque() async {
    final prefs = await SharedPreferences.getInstance();
    String jsonStr;

    try {
      final response = await _dio.get<String>(
        AppConstants.bibliothequeRemoteUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 &&
          response.data != null &&
          response.data!.trim().isNotEmpty) {
        final remoteJson = response.data!;
        // Validation JSON avant sauvegarde
        jsonDecode(remoteJson);

        final remoteHash = md5.convert(utf8.encode(remoteJson)).toString();
        final cachedHash = prefs.getString(AppConstants.prefBiblioHash) ?? '';

        if (remoteHash != cachedHash) {
          await _saveLocalBiblio(remoteJson);
          await prefs.setString(AppConstants.prefBiblioHash, remoteHash);
        }
        jsonStr = remoteJson;
      } else {
        jsonStr = await _loadLocalBiblio();
      }
    } catch (_) {
      jsonStr = await _loadLocalBiblio();
    }

    return _parseBibliotheque(jsonStr);
  }

  Future<void> _saveLocalBiblio(String json) async {
    final dir  = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${AppConstants.localBiblioFilename}');
    await file.writeAsString(json, encoding: utf8);
  }

  Future<String> _loadLocalBiblio() async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${AppConstants.localBiblioFilename}');
      if (await file.exists()) {
        final content = await file.readAsString(encoding: utf8);
        if (content.trim().isNotEmpty) return content;
      }
    } catch (_) {}
    return rootBundle.loadString('assets/bibliotheque.json');
  }

  // ── Parsing ──────────────────────────────────────────────────────────

  List<Professor> _parseBibliotheque(String jsonStr) {
    final Map<String, dynamic> data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final List<Professor> professors = [];

    data.forEach((profName, themesData) {
      final profKey = toSlug(profName);
      final themes  = <AudioTheme>[];

      if (themesData is Map<String, dynamic>) {
        themesData.forEach((themeName, audioFiles) {
          final themeKey = toSlug(themeName);
          final tracks   = <AudioTrack>[];

          if (audioFiles is List) {
            for (final filename in audioFiles) {
              tracks.add(AudioTrack(
                filename: filename.toString(),
                profKey:  profKey,
                themeKey: themeKey,
              ));
            }
          }

          themes.add(AudioTheme(
            name:    themeName,
            profKey: profKey,
            tracks:  tracks,
          ));
        });
      }

      professors.add(Professor(
        name:      profName,
        key:       profKey,
        // Convention automatique : toSlug(profName) = nom du fichier image
        // "S Sam Mbaye" → "s_sam_mbaye" → assets/images/s_sam_mbaye.jpg
        // (repli tant que ProfessorsService n'a pas fourni de photo locale)
        imagePath: _resolveImagePath(profKey),
        themes:    themes,
        // role/order/localImagePath : valeurs par défaut du modèle,
        // écrasées ensuite par ProfessorsService.applyInfos().
      ));
    });

    return professors;
  }

  /// Retourne le chemin asset de l'image du prof.
  /// Essaie chaque extension dans l'ordre jusqu'à trouver.
  /// Si aucune n'existe dans le manifest → image par défaut.
  ///
  /// Exemple :
  ///   profKey = "s_sam_mbaye"
  ///   Tente : assets/images/s_sam_mbaye.jpg  ← en production c'est celui-là
  ///           assets/images/s_sam_mbaye.jpeg
  ///           assets/images/s_sam_mbaye.png
  ///           assets/images/s_sam_mbaye.webp
  ///   Fallback : assets/images/default_prof.png
  String _resolveImagePath(String profKey) {
    // On retourne le chemin .jpg par défaut.
    // Flutter lèvera l'errorBuilder si l'asset n'existe pas
    // (géré dans le widget avec l'initiale du prof).
    // Pour supporter d'autres extensions, ajouter une logique async ici.
    return 'assets/images/$profKey.jpg';
  }
}
