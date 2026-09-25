import 'package:isar/isar.dart';

part 'folder.g.dart';

@collection
class Folder {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.hash, unique: true, replace: true)
  late String path;

  late String displayName;

  /// Id of the parent Folder row, -1 for a scan root.
  int parentFolderId = -1;

  int trackCount = 0;

  /// Whether the user has explicitly excluded this folder (and its
  /// subtree) from future scans — checked by the scanner before it
  /// recurses into a directory.
  @Index()
  bool isExcluded = false;
}
