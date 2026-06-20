import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:path/path.dart' as p;

class SettingsService {
  Database? _db;
  final StoreRef<String, dynamic> _store = StoreRef<String, dynamic>.main();
  static const String _recentDbsKey = 'recent_dbs';

  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final dbPath = p.join(dir.path, 'sembast_ide_settings.db');
    
    DatabaseFactory dbFactory = databaseFactoryIo;
    _db = await dbFactory.openDatabase(dbPath);
  }

  Future<List<String>> getRecentDatabases() async {
    if (_db == null) return [];
    final record = await _store.record(_recentDbsKey).get(_db!);
    if (record != null && record is List) {
      return record.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<void> addRecentDatabase(String path) async {
    if (_db == null) return;
    
    List<String> recents = await getRecentDatabases();
    
    // Remove if already exists so we can move it to the top
    recents.remove(path);
    
    // Insert at the beginning
    recents.insert(0, path);
    
    // Keep only last 10
    if (recents.length > 10) {
      recents = recents.sublist(0, 10);
    }
    
    await _store.record(_recentDbsKey).put(_db!, recents);
  }
}
