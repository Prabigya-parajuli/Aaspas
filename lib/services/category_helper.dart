import 'package:flutter/material.dart';

class CategoryHelper {
  static IconData getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'tech':
        return Icons.computer;
      case 'health':
        return Icons.local_hospital;
      case 'culture':
        return Icons.theater_comedy;
      case 'sports':
        return Icons.sports_basketball;
      case 'volunteer':
        return Icons.volunteer_activism;
      default:
        return Icons.event;
    }
  }

  static Color getColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'tech':
        return Colors.blue;
      case 'health':
        return Colors.red;
      case 'culture':
        return Colors.purple;
      case 'sports':
        return Colors.orange;
      case 'volunteer':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  static Color getLightColorForCategory(String category) {
    final color = getColorForCategory(category);
    return color.withOpacity(0.1);
  }

  static const List<String> categories = [
    'Tech',
    'Health',
    'Culture',
    'Sports',
    'Volunteer',
    'Other',
  ];
}