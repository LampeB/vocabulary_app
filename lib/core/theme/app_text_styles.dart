import 'package:flutter/material.dart';

abstract final class AppTextStyles {
  static const _base = TextStyle(fontFamily: 'Inter', letterSpacing: 0);

  static final displayLarge = _base.copyWith(fontSize: 48, fontWeight: FontWeight.w800, height: 1.1);
  static final displayMedium = _base.copyWith(fontSize: 36, fontWeight: FontWeight.w700, height: 1.2);
  static final headlineLarge = _base.copyWith(fontSize: 28, fontWeight: FontWeight.w700, height: 1.25);
  static final headlineMedium = _base.copyWith(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3);
  static final titleLarge = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4);
  static final titleMedium = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);
  static final bodyLarge = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);
  static final bodyMedium = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static final bodySmall = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5);
  static final labelLarge = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.4);
  static final labelSmall = _base.copyWith(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5);

  static final koreanWord = TextStyle(
    fontFamily: 'NotoSansKR',
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
  static final koreanBody = TextStyle(
    fontFamily: 'NotoSansKR',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );
}
