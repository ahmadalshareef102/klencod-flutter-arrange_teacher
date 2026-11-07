import 'package:flutter/material.dart';
import 'models.dart';

class Dd<T> extends StatelessWidget {
  const Dd({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

List<DropdownMenuItem<int>> lblItems(List<Lbl> l, {bool all = false}) => [
      if (all) const DropdownMenuItem<int>(value: 0, child: Text('الكل')),
      for (final x in l) DropdownMenuItem<int>(value: x.id, child: Text(x.name)),
    ];

int? pickValid(int? cur, List<Lbl> l) =>
    l.any((x) => x.id == cur) ? cur : (l.isEmpty ? null : l.first.id);
