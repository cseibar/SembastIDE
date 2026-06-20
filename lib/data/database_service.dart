import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:sembast/sembast_io.dart';

class DatabaseService {
  Database? _db;
  String? _currentPath;

  Database? get db => _db;
  String? get currentPath => _currentPath;

  Future<void> openDatabase(String path) async {
    if (_db != null) {
      await closeDatabase();
    }
    
    DatabaseFactory dbFactory = databaseFactoryIo;
    _db = await dbFactory.openDatabase(path);
    _currentPath = path;
  }

  Future<void> closeDatabase() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _currentPath = null;
    }
  }

  /// Get a list of all stores in the database by parsing the raw file.
  /// Sembast doesn't provide a built-in way to list all stores.
  Future<List<String>> getStoreNames() async {
    if (_currentPath == null) return [];
    
    final file = File(_currentPath!);
    if (!await file.exists()) return [];

    final Set<String> stores = {};
    
    try {
      final lines = await file.readAsLines();
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        
        try {
          final decoded = jsonDecode(line) as Map<String, dynamic>;
          // Sembast records have a 'store' field for custom stores
          if (decoded.containsKey('store')) {
            stores.add(decoded['store'] as String);
          } else {
            // Main store
            stores.add('_main');
          }
        } catch (e) {
          // Ignore invalid JSON lines
        }
      }
    } catch (e) {
      debugPrint('Error reading Sembast file for store names: $e');
    }
    
    return stores.toList()..sort();
  }

  Future<List<String>> getRawLinesForStore(String storeName) async {
    if (_currentPath == null) return [];
    final storeLines = <String>[];
    try {
      final file = File(_currentPath!);
      final lines = await file.readAsLines();
      final target = '"store":"$storeName"';
      for (var line in lines) {
        if (line.contains(target)) {
          storeLines.add(line);
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
    return storeLines;
  }

  /// Recovers records for a store by parsing the raw JSON file in a background isolate.
  Future<List<Map<String, dynamic>>> recoverStoreData(String storeName) async {
    if (_currentPath == null) return [];
    return await compute(_parseStoreDataInIsolate, {'path': _currentPath!, 'store': storeName});
  }
}

/// Runs in a background isolate so it doesn't freeze the UI.
List<Map<String, dynamic>> _parseStoreDataInIsolate(Map<String, String> args) {
  final path = args['path']!;
  final storeName = args['store']!;
  
  try {
    final file = File(path);
    final lines = file.readAsLinesSync();
    
    final recoveredMap = <dynamic, Map<String, dynamic>>{};
    
    for (var line in lines) {
      try {
        final map = jsonDecode(line) as Map<String, dynamic>;
        if (map['store'] == storeName) {
          final key = map['key'];
          if (map['deleted'] == true) {
            recoveredMap.remove(key);
          } else {
            recoveredMap[key] = {
              'key': key,
              'value': map['value'],
            };
          }
        }
      } catch (e) {
        // Ignore invalid lines
      }
    }
    
    return recoveredMap.values.toList();
  } catch (e) {
    return [];
  }
}
