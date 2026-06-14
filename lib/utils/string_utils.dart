// lib/utils/string_utils.dart

/// Formate un nom de fichier audio en titre lisible.
/// Enlève l'extension, remplace `_` et `-` par des espaces,
/// met la première lettre en majuscule.
String formatAudioTitle(String filename) {
  // Supprimer l'extension
  var name = filename.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
  // Remplacer underscores, tirets, points par espace
  name = name.replaceAll(RegExp(r'[_\-\.]+'), ' ');
  // Supprimer les numéros de piste en préfixe (ex: "01 ", "001 ")
  name = name.replaceAll(RegExp(r'^\d+\s+'), '');
  // Trim
  name = name.trim();
  // Capitaliser
  if (name.isEmpty) return filename;
  return name[0].toUpperCase() + name.substring(1);
}

/// Formate une durée en mm:ss
String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    return '${d.inHours}:$m:$s';
  }
  return '$m:$s';
}

/// Génère une clé normalisée (slug) pour une chaîne (pour URLs/chemins)
String toSlug(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll(RegExp(r'[ç]'), 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
