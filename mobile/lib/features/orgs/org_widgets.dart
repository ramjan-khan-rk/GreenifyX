import 'package:flutter/material.dart';

const orgTypes = ["Company", "School", "University", "NGO", "Community", "Government"];

IconData orgIcon(String type) => switch (type) {
      "Company" => Icons.business_rounded,
      "School" => Icons.school_rounded,
      "University" => Icons.account_balance_rounded,
      "NGO" => Icons.volunteer_activism_rounded,
      "Community" => Icons.holiday_village_rounded,
      "Government" => Icons.account_balance_wallet_rounded,
      _ => Icons.groups_rounded,
    };

String compactNumber(num? v) {
  final x = (v ?? 0).round();
  return x >= 10000 ? "${(x / 1000).toStringAsFixed(1)}k" : "$x";
}
