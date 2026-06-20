import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SembastIDEApp(),
    ),
  );
}

class SembastIDEApp extends StatelessWidget {
  const SembastIDEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sembast IDE',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurpleAccent,
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E2C),
        ),
        scaffoldBackgroundColor: const Color(0xFF151521),
        cardTheme: CardThemeData(
          color: const Color(0xFF252538),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF151521),
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
