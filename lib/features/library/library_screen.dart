import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/album.dart';
import '../../core/models/artist.dart';
import '../../core/models/track.dart';
import '../../core/theme/app_theme.dart';
import 'state/library_providers.dart';
import 'widgets/az_fast_scroller.dart';
import 'widgets/track_list_tile.dart';
import '../settings/settings_screen.dart';
import '../player/widgets/queue_screen.dart';

/// Fixed row height for track rows. The A-Z fast scroller needs to jump
/// the ScrollController to a known pixel offset for a given track index,
/// which is only an O(1) multiplication when every row is the same
/// height — a variable-height list would require either a slow up-front
/// measurement pass or an approximation that drifts on long libraries.
const double _trackRowExtent = 66.0;

class LibraryScreen extends ConsumerStatefulWidget {
  final void Function(Track track, List<Track> queue, int startIndex)? onTrackSelected;

  const LibraryScreen({super.key, this.onTrackSelected});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _songsScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _songsScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        title: const Text('Library', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: AccentScope.of(context).primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.5),
          tabs: const [
            Tab(text: 'Songs'),
            Tab(text: 'Albums'),
            Tab(text: 'Artists'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music),
            tooltip: 'Up Next',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QueueScreen()),
            ),
          ),
          PopupMenuButton<LibrarySortOrder>(
            icon: const Icon(Icons.sort),
            onSelected: (order) => ref.read(librarySortOrderProvider.notifier).state = order,
            itemBuilder: (context) => const [
              PopupMenuItem(value: LibrarySortOrder.titleAsc, child: Text('Title')),
              PopupMenuItem(value: LibrarySortOrder.artistAsc, child: Text('Artist')),
              PopupMenuItem(value: LibrarySortOrder.dateAddedDesc, child: Text('Recently added')),
              PopupMenuItem(value: LibrarySortOrder.playCountDesc, child: Text('Most played')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SongsTab(
            scrollController: _songsScrollController,
            searchController: _searchController,
            onTrackSelected: widget.onTrackSelected,
          ),
          const _AlbumsTab(),
          const _ArtistsTab(),
        ],
      ),
    );
  }
}

class _SongsTab extends ConsumerWidget {
  final ScrollController scrollController;
  final TextEditingController searchController;
  final void Function(Track track, List<Track> queue, int startIndex)? onTrackSelected;

  const _SongsTab({
    required this.scrollController,
    required this.searchController,
    required this.onTrackSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(trackListProvider);
    final azIndex = ref.watch(azIndexProvider);
    final sortOrder = ref.watch(librarySortOrderProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            controller: searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search songs, artists, albums',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
              filled: true,
              fillColor: AppColors.surfaceDark,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => ref.read(libraryQueryProvider.notifier).state = value,
          ),
        ),
        Expanded(
          child: tracksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('Could not load library: $err', style: const TextStyle(color: Colors.white54)),
            ),
            data: (tracks) {
              if (tracks.isEmpty) {
                return _EmptyLibraryState(hasQuery: ref.watch(libraryQueryProvider).isNotEmpty);
              }
              return Stack(
                children: [
                  ListView.builder(
                    controller: scrollController,
                    itemExtent: _trackRowExtent,
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return TrackListTile(
                        track: track,
                        onTap: () => onTrackSelected?.call(track, tracks, index),
                        onFavoriteToggle: () => _toggleFavorite(ref, track),
                        onMoreTap: () => _showTrackActions(context, ref, track),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: AzFastScroller(
                      index: azIndex,
                      scrollController: scrollController,
                      visible: sortOrder == LibrarySortOrder.titleAsc ||
                          sortOrder == LibrarySortOrder.artistAsc,
                      estimateOffsetForIndex: (i) => i * _trackRowExtent,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _toggleFavorite(WidgetRef ref, Track track) async {
    final isar = await ref.read(isarProvider.future);
    await isar.writeTxn(() async {
      track.isFavorite = !track.isFavorite;
      await isar.tracks.put(track);
    });
  }

  void _showTrackActions(BuildContext context, WidgetRef ref, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevatedDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusLg)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add, color: Colors.white),
              title: const Text('Add to playlist', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white),
              title: const Text('Track details', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('Edit tags', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumListProvider);
    return albumsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('$err', style: const TextStyle(color: Colors.white54))),
      data: (albums) {
        if (albums.isEmpty) return const _EmptyLibraryState(hasQuery: false);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 18,
            crossAxisSpacing: 16,
            childAspectRatio: 0.78,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) => _AlbumGridTile(album: albums[index]),
        );
      },
    );
  }
}

class _AlbumGridTile extends StatelessWidget {
  final Album album;
  const _AlbumGridTile({required this.album});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              gradient: const LinearGradient(
                colors: [AppColors.accentDefault, AppColors.accentSecondaryDefault],
              ),
            ),
            child: const Icon(Icons.album, color: Colors.white70, size: 36),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          album.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
        Text(
          album.primaryArtistName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
      ],
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistListProvider);
    return artistsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('$err', style: const TextStyle(color: Colors.white54))),
      data: (artists) {
        if (artists.isEmpty) return const _EmptyLibraryState(hasQuery: false);
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: artists.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withOpacity(0.06)),
          itemBuilder: (context, index) => _ArtistListTile(artist: artists[index]),
        );
      },
    );
  }
}

class _ArtistListTile extends StatelessWidget {
  final Artist artist;
  const _ArtistListTile({required this.artist});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.white.withOpacity(0.08),
        child: const Icon(Icons.person, color: Colors.white70),
      ),
      title: Text(artist.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${artist.trackCount} songs • ${artist.albumCount} albums',
        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12.5),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyLibraryState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.library_music_outlined,
              size: 48,
              color: Colors.white.withOpacity(0.25),
            ),
            const SizedBox(height: 14),
            Text(
              hasQuery ? 'No matches for that search' : 'No music found yet',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15),
              textAlign: TextAlign.center,
            ),
            if (!hasQuery) ...[
              const SizedBox(height: 6),
              Text(
                'Run a library scan from Settings to index your local files.',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
