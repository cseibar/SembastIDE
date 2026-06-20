import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

import 'package:sembast/sembast_io.dart';

class ExportService {
  static Future<void> exportToJson(String storeName, List<RecordSnapshot> records) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export $storeName to JSON',
      fileName: '$storeName.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return;

    final data = records.map((r) => {'key': r.key, 'value': r.value}).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    await File(path).writeAsString(jsonStr);
  }

  static Future<void> exportToCsv(String storeName, List<RecordSnapshot> records) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export $storeName to CSV',
      fileName: '$storeName.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return;

    if (records.isEmpty) {
      await File(path).writeAsString("");
      return;
    }

    // Extract all unique keys from values to form headers
    final Set<String> headersSet = {'_key'};
    for (var record in records) {
      if (record.value is Map) {
        headersSet.addAll((record.value as Map).keys.cast<String>());
      }
    }
    final headers = headersSet.toList();

    final List<List<dynamic>> rows = [headers];

    for (var record in records) {
      final row = <dynamic>[];
      for (var header in headers) {
        if (header == '_key') {
          row.add(record.key);
        } else {
          if (record.value is Map) {
            row.add((record.value as Map)[header] ?? '');
          } else {
            row.add('');
          }
        }
      }
      rows.add(row);
    }

    final csvStr = csv.encode(rows);
    await File(path).writeAsString(csvStr);
  }

  static Future<void> exportToSembast(String storeName, List<RecordSnapshot> records) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export $storeName to Sembast DB',
      fileName: '${storeName}_export.db',
    );
    if (path == null) return;

    final targetDb = await databaseFactoryIo.openDatabase(path);
    final store = StoreRef(storeName);
    
    await targetDb.transaction((txn) async {
      for (var record in records) {
        await store.record(record.key).put(txn, record.value);
      }
    });

    await targetDb.close();
  }

  static Future<List<Map<String, dynamic>>?> importFromJson() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import JSON',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return null;

    final file = File(result.files.single.path!);
    final str = await file.readAsString();
    final decoded = jsonDecode(str);
    
    if (decoded is List) {
      return decoded.map((e) {
        if (e is Map) {
          // If it matches our export format: {key: ..., value: ...}
          if (e.containsKey('key') && e.containsKey('value')) {
            return {'_key': e['key'], 'value': e['value']};
          }
          // Otherwise, import the whole map as a new record
          return {'value': e};
        }
        return {'value': e};
      }).toList().cast<Map<String, dynamic>>();
    }
    return null;
  }
}
