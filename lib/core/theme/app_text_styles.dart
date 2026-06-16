import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography system — three Latin families + Noto Sans KR for Hangul.
///
/// Space Grotesk 600/700  — display: prompt word, titles, hero numbers
/// Figtree 400–700        — UI & body: buttons, list text, paragraphs
/// Space Mono 400/700     — data & labels: eyebrows (UPPERCASE), counters, codes
/// Noto Sans KR 400–700   — all Korean / Hangul (sized ~1–2px larger for balance)
abstract final class AppTextStyles {
  // ── Font constructors ─────────────────────────────────────────────────────

  static TextStyle grotesk(
    double size,
    FontWeight weight, {
    double? letterSpacing,
    double? height,
    Color? color,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        // Tight tracking is the hallmark of Space Grotesk in this design.
        letterSpacing: letterSpacing ?? (size * -0.02),
        height: height,
        color: color,
      );

  static TextStyle fig(
    double size,
    FontWeight weight, {
    double? letterSpacing,
    double? height,
    Color? color,
  }) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
      );

  static TextStyle mono(
    double size,
    FontWeight weight, {
    double? letterSpacing,
    double? height,
    Color? color,
  }) =>
      GoogleFonts.spaceMono(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
      );

  static TextStyle kr(
    double size,
    FontWeight weight, {
    double? height,
    Color? color,
  }) =>
      GoogleFonts.notoSansKr(
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color,
      );

  // ── Named scale ───────────────────────────────────────────────────────────

  /// Quiz prompt word — Space Grotesk 56/700, tight tracking.
  static final promptWord  = grotesk(56, FontWeight.w700);

  /// Hands-free immersive prompt — Space Grotesk 48/700.
  static final promptLarge = grotesk(48, FontWeight.w700);

  /// Screen title (AppBar / modals) — Space Grotesk 24/700.
  static final screenTitle = grotesk(24, FontWeight.w700);

  /// Section heading — Space Grotesk 20/700.
  static final sectionTitle = grotesk(20, FontWeight.w700);

  /// Hero number (streak count, accuracy %) — Space Grotesk 48/700.
  static final heroNumber  = grotesk(48, FontWeight.w700);

  /// Large stat — Space Grotesk 36/700.
  static final statLarge   = grotesk(36, FontWeight.w700);

  // Figtree body & UI
  static final body        = fig(15, FontWeight.w400, height: 1.55);
  static final bodyStrong  = fig(15, FontWeight.w600);
  static final label       = fig(14, FontWeight.w600);
  static final labelSmall  = fig(13, FontWeight.w600);
  static final caption     = fig(13, FontWeight.w400);
  static final captionSmall = fig(12, FontWeight.w400);

  /// Button text — Figtree 15/700.
  static final button      = fig(15, FontWeight.w700);

  // Space Mono data labels
  /// Eyebrow label — 11px UPPERCASE, 0.16em tracking.
  static final eyebrow     = mono(11, FontWeight.w700, letterSpacing: 1.8);

  /// Compact eyebrow — 10px UPPERCASE.
  static final eyebrowSm   = mono(10, FontWeight.w700, letterSpacing: 1.6);

  /// Counter — Space Mono 13/700 (e.g. "07/20").
  static final counter     = mono(13, FontWeight.w700);

  /// Data label — Space Mono 12/400.
  static final dataLabel   = mono(12, FontWeight.w400);

  // Noto Sans KR — Hangul
  /// Large Korean prompt (quiz answer reveal) — 58/700.
  static final koreanPrompt = kr(58, FontWeight.w700, height: 1.2);

  /// Korean in word pairs / list rows — 17/500.
  static final koreanBody   = kr(17, FontWeight.w500, height: 1.4);

  /// Small Korean (romaji companion line) — 14/400.
  static final koreanCaption = kr(14, FontWeight.w400, height: 1.4);
}
