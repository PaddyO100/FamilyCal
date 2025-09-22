import 'package:flutter/material.dart';

class RoleColorPicker extends StatelessWidget {
  const RoleColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  static const _palette = <Color>[
    Color(0xFF5B67F1),
    Color(0xFF6F75F3),
    Color(0xFF9D7BFF),
    Color(0xFF00BFA6),
    Color(0xFFFFB74D),
    Color(0xFFEC407A),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: _palette
          .map(
            (color) => GestureDetector(
              onTap: () => onColorSelected(color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: selectedColor == color ? 48 : 40,
                height: selectedColor == color ? 48 : 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedColor == color
                        ? Theme.of(context).colorScheme.onPrimary
                        : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 4,
                      spreadRadius: 1,
                      color: Colors.black12,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
