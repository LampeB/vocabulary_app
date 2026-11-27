# Synchronisation locale et distante

L'application utilise SQLite comme source de lecture et les colonnes
`isSynced = false` comme file durable des écritures sortantes.

## Écritures

- Les repositories écrivent localement. `PushSync` est le seul responsable
  des envois de listes, concepts, variantes, progression et événements.
- Le shell déclenche un envoi après modification locale (regroupement de
  300 ms), à la connexion et au retour du réseau. Un échec conserve la ligne
  en attente pour une prochaine tentative.
- Les envois de production sont filtrés par utilisateur connecté, y compris
  les concepts et variantes reliés à leurs listes. Les recherches de token de
  partage et de progression sont également isolées par compte.
- Les envois respectent l'ordre listes → concepts → variantes → progression
  → événements. L'audio est provisionné après l'envoi d'une variante.
- L'accusé de réception ne marque une ligne synchronisée que si tous ses
  champs correspondent toujours à la version envoyée. Une modification
  pendant un envoi reste donc en attente.
- Un partage attend le passage de la file et vérifie l'accusé du token et de
  tous ses mots avant d'ouvrir le partage système. Son token et sa visibilité
  publique sont conservés localement ; importer un lien conserve la copie
  privée tant que l'utilisateur ne la partage pas lui-même.
- La provenance d'import (`imported_from_share_token`) est distincte du jeton
  public unique. Elle est écrite atomiquement avec la copie et sert à la
  déduplication par compte. La migration locale 11 répare les anciennes copies.
- Une progression est identifiée par `(user_id, variant_id, direction)` : les
  nouvelles cartes utilisent un UUID déterministe et l'envoi distant fait un
  upsert sur cette clé métier. La récupération préserve une édition locale en
  attente et ne crée pas un doublon lorsqu'un autre appareil a un ancien UUID.

## Récupération distante

- Une métadonnée locale non synchronisée n'est pas remplacée par une copie
  distante vivante. Les autres enfants continuent cependant à être restaurés.
- Une suppression distante de liste invalide ses concepts et variantes et
  retire la progression locale associée. Une progression distante ancienne
  ne doit pas faire réapparaître des cartes supprimées.
- Le recalcul du nombre de mots après récupération est une donnée dérivée :
  il ne fabrique pas une nouvelle modification à envoyer.
- L'authentification, y compris une connexion depuis l'écran d'accueil,
  déclenche la récupération puis le seeding idempotent avant le plateau.
  Une panne réseau autorise toujours le travail local.
- Les créations de listes starter partagent une exécution en cours par
  compte/paire. Un import échoué ne positionne jamais le marqueur de complétion.

## Paires de langues

Les exports JSON et les liens partagés préservent `langA` et `langB`. Le chemin
quotidien recommande uniquement une liste de la paire active ; sans liste
correspondante, il propose d'en préparer une.
Les compteurs et les sessions intelligentes utilisent la paire **ordonnée**
de la liste et excluent les concepts/listes supprimés. Un compteur ouvert
réévalue l'heure au moins une fois par minute. Les exercices observent une
projection dédupliquée des états pédagogiques et du vocabulaire ; un accusé de
synchronisation sans changement pédagogique ne recharge pas leur pool.

Les tests d'intégration de récupération, d'envoi et d'export/import servent de
preuves exécutables. La validation sur deux appareils reste nécessaire avant
une ouverture bêta.
