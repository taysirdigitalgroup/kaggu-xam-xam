// lib/services/professors_service.dart
//
// Gère la récupération dynamique des informations professeurs depuis le
// dépôt distant : dossier "professors/" contenant profs_infos.json (métadonnées)
// et profils/ (photos). Permet d'ajouter, retirer ou modifier un professeur
// (nom, rôle, ordre, photo) sans republier l'application.
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

/// Informations d'un professeur telles que décrites dans profs_infos.json.
///
/// Format attendu (voir README du dépôt data pour l'exemple complet) :
/// ```json
/// {
///   "name": "S Abdou Rahmane",
///   "role": "Enseignements",
///   "image": "s_abdou_rahmane.jpg",
///   "order": 1,
///   "active": true
/// }
/// ```
class ProfessorInfo {
  /// Doit correspondre EXACTEMENT à la clé utilisée dans bibliotheque.json
  /// (c'est ce qui permet de relier les deux catalogues).
  final String name;

  /// Rôle affiché sous le nom. Défaut : "Enseignements".
  final String role;

  /// Nom du fichier photo dans professors/profils/ du dépôt
  /// (ex : "s_saliou_sow.jpg"). Peut être vide si aucune photo.
  final String image;

  /// Ordre d'affichage (plus petit = affiché en premier). Défaut : 999.
  final int order;

  /// Permet de masquer un professeur sans supprimer son entrée
  /// (ex : en attendant que son contenu audio soit prêt). Défaut : true.
  final bool active;

  ProfessorInfo({
    required this.name,
    required this.role,
    required this.image,
    required this.order,
    required this.active,
  });

  /// Clé de correspondance avec Professor.key (même convention toSlug).
  String get key => toSlug(name);

  factory ProfessorInfo.fromJson(Map<String, dynamic> j) {
    return ProfessorInfo(
      name: (j['name'] ?? '').toString().trim(),
      role: (j['role'] ?? 'Enseignements').toString().trim().isEmpty
          ? 'Enseignements'
          : (j['role'] ?? 'Enseignements').toString().trim(),
      image: (j['image'] ?? '').toString().trim(),
      order: j['order'] is int
          ? j['order'] as int
          : int.tryParse('${j['order']}') ?? 999,
      active: j['active'] is bool ? j['active'] as bool : true,
    );
  }
}

/// Résultat du chargement de profs_infos.json.
class ProfessorsInfoResult {
  final List<ProfessorInfo> infos;

  /// true si le JSON distant récupéré diffère du cache local précédent
  /// (nouveau prof, rôle modifié, photo renommée, etc.) → dans ce cas
  /// il faut resynchroniser les photos via [ProfessorsService.refreshImages].
  final bool changed;

  ProfessorsInfoResult(this.infos, this.changed);
}

class ProfessorsService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: Duration(seconds: AppConstants.connectTimeoutSec),
    receiveTimeout: Duration(seconds: AppConstants.biblioReceiveTimeoutSec),
    followRedirects: true,
    maxRedirects: 5,
    headers: {
      'Cache-Control': 'no-cache',
      'User-Agent': 'KagguXamXam/${AppConstants.appVersion}',
    },
  ));

  // ── Chargement du catalogue profs_infos.json ──────────────────────────
  //
  // Même stratégie que BibliothequeService.loadBibliotheque() :
  //   1. Tente de récupérer le JSON distant.
  //   2. Compare son hash MD5 à celui mis en cache (SharedPreferences).
  //   3. Si différent → sauvegarde locale + hash mis à jour + changed=true.
  //   4. En cas d'échec réseau → repli sur le cache local, puis sur l'asset
  //      embarqué assets/professors/profs_infos.json (état "jour 1").

  Future<ProfessorsInfoResult> loadProfessorsInfo() async {
    final prefs = await SharedPreferences.getInstance();
    String jsonStr;
    bool changed = false;

    try {
      final response = await _dio.get<String>(
        AppConstants.professorsInfosRemoteUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 &&
          response.data != null &&
          response.data!.trim().isNotEmpty) {
        final remoteJson = response.data!;
        jsonDecode(remoteJson); // validation JSON avant sauvegarde

        final remoteHash = md5.convert(utf8.encode(remoteJson)).toString();
        final cachedHash =
            prefs.getString(AppConstants.prefProfsInfosHash) ?? '';

        if (remoteHash != cachedHash) {
          await _saveLocalInfos(remoteJson);
          await prefs.setString(AppConstants.prefProfsInfosHash, remoteHash);
          changed = true;
        }
        jsonStr = remoteJson;
      } else {
        jsonStr = await _loadLocalInfos();
      }
    } catch (_) {
      jsonStr = await _loadLocalInfos();
    }

    return ProfessorsInfoResult(_parse(jsonStr), changed);
  }

  Future<void> _saveLocalInfos(String json) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${AppConstants.localProfsInfosFilename}');
    await file.writeAsString(json, encoding: utf8);
  }

  Future<String> _loadLocalInfos() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${AppConstants.localProfsInfosFilename}');
      if (await file.exists()) {
        final content = await file.readAsString(encoding: utf8);
        if (content.trim().isNotEmpty) return content;
      }
    } catch (_) {}
    try {
      return await rootBundle.loadString('assets/professors/profs_infos.json');
    } catch (_) {
      return '{"professors": []}';
    }
  }

  List<ProfessorInfo> _parse(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final list = (data['professors'] as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ProfessorInfo.fromJson)
          .where((i) => i.name.isNotEmpty && i.active)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ── Répertoire local des photos ────────────────────────────────────────
  //
  // Emplacement : <Documents>/professors/profils/<image>
  // (miroir de la structure du dépôt distant "professors/profils/<image>")

  Future<Directory> get _profilsDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/${AppConstants.professorsImagesLocalDir}');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> localImagePathFor(ProfessorInfo info) async {
    final dir = await _profilsDir;
    return '${dir.path}/${info.image}';
  }

  String remoteImageUrlFor(ProfessorInfo info) =>
      '${AppConstants.professorsProfilsBaseUrl}/${info.image}';

  // ── Téléchargement avec retry ───────────────────────────────────────────

  Future<bool> _downloadOneImage(ProfessorInfo info) async {
    if (info.image.isEmpty) return false;
    final localPath = await localImagePathFor(info);
    final localFile = File(localPath);
    await localFile.parent.create(recursive: true);

    for (int attempt = 1; attempt <= AppConstants.downloadMaxRetries; attempt++) {
      try {
        await _dio.download(
          remoteImageUrlFor(info),
          localPath,
          deleteOnError: true,
        );
        // Vérification fichier non vide (GitHub renvoie une page HTML sur 404)
        if (await localFile.exists() && await localFile.length() > 0) {
          return true;
        }
        if (await localFile.exists()) await localFile.delete();
        throw Exception('Fichier image vide ou absent après téléchargement');
      } on DioException catch (_) {
        if (attempt == AppConstants.downloadMaxRetries) return false;
        await Future.delayed(Duration(seconds: attempt * 2));
      } catch (_) {
        if (attempt == AppConstants.downloadMaxRetries) return false;
      }
    }
    return false;
  }

  /// Télécharge uniquement les photos absentes localement.
  /// Appelé à chaque démarrage — coût réseau minimal une fois les photos
  /// déjà en cache.
  Future<void> ensureImages(List<ProfessorInfo> infos) async {
    for (final info in infos) {
      if (info.image.isEmpty) continue;
      final path = await localImagePathFor(info);
      if (!await File(path).exists()) {
        await _downloadOneImage(info);
      }
    }
  }

  /// Resynchronise entièrement les photos : supprime celles qui ne sont
  /// plus référencées (prof retiré ou photo renommée) puis retélécharge
  /// (écrase) toutes les photos attendues.
  ///
  /// À appeler uniquement quand profs_infos.json a changé
  /// ([ProfessorsInfoResult.changed] == true) : c'est le seul cas où une
  /// photo existante côté dépôt a pu être remplacée par une nouvelle
  /// version sous le même nom de fichier.
  Future<void> refreshImages(List<ProfessorInfo> infos) async {
    final dir = await _profilsDir;
    final expected =
        infos.map((i) => i.image).where((f) => f.isNotEmpty).toSet();

    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final filename = entity.uri.pathSegments.last;
          if (!expected.contains(filename)) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    }

    for (final info in infos) {
      if (info.image.isEmpty) continue;
      await _downloadOneImage(info);
    }
  }

  // ── Fusion avec la liste des professeurs (issue de bibliotheque.json) ──

  /// Applique rôle / ordre / photo locale sur chaque [Professor], en les
  /// faisant correspondre par clé (slug du nom, même convention que
  /// bibliotheque.json). Un professeur présent dans bibliotheque.json mais
  /// absent de profs_infos.json conserve ses valeurs par défaut (rôle
  /// "Enseignements", image embarquée assets/images/<key>.jpg).
  Future<void> applyInfos(
    List<Professor> professors,
    List<ProfessorInfo> infos,
  ) async {
    final byKey = {for (final i in infos) i.key: i};

    for (final prof in professors) {
      final info = byKey[prof.key];
      if (info == null) continue;

      prof.role = info.role;
      prof.order = info.order;

      if (info.image.isNotEmpty) {
        final localPath = await localImagePathFor(info);
        prof.localImagePath = await File(localPath).exists() ? localPath : null;
      }
    }
  }
}
