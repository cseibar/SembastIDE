
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_view_model.dart';
import 'providers.dart';
import 'record_editor_dialog.dart';
import 'widgets/records_table.dart';
import 'widgets/export_dialog.dart';
import 'widgets/import_dialog.dart';
import 'widgets/new_db_dialog.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final viewModel = ref.read(homeViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.dbPath != null ? 'Sembast IDE - ${state.dbPath!.split(RegExp(r'[\\/]')).last}' : 'Sembast IDE'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add_box, color: Colors.white),
            label: const Text('Nueva', style: TextStyle(color: Colors.white)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => NewDbDialog(
                  onCreate: (folder, name) async {
                    await viewModel.createNewDatabase(folder, name);
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Open Database',
            icon: const Icon(Icons.folder_open),
            onPressed: () async {
              final result = await FilePicker.pickFiles(
                type: FileType.any,
                allowMultiple: false,
              );
              if (result != null && result.files.single.path != null) {
                await viewModel.openDatabase(result.files.single.path!);
              }
            },
          ),
          if (state.dbPath != null) ...[
            TextButton.icon(
              icon: const Icon(Icons.upload_file, color: Colors.white),
              label: const Text('Export', style: TextStyle(color: Colors.white)),
              onPressed: () {
                final stores = state.storeNames.where((s) => s != '_main').toList();
                showDialog(
                  context: context,
                  builder: (context) => ExportDialog(
                    storeNames: stores,
                    onExport: (selectedStores, format) async {
                      await viewModel.exportStores(selectedStores, format);
                    },
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.download, color: Colors.white),
              label: const Text('Import', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['csv', 'json'],
                  allowMultiple: true,
                  dialogTitle: 'Selecciona archivos CSV o JSON para importar',
                );

                if (result != null && result.files.isNotEmpty) {
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => ImportDialog(
                      files: result.files,
                      onImport: (tasks) async {
                        await viewModel.processImport(tasks);
                      },
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.backup, color: Colors.white),
              label: const Text('Backup', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                await viewModel.backupDatabase();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup creado con éxito')),
                );
              },
            ),
            const SizedBox(width: 16),
          ],
          IconButton(
            tooltip: 'Refresh Stores',
            icon: const Icon(Icons.refresh),
            onPressed: state.dbPath == null ? null : () async {
              await viewModel.refreshStores();
            },
          ),
        ],
      ),
      body: state.dbPath == null
          ? Center(
              child: state.isLoading 
                ? const CircularProgressIndicator()
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.data_object, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No Database Opened', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),
                    if (state.recentDbs.isNotEmpty) ...[
                      const Text('Recent Databases', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 400,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: state.recentDbs.length,
                          itemBuilder: (context, index) {
                            final path = state.recentDbs[index];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.history),
                                title: Text(path.split(RegExp(r'[\\/]')).last),
                                subtitle: Text(path, style: const TextStyle(fontSize: 12)),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => viewModel.openDatabase(path),
                              ),
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Open Database'),
                        onPressed: () async {
                          final result = await FilePicker.pickFiles(
                            type: FileType.any,
                            allowMultiple: false,
                          );
                          if (result != null && result.files.single.path != null) {
                            await viewModel.openDatabase(result.files.single.path!);
                          }
                        },
                      ),
                    ]
                  ],
                ),
            )
          : state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    // Sidebar for Stores
                    Material(
                      color: Theme.of(context).cardTheme.color,
                      child: SizedBox(
                        width: 250,
                        child: Column(
                          children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Stores',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: state.storeNames.length,
                              itemBuilder: (context, index) {
                                final store = state.storeNames[index];
                                final isSelected = store == state.selectedStore;
                                return GestureDetector(
                                  onSecondaryTapDown: (details) {
                                    showMenu(
                                      context: context,
                                      position: RelativeRect.fromLTRB(
                                        details.globalPosition.dx,
                                        details.globalPosition.dy,
                                        details.globalPosition.dx,
                                        details.globalPosition.dy,
                                      ),
                                      items: [
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: const Text('Borrar store', style: TextStyle(color: Colors.red)),
                                          onTap: () {
                                            Future.delayed(
                                              const Duration(milliseconds: 10),
                                              () {
                                                if (!context.mounted) return;
                                                showDialog(
                                                  context: context,
                                                  builder: (dialogCtx) => AlertDialog(
                                                    title: Text('Borrar store $store'),
                                                    content: Text('¿Seguro que quieres borrar la tabla "$store" por completo? Se perderán todos sus datos y no se puede deshacer.'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(dialogCtx),
                                                        child: const Text('Cancelar'),
                                                      ),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                        onPressed: () {
                                                          Navigator.pop(dialogCtx);
                                                          viewModel.deleteStore(store);
                                                        },
                                                        child: const Text('Borrar', style: TextStyle(color: Colors.white)),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                  child: ListTile(
                                    title: Text(store),
                                    selected: isSelected,
                                    selectedTileColor: Theme.of(context).colorScheme.primary.withAlpha(26),
                                    onTap: () {
                                      viewModel.loadRecords(store);
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                    // Main area for Records
                    Expanded(
                      child: state.selectedStore == null
                          ? const Center(child: Text('Select a store'))
                          : state.error != null
                              ? Center(child: Text('Error loading records:\n${state.error}', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center))
                              : Column(
                                  children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(
                                              'Records in ${state.selectedStore}',
                                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(width: 24),
                                            Expanded(
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 400),
                                                child: StoreSearchBar(
                                                  initialQuery: state.searchQuery,
                                                  onSubmitted: (value) {
                                                    viewModel.setSearchQuery(value);
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              _showEditor(context, ref, null, null);
                                            },
                                            icon: const Icon(Icons.add),
                                            label: const Text('Add Record'),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (dialogContext) => AlertDialog(
                                                  title: Text('Borrar todos los registros de ${state.selectedStore}'),
                                                  content: Text('¿Seguro que quieres borrar todos los registros de la tabla ${state.selectedStore}? Esta acción no se puede deshacer.'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(dialogContext),
                                                      child: const Text('No'),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                      onPressed: () {
                                                        Navigator.pop(dialogContext);
                                                        viewModel.clearStore(state.selectedStore!);
                                                      },
                                                      child: const Text('Sí', style: TextStyle(color: Colors.white)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.delete_sweep),
                                            label: const Text('Delete all records'),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      if (state.totalRecords > 200)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Showing records ${(state.currentPage * 200) + 1} - ${((state.currentPage + 1) * 200).clamp(0, state.totalRecords)} of ${state.totalRecords}',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.chevron_left),
                                                    onPressed: state.currentPage > 0
                                                        ? () => viewModel.loadRecords(state.selectedStore!, page: state.currentPage - 1)
                                                        : null,
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.chevron_right),
                                                    onPressed: (state.currentPage + 1) * 200 < state.totalRecords
                                                        ? () => viewModel.loadRecords(state.selectedStore!, page: state.currentPage + 1)
                                                        : null,
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                      Expanded(
                                        child: state.records.isEmpty
                                            ? Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Text('No records found.'),
                                                    const SizedBox(height: 16),
                                                    ElevatedButton.icon(
                                                      onPressed: () {
                                                        viewModel.recoverStore(state.selectedStore!);
                                                      },
                                                      icon: const Icon(Icons.build),
                                                      label: const Text('Force Recover Corrupted Data'),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.orange,
                                                        foregroundColor: Colors.white,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    ElevatedButton(
                                                      onPressed: () async {
                                                        final lines = await ref.read(databaseServiceProvider).getRawLinesForStore(state.selectedStore!);
                                                        if (context.mounted) {
                                                          showDialog(
                                                            context: context,
                                                            builder: (context) => AlertDialog(
                                                              title: Text('Raw Data for ${state.selectedStore}'),
                                                              content: SizedBox(
                                                                width: double.maxFinite,
                                                                child: SingleChildScrollView(
                                                                  child: Text(
                                                                    lines.isEmpty ? 'The file has NO lines with this store name.' : lines.join('\n'),
                                                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                                                  ),
                                                                ),
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(context),
                                                                  child: const Text('Close'),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        }
                                                      },
                                                      child: const Text('Debug Raw File Content'),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : RecordsTable(records: state.records),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }

  void _showEditor(BuildContext context, WidgetRef ref, dynamic key, dynamic value) {
    showDialog(
      context: context,
      builder: (context) {
        return RecordEditorDialog(
          recordKey: key,
          initialValue: value,
          onSave: (newKey, newValue) async {
            final viewModel = ref.read(homeViewModelProvider.notifier);
            if (key == null) {
              await viewModel.addRecord(newValue);
            } else {
              await viewModel.updateRecord(key, newValue);
            }
          },
        );
      },
    );
  }
}

class StoreSearchBar extends StatefulWidget {
  final String initialQuery;
  final Function(String) onSubmitted;

  const StoreSearchBar({
    super.key,
    required this.initialQuery,
    required this.onSubmitted,
  });

  @override
  State<StoreSearchBar> createState() => _StoreSearchBarState();
}

class _StoreSearchBarState extends State<StoreSearchBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(StoreSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery &&
        _controller.text != widget.initialQuery) {
      _controller.text = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: 'Buscar en todos los registros...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  widget.onSubmitted('');
                },
              )
            : null,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.all(8),
      ),
      onSubmitted: widget.onSubmitted,
      onChanged: (val) {
        setState(() {}); // show/hide clear icon
      },
    );
  }
}
