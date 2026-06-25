import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark  => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Resolve brightness-aware tokens.
    final bg      = isDark ? AppColors.paperDark   : AppColors.paper;
    final cardCol = isDark ? AppColors.cardDark    : AppColors.card;
    final inkCol  = isDark ? AppColors.onDark      : AppColors.ink;
    final mutedCol = isDark ? AppColors.onDarkMuted : AppColors.muted;
    final lineCol  = isDark ? const Color(0x1FFFFFFF) : AppColors.line;
    final tealCol  = isDark ? AppColors.tealDark   : AppColors.teal;
    final clayCol  = isDark ? AppColors.clayDark   : AppColors.clay;

    final colorScheme = ColorScheme(
      brightness: brightness,
      // Teal = commit / correct / progress (French cool accent).
      primary: tealCol,
      onPrimary: Colors.white,
      primaryContainer: tealCol.withValues(alpha: 0.12),
      onPrimaryContainer: tealCol,
      // Clay = live action / mic / primary CTA (Korean warm accent).
      secondary: clayCol,
      onSecondary: Colors.white,
      secondaryContainer: clayCol.withValues(alpha: 0.12),
      onSecondaryContainer: clayCol,
      // Rose = destructive only.
      error: AppColors.rose,
      onError: Colors.white,
      errorContainer: AppColors.rose.withValues(alpha: 0.12),
      onErrorContainer: AppColors.rose,
      // Surfaces.
      surface: bg,
      onSurface: inkCol,
      surfaceContainerHighest: cardCol,
      outline: lineCol,
      outlineVariant: lineCol,
    );

    // Base text theme: Figtree for all body/UI slots, then we override
    // display/headline slots with Space Grotesk.
    final baseTextTheme = GoogleFonts.figtreeTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );

    final textTheme = baseTextTheme
        .copyWith(
          // Display = Space Grotesk — prompt word, hero numbers.
          displayLarge:  AppTextStyles.grotesk(56, FontWeight.w700),
          displayMedium: AppTextStyles.grotesk(48, FontWeight.w700),
          displaySmall:  AppTextStyles.grotesk(36, FontWeight.w700),
          // Headline = Space Grotesk — screen titles.
          headlineLarge:  AppTextStyles.grotesk(28, FontWeight.w700),
          headlineMedium: AppTextStyles.grotesk(24, FontWeight.w700),
          headlineSmall:  AppTextStyles.grotesk(20, FontWeight.w700),
          // Title = Figtree — card/section titles.
          titleLarge:  AppTextStyles.fig(18, FontWeight.w700),
          titleMedium: AppTextStyles.fig(16, FontWeight.w600),
          titleSmall:  AppTextStyles.fig(14, FontWeight.w600),
          // Body = Figtree.
          bodyLarge:  AppTextStyles.fig(16, FontWeight.w400, height: 1.55),
          bodyMedium: AppTextStyles.fig(15, FontWeight.w400, height: 1.55),
          bodySmall:  AppTextStyles.fig(13, FontWeight.w400, height: 1.5),
          // Labels: large = Figtree buttons; small = Space Mono eyebrows.
          labelLarge:  AppTextStyles.fig(14, FontWeight.w600),
          labelMedium: AppTextStyles.fig(12, FontWeight.w600),
          labelSmall:  AppTextStyles.mono(11, FontWeight.w700, letterSpacing: 1.8),
        )
        .apply(bodyColor: inkCol, displayColor: inkCol);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,

      // ── AppBar ──────────────────────────────────────────────────────────
      // Transparent so the dotted ground shows through on every screen.
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: inkCol,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.grotesk(22, FontWeight.w700)
            .copyWith(color: inkCol),
        iconTheme: IconThemeData(color: inkCol, size: 22),
      ),

      // ── Navigation bar ──────────────────────────────────────────────────
      // We render our own frosted shell; this keeps the system nav bar
      // minimal in case it appears.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          AppTextStyles.fig(10, FontWeight.w600).copyWith(color: inkCol),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: inkCol, size: 24);
          }
          return const IconThemeData(color: AppColors.faint, size: 24);
        }),
      ),

      // ── Cards ───────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: lineCol),
        ),
        color: cardCol,
      ),

      // ── Inputs ──────────────────────────────────────────────────────────
      // Clay focus border matches the "Korean warm" input convention.
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: lineCol),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: lineCol),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: clayCol, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.rose, width: 1.5),
        ),
        filled: true,
        fillColor: cardCol,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: AppTextStyles.fig(14, FontWeight.w500)
            .copyWith(color: mutedCol),
        hintStyle: AppTextStyles.fig(14, FontWeight.w400)
            .copyWith(color: AppColors.faint),
      ),

      // ── Buttons ─────────────────────────────────────────────────────────
      // FilledButton = teal — commit / continue / correct.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tealCol,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: AppTextStyles.fig(15, FontWeight.w700),
        ),
      ),
      // ElevatedButton = clay — primary CTA / mic / live action.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: clayCol,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: AppTextStyles.fig(15, FontWeight.w700),
        ),
      ),
      // OutlinedButton = frosted secondary (glass effect applied in widget).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: mutedCol,
          side: BorderSide(color: lineCol),
          backgroundColor: Colors.white.withValues(alpha: 0.5),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          textStyle: AppTextStyles.fig(14, FontWeight.w600),
        ),
      ),
      // TextButton = muted; rose variant applied in-widget for destructive.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: mutedCol,
          textStyle: AppTextStyles.fig(14, FontWeight.w600),
        ),
      ),

      // ── Misc ────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
          color: lineCol, thickness: 1, space: 1),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.card : AppColors.ink,
        contentTextStyle: AppTextStyles.fig(14, FontWeight.w500).copyWith(
          color: isDark ? AppColors.ink : AppColors.onDark,
        ),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: cardCol,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: lineCol),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        labelStyle: AppTextStyles.fig(13, FontWeight.w600),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28)),
        titleTextStyle: AppTextStyles.grotesk(20, FontWeight.w700)
            .copyWith(color: inkCol),
        contentTextStyle: AppTextStyles.fig(15, FontWeight.w400)
            .copyWith(color: mutedCol),
        elevation: 0,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 0,
      ),
    );
  }
}
