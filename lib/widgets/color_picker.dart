import 'package:flutter/material.dart';

class ColorPicker extends StatelessWidget {
  final String? selectedColor;
  final Function(String) onColorSelected;

  static const List<Map<String, dynamic>> colors = [
    {'name': 'Синий', 'value': 'blue', 'color': Colors.blue},
    {'name': 'Красный', 'value': 'red', 'color': Colors.red},
    {'name': 'Зеленый', 'value': 'green', 'color': Colors.green},
    {'name': 'Фиолетовый', 'value': 'purple', 'color': Colors.purple},
    {'name': 'Оранжевый', 'value': 'orange', 'color': Colors.orange},
  ];

  const ColorPicker({
    Key? key,
    this.selectedColor,
    required this.onColorSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((color) {
        return GestureDetector(
          onTap: () => onColorSelected(color['value']),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color['color'],
              borderRadius: BorderRadius.circular(30),
              border: selectedColor == color['value']
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
            ),
            child: selectedColor == color['value']
                ? const Center(
                    child: Icon(Icons.check, color: Colors.white),
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}
