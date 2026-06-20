import 'dart:convert';
import 'package:flutter/material.dart';

class RecordEditorDialog extends StatefulWidget {
  final dynamic recordKey;
  final dynamic initialValue;
  final Function(dynamic key, Map<String, dynamic> value) onSave;

  const RecordEditorDialog({
    super.key,
    this.recordKey,
    this.initialValue,
    required this.onSave,
  });

  @override
  State<RecordEditorDialog> createState() => _RecordEditorDialogState();
}

class _RecordEditorDialogState extends State<RecordEditorDialog> {
  late TextEditingController _jsonController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    String initialText = "{\n  \n}";
    if (widget.initialValue != null) {
      initialText = const JsonEncoder.withIndent('  ').convert(widget.initialValue);
    }
    _jsonController = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  void _save() {
    try {
      final decoded = jsonDecode(_jsonController.text);
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _errorText = 'Root must be a JSON object';
        });
        return;
      }
      widget.onSave(widget.recordKey, decoded);
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorText = 'Invalid JSON: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.recordKey == null ? 'Add Record' : 'Edit Record (Key: ${widget.recordKey})'),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Value (JSON)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withAlpha(128)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _jsonController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() {
                        _errorText = null;
                      });
                    }
                  },
                ),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!, style: const TextStyle(color: Colors.redAccent)),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
