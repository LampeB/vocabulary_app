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
    final held = await _lists.getLegacyShare(row.id);
    if (held == null) return;
    if (await _lists.getSharedImportBase(row.id) == null) {
      await _lists.rememberSharedImport(row.id, row);
    }
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
    final preserveSharing =
        (pending.edited && !row.isSynced) || row.isDeleted || server == null;
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
    final restored = (row.isSynced && server != null ? server : local).copyWith(
      importedFromShareToken: provenance,
      shareToken: preserveSharing ? local.shareToken : server.shareToken,
      visibility: preserveSharing ? local.visibility : server.visibility,
    );
    final needsUpload =
        !row.isSynced ||
        server == null ||
        restored.shareToken != server.shareToken ||
        restored.visibility != server.visibility ||
        (remainingToken == null && provenance != serverProvenance);
    if (needsUpload) {
      final base = server ?? local;
      await _lists.upsert(base.toLocalCompanion());
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
