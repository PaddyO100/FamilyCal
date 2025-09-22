import 'package:flutter/material.dart';

const defaultCategories = <String>[
  'geschäftlich',
  'privat',
  'essen',
  'feier',
  'konzert',
  'urlaub',
  'besuch',
];

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in defaultCategories)
          ChoiceChip(
            label: Text(category),
            selected: selectedCategory == category,
            onSelected: (value) {
              if (value) {
                onCategorySelected(category);
              }
            },
          ),
      ],
    );
  }
}
