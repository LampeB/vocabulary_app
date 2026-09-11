# VocabKR — Audit complet de l’application

## Verdict

VocabKR possède un **noyau de produit sérieux, testable et déjà utilisable** :
la gestion locale des données, les révisions FSRS, les sessions de quiz, le
mode hors-ligne, la synchronisation sortante, les listes, le contenu seedé et
une grande partie des parcours v1 sont réellement implémentés. Ce n'est pas
une simple maquette.

En revanche, ce n'est pas encore un produit prêt à distribuer largement. Les
blocages ne sont pas d'abord des problèmes de qualité Flutter : ce sont des
questions de **sécurité et de coût des services IA**, de **parcours de compte
et de paiement inachevés**, de **contenu pédagogique insuffisant au-delà du
noyau A1**, et d'un **écart structurel entre le design v2 décidé et l'interface
actuellement livrée**.

La bonne séquence n'est donc pas de construire toutes les idées v2 maintenant.
Il faut d'abord sécuriser et fiabiliser le socle distribué, puis construire un
vertical slice du nouveau parcours quotidien sur des données réelles.

## Périmètre et limites

L'audit porte sur le dépôt local au 11 septembre 2026, branche
`feat/multi-language-learning`, qui est en avance de deux commits sur `origin`.
Le répertoire de travail contient aussi des modifications de design non
commitées ; elles sont traitées comme du travail en cours, pas comme une
version publiée.

Les constats sont fondés sur le code, les migrations, les workflows et les
documents du dépôt. Ils ne valident pas l'état réellement déployé de Supabase,
RevenueCat, des stores, ni le comportement d'un microphone ou d'un achat sur
un appareil physique. Aucun scan CVE externe ni test de pénétration n'a été
effectué : les risques sécurité ci-dessous sont des constats de conception et
de code à vérifier avant distribution.

## État global

| Axe | État | Lecture |
| --- | --- | --- |
| Noyau d’apprentissage | Bon | FSRS, quiz, listes, grammaire A1, historique et progression locale sont présents et testés. |
| Architecture Flutter | Bon | Séparation core / domain / data / presentation / services cohérente ; Riverpod, Drift et GoRouter sont employés de manière lisible. |
| Qualité automatique | Bon, mais incomplet | 650 tests hôte validés ; CI couvre les tests et un plancher de couverture, mais pas l'analyse ni le formatage. |
| Offline et sync | Bon avec un risque de conflit | Écriture locale d'abord et file sortante par `isSynced` sont bien conçues ; la protection des écritures locales pendant un pull n'est complète que pour la progression. |
| Sécurité backend | À corriger avant ouverture | Les proxys IA coûteux ne démontrent pas une authentification/limitation dans le dépôt ; les politiques sociales permettent une relation d'amitié forgée. |
| Compte et monétisation | Incomplet | Email/mot de passe fonctionne ; OAuth et suppression de compte sont des stubs ; les builds CI injectent une clé RevenueCat de démonstration. |
| Design et UX | Direction forte, implémentation v1 | Le nouveau système « plongée / flashcards / popup » est documenté mais le code reste majoritairement sur le langage v1 papier/teal. |
| Contenu et curriculum | Prototype A1 solide, insuffisant pour un parcours | 111 concepts sur six langues, mais une grande partie des exemples, des notes et toutes les leçons sont encore manquants. |
| Livraison | À industrialiser | Tests hôte à chaque push/PR ; build APK, E2E et TestFlight restent manuels ou dépendent de prérequis externes. |

## Ce qui existe réellement

### Application et architecture

Le projet est une application Flutter/Dart (`Flutter 3.44.9`, Dart 3.12.2),
avec Riverpod pour l'état, GoRouter pour les routes, Drift/SQLite pour les
données locales et Supabase pour l'authentification et la synchronisation.
Le code source Dart hors fichiers générés représente environ 22 000 lignes :
près de 12 000 dans la présentation, 3 756 dans la couche data, 2 634 dans le
core, 2 364 dans les services et 1 004 dans le domaine.

La structure suit globalement une séparation saine : entités et interfaces dans
`lib/domain/`, accès Drift/Supabase et repositories dans `lib/data/`, services
audio/STT/paiement dans `lib/services/`, et écrans/providers/widgets dans
`lib/presentation/`. Le bootstrap initialise Supabase, notifications,
localisation et RevenueCat, puis expose les routes sous un `ShellRoute`.
Voir [le bootstrap](../../lib/main.dart), [le routeur](../../lib/app.dart) et
[le tour du dépôt](../../README.md).

### Boucle d’apprentissage

Les briques essentielles sont là : création et import de listes, concepts et
variantes bilingues, sélection des cartes dues, calcul FSRS, modes cartes,
écrit, voix et mains libres, historique de sessions et événements de révision.
La progression est isolée par direction de quiz, ce qui est important pour les
paires de langues réversibles. Les modes de voix sont encadrés par les seams
`VoiceTurnMachine`, `AudioDirector` et `SttRace`, et la réponse silencieuse
est reprogrammée sans être considérée comme fausse.

La reconnaissance combine le moteur système et un Whisper on-device dans un
mode « course » configurable. C'est nettement plus avancé que le vieux statut
du fichier `docs/stt-improvement-plan.md`, qui se dit « proposed / not yet
implemented » alors que les adapters, le race engine et ses tests existent.
Le plan de STT doit être mis à jour pour distinguer le réalisé de ce qui reste
à mesurer sur appareil.

### Données, offline et synchronisation

Les écritures passent par Drift et les tables possèdent un marqueur `isSynced`.
`PushSync` traite les lignes en ordre de clés étrangères (listes, concepts,
variantes, progression, événements) et ne marque une ligne synchronisée qu'en
cas de succès. C'est un mécanisme léger et pertinent de file sortante, testé
pour les réessais et les tombstones. La base locale est versionnée jusqu'au
schéma 9 et inclut les migrations de données nécessaires aux paires génériques
et aux exemples par variante.

Le point faible est le pull : `syncFromRemote()` évite explicitement d'écraser
une progression locale encore non synchronisée, mais il applique les listes,
concepts et variantes distantes sans le même garde-fou. Selon l'ordre entre un
pull au login et le drain sortant, une modification locale récente de ces
objets pourrait être remplacée par une version serveur plus ancienne. Il faut
soit adopter une règle de résolution de conflit explicite (`updated_at`,
version, ou priorité locale), soit appliquer le même garde-fou aux trois
familles d'entités. Voir
[`syncFromRemote`](../../lib/data/repositories/vocabulary_repository_impl.dart)
et [`PushSync`](../../lib/data/sync/push_sync.dart).

### Produit, contenu et design

La v1 contient les écrans de compte, accueil, listes, détail de liste,
session, grammaire, social, profil, paiement, paramètres, statistiques,
notifications et import. Les parcours du document v2 — parcours quotidien,
découverte de vocabulaire, lecteur de leçons, dashboard, familles, défis et
tests de niveau — constituent encore un plan produit, non un ensemble livré.

Le contenu confirme la même réalité : six couches linguistiques (fr, en, it,
de, es, ko) et 111 concepts A1, mais seulement 40 concepts avec exemples, les
notes pédagogiques complètes uniquement en coréen et aucun texte de leçon.
Les données permettent donc un bon démonstrateur et une base de moteur, pas
encore un parcours A1→C2 honnête. Voir
[la roadmap de contenu](../content-roadmap.md) et
[le plan d'implémentation v2](../implementation-plan-v2.md).

Le design v2 est désormais beaucoup plus précis que l'application actuelle.
Les décisions « plonger dans une destination », « dépiler seulement en quiz »,
« popup contextuelle de leçon » et « scroll rare mais signalé » sont correctement
consignées dans
[`interaction-language.md`](../design/map/interaction-language.md). Elles ne
sont pas encore un système de composants Flutter ni une migration d'écrans.
Le risque serait de les appliquer écran par écran : il faut une fondation de
transitions, surfaces, popup accessible et indicateur de scroll, puis un flux
complet.

## Validation effectuée

Les contrôles suivants ont été exécutés dans ce workspace :

| Contrôle | Résultat |
| --- | --- |
| `dart analyze lib/core lib/domain` | Conforme, aucune issue. |
| `dart analyze lib/data lib/services` | Conforme, aucune issue. |
| `dart analyze lib/presentation lib/app.dart lib/main.dart` | Conforme, aucune issue. |
| `flutter test test/unit` | 368 tests réussis. |
| `flutter test test/integration` | 158 tests réussis. |
| `flutter test test/seed` | 9 tests réussis. |
| `flutter test test/widget test/widget_test.dart` | 115 tests réussis. |
| Total hôte vérifié | **650 tests réussis**. |

La suite protège bien les invariants pédagogiques et de données : transitions
FSRS, validation de réponse, sync, offline, quotas, import/export, progression,
grammaire, thèmes et une partie importante de la navigation. La CI exécute les
tests avec couverture et impose un plancher de 47,5 %, documenté à 49,7 % lors
de la dernière mesure de référence. Elle ne lance toutefois ni analyse Dart,
ni vérification de formatage, ni build Android sur les PR. Les E2E Patrol sont
manuels et connus pour avoir une instabilité d'orchestration ; les tests
matériels restent à exécuter avant chaque release. Voir
[le workflow de tests](../../.github/workflows/test.yml),
[le workflow E2E](../../.github/workflows/e2e.yml) et
[la couverture fonctionnelle](../feature-coverage.md).

## Risques et écarts prioritaires

### P0 — à fermer avant bêta publique ou hausse de trafic

1. **Protéger et borner les fonctions IA payantes.**
   `whisper-proxy` et `elevenlabs-proxy` font transiter un appel vers OpenAI ou
   ElevenLabs avec des secrets serveur mais n'effectuent aucune vérification de
   JWT, quota utilisateur, limite de taille d'audio, limite de débit ou
   comptabilisation dans leur code. Le dépôt ne contient pas de configuration
   Supabase prouvant que la passerelle impose la vérification JWT. Dans cet état,
   il faut considérer l'abus de coûts comme possible jusqu'à preuve du contraire.
   Verrouiller l'accès au niveau gateway **et** dans la fonction, vérifier le
   sujet du JWT, limiter le volume/durée, appliquer une limite par utilisateur
   et journaliser les métriques sans audio brut. Les fonctions Anthropic doivent
   recevoir le même audit ; leurs commentaires ne remplacent pas un contrôle
   déployé. Voir les fonctions dans
   [`supabase/functions`](../../supabase/functions).

2. **Corriger la création directe de relations d'amitié.**
   La politique RLS `Create friendship` permet l'insertion dès que l'utilisateur
   connecté est l'un des deux membres. Une personne peut donc, en principe,
   créer elle-même une ligne de relation avec une cible et satisfaire ensuite la
   politique d'accès aux listes « friends ». La création doit passer par une
   fonction RPC ou un trigger qui vérifie une demande acceptée et impose un
   ordre canonique des deux identifiants ; supprimer l'INSERT direct client.
   Voir [`003_fix_schema.sql`](../../supabase/migrations/003_fix_schema.sql).

3. **Rendre les builds de distribution impossibles avec une configuration
   fictive.** Les workflows APK et TestFlight placent encore
   `YOUR_REVENUECAT_KEY` dans l'environnement. Soit RevenueCat est requis :
   utiliser un secret réel et faire échouer explicitement le build s'il manque.
   Soit il est différé : désactiver proprement l'initialisation et le paywall
   payant dans les builds de test. Aujourd'hui, l'app peut se construire mais
   la promesse d'achat ne constitue pas un parcours de production.

4. **Décider et implémenter la suppression de compte.** La méthode retourne
   explicitement « not implemented ». Avant de collecter durablement des
   profils, progrès, enregistrements de révision et potentiellement des données
   de voix, fournir une suppression authentifiée côté serveur, sa confirmation,
   la purge/cascade vérifiée et la documentation de confidentialité. C'est un
   prérequis produit et réglementaire, pas une finition d'interface.

### P1 — prochaine séquence de fiabilisation

1. **Formaliser les conflits de synchronisation** pour listes, concepts et
   variantes, puis ajouter des tests « deux appareils, modifications opposées,
   offline puis reconnexion ». La progression a déjà le bon garde-fou ; étendre
   la règle ou passer à une version de ligne.

2. **Mettre à niveau la chaîne CI.** Sur chaque PR : `dart format
   --set-exit-if-changed`, analyse Dart, tests/couverture, puis au moins un
   build Android debug. Conserver E2E en déclenchement manuel et ajouter un
   run planifié nocturne quand leur flakiness sera instrumentée. Ajouter un
   rapport d'échec utile et une checklist de release physique (paiement,
   microphone, TTS, notifications, deep link, restauration d'achat).

3. **Remplacer les stubs de compte selon la promesse de lancement.** OAuth
   Google/Apple retourne « not configured » ; soit le masquer avant lancement,
   soit le livrer avec les tests et les réglages plateformes. Définir également
   le cycle complet de facturation : clé RevenueCat, entitlement, webhook ou
   rapprochement avec Supabase, restauration et annulation.

4. **Établir un registre de vérité documentaire.** `PROJECT_STATUS.md` décrit
   l'état de juin et ne reflète ni le multi-langue ni la progression récente ;
   `stt-improvement-plan.md` se présente comme non implémenté malgré le code ;
   certaines études de test décrivent encore l'ancienne `sync_queue` alors que
   `PushSync` a remplacé cette approche. Garder une page « état actuel » et
   déplacer les anciens constats dans un historique évite les décisions basées
   sur des faits périmés.

5. **Traiter le nouveau design comme une fondation, pas comme du polish.**
   Construire d'abord quatre primitives : transition de plongée réversible,
   pile de flashcards dédiée au quiz, popup contextuelle accessible, et
   conteneur scrollable avec affordance. Ensuite migrer un seul flux complet :
   Parcours → setup/pratique → quiz → résumé/retour. Ce flux donnera les bons
   contrats de route, état et retour avant de toucher aux listes ou réglages.

### P2 — dette saine à planifier

- Décomposer progressivement les très gros fichiers : `quiz_screen.dart`
  (1 503 lignes), `quiz_provider.dart` (954), `list_detail_screen.dart` (898),
  `start_session_screen.dart` (896) et `social_screen.dart` (888). Les seams
  métier sont plutôt bons, mais ces fichiers rendent les changements UI et les
  revues difficiles. Extraire par états et composants, pas dans un refactor
  massif.
- Lancer une campagne de mise à jour de dépendances. `flutter pub get` signale
  128 versions plus récentes incompatibles avec les bornes actuelles, dont des
  majeures de Riverpod, GoRouter, Drift, notifications et plugins natifs. Faire
  cette mise à jour en lots avec build Android/iOS et tests, jamais en même temps
  qu'une fonctionnalité.
- Compléter le contenu avant de promettre un parcours : P1/P2/P3 de la roadmap,
  exemples A1 manquants, revue native des couches générées, puis A2 et groupes
  de grammaire. Le lecteur de leçons doit attendre un slot de données stable.
- Faire un audit d'accessibilité réel : lecteur d'écran, labels des contrôles
  icon-only/GestureDetector, navigation clavier, tailles système, contraste et
  réduction de mouvement. Les tests de thèmes et de grand texte sont une bonne
  base, pas une validation complète.
- Définir une télémétrie minimale et respectueuse de la vie privée : événements
  de réussite/abandon/latence STT sans audio ni texte sensible, consentement et
  rétention documentés. C'est indispensable pour savoir si le mode voix marche
  réellement sur le terrain.

## Plan d’action recommandé

### Étape 0 — Décider le périmètre de la prochaine bêta

Choisir explicitement une cible : « bêta privée centrée sur révision vocab » ou
« lancement avec parcours v2 ». La première est plus réaliste à court terme :
elle exige sécurité, compte, paiement ou retrait du paiement, stabilité audio
et contenu A1, sans bloquer sur les 18 écrans v2.

**Sortie attendue :** une définition de release écrite, une liste des fonctions
visibles/masquées et des critères de sortie testables.

### Étape 1 — Fermer les portes de sécurité et de distribution

1. Vérifier la configuration réellement déployée de chaque Edge Function.
2. Ajouter authentification, quotas, limites de payload et logs de coût aux
   proxies IA.
3. Remplacer la policy d'amitié par un flux d'acceptation atomique côté serveur.
4. Implémenter suppression de compte et politique de confidentialité associée.
5. Bloquer toute build release avec URL Supabase, clé publishable ou clé
   RevenueCat factices.

**Critère de sortie :** revue SQL/fonctions, tests RLS positifs et négatifs,
test d'abus de taille/débit, et build release configuré depuis des secrets.

### Étape 2 — Rendre le socle opérable

1. Définir la stratégie de conflit sync et couvrir deux appareils hors ligne.
2. Ajouter formatage, analyse et build debug à la CI PR.
3. Écrire une checklist de test matériel et l'exécuter sur Android ; préparer
   l'équivalent iOS/TestFlight.
4. Mettre à jour `PROJECT_STATUS`, le plan STT et les documents de test pour
   qu'ils décrivent l'implémentation actuelle.

**Critère de sortie :** une PR propre ne peut pas contourner les contrôles
automatiques ; les risques matériels sont explicitement testés et attribués.

### Étape 3 — Livrer un vertical slice du design v2

1. Créer les primitives de navigation/mouvement décidées.
2. Réaliser le flux Parcours → Pratique libre/setup → Quiz → résumé → retour,
   sans encore migrer les écrans secondaires.
3. Faire des tests widget des transitions réduites, de la conservation de
   l'état et de la popup ; tester le flux sur un téléphone avec tailles de texte
   normales et élevées.
4. Garder les piles inclinées strictement dans le quiz, comme le prescrit
   [`interaction-language.md`](../design/map/interaction-language.md).

**Critère de sortie :** un utilisateur peut accomplir une session entière dans
le nouveau langage visuel, revenir à son contexte exact et comprendre tout
scroll présent sans aide.

### Étape 4 — Étendre le produit seulement après le slice

Ordre conseillé : M1 mots difficiles → M3 chemin quotidien → M4 découverte
vocabulaire → P1/P2/P3 contenu → M5 leçons/grammaire → M6 cloze → M7 progrès.
Les familles, défis et tests de niveau viennent ensuite. Ce séquençage réutilise
les données, évite les écrans sans contenu et maintient le cœur de révision
comme produit utile à chaque étape.

## Décisions à prendre

1. La prochaine version est-elle une bêta privée sans achats réels, ou une
   release commerciale ?
2. Les fonctions IA doivent-elles être premium, limitées quotidiennement, ou
   retirées de la bêta ?
3. Quel comportement veut-on en cas de conflit de modification entre deux
   appareils : dernière écriture, priorité locale, ou résolution visible ?
4. Le lancement se limite-t-il au français↔coréen avec contenu soigneusement
   revu, ou expose-t-il les six langues malgré la couverture A1 et la revue
   native incomplète ?
5. Quelle portion du design v2 doit être le prochain slice, et quels écrans v1
   restent volontairement inchangés pendant cette migration ?

## Sources internes

- [README](../../README.md) — stack, démarrage, conventions et tour du dépôt.
- [Configuration Flutter](../../pubspec.yaml) — dépendances, versions et assets.
- [Bootstrap](../../lib/main.dart), [routes](../../lib/app.dart),
  [base locale](../../lib/data/datasources/local/app_database.dart) — structure
  d'exécution et de données.
- [Synchronisation sortante](../../lib/data/sync/push_sync.dart) et
  [synchronisation entrante](../../lib/data/repositories/vocabulary_repository_impl.dart).
- [Migrations Supabase](../../supabase/migrations) et
  [fonctions Edge](../../supabase/functions) — RLS et appels fournisseurs.
- [Workflows CI](../../.github/workflows),
  [couverture fonctionnelle](../feature-coverage.md) et
  [roadmap de couverture](../test-coverage-roadmap.md).
- [Roadmap contenu](../content-roadmap.md),
  [plan v2](../implementation-plan-v2.md) et
  [carte de décisions design](../design/map/app-map.md).
