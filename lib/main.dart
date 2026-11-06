import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/bedtime_screen.dart';
import 'presentation/theme/amoled_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: NocturneApp(),
    ),
  );
}

/// Nocturne Hauptanwendung.
class NocturneApp extends StatelessWidget {
  const NocturneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nocturne',
      debugShowCheckedModeBanner: false,
      theme: AmoledTheme.themeData,
      home: const BedtimeScreen(),
    );
  }
}
