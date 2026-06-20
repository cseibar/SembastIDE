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

  Future<int> countRecords(String storeName) async {
    final store = _getStore(storeName);
    return await store.count(db);
  }

  Future<List<RecordSnapshot<dynamic, dynamic>>> getAllRecords(String storeName, {int offset = 0, int limit = 200}) async {
    final store = _getStore(storeName);
    return await store.find(db, finder: Finder(offset: offset, limit: limit));
  }

  Future<dynamic> addRecord(String storeName, Map<String, dynamic> data) async {
    final store = _getStore(storeName);
    return await store.add(db, data);
  }

  Future<void> updateRecord(String storeName, dynamic key, Map<String, dynamic> data) async {
    final store = _getStore(storeName);
    await store.record(key).update(db, data);
  }

  Future<void> deleteRecord(String storeName, dynamic key) async {
    final store = _getStore(storeName);
    await store.record(key).delete(db);
  }

  Future<List<RecordSnapshot<dynamic, dynamic>>> getAllRecordsUnpaginated(String storeName) async {
    final store = _getStore(storeName);
    return await store.find(db);
  }

  Future<void> addRecordsBatch(String storeName, List<Map<String, dynamic>> dataList) async {
    final store = _getStore(storeName);
    await db.transaction((txn) async {
      for (final data in dataList) {
        await store.add(txn, data);
      }
    });
  }

  Future<void> deleteStore(String storeName) async {
    final store = _getStore(storeName);
    await store.drop(db);
  }

  Future<void> clearStore(String storeName) async {
    final store = _getStore(storeName);
    await store.delete(db);
  }

  Future<void> executeImportTask(String storeName, List<Map<String, dynamic>> records, ImportAction action) async {
    final store = _getStore(storeName);
    
    if (action == ImportAction.overwrite) {
      await store.delete(db); // Clear first
    }

    await db.transaction((txn) async {
      for (final record in records) {
        final key = record['__key'];
        final value = record['value'];

        if (action == ImportAction.append) {
          // Generate new keys, ignoring original key
          await store.add(txn, value);
        } else if (action == ImportAction.overwrite) {
          // Preserve keys when overwriting (or generate new if no key)
          if (key != null) {
            await store.record(key).put(txn, value);
          } else {
            await store.add(txn, value);
          }
        } else if (action == ImportAction.addNew) {
          // Only add if key doesn't exist. If key is null, it's always new.
          if (key != null) {
            await store.record(key).add(txn, value); // Sembast's .add throws or returns null if it already exists, skipping it.
          } else {
            await store.add(txn, value);
          }
        }
      }
    });
  }
}

enum ImportAction {
  append,
  overwrite,
  addNew,
}
