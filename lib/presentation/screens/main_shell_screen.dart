import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bedtime_audio_provider.dart';
import '../providers/sensor_providers.dart';
import '../theme/amoled_colors.dart';
import '../theme/amoled_typography.dart';
import '../widgets/expandable_player_sheet.dart';
import '../widgets/mini_player_bar.dart';
import '../widgets/unified_queue_view.dart';
import 'library_browser_screen.dart';

/// Main application shell providing Spotify-like navigation between Library,
/// Queue, Playlists, and Settings, with a persistent bottom MiniPlayerBar
/// and expandable swipe-down bedtime player.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(bedtimeAudioProvider);
    final playerNotifier = ref.read(bedtimeAudioProvider.notifier);

    return Scaffold(
      backgroundColor: AmoledColors.pureBlack,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentTabIndex,
          children: const [
            LibraryBrowserScreen(),
            UnifiedQueueView(),
            _PlaylistsTab(),
            _SettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Persistent Mini Player Bar
          MiniPlayerBar(
            key: const Key('main_shell_mini_player'),
            title: playerState.title,
            author: playerState.author,
            isPlaying: playerState.isPlaying,
            position: playerState.position,
            totalDuration: playerState.totalDuration,
            onTap: () => ExpandablePlayerSheet.show(context),
            onTogglePlayPause: () => playerNotifier.togglePlayPause(),
          ),

          // Bottom Navigation Bar
          NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: AmoledColors.pureBlack,
              indicatorColor: AmoledColors.surfaceElevated,
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    color: AmoledColors.midnightBlue,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  );
                }
                return const TextStyle(
                  color: AmoledColors.textTertiary,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(
                    color: AmoledColors.midnightBlue,
                    size: 24.0,
                  );
                }
                return const IconThemeData(
                  color: AmoledColors.textTertiary,
                  size: 24.0,
                );
              }),
            ),
            child: NavigationBar(
              key: const Key('main_shell_nav_bar'),
              selectedIndex: _currentTabIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentTabIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  key: Key('nav_destination_library'),
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded),
                  label: 'Library',
                ),
                NavigationDestination(
                  key: Key('nav_destination_queue'),
                  icon: Icon(Icons.queue_music_outlined),
                  selectedIcon: Icon(Icons.queue_music_rounded),
                  label: 'Queue',
                ),
                NavigationDestination(
                  key: Key('nav_destination_playlists'),
                  icon: Icon(Icons.playlist_play_outlined),
                  selectedIcon: Icon(Icons.playlist_play_rounded),
                  label: 'Playlists',
                ),
                NavigationDestination(
                  key: Key('nav_destination_settings'),
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune_rounded),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple Playlists view tab.
class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AmoledColors.pureBlack,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Playlists & Collections',
                  style: AmoledTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AmoledColors.textPrimary,
                  ),
                ),
                IconButton(
                  key: const Key('create_new_playlist_button'),
                  icon: const Icon(
                    Icons.add_rounded,
                    color: AmoledColors.midnightBlue,
                    size: 28,
                  ),
                  tooltip: 'Create Playlist',
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AmoledColors.divider, height: 1),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    key: const Key('playlist_tile_favorites'),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AmoledColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: AmoledColors.violet,
                      ),
                    ),
                    title: const Text(
                      'Favorites',
                      style: TextStyle(
                        color: AmoledColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Saved tracks & streams',
                      style: TextStyle(color: AmoledColors.textSecondary),
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings & diagnostics tab.
class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorProfile = ref.watch(sensorProfileProvider);
    final sensorNotifier = ref.read(sensorProfileProvider.notifier);

    return Material(
      color: AmoledColors.pureBlack,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Settings',
            style: AmoledTypography.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: AmoledColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AmoledColors.divider, height: 1),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(
              Icons.vibration_rounded,
              color: AmoledColors.midnightBlue,
            ),
            title: const Text(
              'Shake Sensor Profile',
              style: TextStyle(
                color: AmoledColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              sensorProfile.displayName,
              style: const TextStyle(color: AmoledColors.textSecondary),
            ),
            trailing: const Icon(
              Icons.swap_horiz_rounded,
              color: AmoledColors.textSecondary,
            ),
            onTap: () => sensorNotifier.toggleProfile(),
          ),
          const Divider(color: AmoledColors.divider, height: 1),
          const ListTile(
            leading: Icon(
              Icons.dark_mode_rounded,
              color: AmoledColors.indigo,
            ),
            title: Text(
              'Theme',
              style: TextStyle(
                color: AmoledColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'AMOLED Pure Black (0% Pixel Light)',
              style: TextStyle(color: AmoledColors.textSecondary),
            ),
          ),
          const Divider(color: AmoledColors.divider, height: 1),
          const ListTile(
            leading: Icon(
              Icons.info_outline_rounded,
              color: AmoledColors.textSecondary,
            ),
            title: Text(
              'Nocturne v1.0.1',
              style: TextStyle(
                color: AmoledColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Bedtime Audio Engine',
              style: TextStyle(color: AmoledColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
