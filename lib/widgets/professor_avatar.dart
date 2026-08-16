// lib/widgets/professor_avatar.dart
//
// Avatar circulaire d'un professeur, avec ordre de priorité :
//   1. Photo téléchargée localement (Professor.localImagePath), si présente
//      sur le disque — mise à jour dynamiquement depuis profs_infos.json.
//   2. Image embarquée dans l'APK (Professor.imagePath), en repli.
//   3. Initiales du nom sur fond de couleur, en dernier recours.
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';

class ProfessorAvatar extends StatelessWidget {
  final Professor professor;
  final double size;
  final double borderWidth;
  final Color borderColor;
  final Color backgroundColor;
  final Color textColor;

  const ProfessorAvatar({
    super.key,
    required this.professor,
    required this.borderColor,
    required this.backgroundColor,
    required this.textColor,
    this.size = 48,
    this.borderWidth = 2.5,
  });

  String get _initials => professor.name.length >= 2
      ? professor.name.substring(0, 2).toUpperCase()
      : professor.name.toUpperCase();

  Widget _initialsFallback() => Container(
        color: backgroundColor,
        alignment: Alignment.center,
        child: Text(
          _initials,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.3,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final localPath = professor.localImagePath;
    final hasLocalImage = localPath != null && File(localPath).existsSync();

    final Widget image = hasLocalImage
        ? Image.file(
            File(localPath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.asset(
              professor.imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialsFallback(),
            ),
          )
        : Image.asset(
            professor.imagePath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initialsFallback(),
          );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipOval(child: image),
    );
  }
}
