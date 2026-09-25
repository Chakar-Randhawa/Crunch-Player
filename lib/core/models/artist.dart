import 'package:isar/isar.dart';

part 'artist.g.dart';

@collection
class Artist {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.hash, unique: true, replace: true)
  late String nameKey; // lowercased, trimmed — de-dup key

  @Index(type: IndexType.value, caseSensitive: false)
  late String name;

  int trackCount = 0;

  int albumCount = 0;
}
