import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../home_view_model.dart';
import '../../data/generic_repository.dart';

class ImportDialog extends StatefulWidget {
  final List<PlatformFile> files;
  final Future<void> Function(List<ImportTaskModel> tasks) onImport;

  const ImportDialog({super.key, required this.files, required this.onImport});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  late List<ImportTaskModel> _tasks;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tasks = widget.files.map((file) {
      return ImportTaskModel(
        storeName: p.basenameWithoutExtension(file.name),
        filePath: file.path!,
        action: ImportAction.append,
      );
    }).toList();
  }

  String _getActionExplanation(ImportAction action) {
    switch (action) {
      case ImportAction.append:
        return 'Añade todos los registros ignorando duplicados y generando nuevos IDs si chocan.';
      case ImportAction.overwrite:
        return 'Borra la tabla actual por completo y la sustituye por estos datos.';
      case ImportAction.addNew:
        return 'Solo añade los registros cuyas claves (IDs) no existan ya en la tabla.';
    }
  }

  String _getActionName(ImportAction action) {
    switch (action) {
      case ImportAction.append:
        return 'Añadir';
      case ImportAction.overwrite:
        return 'Sobreescribir';
      case ImportAction.addNew:
        return 'Añadir nuevos registros';
    }
  }

  void _submit() async {
    // Check if any action is overwrite to ask for confirmation
    final hasOverwrite = _tasks.any((t) => t.action == ImportAction.overwrite);

    if (hasOverwrite) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmación de Sobreescritura'),
          content: const Text('Has seleccionado "Sobreescribir" para una o más tablas. Esto borrará irreversiblemente los datos existentes en esas tablas antes de importar. ¿Estás seguro?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, sobreescribir', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onImport(_tasks);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importando: $e')),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurar Importación'),
      content: SizedBox(
        width: 900,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Store', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Archivo', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Acción', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Explicación', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _tasks.map((task) {
              return DataRow(
                cells: [
                  DataCell(
                    TextFormField(
                      initialValue: task.storeName,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (val) {
                        task.storeName = val.trim();
                      },
                    ),
                  ),
                  DataCell(Text(p.basename(task.filePath))),
                  DataCell(
                    DropdownButton<ImportAction>(
                      value: task.action,
                      isExpanded: true,
                      underline: const SizedBox(),
                      onChanged: (newAction) {
                        if (newAction != null) {
                          setState(() {
                            task.action = newAction;
                          });
                        }
                      },
                      items: ImportAction.values.map((act) {
                        return DropdownMenuItem(
                          value: act,
                          child: Text(_getActionName(act)),
                        );
                      }).toList(),
                    ),
                  ),
                  DataCell(
                    Text(
                      _getActionExplanation(task.action),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              );
            }).toList(),
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
            : const Text('Importar'),
        ),
      ],
    );
  }
}
