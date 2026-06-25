// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $VocabularyListsTableTable extends VocabularyListsTable
    with TableInfo<$VocabularyListsTableTable, VocabularyListsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VocabularyListsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _visibilityMeta =
      const VerificationMeta('visibility');
  @override
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
      'visibility', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('private'));
  static const VerificationMeta _wordCountMeta =
      const VerificationMeta('wordCount');
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
      'word_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _shareTokenMeta =
      const VerificationMeta('shareToken');
  @override
  late final GeneratedColumn<String> shareToken = GeneratedColumn<String>(
      'share_token', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isSyncedMeta =
      const VerificationMeta('isSynced');
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
      'is_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ownerId,
        name,
        description,
        visibility,
        wordCount,
        shareToken,
        isSynced,
        isDeleted,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vocabulary_lists';
  @override
  VerificationContext validateIntegrity(
      Insertable<VocabularyListsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('visibility')) {
      context.handle(
          _visibilityMeta,
          visibility.isAcceptableOrUnknown(
              data['visibility']!, _visibilityMeta));
    }
    if (data.containsKey('word_count')) {
      context.handle(_wordCountMeta,
          wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta));
    }
    if (data.containsKey('share_token')) {
      context.handle(
          _shareTokenMeta,
          shareToken.isAcceptableOrUnknown(
              data['share_token']!, _shareTokenMeta));
    }
    if (data.containsKey('is_synced')) {
      context.handle(_isSyncedMeta,
          isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VocabularyListsTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VocabularyListsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      visibility: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}visibility'])!,
      wordCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}word_count'])!,
      shareToken: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}share_token']),
      isSynced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synced'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $VocabularyListsTableTable createAlias(String alias) {
    return $VocabularyListsTableTable(attachedDatabase, alias);
  }
}

class VocabularyListsTableData extends DataClass
    implements Insertable<VocabularyListsTableData> {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String visibility;
  final int wordCount;
  final String? shareToken;
  final bool isSynced;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  const VocabularyListsTableData(
      {required this.id,
      required this.ownerId,
      required this.name,
      this.description,
      required this.visibility,
      required this.wordCount,
      this.shareToken,
      required this.isSynced,
      required this.isDeleted,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['visibility'] = Variable<String>(visibility);
    map['word_count'] = Variable<int>(wordCount);
    if (!nullToAbsent || shareToken != null) {
      map['share_token'] = Variable<String>(shareToken);
    }
    map['is_synced'] = Variable<bool>(isSynced);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  VocabularyListsTableCompanion toCompanion(bool nullToAbsent) {
    return VocabularyListsTableCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      visibility: Value(visibility),
      wordCount: Value(wordCount),
      shareToken: shareToken == null && nullToAbsent
          ? const Value.absent()
          : Value(shareToken),
      isSynced: Value(isSynced),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory VocabularyListsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VocabularyListsTableData(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      visibility: serializer.fromJson<String>(json['visibility']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      shareToken: serializer.fromJson<String?>(json['shareToken']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'visibility': serializer.toJson<String>(visibility),
      'wordCount': serializer.toJson<int>(wordCount),
      'shareToken': serializer.toJson<String?>(shareToken),
      'isSynced': serializer.toJson<bool>(isSynced),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  VocabularyListsTableData copyWith(
          {String? id,
          String? ownerId,
          String? name,
          Value<String?> description = const Value.absent(),
          String? visibility,
          int? wordCount,
          Value<String?> shareToken = const Value.absent(),
          bool? isSynced,
          bool? isDeleted,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      VocabularyListsTableData(
        id: id ?? this.id,
        ownerId: ownerId ?? this.ownerId,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        visibility: visibility ?? this.visibility,
        wordCount: wordCount ?? this.wordCount,
        shareToken: shareToken.present ? shareToken.value : this.shareToken,
        isSynced: isSynced ?? this.isSynced,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  VocabularyListsTableData copyWithCompanion(
      VocabularyListsTableCompanion data) {
    return VocabularyListsTableData(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      visibility:
          data.visibility.present ? data.visibility.value : this.visibility,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      shareToken:
          data.shareToken.present ? data.shareToken.value : this.shareToken,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyListsTableData(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('visibility: $visibility, ')
          ..write('wordCount: $wordCount, ')
          ..write('shareToken: $shareToken, ')
          ..write('isSynced: $isSynced, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ownerId, name, description, visibility,
      wordCount, shareToken, isSynced, isDeleted, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VocabularyListsTableData &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.name == this.name &&
          other.description == this.description &&
          other.visibility == this.visibility &&
          other.wordCount == this.wordCount &&
          other.shareToken == this.shareToken &&
          other.isSynced == this.isSynced &&
          other.isDeleted == this.isDeleted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class VocabularyListsTableCompanion
    extends UpdateCompanion<VocabularyListsTableData> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> visibility;
  final Value<int> wordCount;
  final Value<String?> shareToken;
  final Value<bool> isSynced;
  final Value<bool> isDeleted;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const VocabularyListsTableCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.visibility = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.shareToken = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VocabularyListsTableCompanion.insert({
    required String id,
    required String ownerId,
    required String name,
    this.description = const Value.absent(),
    this.visibility = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.shareToken = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        ownerId = Value(ownerId),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<VocabularyListsTableData> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? visibility,
    Expression<int>? wordCount,
    Expression<String>? shareToken,
    Expression<bool>? isSynced,
    Expression<bool>? isDeleted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (visibility != null) 'visibility': visibility,
      if (wordCount != null) 'word_count': wordCount,
      if (shareToken != null) 'share_token': shareToken,
      if (isSynced != null) 'is_synced': isSynced,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VocabularyListsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? ownerId,
      Value<String>? name,
      Value<String?>? description,
      Value<String>? visibility,
      Value<int>? wordCount,
      Value<String?>? shareToken,
      Value<bool>? isSynced,
      Value<bool>? isDeleted,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return VocabularyListsTableCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      visibility: visibility ?? this.visibility,
      wordCount: wordCount ?? this.wordCount,
      shareToken: shareToken ?? this.shareToken,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (shareToken.present) {
      map['share_token'] = Variable<String>(shareToken.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyListsTableCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('visibility: $visibility, ')
          ..write('wordCount: $wordCount, ')
          ..write('shareToken: $shareToken, ')
          ..write('isSynced: $isSynced, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConceptsTableTable extends ConceptsTable
    with TableInfo<$ConceptsTableTable, ConceptsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConceptsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
      'list_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES vocabulary_lists (id)'));
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _exampleFrMeta =
      const VerificationMeta('exampleFr');
  @override
  late final GeneratedColumn<String> exampleFr = GeneratedColumn<String>(
      'example_fr', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _exampleKoMeta =
      const VerificationMeta('exampleKo');
  @override
  late final GeneratedColumn<String> exampleKo = GeneratedColumn<String>(
      'example_ko', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isSyncedMeta =
      const VerificationMeta('isSynced');
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
      'is_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        listId,
        category,
        notes,
        imageUrl,
        exampleFr,
        exampleKo,
        isSynced,
        isDeleted,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'concepts';
  @override
  VerificationContext validateIntegrity(Insertable<ConceptsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('list_id')) {
      context.handle(_listIdMeta,
          listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta));
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('example_fr')) {
      context.handle(_exampleFrMeta,
          exampleFr.isAcceptableOrUnknown(data['example_fr']!, _exampleFrMeta));
    }
    if (data.containsKey('example_ko')) {
      context.handle(_exampleKoMeta,
          exampleKo.isAcceptableOrUnknown(data['example_ko']!, _exampleKoMeta));
    }
    if (data.containsKey('is_synced')) {
      context.handle(_isSyncedMeta,
          isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConceptsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConceptsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      listId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}list_id'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      exampleFr: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}example_fr']),
      exampleKo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}example_ko']),
      isSynced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synced'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ConceptsTableTable createAlias(String alias) {
    return $ConceptsTableTable(attachedDatabase, alias);
  }
}

class ConceptsTableData extends DataClass
    implements Insertable<ConceptsTableData> {
  final String id;
  final String listId;
  final String? category;
  final String? notes;
  final String? imageUrl;
  final String? exampleFr;
  final String? exampleKo;
  final bool isSynced;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ConceptsTableData(
      {required this.id,
      required this.listId,
      this.category,
      this.notes,
      this.imageUrl,
      this.exampleFr,
      this.exampleKo,
      required this.isSynced,
      required this.isDeleted,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['list_id'] = Variable<String>(listId);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || exampleFr != null) {
      map['example_fr'] = Variable<String>(exampleFr);
    }
    if (!nullToAbsent || exampleKo != null) {
      map['example_ko'] = Variable<String>(exampleKo);
    }
    map['is_synced'] = Variable<bool>(isSynced);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConceptsTableCompanion toCompanion(bool nullToAbsent) {
    return ConceptsTableCompanion(
      id: Value(id),
      listId: Value(listId),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      exampleFr: exampleFr == null && nullToAbsent
          ? const Value.absent()
          : Value(exampleFr),
      exampleKo: exampleKo == null && nullToAbsent
          ? const Value.absent()
          : Value(exampleKo),
      isSynced: Value(isSynced),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConceptsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConceptsTableData(
      id: serializer.fromJson<String>(json['id']),
      listId: serializer.fromJson<String>(json['listId']),
      category: serializer.fromJson<String?>(json['category']),
      notes: serializer.fromJson<String?>(json['notes']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      exampleFr: serializer.fromJson<String?>(json['exampleFr']),
      exampleKo: serializer.fromJson<String?>(json['exampleKo']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'listId': serializer.toJson<String>(listId),
      'category': serializer.toJson<String?>(category),
      'notes': serializer.toJson<String?>(notes),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'exampleFr': serializer.toJson<String?>(exampleFr),
      'exampleKo': serializer.toJson<String?>(exampleKo),
      'isSynced': serializer.toJson<bool>(isSynced),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ConceptsTableData copyWith(
          {String? id,
          String? listId,
          Value<String?> category = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          Value<String?> imageUrl = const Value.absent(),
          Value<String?> exampleFr = const Value.absent(),
          Value<String?> exampleKo = const Value.absent(),
          bool? isSynced,
          bool? isDeleted,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      ConceptsTableData(
        id: id ?? this.id,
        listId: listId ?? this.listId,
        category: category.present ? category.value : this.category,
        notes: notes.present ? notes.value : this.notes,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        exampleFr: exampleFr.present ? exampleFr.value : this.exampleFr,
        exampleKo: exampleKo.present ? exampleKo.value : this.exampleKo,
        isSynced: isSynced ?? this.isSynced,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ConceptsTableData copyWithCompanion(ConceptsTableCompanion data) {
    return ConceptsTableData(
      id: data.id.present ? data.id.value : this.id,
      listId: data.listId.present ? data.listId.value : this.listId,
      category: data.category.present ? data.category.value : this.category,
      notes: data.notes.present ? data.notes.value : this.notes,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      exampleFr: data.exampleFr.present ? data.exampleFr.value : this.exampleFr,
      exampleKo: data.exampleKo.present ? data.exampleKo.value : this.exampleKo,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConceptsTableData(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('category: $category, ')
          ..write('notes: $notes, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('exampleFr: $exampleFr, ')
          ..write('exampleKo: $exampleKo, ')
          ..write('isSynced: $isSynced, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, listId, category, notes, imageUrl,
      exampleFr, exampleKo, isSynced, isDeleted, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConceptsTableData &&
          other.id == this.id &&
          other.listId == this.listId &&
          other.category == this.category &&
          other.notes == this.notes &&
          other.imageUrl == this.imageUrl &&
          other.exampleFr == this.exampleFr &&
          other.exampleKo == this.exampleKo &&
          other.isSynced == this.isSynced &&
          other.isDeleted == this.isDeleted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConceptsTableCompanion extends UpdateCompanion<ConceptsTableData> {
  final Value<String> id;
  final Value<String> listId;
  final Value<String?> category;
  final Value<String?> notes;
  final Value<String?> imageUrl;
  final Value<String?> exampleFr;
  final Value<String?> exampleKo;
  final Value<bool> isSynced;
  final Value<bool> isDeleted;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConceptsTableCompanion({
    this.id = const Value.absent(),
    this.listId = const Value.absent(),
    this.category = const Value.absent(),
    this.notes = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.exampleFr = const Value.absent(),
    this.exampleKo = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConceptsTableCompanion.insert({
    required String id,
    required String listId,
    this.category = const Value.absent(),
    this.notes = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.exampleFr = const Value.absent(),
    this.exampleKo = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        listId = Value(listId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ConceptsTableData> custom({
    Expression<String>? id,
    Expression<String>? listId,
    Expression<String>? category,
    Expression<String>? notes,
    Expression<String>? imageUrl,
    Expression<String>? exampleFr,
    Expression<String>? exampleKo,
    Expression<bool>? isSynced,
    Expression<bool>? isDeleted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (listId != null) 'list_id': listId,
      if (category != null) 'category': category,
      if (notes != null) 'notes': notes,
      if (imageUrl != null) 'image_url': imageUrl,
      if (exampleFr != null) 'example_fr': exampleFr,
      if (exampleKo != null) 'example_ko': exampleKo,
      if (isSynced != null) 'is_synced': isSynced,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConceptsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? listId,
      Value<String?>? category,
      Value<String?>? notes,
      Value<String?>? imageUrl,
      Value<String?>? exampleFr,
      Value<String?>? exampleKo,
      Value<bool>? isSynced,
      Value<bool>? isDeleted,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ConceptsTableCompanion(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      exampleFr: exampleFr ?? this.exampleFr,
      exampleKo: exampleKo ?? this.exampleKo,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (exampleFr.present) {
      map['example_fr'] = Variable<String>(exampleFr.value);
    }
    if (exampleKo.present) {
      map['example_ko'] = Variable<String>(exampleKo.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConceptsTableCompanion(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('category: $category, ')
          ..write('notes: $notes, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('exampleFr: $exampleFr, ')
          ..write('exampleKo: $exampleKo, ')
          ..write('isSynced: $isSynced, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WordVariantsTableTable extends WordVariantsTable
    with TableInfo<$WordVariantsTableTable, WordVariantsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordVariantsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conceptIdMeta =
      const VerificationMeta('conceptId');
  @override
  late final GeneratedColumn<String> conceptId = GeneratedColumn<String>(
      'concept_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES concepts (id)'));
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
      'word', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _langCodeMeta =
      const VerificationMeta('langCode');
  @override
  late final GeneratedColumn<String> langCode = GeneratedColumn<String>(
      'lang_code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _registerTagMeta =
      const VerificationMeta('registerTag');
  @override
  late final GeneratedColumn<String> registerTag = GeneratedColumn<String>(
      'register_tag', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('neutral'));
  static const VerificationMeta _contextTagsMeta =
      const VerificationMeta('contextTags');
  @override
  late final GeneratedColumn<String> contextTags = GeneratedColumn<String>(
      'context_tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _isPrimaryMeta =
      const VerificationMeta('isPrimary');
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
      'is_primary', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_primary" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _audioHashMeta =
      const VerificationMeta('audioHash');
  @override
  late final GeneratedColumn<String> audioHash = GeneratedColumn<String>(
      'audio_hash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _audioVoiceIdMeta =
      const VerificationMeta('audioVoiceId');
  @override
  late final GeneratedColumn<String> audioVoiceId = GeneratedColumn<String>(
      'audio_voice_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isSyncedMeta =
      const VerificationMeta('isSynced');
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
      'is_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        conceptId,
        word,
        langCode,
        registerTag,
        contextTags,
        isPrimary,
        audioHash,
        audioVoiceId,
        position,
        isSynced,
        isDeleted,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_variants';
  @override
  VerificationContext validateIntegrity(
      Insertable<WordVariantsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('concept_id')) {
      context.handle(_conceptIdMeta,
          conceptId.isAcceptableOrUnknown(data['concept_id']!, _conceptIdMeta));
    } else if (isInserting) {
      context.missing(_conceptIdMeta);
    }
    if (data.containsKey('word')) {
      context.handle(
          _wordMeta, word.isAcceptableOrUnknown(data['word']!, _wordMeta));
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('lang_code')) {
      context.handle(_langCodeMeta,
          langCode.isAcceptableOrUnknown(data['lang_code']!, _langCodeMeta));
    } else if (isInserting) {
      context.missing(_langCodeMeta);
    }
    if (data.containsKey('register_tag')) {
      context.handle(
          _registerTagMeta,
          registerTag.isAcceptableOrUnknown(
              data['register_tag']!, _registerTagMeta));
    }
    if (data.containsKey('context_tags')) {
      context.handle(
          _contextTagsMeta,
          contextTags.isAcceptableOrUnknown(
              data['context_tags']!, _contextTagsMeta));
    }
    if (data.containsKey('is_primary')) {
      context.handle(_isPrimaryMeta,
          isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta));
    }
    if (data.containsKey('audio_hash')) {
      context.handle(_audioHashMeta,
          audioHash.isAcceptableOrUnknown(data['audio_hash']!, _audioHashMeta));
    }
    if (data.containsKey('audio_voice_id')) {
      context.handle(
          _audioVoiceIdMeta,
          audioVoiceId.isAcceptableOrUnknown(
              data['audio_voice_id']!, _audioVoiceIdMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('is_synced')) {
      context.handle(_isSyncedMeta,
          isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WordVariantsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordVariantsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      conceptId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}concept_id'])!,
      word: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}word'])!,
      langCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lang_code'])!,
      registerTag: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}register_tag'])!,
      contextTags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}context_tags'])!,
      isPrimary: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_primary'])!,
      audioHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_hash']),
      audioVoiceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_voice_id']),
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      isSynced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synced'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $WordVariantsTableTable createAlias(String alias) {
    return $WordVariantsTableTable(attachedDatabase, alias);
  }
}

class WordVariantsTableData extends DataClass
    implements Insertable<WordVariantsTableData> {
  final String id;
  final String conceptId;
  final String word;
  final String langCode;
  final String registerTag;
  final String contextTags;
  final bool isPrimary;
  final String? audioHash;
  final String? audioVoiceId;
  final int position;
  final bool isSynced;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  const WordVariantsTableData(
      {required this.id,
      required this.conceptId,
      required this.word,
      required this.langCode,
      required this.registerTag,
      required this.contextTags,
      required this.isPrimary,
      this.audioHash,
      this.audioVoiceId,
      required this.position,
      required this.isSynced,
      required this.isDeleted,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['concept_id'] = Variable<String>(conceptId);
    map['word'] = Variable<String>(word);
    map['lang_code'] = Variable<String>(langCode);
    map['register_tag'] = Variable<String>(registerTag);
    map['context_tags'] = Variable<String>(contextTags);
    map['is_primary'] = Variable<bool>(isPrimary);
    if (!nullToAbsent || audioHash != null) {
      map['audio_hash'] = Variable<String>(audioHash);
    }
    if (!nullToAbsent || audioVoiceId != null) {
      map['audio_voice_id'] = Variable<String>(audioVoiceId);
    }
    map['position'] = Variable<int>(position);
    map['is_synced'] = Variable<bool>(isSynced);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WordVariantsTableCompanion toCompanion(bool nullToAbsent) {
    return WordVariantsTableCompanion(
      id: Value(id),
      conceptId: Value(conceptId),
      word: Value(word),
      langCode: Value(langCode),
      registerTag: Value(registerTag),
      contextTags: Value(contextTags),
      isPrimary: Value(isPrimary),
      audioHash: audioHash == null && nullToAbsent
          ? const Value.absent()
          : Value(audioHash),
      audioVoiceId: audioVoiceId == null && nullToAbsent
          ? const Value.absent()
          : Value(audioVoiceId),
      position: Value(position),
      isSynced: Value(isSynced),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WordVariantsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordVariantsTableData(
      id: serializer.fromJson<String>(json['id']),
      conceptId: serializer.fromJson<String>(json['conceptId']),
      word: serializer.fromJson<String>(json['word']),
      langCode: serializer.fromJson<String>(json['langCode']),
      registerTag: serializer.fromJson<String>(json['registerTag']),
      contextTags: serializer.fromJson<String>(json['contextTags']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      audioHash: serializer.fromJson<String?>(json['audioHash']),
      audioVoiceId: serializer.fromJson<String?>(json['audioVoiceId']),
      position: serializer.fromJson<int>(json['position']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conceptId': serializer.toJson<String>(conceptId),
      'word': serializer.toJson<String>(word),
      'langCode': serializer.toJson<String>(langCode),
      'registerTag': serializer.toJson<String>(registerTag),
      'contextTags': serializer.toJson<String>(contextTags),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'audioHash': serializer.toJson<String?>(audioHash),
      'audioVoiceId': serializer.toJson<String?>(audioVoiceId),
      'position': serializer.toJson<int>(position),
      'isSynced': serializer.toJson<bool>(isSynced),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WordVariantsTableData copyWith(
          {String? id,
          String? conceptId,
          String? word,
          String? langCode,
          String? registerTag,
          String? contextTags,
          bool? isPrimary,
          Value<String?> audioHash = const Value.absent(),
          Value<String?> audioVoiceId = const Value.absent(),
          int? position,
          bool? isSynced,
          bool? isDeleted,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      WordVariantsTableData(
        id: id ?? this.id,
        conceptId: conceptId ?? this.conceptId,
        word: word ?? this.word,
        langCode: langCode ?? this.langCode,
        registerTag: registerTag ?? this.registerTag,
        contextTags: contextTags ?? this.contextTags,
        isPrimary: isPrimary ?? this.isPrimary,
        audioHash: audioHash.present ? audioHash.value : this.audioHash,
        audioVoiceId:
            audioVoiceId.present ? audioVoiceId.value : this.audioVoiceId,
        position: position ?? this.position,
        isSynced: isSynced ?? this.isSynced,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  WordVariantsTableData copyWithCompanion(WordVariantsTableCompanion data) {
    return WordVariantsTableData(
      id: data.id.present ? data.id.value : this.id,
      conceptId: data.conceptId.present ? data.conceptId.value : this.conceptId,
      word: data.word.present ? data.word.value : this.word,
      langCode: data.langCode.present ? data.langCode.value : this.langCode,
      registerTag:
          data.registerTag.present ? data.registerTag.value : this.registerTag,
      contextTags:
          data.contextTags.present ? data.contextTags.value : this.contextTags,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      audioHash: data.audioHash.present ? data.audioHash.value : this.audioHash,
      audioVoiceId: data.audioVoiceId.present
          ? data.audioVoiceId.value
          : this.audioVoiceId,
      position: data.position.present ? data.position.value : this.position,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordVariantsTableData(')
          ..write('id: $id, ')
          ..write('conceptId: $conceptId, ')
          ..write('word: $word, ')
          ..write('langCode: $langCode, ')
          ..write('registerTag: $registerTag, ')
          ..write('contextTags: $contextTags, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('audioHash: $audioHash, ')
          ..write('audioVoiceId: $audioVoiceId, ')
          ..write('position: $position, ')
          ..write('isSynced: $isSynced, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      conceptId,
      word,
      langCode,
      registerTag,
      contextTags,
      isPrimary,
      audioHash,
      audioVoiceId,
      position,
      isSynced,
      isDeleted,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordVariantsTableData &&
          other.id == this.id &&
          other.conceptId == this.conceptId &&
          other.word == this.word &&
          other.langCode == this.langCode &&
          other.registerTag == this.registerTag &&
          other.contextTags == this.contextTags &&
          other.isPrimary == this.isPrimary &&
          other.audioHash == this.audioHash &&
          other.audioVoiceId == this.audioVoiceId &&
          other.position == this.position &&
          other.isSynced == this.isSynced &&
          other.isDeleted == this.isDeleted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WordVariantsTableCompanion
    extends UpdateCompanion<WordVariantsTableData> {
  final Value<String> id;
  final Value<String> conceptId;
  final Value<String> word;
  final Value<String> langCode;
  final Value<String> registerTag;
  final Value<String> contextTags;
  final Value<bool> isPrimary;
  final Value<String?> audioHash;
  final Value<String?> audioVoiceId;
  final Value<int> position;
  final Value<bool> isSynced;
  final Value<bool> isDeleted;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WordVariantsTableCompanion({
    this.id = const Value.absent(),
    this.conceptId = const Value.absent(),
    this.word = const Value.absent(),
    this.langCode = const Value.absent(),
    this.registerTag = const Value.absent(),
    this.contextTags = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.audioHash = const Value.absent(),
    this.audioVoiceId = const Value.absent(),
    this.position = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordVariantsTableCompanion.insert({
    required String id,
    required String conceptId,
    required String word,
    required String langCode,
    this.registerTag = const Value.absent(),
    this.contextTags = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.audioHash = const Value.absent(),
    this.audioVoiceId = const Value.absent(),
    this.position = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        conceptId = Value(conceptId),
        word = Value(word),
        langCode = Value(langCode),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<WordVariantsTableData> custom({
    Expression<String>? id,
    Expression<String>? conceptId,
    Expression<String>? word,
    Expression<String>? langCode,
    Expression<String>? registerTag,
    Expression<String>? contextTags,
    Expression<bool>? isPrimary,
    Expression<String>? audioHash,
    Expression<String>? audioVoiceId,
    Expression<int>? position,
    Expression<bool>? isSynced,
    Expression<bool>? isDeleted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conceptId != null) 'concept_id': conceptId,
      if (word != null) 'word': word,
      if (langCode != null) 'lang_code': langCode,
      if (registerTag != null) 'register_tag': registerTag,
      if (contextTags != null) 'context_tags': contextTags,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (audioHash != null) 'audio_hash': audioHash,
      if (audioVoiceId != null) 'audio_voice_id': audioVoiceId,
      if (position != null) 'position': position,
      if (isSynced != null) 'is_synced': isSynced,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordVariantsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? conceptId,
      Value<String>? word,
      Value<String>? langCode,
      Value<String>? registerTag,
      Value<String>? contextTags,
      Value<bool>? isPrimary,
      Value<String?>? audioHash,
      Value<String?>? audioVoiceId,
      Value<int>? position,
      Value<bool>? isSynced,
      Value<bool>? isDeleted,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return WordVariantsTableCompanion(
      id: id ?? this.id,
      conceptId: conceptId ?? this.conceptId,
      word: word ?? this.word,
      langCode: langCode ?? this.langCode,
      registerTag: registerTag ?? this.registerTag,
      contextTags: contextTags ?? this.contextTags,
      isPrimary: isPrimary ?? this.isPrimary,
      audioHash: audioHash ?? this.audioHash,
      audioVoiceId: audioVoiceId ?? this.audioVoiceId,
      position: position ?? this.position,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conceptId.present) {
      map['concept_id'] = Variable<String>(conceptId.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (langCode.present) {
      map['lang_code'] = Variable<String>(langCode.value);
    }
    if (registerTag.present) {
      map['register_tag'] = Variable<String>(registerTag.value);
    }
    if (contextTags.present) {
      map['context_tags'] = Variable<String>(contextTags.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (audioHash.present) {
      map['audio_hash'] = Variable<String>(audioHash.value);
    }
    if (audioVoiceId.present) {
      map['audio_voice_id'] = Variable<String>(audioVoiceId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordVariantsTableCompanion(')
          ..write('id: $id, ')
          ..write('conceptId: $conceptId, ')
          ..write('word: $word, ')
          ..write('langCode: $langCode, ')
          ..write('registerTag: $registerTag, ')
          ..write('contextTags: $contextTags, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('audioHash: $audioHash, ')
          ..write('audioVoiceId: $audioVoiceId, ')
          ..write('position: $position, ')
          ..write('isSynced: $isSynced, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VariantProgressTableTable extends VariantProgressTable
    with TableInfo<$VariantProgressTableTable, VariantProgressTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VariantProgressTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _variantIdMeta =
      const VerificationMeta('variantId');
  @override
  late final GeneratedColumn<String> variantId = GeneratedColumn<String>(
      'variant_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES word_variants (id)'));
  static const VerificationMeta _directionMeta =
      const VerificationMeta('direction');
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
      'direction', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stabilityMeta =
      const VerificationMeta('stability');
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
      'stability', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _difficultyMeta =
      const VerificationMeta('difficulty');
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
      'difficulty', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(5.0));
  static const VerificationMeta _elapsedDaysMeta =
      const VerificationMeta('elapsedDays');
  @override
  late final GeneratedColumn<int> elapsedDays = GeneratedColumn<int>(
      'elapsed_days', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _scheduledDaysMeta =
      const VerificationMeta('scheduledDays');
  @override
  late final GeneratedColumn<int> scheduledDays = GeneratedColumn<int>(
      'scheduled_days', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
      'reps', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
      'lapses', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('newCard'));
  static const VerificationMeta _lastReviewMeta =
      const VerificationMeta('lastReview');
  @override
  late final GeneratedColumn<DateTime> lastReview = GeneratedColumn<DateTime>(
      'last_review', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _nextReviewMeta =
      const VerificationMeta('nextReview');
  @override
  late final GeneratedColumn<DateTime> nextReview = GeneratedColumn<DateTime>(
      'next_review', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _timesShownMeta =
      const VerificationMeta('timesShown');
  @override
  late final GeneratedColumn<int> timesShown = GeneratedColumn<int>(
      'times_shown', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _timesCorrectMeta =
      const VerificationMeta('timesCorrect');
  @override
  late final GeneratedColumn<int> timesCorrect = GeneratedColumn<int>(
      'times_correct', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _masteryLevelMeta =
      const VerificationMeta('masteryLevel');
  @override
  late final GeneratedColumn<double> masteryLevel = GeneratedColumn<double>(
      'mastery_level', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _isSyncedMeta =
      const VerificationMeta('isSynced');
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
      'is_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        variantId,
        direction,
        stability,
        difficulty,
        elapsedDays,
        scheduledDays,
        reps,
        lapses,
        state,
        lastReview,
        nextReview,
        timesShown,
        timesCorrect,
        masteryLevel,
        isSynced,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'variant_progress';
  @override
  VerificationContext validateIntegrity(
      Insertable<VariantProgressTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('variant_id')) {
      context.handle(_variantIdMeta,
          variantId.isAcceptableOrUnknown(data['variant_id']!, _variantIdMeta));
    } else if (isInserting) {
      context.missing(_variantIdMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(_directionMeta,
          direction.isAcceptableOrUnknown(data['direction']!, _directionMeta));
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('stability')) {
      context.handle(_stabilityMeta,
          stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta));
    }
    if (data.containsKey('difficulty')) {
      context.handle(
          _difficultyMeta,
          difficulty.isAcceptableOrUnknown(
              data['difficulty']!, _difficultyMeta));
    }
    if (data.containsKey('elapsed_days')) {
      context.handle(
          _elapsedDaysMeta,
          elapsedDays.isAcceptableOrUnknown(
              data['elapsed_days']!, _elapsedDaysMeta));
    }
    if (data.containsKey('scheduled_days')) {
      context.handle(
          _scheduledDaysMeta,
          scheduledDays.isAcceptableOrUnknown(
              data['scheduled_days']!, _scheduledDaysMeta));
    }
    if (data.containsKey('reps')) {
      context.handle(
          _repsMeta, reps.isAcceptableOrUnknown(data['reps']!, _repsMeta));
    }
    if (data.containsKey('lapses')) {
      context.handle(_lapsesMeta,
          lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta));
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    }
    if (data.containsKey('last_review')) {
      context.handle(
          _lastReviewMeta,
          lastReview.isAcceptableOrUnknown(
              data['last_review']!, _lastReviewMeta));
    }
    if (data.containsKey('next_review')) {
      context.handle(
          _nextReviewMeta,
          nextReview.isAcceptableOrUnknown(
              data['next_review']!, _nextReviewMeta));
    }
    if (data.containsKey('times_shown')) {
      context.handle(
          _timesShownMeta,
          timesShown.isAcceptableOrUnknown(
              data['times_shown']!, _timesShownMeta));
    }
    if (data.containsKey('times_correct')) {
      context.handle(
          _timesCorrectMeta,
          timesCorrect.isAcceptableOrUnknown(
              data['times_correct']!, _timesCorrectMeta));
    }
    if (data.containsKey('mastery_level')) {
      context.handle(
          _masteryLevelMeta,
          masteryLevel.isAcceptableOrUnknown(
              data['mastery_level']!, _masteryLevelMeta));
    }
    if (data.containsKey('is_synced')) {
      context.handle(_isSyncedMeta,
          isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VariantProgressTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VariantProgressTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      variantId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}variant_id'])!,
      direction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}direction'])!,
      stability: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}stability'])!,
      difficulty: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}difficulty'])!,
      elapsedDays: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}elapsed_days'])!,
      scheduledDays: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}scheduled_days'])!,
      reps: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reps'])!,
      lapses: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lapses'])!,
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      lastReview: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_review']),
      nextReview: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}next_review']),
      timesShown: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}times_shown'])!,
      timesCorrect: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}times_correct'])!,
      masteryLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}mastery_level'])!,
      isSynced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synced'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $VariantProgressTableTable createAlias(String alias) {
    return $VariantProgressTableTable(attachedDatabase, alias);
  }
}

class VariantProgressTableData extends DataClass
    implements Insertable<VariantProgressTableData> {
  final String id;
  final String userId;
  final String variantId;
  final String direction;
  final double stability;
  final double difficulty;
  final int elapsedDays;
  final int scheduledDays;
  final int reps;
  final int lapses;
  final String state;
  final DateTime? lastReview;
  final DateTime? nextReview;
  final int timesShown;
  final int timesCorrect;
  final double masteryLevel;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  const VariantProgressTableData(
      {required this.id,
      required this.userId,
      required this.variantId,
      required this.direction,
      required this.stability,
      required this.difficulty,
      required this.elapsedDays,
      required this.scheduledDays,
      required this.reps,
      required this.lapses,
      required this.state,
      this.lastReview,
      this.nextReview,
      required this.timesShown,
      required this.timesCorrect,
      required this.masteryLevel,
      required this.isSynced,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['variant_id'] = Variable<String>(variantId);
    map['direction'] = Variable<String>(direction);
    map['stability'] = Variable<double>(stability);
    map['difficulty'] = Variable<double>(difficulty);
    map['elapsed_days'] = Variable<int>(elapsedDays);
    map['scheduled_days'] = Variable<int>(scheduledDays);
    map['reps'] = Variable<int>(reps);
    map['lapses'] = Variable<int>(lapses);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || lastReview != null) {
      map['last_review'] = Variable<DateTime>(lastReview);
    }
    if (!nullToAbsent || nextReview != null) {
      map['next_review'] = Variable<DateTime>(nextReview);
    }
    map['times_shown'] = Variable<int>(timesShown);
    map['times_correct'] = Variable<int>(timesCorrect);
    map['mastery_level'] = Variable<double>(masteryLevel);
    map['is_synced'] = Variable<bool>(isSynced);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  VariantProgressTableCompanion toCompanion(bool nullToAbsent) {
    return VariantProgressTableCompanion(
      id: Value(id),
      userId: Value(userId),
      variantId: Value(variantId),
      direction: Value(direction),
      stability: Value(stability),
      difficulty: Value(difficulty),
      elapsedDays: Value(elapsedDays),
      scheduledDays: Value(scheduledDays),
      reps: Value(reps),
      lapses: Value(lapses),
      state: Value(state),
      lastReview: lastReview == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReview),
      nextReview: nextReview == null && nullToAbsent
          ? const Value.absent()
          : Value(nextReview),
      timesShown: Value(timesShown),
      timesCorrect: Value(timesCorrect),
      masteryLevel: Value(masteryLevel),
      isSynced: Value(isSynced),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory VariantProgressTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VariantProgressTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      variantId: serializer.fromJson<String>(json['variantId']),
      direction: serializer.fromJson<String>(json['direction']),
      stability: serializer.fromJson<double>(json['stability']),
      difficulty: serializer.fromJson<double>(json['difficulty']),
      elapsedDays: serializer.fromJson<int>(json['elapsedDays']),
      scheduledDays: serializer.fromJson<int>(json['scheduledDays']),
      reps: serializer.fromJson<int>(json['reps']),
      lapses: serializer.fromJson<int>(json['lapses']),
      state: serializer.fromJson<String>(json['state']),
      lastReview: serializer.fromJson<DateTime?>(json['lastReview']),
      nextReview: serializer.fromJson<DateTime?>(json['nextReview']),
      timesShown: serializer.fromJson<int>(json['timesShown']),
      timesCorrect: serializer.fromJson<int>(json['timesCorrect']),
      masteryLevel: serializer.fromJson<double>(json['masteryLevel']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'variantId': serializer.toJson<String>(variantId),
      'direction': serializer.toJson<String>(direction),
      'stability': serializer.toJson<double>(stability),
      'difficulty': serializer.toJson<double>(difficulty),
      'elapsedDays': serializer.toJson<int>(elapsedDays),
      'scheduledDays': serializer.toJson<int>(scheduledDays),
      'reps': serializer.toJson<int>(reps),
      'lapses': serializer.toJson<int>(lapses),
      'state': serializer.toJson<String>(state),
      'lastReview': serializer.toJson<DateTime?>(lastReview),
      'nextReview': serializer.toJson<DateTime?>(nextReview),
      'timesShown': serializer.toJson<int>(timesShown),
      'timesCorrect': serializer.toJson<int>(timesCorrect),
      'masteryLevel': serializer.toJson<double>(masteryLevel),
      'isSynced': serializer.toJson<bool>(isSynced),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  VariantProgressTableData copyWith(
          {String? id,
          String? userId,
          String? variantId,
          String? direction,
          double? stability,
          double? difficulty,
          int? elapsedDays,
          int? scheduledDays,
          int? reps,
          int? lapses,
          String? state,
          Value<DateTime?> lastReview = const Value.absent(),
          Value<DateTime?> nextReview = const Value.absent(),
          int? timesShown,
          int? timesCorrect,
          double? masteryLevel,
          bool? isSynced,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      VariantProgressTableData(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        variantId: variantId ?? this.variantId,
        direction: direction ?? this.direction,
        stability: stability ?? this.stability,
        difficulty: difficulty ?? this.difficulty,
        elapsedDays: elapsedDays ?? this.elapsedDays,
        scheduledDays: scheduledDays ?? this.scheduledDays,
        reps: reps ?? this.reps,
        lapses: lapses ?? this.lapses,
        state: state ?? this.state,
        lastReview: lastReview.present ? lastReview.value : this.lastReview,
        nextReview: nextReview.present ? nextReview.value : this.nextReview,
        timesShown: timesShown ?? this.timesShown,
        timesCorrect: timesCorrect ?? this.timesCorrect,
        masteryLevel: masteryLevel ?? this.masteryLevel,
        isSynced: isSynced ?? this.isSynced,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  VariantProgressTableData copyWithCompanion(
      VariantProgressTableCompanion data) {
    return VariantProgressTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      direction: data.direction.present ? data.direction.value : this.direction,
      stability: data.stability.present ? data.stability.value : this.stability,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      elapsedDays:
          data.elapsedDays.present ? data.elapsedDays.value : this.elapsedDays,
      scheduledDays: data.scheduledDays.present
          ? data.scheduledDays.value
          : this.scheduledDays,
      reps: data.reps.present ? data.reps.value : this.reps,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      state: data.state.present ? data.state.value : this.state,
      lastReview:
          data.lastReview.present ? data.lastReview.value : this.lastReview,
      nextReview:
          data.nextReview.present ? data.nextReview.value : this.nextReview,
      timesShown:
          data.timesShown.present ? data.timesShown.value : this.timesShown,
      timesCorrect: data.timesCorrect.present
          ? data.timesCorrect.value
          : this.timesCorrect,
      masteryLevel: data.masteryLevel.present
          ? data.masteryLevel.value
          : this.masteryLevel,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VariantProgressTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('variantId: $variantId, ')
          ..write('direction: $direction, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('elapsedDays: $elapsedDays, ')
          ..write('scheduledDays: $scheduledDays, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('state: $state, ')
          ..write('lastReview: $lastReview, ')
          ..write('nextReview: $nextReview, ')
          ..write('timesShown: $timesShown, ')
          ..write('timesCorrect: $timesCorrect, ')
          ..write('masteryLevel: $masteryLevel, ')
          ..write('isSynced: $isSynced, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      userId,
      variantId,
      direction,
      stability,
      difficulty,
      elapsedDays,
      scheduledDays,
      reps,
      lapses,
      state,
      lastReview,
      nextReview,
      timesShown,
      timesCorrect,
      masteryLevel,
      isSynced,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VariantProgressTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.variantId == this.variantId &&
          other.direction == this.direction &&
          other.stability == this.stability &&
          other.difficulty == this.difficulty &&
          other.elapsedDays == this.elapsedDays &&
          other.scheduledDays == this.scheduledDays &&
          other.reps == this.reps &&
          other.lapses == this.lapses &&
          other.state == this.state &&
          other.lastReview == this.lastReview &&
          other.nextReview == this.nextReview &&
          other.timesShown == this.timesShown &&
          other.timesCorrect == this.timesCorrect &&
          other.masteryLevel == this.masteryLevel &&
          other.isSynced == this.isSynced &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class VariantProgressTableCompanion
    extends UpdateCompanion<VariantProgressTableData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> variantId;
  final Value<String> direction;
  final Value<double> stability;
  final Value<double> difficulty;
  final Value<int> elapsedDays;
  final Value<int> scheduledDays;
  final Value<int> reps;
  final Value<int> lapses;
  final Value<String> state;
  final Value<DateTime?> lastReview;
  final Value<DateTime?> nextReview;
  final Value<int> timesShown;
  final Value<int> timesCorrect;
  final Value<double> masteryLevel;
  final Value<bool> isSynced;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const VariantProgressTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.variantId = const Value.absent(),
    this.direction = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.elapsedDays = const Value.absent(),
    this.scheduledDays = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.state = const Value.absent(),
    this.lastReview = const Value.absent(),
    this.nextReview = const Value.absent(),
    this.timesShown = const Value.absent(),
    this.timesCorrect = const Value.absent(),
    this.masteryLevel = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VariantProgressTableCompanion.insert({
    required String id,
    required String userId,
    required String variantId,
    required String direction,
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.elapsedDays = const Value.absent(),
    this.scheduledDays = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.state = const Value.absent(),
    this.lastReview = const Value.absent(),
    this.nextReview = const Value.absent(),
    this.timesShown = const Value.absent(),
    this.timesCorrect = const Value.absent(),
    this.masteryLevel = const Value.absent(),
    this.isSynced = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        variantId = Value(variantId),
        direction = Value(direction),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<VariantProgressTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? variantId,
    Expression<String>? direction,
    Expression<double>? stability,
    Expression<double>? difficulty,
    Expression<int>? elapsedDays,
    Expression<int>? scheduledDays,
    Expression<int>? reps,
    Expression<int>? lapses,
    Expression<String>? state,
    Expression<DateTime>? lastReview,
    Expression<DateTime>? nextReview,
    Expression<int>? timesShown,
    Expression<int>? timesCorrect,
    Expression<double>? masteryLevel,
    Expression<bool>? isSynced,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (variantId != null) 'variant_id': variantId,
      if (direction != null) 'direction': direction,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
      if (elapsedDays != null) 'elapsed_days': elapsedDays,
      if (scheduledDays != null) 'scheduled_days': scheduledDays,
      if (reps != null) 'reps': reps,
      if (lapses != null) 'lapses': lapses,
      if (state != null) 'state': state,
      if (lastReview != null) 'last_review': lastReview,
      if (nextReview != null) 'next_review': nextReview,
      if (timesShown != null) 'times_shown': timesShown,
      if (timesCorrect != null) 'times_correct': timesCorrect,
      if (masteryLevel != null) 'mastery_level': masteryLevel,
      if (isSynced != null) 'is_synced': isSynced,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VariantProgressTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? variantId,
      Value<String>? direction,
      Value<double>? stability,
      Value<double>? difficulty,
      Value<int>? elapsedDays,
      Value<int>? scheduledDays,
      Value<int>? reps,
      Value<int>? lapses,
      Value<String>? state,
      Value<DateTime?>? lastReview,
      Value<DateTime?>? nextReview,
      Value<int>? timesShown,
      Value<int>? timesCorrect,
      Value<double>? masteryLevel,
      Value<bool>? isSynced,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return VariantProgressTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      variantId: variantId ?? this.variantId,
      direction: direction ?? this.direction,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      state: state ?? this.state,
      lastReview: lastReview ?? this.lastReview,
      nextReview: nextReview ?? this.nextReview,
      timesShown: timesShown ?? this.timesShown,
      timesCorrect: timesCorrect ?? this.timesCorrect,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (variantId.present) {
      map['variant_id'] = Variable<String>(variantId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (elapsedDays.present) {
      map['elapsed_days'] = Variable<int>(elapsedDays.value);
    }
    if (scheduledDays.present) {
      map['scheduled_days'] = Variable<int>(scheduledDays.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (lastReview.present) {
      map['last_review'] = Variable<DateTime>(lastReview.value);
    }
    if (nextReview.present) {
      map['next_review'] = Variable<DateTime>(nextReview.value);
    }
    if (timesShown.present) {
      map['times_shown'] = Variable<int>(timesShown.value);
    }
    if (timesCorrect.present) {
      map['times_correct'] = Variable<int>(timesCorrect.value);
    }
    if (masteryLevel.present) {
      map['mastery_level'] = Variable<double>(masteryLevel.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VariantProgressTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('variantId: $variantId, ')
          ..write('direction: $direction, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('elapsedDays: $elapsedDays, ')
          ..write('scheduledDays: $scheduledDays, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('state: $state, ')
          ..write('lastReview: $lastReview, ')
          ..write('nextReview: $nextReview, ')
          ..write('timesShown: $timesShown, ')
          ..write('timesCorrect: $timesCorrect, ')
          ..write('masteryLevel: $masteryLevel, ')
          ..write('isSynced: $isSynced, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTableTable extends SyncQueueTable
    with TableInfo<$SyncQueueTableTable, SyncQueueTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _tableName_Meta =
      const VerificationMeta('tableName_');
  @override
  late final GeneratedColumn<String> tableName_ = GeneratedColumn<String>(
      'table_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
      'row_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, tableName_, rowId, operation, payload, retryCount, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(Insertable<SyncQueueTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('table_name')) {
      context.handle(
          _tableName_Meta,
          tableName_.isAcceptableOrUnknown(
              data['table_name']!, _tableName_Meta));
    } else if (isInserting) {
      context.missing(_tableName_Meta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
          _rowIdMeta, rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta));
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      tableName_: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}table_name'])!,
      rowId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}row_id'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SyncQueueTableTable createAlias(String alias) {
    return $SyncQueueTableTable(attachedDatabase, alias);
  }
}

class SyncQueueTableData extends DataClass
    implements Insertable<SyncQueueTableData> {
  final int id;
  final String tableName_;
  final String rowId;
  final String operation;
  final String payload;
  final int retryCount;
  final DateTime createdAt;
  const SyncQueueTableData(
      {required this.id,
      required this.tableName_,
      required this.rowId,
      required this.operation,
      required this.payload,
      required this.retryCount,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['table_name'] = Variable<String>(tableName_);
    map['row_id'] = Variable<String>(rowId);
    map['operation'] = Variable<String>(operation);
    map['payload'] = Variable<String>(payload);
    map['retry_count'] = Variable<int>(retryCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyncQueueTableCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueTableCompanion(
      id: Value(id),
      tableName_: Value(tableName_),
      rowId: Value(rowId),
      operation: Value(operation),
      payload: Value(payload),
      retryCount: Value(retryCount),
      createdAt: Value(createdAt),
    );
  }

  factory SyncQueueTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueTableData(
      id: serializer.fromJson<int>(json['id']),
      tableName_: serializer.fromJson<String>(json['tableName_']),
      rowId: serializer.fromJson<String>(json['rowId']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String>(json['payload']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tableName_': serializer.toJson<String>(tableName_),
      'rowId': serializer.toJson<String>(rowId),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String>(payload),
      'retryCount': serializer.toJson<int>(retryCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SyncQueueTableData copyWith(
          {int? id,
          String? tableName_,
          String? rowId,
          String? operation,
          String? payload,
          int? retryCount,
          DateTime? createdAt}) =>
      SyncQueueTableData(
        id: id ?? this.id,
        tableName_: tableName_ ?? this.tableName_,
        rowId: rowId ?? this.rowId,
        operation: operation ?? this.operation,
        payload: payload ?? this.payload,
        retryCount: retryCount ?? this.retryCount,
        createdAt: createdAt ?? this.createdAt,
      );
  SyncQueueTableData copyWithCompanion(SyncQueueTableCompanion data) {
    return SyncQueueTableData(
      id: data.id.present ? data.id.value : this.id,
      tableName_:
          data.tableName_.present ? data.tableName_.value : this.tableName_,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueTableData(')
          ..write('id: $id, ')
          ..write('tableName_: $tableName_, ')
          ..write('rowId: $rowId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, tableName_, rowId, operation, payload, retryCount, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueTableData &&
          other.id == this.id &&
          other.tableName_ == this.tableName_ &&
          other.rowId == this.rowId &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.retryCount == this.retryCount &&
          other.createdAt == this.createdAt);
}

class SyncQueueTableCompanion extends UpdateCompanion<SyncQueueTableData> {
  final Value<int> id;
  final Value<String> tableName_;
  final Value<String> rowId;
  final Value<String> operation;
  final Value<String> payload;
  final Value<int> retryCount;
  final Value<DateTime> createdAt;
  const SyncQueueTableCompanion({
    this.id = const Value.absent(),
    this.tableName_ = const Value.absent(),
    this.rowId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SyncQueueTableCompanion.insert({
    this.id = const Value.absent(),
    required String tableName_,
    required String rowId,
    required String operation,
    required String payload,
    this.retryCount = const Value.absent(),
    required DateTime createdAt,
  })  : tableName_ = Value(tableName_),
        rowId = Value(rowId),
        operation = Value(operation),
        payload = Value(payload),
        createdAt = Value(createdAt);
  static Insertable<SyncQueueTableData> custom({
    Expression<int>? id,
    Expression<String>? tableName_,
    Expression<String>? rowId,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<int>? retryCount,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tableName_ != null) 'table_name': tableName_,
      if (rowId != null) 'row_id': rowId,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (retryCount != null) 'retry_count': retryCount,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SyncQueueTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? tableName_,
      Value<String>? rowId,
      Value<String>? operation,
      Value<String>? payload,
      Value<int>? retryCount,
      Value<DateTime>? createdAt}) {
    return SyncQueueTableCompanion(
      id: id ?? this.id,
      tableName_: tableName_ ?? this.tableName_,
      rowId: rowId ?? this.rowId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tableName_.present) {
      map['table_name'] = Variable<String>(tableName_.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueTableCompanion(')
          ..write('id: $id, ')
          ..write('tableName_: $tableName_, ')
          ..write('rowId: $rowId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $QuizSessionsTableTable extends QuizSessionsTable
    with TableInfo<$QuizSessionsTableTable, QuizSessionsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuizSessionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
      'list_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _listNameMeta =
      const VerificationMeta('listName');
  @override
  late final GeneratedColumn<String> listName = GeneratedColumn<String>(
      'list_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
      'mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _directionMeta =
      const VerificationMeta('direction');
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
      'direction', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cardCountMeta =
      const VerificationMeta('cardCount');
  @override
  late final GeneratedColumn<int> cardCount = GeneratedColumn<int>(
      'card_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _correctCountMeta =
      const VerificationMeta('correctCount');
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
      'correct_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _masteredWordCountMeta =
      const VerificationMeta('masteredWordCount');
  @override
  late final GeneratedColumn<int> masteredWordCount = GeneratedColumn<int>(
      'mastered_word_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        listId,
        listName,
        mode,
        direction,
        cardCount,
        correctCount,
        durationSeconds,
        masteredWordCount,
        completedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quiz_sessions';
  @override
  VerificationContext validateIntegrity(
      Insertable<QuizSessionsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('list_id')) {
      context.handle(_listIdMeta,
          listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta));
    }
    if (data.containsKey('list_name')) {
      context.handle(_listNameMeta,
          listName.isAcceptableOrUnknown(data['list_name']!, _listNameMeta));
    } else if (isInserting) {
      context.missing(_listNameMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(_directionMeta,
          direction.isAcceptableOrUnknown(data['direction']!, _directionMeta));
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('card_count')) {
      context.handle(_cardCountMeta,
          cardCount.isAcceptableOrUnknown(data['card_count']!, _cardCountMeta));
    } else if (isInserting) {
      context.missing(_cardCountMeta);
    }
    if (data.containsKey('correct_count')) {
      context.handle(
          _correctCountMeta,
          correctCount.isAcceptableOrUnknown(
              data['correct_count']!, _correctCountMeta));
    } else if (isInserting) {
      context.missing(_correctCountMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('mastered_word_count')) {
      context.handle(
          _masteredWordCountMeta,
          masteredWordCount.isAcceptableOrUnknown(
              data['mastered_word_count']!, _masteredWordCountMeta));
    } else if (isInserting) {
      context.missing(_masteredWordCountMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuizSessionsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuizSessionsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      listId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}list_id']),
      listName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}list_name'])!,
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      direction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}direction'])!,
      cardCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}card_count'])!,
      correctCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}correct_count'])!,
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds'])!,
      masteredWordCount: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}mastered_word_count'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at'])!,
    );
  }

  @override
  $QuizSessionsTableTable createAlias(String alias) {
    return $QuizSessionsTableTable(attachedDatabase, alias);
  }
}

class QuizSessionsTableData extends DataClass
    implements Insertable<QuizSessionsTableData> {
  final String id;
  final String userId;

  /// Nullable: list may be deleted, but we keep the history.
  final String? listId;

  /// Snapshot of the list name at the time of the session.
  final String listName;

  /// QuizMode name (voice / flashcard / typing / handsFree).
  final String mode;

  /// QuizDirectionChoice name (frToKo / koToFr / both).
  final String direction;
  final int cardCount;
  final int correctCount;
  final int durationSeconds;

  /// Total mastered words across ALL lists at the moment the session ended.
  final int masteredWordCount;
  final DateTime completedAt;
  const QuizSessionsTableData(
      {required this.id,
      required this.userId,
      this.listId,
      required this.listName,
      required this.mode,
      required this.direction,
      required this.cardCount,
      required this.correctCount,
      required this.durationSeconds,
      required this.masteredWordCount,
      required this.completedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || listId != null) {
      map['list_id'] = Variable<String>(listId);
    }
    map['list_name'] = Variable<String>(listName);
    map['mode'] = Variable<String>(mode);
    map['direction'] = Variable<String>(direction);
    map['card_count'] = Variable<int>(cardCount);
    map['correct_count'] = Variable<int>(correctCount);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['mastered_word_count'] = Variable<int>(masteredWordCount);
    map['completed_at'] = Variable<DateTime>(completedAt);
    return map;
  }

  QuizSessionsTableCompanion toCompanion(bool nullToAbsent) {
    return QuizSessionsTableCompanion(
      id: Value(id),
      userId: Value(userId),
      listId:
          listId == null && nullToAbsent ? const Value.absent() : Value(listId),
      listName: Value(listName),
      mode: Value(mode),
      direction: Value(direction),
      cardCount: Value(cardCount),
      correctCount: Value(correctCount),
      durationSeconds: Value(durationSeconds),
      masteredWordCount: Value(masteredWordCount),
      completedAt: Value(completedAt),
    );
  }

  factory QuizSessionsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuizSessionsTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      listId: serializer.fromJson<String?>(json['listId']),
      listName: serializer.fromJson<String>(json['listName']),
      mode: serializer.fromJson<String>(json['mode']),
      direction: serializer.fromJson<String>(json['direction']),
      cardCount: serializer.fromJson<int>(json['cardCount']),
      correctCount: serializer.fromJson<int>(json['correctCount']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      masteredWordCount: serializer.fromJson<int>(json['masteredWordCount']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'listId': serializer.toJson<String?>(listId),
      'listName': serializer.toJson<String>(listName),
      'mode': serializer.toJson<String>(mode),
      'direction': serializer.toJson<String>(direction),
      'cardCount': serializer.toJson<int>(cardCount),
      'correctCount': serializer.toJson<int>(correctCount),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'masteredWordCount': serializer.toJson<int>(masteredWordCount),
      'completedAt': serializer.toJson<DateTime>(completedAt),
    };
  }

  QuizSessionsTableData copyWith(
          {String? id,
          String? userId,
          Value<String?> listId = const Value.absent(),
          String? listName,
          String? mode,
          String? direction,
          int? cardCount,
          int? correctCount,
          int? durationSeconds,
          int? masteredWordCount,
          DateTime? completedAt}) =>
      QuizSessionsTableData(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        listId: listId.present ? listId.value : this.listId,
        listName: listName ?? this.listName,
        mode: mode ?? this.mode,
        direction: direction ?? this.direction,
        cardCount: cardCount ?? this.cardCount,
        correctCount: correctCount ?? this.correctCount,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        masteredWordCount: masteredWordCount ?? this.masteredWordCount,
        completedAt: completedAt ?? this.completedAt,
      );
  QuizSessionsTableData copyWithCompanion(QuizSessionsTableCompanion data) {
    return QuizSessionsTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      listId: data.listId.present ? data.listId.value : this.listId,
      listName: data.listName.present ? data.listName.value : this.listName,
      mode: data.mode.present ? data.mode.value : this.mode,
      direction: data.direction.present ? data.direction.value : this.direction,
      cardCount: data.cardCount.present ? data.cardCount.value : this.cardCount,
      correctCount: data.correctCount.present
          ? data.correctCount.value
          : this.correctCount,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      masteredWordCount: data.masteredWordCount.present
          ? data.masteredWordCount.value
          : this.masteredWordCount,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuizSessionsTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('listId: $listId, ')
          ..write('listName: $listName, ')
          ..write('mode: $mode, ')
          ..write('direction: $direction, ')
          ..write('cardCount: $cardCount, ')
          ..write('correctCount: $correctCount, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('masteredWordCount: $masteredWordCount, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, listId, listName, mode, direction,
      cardCount, correctCount, durationSeconds, masteredWordCount, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuizSessionsTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.listId == this.listId &&
          other.listName == this.listName &&
          other.mode == this.mode &&
          other.direction == this.direction &&
          other.cardCount == this.cardCount &&
          other.correctCount == this.correctCount &&
          other.durationSeconds == this.durationSeconds &&
          other.masteredWordCount == this.masteredWordCount &&
          other.completedAt == this.completedAt);
}

class QuizSessionsTableCompanion
    extends UpdateCompanion<QuizSessionsTableData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> listId;
  final Value<String> listName;
  final Value<String> mode;
  final Value<String> direction;
  final Value<int> cardCount;
  final Value<int> correctCount;
  final Value<int> durationSeconds;
  final Value<int> masteredWordCount;
  final Value<DateTime> completedAt;
  final Value<int> rowid;
  const QuizSessionsTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.listId = const Value.absent(),
    this.listName = const Value.absent(),
    this.mode = const Value.absent(),
    this.direction = const Value.absent(),
    this.cardCount = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.masteredWordCount = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuizSessionsTableCompanion.insert({
    required String id,
    required String userId,
    this.listId = const Value.absent(),
    required String listName,
    required String mode,
    required String direction,
    required int cardCount,
    required int correctCount,
    required int durationSeconds,
    required int masteredWordCount,
    required DateTime completedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        listName = Value(listName),
        mode = Value(mode),
        direction = Value(direction),
        cardCount = Value(cardCount),
        correctCount = Value(correctCount),
        durationSeconds = Value(durationSeconds),
        masteredWordCount = Value(masteredWordCount),
        completedAt = Value(completedAt);
  static Insertable<QuizSessionsTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? listId,
    Expression<String>? listName,
    Expression<String>? mode,
    Expression<String>? direction,
    Expression<int>? cardCount,
    Expression<int>? correctCount,
    Expression<int>? durationSeconds,
    Expression<int>? masteredWordCount,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (listId != null) 'list_id': listId,
      if (listName != null) 'list_name': listName,
      if (mode != null) 'mode': mode,
      if (direction != null) 'direction': direction,
      if (cardCount != null) 'card_count': cardCount,
      if (correctCount != null) 'correct_count': correctCount,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (masteredWordCount != null) 'mastered_word_count': masteredWordCount,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuizSessionsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String?>? listId,
      Value<String>? listName,
      Value<String>? mode,
      Value<String>? direction,
      Value<int>? cardCount,
      Value<int>? correctCount,
      Value<int>? durationSeconds,
      Value<int>? masteredWordCount,
      Value<DateTime>? completedAt,
      Value<int>? rowid}) {
    return QuizSessionsTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      listId: listId ?? this.listId,
      listName: listName ?? this.listName,
      mode: mode ?? this.mode,
      direction: direction ?? this.direction,
      cardCount: cardCount ?? this.cardCount,
      correctCount: correctCount ?? this.correctCount,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      masteredWordCount: masteredWordCount ?? this.masteredWordCount,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (listName.present) {
      map['list_name'] = Variable<String>(listName.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (cardCount.present) {
      map['card_count'] = Variable<int>(cardCount.value);
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (masteredWordCount.present) {
      map['mastered_word_count'] = Variable<int>(masteredWordCount.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuizSessionsTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('listId: $listId, ')
          ..write('listName: $listName, ')
          ..write('mode: $mode, ')
          ..write('direction: $direction, ')
          ..write('cardCount: $cardCount, ')
          ..write('correctCount: $correctCount, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('masteredWordCount: $masteredWordCount, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VocabularyListsTableTable vocabularyListsTable =
      $VocabularyListsTableTable(this);
  late final $ConceptsTableTable conceptsTable = $ConceptsTableTable(this);
  late final $WordVariantsTableTable wordVariantsTable =
      $WordVariantsTableTable(this);
  late final $VariantProgressTableTable variantProgressTable =
      $VariantProgressTableTable(this);
  late final $SyncQueueTableTable syncQueueTable = $SyncQueueTableTable(this);
  late final $QuizSessionsTableTable quizSessionsTable =
      $QuizSessionsTableTable(this);
  late final VocabularyListDao vocabularyListDao =
      VocabularyListDao(this as AppDatabase);
  late final ConceptDao conceptDao = ConceptDao(this as AppDatabase);
  late final ProgressDao progressDao = ProgressDao(this as AppDatabase);
  late final QuizSessionDao quizSessionDao =
      QuizSessionDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        vocabularyListsTable,
        conceptsTable,
        wordVariantsTable,
        variantProgressTable,
        syncQueueTable,
        quizSessionsTable
      ];
}

typedef $$VocabularyListsTableTableCreateCompanionBuilder
    = VocabularyListsTableCompanion Function({
  required String id,
  required String ownerId,
  required String name,
  Value<String?> description,
  Value<String> visibility,
  Value<int> wordCount,
  Value<String?> shareToken,
  Value<bool> isSynced,
  Value<bool> isDeleted,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$VocabularyListsTableTableUpdateCompanionBuilder
    = VocabularyListsTableCompanion Function({
  Value<String> id,
  Value<String> ownerId,
  Value<String> name,
  Value<String?> description,
  Value<String> visibility,
  Value<int> wordCount,
  Value<String?> shareToken,
  Value<bool> isSynced,
  Value<bool> isDeleted,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$VocabularyListsTableTableReferences extends BaseReferences<
    _$AppDatabase, $VocabularyListsTableTable, VocabularyListsTableData> {
  $$VocabularyListsTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ConceptsTableTable, List<ConceptsTableData>>
      _conceptsTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.conceptsTable,
              aliasName: $_aliasNameGenerator(
                  db.vocabularyListsTable.id, db.conceptsTable.listId));

  $$ConceptsTableTableProcessedTableManager get conceptsTableRefs {
    final manager = $$ConceptsTableTableTableManager($_db, $_db.conceptsTable)
        .filter((f) => f.listId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_conceptsTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$VocabularyListsTableTableFilterComposer
    extends Composer<_$AppDatabase, $VocabularyListsTableTable> {
  $$VocabularyListsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get visibility => $composableBuilder(
      column: $table.visibility, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get wordCount => $composableBuilder(
      column: $table.wordCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shareToken => $composableBuilder(
      column: $table.shareToken, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSynced => $composableBuilder(
      column: $table.isSynced, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> conceptsTableRefs(
      Expression<bool> Function($$ConceptsTableTableFilterComposer f) f) {
    final $$ConceptsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.conceptsTable,
        getReferencedColumn: (t) => t.listId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConceptsTableTableFilterComposer(
              $db: $db,
              $table: $db.conceptsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$VocabularyListsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $VocabularyListsTableTable> {
  $$VocabularyListsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get visibility => $composableBuilder(
      column: $table.visibility, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get wordCount => $composableBuilder(
      column: $table.wordCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shareToken => $composableBuilder(
      column: $table.shareToken, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSynced => $composableBuilder(
      column: $table.isSynced, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$VocabularyListsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $VocabularyListsTableTable> {
  $$VocabularyListsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get visibility => $composableBuilder(
      column: $table.visibility, builder: (column) => column);

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<String> get shareToken => $composableBuilder(
      column: $table.shareToken, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> conceptsTableRefs<T extends Object>(
      Expression<T> Function($$ConceptsTableTableAnnotationComposer a) f) {
    final $$ConceptsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.conceptsTable,
        getReferencedColumn: (t) => t.listId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConceptsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.conceptsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$VocabularyListsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $VocabularyListsTableTable,
    VocabularyListsTableData,
    $$VocabularyListsTableTableFilterComposer,
    $$VocabularyListsTableTableOrderingComposer,
    $$VocabularyListsTableTableAnnotationComposer,
    $$VocabularyListsTableTableCreateCompanionBuilder,
    $$VocabularyListsTableTableUpdateCompanionBuilder,
    (VocabularyListsTableData, $$VocabularyListsTableTableReferences),
    VocabularyListsTableData,
    PrefetchHooks Function({bool conceptsTableRefs})> {
  $$VocabularyListsTableTableTableManager(
      _$AppDatabase db, $VocabularyListsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VocabularyListsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VocabularyListsTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VocabularyListsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> ownerId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> visibility = const Value.absent(),
            Value<int> wordCount = const Value.absent(),
            Value<String?> shareToken = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              VocabularyListsTableCompanion(
            id: id,
            ownerId: ownerId,
            name: name,
            description: description,
            visibility: visibility,
            wordCount: wordCount,
            shareToken: shareToken,
            isSynced: isSynced,
            isDeleted: isDeleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String ownerId,
            required String name,
            Value<String?> description = const Value.absent(),
            Value<String> visibility = const Value.absent(),
            Value<int> wordCount = const Value.absent(),
            Value<String?> shareToken = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              VocabularyListsTableCompanion.insert(
            id: id,
            ownerId: ownerId,
            name: name,
            description: description,
            visibility: visibility,
            wordCount: wordCount,
            shareToken: shareToken,
            isSynced: isSynced,
            isDeleted: isDeleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$VocabularyListsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({conceptsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (conceptsTableRefs) db.conceptsTable
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (conceptsTableRefs)
                    await $_getPrefetchedData<VocabularyListsTableData,
                            $VocabularyListsTableTable, ConceptsTableData>(
                        currentTable: table,
                        referencedTable: $$VocabularyListsTableTableReferences
                            ._conceptsTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$VocabularyListsTableTableReferences(db, table, p0)
                                .conceptsTableRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.listId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$VocabularyListsTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $VocabularyListsTableTable,
        VocabularyListsTableData,
        $$VocabularyListsTableTableFilterComposer,
        $$VocabularyListsTableTableOrderingComposer,
        $$VocabularyListsTableTableAnnotationComposer,
        $$VocabularyListsTableTableCreateCompanionBuilder,
        $$VocabularyListsTableTableUpdateCompanionBuilder,
        (VocabularyListsTableData, $$VocabularyListsTableTableReferences),
        VocabularyListsTableData,
        PrefetchHooks Function({bool conceptsTableRefs})>;
typedef $$ConceptsTableTableCreateCompanionBuilder = ConceptsTableCompanion
    Function({
  required String id,
  required String listId,
  Value<String?> category,
  Value<String?> notes,
  Value<String?> imageUrl,
  Value<String?> exampleFr,
  Value<String?> exampleKo,
  Value<bool> isSynced,
  Value<bool> isDeleted,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ConceptsTableTableUpdateCompanionBuilder = ConceptsTableCompanion
    Function({
  Value<String> id,
  Value<String> listId,
  Value<String?> category,
  Value<String?> notes,
  Value<String?> imageUrl,
  Value<String?> exampleFr,
  Value<String?> exampleKo,
  Value<bool> isSynced,
  Value<bool> isDeleted,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ConceptsTableTableReferences extends BaseReferences<_$AppDatabase,
    $ConceptsTableTable, ConceptsTableData> {
  $$ConceptsTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $VocabularyListsTableTable _listIdTable(_$AppDatabase db) =>
      db.vocabularyListsTable.createAlias($_aliasNameGenerator(
          db.conceptsTable.listId, db.vocabularyListsTable.id));

  $$VocabularyListsTableTableProcessedTableManager get listId {
    final $_column = $_itemColumn<String>('list_id')!;

    final manager =
        $$VocabularyListsTableTableTableManager($_db, $_db.vocabularyListsTable)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_listIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$WordVariantsTableTable,
      List<WordVariantsTableData>> _wordVariantsTableRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.wordVariantsTable,
          aliasName: $_aliasNameGenerator(
              db.conceptsTable.id, db.wordVariantsTable.conceptId));

  $$WordVariantsTableTableProcessedTableManager get wordVariantsTableRefs {
    final manager = $$WordVariantsTableTableTableManager(
            $_db, $_db.wordVariantsTable)
        .filter((f) => f.conceptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_wordVariantsTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ConceptsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ConceptsTableTable> {
  $$ConceptsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get exampleFr => $composableBuilder(
      column: $table.exampleFr, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get exampleKo => $composableBuilder(
      column: $table.exampleKo, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSynced => $composableBuilder(
      column: $table.isSynced, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$VocabularyListsTableTableFilterComposer get listId {
    final $$VocabularyListsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.listId,
        referencedTable: $db.vocabularyListsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$VocabularyListsTableTableFilterComposer(
              $db: $db,
              $table: $db.vocabularyListsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> wordVariantsTableRefs(
      Expression<bool> Function($$WordVariantsTableTableFilterComposer f) f) {
    final $$WordVariantsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.wordVariantsTable,
        getReferencedColumn: (t) => t.conceptId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WordVariantsTableTableFilterComposer(
              $db: $db,
              $table: $db.wordVariantsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ConceptsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ConceptsTableTable> {
  $$ConceptsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get exampleFr => $composableBuilder(
      column: $table.exampleFr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get exampleKo => $composableBuilder(
      column: $table.exampleKo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSynced => $composableBuilder(
      column: $table.isSynced, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$VocabularyListsTableTableOrderingComposer get listId {
    final $$VocabularyListsTableTableOrderingComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.listId,
            referencedTable: $db.vocabularyListsTable,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$VocabularyListsTableTableOrderingComposer(
                  $db: $db,
                  $table: $db.vocabularyListsTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$ConceptsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConceptsTableTable> {
  $$ConceptsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get exampleFr =>
      $composableBuilder(column: $table.exampleFr, builder: (column) => column);

  GeneratedColumn<String> get exampleKo =>
      $composableBuilder(column: $table.exampleKo, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$VocabularyListsTableTableAnnotationComposer get listId {
    final $$VocabularyListsTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.listId,
            referencedTable: $db.vocabularyListsTable,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$VocabularyListsTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.vocabularyListsTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }

  Expression<T> wordVariantsTableRefs<T extends Object>(
      Expression<T> Function($$WordVariantsTableTableAnnotationComposer a) f) {
    final $$WordVariantsTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.wordVariantsTable,
            getReferencedColumn: (t) => t.conceptId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$WordVariantsTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.wordVariantsTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$ConceptsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ConceptsTableTable,
    ConceptsTableData,
    $$ConceptsTableTableFilterComposer,
    $$ConceptsTableTableOrderingComposer,
    $$ConceptsTableTableAnnotationComposer,
    $$ConceptsTableTableCreateCompanionBuilder,
    $$ConceptsTableTableUpdateCompanionBuilder,
    (ConceptsTableData, $$ConceptsTableTableReferences),
    ConceptsTableData,
    PrefetchHooks Function({bool listId, bool wordVariantsTableRefs})> {
  $$ConceptsTableTableTableManager(_$AppDatabase db, $ConceptsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConceptsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConceptsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConceptsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> listId = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> exampleFr = const Value.absent(),
            Value<String?> exampleKo = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConceptsTableCompanion(
            id: id,
            listId: listId,
            category: category,
            notes: notes,
            imageUrl: imageUrl,
            exampleFr: exampleFr,
            exampleKo: exampleKo,
            isSynced: isSynced,
            isDeleted: isDeleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String listId,
            Value<String?> category = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> exampleFr = const Value.absent(),
            Value<String?> exampleKo = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ConceptsTableCompanion.insert(
            id: id,
            listId: listId,
            category: category,
            notes: notes,
            imageUrl: imageUrl,
            exampleFr: exampleFr,
            exampleKo: exampleKo,
            isSynced: isSynced,
            isDeleted: isDeleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ConceptsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {listId = false, wordVariantsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (wordVariantsTableRefs) db.wordVariantsTable
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (listId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.listId,
                    referencedTable:
                        $$ConceptsTableTableReferences._listIdTable(db),
                    referencedColumn:
                        $$ConceptsTableTableReferences._listIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (wordVariantsTableRefs)
                    await $_getPrefetchedData<ConceptsTableData,
                            $ConceptsTableTable, WordVariantsTableData>(
                        currentTable: table,
                        referencedTable: $$ConceptsTableTableReferences
                            ._wordVariantsTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ConceptsTableTableReferences(db, table, p0)
                                .wordVariantsTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.conceptId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ConceptsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ConceptsTableTable,
    ConceptsTableData,
    $$ConceptsTableTableFilterComposer,
    $$ConceptsTableTableOrderingComposer,
    $$ConceptsTableTableAnnotationComposer,
    $$ConceptsTableTableCreateCompanionBuilder,
    $$ConceptsTableTableUpdateCompanionBuilder,
    (ConceptsTableData, $$ConceptsTableTableReferences),
    ConceptsTableData,
    PrefetchHooks Function({bool listId, bool wordVariantsTableRefs})>;
typedef $$WordVariantsTableTableCreateCompanionBuilder
    = WordVariantsTableCompanion Function({
  required String id,
  required String conceptId,
  required String word,
  required String langCode,
  Value<String> registerTag,
  Value<String> contextTags,
  Value<bool> isPrimary,
  Value<String?> audioHash,
  Value<String?> audioVoiceId,
  Value<int> position,
  Value<bool> isSynced,
  Value<bool> isDeleted,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$WordVariantsTableTableUpdateCompanionBuilder
    = WordVariantsTableCompanion Function({
  Value<String> id,
  Value<String> conceptId,
  Value<String> word,
  Value<String> langCode,
  Value<String> registerTag,
  Value<String> contextTags,
  Value<bool> isPrimary,
  Value<String?> audioHash,
  Value<String?> audioVoiceId,
  Value<int> position,
  Value<bool> isSynced,
  Value<bool> isDeleted,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$WordVariantsTableTableReferences extends BaseReferences<
    _$AppDatabase, $WordVariantsTableTable, WordVariantsTableData> {
  $$WordVariantsTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ConceptsTableTable _conceptIdTable(_$AppDatabase db) =>
      db.conceptsTable.createAlias($_aliasNameGenerator(
          db.wordVariantsTable.conceptId, db.conceptsTable.id));

  $$ConceptsTableTableProcessedTableManager get conceptId {
    final $_column = $_itemColumn<String>('concept_id')!;

    final manager = $$ConceptsTableTableTableManager($_db, $_db.conceptsTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conceptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$VariantProgressTableTable,
      List<VariantProgressTableData>> _variantProgressTableRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.variantProgressTable,
          aliasName: $_aliasNameGenerator(
              db.wordVariantsTable.id, db.variantProgressTable.variantId));

  $$VariantProgressTableTableProcessedTableManager
      get variantProgressTableRefs {
    final manager = $$VariantProgressTableTableTableManager(
            $_db, $_db.variantProgressTable)
        .filter((f) => f.variantId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_variantProgressTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$WordVariantsTableTableFilterComposer
    extends Composer<_$AppDatabase, $WordVariantsTableTable> {
  $$WordVariantsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get word => $composableBuilder(
      column: $table.word, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get langCode => $composableBuilder(
      column: $table.langCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get registerTag => $composableBuilder(
      column: $table.registerTag, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contextTags => $composableBuilder(
      column: $table.contextTags, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPrimary => $composableBuilder(
      column: $table.isPrimary, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioHash => $composableBuilder(
      column: $table.audioHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioVoiceId => $composableBuilder(
      column: $table.audioVoiceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSynced => $composableBuilder(
      column: $table.isSynced, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$ConceptsTableTableFilterComposer get conceptId {
    final $$ConceptsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conceptId,
        referencedTable: $db.conceptsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConceptsTableTableFilterComposer(
              $db: $db,
              $table: $db.conceptsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> variantProgressTableRefs(
      Expression<bool> Function($$VariantProgressTableTableFilterComposer f)
          f) {
    final $$VariantProgressTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.variantProgressTable,
        getReferencedColumn: (t) => t.variantId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$VariantProgressTableTableFilterComposer(
              $db: $db,
              $table: $db.variantProgressTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$WordVariantsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WordVariantsTableTable> {
  $$WordVariantsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get word => $composableBuilder(
      column: $table.word, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get langCode => $composableBuilder(
      column: $table.langCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get registerTag => $composableBuilder(
      column: $table.registerTag, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contextTags => $composableBuilder(
      column: $table.contextTags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
      column: $table.isPrimary, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioHash => $composableBuilder(
      column: $table.audioHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioVoiceId => $composableBuilder(
      column: $table.audioVoiceId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSynced => $composableBuilder(
      column: $table.isSynced, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$ConceptsTableTableOrderingComposer get conceptId {
    final $$ConceptsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conceptId,
        referencedTable: $db.conceptsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConceptsTableTableOrderingComposer(
              $db: $db,
              $table: $db.conceptsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WordVariantsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordVariantsTableTable> {
  $$WordVariantsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<String> get langCode =>
      $composableBuilder(column: $table.langCode, builder: (column) => column);

  GeneratedColumn<String> get registerTag => $composableBuilder(
      column: $table.registerTag, builder: (column) => column);

  GeneratedColumn<String> get contextTags => $composableBuilder(
      column: $table.contextTags, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<String> get audioHash =>
      $composableBuilder(column: $table.audioHash, builder: (column) => column);

  GeneratedColumn<String> get audioVoiceId => $composableBuilder(
      column: $table.audioVoiceId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ConceptsTableTableAnnotationComposer get conceptId {
    final $$ConceptsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conceptId,
        referencedTable: $db.conceptsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConceptsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.conceptsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> variantProgressTableRefs<T extends Object>(
      Expression<T> Function($$VariantProgressTableTableAnnotationComposer a)
          f) {
    final $$VariantProgressTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.variantProgressTable,
            getReferencedColumn: (t) => t.variantId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$VariantProgressTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.variantProgressTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$WordVariantsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WordVariantsTableTable,
    WordVariantsTableData,
    $$WordVariantsTableTableFilterComposer,
    $$WordVariantsTableTableOrderingComposer,
    $$WordVariantsTableTableAnnotationComposer,
    $$WordVariantsTableTableCreateCompanionBuilder,
    $$WordVariantsTableTableUpdateCompanionBuilder,
    (WordVariantsTableData, $$WordVariantsTableTableReferences),
    WordVariantsTableData,
    PrefetchHooks Function({bool conceptId, bool variantProgressTableRefs})> {
  $$WordVariantsTableTableTableManager(
      _$AppDatabase db, $WordVariantsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordVariantsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordVariantsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordVariantsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> conceptId = const Value.absent(),
            Value<String> word = const Value.absent(),
            Value<String> langCode = const Value.absent(),
            Value<String> registerTag = const Value.absent(),
            Value<String> contextTags = const Value.absent(),
            Value<bool> isPrimary = const Value.absent(),
            Value<String?> audioHash = const Value.absent(),
            Value<String?> audioVoiceId = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WordVariantsTableCompanion(
            id: id,
            conceptId: conceptId,
            word: word,
            langCode: langCode,
            registerTag: registerTag,
            contextTags: contextTags,
            isPrimary: isPrimary,
            audioHash: audioHash,
            audioVoiceId: audioVoiceId,
            position: position,
            isSynced: isSynced,
            isDeleted: isDeleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String conceptId,
            required String word,
            required String langCode,
            Value<String> registerTag = const Value.absent(),
            Value<String> contextTags = const Value.absent(),
            Value<bool> isPrimary = const Value.absent(),
            Value<String?> audioHash = const Value.absent(),
            Value<String?> audioVoiceId = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              WordVariantsTableCompanion.insert(
            id: id,
            conceptId: conceptId,
            word: word,
            langCode: langCode,
            registerTag: registerTag,
            contextTags: contextTags,
            isPrimary: isPrimary,
            audioHash: audioHash,
            audioVoiceId: audioVoiceId,
            position: position,
            isSynced: isSynced,
            isDeleted: isDeleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$WordVariantsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {conceptId = false, variantProgressTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (variantProgressTableRefs) db.variantProgressTable
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (conceptId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.conceptId,
                    referencedTable:
                        $$WordVariantsTableTableReferences._conceptIdTable(db),
                    referencedColumn: $$WordVariantsTableTableReferences
                        ._conceptIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (variantProgressTableRefs)
                    await $_getPrefetchedData<WordVariantsTableData,
                            $WordVariantsTableTable, VariantProgressTableData>(
                        currentTable: table,
                        referencedTable: $$WordVariantsTableTableReferences
                            ._variantProgressTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$WordVariantsTableTableReferences(db, table, p0)
                                .variantProgressTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.variantId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$WordVariantsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WordVariantsTableTable,
    WordVariantsTableData,
    $$WordVariantsTableTableFilterComposer,
    $$WordVariantsTableTableOrderingComposer,
    $$WordVariantsTableTableAnnotationComposer,
    $$WordVariantsTableTableCreateCompanionBuilder,
    $$WordVariantsTableTableUpdateCompanionBuilder,
    (WordVariantsTableData, $$WordVariantsTableTableReferences),
    WordVariantsTableData,
    PrefetchHooks Function({bool conceptId, bool variantProgressTableRefs})>;
typedef $$VariantProgressTableTableCreateCompanionBuilder
    = VariantProgressTableCompanion Function({
  required String id,
  required String userId,
  required String variantId,
  required String direction,
  Value<double> stability,
  Value<double> difficulty,
  Value<int> elapsedDays,
  Value<int> scheduledDays,
  Value<int> reps,
  Value<int> lapses,
  Value<String> state,
  Value<DateTime?> lastReview,
  Value<DateTime?> nextReview,
  Value<int> timesShown,
  Value<int> timesCorrect,
  Value<double> masteryLevel,
  Value<bool> isSynced,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$VariantProgressTableTableUpdateCompanionBuilder
    = VariantProgressTableCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String> variantId,
  Value<String> direction,
  Value<double> stability,
  Value<double> difficulty,
  Value<int> elapsedDays,
  Value<int> scheduledDays,
  Value<int> reps,
  Value<int> lapses,
  Value<String> state,
  Value<DateTime?> lastReview,
  Value<DateTime?> nextReview,
  Value<int> timesShown,
  Value<int> timesCorrect,
  Value<double> masteryLevel,
  Value<bool> isSynced,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$VariantProgressTableTableReferences extends BaseReferences<
    _$AppDatabase, $VariantProgressTableTable, VariantProgressTableData> {
  $$VariantProgressTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $WordVariantsTableTable _variantIdTable(_$AppDatabase db) =>
      db.wordVariantsTable.createAlias($_aliasNameGenerator(
          db.variantProgressTable.variantId, db.wordVariantsTable.id));

  $$WordVariantsTableTableProcessedTableManager get variantId {
    final $_column = $_itemColumn<String>('variant_id')!;

    final manager =
        $$WordVariantsTableTableTableManager($_db, $_db.wordVariantsTable)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_variantIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$VariantProgressTableTableFilterComposer
    extends Composer<_$AppDatabase, $VariantProgressTableTable> {
  $$VariantProgressTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get stability => $composableBuilder(
      column: $table.stability, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get elapsedDays => $composableBuilder(
      column: $table.elapsedDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get scheduledDays => $composableBuilder(
      column: $table.scheduledDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reps => $composableBuilder(
      column: $table.reps, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lapses => $composableBuilder(
      column: $table.lapses, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastReview => $composableBuilder(
      column: $table.lastReview, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextReview => $composableBuilder(
      column: $table.nextReview, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timesShown => $composableBuilder(
      column: $table.timesShown, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timesCorrect => $composableBuilder(
      column: $table.timesCorrect, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get masteryLevel => $composableBuilder(
      column: $table.masteryLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSynced => $composableBuilder(
      column: $table.isSynced, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$WordVariantsTableTableFilterComposer get variantId {
    final $$WordVariantsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.variantId,
        referencedTable: $db.wordVariantsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WordVariantsTableTableFilterComposer(
              $db: $db,
              $table: $db.wordVariantsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$VariantProgressTableTableOrderingComposer
    extends Composer<_$AppDatabase, $VariantProgressTableTable> {
  $$VariantProgressTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get stability => $composableBuilder(
      column: $table.stability, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get elapsedDays => $composableBuilder(
      column: $table.elapsedDays, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get scheduledDays => $composableBuilder(
      column: $table.scheduledDays,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reps => $composableBuilder(
      column: $table.reps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lapses => $composableBuilder(
      column: $table.lapses, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastReview => $composableBuilder(
      column: $table.lastReview, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextReview => $composableBuilder(
      column: $table.nextReview, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timesShown => $composableBuilder(
      column: $table.timesShown, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timesCorrect => $composableBuilder(
      column: $table.timesCorrect,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get masteryLevel => $composableBuilder(
      column: $table.masteryLevel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSynced => $composableBuilder(
      column: $table.isSynced, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$WordVariantsTableTableOrderingComposer get variantId {
    final $$WordVariantsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.variantId,
        referencedTable: $db.wordVariantsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WordVariantsTableTableOrderingComposer(
              $db: $db,
              $table: $db.wordVariantsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$VariantProgressTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $VariantProgressTableTable> {
  $$VariantProgressTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<double> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => column);

  GeneratedColumn<int> get elapsedDays => $composableBuilder(
      column: $table.elapsedDays, builder: (column) => column);

  GeneratedColumn<int> get scheduledDays => $composableBuilder(
      column: $table.scheduledDays, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReview => $composableBuilder(
      column: $table.lastReview, builder: (column) => column);

  GeneratedColumn<DateTime> get nextReview => $composableBuilder(
      column: $table.nextReview, builder: (column) => column);

  GeneratedColumn<int> get timesShown => $composableBuilder(
      column: $table.timesShown, builder: (column) => column);

  GeneratedColumn<int> get timesCorrect => $composableBuilder(
      column: $table.timesCorrect, builder: (column) => column);

  GeneratedColumn<double> get masteryLevel => $composableBuilder(
      column: $table.masteryLevel, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$WordVariantsTableTableAnnotationComposer get variantId {
    final $$WordVariantsTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.variantId,
            referencedTable: $db.wordVariantsTable,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$WordVariantsTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.wordVariantsTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$VariantProgressTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $VariantProgressTableTable,
    VariantProgressTableData,
    $$VariantProgressTableTableFilterComposer,
    $$VariantProgressTableTableOrderingComposer,
    $$VariantProgressTableTableAnnotationComposer,
    $$VariantProgressTableTableCreateCompanionBuilder,
    $$VariantProgressTableTableUpdateCompanionBuilder,
    (VariantProgressTableData, $$VariantProgressTableTableReferences),
    VariantProgressTableData,
    PrefetchHooks Function({bool variantId})> {
  $$VariantProgressTableTableTableManager(
      _$AppDatabase db, $VariantProgressTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VariantProgressTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VariantProgressTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VariantProgressTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> variantId = const Value.absent(),
            Value<String> direction = const Value.absent(),
            Value<double> stability = const Value.absent(),
            Value<double> difficulty = const Value.absent(),
            Value<int> elapsedDays = const Value.absent(),
            Value<int> scheduledDays = const Value.absent(),
            Value<int> reps = const Value.absent(),
            Value<int> lapses = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<DateTime?> lastReview = const Value.absent(),
            Value<DateTime?> nextReview = const Value.absent(),
            Value<int> timesShown = const Value.absent(),
            Value<int> timesCorrect = const Value.absent(),
            Value<double> masteryLevel = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              VariantProgressTableCompanion(
            id: id,
            userId: userId,
            variantId: variantId,
            direction: direction,
            stability: stability,
            difficulty: difficulty,
            elapsedDays: elapsedDays,
            scheduledDays: scheduledDays,
            reps: reps,
            lapses: lapses,
            state: state,
            lastReview: lastReview,
            nextReview: nextReview,
            timesShown: timesShown,
            timesCorrect: timesCorrect,
            masteryLevel: masteryLevel,
            isSynced: isSynced,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String variantId,
            required String direction,
            Value<double> stability = const Value.absent(),
            Value<double> difficulty = const Value.absent(),
            Value<int> elapsedDays = const Value.absent(),
            Value<int> scheduledDays = const Value.absent(),
            Value<int> reps = const Value.absent(),
            Value<int> lapses = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<DateTime?> lastReview = const Value.absent(),
            Value<DateTime?> nextReview = const Value.absent(),
            Value<int> timesShown = const Value.absent(),
            Value<int> timesCorrect = const Value.absent(),
            Value<double> masteryLevel = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              VariantProgressTableCompanion.insert(
            id: id,
            userId: userId,
            variantId: variantId,
            direction: direction,
            stability: stability,
            difficulty: difficulty,
            elapsedDays: elapsedDays,
            scheduledDays: scheduledDays,
            reps: reps,
            lapses: lapses,
            state: state,
            lastReview: lastReview,
            nextReview: nextReview,
            timesShown: timesShown,
            timesCorrect: timesCorrect,
            masteryLevel: masteryLevel,
            isSynced: isSynced,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$VariantProgressTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({variantId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (variantId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.variantId,
                    referencedTable: $$VariantProgressTableTableReferences
                        ._variantIdTable(db),
                    referencedColumn: $$VariantProgressTableTableReferences
                        ._variantIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$VariantProgressTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $VariantProgressTableTable,
        VariantProgressTableData,
        $$VariantProgressTableTableFilterComposer,
        $$VariantProgressTableTableOrderingComposer,
        $$VariantProgressTableTableAnnotationComposer,
        $$VariantProgressTableTableCreateCompanionBuilder,
        $$VariantProgressTableTableUpdateCompanionBuilder,
        (VariantProgressTableData, $$VariantProgressTableTableReferences),
        VariantProgressTableData,
        PrefetchHooks Function({bool variantId})>;
typedef $$SyncQueueTableTableCreateCompanionBuilder = SyncQueueTableCompanion
    Function({
  Value<int> id,
  required String tableName_,
  required String rowId,
  required String operation,
  required String payload,
  Value<int> retryCount,
  required DateTime createdAt,
});
typedef $$SyncQueueTableTableUpdateCompanionBuilder = SyncQueueTableCompanion
    Function({
  Value<int> id,
  Value<String> tableName_,
  Value<String> rowId,
  Value<String> operation,
  Value<String> payload,
  Value<int> retryCount,
  Value<DateTime> createdAt,
});

class $$SyncQueueTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tableName_ => $composableBuilder(
      column: $table.tableName_, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rowId => $composableBuilder(
      column: $table.rowId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SyncQueueTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tableName_ => $composableBuilder(
      column: $table.tableName_, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rowId => $composableBuilder(
      column: $table.rowId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncQueueTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tableName_ => $composableBuilder(
      column: $table.tableName_, builder: (column) => column);

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncQueueTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncQueueTableTable,
    SyncQueueTableData,
    $$SyncQueueTableTableFilterComposer,
    $$SyncQueueTableTableOrderingComposer,
    $$SyncQueueTableTableAnnotationComposer,
    $$SyncQueueTableTableCreateCompanionBuilder,
    $$SyncQueueTableTableUpdateCompanionBuilder,
    (
      SyncQueueTableData,
      BaseReferences<_$AppDatabase, $SyncQueueTableTable, SyncQueueTableData>
    ),
    SyncQueueTableData,
    PrefetchHooks Function()> {
  $$SyncQueueTableTableTableManager(
      _$AppDatabase db, $SyncQueueTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> tableName_ = const Value.absent(),
            Value<String> rowId = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SyncQueueTableCompanion(
            id: id,
            tableName_: tableName_,
            rowId: rowId,
            operation: operation,
            payload: payload,
            retryCount: retryCount,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String tableName_,
            required String rowId,
            required String operation,
            required String payload,
            Value<int> retryCount = const Value.absent(),
            required DateTime createdAt,
          }) =>
              SyncQueueTableCompanion.insert(
            id: id,
            tableName_: tableName_,
            rowId: rowId,
            operation: operation,
            payload: payload,
            retryCount: retryCount,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncQueueTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncQueueTableTable,
    SyncQueueTableData,
    $$SyncQueueTableTableFilterComposer,
    $$SyncQueueTableTableOrderingComposer,
    $$SyncQueueTableTableAnnotationComposer,
    $$SyncQueueTableTableCreateCompanionBuilder,
    $$SyncQueueTableTableUpdateCompanionBuilder,
    (
      SyncQueueTableData,
      BaseReferences<_$AppDatabase, $SyncQueueTableTable, SyncQueueTableData>
    ),
    SyncQueueTableData,
    PrefetchHooks Function()>;
typedef $$QuizSessionsTableTableCreateCompanionBuilder
    = QuizSessionsTableCompanion Function({
  required String id,
  required String userId,
  Value<String?> listId,
  required String listName,
  required String mode,
  required String direction,
  required int cardCount,
  required int correctCount,
  required int durationSeconds,
  required int masteredWordCount,
  required DateTime completedAt,
  Value<int> rowid,
});
typedef $$QuizSessionsTableTableUpdateCompanionBuilder
    = QuizSessionsTableCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String?> listId,
  Value<String> listName,
  Value<String> mode,
  Value<String> direction,
  Value<int> cardCount,
  Value<int> correctCount,
  Value<int> durationSeconds,
  Value<int> masteredWordCount,
  Value<DateTime> completedAt,
  Value<int> rowid,
});

class $$QuizSessionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $QuizSessionsTableTable> {
  $$QuizSessionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get listId => $composableBuilder(
      column: $table.listId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get listName => $composableBuilder(
      column: $table.listName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cardCount => $composableBuilder(
      column: $table.cardCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get correctCount => $composableBuilder(
      column: $table.correctCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get masteredWordCount => $composableBuilder(
      column: $table.masteredWordCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));
}

class $$QuizSessionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $QuizSessionsTableTable> {
  $$QuizSessionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get listId => $composableBuilder(
      column: $table.listId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get listName => $composableBuilder(
      column: $table.listName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cardCount => $composableBuilder(
      column: $table.cardCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get correctCount => $composableBuilder(
      column: $table.correctCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get masteredWordCount => $composableBuilder(
      column: $table.masteredWordCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));
}

class $$QuizSessionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuizSessionsTableTable> {
  $$QuizSessionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get listName =>
      $composableBuilder(column: $table.listName, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get cardCount =>
      $composableBuilder(column: $table.cardCount, builder: (column) => column);

  GeneratedColumn<int> get correctCount => $composableBuilder(
      column: $table.correctCount, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<int> get masteredWordCount => $composableBuilder(
      column: $table.masteredWordCount, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);
}

class $$QuizSessionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $QuizSessionsTableTable,
    QuizSessionsTableData,
    $$QuizSessionsTableTableFilterComposer,
    $$QuizSessionsTableTableOrderingComposer,
    $$QuizSessionsTableTableAnnotationComposer,
    $$QuizSessionsTableTableCreateCompanionBuilder,
    $$QuizSessionsTableTableUpdateCompanionBuilder,
    (
      QuizSessionsTableData,
      BaseReferences<_$AppDatabase, $QuizSessionsTableTable,
          QuizSessionsTableData>
    ),
    QuizSessionsTableData,
    PrefetchHooks Function()> {
  $$QuizSessionsTableTableTableManager(
      _$AppDatabase db, $QuizSessionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuizSessionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuizSessionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuizSessionsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String?> listId = const Value.absent(),
            Value<String> listName = const Value.absent(),
            Value<String> mode = const Value.absent(),
            Value<String> direction = const Value.absent(),
            Value<int> cardCount = const Value.absent(),
            Value<int> correctCount = const Value.absent(),
            Value<int> durationSeconds = const Value.absent(),
            Value<int> masteredWordCount = const Value.absent(),
            Value<DateTime> completedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              QuizSessionsTableCompanion(
            id: id,
            userId: userId,
            listId: listId,
            listName: listName,
            mode: mode,
            direction: direction,
            cardCount: cardCount,
            correctCount: correctCount,
            durationSeconds: durationSeconds,
            masteredWordCount: masteredWordCount,
            completedAt: completedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            Value<String?> listId = const Value.absent(),
            required String listName,
            required String mode,
            required String direction,
            required int cardCount,
            required int correctCount,
            required int durationSeconds,
            required int masteredWordCount,
            required DateTime completedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              QuizSessionsTableCompanion.insert(
            id: id,
            userId: userId,
            listId: listId,
            listName: listName,
            mode: mode,
            direction: direction,
            cardCount: cardCount,
            correctCount: correctCount,
            durationSeconds: durationSeconds,
            masteredWordCount: masteredWordCount,
            completedAt: completedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$QuizSessionsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $QuizSessionsTableTable,
    QuizSessionsTableData,
    $$QuizSessionsTableTableFilterComposer,
    $$QuizSessionsTableTableOrderingComposer,
    $$QuizSessionsTableTableAnnotationComposer,
    $$QuizSessionsTableTableCreateCompanionBuilder,
    $$QuizSessionsTableTableUpdateCompanionBuilder,
    (
      QuizSessionsTableData,
      BaseReferences<_$AppDatabase, $QuizSessionsTableTable,
          QuizSessionsTableData>
    ),
    QuizSessionsTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VocabularyListsTableTableTableManager get vocabularyListsTable =>
      $$VocabularyListsTableTableTableManager(_db, _db.vocabularyListsTable);
  $$ConceptsTableTableTableManager get conceptsTable =>
      $$ConceptsTableTableTableManager(_db, _db.conceptsTable);
  $$WordVariantsTableTableTableManager get wordVariantsTable =>
      $$WordVariantsTableTableTableManager(_db, _db.wordVariantsTable);
  $$VariantProgressTableTableTableManager get variantProgressTable =>
      $$VariantProgressTableTableTableManager(_db, _db.variantProgressTable);
  $$SyncQueueTableTableTableManager get syncQueueTable =>
      $$SyncQueueTableTableTableManager(_db, _db.syncQueueTable);
  $$QuizSessionsTableTableTableManager get quizSessionsTable =>
      $$QuizSessionsTableTableTableManager(_db, _db.quizSessionsTable);
}
