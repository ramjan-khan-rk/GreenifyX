import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class BrandCopy {
  BrandCopy._();

  static const name = "GreenifyX";
  static const tagline = "Small Actions Big Impact";
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get heading => GoogleFonts.manrope(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.forest,
  );

  static TextStyle get title => GoogleFonts.manrope(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.forest,
  );

  static TextStyle get body => GoogleFonts.manrope(
    fontSize: 16,
    color: AppColors.text,
  );

  static TextStyle get subtitle => GoogleFonts.manrope(
    fontSize: 14,
    color: AppColors.subtitle,
  );

  static TextStyle get tagline => GoogleFonts.manrope(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: AppColors.navy,
  );

  static TextStyle get button => GoogleFonts.manrope(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}
