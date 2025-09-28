import 'package:flutter/material.dart';

const defaultCategories = <String>[
  'Geschäftlich',
  'Privat',
  'Essen',
  'Feier',
  'Konzert',
  'Urlaub',
  'Besuch',
];

class CategoryChips extends StatelessWidget {
  const CategoryChips({super.key, required this.selectedCategory, required this.onCategorySelected});
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  @override
  Widget build(BuildContext context) {
    final normalizedSelected = selectedCategory.toLowerCase();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in defaultCategories)
          ChoiceChip(
            label: Text(category),
            selected: category.toLowerCase() == normalizedSelected,
            onSelected: (value) {
              if (value) onCategorySelected(category);
            },
          ),
      ],
    );
  }
}
