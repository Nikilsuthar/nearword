import 'package:flutter/material.dart';

/// Maps the icon names in categories.json to Material icons.
IconData categoryIcon(String name) {
  switch (name) {
    case 'pets':
      return Icons.pets_rounded;
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'sports_soccer':
      return Icons.sports_soccer_rounded;
    case 'devices':
      return Icons.devices_rounded;
    case 'park':
      return Icons.park_rounded;
    case 'work':
      return Icons.work_rounded;
    case 'directions_car':
      return Icons.directions_car_rounded;
    case 'music_note':
      return Icons.music_note_rounded;
    case 'rocket_launch':
      return Icons.rocket_launch_rounded;
    case 'favorite':
      return Icons.favorite_rounded;
    default:
      return Icons.category_rounded;
  }
}
