import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../datasources/local/app_database.dart';

class VocabularyWriteStamp {
  const VocabularyWriteStamp(this.writer, this.sequence);

  final String writer;
  final int sequence;

  static const _writerKey = '_sync_writer';
  static const _sequenceKey = '_sync_sequence';

  /// The caller holds the SQLite transaction that checked the sent snapshot.
  static Future<VocabularyWriteStamp> allocate(
    AppDatabase db,
    String userId,
  ) async {
    final key = 'vocabulary-write-order:$userId';
    final row = await (db.select(
      db.sharedImportBootstrapTable,
    )..where((t) => t.id.equals(key))).getSingleOrNull();
    final Map<String, dynamic> state = row == null
        ? {}
        : jsonDecode(row.snapshot);
    final writer = state['writer'] as String? ?? const Uuid().v4();
    final sequence = (state['sequence'] as int? ?? 0) + 1;
    // This private sequence does not invalidate the UI's alias queries.
    await db.customInsert(
      'INSERT INTO shared_import_bootstrap (id, snapshot) VALUES (?, ?) '
      'ON CONFLICT(id) DO UPDATE SET snapshot = excluded.snapshot',
      variables: [
        Variable(key),
        Variable(jsonEncode({'writer': writer, 'sequence': sequence})),
      ],
    );
    return VocabularyWriteStamp(writer, sequence);
  }

  Map<String, dynamic> apply(Map<String, dynamic> row) => {
    ...row,
    _writerKey: writer,
    _sequenceKey: sequence,
  };

  static (VocabularyWriteStamp, Map<String, dynamic>) take(
    Map<String, dynamic> data,
  ) {
    final payload = Map<String, dynamic>.of(data);
    final writer = payload.remove(_writerKey);
    final sequence = payload.remove(_sequenceKey);
    if (writer is! String || sequence is! int) {
      throw StateError('Vocabulary write is missing its SQLite sequence');
    }
    return (
      VocabularyWriteStamp(writer, sequence),
      {...payload, 'sync_write_protocol': 16},
    );
  }
}
