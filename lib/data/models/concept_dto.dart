import 'package:drift/drift.dart' show Value;

import '../datasources/local/app_database.dart';

extension ConceptSyncDto on ConceptsTableData {
  Map<String, dynamic> toRemoteMap() => {
        'id': id,
        'list_id': listId,
        'category': category,
        'notes': notes,
        'image_url': imageUrl,
        'example_fr': exampleFr,
        'example_ko': exampleKo,
        'seed_id': seedId,
        'is_deleted': isDeleted,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

ConceptsTableCompanion conceptCompanionFromRemote(Map<String, dynamic> row,
        {bool isSynced = true}) =>
    ConceptsTableCompanion(
      id: Value(row['id'] as String),
      listId: Value(row['list_id'] as String),
      category: Value(row['category'] as String?),
      notes: Value(row['notes'] as String?),
      imageUrl: Value(row['image_url'] as String?),
      exampleFr: Value(row['example_fr'] as String?),
      exampleKo: Value(row['example_ko'] as String?),
      seedId: Value(row['seed_id'] as String?),
      isDeleted: Value(row['is_deleted'] as bool? ?? false),
      isSynced: Value(isSynced),
      createdAt: Value(DateTime.parse(row['created_at'] as String)),
      updatedAt: Value(DateTime.parse(row['updated_at'] as String)),
    );
