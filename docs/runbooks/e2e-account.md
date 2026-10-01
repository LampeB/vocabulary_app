# Comptes E2E permanents par scénario

Décision du 1 octobre 2026 : **chaque scénario possède son propre compte**,
réutilisé et remis dans un état connu avant chaque exécution. Le catalogue
[scenarios.json](../../tool/e2e/scenarios.json) contient 36 identifiants stables,
y compris les anciens tests. Aucun compte personnel ne doit être inscrit.

## Activation Supabase

1. Réactiver le projet si nécessaire. Appliquer dans le SQL Editor les migrations
   [008](../../supabase/migrations/008_e2e_reset.sql) puis
   [009](../../supabase/migrations/009_e2e_scenario_accounts.sql).
   Les migrations antérieures, dont `add_subscription_type.sql`, sont requises.
   Pour obtenir un seul script atomique prêt à coller :
   `python3 tool/e2e/build_activation.py > /tmp/activer-vocab-e2e.sql`.
2. Depuis la racine du dépôt, avec `.env.json` configuré pour ce projet :

   ```bash
   python3 tool/e2e/provision.py --publish-github
   ```

   Saisir la clé Supabase `service_role` ou secret key dans l'invite masquée du
   terminal. Ne pas la coller dans un chat. Elle reste en mémoire et n'est
   transmise ni à GitHub ni à l'APK. L'option GitHub nécessite `gh auth login`.
3. Sauvegarder **privément** `.e2e/accounts.json`. Ce fichier ignoré par Git
   conserve les mots de passe et UUID ; `test.accounts.env.json` est généré
   pour Patrol. Les fichiers sont écrits avec des permissions 0600.
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
Les suites suivantes restent exécutées même après les retries d'une suite en
échec. Les processus Android sont renouvelés par Test Orchestrator avec
`clearPackageData=true`. `TEST_SESSION` est interdit.

Le reset efface listes, concepts, variantes, progression, abonnements Supabase,
notifications et classement du compte. Il recrée son profil gratuit avec le
pseudo enregistré. Les historiques serveur optionnels sont également effacés.
Les amitiés, demandes, défis et progressions d'autres comptes sur ses listes
font **refuser** le reset : ne pas créer de fixtures partagées entre scénarios.
Les futurs tests sociaux devront disposer d'une stratégie dédiée documentée.

L'identité Auth est conservée. Le reset ne supprime pas les objets Storage ni
l'état des services externes. RevenueCat est désactivé en mode test et STT est
simulé. Toute nouvelle table synchronisée doit être intégrée au reset et à ses
tests. Le teardown reste au mieux ; il ne remplace jamais la préparation.

## Ajouter ou lancer un scénario

Ajouter un ID stable dans le test et dans le catalogue, puis relancer le script
de provisioning. Renommer une description ne change pas l'ID ni le compte.

```bash
patrol test --target patrol_test/quiz_test.dart \
  --dart-define-from-file=test.accounts.env.json -d <device-id>
```

La CI fixe `patrol_cli` à **4.4.0**, compatible avec `patrol` **4.6.1**.
Utiliser cette même version localement : `dart pub global activate patrol_cli 4.4.0`.
Une mise à jour du package Patrol doit réévaluer cette compatibilité.

La CI utilise `SUPABASE_URL`, `SUPABASE_ANON_KEY` et `E2E_ACCOUNTS_JSON`.
Les anciens secrets `TEST_EMAIL` et `TEST_PASSWORD` ne sont plus utilisés.
Le précontrôle valide le catalogue complet sans modifier les comptes ; seul
le scénario sur le point de démarrer réinitialise son propre compte.

Le dispatcher sur `main` cible `feat/multi-language-learning` chaque soir à
22 h 17 Asia/Seoul (13 h 17 UTC). Le verrou `supabase-e2e-account` sérialise les
runs ; ne pas exécuter le même scénario localement pendant la CI. Un dispatcher
réussi ne prouve pas le succès du run « E2E (emulator) ».
Le trafic ne garantit pas contractuellement l'absence de pause Supabase.

## Vérification

- `python3 -m unittest discover -s tool/e2e -p 'test_*.py'` : catalogue,
  unicité et reprise du provisioning sans rotation d'identité.
- `flutter test test/unit/e2e_scenario_accounts_test.dart test/integration/e2e_reset_test.dart` :
  sélection, absence de compte partagé, reset local et rollback.
- Sur une base **jetable**, appliquer 008 et exécuter
  [les tests du reset](../../supabase/tests/reset_e2e_account.sql), puis 009 et
  [les tests d'isolation](../../supabase/tests/e2e_scenario_accounts.sql).
  Ils vérifient les permissions, le refus de réaffectation, le rollback et
  l'absence de modification du compte B lorsque A est réinitialisé.
- Un passage Patrol réel reste nécessaire après activation de la base hébergée.
