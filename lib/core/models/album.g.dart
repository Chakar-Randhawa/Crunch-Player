// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAlbumCollection on Isar {
  IsarCollection<Album> get albums => this.collection();
}

const AlbumSchema = CollectionSchema(
  name: r'Album',
  id: -1355968412107120937,
  properties: {
    r'albumKey': PropertySchema(
      id: 0,
      name: r'albumKey',
      type: IsarType.string,
    ),
    r'artworkSourceTrackPath': PropertySchema(
      id: 1,
      name: r'artworkSourceTrackPath',
      type: IsarType.string,
    ),
    r'name': PropertySchema(
      id: 2,
      name: r'name',
      type: IsarType.string,
    ),
    r'paletteColorPrimary': PropertySchema(
      id: 3,
      name: r'paletteColorPrimary',
      type: IsarType.long,
    ),
    r'paletteColorSecondary': PropertySchema(
      id: 4,
      name: r'paletteColorSecondary',
      type: IsarType.long,
    ),
    r'primaryArtistName': PropertySchema(
      id: 5,
      name: r'primaryArtistName',
      type: IsarType.string,
    ),
    r'totalDurationMs': PropertySchema(
      id: 6,
      name: r'totalDurationMs',
      type: IsarType.long,
    ),
    r'trackCount': PropertySchema(
      id: 7,
      name: r'trackCount',
      type: IsarType.long,
    ),
    r'year': PropertySchema(
      id: 8,
      name: r'year',
      type: IsarType.long,
    )
  },
  estimateSize: _albumEstimateSize,
  serialize: _albumSerialize,
  deserialize: _albumDeserialize,
  deserializeProp: _albumDeserializeProp,
  idName: r'id',
  indexes: {
    r'albumKey': IndexSchema(
      id: 8512154875591279857,
      name: r'albumKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'albumKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'name': IndexSchema(
      id: 879695947855722453,
      name: r'name',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'name',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _albumGetId,
  getLinks: _albumGetLinks,
  attach: _albumAttach,
  version: '3.1.0+1',
);

int _albumEstimateSize(
  Album object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.albumKey.length * 3;
  {
    final value = object.artworkSourceTrackPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.primaryArtistName.length * 3;
  return bytesCount;
}

void _albumSerialize(
  Album object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.albumKey);
  writer.writeString(offsets[1], object.artworkSourceTrackPath);
  writer.writeString(offsets[2], object.name);
  writer.writeLong(offsets[3], object.paletteColorPrimary);
  writer.writeLong(offsets[4], object.paletteColorSecondary);
  writer.writeString(offsets[5], object.primaryArtistName);
  writer.writeLong(offsets[6], object.totalDurationMs);
  writer.writeLong(offsets[7], object.trackCount);
  writer.writeLong(offsets[8], object.year);
}

Album _albumDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Album();
  object.albumKey = reader.readString(offsets[0]);
  object.artworkSourceTrackPath = reader.readStringOrNull(offsets[1]);
  object.id = id;
  object.name = reader.readString(offsets[2]);
  object.paletteColorPrimary = reader.readLongOrNull(offsets[3]);
  object.paletteColorSecondary = reader.readLongOrNull(offsets[4]);
  object.primaryArtistName = reader.readString(offsets[5]);
  object.totalDurationMs = reader.readLong(offsets[6]);
  object.trackCount = reader.readLong(offsets[7]);
  object.year = reader.readLong(offsets[8]);
  return object;
}

P _albumDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _albumGetId(Album object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _albumGetLinks(Album object) {
  return [];
}

void _albumAttach(IsarCollection<dynamic> col, Id id, Album object) {
  object.id = id;
}

extension AlbumByIndex on IsarCollection<Album> {
  Future<Album?> getByAlbumKey(String albumKey) {
    return getByIndex(r'albumKey', [albumKey]);
  }

  Album? getByAlbumKeySync(String albumKey) {
    return getByIndexSync(r'albumKey', [albumKey]);
  }

  Future<bool> deleteByAlbumKey(String albumKey) {
    return deleteByIndex(r'albumKey', [albumKey]);
  }

  bool deleteByAlbumKeySync(String albumKey) {
    return deleteByIndexSync(r'albumKey', [albumKey]);
  }

  Future<List<Album?>> getAllByAlbumKey(List<String> albumKeyValues) {
    final values = albumKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'albumKey', values);
  }

  List<Album?> getAllByAlbumKeySync(List<String> albumKeyValues) {
    final values = albumKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'albumKey', values);
  }

  Future<int> deleteAllByAlbumKey(List<String> albumKeyValues) {
    final values = albumKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'albumKey', values);
  }

  int deleteAllByAlbumKeySync(List<String> albumKeyValues) {
    final values = albumKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'albumKey', values);
  }

  Future<Id> putByAlbumKey(Album object) {
    return putByIndex(r'albumKey', object);
  }

  Id putByAlbumKeySync(Album object, {bool saveLinks = true}) {
    return putByIndexSync(r'albumKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByAlbumKey(List<Album> objects) {
    return putAllByIndex(r'albumKey', objects);
  }

  List<Id> putAllByAlbumKeySync(List<Album> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'albumKey', objects, saveLinks: saveLinks);
  }
}

extension AlbumQueryWhereSort on QueryBuilder<Album, Album, QWhere> {
  QueryBuilder<Album, Album, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<Album, Album, QAfterWhere> anyName() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'name'),
      );
    });
  }
}

extension AlbumQueryWhere on QueryBuilder<Album, Album, QWhereClause> {
  QueryBuilder<Album, Album, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Album, Album, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Album, Album, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Album, Album, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterWhereClause> albumKeyEqualTo(
      String albumKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'albumKey',
        value: [albumKey],
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterWhereClause> albumKeyNotEqualTo(
      String albumKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'albumKey',
              lower: [],
              upper: [albumKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'albumKey',
              lower: [albumKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'albumKey',
              lower: [albumKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'albumKey',
              lower: [],
              upper: [albumKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<Album, Album, QAfterWhereClause> nameEqualTo(String name) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'name',
        value: [name],
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterWhereClause> nameNotEqualTo(String name) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [],
              upper: [name],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [name],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [name],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [],
              upper: [name],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<Album, Album, QAfterWhereClause> nameGreaterThan(
    String name, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'name',
        lower: [name],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterWhereClause> nameLessThan(
    String name, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'name',
        lower: [],
        upper: [name],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterWhereClause> nameBetween(
    String lowerName,
    String upperName, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'name',
        lower: [lowerName],
        includeLower: includeLower,
        upper: [upperName],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterWhereClause> nameStartsWith(
      String NamePrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'name',
        lower: [NamePrefix],
        upper: ['$NamePrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterWhereClause> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'name',
        value: [''],
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterWhereClause> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'name',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'name',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'name',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'name',
              upper: [''],
            ));
      }
    });
  }
}

extension AlbumQueryFilter on QueryBuilder<Album, Album, QFilterCondition> {
  QueryBuilder<Album, Album, QAfterFilterCondition> albumKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'albumKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> albumKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'albumKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> albumKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'albumKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> albumKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'albumKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> albumKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'albumKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> albumKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'albumKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> albumKeyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'albumKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> albumKeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'albumKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> albumKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'albumKey',
        value: '',
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> albumKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'albumKey',
        value: '',
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      artworkSourceTrackPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'artworkSourceTrackPath',
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      artworkSourceTrackPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'artworkSourceTrackPath',
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      artworkSourceTrackPathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'artworkSourceTrackPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      artworkSourceTrackPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'artworkSourceTrackPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      artworkSourceTrackPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'artworkSourceTrackPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      artworkSourceTrackPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'artworkSourceTrackPath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      artworkSourceTrackPathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'artworkSourceTrackPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      artworkSourceTrackPathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'artworkSourceTrackPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      artworkSourceTrackPathContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'artworkSourceTrackPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      artworkSourceTrackPathMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'artworkSourceTrackPath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      artworkSourceTrackPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'artworkSourceTrackPath',
        value: '',
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      artworkSourceTrackPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'artworkSourceTrackPath',
        value: '',
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> nameContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> nameMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      paletteColorPrimaryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'paletteColorPrimary',
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      paletteColorPrimaryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'paletteColorPrimary',
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> paletteColorPrimaryEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'paletteColorPrimary',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      paletteColorPrimaryGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'paletteColorPrimary',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> paletteColorPrimaryLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'paletteColorPrimary',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> paletteColorPrimaryBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'paletteColorPrimary',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      paletteColorSecondaryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'paletteColorSecondary',
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      paletteColorSecondaryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'paletteColorSecondary',
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      paletteColorSecondaryEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'paletteColorSecondary',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      paletteColorSecondaryGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'paletteColorSecondary',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      paletteColorSecondaryLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'paletteColorSecondary',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      paletteColorSecondaryBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'paletteColorSecondary',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> primaryArtistNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'primaryArtistName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      primaryArtistNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'primaryArtistName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> primaryArtistNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'primaryArtistName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> primaryArtistNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'primaryArtistName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> primaryArtistNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'primaryArtistName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> primaryArtistNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'primaryArtistName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> primaryArtistNameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'primaryArtistName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> primaryArtistNameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'primaryArtistName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> primaryArtistNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'primaryArtistName',
        value: '',
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition>
      primaryArtistNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'primaryArtistName',
        value: '',
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> totalDurationMsEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalDurationMs',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> totalDurationMsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalDurationMs',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> totalDurationMsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalDurationMs',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> totalDurationMsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalDurationMs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> trackCountEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'trackCount',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> trackCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'trackCount',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> trackCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'trackCount',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> trackCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'trackCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> yearEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'year',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> yearGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'year',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> yearLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'year',
        value: value,
      ));
    });
  }

  QueryBuilder<Album, Album, QAfterFilterCondition> yearBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'year',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension AlbumQueryObject on QueryBuilder<Album, Album, QFilterCondition> {}

extension AlbumQueryLinks on QueryBuilder<Album, Album, QFilterCondition> {}

extension AlbumQuerySortBy on QueryBuilder<Album, Album, QSortBy> {
  QueryBuilder<Album, Album, QAfterSortBy> sortByAlbumKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'albumKey', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByAlbumKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'albumKey', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByArtworkSourceTrackPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artworkSourceTrackPath', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByArtworkSourceTrackPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artworkSourceTrackPath', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByPaletteColorPrimary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paletteColorPrimary', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByPaletteColorPrimaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paletteColorPrimary', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByPaletteColorSecondary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paletteColorSecondary', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByPaletteColorSecondaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paletteColorSecondary', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByPrimaryArtistName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'primaryArtistName', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByPrimaryArtistNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'primaryArtistName', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByTotalDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalDurationMs', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByTotalDurationMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalDurationMs', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByTrackCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackCount', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByTrackCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackCount', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> sortByYearDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.desc);
    });
  }
}

extension AlbumQuerySortThenBy on QueryBuilder<Album, Album, QSortThenBy> {
  QueryBuilder<Album, Album, QAfterSortBy> thenByAlbumKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'albumKey', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByAlbumKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'albumKey', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByArtworkSourceTrackPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artworkSourceTrackPath', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByArtworkSourceTrackPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artworkSourceTrackPath', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByPaletteColorPrimary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paletteColorPrimary', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByPaletteColorPrimaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paletteColorPrimary', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByPaletteColorSecondary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paletteColorSecondary', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByPaletteColorSecondaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paletteColorSecondary', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByPrimaryArtistName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'primaryArtistName', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByPrimaryArtistNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'primaryArtistName', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByTotalDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalDurationMs', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByTotalDurationMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalDurationMs', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByTrackCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackCount', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByTrackCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackCount', Sort.desc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.asc);
    });
  }

  QueryBuilder<Album, Album, QAfterSortBy> thenByYearDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.desc);
    });
  }
}

extension AlbumQueryWhereDistinct on QueryBuilder<Album, Album, QDistinct> {
  QueryBuilder<Album, Album, QDistinct> distinctByAlbumKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'albumKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Album, Album, QDistinct> distinctByArtworkSourceTrackPath(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'artworkSourceTrackPath',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Album, Album, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Album, Album, QDistinct> distinctByPaletteColorPrimary() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'paletteColorPrimary');
    });
  }

  QueryBuilder<Album, Album, QDistinct> distinctByPaletteColorSecondary() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'paletteColorSecondary');
    });
  }

  QueryBuilder<Album, Album, QDistinct> distinctByPrimaryArtistName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'primaryArtistName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Album, Album, QDistinct> distinctByTotalDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalDurationMs');
    });
  }

  QueryBuilder<Album, Album, QDistinct> distinctByTrackCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'trackCount');
    });
  }

  QueryBuilder<Album, Album, QDistinct> distinctByYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'year');
    });
  }
}

extension AlbumQueryProperty on QueryBuilder<Album, Album, QQueryProperty> {
  QueryBuilder<Album, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Album, String, QQueryOperations> albumKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'albumKey');
    });
  }

  QueryBuilder<Album, String?, QQueryOperations>
      artworkSourceTrackPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'artworkSourceTrackPath');
    });
  }

  QueryBuilder<Album, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<Album, int?, QQueryOperations> paletteColorPrimaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'paletteColorPrimary');
    });
  }

  QueryBuilder<Album, int?, QQueryOperations> paletteColorSecondaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'paletteColorSecondary');
    });
  }

  QueryBuilder<Album, String, QQueryOperations> primaryArtistNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'primaryArtistName');
    });
  }

  QueryBuilder<Album, int, QQueryOperations> totalDurationMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalDurationMs');
    });
  }

  QueryBuilder<Album, int, QQueryOperations> trackCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'trackCount');
    });
  }

  QueryBuilder<Album, int, QQueryOperations> yearProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'year');
    });
  }
}
