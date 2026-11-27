# Comptes E2E permanents par scénario

Décision du 1 octobre 2026 : **chaque scénario possède son propre compte**,
réutilisé et remis dans un état connu avant chaque exécution. Le catalogue
[scenarios.json](../../tool/e2e/scenarios.json) contient 36 identifiants stables,
y compris les anciens tests. Aucun compte personnel ne doit être inscrit.

## Activation Supabase

1. Réactiver le projet si nécessaire. Appliquer les migrations manquantes dans
   l'ordre de [la CI PostgreSQL](../../.github/workflows/pr-validation.yml),
   jusqu'à [015](../../supabase/migrations/015_vocabulary_owner_namespace.sql).
   Patrol exige les gardes de [013](../../supabase/migrations/013_e2e_isolation.sql),
   les suppressions persistantes de [014](../../supabase/migrations/014_vocabulary_tombstones.sql)
   et les identifiants qualifiés par propriétaire de 015. La version actuelle de
   [007](../../supabase/migrations/007_audio_storage.sql) ferme les lectures
   client de `vocab-audio` jusqu'aux règles définitives de
   [012](../../supabase/migrations/012_security_boundaries.sql).
   Si le projet a appliqué une ancienne version de 007 et attend encore
   012, rejouer la version actuelle de 007 avant les autres étapes. Si la
   version actuelle de 012 est déjà appliquée, passer aux migrations manquantes.

   Si 008, 009 et 012 à 015 restent à appliquer et que les migrations 000,
   004 à 007, 010, 011 et `add_subscription_type.sql` sont déjà présentes,
   le générateur
   `python3 tool/e2e/build_activation.py > /tmp/activer-vocab-e2e.sql` regroupe
   008, 009 et 012 à 015 dans une transaction. Si le projet est déjà partiellement
   activé, appliquer uniquement les migrations manquantes.
2. Avant toute publication du secret CI, créer l'environnement GitHub Actions
   `patrol-e2e`. Dans *Deployment branches and tags*, sélectionner les branches
   et tags explicitement autorisés et ajouter uniquement la branche `main`.
   Depuis la racine du dépôt, avec `.env.json` configuré pour ce projet :

   ```bash
   python3 tool/e2e/provision.py --publish-github
   ```

   Saisir la clé Supabase `service_role` ou secret key dans l'invite masquée du
   terminal. Ne pas la coller dans un chat. Elle reste en mémoire et n'est
   transmise ni à GitHub ni à l'APK. L'option GitHub nécessite `gh auth login`
   et écrit le secret des comptes dans l'environnement `patrol-e2e`.
3. Sauvegarder **privément** `.e2e/accounts.json`. Ce fichier ignoré par Git
   conserve les mots de passe et UUID ; `test.accounts.env.json` est généré
   pour Patrol. Les fichiers sont écrits avec des permissions 0600 sur POSIX
   et une ACL réservée à l'utilisateur courant sur Windows.
4. Une fois les migrations appliquées, vérifier le schéma Patrol du projet
   qui correspond aux secrets CI avec le contrôle en lecture seule.

   ```bash
   python3 tool/e2e/check_activation.py --config .env.json
   ```

   Lorsque le contrôle réussit, définir la variable de dépôt GitHub
   `PATROL_E2E_ACTIVATION` à `owner-scoped-v1` pour autoriser le CI manuel et
   planifié. Une valeur absente ou différente garde le CI désactivé. Retirer
   la variable pour suspendre les lancements. Lancer ensuite une suite et
   vérifier son résultat réel.

L'outil crée les comptes via l'API administrateur, avec email confirmé et
métadonnées administrateur identifiant le scénario. Il les inscrit via une RPC
réservée au rôle serveur. Une relance reprend une création interrompue sans
changer les mots de passe ni recréer les identités. Un compte distant existant
sans sauvegarde locale ou une identité incohérente provoque un arrêt, sans
adoption ni suppression. Le fichier `.e2e/project.json` lie les données au projet.
Les adresses générées sont consultables dans le fichier privé ; rien à inventer
ou à saisir manuellement pour chaque test.

L'ancien compte partagé reste non attribué et ne peut plus appeler le reset.
Aucun compte existant n'est supprimé par cette migration.

## Isolation et état initial

Chaque `isolatedPatrolTest` reçoit un `scenarioId` explicite. La configuration
`TEST_ACCOUNTS_JSON` associe chaque ID à un UUID, email, mot de passe et pseudo.
Les UUID et emails doivent être distincts ; aucune entrée de secours partagée.
Avant `app.main()`, le helper :

1. vérifie le schéma Patrol hébergé en lecture seule, sélectionne le compte du
   scénario, se connecte et vérifie UUID et email ;
2. appelle `reset_e2e_account(p_scenario_id)` et vérifie identité, scénario,
   pseudo et baseline `empty-free-v1` ;
3. vide transactionnellement les tables SQLite et les préférences locales ;
4. démarre l'app, puis les étapes `given.*` construisent les préconditions.

Le serveur vérifie l'association compte/scénario sous verrou. La liste
`e2e_private.accounts` a RLS activée sans politique client et des droits retirés.
La fonction sans argument est privée ; le client ne peut cibler un autre UUID.
Une erreur annule le reset et fait échouer uniquement le scénario concerné.
Les autres suites continuent même après un échec. Les processus Android sont renouvelés par Test Orchestrator avec
`clearPackageData=true`. Le démarrage de l'application utilise l'initialisation
Supabase habituelle et chaque scénario se connecte avec son compte dédié.
Le helper Patrol refuse la définition `TEST_SESSION`.
La migration 012 étend le verrou transactionnel aux tables de relations et de
contenu avant le précontrôle : une écriture intercompte arrivant pendant le
reset attend sa fin au lieu d'être supprimée après un contrôle déjà passé.
La migration 013 refuse dès l'écriture les amitiés, demandes, défis et
progressions intercomptes impliquant un compte attribué à un scénario. Elle
contrôle aussi le propriétaire de la liste du défi ou de la variante étudiée.
La progression d'un compte E2E sur ses propres listes reste autorisée.
La migration 015 publie `e2e_patrol_contract()`. Le prévol CI, le helper
Patrol et le reset exigent tous la valeur `owner-scoped-v1`. Elle confirme
les prérequis de 012, les déclencheurs d'isolation de 013, les gardes de
suppression de 014 et les clés qualifiées par propriétaire de 015. La réponse
booléenne de `e2e_isolation_ready()` sur un ancien projet 013 laisse le CI
fermé. Les migrations intermédiaires gardent le reset inaccessible aux rôles
client jusqu'à 015.

Le reset efface listes, concepts, variantes, progression, abonnements Supabase,
notifications et classement du compte. Il recrée son profil gratuit avec le
pseudo enregistré. Les historiques serveur optionnels sont également effacés.
Les amitiés, demandes, défis et progressions d'autres comptes sur ses listes
font **refuser** le reset : ne pas créer de fixtures partagées entre scénarios.
Les futurs tests sociaux devront disposer d'une stratégie dédiée documentée.

L'identité Auth est conservée. Le reset ne supprime pas les objets Storage ni
l'état des services externes. RevenueCat est désactivé en mode test et STT est
simulé. Toute nouvelle table synchronisée doit être intégrée au reset et à ses
tests. En `TEST_MODE`, la création de listes ne déclenche pas non plus le seeding
automatique : les fixtures restent seules responsables des listes présentes.
Le teardown reste au mieux ; il ne remplace jamais la préparation.

## Ajouter ou lancer un scénario

Ajouter un ID stable dans le test et dans le catalogue, puis relancer le script
de provisioning. Renommer une description ne change pas l'ID ni le compte.

```bash
patrol test --target patrol_test/quiz_test.dart \
  --dart-define-from-file=test.accounts.env.json -d <device-id>
```

La CI crée **neuf jobs indépendants**, un par suite, avec **trois jobs maximum
simultanément** (`max-parallel: 3`, `fail-fast: false`). GitHub démarre une suite
en attente dès qu'un créneau se libère. Chaque job possède son propre émulateur.
Une seule tentative est effectuée ; les jobs en échec peuvent être relancés
explicitement. Le timeout est de **3 minutes par scénario**, **35 minutes pour
la commande Patrol** (compilation comprise, arrêt forcé après 30 secondes de
grâce) et **40 minutes par job** (installation et émulateur compris).
Le choix manuel d'un fichier ne crée qu'un job E2E. Le catalogue des neuf suites
CI est dans `tool/e2e/matrix.py` ; ajouter toute nouvelle suite à cette liste.
Le verrou reste au niveau du workflow entier pour empêcher deux runs d'utiliser
simultanément le compte d'un même scénario.

La CI fixe `patrol_cli` à **4.4.0**, compatible avec `patrol` **4.6.1**.
Utiliser cette même version localement : `dart pub global activate patrol_cli 4.4.0`.
Une mise à jour du package Patrol doit réévaluer cette compatibilité.

Seuls les jobs issus de `main` utilisent l'environnement GitHub `patrol-e2e`.
`E2E_ACCOUNTS_JSON` appartient à cet environnement. `SUPABASE_URL` et
`SUPABASE_ANON_KEY` restent des secrets du dépôt pour la CI Android. Le
27 novembre, le secret historique a été transféré sous chiffrement scellé vers
la clé de cet environnement, puis sa copie dépôt a été retirée après vérification
de l'écriture. Les identifiants n'ont pas été affichés. La lecture effective du
secret depuis le runner intégré reste à confirmer après fusion et migrations.
Les anciens secrets `TEST_EMAIL`
et `TEST_PASSWORD` ne sont plus requis.
[Environnements GitHub Actions](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments).

Le premier job vérifie le contrat sur le projet ciblé avant de sélectionner
les suites. Le précontrôle de chaque suite valide ensuite le catalogue complet
sans modifier les comptes. Pour chaque job, le fichier de compilation contient
uniquement les comptes du fichier
Patrol ciblé. La cible manuelle `quiz_all_test.dart` reçoit les scénarios de ses
suites importées. Seul le scénario en cours réinitialise son compte.

Après activation, le dispatcher cible `main` chaque soir à 22 h 17 Asia/Seoul
(13 h 17 UTC). Le verrou `supabase-e2e-account` sérialise les
runs ; ne pas exécuter le même scénario localement pendant la CI. Un dispatcher
réussi ne prouve pas le succès du run « E2E (emulator) ».
Le trafic ne garantit pas contractuellement l'absence de pause Supabase.

## Vérification

- `python3 -m unittest discover -s tool/e2e -p 'test_*.py'` vérifie le catalogue,
  l'unicité, la reprise du provisioning sans rotation d'identité et le refus
  lorsque le contrôle hébergé est absent ou négatif.
- `flutter test test/unit/e2e_scenario_accounts_test.dart test/integration/e2e_reset_test.dart` :
  sélection, absence de compte partagé, reset local et rollback.
- Sur une base **jetable**, appliquer le bootstrap et les migrations dans
  l'ordre de [la CI PostgreSQL](../../.github/workflows/pr-validation.yml).
  Les tests de [reset](../../supabase/tests/reset_e2e_account.sql), de
  [liaison de compte](../../supabase/tests/e2e_scenario_accounts.sql) et
  d'[isolation en écriture](../../supabase/tests/e2e_isolation.sql) vérifient
  les permissions, le rollback, les refus et la préservation des autres comptes.
- Un passage Patrol réel reste nécessaire après activation de la base hébergée.
- `supabase/tests/reset_concurrency.sh`, sur un PostgreSQL jetable dont le nom
  se termine par `_test`, vérifie avec deux connexions qu'une demande d'amitié
  concurrente attend le verrou du reset puis est refusée par l'isolation E2E.

## Diagnostic vocal local

Les routes, liens et enregistreurs des laboratoires STT exigent un build debug
lancé avec `--dart-define=STT_DIAGNOSTICS=true`. Cette option active les WAV,
les transcriptions du corpus et le journal brut dans ce build.
Le récepteur de corpus debug exige la permission système `DUMP` détenue par
`adb shell`, refuse les applications ordinaires, et limite ses fichiers WAV
PCM16 mono 16 kHz de 30 secondes au répertoire externe `files/corpus/` du build.
Les règles Android du build debug excluent des sauvegardes système et des
transferts entre appareils le corpus interne `app_flutter/stt_corpus`, le
journal externe `files/stt_logs` et le corpus de rejeu externe `files/corpus`.
L'extraction manuelle reste disponible via `adb pull` pour les fichiers
externes et via `adb exec-out run-as` pour le corpus interne du build debug.
[Règles Android de sauvegarde et de transfert](https://developer.android.com/identity/data/autobackup).

```bash
pkg=com.vocabkr.vocab_kr.debug
mkdir -p tool/stt_corpus
extract_dir=$(mktemp -d tool/stt_corpus/extraction.XXXXXX)
adb pull "/sdcard/Android/data/$pkg/files/stt_logs" "$extract_dir/"
adb exec-out run-as "$pkg" tar -cf - app_flutter/stt_corpus > "$extract_dir/stt_corpus.tar"
```

Les jobs conservent pendant 7 jours les rapports Android HTML/XML/textuels,
même en cas d’échec. Les identifiants configurés et JWT sont masqués avant
upload ; les APK et fichiers de configuration ne sont pas inclus.
