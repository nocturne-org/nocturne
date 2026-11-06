import 'package:flutter/material.dart';
import '../theme/amoled_colors.dart';

/// Basis-Screen fuer den Bedtime Player mit reinem AMOLED-Container (#000000).
class BedtimeScreen extends StatelessWidget {
  const BedtimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AmoledColors.pureBlack,
      body: SafeArea(
        child: SizedBox.expand(
          child: Center(
            child: Text(
              'Nocturne Bedtime Audio',
              style: TextStyle(
                color: AmoledColors.textSecondary,
                fontSize: 16.0,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
