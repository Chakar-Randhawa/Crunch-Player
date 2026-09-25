import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../../core/database/isar_service.dart';
import '../../../core/models/track.dart';
import '../../../core/models/album.dart';
import '../../../core/models/artist.dart';

enum LibrarySortOrder { titleAsc, artistAsc, dateAddedDesc, playCountDesc }

final isarProvider = FutureProvider<Isar>((ref) => IsarService.instance.open());

final librarySortOrderProvider = StateProvider<LibrarySortOrder>((ref) => LibrarySortOrder.titleAsc);

final libraryQueryProvider = StateProvider<String>((ref) => '');

/// Live-updating track list, already sorted and filtered. Rebuilding this
/// from an Isar `.watch()` stream — rather than reading once — is what
/// makes the Songs tab reflect an in-progress scan without the user
/// pulling to refresh.
final trackListProvider = StreamProvider<List<Track>>((ref) async* {
  final isar = await ref.watch(isarProvider.future);
  final sortOrder = ref.watch(librarySortOrderProvider);
  final query = ref.watch(libraryQueryProvider).trim().toLowerCase();

  Query<Track> buildQuery() {
    QueryBuilder<Track, Track, QAfterFilterCondition> filtered;
    if (query.isEmpty) {
      filtered = isar.tracks.filter().titleIsNotEmpty();
    } else {
      filtered = isar.tracks
          .filter()
          .titleContains(query, caseSensitive: false)
          .or()
          .artistNameContains(query, caseSensitive: false)
          .or()
          .albumNameContains(query, caseSensitive: false);
    }

    switch (sortOrder) {
      case LibrarySortOrder.titleAsc:
        return filtered.sortByTitle().build();
      case LibrarySortOrder.artistAsc:
        return filtered.sortByArtistName().thenByTitle().build();
      case LibrarySortOrder.dateAddedDesc:
        return filtered.sortByDateAddedDesc().build();
      case LibrarySortOrder.playCountDesc:
        return filtered.sortByPlayCountDesc().build();
    }
  }

  yield* buildQuery().watch(fireImmediately: true);
});

final albumListProvider = StreamProvider<List<Album>>((ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.albums.where().sortByName().watch(fireImmediately: true);
});

final artistListProvider = StreamProvider<List<Artist>>((ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.artists.where().sortByName().watch(fireImmediately: true);
});

/// Maps each letter A-Z (plus '#' for non-alphabetic leading characters)
/// to the index of the first track in the *currently displayed* sorted
/// list whose sort key starts with that letter. Only meaningful when
/// sortOrder is titleAsc or artistAsc — the fast scroller hides itself
/// otherwise, since "jump to letter" isn't a coherent action on a list
/// sorted by date or play count.
class AzIndex {
  final Map<String, int> letterToFirstIndex;
  const AzIndex(this.letterToFirstIndex);

  static const List<String> alphabet = [
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];
}

final azIndexProvider = Provider<AzIndex>((ref) {
  final tracksAsync = ref.watch(trackListProvider);
  final sortOrder = ref.watch(librarySortOrderProvider);
  final tracks = tracksAsync.value ?? const <Track>[];

  final map = <String, int>{};
  if (sortOrder == LibrarySortOrder.titleAsc || sortOrder == LibrarySortOrder.artistAsc) {
    for (int i = 0; i < tracks.length; i++) {
      final key = sortOrder == LibrarySortOrder.titleAsc ? tracks[i].title : tracks[i].artistName;
      final letter = _leadingLetter(key);
      map.putIfAbsent(letter, () => i);
    }
  }
  return AzIndex(map);
});

String _leadingLetter(String value) {
  final trimmed = value.trim().toUpperCase();
  if (trimmed.isEmpty) return '#';
  final first = trimmed[0];
  return RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
}
