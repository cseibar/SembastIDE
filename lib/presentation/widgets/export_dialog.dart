import 'package:flutter/material.dart';

class ExportDialog extends StatefulWidget {
  final List<String> storeNames;
  final Function(List<String> selectedStores, String format) onExport;

  const ExportDialog({
    super.key,
    required this.storeNames,
    required this.onExport,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  final Set<String> _selectedStores = {};
  String _selectedFormat = 'CSV';

  @override
  void initState() {
    super.initState();
    // Pre-select all stores
    _selectedStores.addAll(widget.storeNames);
  }

  bool get _allSelected => _selectedStores.length == widget.storeNames.length && widget.storeNames.isNotEmpty;

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedStores.addAll(widget.storeNames);
      } else {
        _selectedStores.clear();
      }
    });
  }

  void _toggleStore(String storeName, bool? value) {
    setState(() {
      if (value == true) {
        _selectedStores.add(storeName);
      } else {
        _selectedStores.remove(storeName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Stores'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Format Selection
            RadioGroup<String>(
              groupValue: _selectedFormat,
              onChanged: (val) => setState(() => _selectedFormat = val!),
              child: Row(
                children: [
                  const Text('Format: '),
                  Radio<String>(
                    value: 'CSV',
                  ),
                  const Text('CSV'),
                  Radio<String>(
                    value: 'JSON',
                  ),
                  const Text('JSON'),
                ],
              ),
            ),
            const Divider(),
            
            // Master Checkbox Header
            ListTile(
              leading: Checkbox(
                value: _allSelected,
                onChanged: _toggleAll,
              ),
              title: const Text('Stores', style: TextStyle(fontWeight: FontWeight.bold)),
              tileColor: Colors.grey.withValues(alpha: 0.1),
            ),
            
            // Stores List
            Expanded(
              child: ListView.builder(
                itemCount: widget.storeNames.length,
                itemBuilder: (context, index) {
                  final storeName = widget.storeNames[index];
                  return CheckboxListTile(
                    value: _selectedStores.contains(storeName),
                    onChanged: (val) => _toggleStore(storeName, val),
                    title: Text(storeName),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Omitir'),
        ),
        ElevatedButton(
          onPressed: _selectedStores.isEmpty
              ? null
              : () {
                  Navigator.pop(context);
                  widget.onExport(_selectedStores.toList(), _selectedFormat);
                },
          child: const Text('Exportar'),
        ),
      ],
    );
  }
}
