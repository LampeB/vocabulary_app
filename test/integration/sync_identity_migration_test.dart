import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/datasources/remote/vocabulary_remote_datasource.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/data/sync/push_sync.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';

import '../helpers/fake_remote.dart';

const _owner = 'owner';
const _time = '2025-01-01T00:00:00.000Z';
const _localAlias = '00000000-0000-4000-8000-000000000001';
const _modernWire = '00000000-0000-5000-8000-000000000002';

Map<String, dynamic> _list(
  String id, {
  String owner = _owner,
  String? token,
  String? provenance,
  String? name,
  String visibility = 'private',
}) => {
  'id': id,
  'owner_id': owner,
  'name': name ?? id,
  'visibility': visibility,
  'word_count': 1,
  'share_token': token,
  'imported_from_share_token': provenance,
  'created_at': _time,
  'updated_at': _time,
};

class _Remote extends FakeRemote {
  final lists = <String, Map<String, dynamic>>{};
  final public = <String, Map<String, dynamic>>{};
  final patches = <(String, Map<String, dynamic>?)>[];
  final reviews = <String>[];
  bool shareLookupOffline = false;
  Future<void> Function(String token)? beforePublicResponse;
  Future<void> Function()? beforeListsResponse;

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchLists(
    String ownerId, {
    VocabularyNetworkBudget? budget,
  }) async {
    final snapshot = lists.values
        .where((row) => row['owner_id'] == ownerId)
        .toList();
    await beforeListsResponse?.call();
    return Success(snapshot);
  }

  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(
    String token,
  ) async {
    final source = public[token];
    await beforePublicResponse?.call(token);
    return shareLookupOffline
        ? const Failure(NetworkException('offline'))
        : Success(source);
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertList(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async {
    final id = data['id'] as String;
    patches.add((id, insertOnly ? changes : null));
    final existing = lists[id];
    final row = insertOnly && existing != null
        ? {...existing, ...?changes}
        : {...?existing, ...data};
    lists[id] = row;
    return Success(row);
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertProgress(
    Map<String, dynamic> data,
  ) async {
    reviews.add(data['id'] as String);
    return Success(data);
  }
}

VocabularyRepositoryImpl _repo(AppDatabase db, _Remote remote) =>
    VocabularyRepositoryImpl(
      db.vocabularyListDao,
      db.conceptDao,
      remote,
      _owner,
      db,
    );

PushSync _push(AppDatabase db, _Remote remote) => PushSync(
  db.vocabularyListDao,
  db.conceptDao,
  db.progressDao,
  db.reviewEventDao,
  remote,
  userId: _owner,
);

// Frozen Drift v2 tables from the integration base. Its two sharing paths set
// identical private/local metadata and only its publication path wrote public
// visibility to the server. The quiz table is untouched by all later migrations.
AppDatabase _version2() => AppDatabase.forTesting(
  NativeDatabase.memory(
    setup: (sqlite) {
      sqlite.execute('''
      CREATE TABLE vocabulary_lists (
        id TEXT NOT NULL PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
        description TEXT, visibility TEXT NOT NULL DEFAULT 'private',
        word_count INTEGER NOT NULL DEFAULT 0, share_token TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
      );
      CREATE TABLE concepts (
        id TEXT NOT NULL PRIMARY KEY, list_id TEXT NOT NULL REFERENCES vocabulary_lists(id),
        category TEXT, notes TEXT, image_url TEXT, example_fr TEXT, example_ko TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
      );
      CREATE TABLE word_variants (
        id TEXT NOT NULL PRIMARY KEY, concept_id TEXT NOT NULL REFERENCES concepts(id),
        word TEXT NOT NULL, lang_code TEXT NOT NULL, register_tag TEXT NOT NULL DEFAULT 'neutral',
        context_tags TEXT NOT NULL DEFAULT '[]', is_primary INTEGER NOT NULL DEFAULT 0,
        audio_hash TEXT, audio_voice_id TEXT, position INTEGER NOT NULL DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
      );
      CREATE TABLE variant_progress (
        id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL,
        variant_id TEXT NOT NULL REFERENCES word_variants(id), direction TEXT NOT NULL,
        stability REAL NOT NULL DEFAULT 0, difficulty REAL NOT NULL DEFAULT 5,
        elapsed_days INTEGER NOT NULL DEFAULT 0, scheduled_days INTEGER NOT NULL DEFAULT 0,
        reps INTEGER NOT NULL DEFAULT 0, lapses INTEGER NOT NULL DEFAULT 0,
        state TEXT NOT NULL DEFAULT 'newCard', last_review INTEGER, next_review INTEGER,
        times_shown INTEGER NOT NULL DEFAULT 0, times_correct INTEGER NOT NULL DEFAULT 0,
        mastery_level REAL NOT NULL DEFAULT 0, is_synced INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
      );
      CREATE TABLE quiz_sessions (
        id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, list_id TEXT, list_name TEXT NOT NULL,
        mode TEXT NOT NULL, direction TEXT NOT NULL, card_count INTEGER NOT NULL,
        correct_count INTEGER NOT NULL, duration_seconds INTEGER NOT NULL,
        mastered_word_count INTEGER NOT NULL, completed_at INTEGER NOT NULL
      );
      CREATE TABLE sync_queue (id TEXT NOT NULL PRIMARY KEY);
      INSERT INTO vocabulary_lists(id, owner_id, name, visibility, share_token, is_synced, created_at, updated_at)
        VALUES ('own', 'owner', 'Own list', 'private', 'owned-link', 0, 1, 2),
               ('copy', 'owner', 'Imported copy', 'private', 'friend-link', 0, 1, 2),
               ('unknown', 'owner', 'Pending', 'private', 'unknown-link', 0, 1, 2),
               ('already-public', 'owner', 'Public', 'public', 'public-link', 1, 1, 2),
               ('friends', 'owner', 'Friends', 'friends', NULL, 1, 1, 2),
               ('different-account', 'other', 'Other', 'private', 'other-link', 0, 1, 2);
      INSERT INTO concepts(id, list_id, is_synced, created_at, updated_at)
        VALUES ('c-copy', 'copy', 1, 1, 2), ('c-unknown', 'unknown', 0, 1, 2),
               ('c-friends', 'friends', 1, 1, 2);
      INSERT INTO word_variants(id, concept_id, word, lang_code, is_synced, created_at, updated_at)
        VALUES ('card-copy', 'c-copy', '예', 'ko', 1, 1, 2),
               ('card-unknown', 'c-unknown', '예', 'ko', 0, 1, 2),
               ('card-friends', 'c-friends', '예', 'ko', 1, 1, 2);
      INSERT INTO variant_progress(id, user_id, variant_id, direction, reps, is_synced, created_at, updated_at)
        VALUES ('old-copy', 'owner', 'card-copy', 'frToKo', 4, 1, 1, 3),
               ('copy-review', 'owner', 'card-copy', 'fr>ko', 3, 0, 1, 2),
               ('unknown-review', 'owner', 'card-unknown', 'frToKo', 6, 0, 1, 2),
               ('friend-review', 'owner', 'card-friends', 'koToFr', 8, 0, 1, 2);
      PRAGMA user_version = 2;
    ''');
    },
  ),
);

void main() {
  test(
    'v2 recovers the own link, establishes the real copy and preserves FSRS identity',
    () async {
      final db = _version2();
      addTearDown(db.close);
      final dao = db.vocabularyListDao;
      final own = _list('own', token: 'owned-link', visibility: 'public');
      final remote = _Remote()
        ..lists.addAll({'own': own, 'copy': _list('copy')})
        ..public.addAll({
          'owned-link': own,
          // This can be a copy of a different list from the same account.
          'friend-link': _list(
            'source',
            token: 'friend-link',
            visibility: 'public',
          ),
        });

      expect((await dao.getById('own'))?.visibility, 'private');
      expect((await dao.getLegacyShare('own'))?.token, 'owned-link');
      expect((await dao.getById('copy'))?.importedFromShareToken, isNull);
      expect((await dao.getById('already-public'))?.shareToken, 'public-link');
      expect((await dao.getById('friends'))?.visibility, 'friends');

      final repo = _repo(db, remote);
      await repo.syncFromRemote();
      expect((await dao.getById('own'))?.visibility, 'public');
      expect((await dao.getById('own'))?.shareToken, 'owned-link');
      expect((await dao.getById('own'))?.importedFromShareToken, isNull);
      expect(await dao.getLegacyShare('own'), isNull);
      expect((await dao.getLegacyShare('copy'))?.token, 'friend-link');

      // Simulate another device revoking the link between pull and outbound ack.
      // The historical repair is allowed to sync a genuine rename but must not
      // re-publish the just-revoked link as a side effect.
      remote.lists['own'] = _list('own');
      await repo.renameList('own', 'Renamed on this device');
      await _push(db, remote).pushAll();
      expect(remote.lists['own']?['visibility'], 'private');
      expect(remote.lists['own']?['share_token'], isNull);
      expect(remote.lists['own']?['name'], 'Renamed on this device');
      expect(
        remote.patches.where((entry) => entry.$1 == 'own').single.$2,
        isNot(contains('visibility')),
      );

      final copy = await dao.getById('copy');
      expect(copy?.visibility, 'private');
      expect(copy?.shareToken, isNull);
      expect(copy?.importedFromShareToken, 'friend-link');
      expect(remote.lists['copy']?['imported_from_share_token'], 'friend-link');
      expect(
        (await repo.importFromShareToken('friend-link')).valueOrNull?.id,
        'copy',
      );
      expect((await dao.getLegacyShare('unknown'))?.token, 'unknown-link');
      expect(
        (await dao.getLegacyShare('different-account'))?.token,
        'other-link',
      );
      expect(remote.lists['unknown'], isNull);

      final progress = await db.select(db.variantProgressTable).get();
      expect(
        progress.map((row) => (row.id, row.variantId, row.direction, row.reps)),
        unorderedEquals([
          ('copy-review', 'card-copy', 'fr>ko', 3),
          ('unknown-review', 'card-unknown', 'fr>ko', 6),
          ('friend-review', 'card-friends', 'ko>fr', 8),
        ]),
      );
      expect(remote.reviews, unorderedEquals(['copy-review', 'friend-review']));
      await expectLater(
        db.customStatement(
          "INSERT INTO variant_progress(id,user_id,variant_id,direction,created_at,updated_at) VALUES('duplicate','owner','card-friends','ko>fr',1,3)",
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains('UNIQUE constraint failed'),
          ),
        ),
      );
    },
  );

  for (final version in [10, 11, 12]) {
    test(
      'v$version keeps ambiguous history and valid modern lineage on restart',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'ponderin-share-migration',
        );
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/history.sqlite');
        final earlier = AppDatabase.forTesting(NativeDatabase(file));
        // v13 changes no DDL. Reverse only the v11 and v12 DDL for earlier fixtures.
        await earlier.customStatement('''
        INSERT INTO vocabulary_lists(id,owner_id,name,share_token,imported_from_share_token,is_synced,created_at,updated_at)
        VALUES ('historical','owner','History',${version < 11 ? "'token',NULL" : "NULL,'token'"},1,1,2)
      ''');
        if (version >= 11) {
          await earlier.customStatement(
            '''
          INSERT INTO vocabulary_lists(id,owner_id,name,imported_from_share_token,is_synced,created_at,updated_at)
          VALUES (?, 'owner', 'Trusted import of own list', 'own-source', 0, 1, 2)
        ''',
            [version == 12 ? _localAlias : _modernWire],
          );
        }
        if (version == 12) {
          await earlier.customStatement(
            'INSERT INTO shared_import_bootstrap VALUES(?, ?)',
            [
              'vocabulary-wire-ids:owner',
              jsonEncode({
                'list': {_modernWire: _localAlias},
              }),
            ],
          );
        }
        if (version < 12) {
          await earlier.customStatement('DROP TABLE shared_import_bootstrap');
        }
        if (version < 11) {
          await earlier.customStatement(
            'ALTER TABLE vocabulary_lists DROP COLUMN imported_from_share_token',
          );
          await earlier.customStatement('DROP INDEX idx_progress_identity');
        }
        await earlier.customStatement('PRAGMA user_version = $version');
        await earlier.close();

        var db = AppDatabase.forTesting(NativeDatabase(file));
        expect(
          (await db.vocabularyListDao.getLegacyShare('historical'))?.token,
          'token',
        );
        expect(
          (await db.vocabularyListDao.getById('historical'))?.isSynced,
          isTrue,
        );
        expect(
          (await db.vocabularyListDao.getById(
            'historical',
          ))?.importedFromShareToken,
          isNull,
        );
        if (version >= 11) {
          expect(
            (await db.vocabularyListDao.getById(
              version == 12 ? _localAlias : _modernWire,
            ))?.importedFromShareToken,
            'own-source',
          );
        }
        await db.close();

        db = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(db.close);
        expect(
          (await db.vocabularyListDao.getLegacyShare('historical'))?.token,
          'token',
        );
        final remote = _Remote()
          ..lists['historical'] = _list('historical', provenance: 'token')
          ..shareLookupOffline = true;
        await _repo(db, remote).renameList('historical', 'Kept offline');
        await _push(db, remote).pushAll();
        expect(
          remote.patches.where((entry) => entry.$1 == 'historical'),
          isEmpty,
        );
        remote.shareLookupOffline = false;
        await _push(db, remote).pushAll();
        expect(
          remote.patches.where((entry) => entry.$1 == 'historical'),
          isEmpty,
        );
        expect(
          (await db.vocabularyListDao.getById('historical'))?.name,
          'Kept offline',
        );
        expect(
          (await db.vocabularyListDao.getLegacyShare('historical'))?.token,
          'token',
        );

        final public = _list(
          'historical',
          token: 'token',
          visibility: 'public',
        );
        remote.lists['historical'] = public;
        remote.public['token'] = public;
        await _push(db, remote).pushAll();
        final recovered = await db.vocabularyListDao.getById('historical');
        expect(recovered?.name, 'Kept offline');
        expect(recovered?.visibility, 'public');
        expect(recovered?.shareToken, 'token');
        expect(recovered?.importedFromShareToken, isNull);
        expect(await db.vocabularyListDao.getLegacyShare('historical'), isNull);
      },
    );
  }

  test(
    'metadata reads in flight preserve a concurrent explicit privacy edit',
    () async {
      final db = _version2();
      addTearDown(db.close);
      final entered = Completer<void>();
      final proceed = Completer<void>();
      final own = _list('own', token: 'owned-link', visibility: 'public');
      final remote = _Remote()
        ..lists['own'] = own
        ..public['owned-link'] = own
        ..beforePublicResponse = (token) async {
          if (token != 'owned-link' || entered.isCompleted) return;
          entered.complete();
          await proceed.future;
        };
      final repo = _repo(db, remote);
      final pushing = _push(db, remote).pushAll();
      await entered.future;
      final row = (await repo.getListById('own')).valueOrNull!;
      expect(
        (await repo.updateList(
          row.copyWith(
            visibility: ListVisibility.friends,
            name: 'Private to their friends',
          ),
        )).isSuccess,
        isTrue,
      );
      proceed.complete();
      await pushing;

      final saved = await db.vocabularyListDao.getById('own');
      expect(saved?.name, 'Private to their friends');
      expect(saved?.visibility, 'friends');
      expect(saved?.shareToken, isNull);
      expect(remote.lists['own']?['visibility'], 'friends');
      expect(remote.lists['own']?['share_token'], isNull);
      expect(saved?.importedFromShareToken, isNull);
    },
  );

  test(
    'a stale pull and a different token leave the old candidate intact',
    () async {
      final db = _version2();
      addTearDown(db.close);
      final entered = Completer<void>();
      final proceed = Completer<void>();
      final own = _list('own', token: 'owned-link', visibility: 'public');
      final remote = _Remote()
        ..lists['own'] = own
        ..beforeListsResponse = () async {
          if (entered.isCompleted) return;
          entered.complete();
          await proceed.future;
        };
      final repo = _repo(db, remote);
      final pulling = repo.syncFromRemote();
      await entered.future;
      await repo.renameList('own', 'Renamed during pull');
      proceed.complete();
      await pulling;

      final dao = db.vocabularyListDao;
      expect((await dao.getById('own'))?.name, 'Renamed during pull');
      expect((await dao.getLegacyShare('own'))?.token, 'owned-link');
      final replacement = _list(
        'own',
        token: 'different-token',
        visibility: 'public',
      );
      remote.lists['own'] = replacement;
      remote.public['owned-link'] = replacement;
      await _push(db, remote).pushAll();
      expect(remote.patches.where((entry) => entry.$1 == 'own'), isEmpty);
      expect((await dao.getLegacyShare('own'))?.token, 'owned-link');
      expect((await dao.getById('own'))?.visibility, 'private');
    },
  );

  test(
    'an explicit replacement can share an otherwise unresolved list',
    () async {
      final db = _version2();
      addTearDown(db.close);
      final remote = _Remote()
        ..lists['own'] = _list('own', provenance: 'owned-link')
        ..shareLookupOffline = true;
      final repo = _repo(db, remote);
      final link = (await repo.generateShareLink('own')).valueOrNull!;
      final activeToken = Uri.parse(link).queryParameters['token'];

      await _push(db, remote).pushList('own');
      final row = await db.vocabularyListDao.getById('own');
      expect(row?.isSynced, isTrue);
      expect(row?.shareToken, activeToken);
      expect(row?.importedFromShareToken, isNull);
      expect(remote.lists['own']?['visibility'], 'public');
      expect(remote.lists['own']?['share_token'], activeToken);
      expect(
        (await db.vocabularyListDao.getLegacyShare('own'))?.token,
        'owned-link',
      );
    },
  );

  test(
    'opening an own link resolves its separate historical copy first',
    () async {
      final db = _version2();
      addTearDown(db.close);
      final source = _list(
        'source',
        token: 'friend-link',
        visibility: 'public',
      );
      final remote = _Remote()
        ..lists['source'] = source
        ..lists['copy'] = _list('copy')
        ..public['friend-link'] = source;
      final repo = _repo(db, remote);
      await repo.syncFromRemote();
      expect(
        (await repo.getListById('source')).valueOrNull?.shareToken,
        'friend-link',
      );

      final imported = (await repo.importFromShareToken(
        'friend-link',
      )).valueOrNull;
      expect(imported?.id, 'copy');
      expect(imported?.importedFromShareToken, 'friend-link');
      expect(imported?.visibility, ListVisibility.private);
      expect(
        (await repo.getListById('source')).valueOrNull?.visibility,
        ListVisibility.public,
      );
    },
  );

  test(
    'a pending share edit cannot authorize a starter identity change',
    () async {
      final db = _version2();
      addTearDown(db.close);
      await db.customStatement(
        "UPDATE vocabulary_lists SET origin = 'starter', seed_id = 'starter:fr>ko' WHERE id = 'unknown'",
      );
      final remote = _Remote()
        ..lists['canonical-starter'] = {
          ..._list('canonical-starter'),
          'origin': 'starter',
          'seed_id': 'starter:fr>ko',
        };
      final repo = _repo(db, remote);
      expect((await repo.generateShareLink('unknown')).isSuccess, isTrue);
      await repo.syncFromRemote();

      final original = (await repo.getListById('unknown')).valueOrNull;
      expect(original?.id, 'unknown');
      expect(original?.shareToken, isNotNull);
      expect(
        (await db.vocabularyListDao.getLegacyShare('unknown'))?.token,
        'unknown-link',
      );
      expect(
        (await db.select(db.variantProgressTable).get()).any(
          (row) =>
              row.id == 'unknown-review' && row.variantId == 'card-unknown',
        ),
        isTrue,
      );
      expect(
        (await repo.getListById('canonical-starter')).valueOrNull?.visibility,
        ListVisibility.private,
      );
    },
  );
}
