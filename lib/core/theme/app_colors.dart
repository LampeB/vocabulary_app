import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Ground ────────────────────────────────────────────────────────────────
  static const paper    = Color(0xFFF6F1EA); // app background — every screen
  static const surface  = Color(0xFFEFE7DB); // soft secondary surfaces
  static const card     = Color(0xFFFFFFFF); // list cards, inputs, vocab rows
  static const inkDark  = Color(0xFF241F1B); // hands-free / immersive dark bg

  // ── Text ──────────────────────────────────────────────────────────────────
  static const ink      = Color(0xFF2B2622); // primary text; also dark hero cards
  static const muted    = Color(0xFF756C62); // secondary text
  static const muted2   = Color(0xFF8A857C); // eyebrow labels, meta
  static const faint    = Color(0xFFA99F90); // captions, inactive nav
  static const line     = Color(0xFFECE3D7); // borders, progress track, dividers

  // ── Accents ───────────────────────────────────────────────────────────────
  /// French / cool accent — progress fills, correct state, commit actions.
  static const teal      = Color(0xFF4C8C86);
  static const tealLight = Color(0xFF6BA39D); // waveform low bars
  /// Korean / warm accent — mic, live/voice state, primary CTA, streak energy.
  static const clay      = Color(0xFFD08358);
  static const clayLight = Color(0xFFE0A079); // waveform warm bars
  static const clayDeep  = Color(0xFFC4703F); // clay text on light (AA contrast)
  /// Destructive — delete, sign-out, error states only.
  static const rose      = Color(0xFFB0556B);

  // ── On-dark text ──────────────────────────────────────────────────────────
  static const onDark      = Color(0xFFF6F1EA);
  static const onDarkMuted = Color(0xFFCFC6BA);
  static const onDarkFaint = Color(0xFF9A9086);

  // ── Dark theme surface overrides ──────────────────────────────────────────
  static const paperDark = Color(0xFF241F1B);
  static const cardDark  = Color(0xFF2E2823);
  static const tealDark  = Color(0xFF5FB0A8); // slightly brighter on dark bg
  static const clayDark  = Color(0xFFFF8A55); // slightly brighter on dark bg

  // ── List accent palette (user picks one per list) ─────────────────────────
  static const paletteClay   = Color(0xFFD08358);
  static const paletteTeal   = Color(0xFF4C8C86);
  static const paletteIndigo = Color(0xFF6B6CB0);
  static const paletteRose   = Color(0xFFB0556B);
  static const paletteStone  = Color(0xFF7A7066);
  static const listPalette   = [
    paletteClay, paletteTeal, paletteIndigo, paletteRose, paletteStone,
  ];

  // ── Feedback flashes ──────────────────────────────────────────────────────
  static const correctFlash   = Color(0x9934C759); // vivid green 60 %
  static const incorrectFlash = Color(0x99FF3B30); // vivid red 60 %

  // ── Legacy aliases (keep existing code compiling while screens are migrated)
  static const primary        = clay;
  static const primaryVariant = clayDeep;
  static const secondary      = rose;
  static const success        = teal;
  static const warning        = clayLight;
  static const frenchBlue     = teal;
  static const koreanRed      = clay;
  static const grey100        = Color(0xFFF5F0EA);
  static const grey300        = line;
  static const grey500        = faint;
  static const grey700        = muted;
  static const grey900        = ink;
  static const onSurface      = ink;
  static const onSurfaceDark  = onDark;
  static const surfaceVariant      = surface;
  static const surfaceDark         = paperDark;
  static const surfaceVariantDark  = cardDark;
  static const streakActive   = clay;
  static const streakInactive = line;
}
