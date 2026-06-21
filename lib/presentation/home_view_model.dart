import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sembast/sembast.dart';
import '../data/generic_repository.dart';
import '../data/models/column_filter.dart';
import 'providers.dart';

part 'home_view_model.g.dart';

class HomeState {
  final String? dbPath;
  final List<String> storeNames;
  final String? selectedStore;
  final List<RecordSnapshot<dynamic, dynamic>> records;
  final List<String> recentDbs;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final int totalRecords;
  final String searchQuery;
  final List<ColumnFilter> columnFilters;
  final String? sortColumn;
  final bool sortAscending;

  HomeState({
    this.dbPath,
    this.storeNames = const [],
    this.selectedStore,
    this.records = const [],
    this.recentDbs = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 0,
    this.totalRecords = 0,
    this.searchQuery = '',
    this.columnFilters = const [],
    this.sortColumn,
    this.sortAscending = true,
  });

  HomeState copyWith({
    String? dbPath,
    List<String>? storeNames,
    String? selectedStore,
    List<RecordSnapshot<dynamic, dynamic>>? records,
    List<String>? recentDbs,
    bool? isLoading,
    String? error,
    int? currentPage,
    int? totalRecords,
    String? searchQuery,
    List<ColumnFilter>? columnFilters,
    String? sortColumn,
    bool? sortAscending,
  }) {
    return HomeState(
      dbPath: dbPath ?? this.dbPath,
      storeNames: storeNames ?? this.storeNames,
      selectedStore: selectedStore ?? this.selectedStore,
      records: records ?? this.records,
      recentDbs: recentDbs ?? this.recentDbs,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Allow nulling error
      currentPage: currentPage ?? this.currentPage,
      totalRecords: totalRecords ?? this.totalRecords,
      searchQuery: searchQuery ?? this.searchQuery,
      columnFilters: columnFilters ?? this.columnFilters,
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

@riverpod
class HomeViewModel extends _$HomeViewModel {
  @override
  HomeState build() {
    Future.microtask(() => _initSettings());
    return HomeState();
  }

  Future<void> _initSettings() async {
    state = state.copyWith(isLoading: true);
    final settingsService = ref.read(settingsServiceProvider);
    await settingsService.init();
    final recents = await settingsService.getRecentDatabases();
    state = state.copyWith(recentDbs: recents, isLoading: false);
  }

  GenericRepository _getRepo() {
    final dbService = ref.read(databaseServiceProvider);
    if (dbService.db == null) throw Exception("Database not open");
    return GenericRepository(dbService.db!);
  }

  Future<void> openDatabase(String path) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dbService = ref.read(databaseServiceProvider);
      await dbService.openDatabase(path);

      // Save to recent
      final settingsService = ref.read(settingsServiceProvider);
      await settingsService.addRecentDatabase(path);
      final recents = await settingsService.getRecentDatabases();

      final stores = await dbService.getStoreNames();

      state = state.copyWith(
        dbPath: path,
        storeNames: stores,
        selectedStore: stores.isNotEmpty ? stores.first : null,
        recentDbs: recents,
        isLoading: false,
      );

      if (state.selectedStore != null) {
        await loadRecords(state.selectedStore!);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadRecords(String storeName, {int page = 1}) async {
    try {
      final isNewStore = state.selectedStore != storeName;
      state = state.copyWith(
        isLoading: true,
        error: null,
        selectedStore: storeName,
        columnFilters: isNewStore ? [] : state.columnFilters,
        sortColumn: isNewStore ? null : state.sortColumn,
        sortAscending: isNewStore ? true : state.sortAscending,
      );
      final repo = _getRepo();

      final totalRecords = await repo.countRecords(
        storeName, 
        query: state.searchQuery,
        columnFilters: state.columnFilters,
      );
      
      final offset = (page - 1) * 200;
      final records = await repo.getAllRecords(
        storeName, 
        offset: offset, 
        limit: 200, 
        query: state.searchQuery,
        columnFilters: state.columnFilters,
        sortColumn: state.sortColumn,
        sortAscending: state.sortAscending,
      );

      state = state.copyWith(
        records: records,
        currentPage: page,
        totalRecords: totalRecords,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load records: $e',
        isLoading: false,
      );
    }
  }

  Future<void> setSearchQuery(String query) async {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    if (state.selectedStore != null) {
      await loadRecords(state.selectedStore!, page: 1);
    }
  }

  Future<void> setSortColumn(String column) async {
    if (state.sortColumn == column) {
      // Toggle ascending/descending
      state = state.copyWith(sortAscending: !state.sortAscending);
    } else {
      state = state.copyWith(sortColumn: column, sortAscending: true);
    }
    if (state.selectedStore != null) {
      await loadRecords(state.selectedStore!, page: 1);
    }
  }

  Future<void> setColumnFilter(ColumnFilter filter) async {
    final newFilters = List<ColumnFilter>.from(state.columnFilters);
    final existingIndex = newFilters.indexWhere((f) => f.column == filter.column);
    if (existingIndex >= 0) {
      newFilters[existingIndex] = filter;
    } else {
      newFilters.add(filter);
    }
    state = state.copyWith(columnFilters: newFilters);
    if (state.selectedStore != null) {
      await loadRecords(state.selectedStore!, page: 1);
    }
  }

  Future<void> removeColumnFilter(String column) async {
    final newFilters = state.columnFilters.where((f) => f.column != column).toList();
    if (newFilters.length == state.columnFilters.length) return;
    state = state.copyWith(columnFilters: newFilters);
    if (state.selectedStore != null) {
      await loadRecords(state.selectedStore!, page: 1);
    }
  }

  Future<void> clearColumnFilters() async {
    if (state.columnFilters.isEmpty) return;
    state = state.copyWith(columnFilters: []);
    if (state.selectedStore != null) {
      await loadRecords(state.selectedStore!, page: 1);
    }
  }

  Future<void> recoverStore(String storeName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dbService = ref.read(databaseServiceProvider);
      final rawData = await dbService.recoverStoreData(storeName);

      final recoveredRecords = rawData
          .map((data) => _RecoveredRecord(data['key'], data['value']))
          .toList();

      state = state.copyWith(records: recoveredRecords, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error recovering store: $e',
      );
    }
  }

  Future<void> addRecord(Map<String, dynamic> data) async {
    if (state.selectedStore == null) return;
    try {
      final repo = _getRepo();
      await repo.addRecord(state.selectedStore!, data);
      await loadRecords(state.selectedStore!);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateRecord(dynamic key, Map<String, dynamic> data) async {
    if (state.selectedStore == null) return;
    try {
      final repo = _getRepo();
      await repo.updateRecord(state.selectedStore!, key, data);
      await loadRecords(state.selectedStore!);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteRecord(dynamic key) async {
    if (state.selectedStore == null) return;
    try {
      final repo = _getRepo();
      await repo.deleteRecord(state.selectedStore!, key);
      await loadRecords(state.selectedStore!);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> refreshStores() async {
    if (state.dbPath == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dbService = ref.read(databaseServiceProvider);
      final stores = await dbService.getStoreNames();

      // Keep selected store if it still exists
      String? newSelectedStore = state.selectedStore;
      if (!stores.contains(newSelectedStore)) {
        newSelectedStore = stores.isNotEmpty ? stores.first : null;
      }

      state = state.copyWith(
        storeNames: stores,
        selectedStore: newSelectedStore,
        isLoading: false,
      );

      if (newSelectedStore != null) {
        await loadRecords(newSelectedStore);
      } else {
        state = state.copyWith(records: []);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> importFromJsonData(List<Map<String, dynamic>> data) async {
    if (state.selectedStore == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _getRepo();

      for (var item in data) {
        if (item.containsKey('_key')) {
          await repo.updateRecord(
            state.selectedStore!,
            item['_key'],
            item['value'] as Map<String, dynamic>,
          );
        } else {
          await repo.addRecord(
            state.selectedStore!,
            item['value'] as Map<String, dynamic>,
          );
        }
      }
      await loadRecords(state.selectedStore!);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> exportStores(List<String> storesToExport, String format) async {
    try {
      final selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select folder to save exports',
      );

      if (selectedDirectory == null) return; // User canceled

      final repo = _getRepo();
      state = state.copyWith(isLoading: true, error: null);

      for (var storeName in storesToExport) {
        final records = await repo.getAllRecordsUnpaginated(storeName);

        final filePath = p.join(
          selectedDirectory,
          '$storeName.${format.toLowerCase()}',
        );
        final file = File(filePath);

        if (format.toLowerCase() == 'json') {
          final jsonData = records
              .map((r) => {'key': r.key, 'value': r.value})
              .toList();
          await file.writeAsString(jsonEncode(jsonData));
        } else if (format.toLowerCase() == 'csv') {
          if (records.isEmpty) continue;

          final Set<String> headers = {'key'};
          for (var r in records) {
            if (r.value is Map) {
              headers.addAll((r.value as Map).keys.map((e) => e.toString()));
            }
          }
          final headerList = headers.toList();

          final List<List<dynamic>> rows = [headerList];

          for (var r in records) {
            final row = <dynamic>[r.key];
            final val = r.value;
            for (var i = 1; i < headerList.length; i++) {
              if (val is Map && val.containsKey(headerList[i])) {
                row.add(val[headerList[i]]);
              } else {
                row.add('');
              }
            }
            rows.add(row);
          }

          final csvData = csv.encode(rows);
          await file.writeAsString(csvData);
        }
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Export failed: $e');
    }
  }

  Future<void> processImport(List<ImportTaskModel> tasks) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final repo = _getRepo();
      bool importedAny = false;

      for (var task in tasks) {
        final entity = File(task.filePath);
        if (!await entity.exists()) continue;

        final ext = p.extension(entity.path).toLowerCase();
        final storeName = task.storeName;

        final content = await entity.readAsString();
        final recordsToAdd = <Map<String, dynamic>>[];

        if (ext == '.json') {
          try {
            final decoded = jsonDecode(content);
            if (decoded is List) {
              for (var item in decoded) {
                if (item is Map) {
                  if (item.containsKey('key') && item.containsKey('value')) {
                    final parsedKey = item['key'];
                    final parsedValue = item['value'];
                    if (parsedValue is Map<String, dynamic>) {
                      recordsToAdd.add({
                        '__key': parsedKey,
                        'value': parsedValue,
                      });
                    } else {
                      recordsToAdd.add({
                        '__key': parsedKey,
                        'value': {'value': parsedValue},
                      });
                    }
                  } else {
                    recordsToAdd.add({
                      '__key': null,
                      'value': item.cast<String, dynamic>(),
                    });
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Failed to parse JSON for $storeName: $e');
          }
        } else if (ext == '.csv') {
          try {
            final rows = csv.decode(content);
            if (rows.length > 1) {
              final headers = rows[0].map((e) => e.toString()).toList();
              for (var i = 1; i < rows.length; i++) {
                final row = rows[i];
                final map = <String, dynamic>{};
                dynamic parsedKey;
                for (var j = 0; j < headers.length; j++) {
                  if (j < row.length) {
                    if (headers[j] == 'key') {
                      parsedKey = row[j];
                    } else {
                      map[headers[j]] = row[j];
                    }
                  }
                }
                // Try parsing int keys
                if (parsedKey is String && int.tryParse(parsedKey) != null) {
                  parsedKey = int.parse(parsedKey);
                }
                recordsToAdd.add({'__key': parsedKey, 'value': map});
              }
            }
          } catch (e) {
            debugPrint('Failed to parse CSV for $storeName: $e');
          }
        }

        if (recordsToAdd.isNotEmpty) {
          await repo.executeImportTask(storeName, recordsToAdd, task.action);
          importedAny = true;
        }
      }

      if (importedAny) {
        final newStores = await ref
            .read(databaseServiceProvider)
            .getStoreNames();
        state = state.copyWith(storeNames: newStores);
        if (state.selectedStore != null) {
          await loadRecords(state.selectedStore!, page: state.currentPage);
        }
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Import failed: $e');
    }
  }

  Future<void> createNewDatabase(String folderPath, String dbName) async {
    String finalName = dbName.trim();
    if (!finalName.endsWith('.db')) {
      finalName += '.db';
    }
    final fullPath = p.join(folderPath, finalName);
    await openDatabase(fullPath);
  }

  Future<void> deleteStore(String storeName) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final repo = _getRepo();
      await repo.deleteStore(storeName);

      final newStores = await ref.read(databaseServiceProvider).getStoreNames();
      String? nextStore;
      if (state.selectedStore == storeName) {
        nextStore = newStores.isNotEmpty ? newStores.first : null;
      } else {
        nextStore = state.selectedStore;
      }

      state = state.copyWith(storeNames: newStores, selectedStore: nextStore);
      if (nextStore != null) {
        await loadRecords(nextStore, page: 1);
      } else {
        state = state.copyWith(records: [], totalRecords: 0, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to delete store: $e',
        isLoading: false,
      );
    }
  }

  Future<void> clearStore(String storeName) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final repo = _getRepo();
      await repo.clearStore(storeName);
      if (state.selectedStore == storeName) {
        await loadRecords(storeName, page: 1);
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to clear store: $e',
        isLoading: false,
      );
    }
  }

  Future<void> backupDatabase() async {
    if (state.dbPath == null) return;
    try {
      state = state.copyWith(isLoading: true, error: null);

      final dbFile = File(state.dbPath!);
      if (!await dbFile.exists()) throw Exception('Database file not found');

      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      final dbName = p.basenameWithoutExtension(state.dbPath!);
      final dir = p.dirname(state.dbPath!);
      final backupFileName = '${dbName}_$timestamp.zip';
      final backupPath = p.join(dir, backupFileName);

      final zipEncoder = ZipFileEncoder();
      zipEncoder.create(backupPath);
      zipEncoder.addFile(dbFile);
      zipEncoder.close();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(error: 'Backup error: $e', isLoading: false);
    }
  }
}

class _RecoveredRecord implements RecordSnapshot<dynamic, dynamic> {
  @override
  final dynamic key;
  @override
  final dynamic value;

  _RecoveredRecord(this.key, this.value);

  @override
  RecordRef<dynamic, dynamic> get ref => throw UnimplementedError();

  @override
  RecordSnapshot<RK, RV> cast<RK, RV>() => throw UnimplementedError();

  @override
  dynamic operator [](String field) {
    if (value is Map) {
      return (value as Map)[field];
    }
    return null;
  }
}

class ImportTaskModel {
  String storeName;
  final String filePath;
  ImportAction action;

  ImportTaskModel({
    required this.storeName,
    required this.filePath,
    this.action = ImportAction.append,
  });
}
