import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/presentation/theme/amoled_theme.dart';
import 'package:nocturne/presentation/widgets/mini_player_bar.dart';

void main() {
  group('MiniPlayerBar Widget Tests (TICK-V2-05)', () {
    testWidgets('Renders title, author, progress bar, and play/pause button',
        (tester) async {
      var tapped = false;
      var playPauseToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AmoledTheme.themeData,
          home: Scaffold(
            bottomNavigationBar: MiniPlayerBar(
              title: 'Der Steppenwolf',
              author: 'Hermann Hesse',
              isPlaying: false,
              position: const Duration(minutes: 15),
              totalDuration: const Duration(minutes: 60),
              onTap: () => tapped = true,
              onTogglePlayPause: () => playPauseToggled = true,
            ),
          ),
        ),
      );

      // Verify metadata
      expect(find.text('Der Steppenwolf'), findsOneWidget);
      expect(find.text('Hermann Hesse'), findsOneWidget);

      // Verify play icon
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Verify progress bar
      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('mini_player_progress_bar')),
      );
      expect(progressBar.value, closeTo(0.25, 0.01));

      // Test tap on bar opens full player
      await tester.tap(find.byKey(const Key('mini_player_tap_area')));
      await tester.pump();
      expect(tapped, isTrue);

      // Test play/pause toggle
      await tester.tap(find.byKey(const Key('mini_player_play_pause_button')));
      await tester.pump();
      expect(playPauseToggled, isTrue);
    });

    testWidgets('Renders pause icon when isPlaying is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AmoledTheme.themeData,
          home: Scaffold(
            bottomNavigationBar: MiniPlayerBar(
              title: 'Der Steppenwolf',
              author: 'Hermann Hesse',
              isPlaying: true,
              position: const Duration(minutes: 30),
              totalDuration: const Duration(minutes: 60),
              onTap: () {},
              onTogglePlayPause: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });
  });
}
