// lib/widgets/sidebar_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../screens/info_screen.dart';
import '../utils/app_theme.dart';
import '../utils/string_utils.dart';
import 'download_sheet.dart';
import 'professor_avatar.dart';

class SidebarDrawer extends StatefulWidget {
  const SidebarDrawer({super.key});

  @override
  State<SidebarDrawer> createState() => _SidebarDrawerState();
}

class _SidebarDrawerState extends State<SidebarDrawer> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _rawQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _rawQuery = value);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _rawQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    final provider    = context.watch<AppProvider>();
    final query       = normalizeForSearch(_rawQuery.trim());
    final isSearching = query.isNotEmpty;

    // Calcule, pour chaque professeur, s'il correspond à la recherche et
    // quels thèmes afficher : match sur le nom/rôle du prof → tous ses
    // thèmes ; sinon match sur le nom d'un ou plusieurs thèmes → seulement
    // ceux-là ; sinon → professeur exclu des résultats.
    final results = <_ProfMatch>[];
    for (final prof in provider.professors) {
      if (!isSearching) {
        results.add(_ProfMatch(prof: prof, themes: prof.themes, forceExpanded: false));
        continue;
      }
      final profMatches = normalizeForSearch(prof.name).contains(query) ||
          normalizeForSearch(prof.role).contains(query);
      final matchingThemes = prof.themes
          .where((t) => normalizeForSearch(t.name).contains(query))
          .toList();

      if (profMatches) {
        results.add(_ProfMatch(prof: prof, themes: prof.themes, forceExpanded: true));
      } else if (matchingThemes.isNotEmpty) {
        results.add(_ProfMatch(prof: prof, themes: matchingThemes, forceExpanded: true));
      }
    }

    final themeCount = results.fold<int>(0, (sum, r) => sum + r.themes.length);

    return Drawer(
      width: 300,
      backgroundColor: kNavy,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Text(
                      'PROFESSEURS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.4),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: _SearchField(
                      controller: _searchCtrl,
                      onChanged: _onQueryChanged,
                      onClear: _clearSearch,
                    ),
                  ),
                  if (isSearching)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                      child: Text(
                        results.isEmpty
                            ? 'Aucun résultat'
                            : '$themeCount thème${themeCount > 1 ? 's' : ''} · '
                              '${results.length} prof${results.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: kGoldLight.withOpacity(0.7),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  if (isSearching && results.isEmpty)
                    _NoResults(query: _rawQuery.trim())
                  else
                    ...results.map((r) => _ProfessorTile(
                          prof: r.prof,
                          themesOverride: isSearching ? r.themes : null,
                          forceExpanded: r.forceExpanded,
                          searchQuery: isSearching ? _rawQuery.trim() : '',
                        )),
                ],
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.1), height: 1),
            _InfoTile(),
          ],
        ),
      ),
    );
  }
}

/// Résultat de la recherche pour un professeur donné : lui-même et la
/// liste (filtrée ou complète) de ses thèmes à afficher.
class _ProfMatch {
  final Professor prof;
  final List<AudioTheme> themes;
  final bool forceExpanded;
  const _ProfMatch({required this.prof, required this.themes, required this.forceExpanded});
}

/// Champ de recherche moderne : icône loupe, placeholder, bouton d'effacement
/// qui n'apparaît que si du texte est saisi, style cohérent avec le thème
/// (fond translucide, bord doré au focus).
class _SearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Alignement/direction du texte adaptés automatiquement à la langue
    // tapée : RTL (arabe/hébreu) aligné à droite, sinon LTR à gauche —
    // utile car les thèmes/profs peuvent être recherchés en arabe.
    final rtl = isRtlText(widget.controller.text);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(_focused ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focused ? kGold.withOpacity(0.7) : Colors.white.withOpacity(0.08),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        textAlign: rtl ? TextAlign.right : TextAlign.left,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: kGold,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: 'Rechercher un thème...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _focused ? kGold : Colors.white.withOpacity(0.4),
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.5), size: 18),
                splashRadius: 16,
                onPressed: widget.onClear,
              );
            },
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        ),
      ),
    );
  }
}

/// État "aucun résultat" affiché quand la recherche ne correspond à aucun
/// professeur ni thème.
class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: Colors.white.withOpacity(0.25), size: 36),
          const SizedBox(height: 10),
          Text(
            'Aucun thème ne correspond à « $query »',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// Texte avec la portion correspondant à [query] surlignée en doré
/// (recherche insensible à la casse et aux accents). Si aucune
/// correspondance n'est trouvée dans [text], l'affiche tel quel.
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final TextStyle highlightStyle;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);

    final normText  = normalizeForSearch(text);
    final normQuery = normalizeForSearch(query);
    final idx = normText.indexOf(normQuery);
    if (idx < 0) return Text(text, style: style);

    final end = idx + query.length;
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(text: text.substring(idx, end), style: highlightStyle),
          if (end < text.length) TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}

class _ProfessorTile extends StatelessWidget {
  final Professor prof;

  /// Liste de thèmes à afficher (déjà filtrée par la recherche). `null` =
  /// mode normal, tous les thèmes du prof, expansion pilotée par
  /// [AppProvider.expandedProfs].
  final List<AudioTheme>? themesOverride;

  /// Forcer l'expansion (utilisé pendant une recherche active, pour que
  /// les résultats soient visibles sans avoir à taper sur l'en-tête).
  final bool forceExpanded;

  /// Texte de recherche brut (non normalisé) pour le surlignage. Vide en
  /// mode normal.
  final String searchQuery;

  const _ProfessorTile({
    required this.prof,
    this.themesOverride,
    this.forceExpanded = false,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    final provider   = context.watch<AppProvider>();
    final isExpanded = forceExpanded || provider.expandedProfs.contains(prof.key);
    final isSelected = provider.selectedProfessor?.key == prof.key;

    return Column(
      children: [
        InkWell(
          // Pendant une recherche, l'expansion est forcée : l'en-tête ne
          // fait rien (déjà déplié), pour éviter un toggle qui n'aurait
          // d'effet qu'après avoir effacé la recherche.
          onTap: forceExpanded ? null : () => provider.toggleProfExpand(prof.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: isSelected ? kGold.withOpacity(0.15) : Colors.transparent,
            child: Row(
              children: [
                // Avatar
                ProfessorAvatar(
                  professor: prof,
                  size: 48,
                  borderWidth: 2.5,
                  borderColor: kGold,
                  backgroundColor: kNavy,
                  textColor: kGold,
                ),
                const SizedBox(width: 12),
                // Nom + Rôle — N thèmes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      searchQuery.isEmpty
                          ? Text(
                              prof.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : _HighlightedText(
                              text: prof.name,
                              query: searchQuery,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              highlightStyle: TextStyle(
                                color: kGold,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: prof.role,
                              style: TextStyle(
                                color: kGoldLight.withOpacity(0.85),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: '  —  ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.25),
                                fontSize: 10,
                              ),
                            ),
                            TextSpan(
                              text: () {
                                final n = (themesOverride ?? prof.themes).length;
                                return searchQuery.isEmpty
                                    ? '$n thème${n > 1 ? 's' : ''}'
                                    : '$n résultat${n > 1 ? 's' : ''}';
                              }(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down, color: kGoldLight, size: 20),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild:      const SizedBox.shrink(),
          secondChild:     _ThemesList(
            prof: prof,
            themesOverride: themesOverride,
            searchQuery: searchQuery,
          ),
          crossFadeState:  isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
        Divider(
          color: Colors.white.withOpacity(0.07),
          height: 1,
          indent: 14,
          endIndent: 14,
        ),
      ],
    );
  }
}

class _ThemesList extends StatelessWidget {
  final Professor prof;
  final List<AudioTheme>? themesOverride;
  final String searchQuery;

  const _ThemesList({
    required this.prof,
    this.themesOverride,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    final provider   = context.watch<AppProvider>();
    final themesToShow = themesOverride ?? prof.themes;

    return Container(
      margin: const EdgeInsets.only(left: 74, bottom: 6),
      child: Column(
        children: themesToShow.map((theme) {
          final isSelected    = provider.selectedTheme?.name == theme.name &&
              provider.selectedProfessor?.key == prof.key;
          final isDownloading = provider.isThemeDownloading(theme);
          final isRefreshing  = provider.isThemeRefreshing(theme);

          return InkWell(
            onTap: () => _onThemeTap(context, provider, prof, theme),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected ? kGold.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? kGold : kGold.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: searchQuery.isEmpty
                        ? Text(
                            theme.name,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.72),
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          )
                        : _HighlightedText(
                            text: theme.name,
                            query: searchQuery,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.72),
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            highlightStyle: TextStyle(
                              color: kGold,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                  _ThemeActionButton(
                    theme: theme, prof: prof,
                    isDownloading: isDownloading, isRefreshing: isRefreshing,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Gère le tap sur un thème :
  ///   1. Vérifie hors-ligne → dialog "Télécharger"
  ///   2. Vérifie reprise possible → dialog "Continuer ?"
  ///   3. Sinon → sélectionne directement
  Future<void> _onThemeTap(
    BuildContext context,
    AppProvider provider,
    Professor prof,
    AudioTheme theme,
  ) async {
    Navigator.pop(context); // fermer le drawer d'abord

    final result = await provider.selectTheme(prof, theme);

    if (result == null) return; // tout bon

    if (result == 'offline_theme') {
      if (context.mounted) _showOfflineThemeDialog(context, provider, theme, prof);
      return;
    }

    if (result.startsWith('resume:')) {
      final parts      = result.split(':');
      final trackIndex = int.tryParse(parts[1]) ?? 0;
      final positionMs = int.tryParse(parts[2]) ?? 0;
      if (context.mounted) {
        _showResumeDialog(context, provider, prof, theme, trackIndex, positionMs);
      }
    }
  }
}

// ── Dialogs ──────────────────────────────────────────────────────────────────

void _showOfflineThemeDialog(
  BuildContext context,
  AppProvider provider,
  AudioTheme theme,
  Professor prof,
) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(Icons.wifi_off_rounded, color: kNavy, size: 40),
      title: const Text(
        'Hors-ligne',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: Text(
        'Aucun audio de « ${theme.name} » n\'est disponible hors-ligne.\n\n'
        'Connectez-vous à internet ou téléchargez les audios pour les écouter sans connexion.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Fermer', style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            showDownloadSheet(ctx, theme, prof);
          },
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Télécharger'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    ),
  );
}

void _showResumeDialog(
  BuildContext context,
  AppProvider provider,
  Professor prof,
  AudioTheme theme,
  int trackIndex,
  int positionMs,
) {
  final trackName = trackIndex < theme.tracks.length
      ? formatAudioTitle(theme.tracks[trackIndex].filename)
      : 'Piste ${trackIndex + 1}';
  final pos = Duration(milliseconds: positionMs);
  final posStr = '${pos.inMinutes.toString().padLeft(2, '0')}:${(pos.inSeconds % 60).toString().padLeft(2, '0')}';

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(Icons.play_circle_outline_rounded, color: kNavy, size: 40),
      title: const Text(
        'Continuer la lecture ?',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            theme.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '« $trackName »',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'à $posStr',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            provider.startFresh(prof, theme);
          },
          child: Text('Depuis le début',
              style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            provider.confirmResume(prof, theme, trackIndex, positionMs);
          },
          icon: const Icon(Icons.play_arrow_rounded, size: 16),
          label: const Text('Reprendre'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    ),
  );
}

class _ThemeActionButton extends StatelessWidget {
  final AudioTheme theme;
  final Professor  prof;
  final bool       isDownloading;
  final bool       isRefreshing;

  const _ThemeActionButton({
    required this.theme,
    required this.prof,
    required this.isDownloading,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    if (theme.tracks.isEmpty) return const SizedBox.shrink();

    if (isDownloading || isRefreshing) {
      return SizedBox(
        width: 18, height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(kGold),
        ),
      );
    }

    if (theme.hasLocalDownloads) {
      return Tooltip(
        message: 'Synchroniser avec le dépôt',
        child: GestureDetector(
          onTap: () => showRefreshSheet(context, theme, prof),
          child: Icon(Icons.sync_rounded, color: Colors.green.shade400, size: 18),
        ),
      );
    }

    return Tooltip(
      message: theme.isBundledOnly
          ? 'Télécharger pour usage hors-ligne'
          : 'Télécharger les audios',
      child: GestureDetector(
        onTap: () => showDownloadSheet(context, theme, prof),
        child: Icon(
          Icons.download_rounded,
          color: theme.isBundledOnly ? kGold.withOpacity(0.6) : kGold,
          size: 18,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InfoScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
              child: Icon(Icons.info_outline, color: kGoldLight, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Infos & À propos',
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
