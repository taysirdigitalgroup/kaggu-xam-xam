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

/// Normalise une chaîne pour la recherche : minuscules + accents retirés,
/// SANS toucher aux espaces ni à la longueur (chaque caractère accentué est
/// remplacé par exactement un caractère non-accentué). Ceci permet de
/// retrouver précisément la position d'une correspondance dans le texte
/// ORIGINAL (pour le surlignage), même quand la recherche ignore les accents
/// — ex: "priere" retrouve "Prière", "eveil" retrouve "Éveil du cœur".
String normalizeForSearch(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll(RegExp(r'[ç]'), 'c');
}

/// Plage Unicode couvrant l'arabe, l'hébreu et leurs extensions/présentations
/// (arabe : \u0600-\u06FF, \u0750-\u077F, \uFB50-\uFDFF, \uFE70-\uFEFF ;
/// hébreu : \u0591-\u05FF). Sert à détecter une saisie RTL.
final RegExp _rtlCharPattern = RegExp(
  r'[\u0591-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]',
);
final RegExp _ltrCharPattern = RegExp(r'[a-zA-Z]');

/// Détecte si un texte est à prédominance RTL (arabe/hébreu), en se basant
/// sur le premier caractère "fort" rencontré (lettre arabe/hébraïque → RTL,
/// lettre latine → LTR). Permet d'aligner et d'orienter automatiquement un
/// champ de saisie selon la langue effectivement tapée par l'utilisateur,
/// plutôt que selon la langue fixe de l'app.
bool isRtlText(String s) {
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    if (_rtlCharPattern.hasMatch(ch)) return true;
    if (_ltrCharPattern.hasMatch(ch)) return false;
  }
  return false; // vide, chiffres ou ponctuation seuls → LTR par défaut
}
