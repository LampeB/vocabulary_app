# Compte E2E permanent et préparation des scénarios

Décision du 30 septembre 2026 : un compte réservé aux E2E, réutilisé en série.
Son identité Auth est conservée ; son état applicatif est reconstruit avant
chaque scénario. Aucun compte personnel ne doit être inscrit dans ce mécanisme.

## Activation Supabase (une seule fois)

1. Réactiver le projet si nécessaire.
2. Appliquer [la migration 008](../../supabase/migrations/008_e2e_reset.sql)
   dans le SQL Editor avec un accès administrateur. Les migrations antérieures
   du projet, dont `add_subscription_type.sql`, doivent être présentes.
3. Inscrire explicitement le compte correspondant au secret GitHub `TEST_EMAIL`.
   Remplacer l'adresse ci-dessous par celle du compte dédié. L'instruction doit
   insérer exactement une ligne ; vérifier son résultat avant de lancer les tests.

```sql
INSERT INTO e2e_private.accounts (user_id, username)
SELECT u.id, p.username
FROM auth.users u JOIN public.profiles p ON p.id = u.id
WHERE lower(u.email) = lower('ADRESSE_DU_COMPTE_E2E')
ON CONFLICT (user_id) DO UPDATE SET username = EXCLUDED.username
RETURNING user_id, username;
```

La liste d'autorisation est inaccessible aux utilisateurs de l'application :
RLS activée sans politique client, et droits retirés sur la table et le schéma.
`reset_e2e_account()` n'accepte aucun identifiant cible : il ne peut effacer que
les données de `auth.uid()`, et uniquement si ce compte est inscrit. La fonction
utilise une transaction et un `search_path` vide. Une erreur annule tout.
Retirer la ligne de `e2e_private.accounts` désactive immédiatement l'autorisation.
Aucune clé `service_role` n'est nécessaire dans la CI ou dans l'APK.

## État initial et périmètre

Chaque scénario utilise `isolatedPatrolTest`, qui prépare l'état **avant**
`app.main()` et avant la synchronisation :

1. Connexion avec `TEST_EMAIL` / `TEST_PASSWORD`, vérification de l'identité.
2. Reset serveur et vérification de la réponse `empty-free-v1` : suppression
   des listes, concepts, variantes, progression, abonnements locaux Supabase,
   notifications, classement, demandes d'amis, amitiés et défis liés au compte.
   Le profil est recréé avec le pseudo inscrit, les valeurs par défaut et
   l'accès gratuit. Les historiques `review_events`, `quiz_sessions` et
   `grammar_progress` sont aussi effacés s'ils existent sur le serveur.
3. Suppression transactionnelle de toutes les tables SQLite de l'app, y compris
   les historiques locaux, puis des préférences. Vérification de leur vacuité.
4. Lancement de l'app, connexion, puis préparation spécifique via `given.*`.

Les scénarios Android exigent un processus neuf via Test Orchestrator et
`clearPackageData=true`. Une réutilisation de processus est refusée : le reset
ne doit jamais courir en même temps qu'une ancienne synchronisation.
`TEST_SESSION` doit être absent : aucune session compilée partagée entre tests.
Le nettoyage après test reste au mieux ; le reset préalable est obligatoire et
ses erreurs arrêtent le scénario. Ne pas lancer un test local pendant la CI.

Les méthodes `given.aListWithOneWord`, `given.theFrenchKoreanStarterCurriculum`
et `given.theStarterListIsKnown` construisent les préconditions. La première
vérifie le concept et ses deux variantes, la deuxième les listes seedées, et
la troisième l'enregistrement de la progression. Étendre ces préparations pour
chaque nouvel état métier ; ne pas dépendre des résultats d'un autre test.

La réinitialisation conserve l'identité Auth (email, mot de passe, métadonnées
d'identité). Elle ne supprime pas les fichiers Storage, notamment les audios
partagés, ni l'état des services externes (RevenueCat, emails). RevenueCat et
la reconnaissance vocale réelle restent désactivés/simulés par la configuration
CI. Toute nouvelle table métier synchronisée doit être ajoutée au reset et à
ses tests ; ce mécanisme ne promet pas de vider un schéma distant inconnu.

## GitHub Actions

Le [workflow E2E](../../.github/workflows/e2e.yml) utilise les quatre secrets
existants : `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `TEST_EMAIL`, `TEST_PASSWORD`.
Le précontrôle teste le reset avant de démarrer l'émulateur et génère le JSON
avec un encodeur, sans écrire de session dans les logs. Le fichier est supprimé
à la fin du job. Le mode manuel permet toujours de choisir une suite.

- Planification quotidienne : **22 h 17 Asia/Seoul**, soit 13 h 17 UTC.
- Verrou commun `supabase-e2e-account` entre branches et déclenchements ; un run
  actif n'est pas annulé par un nouveau run. GitHub peut remplacer un run en
  attente par un plus récent ; ce n'est pas une file illimitée.
- Le [déclencheur nocturne](../../.github/workflows/e2e-nightly.yml) doit être
  présent sur `main`. Il déclenche `e2e.yml` sur `feat/multi-language-learning`,
  qui contient les neuf suites maintenues et le reset. Cela évite de fusionner
  tout le développement dans `main`. Il n'y a qu'un seul schedule ; `e2e.yml`
  reste déclenchable manuellement. Le job dispatcher réussi confirme l'envoi,
  pas le succès E2E : consulter ensuite le run « E2E (emulator) ».
  Lors du déplacement de la branche de travail, mettre à jour le `--ref`.
- Les anciennes versions du workflow sans ce verrou ne sont pas protégées.
- Les schedules des dépôts publics peuvent être désactivés après 60 jours
  d'inactivité du dépôt ; surveiller l'onglet Actions et réactiver si nécessaire.
- Le trafic E2E constitue une activité réelle, sans garantie contractuelle
  contre la pause Supabase. Une pause déjà effective doit être levée manuellement.

Sources : [GitHub schedules](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule),
[Supabase pausing](https://supabase.com/docs/guides/platform/free-project-pausing).

## Vérification

- `flutter test test/integration/e2e_reset_test.dart` vérifie la remise à zéro
  SQLite avec clés étrangères actives et le rollback sur échec.
- [Tests SQL](../../supabase/tests/reset_e2e_account.sql) : sur une base jetable
  uniquement, avec le schéma du projet installé ; vérifient les permissions,
  les comptes non inscrits, les cascades, l'isolation et le rollback.
- Un passage réel Patrol après activation reste nécessaire pour valider le
  schéma hébergé et le démarrage Android de bout en bout.
