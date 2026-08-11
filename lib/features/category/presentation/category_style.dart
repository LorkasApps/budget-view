import 'package:flutter/material.dart';

/// Icons offered in the category form. The map key is what gets persisted, so
/// entries may be added but never renamed — a rename orphans existing rows.
const Map<String, IconData> categoryIcons = {
  'label': Icons.label,
  'shopping_cart': Icons.shopping_cart,
  'restaurant': Icons.restaurant,
  'local_cafe': Icons.local_cafe,
  'home': Icons.home,
  'bolt': Icons.bolt,
  'water_drop': Icons.water_drop,
  'wifi': Icons.wifi,
  'smartphone': Icons.smartphone,
  'directions_car': Icons.directions_car,
  'local_gas_station': Icons.local_gas_station,
  'train': Icons.train,
  'medical_services': Icons.medical_services,
  'fitness_center': Icons.fitness_center,
  'school': Icons.school,
  'child_care': Icons.child_care,
  'pets': Icons.pets,
  'movie': Icons.movie,
  'sports_esports': Icons.sports_esports,
  'card_giftcard': Icons.card_giftcard,
  'savings': Icons.savings,
  'payments': Icons.payments,
  'receipt_long': Icons.receipt_long,
  'shield': Icons.shield,
};

IconData categoryIcon(String name) => categoryIcons[name] ?? Icons.label;

const List<String> categoryPalette = [
  '#E53935',
  '#D81B60',
  '#8E24AA',
  '#5E35B1',
  '#3949AB',
  '#1E88E5',
  '#00897B',
  '#43A047',
  '#F9A825',
  '#FB8C00',
  '#6D4C41',
  '#607D8B',
];

const Color _fallbackColor = Color(0xFF607D8B);

Color categoryColor(String hex) {
  final digits = hex.replaceFirst('#', '');
  if (digits.length != 6) return _fallbackColor;
  final value = int.tryParse(digits, radix: 16);
  if (value == null) return _fallbackColor;
  return Color(0xFF000000 | value);
}
