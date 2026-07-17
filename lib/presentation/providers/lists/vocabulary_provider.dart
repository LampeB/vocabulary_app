import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/datasources/local/daos/vocabulary_list_dao.dart';
import '../../../data/datasources/local/daos/concept_dao.dart';
import '../../../data/datasources/local/daos/progress_dao.dart';
import '../../../data/datasources/remote/vocabulary_remote_datasource.dart';
import '../../../data/repositories/vocabulary_repository_impl.dart';
import '../../../data/sync/push_sync.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../../domain/entities/concept.dart';
import '../../../domain/entities/word_variant.dart';
import '../../../domain/repositories/vocabulary_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/app_exception.dart';
import '../auth/auth_provider.dart';
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
  final userId = ref.watch(currentUserProvider)?.id ?? '';
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

// Fetches metadata for a single list (for AppBar titles etc.).
final listInfoProvider =
    FutureProvider.family<VocabularyList?, String>((ref, listId) {
  return ref
      .watch(vocabularyRepositoryProvider)
      .getListById(listId)
      .then((r) => r.valueOrNull);
});

// Streams concepts for a given list.
final listDetailProvider =
    StreamProvider.family<List<Concept>, String>((ref, listId) {
  return ref.watch(vocabularyRepositoryProvider).watchConcepts(listId);
});

// Fetches variants for a concept (cached per conceptId).
final variantsProvider =
    FutureProvider.family<List<WordVariant>, String>((ref, conceptId) {
  return ref
      .watch(vocabularyRepositoryProvider)
      .getVariants(conceptId)
      .then((r) => r.valueOrNull ?? []);
});

// Streams the number of cards due for review today.
final dueCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  if (userId.isEmpty) return Stream.value(0);
  return ref.watch(progressDaoProvider).watchDueCount(userId);
});

/// List IDs the user has started studying (≥1 reviewed card). Drives the
/// "currently studying" vs "not yet studied" split in the quiz setup screen.
final studiedListIdsProvider = FutureProvider<Set<String>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  if (userId.isEmpty) return <String>{};
  return ref.watch(progressDaoProvider).getStudiedListIds(userId);
});

const _kTestMode = bool.fromEnvironment('TEST_MODE');

// Pulls the user's lists from Supabase into the local DB on login.
// Watchers (myListsProvider) update automatically when Drift rows change.
// Skipped in TEST_MODE — tests create their own isolated data and the sync
// can queue hundreds of Drift writes that block quiz card loading.
final syncOnLoginProvider = FutureProvider<void>((ref) async {
  if (_kTestMode) return;
  final user = ref.watch(currentUserProvider);
  if (user == null) return;
  await ref.watch(vocabularyRepositoryProvider).syncFromRemote();
});

/// Seeds the bundled starter lists (assets/seed/starter_lists.json — 6 themed
/// FR/KR lists that are also the grammar lessons' prerequisites). Runs AFTER
/// the pull sync so an existing account's lists arrive first, then seeds any
/// starter list the account is MISSING (matched by name — the canonical names
/// the grammar rules reference). Accounts created before the starter lists
/// shipped must still receive them, or grammar is permanently locked for
/// them; starter lists are quota-exempt, so topping up is always safe.
/// A per-user flag (v2: the v1 flag was set without seeding on pre-existing
/// accounts) makes it once-ever — deleting a starter list later does NOT
/// bring it back. Skipped in TEST_MODE — E2E owns its own data.
final seedStarterListsProvider = FutureProvider<void>((ref) async {
  if (_kTestMode) return;
  final user = ref.watch(currentUserProvider);
  if (user == null) return;
  await ref.watch(syncOnLoginProvider.future);

  final prefs = await SharedPreferences.getInstance();
  final flagKey = 'seeded_starter_lists_v2_${user.id}';
  if (prefs.getBool(flagKey) ?? false) return;

  final repo = ref.read(vocabularyRepositoryProvider);
  final existingNames =
      (await repo.watchMyLists().first).map((l) => l.name).toSet();
  final raw = await rootBundle.loadString('assets/seed/starter_lists.json');
  for (final entry in jsonDecode(raw) as List<dynamic>) {
    final map = entry as Map<String, dynamic>;
    final name = (map['list'] as Map<String, dynamic>)['name'] as String?;
    if (name != null && existingNames.contains(name)) continue;
    await repo.importFromJson(map, origin: 'starter');
  }
  await prefs.setBool(flagKey, true);
});

/// Outbound sync (the isSynced flags are the queue — see data/sync/push_sync).
final pushSyncProvider = Provider<PushSync>((ref) => PushSync(
      ref.watch(vocabularyListDaoProvider),
      ref.watch(conceptDaoProvider),
      ref.watch(progressDaoProvider),
      ref.watch(appDatabaseProvider).reviewEventDao,
      ref.watch(vocabularyRemoteProvider),
    ));

final listActionsProvider =
    NotifierProvider<ListActionsNotifier, void>(ListActionsNotifier.new);

class ListActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  VocabularyRepository get _repo => ref.read(vocabularyRepositoryProvider);

  Future<Result<VocabularyList>> createList(
      String name, String? description,
      {String langA = 'fr', String langB = 'ko'}) async {
    if (!ref.read(isPremiumProvider)) {
      // Only USER-created lists count against the free quota — seeded starter
      // lists and premium packs are exempt (product decision 2026-07-04).
      final count = ref
              .read(myListsProvider)
              .valueOrNull
              ?.where((l) => l.origin == 'user')
              .length ??
          0;
      if (count >= AppConfig.maxFreeVocabLists) {
        return const Failure(QuotaExceededException(
          'Free plan includes ${AppConfig.maxFreeVocabLists} lists. Upgrade to create more.',
        ));
      }
    }
    return _repo.createList(
        name: name, description: description, langA: langA, langB: langB);
  }

  Future<Result<VocabularyList>> renameList(
      String listId, String newName) async {
    final r = await _repo.getListById(listId);
    return r.fold(
      onSuccess: (list) => _repo.updateList(list.copyWith(name: newName)),
      onFailure: (e) async => Failure(e),
    );
  }

  Future<Result<void>> deleteList(String listId) =>
      _repo.deleteList(listId);

  Future<Result<Concept>> addConcept({
    required String listId,
    required String wordA,
    required String wordB,
    String? notes,
    String? category,
  }) async {
    // Fetch the list once: for the free-tier word quota AND to learn its
    // language pair, so the two variants get the right lang codes instead of
    // a hardcoded fr/ko (generic-language-pairs epic).
    final listResult = await _repo.getListById(listId);
    final list = switch (listResult) {
      Success(:final value) => value,
      _ => null,
    };
    if (!ref.read(isPremiumProvider) &&
        list != null &&
        list.wordCount >= AppConfig.maxFreeWordsPerList) {
      return const Failure(QuotaExceededException(
        'Free plan includes ${AppConfig.maxFreeWordsPerList} words per list. Upgrade for unlimited words.',
      ));
    }
    return _repo.addConceptWithVariants(
      listId: listId,
      wordA: wordA,
      wordB: wordB,
      langA: list?.langA ?? 'fr',
      langB: list?.langB ?? 'ko',
      notes: notes,
      category: category,
    );
  }

  Future<Result<void>> deleteConcept(String conceptId) =>
      _repo.deleteConcept(conceptId);

  Future<void> updateVariants({
    required WordVariant frVariant,
    required String newFrWord,
    required WordVariant koVariant,
    required String newKoWord,
  }) async {
    await _repo.updateVariant(frVariant.copyWith(word: newFrWord));
    await _repo.updateVariant(koVariant.copyWith(word: newKoWord));
    // variantsProvider is a cached FutureProvider, so the edited words won't
    // show until it's invalidated (otherwise the tile keeps the stale value).
    ref.invalidate(variantsProvider(frVariant.conceptId));
  }

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
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: '$listName — VocabKR Export',
      );
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
      String listId, String listName) async {
    final result = await _repo.generateShareLink(listId);
    if (result.isFailure) return result;
    await Share.share(result.valueOrNull!, subject: '$listName — VocabKR');
    return result;
  }

  // Imports a publicly shared list by its share token (from a deep link).
  Future<Result<VocabularyList>> importFromLink(String token) =>
      _repo.importFromShareToken(token);
}
