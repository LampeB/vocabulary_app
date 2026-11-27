# Comptes E2E permanents par scénario

Décision du 1 octobre 2026 : **chaque scénario possède son propre compte**,
réutilisé et remis dans un état connu avant chaque exécution. Le catalogue
[scenarios.json](../../tool/e2e/scenarios.json) contient 36 identifiants stables,
y compris les anciens tests. Aucun compte personnel ne doit être inscrit.

## Activation Supabase

1. Réactiver le projet si nécessaire. Appliquer les migrations manquantes dans
   l'ordre de [la CI PostgreSQL](../../.github/workflows/pr-validation.yml),
   dont [012](../../supabase/migrations/012_security_boundaries.sql) et
   [013](../../supabase/migrations/013_e2e_isolation.sql). Si aucune migration
   E2E ou de sécurité n'a été appliquée et que les migrations 000, 004 à 007,
   010, 011 et `add_subscription_type.sql` sont déjà présentes, le générateur
   `python3 tool/e2e/build_activation.py > /tmp/activer-vocab-e2e.sql` regroupe
   008, 009, 012 et 013 dans une transaction. Si le projet est déjà partiellement
   activé, appliquer uniquement les migrations manquantes.
2. Depuis la racine du dépôt, avec `.env.json` configuré pour ce projet :

   ```bash
   python3 tool/e2e/provision.py --publish-github
   ```

   Saisir la clé Supabase `service_role` ou secret key dans l'invite masquée du
   terminal. Ne pas la coller dans un chat. Elle reste en mémoire et n'est
   transmise ni à GitHub ni à l'APK. L'option GitHub nécessite `gh auth login`.
3. Sauvegarder **privément** `.e2e/accounts.json`. Ce fichier ignoré par Git
   conserve les mots de passe et UUID ; `test.accounts.env.json` est généré
   pour Patrol. Les fichiers sont écrits avec des permissions 0600 sur POSIX
   et une ACL réservée à l'utilisateur courant sur Windows.
4. Lancer une suite locale ou le workflow E2E et vérifier son résultat réel.

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

1. sélectionne le compte du scénario, se connecte et vérifie UUID et email ;
2. appelle `reset_e2e_account(p_scenario_id)` et vérifie identité, scénario,
   pseudo et baseline `empty-free-v1` ;
3. vide transactionnellement les tables SQLite et les préférences locales ;
4. démarre l'app, puis les étapes `given.*` construisent les préconditions.

Le serveur vérifie l'association compte/scénario sous verrou. La liste
`e2e_private.accounts` a RLS activée sans politique client et des droits retirés.
La fonction sans argument est privée ; le client ne peut cibler un autre UUID.
Une erreur annule le reset et fait échouer uniquement le scénario concerné.
Les autres suites continuent même après un échec. Les processus Android sont renouvelés par Test Orchestrator avec
`clearPackageData=true`. `TEST_SESSION` est interdit.
La migration 012 étend le verrou transactionnel aux tables de relations et de
contenu avant le précontrôle : une écriture intercompte arrivant pendant le
reset attend sa fin au lieu d'être supprimée après un contrôle déjà passé.
La migration 013 refuse dès l'écriture les amitiés, demandes, défis et
progressions intercomptes impliquant un compte attribué à un scénario. Elle
contrôle aussi le propriétaire de la liste du défi ou de la variante étudiée.
La progression d'un compte E2E sur ses propres listes reste autorisée.

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

La CI utilise `SUPABASE_URL`, `SUPABASE_ANON_KEY` et `E2E_ACCOUNTS_JSON`.
Les anciens secrets `TEST_EMAIL` et `TEST_PASSWORD` ne sont plus utilisés.
Le précontrôle valide le catalogue complet sans modifier les comptes ; seul
le scénario sur le point de démarrer réinitialise son propre compte.

Le dispatcher cible `main` après intégration de cette branche, chaque soir à
22 h 17 Asia/Seoul (13 h 17 UTC). Le verrou `supabase-e2e-account` sérialise les
runs ; ne pas exécuter le même scénario localement pendant la CI. Un dispatcher
réussi ne prouve pas le succès du run « E2E (emulator) ».
Le trafic ne garantit pas contractuellement l'absence de pause Supabase.

## Vérification

- `python3 -m unittest discover -s tool/e2e -p 'test_*.py'` : catalogue,
  unicité et reprise du provisioning sans rotation d'identité.
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

Les jobs conservent pendant 7 jours les rapports Android HTML/XML/textuels,
même en cas d’échec. Les identifiants configurés et JWT sont masqués avant
upload ; les APK et fichiers de configuration ne sont pas inclus.
