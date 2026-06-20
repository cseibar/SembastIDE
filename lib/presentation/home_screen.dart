
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/export_service.dart';
import 'home_view_model.dart';
import 'providers.dart';
import 'record_editor_dialog.dart';
import 'widgets/records_table.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final viewModel = ref.read(homeViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sembast IDE'),
        actions: [
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
          if (state.selectedStore != null) ...[
            PopupMenuButton<String>(
              tooltip: 'Import/Export',
              icon: const Icon(Icons.import_export),
              onSelected: (value) async {
                final storeName = state.selectedStore!;
                if (value == 'export_json') {
                  await ExportService.exportToJson(storeName, state.records);
                } else if (value == 'export_csv') {
                  await ExportService.exportToCsv(storeName, state.records);
                } else if (value == 'export_db') {
                  await ExportService.exportToSembast(storeName, state.records);
                } else if (value == 'import_json') {
                  final data = await ExportService.importFromJson();
                  if (data != null) {
                    await viewModel.importFromJsonData(data);
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'import_json', child: Text('Import JSON')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'export_json', child: Text('Export to JSON')),
                const PopupMenuItem(value: 'export_csv', child: Text('Export to CSV')),
                const PopupMenuItem(value: 'export_db', child: Text('Export to Sembast DB')),
              ],
            ),
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
                                return ListTile(
                                  title: Text(store),
                                  selected: isSelected,
                                  selectedTileColor: Theme.of(context).colorScheme.primary.withAlpha(26),
                                  onTap: () {
                                    viewModel.loadRecords(store);
                                  },
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
                                      Text(
                                        'Records in ${state.selectedStore}',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          _showEditor(context, ref, null, null);
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add Record'),
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
