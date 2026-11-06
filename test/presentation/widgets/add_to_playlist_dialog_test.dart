import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/datasources/database/app_database.dart';
import 'package:nocturne/presentation/theme/amoled_theme.dart';
import 'package:nocturne/presentation/widgets/add_to_playlist_dialog.dart';

void main() {
  group('AddToPlaylistDialog Tests (TICK-V2-10)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.memory();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Renders existing playlists and creates new playlist',
        (tester) async {
      await db.mediaDao.createPlaylist('Night Vibes');
      await tester.pump(const Duration(milliseconds: 10));
      await db.mediaDao.createPlaylist('Rain Sounds');

      await tester.pumpWidget(
        MaterialApp(
          theme: AmoledTheme.themeData,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () => AddToPlaylistDialog.show(
                  context: context,
                  mediaItemId: 'track-42',
                  itemTitle: 'Soft Thunder',
                  mediaDao: db.mediaDao,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Add to Playlist'), findsOneWidget);
      expect(find.text('Rain Sounds'), findsOneWidget);
      expect(find.text('Night Vibes'), findsOneWidget);

      // Add to existing playlist
      await tester.tap(find.text('Rain Sounds'));
      await tester.pumpAndSettle();

      final recent = await db.mediaDao.getPlaylistsSortedByRecent();
      final items = await db.mediaDao.getPlaylistItems(recent.first.id);
      expect(items, contains('track-42'));
    });
  });
}
