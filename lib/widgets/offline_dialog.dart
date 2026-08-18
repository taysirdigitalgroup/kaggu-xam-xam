// lib/widgets/offline_dialog.dart
//
// Dialogue affiché quand l'utilisateur tente de LIRE (Play) un thème qui
// n'a aucun audio disponible hors-ligne et qu'il n'y a pas de connexion.
// Partagé entre audio_player_widget.dart et audio_track_list.dart — la
// vérification/déclenchement se fait désormais au moment du Play (via
// AppProvider.commitAndPlay), plus à la simple ouverture d'un thème.
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import 'download_sheet.dart';

void showOfflineThemeDialog(
  BuildContext context,
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
