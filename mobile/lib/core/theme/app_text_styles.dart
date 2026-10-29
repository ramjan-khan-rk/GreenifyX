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

  static final heading = GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.forest,
  );

  static final title = GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.forest,
  );

  static final body = GoogleFonts.poppins(
    fontSize: 16,
    color: AppColors.text,
  );

  static final subtitle = GoogleFonts.poppins(
    fontSize: 14,
    color: AppColors.subtitle,
  );

  static final tagline = GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: AppColors.navy,
  );

  static final button = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}
