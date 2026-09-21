import 'package:flutter/material.dart';

/// Canonical V3 "Sentier de cartes" palette.
///
/// This stays separate from [AppColors] while V3 replaces the legacy screens
/// progressively: an unfinished screen must not accidentally inherit a V3
/// surface or, conversely, dilute the V3 dark-water language.
abstract final class V3Colors {
  static const app = Color(0xFF262A24);
  static const block = Color(0xFF313A2F);
  static const block2 = Color(0xFF333B31);
  static const chip = Color(0xFF3D4539);
  static const chip2 = Color(0xFF45503F);
  static const ruleDark = Color(0xFF4E5A4A);

  static const paper = Color(0xFFFBF7EC);
  static const paper2 = Color(0xFFF3EDE0);
  static const paper3 = Color(0xFFEFE8D6);
  static const edgeWarm1 = Color(0xFFDED5BE);
  static const edgeWarm2 = Color(0xFFC8BFA8);

  static const ink = Color(0xFF23231D);
  static const ink60 = Color(0xFF5C5749);
  static const light = Color(0xFFF1EDE2);
  static const light70 = Color(0xFFC9D0C6);
  static const light60 = Color(0xFFAFB9AD);

  static const terra = Color(0xFF9B4F13);
  static const terraInk = Color(0xFF8B3F0D);
  static const amber = Color(0xFFEBC08C);
  static const moss = Color(0xFF6E7A66);
}
