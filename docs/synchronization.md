# Synchronisation locale et distante

L'application utilise SQLite comme source de lecture et les colonnes
`isSynced = false` comme file durable des écritures sortantes.

## Écritures

- Les repositories écrivent localement. `PushSync` est le seul responsable
  des envois de listes, concepts, variantes, progression et événements.
- Le shell déclenche un envoi après modification locale (regroupement de
  300 ms) lorsque le réseau est disponible, à la connexion et au retour du
  réseau. Une panne de transport interrompt la passe courante et laisse les
  écritures en attente. Un refus attaché à une ligne laisse les autres
  écritures avancer. Les dates envoyées au serveur sont explicites en UTC.
- Le déclencheur écoute les mutations locales validées par SQLite pour le
  compte actif. Une nouvelle édition d'une ligne déjà en attente réveille
  la file. Les accusés, les restaurations et les mutations des autres comptes
  ne déclenchent aucun envoi. Les colonnes `isSynced` conservent l'arriéré
  après redémarrage et jusqu'au retour du réseau.
- Les envois de production sont filtrés par utilisateur connecté, y compris
  les concepts et variantes reliés à leurs listes. Les recherches de token de
  partage et de progression sont également isolées par compte.
- La file envoie chaque liste avant ses concepts et variantes, puis envoie
  la progression et les événements. Après l'accusé d'une variante, le
  provisionnement audio s'exécute en arrière-plan, à raison d'une requête à
  la fois et de 256 variantes distinctes en attente. Un échec ou une file
  audio pleine laisse la synthèse de l'appareil disponible. SQLite adopte le
  chemin canonique si la variante, son mot, sa langue et ses parents sont
  encore valides. Le changement de chemin ne déclenche aucun nouvel envoi.
- L'accusé de réception ne marque une ligne synchronisée que si tous ses
  champs correspondent toujours à la version envoyée. Une modification
  pendant un envoi reste donc en attente. Les détails de liste et les mots
  ouverts suivent les changements canoniques dans SQLite. Les accusés qui
  changent uniquement le statut sortant ne relancent pas leurs lectures.
- La migration PostgreSQL 014 protège les suppressions sur les écritures
  ordinaires et sur les imports. Une liste, un concept ou une variante
  supprimés conservent leur suppression. Le serveur verrouille les parents
  pendant l'écriture d'un enfant et renvoie la suppression canonique si un
  appareil tente d'éditer une branche supprimée. L'app applique l'accusé à
  la branche locale et retire la progression masquée dans la même transaction.
- Un partage envoie la liste ciblée et vérifie l'accusé de son token et de
  tous ses mots avant d'ouvrir le partage système. Un envoi global en cours
  partage le même travail pour cette liste. Les autres listes, la progression,
  les événements et l'audio n'interviennent pas dans cette attente. Les copies
  importées restent privées jusqu'à leur propre publication.
- La provenance d'import (`imported_from_share_token`) est distincte du jeton
  public unique. Elle est écrite atomiquement avec la copie et sert à la
  déduplication par compte. Les nouveaux imports utilisent un UUIDv5 dérivé
  du compte et du token. Les UUIDv5 des enfants dérivent de leurs identifiants
  source et de leur parent importé. Si l'utilisateur réimporte après une
  suppression locale, il obtient une nouvelle génération. La migration 11
  répare la provenance des anciennes copies. Si plusieurs copies existent
  déjà, la recherche retrouve la plus ancienne encore active et départage
  les dates identiques par identifiant. Chaque copie et ses éditions restent
  disponibles.
- La migration locale 12 conserve une base durable pour chaque création issue
  d'un lien. Si la ligne existe déjà sur le serveur, l'envoi applique
  uniquement les champs modifiés par l'utilisateur. L'accusé reprend la
  version distante et réapplique dans la même transaction les changements
  locaux survenus en cours de requête. Ces changements restent en attente et
  sont renvoyés par champ après une panne ou un redémarrage. Une suppression
  distante confirmée retire la branche locale et sa progression.
- Une progression est identifiée par `(user_id, variant_id, direction)` : les
  nouvelles cartes utilisent un UUID déterministe et l'envoi distant fait un
  upsert sur cette clé métier. La récupération préserve une édition locale en
  attente et ne crée pas un doublon lorsqu'un autre appareil a un ancien UUID.
- Chaque note calcule FSRS à partir de la progression courante, dans la
  transaction qui enregistre la réponse. Deux passages de la même carte
  incrémentent les compteurs et appliquent les transitions successives, même
  si le quiz a chargé les deux cartes en même temps. Le retour du quiz
  utilise l'intervalle réellement enregistré.

## Récupération distante

- Une métadonnée locale non synchronisée n'est pas remplacée par une copie
  distante vivante. Les autres enfants continuent cependant à être restaurés.
- Le pull capture l'état local complet du compte avant sa première requête.
  Dans la transaction d'application, il préserve toute liste, tout concept,
  toute variante et toute progression dont la ligne a changé, y compris son
  statut d'accusé, pendant la récupération. Une suppression distante attend
  un autre pull si une ligne de la branche affectée a changé entre-temps.
- Une suppression distante de liste invalide ses concepts et variantes et
  retire la progression locale associée. Une progression distante ancienne
  ne doit pas faire réapparaître des cartes supprimées. La suppression locale
  d'un concept retire sa progression dans la transaction de suppression et
  conserve son tombstone dans la file sortante.
- Le nombre de mots suit les concepts actifs après une restauration ou
  l'accusé d'un concept supprimé. Ce recalcul libère la place dans le quota
  local et préserve les métadonnées qui attendent leur propre envoi.
- Après la restauration du contenu, une requête jointe identifie les variantes
  encore actives. Les progressions identiques sont ignorées et les autres
  mises à jour sont regroupées dans la transaction du pull.
- L'authentification, y compris une connexion depuis l'écran d'accueil,
  déclenche la récupération puis le seeding idempotent avant le plateau.
  Les appelants d'une même session partagent la récupération en cours. Un
  enrichissement du profil conserve la même tentative. Une récupération
  incomplète conserve les données reçues et reste en attente de nouvelle
  tentative. Le seeding local et l'ouverture du plateau restent disponibles
  hors ligne. Au retour du réseau, le shell relance la récupération en
  attente avant d'envoyer les modifications locales.
  En cas d'indisponibilité du profil distant, une session déjà signée fournit
  l'identité locale pour le seeding et l'ouverture du plateau. Un profil reçu
  plus tard enrichit la session si elle est toujours active. Après un
  changement de compte ou une déconnexion, une ancienne réponse de profil
  ne peut plus restaurer l'identité précédente.
- Un lien ouvert au démarrage peut importer dès la restauration d'une session
  locale signée, même si le profil distant est encore en cours de chargement.
  Le repository exige un identifiant de compte avant toute création ou import.
- Les créations de listes starter partagent une exécution en cours par
  compte/paire. Un import échoué ne positionne jamais le marqueur de complétion.

## Paires de langues

Les exports JSON et les liens partagés préservent `langA` et `langB`, ainsi que
les tags de contexte et l'exemple de chaque variante. Le chemin
quotidien recommande uniquement une liste de la paire active ; sans liste
correspondante, il propose d'en préparer une.
Les compteurs et les sessions intelligentes utilisent la paire **ordonnée**
de la liste et excluent les concepts/listes supprimés. Un compteur ouvert
réévalue l'heure au moins une fois par minute et arrête son écoute quand le
dernier abonné ferme le compteur de la paire. Les exercices observent une
projection dédupliquée des états pédagogiques et du vocabulaire ; un accusé de
synchronisation sans changement pédagogique ne recharge pas leur pool.

Les tests d'intégration de récupération, d'envoi et d'export/import servent de
preuves exécutables. La validation sur deux appareils reste nécessaire avant
une ouverture bêta.
