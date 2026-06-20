import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/database_service.dart';
import '../data/settings_service.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
DatabaseService databaseService(Ref ref) {
  return DatabaseService();
}

@Riverpod(keepAlive: true)
SettingsService settingsService(Ref ref) {
  return SettingsService();
}


