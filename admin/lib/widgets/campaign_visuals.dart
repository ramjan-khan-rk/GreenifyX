import 'package:flutter/material.dart';

import '../core/theme.dart';

const campaignCategories = [
  'Tree Plantation',
  'Mangrove Restoration',
  'Beach Cleaning',
  'Public Area Cleaning',
  'Recycling',
  'Water Conservation',
  'Community Gardening',
  'Awareness Programme',
];

class CategoryStyle {
  const CategoryStyle(this.icon, this.from, this.to);
  final IconData icon;
  final Color from;
  final Color to;
}

CategoryStyle categoryStyle(String? category) {
  switch (category) {
    case 'Tree Plantation':
      return const CategoryStyle(Icons.park_rounded, Color(0xFF1F8A70), Color(0xFF0F5A47));
    case 'Mangrove Restoration':
      return const CategoryStyle(Icons.forest_rounded, Color(0xFF2A9D8F), Color(0xFF1B5E66));
    case 'Beach Cleaning':
      return const CategoryStyle(Icons.beach_access_rounded, Color(0xFF4A90C2), Color(0xFF2B5C8A));
    case 'Public Area Cleaning':
      return const CategoryStyle(Icons.cleaning_services_rounded, Color(0xFF8A5CC2), Color(0xFF5B3A8C));
    case 'Recycling':
      return const CategoryStyle(Icons.recycling_rounded, Color(0xFF3FA76B), Color(0xFF1F6B43));
    case 'Water Conservation':
      return const CategoryStyle(Icons.water_drop_rounded, Color(0xFF3B82C4), Color(0xFF1D4F82));
    case 'Community Gardening':
      return const CategoryStyle(Icons.yard_rounded, Color(0xFF7FA33A), Color(0xFF4E6B1E));
    case 'Awareness Programme':
      return const CategoryStyle(Icons.campaign_rounded, Color(0xFFE36A4A), Color(0xFFA9452C));
    default:
      return const CategoryStyle(Icons.eco_rounded, Brand.eco, Color(0xFF0F5A47));
  }
}

/// Designed cover for a campaign: category gradient, oversized icon, optional photo.
class CampaignCover extends StatelessWidget {
  const CampaignCover({super.key, required this.category, this.imageUrl, this.height = 120, this.child});
  final String? category;
  final String? imageUrl;
  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final style = categoryStyle(category);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [style.from, style.to], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          if (hasImage)
            Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
          else ...[
            Positioned(
              right: -18,
              bottom: -26,
              child: Icon(style.icon, size: height * 1.05, color: Colors.white.withValues(alpha: 0.14)),
            ),
            Positioned(
              left: -30,
              top: -40,
              child: Container(
                width: height,
                height: height,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
          ],
          ?child,
        ],
      ),
    );
  }
}

String campaignStatusLabel(String status) => switch (status) {
      'draft' => 'Draft',
      'active' => 'Active',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status,
    };

Color campaignStatusColor(String status) => switch (status) {
      'active' => Brand.eco,
      'draft' => Brand.muted,
      'completed' => Brand.sky,
      'cancelled' => Brand.danger,
      _ => Brand.muted,
    };

const flagLabels = {
  'outside_geofence': 'Outside site area',
  'outside_campaign_dates': 'Outside campaign dates',
  'low_gps_accuracy': 'Weak GPS signal',
  'duplicate_photo': 'Photo used before',
  'output_above_target': 'Count well above target',
  'no_after_photo': 'No "after" photo',
  'mock_location': 'Fake GPS detected',
};
