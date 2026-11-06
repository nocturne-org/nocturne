import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';
import 'package:nocturne/main.dart';
import 'package:nocturne/presentation/providers/audio_providers.dart';
import 'package:nocturne/presentation/screens/bedtime_screen.dart';
import 'package:nocturne/presentation/screens/main_shell_screen.dart';
import 'package:nocturne/presentation/widgets/expandable_player_sheet.dart';
import 'package:nocturne/presentation/widgets/mini_player_bar.dart';

class MockAudioPlayerRepository implements AudioPlayerRepository {
  AudioPlaybackStatus currentStatus = AudioPlaybackStatus.idle;
  Duration currentPosition = const Duration(minutes: 5);
  final StreamController<AudioPlaybackStatus> _statusCtrl =
      StreamController<AudioPlaybackStatus>.broadcast();
  final StreamController<Duration> _posCtrl =
      StreamController<Duration>.broadcast();

  @override
  Stream<AudioPlaybackStatus> get playbackStatusStream async* {
    yield currentStatus;
    yield* _statusCtrl.stream;
  }

  @override
  Stream<Duration> get positionStream async* {
    yield currentPosition;
    yield* _posCtrl.stream;
  }

  @override
  Stream<Duration?> get durationStream =>
      Stream.value(const Duration(minutes: 60));

  @override
  Stream<double> get volumeStream => Stream.value(1.0);

  @override
  Future<void> setSource(AudioSourceRef source,
      {Duration? initialPosition}) async {}

  @override
  Future<void> play() async {
    currentStatus = AudioPlaybackStatus.playing;
    _statusCtrl.add(currentStatus);
  }

  @override
  Future<void> pause() async {
    currentStatus = AudioPlaybackStatus.paused;
    _statusCtrl.add(currentStatus);
  }

  @override
  Future<void> stop() async {
    currentStatus = AudioPlaybackStatus.idle;
    _statusCtrl.add(currentStatus);
  }

  @override
  Future<void> seek(Duration position) async {
    currentPosition = position;
    _posCtrl.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    await _statusCtrl.close();
    await _posCtrl.close();
  }
}

void main() {
  testWidgets('NocturneApp starts with MainShellScreen and persistent MiniPlayerBar',
      (WidgetTester tester) async {
    final mockAudio = MockAudioPlayerRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerRepositoryProvider.overrideWithValue(mockAudio),
        ],
        child: const NocturneApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify MainShellScreen and MiniPlayerBar are present
    expect(find.byType(MainShellScreen), findsOneWidget);
    expect(find.byType(MiniPlayerBar), findsOneWidget);
    expect(find.text('Nocturne Bedtime Audio'), findsOneWidget);

    // Verify navigation tabs
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Tap MiniPlayerBar to expand BedtimePlayer
    await tester.tap(find.byKey(const Key('mini_player_tap_area')));
    await tester.pumpAndSettle();

    // BedtimeScreen is now visible in the expandable sheet
    expect(find.byType(ExpandablePlayerSheet), findsOneWidget);
    expect(find.byType(BedtimeScreen), findsOneWidget);

    // Tap collapse button to close
    await tester.tap(find.byKey(const Key('player_sheet_collapse_button')));
    await tester.pumpAndSettle();

    expect(find.byType(ExpandablePlayerSheet), findsNothing);

    await mockAudio.dispose();
  });
}
