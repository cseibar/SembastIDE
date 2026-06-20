import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sembast/sembast.dart';
import '../data/generic_repository.dart';
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

  HomeState({
    this.dbPath,
    this.storeNames = const [],
    this.selectedStore,
    this.records = const [],
    this.recentDbs = const [],
    this.isLoading = false,
    this.error,
  });

  HomeState copyWith({
    String? dbPath,
    List<String>? storeNames,
    String? selectedStore,
    List<RecordSnapshot<dynamic, dynamic>>? records,
    List<String>? recentDbs,
    bool? isLoading,
    String? error,
  }) {
    return HomeState(
      dbPath: dbPath ?? this.dbPath,
      storeNames: storeNames ?? this.storeNames,
      selectedStore: selectedStore ?? this.selectedStore,
      records: records ?? this.records,
      recentDbs: recentDbs ?? this.recentDbs,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Can be null
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

  Future<void> loadRecords(String storeName) async {
    state = state.copyWith(isLoading: true, selectedStore: storeName, error: null);
    try {
      final repo = _getRepo();
      
      final records = await repo.getAllRecords(storeName);
      state = state.copyWith(records: records, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
          await repo.updateRecord(state.selectedStore!, item['_key'], item['value'] as Map<String, dynamic>);
        } else {
          await repo.addRecord(state.selectedStore!, item['value'] as Map<String, dynamic>);
        }
      }
      await loadRecords(state.selectedStore!);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

