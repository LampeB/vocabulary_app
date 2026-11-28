import 'dart:convert' show jsonEncode;

import '../datasources/local/app_database.dart';
import '../datasources/local/daos/vocabulary_list_dao.dart';
import '../datasources/remote/vocabulary_remote_datasource.dart';
import '../models/vocabulary_list_dto.dart';
import '../../core/errors/failure.dart';
import '../../domain/entities/vocabulary_list.dart';

/// Before SQLite 11 both publication and import put a token on a private row.
/// SQLite 11 moved both to provenance and the server had the same heuristic.
/// Neither location establishes the token's meaning on a legacy row.
class LegacyShareReconciliation {
  LegacyShareReconciliation(this._db);

  final AppDatabase _db;
  VocabularyListDao get _lists => _db.vocabularyListDao;

  /// Protect a deliberate publication, visibility change or deletion while the
  /// earlier token's meaning is unknown. Call in the local edit transaction.
  Future<void> beforeSharingEdit(VocabularyListsTableData row) async {
    await _lists.captureLegacyListBase(row);
    final held = await _lists.getLegacyShare(row.id);
    if (held == null) return;
    await _lists.rememberLegacyShare(row.id, (token: held.token, edited: true));
  }

  bool confirmsPublication(
    VocabularyListsTableData row,
    LegacyShare pending,
    VocabularyList source,
    String wireId,
  ) =>
      source.ownerId == row.ownerId &&
      source.id == wireId &&
      _isLiveSource(source, pending.token);

  bool _isLiveSource(VocabularyList source, String token) =>
      !source.isDeleted &&
      source.visibility == ListVisibility.public &&
      source.shareToken == token;

  Future<Result<bool>> reconcileByToken(
    VocabularyListsTableData row,
    LegacyShare pending,
    String wireId,
    VocabularyRemoteDataSource remote, {
    Map<String, dynamic>? publicMetadata,
  }) async {
    if (publicMetadata == null) {
      final result = await remote.fetchPublicShareMetadata(pending.token);
      if (result case Failure(:final exception)) return Failure(exception);
      publicMetadata = result.valueOrNull;
    }
    if (publicMetadata == null ||
        publicMetadata['owner_id'] is! String ||
        publicMetadata['id'] is! String ||
        publicMetadata['visibility'] != 'public' ||
        publicMetadata['share_token'] != pending.token ||
        publicMetadata['is_deleted'] == true) {
      return const Success(false);
    }
    final source = publicMetadata.toVocabularyListDomain();
    final published = confirmsPublication(row, pending, source, wireId);
    VocabularyList? canonical = source;
    if (!published) {
      final result = await remote.fetchOwnedListMetadata(row.ownerId, wireId);
      if (result case Failure(:final exception)) return Failure(exception);
      canonical = result.valueOrNull?.toVocabularyListDomain();
      if (canonical != null &&
          (canonical.ownerId != row.ownerId ||
              canonical.id != wireId ||
              canonical.isDeleted ||
              canonical.shareToken == pending.token)) {
        return const Success(false);
      }
    }
    return Success(
      await applyEvidence(row, pending, canonical, imported: !published),
    );
  }

  /// Compare both the row and the hold before adopting network evidence.
  /// Keep a patch base so unrelated edits cannot re-publish a link which has
  /// been revoked elsewhere since the read.
  Future<bool> applyEvidence(
    VocabularyListsTableData row,
    LegacyShare pending,
    VocabularyList? canonical, {
    required bool imported,
  }) => _db.transaction(() async {
    if (await _lists.getById(row.id) != row ||
        await _lists.getLegacyShare(row.id) != pending) {
      return false;
    }

    final local = row.toDomain();
    final server = canonical?.copyWith(id: row.id);
    final beforeEdit = (await _lists.captureLegacyListBase(
      row,
    ))!.toDomain().toRemoteMap();
    final localFields = local.toRemoteMap();
    final authored = vocabularyMetadataEdits(beforeEdit, localFields);
    if (authored.containsKey('visibility') &&
        local.visibility != ListVisibility.public &&
        local.shareToken == null) {
      // Restricting visibility with no local token also revokes a historical
      // token which was hidden in the local hold when the edit was made.
      authored['share_token'] = null;
    }
    final provenance = imported ? pending.token : local.importedFromShareToken;
    final serverProvenance = server?.importedFromShareToken;
    // A distinct historical token on the server can still be ambiguous even
    // after publication has been confirmed for the local candidate.
    final remainingToken =
        !imported &&
            serverProvenance != pending.token &&
            serverProvenance != provenance
        ? serverProvenance
        : null;
    final rebase = await _lists.retainLegacyMetadata(
      row.id,
      server?.toRemoteMap() ?? beforeEdit,
      localFields,
      edited: authored.keys,
      canonicalExists: server != null,
    );
    final restored = {
      ...rebase,
      ...authored,
      'imported_from_share_token': provenance,
    }.toVocabularyListDomain();
    final needsUpload =
        !row.isSynced ||
        server == null ||
        authored.isNotEmpty ||
        (remainingToken == null && provenance != serverProvenance);
    if (needsUpload) {
      await _lists.upsert(rebase.toVocabularyListDomain().toLocalCompanion());
      await _lists.rememberSharedImport(
        row.id,
        (await _lists.getById(row.id))!,
      );
    } else {
      await _lists.forgetSharedImportBases([row.id]);
    }
    await _lists.upsert(
      restored.copyWith(isSynced: !needsUpload).toLocalCompanion(),
    );
    if (remainingToken == null) {
      await _lists.forgetLegacyShare(row.id);
    } else {
      await _lists.rememberLegacyShare(row.id, (
        token: remainingToken,
        edited: true,
      ));
    }
    return true;
  });
}

Map<String, dynamic> vocabularyMetadataEdits(
  Map<String, dynamic> base,
  Map<String, dynamic> edited,
) {
  const identity = {
    'id',
    'owner_id',
    'list_id',
    'concept_id',
    'created_at',
    'updated_at',
  };
  final changes = {
    for (final entry in edited.entries)
      if (!identity.contains(entry.key) &&
          jsonEncode(base[entry.key]) != jsonEncode(entry.value))
        entry.key: entry.value,
  };
  if (changes.isNotEmpty) changes['updated_at'] = edited['updated_at'];
  return changes;
}
