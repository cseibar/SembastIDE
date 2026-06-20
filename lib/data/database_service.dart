import 'dart:convert';
import 'dart:io';
import 'package:sembast/sembast.dart';
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
      print('Error reading Sembast file for store names: $e');
    }
    
    return stores.toList()..sort();
  }
}
