import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Marathi/Hindi hint copy needs a Devanagari-aware font or conjuncts
/// (e.g. प्र + श्न → प्रश्न) can render incorrectly with the default UI font.
TextStyle quizDevanagariTextStyle({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
}) {
  return GoogleFonts.notoSansDevanagari(
    fontSize: fontSize ?? 13,
    fontWeight: fontWeight ?? FontWeight.w500,
    color: color ?? Colors.black,
    height: height ?? 1.35,
  );
}
