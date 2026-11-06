import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/main_shell_screen.dart';
import 'presentation/theme/amoled_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: NocturneApp(),
    ),
  );
}

/// Nocturne main application widget.
class NocturneApp extends StatelessWidget {
  const NocturneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nocturne',
      debugShowCheckedModeBanner: false,
      theme: AmoledTheme.themeData,
      home: const MainShellScreen(),
    );
  }
}
