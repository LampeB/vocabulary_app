import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens from the VocabKR v3 “Sentier de cartes” design archive.
///
/// These values are deliberately scoped to v3 components while legacy screens
/// are migrated. Do not substitute an existing application colour: the archive
/// is the source of truth for new v3 surfaces.
abstract final class V3Colors {
  static const app = Color(0xFF262A24);
  static const block = Color(0xFF313A2F);
  static const block2 = Color(0xFF333B31);
  static const block3 = Color(0xFF2E362C);
  static const chip = Color(0xFF3D4539);
  static const chip2 = Color(0xFF45503F);
  static const ruleDark = Color(0xFF4E5A4A);

  static const paper = Color(0xFFFBF7EC);
  static const paperPanel = Color(0xFFF3EDE0);
  static const paperInner = Color(0xFFEFE8D6);
  static const edge1 = Color(0xFFEAE3D2);
  static const edge2 = Color(0xFFCFC9B8);
  static const edge3 = Color(0xFFB3AE9E);

  static const ink = Color(0xFF23231D);
  static const ink70 = Color(0xFF4B473C);
  static const ink60 = Color(0xFF5C5749);
  static const inkMeta = Color(0xFF5E5A4C);
  static const inkLight = Color(0xFFF1EDE2);
  static const inkLight70 = Color(0xFFC9D0C6);
  static const inkLight60 = Color(0xFFAFB9AD);
  static const inkLight45 = Color(0xFF8E9884);

  static const terra = Color(0xFF9B4F13);
  static const terraInk = Color(0xFF8B3F0D);
  static const amber = Color(0xFFEBC08C);
  static const moss = Color(0xFF6E7A66);
  static const rule = Color(0xFFE4DCC8);
  static const ruleStrong = Color(0xFFD3CBB6);
}

abstract final class V3Text {
  static TextStyle title(double size, {Color color = V3Colors.ink}) =>
      GoogleFonts.dmSerifDisplay(
        fontSize: size,
        height: 1.06,
        color: color,
      );

  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = V3Colors.ink,
    double? height,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        height: height ?? 1.4,
        color: color,
      );

  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = V3Colors.inkMeta,
  }) =>
      GoogleFonts.spaceMono(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 1.4,
        height: 1.2,
        color: color,
      );

  static TextStyle korean(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color color = V3Colors.ink,
  }) =>
      GoogleFonts.notoSerifKr(
        fontSize: size,
        fontWeight: weight,
        height: 1.25,
        color: color,
      );
}

abstract final class V3Radii {
  static const sheet = Radius.circular(20);
  static const card = Radius.circular(18);
  static const block = Radius.circular(14);
  static const button = Radius.circular(12);
}
