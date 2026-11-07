import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/datasources/database/app_database.dart';
import 'package:nocturne/data/datasources/youtube_search_service.dart';
import 'package:nocturne/presentation/providers/database_provider.dart';
import 'package:nocturne/presentation/screens/youtube_search_screen.dart';
import 'package:nocturne/presentation/widgets/playlist_picker_sheet.dart';

class FakeYouTubeSearchService extends YouTubeSearchService {
  final List<WebStreamSearchResult> resultsToReturn;
  String? lastQuery;

  FakeYouTubeSearchService({this.resultsToReturn = const []});

  @override
  Future<List<WebStreamSearchResult>> search(String query) async {
    lastQuery = query;
    return resultsToReturn;
  }
}

void main() {
  group('YouTubeSearchScreen & Stream Favorites Widget Tests (TICK-V2-06)', () {
    late AppDatabase db;
    late FakeYouTubeSearchService fakeService;

    const testResult = WebStreamSearchResult(
      videoId: 'testVid1234',
      title: 'Nocturne Bedtime Piano Stream',
      channel: 'Ambient Dreams',
      duration: Duration(minutes: 42, seconds: 15),
      thumbnailUrl: 'https://img.youtube.com/vi/testVid1234/hqdefault.jpg',
      url: 'https://www.youtube.com/watch?v=testVid1234',
    );

    setUp(() {
      db = AppDatabase.memory();
      fakeService = FakeYouTubeSearchService(resultsToReturn: [testResult]);
    });

    tearDown(() async {
      await db.close();
    });

    Widget createScreen({FakeYouTubeSearchService? service}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: YouTubeSearchScreen(
            searchService: service ?? fakeService,
          ),
        ),
      );
    }

    testWidgets('Renders search input and initial exploratory state',
        (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      expect(find.text('Web-Streams & YouTube'), findsOneWidget);
      expect(find.byKey(const Key('youtube_search_input')), findsOneWidget);
      expect(find.byKey(const Key('youtube_search_submit_button')),
          findsOneWidget);
      expect(find.byKey(const Key('youtube_search_initial_state')),
          findsOneWidget);
      expect(find.text('Web-Streams & YouTube durchsuchen'), findsOneWidget);
    });

    testWidgets('Submitting search displays results and card metadata',
        (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('youtube_search_input')),
        'Piano Sleep Music',
      );
      await tester.tap(find.byKey(const Key('youtube_search_submit_button')));
      await tester.pumpAndSettle();

      expect(fakeService.lastQuery, 'Piano Sleep Music');
      expect(
        find.byKey(const Key('youtube_result_card_testVid1234')),
        findsOneWidget,
      );
      expect(find.text('Nocturne Bedtime Piano Stream'), findsOneWidget);
      expect(find.text('Ambient Dreams'), findsOneWidget);
      expect(find.text('42:15'), findsOneWidget);
    });

    testWidgets('FavoriteHeartButton toggles favorite status directly in SQLite',
        (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Trigger search to populate result card
      await tester.enterText(
        find.byKey(const Key('youtube_search_input')),
        'Piano',
      );
      await tester.tap(find.byKey(const Key('youtube_search_submit_button')));
      await tester.pumpAndSettle();

      final heartFinder =
          find.byKey(const Key('favorite_heart_testVid1234'));
      expect(heartFinder, findsOneWidget);

      // Verify not favorite initially
      expect(await db.mediaDao.isFavorite('testVid1234'), false);

      // Tap heart to add to favorites
      await tester.tap(heartFinder, warnIfMissed: true);
      await tester.pumpAndSettle();

      // Verify favorite in SQLite
      expect(await db.mediaDao.isFavorite('testVid1234'), true);

      // Tap again to remove from favorites
      await tester.tap(heartFinder);
      await tester.pumpAndSettle();

      expect(await db.mediaDao.isFavorite('testVid1234'), false);
    });

    testWidgets('Tapping playlist button opens PlaylistPickerSheet',
        (tester) async {
      // Seed a test playlist in SQLite
      await db.mediaDao.createPlaylist('Nacht-Entspannung');

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('youtube_search_input')),
        'Sleep',
      );
      await tester.tap(find.byKey(const Key('youtube_search_submit_button')));
      await tester.pumpAndSettle();

      final playlistBtn =
          find.byKey(const Key('add_to_playlist_testVid1234'));
      expect(playlistBtn, findsOneWidget);

      await tester.tap(playlistBtn);
      await tester.pumpAndSettle();

      // Verify bottom sheet appears
      expect(find.byType(PlaylistPickerSheet), findsOneWidget);
      expect(find.text('Zu Playlist hinzufuegen'), findsOneWidget);
      expect(find.text('Nacht-Entspannung'), findsOneWidget);
      expect(find.byKey(const Key('create_new_playlist_button')),
          findsOneWidget);
    });

    testWidgets('Touch target dimensions meet or exceed 48x48 dp minimum',
        (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Submit search button touch target
      final submitSize = tester.getSize(
        find.byKey(const Key('youtube_search_submit_button')),
      );
      expect(submitSize.width, greaterThanOrEqualTo(48.0));
      expect(submitSize.height, greaterThanOrEqualTo(48.0));

      // Trigger search
      await tester.enterText(
        find.byKey(const Key('youtube_search_input')),
        'Test',
      );
      await tester.tap(find.byKey(const Key('youtube_search_submit_button')));
      await tester.pumpAndSettle();

      // Heart button touch target
      final heartSize = tester.getSize(
        find.byKey(const Key('favorite_heart_testVid1234')),
      );
      expect(heartSize.width, greaterThanOrEqualTo(48.0));
      expect(heartSize.height, greaterThanOrEqualTo(48.0));

      // Playlist button touch target
      final playlistBtnSize = tester.getSize(
        find.byKey(const Key('add_to_playlist_testVid1234')),
      );
      expect(playlistBtnSize.width, greaterThanOrEqualTo(48.0));
      expect(playlistBtnSize.height, greaterThanOrEqualTo(48.0));
    });
  });
}
