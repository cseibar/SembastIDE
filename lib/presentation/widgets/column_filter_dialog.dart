import 'package:flutter/material.dart';
import '../../data/models/column_filter.dart';

class ColumnFilterDialog extends StatefulWidget {
  final String columnName;
  final ColumnFilter? initialFilter;
  final Function(ColumnFilter?) onApply;

  const ColumnFilterDialog({
    super.key,
    required this.columnName,
    this.initialFilter,
    required this.onApply,
  });

  @override
  State<ColumnFilterDialog> createState() => _ColumnFilterDialogState();
}

class _ColumnFilterDialogState extends State<ColumnFilterDialog> {
  late ColumnFilterType _selectedType;
  late TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialFilter?.type ?? ColumnFilterType.contains;
    _valueController = TextEditingController(text: widget.initialFilter?.value?.toString() ?? '');
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Filter column: ${widget.columnName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<ColumnFilterType>(
            value: _selectedType,
            items: ColumnFilterType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(_getTypeLabel(type)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedType = val;
                });
              }
            },
            decoration: const InputDecoration(labelText: 'Condition'),
          ),
          if (_selectedType != ColumnFilterType.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
              ),
              keyboardType: _isNumberType(_selectedType) ? TextInputType.number : TextInputType.text,
              onSubmitted: (_) => _apply(),
            ),
          ],
        ],
      ),
      actions: [
        if (widget.initialFilter != null)
          TextButton(
            onPressed: () {
              widget.onApply(null);
              Navigator.pop(context);
            },
            child: const Text('Remove Filter', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _apply() {
    final value = _valueController.text.trim();
    if (value.isEmpty && _selectedType != ColumnFilterType.isNotEmpty) {
      widget.onApply(null);
    } else {
      widget.onApply(ColumnFilter(
        column: widget.columnName,
        type: _selectedType,
        value: value,
      ));
    }
    Navigator.pop(context);
  }

  bool _isNumberType(ColumnFilterType type) {
    return type == ColumnFilterType.equal || 
           type == ColumnFilterType.lessThan || 
           type == ColumnFilterType.greaterThan ||
           type == ColumnFilterType.year;
  }

  String _getTypeLabel(ColumnFilterType type) {
    switch (type) {
      case ColumnFilterType.contains:
        return 'Text: Contains';
      case ColumnFilterType.startsWith:
        return 'Text: Starts with';
      case ColumnFilterType.isNotEmpty:
        return 'Text: Is not empty';
      case ColumnFilterType.equal:
        return 'Number/Text: Equal to';
      case ColumnFilterType.lessThan:
        return 'Number: Less than';
      case ColumnFilterType.greaterThan:
        return 'Number: Greater than';
      case ColumnFilterType.year:
        return 'Date: Year equals';
    }
  }
}
