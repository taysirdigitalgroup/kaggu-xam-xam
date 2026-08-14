// lib/services/playback_persistence_service.dart
//
// Persiste l'état de lecture PAR THÈME (clé = profKey_themeName).
// Chaque thème a son propre trackIndex, positionMs et flag completed.
// La clé "last" pointe vers le thème lu en dernier (pour le WelcomePane).

import 'package:shared_preferences/shared_preferences.dart';

class PlaybackPersistenceService {
  // Clé du dernier thème lu (indirection)
  static const String _keyLastThemeId = 'last_theme_id';

  // Préfixes des données par thème
  static const String _pfxTrackIndex = 'theme_track_';
  static const String _pfxPositionMs = 'theme_pos_';
  static const String _pfxCompleted  = 'theme_done_';
  static const String _pfxProfName   = 'theme_profname_';
  static const String _pfxThemeName  = 'theme_name_';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Clé unique pour un thème : "<profKey>__<themeName>"
  String _id(String profKey, String themeName) =>
      '${profKey}__${themeName.replaceAll(' ', '_')}';

  // ── Sauvegarde ───────────────────────────────────────────────────────

  Future<void> save({
    required String profKey,
    required String profName,
    required String themeName,
    required int    trackIndex,
    required int    positionMs,
    bool completed = false,
  }) async {
    final p  = await _prefs;
    final id = _id(profKey, themeName);

    await p.setString(_pfxProfName  + id, profName);
    await p.setString(_pfxThemeName + id, themeName);
    await p.setInt   (_pfxTrackIndex + id, trackIndex);
    await p.setInt   (_pfxPositionMs + id, positionMs);
    // Ne pas écraser completed=true avec false
    if (completed || !(p.getBool(_pfxCompleted + id) ?? false)) {
      await p.setBool(_pfxCompleted + id, completed);
    }
    // Mettre à jour le pointeur "dernier thème"
    await p.setString(_keyLastThemeId, id);
  }

  Future<void> markCompleted(String profKey, String themeName) async {
    final p  = await _prefs;
    final id = _id(profKey, themeName);
    await p.setBool(_pfxCompleted + id, true);
    // Position à 0 quand terminé (pas de reprise)
    await p.setInt(_pfxPositionMs + id, 0);
    await p.setInt(_pfxTrackIndex + id, 0);
  }

  // ── Lecture par thème ────────────────────────────────────────────────

  /// Charge l'état d'un thème précis.
  Future<PlaybackState?> loadForTheme(String profKey, String themeName) async {
    final p  = await _prefs;
    final id = _id(profKey, themeName);

    final pName = p.getString(_pfxProfName  + id);
    final tName = p.getString(_pfxThemeName + id);
    if (pName == null || tName == null) return null;

    return PlaybackState(
      profKey:    profKey,
      profName:   pName,
      themeName:  tName,
      trackIndex: p.getInt(_pfxTrackIndex + id) ?? 0,
      positionMs: p.getInt(_pfxPositionMs + id) ?? 0,
      completed:  p.getBool(_pfxCompleted + id) ?? false,
    );
  }

  /// Charge le dernier thème lu (pour le WelcomePane).
  Future<PlaybackState?> loadLast() async {
    final p  = await _prefs;
    final id = p.getString(_keyLastThemeId);
    if (id == null) return null;

    final pName = p.getString(_pfxProfName  + id);
    final tName = p.getString(_pfxThemeName + id);
    // Retrouver profKey depuis l'id (profKey__themeName_slug)
    final profKey = id.split('__').first;
    if (pName == null || tName == null) return null;

    return PlaybackState(
      profKey:    profKey,
      profName:   pName,
      themeName:  tName,
      trackIndex: p.getInt(_pfxTrackIndex + id) ?? 0,
      positionMs: p.getInt(_pfxPositionMs + id) ?? 0,
      completed:  p.getBool(_pfxCompleted + id) ?? false,
    );
  }
}

class PlaybackState {
  final String profKey;
  final String profName;
  final String themeName;
  final int    trackIndex;
  final int    positionMs;
  final bool   completed;

  const PlaybackState({
    required this.profKey,
    required this.profName,
    required this.themeName,
    required this.trackIndex,
    required this.positionMs,
    required this.completed,
  });

  bool get hasProgress => trackIndex > 0 || positionMs > 3000;
}
