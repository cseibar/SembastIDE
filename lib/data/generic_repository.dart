import 'package:sembast/sembast.dart';

class GenericRepository {
  final Database db;

  GenericRepository(this.db);

  StoreRef<dynamic, dynamic> _getStore(String storeName) {
    if (storeName == '_main') {
      return StoreRef.main();
    }
    return StoreRef(storeName);
  }

  Future<List<RecordSnapshot<dynamic, dynamic>>> getAllRecords(String storeName) async {
    print('DEBUG: getAllRecords called for $storeName');
    final store = _getStore(storeName);
    try {
      print('DEBUG: Calling store.find()');
      final records = await store.find(db, finder: Finder(limit: 100)).timeout(const Duration(seconds: 5));
      print('DEBUG: store.find() returned ${records.length} records');
      return records;
    } catch (e) {
      print('DEBUG: store.find() timed out or threw error: $e');
      throw Exception('Sembast find() failed or timed out: $e');
    }
  }

  Future<dynamic> addRecord(String storeName, Map<String, dynamic> data) async {
    final store = _getStore(storeName);
    return await store.add(db, data);
  }

  Future<void> updateRecord(String storeName, dynamic key, Map<String, dynamic> data) async {
    final store = _getStore(storeName);
    await store.record(key).put(db, data);
  }

  Future<void> deleteRecord(String storeName, dynamic key) async {
    final store = _getStore(storeName);
    await store.record(key).delete(db);
  }

  Future<void> deleteStore(String storeName) async {
    final store = _getStore(storeName);
    await store.drop(db);
  }
}
