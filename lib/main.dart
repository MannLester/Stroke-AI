// MSRF Mobile Benchmark App
// Medical Signal Recognition Framework - Mobile Performance Testing

import 'package:flutter/material.dart';
import 'screens/benchmark_screen.dart';

void main() {
  runApp(const MSRFApp());
}

class MSRFApp extends StatelessWidget {
  const MSRFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MSRF Benchmark',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const BenchmarkScreen(),
    );
  }
}