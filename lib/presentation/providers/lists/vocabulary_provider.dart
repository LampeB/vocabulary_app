import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart' show Intl;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/datasources/local/daos/vocabulary_list_dao.dart';
import '../../../data/datasources/local/daos/concept_dao.dart';
import '../../../data/datasources/local/daos/progress_dao.dart';
import '../../../data/datasources/remote/vocab_assistant_datasource.dart';
import '../../../data/datasources/remote/vocabulary_remote_datasource.dart';
import '../../../data/repositories/vocabulary_repository_impl.dart';
import '../../../data/seed/starter_seeder.dart';
import '../../../data/sync/push_sync.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../../domain/entities/concept.dart';
import '../../../domain/entities/word_variant.dart';
import '../../../domain/repositories/vocabulary_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/app_exception.dart';
import '../auth/auth_provider.dart';
import '../settings/default_pair_provider.dart';
import '../purchases/purchase_provider.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final vocabularyListDaoProvider = Provider<VocabularyListDao>(
  (ref) => ref.watch(appDatabaseProvider).vocabularyListDao,
);

final conceptDaoProvider = Provider<ConceptDao>(
  (ref) => ref.watch(appDatabaseProvider).conceptDao,
);

final progressDaoProvider = Provider<ProgressDao>(
  (ref) => ref.watch(appDatabaseProvider).progressDao,
);

final vocabularyRemoteProvider = Provider<VocabularyRemoteDataSource>(
  (ref) => VocabularyRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  final userId =
      ref.watch(currentUserProvider.select((user) => user?.id)) ?? '';
  return VocabularyRepositoryImpl(
    ref.watch(vocabularyListDaoProvider),
    ref.watch(conceptDaoProvider),
    ref.watch(vocabularyRemoteProvider),
    userId,
    ref.watch(appDatabaseProvider),
  );
});

// Streams local DB — auto-updates whenever a list changes.
final myListsProvider = StreamProvider<List<VocabularyList>>((ref) {
  return ref.watch(vocabularyRepositoryProvider).watchMyLists();
});

// Streams metadata for an open list, including canonical sync corrections.
final listInfoProvider = StreamProvider.autoDispose
    .family<VocabularyList?, String>((ref, listId) {
      return ref.watch(vocabularyRepositoryProvider).watchListById(listId);
    });

// Streams concepts for a given list.
final listDetailProvider = StreamProvider.autoDispose
    .family<List<Concept>, String>((ref, listId) {
      return ref.watch(vocabularyRepositoryProvider).watchConcepts(listId);
    });

// Each mounted word observes its variants and releases the subscription on exit.
final variantsProvider = StreamProvider.autoDispose
    .family<List<WordVariant>, String>((ref, conceptId) {
      return ref.watch(vocabularyRepositoryProvider).watchVariants(conceptId);
    });

// Streams the number of cards due for review today.
final dueCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  if (userId.isEmpty) return Stream.value(0);
  return ref.watch(progressDaoProvider).watchDueCount(userId);
});

/// List IDs the user has started studying (≥1 reviewed card). Drives the
/// "currently studying" vs "not yet studied" split in the quiz setup screen.
/// A STREAM over the local DB so the split fills in live when the login sync
/// delivers progress rows on a fresh device (field report 2026-07-19).
final studiedListIdsProvider = StreamProvider<Set<String>>((ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  if (userId.isEmpty) return Stream.value(<String>{});
  return ref.watch(progressDaoProvider).watchStudiedListIds(userId);
});

/// Due-card count for one language pair (record: (langA, langB)) — feeds the
/// quiz setup's "to study now" badge so it reflects the chosen language, not
/// every language's due cards. Streamed for the same fresh-device reason.
final dueCountForPairProvider = StreamProvider.autoDispose
    .family<int, (String, String)>((ref, pair) {
      final userId =
          ref.watch(currentUserProvider.select((user) => user?.id)) ?? '';
      if (userId.isEmpty) return Stream.value(0);
      return ref
          .watch(progressDaoProvider)
          .watchDueCountForPair(userId, pair.$1, pair.$2);
    });

const _kTestMode = bool.fromEnvironment('TEST_MODE');

// Pulls the user's lists from Supabase into the local DB on login.
// Watchers (myListsProvider) update automatically when Drift rows change.
// Skipped in TEST_MODE — tests create their own isolated data and the sync
// can queue hundreds of Drift writes that block quiz card loading.
final syncOnLoginProvider = FutureProvider<void>((ref) async {
  if (_kTestMode) return;
  final userId = ref.watch(currentUserProvider.select((user) => user?.id));
  if (userId == null || userId.isEmpty) return;
  await ref.watch(vocabularyRepositoryProvider).syncFromRemote();
});

/// The pair-aware starter seeder (assets/seed/vocab/ catalog). Composed here
/// so both the login path and the create-list path share one instance.
final starterSeederProvider = Provider<StarterSeeder>(
  (ref) => StarterSeeder(
    bundle: rootBundle,
    repo: ref.watch(vocabularyRepositoryProvider),
    listDao: ref.watch(vocabularyListDaoProvider),
    conceptDao: ref.watch(conceptDaoProvider),
    userId: ref.watch(currentUserProvider.select((user) => user?.id)) ?? '',
    uiLocale: Intl.defaultLocale,
  ),
);

/// Seeds the starter curriculum for the user's current default pair. The
/// starter lists are also the grammar lessons' prerequisites, so every
/// studied pair must have them. Runs AFTER the pull sync so an existing
/// account's lists arrive first; StarterSeeder itself is idempotent (per-pair
/// flag, dedup by seed_id, per-concept top-up — see its doc comment) and
/// adopts/heals lists seeded by the old name-keyed fr→ko pipeline.
/// Re-runs whenever the default pair changes (ref.watch), and
/// ListActionsNotifier.createList seeds any new pair a list is created with.
/// Skipped in TEST_MODE — E2E owns its own data.
final seedStarterListsProvider = FutureProvider<void>((ref) async {
  if (_kTestMode) return;
  final userId = ref.watch(currentUserProvider.select((user) => user?.id));
  if (userId == null || userId.isEmpty) return;
  ref.watch(defaultPairProvider);
  final pairRestored = ref.read(defaultPairProvider.notifier).restored;
  final seeder = ref.watch(starterSeederProvider);
  var active = true;
  ref.onDispose(() => active = false);
  // A remote pull improves an existing account, but must not prevent a new
  // user (or an offline user) from receiving the bundled starter curriculum.
  try {
    await ref.watch(syncOnLoginProvider.future);
  } catch (_) {
    // The local database remains usable; a later reconnect retries the pull.
  }

  await pairRestored;
  if (!active) return;
  final pair = ref.read(defaultPairProvider);
  await seeder.ensureSeededForPair(pair.$1, pair.$2);
});

/// Outbound sync (the isSynced flags are the queue — see data/sync/push_sync).
final pushSyncProvider = Provider<PushSync>(
  (ref) => PushSync(
    ref.watch(vocabularyListDaoProvider),
    ref.watch(conceptDaoProvider),
    ref.watch(progressDaoProvider),
    ref.watch(appDatabaseProvider).reviewEventDao,
    ref.watch(vocabularyRemoteProvider),
    userId: ref.watch(currentUserProvider.select((user) => user?.id)) ?? '',
  ),
);

/// Committed local edits wake the scheduler. The sync flags are the durable queue.
final outboundMutationsProvider = StreamProvider<void>((ref) {
  final userId = ref.watch(currentUserProvider.select((user) => user?.id));
  if (userId == null) return const Stream.empty();
  return ref.watch(appDatabaseProvider).watchOutboundMutations(userId);
});

final listActionsProvider = NotifierProvider<ListActionsNotifier, void>(
  ListActionsNotifier.new,
);

class ListActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  VocabularyRepository get _repo => ref.read(vocabularyRepositoryProvider);

  Future<Result<VocabularyList>> createList(
    String name,
    String? description, {
    String langA = 'fr',
    String langB = 'ko',
  }) async {
    if (!ref.read(isPremiumProvider)) {
      // Only USER-created lists count against the free quota — seeded starter
      // lists and premium packs are exempt (product decision 2026-07-04).
      final count =
          ref
              .read(myListsProvider)
              .valueOrNull
              ?.where((l) => l.origin == 'user')
              .length ??
          0;
      if (count >= AppConfig.maxFreeVocabLists) {
        return const Failure(
          QuotaExceededException(
            'Free plan includes ${AppConfig.maxFreeVocabLists} lists. Upgrade to create more.',
          ),
        );
      }
    }
    final result = await _repo.createList(
      name: name,
      description: description,
      langA: langA,
      langB: langB,
    );
    if (result is Success<VocabularyList> && !_kTestMode) {
      // First list in a new pair → that pair's starter curriculum appears
      // alongside it (idempotent; no-op for already-seeded pairs). Fire and
      // forget: a failure here must not break list creation — the login-path
      // seeder retries on next app open (per-pair flag still unset).
      unawaited(
        Future(
          () =>
              ref.read(starterSeederProvider).ensureSeededForPair(langA, langB),
        ).catchError((Object e) => debugPrint('pair seeding failed: $e')),
      );
    }
    return result;
  }

  Future<Result<VocabularyList>> renameList(String listId, String newName) =>
      _repo.renameList(listId, newName);

  Future<Result<void>> deleteList(String listId) => _repo.deleteList(listId);

  Future<List<WordPairSuggestion>> getSuggestionContext(String listId) async {
    final list = (await _repo.getListById(listId)).valueOrNull;
    if (list == null) return const [];
    final sample = await _repo.getWordPairSample(
      listId,
      limit: VocabAssistantDataSource.maxContextItems,
    );
    return VocabAssistantDataSource.boundSuggestionContext(
      sourceLang: list.langA,
      targetLang: list.langB,
      pairs: sample.map(
        (pair) => WordPairSuggestion(source: pair.source, target: pair.target),
      ),
    );
  }

  Future<Result<Concept>> addConcept({
    required String listId,
    required String wordA,
    required String wordB,
    (String, String)? expectedPair,
    String? notes,
    String? category,
  }) async {
    final repo = _repo;
    final Result<VocabularyList> listResult;
    try {
      listResult = await repo.getListById(listId);
    } catch (error) {
      return Failure(StorageException(error.toString()));
    }
    if (!identical(repo, _repo)) return const Failure(PermissionException());
    if (listResult case Failure(:final exception)) return Failure(exception);
    final list = listResult.valueOrNull!;
    final pair = (list.langA, list.langB);
    if (expectedPair != null && expectedPair != pair) {
      return const Failure(ValidationException('List language pair changed'));
    }
    if (!ref.read(isPremiumProvider) &&
        list.wordCount >= AppConfig.maxFreeWordsPerList) {
      return const Failure(
        QuotaExceededException(
          'Free plan includes ${AppConfig.maxFreeWordsPerList} words per list. Upgrade for unlimited words.',
        ),
      );
    }
    return repo.addConceptWithVariants(
      listId: listId,
      wordA: wordA,
      wordB: wordB,
      langA: pair.$1,
      langB: pair.$2,
      notes: notes,
      category: category,
    );
  }

  Future<Result<void>> deleteConcept(String conceptId) =>
      _repo.deleteConcept(conceptId);

  Future<Result<void>> updateVariants({
    required String listId,
    required WordVariant variantA,
    required WordVariant variantB,
    required String wordA,
    required String wordB,
  }) => _repo.updateWordPair(
    listId: listId,
    variantA: variantA,
    variantB: variantB,
    wordA: wordA,
    wordB: wordB,
  );

  // Returns an error message on failure, null on success.
  Future<String?> exportList(String listId, String listName) async {
    final result = await _repo.exportToJson(listId);
    if (result.isFailure) {
      return result.exceptionOrNull?.message ?? 'Export failed';
    }
    try {
      final jsonStr = jsonEncode(result.valueOrNull!);
      final dir = await getTemporaryDirectory();
      final safeName = listName.replaceAll(RegExp(r'[^\w ]'), '_').trim();
      final file = File('${dir.path}/${safeName}_vocabkr.json');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/json'),
      ], subject: '$listName — Ponderin Export');
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Returns null if the user cancelled, Result<VocabularyList> otherwise.
  Future<Result<VocabularyList>?> importList() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null || picked.files.isEmpty) return null;

    final path = picked.files.single.path;
    if (path == null) {
      return const Failure(StorageException('No file path available'));
    }

    try {
      final content = await File(path).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return _repo.importFromJson(json);
    } catch (_) {
      return const Failure(StorageException('Invalid JSON file'));
    }
  }

  // Generates a share token, saves it, and opens the native share sheet.
  Future<Result<String>> generateAndShareLink(
    String listId,
    String listName,
  ) async {
    final result = await _repo.generateShareLink(listId);
    if (result.isFailure) return result;
    final canonical = (await _repo.getListById(listId)).valueOrNull;
    if (canonical == null) {
      return const Failure(NotFoundException('List not found'));
    }
    // Wait for this list and its content to become remotely visible.
    await ref.read(pushSyncProvider).pushList(canonical.id);
    final dao = ref.read(vocabularyListDaoProvider);
    final list = await dao.getById(canonical.id);
    final token = Uri.parse(result.valueOrNull!).queryParameters['token'];
    if (list == null ||
        list.isDeleted ||
        !list.isSynced ||
        list.shareToken != token ||
        list.visibility != 'public' ||
        await dao.hasPendingContents(canonical.id)) {
      return const Failure(
        NetworkException(
          'The list must finish syncing before its link can be shared.',
        ),
      );
    }
    await Share.share(result.valueOrNull!, subject: '$listName — Ponderin');
    return result;
  }

  // Imports a publicly shared list by its share token (from a deep link).
  Future<Result<VocabularyList>> importFromLink(String token) =>
      _repo.importFromShareToken(token);
}
