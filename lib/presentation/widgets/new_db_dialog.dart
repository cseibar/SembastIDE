import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class NewDbDialog extends StatefulWidget {
  final Future<void> Function(String folderPath, String dbName) onCreate;

  const NewDbDialog({super.key, required this.onCreate});

  @override
  State<NewDbDialog> createState() => _NewDbDialogState();
}

class _NewDbDialogState extends State<NewDbDialog> {
  final _nameController = TextEditingController();
  final _folderController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _folderController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select folder for new database',
    );

    if (selectedDirectory != null) {
      setState(() {
        _folderController.text = selectedDirectory;
      });
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await widget.onCreate(_folderController.text, _nameController.text);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Base de Datos'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del archivo',
                  hintText: 'ej. mi_base_datos',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Introduce un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _folderController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Ruta de la carpeta',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Selecciona una carpeta';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: _pickFolder,
                    tooltip: 'Seleccionar carpeta',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Omitir'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Aceptar'),
        ),
      ],
    );
  }
}
