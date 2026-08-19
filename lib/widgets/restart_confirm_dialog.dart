// lib/widgets/restart_confirm_dialog.dart
//
// Dialogue de confirmation affiché avant de recommencer un thème depuis le
// début (piste 1 / position 0). Évite de perdre la progression en cours par
// un appui accidentel sur le bouton "Recommencer".
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Affiche une confirmation. Retourne `true` si l'utilisateur confirme,
/// `false`/`null` sinon (annulation ou dialogue fermé).
Future<bool> showRestartConfirmDialog(
  BuildContext context, {
  required String themeName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(Icons.replay_rounded, color: kNavy, size: 40),
      title: const Text(
        'Recommencer ?',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: Text(
        'Voulez-vous recommencer « $themeName » depuis le début ?\n\n'
        'Votre progression actuelle sera perdue.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Annuler', style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.replay_rounded, size: 16),
          label: const Text('Recommencer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
