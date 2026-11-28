# Synchronisation locale et distante

L'application utilise SQLite comme source de lecture et les colonnes
`isSynced = false` comme file durable des écritures sortantes.

## Écritures

- Le bilan transmet le compte et le jour civil de fin de session à
  `record_study_day`. PostgreSQL verrouille le profil du compte, enregistre
  chaque jour une seule fois et fusionne les jours adjacents en intervalles.
  Une journée arrivée plus tard peut compléter une série sans faire reculer
  la date la plus récente. Le record ne diminue pas. La migration 022 reprend
  la série existante à partir de sa dernière date et de sa longueur.
  La suppression du profil, y compris lors d'un reset Patrol, efface ces
  intervalles.
  Le bilan écrit dans une même transaction SQLite l'historique et le jour civil
  capturé pour le compte. La fin du quiz, la connexion et le retour du réseau
  relancent les jours en attente. Seul l'accusé de `record_study_day` clôt une
  date ; une réponse perdue est rejouable et plusieurs quiz du même jour
  partagent une seule entrée. Les lignes confirmées restent dédupliquées.
  La migration SQLite 14 conserve l'historique ancien sans déduire un jour civil
  d'un timestamp dont le fuseau d'origine n'a pas été conservé.
  Un échec de transaction locale conserve le bilan affiché mais ne marque pas
  le jour étudié, ne supprime pas son rappel et n'envoie pas de RPC pour une
  persistance non confirmée. La réponse distante n'enrichit que le compte actif.

- Les repositories écrivent localement. `PushSync` est le seul responsable
  des envois de listes, concepts, variantes, progression et événements.
- Le shell déclenche un envoi après modification locale (regroupement de
  300 ms) lorsque le réseau est disponible, à la connexion et au retour du
  réseau. Une panne de transport interrompt la passe courante et laisse les
  écritures en attente. Un déclenchement reçu pendant cette passe ouvre
  une nouvelle passe après l'échec. Un refus attaché à une ligne laisse
  les autres écritures avancer. Les dates envoyées au serveur sont explicites en UTC.
- Un envoi PostgREST dispose de 15 secondes, y compris les lectures nécessaires
  à son accusé canonique. L'expiration conserve la version locale en file et
  libère les appelants qui attendent l'envoi de la liste pour la partager.
- La migration PostgreSQL 016 vérifie l'ordre des écritures de chaque
  installation pour une liste, un concept, une variante, une progression ou
  un événement. SQLite attribue le numéro durable après avoir vérifié que
  la version envoyée est toujours la version en file. PostgreSQL refuse un
  ancien numéro dans la même transaction que l'écriture, même après une
  modification par un autre appareil. Le client exige le protocole 016 pour
  toute mutation, y compris une modification d'import. Quand une copie
  importée existe déjà et que ses champs sont revenus à leur valeur de base,
  l'accusé confirme la ligne canonique en validant le nouveau numéro. Un
  renommage antérieur dont la requête a expiré ne peut plus s'appliquer et
  les champs modifiés sur un autre appareil restent intacts.
- Le déclencheur écoute les mutations locales validées par SQLite pour le
  compte actif. Une nouvelle édition d'une ligne déjà en attente réveille
  la file. Les accusés, les restaurations et les mutations des autres comptes
  ne déclenchent aucun envoi. Les colonnes `isSynced` conservent l'arriéré
  après redémarrage et jusqu'au retour du réseau.
- Les envois de production sont filtrés par utilisateur connecté, y compris
  les concepts et variantes reliés à leurs listes. Les recherches de token de
  partage et de progression sont également isolées par compte.
- La migration PostgreSQL 015 qualifie les identifiants de listes, concepts et
  variantes par propriétaire. Les clés parentes, les accusés, la visibilité
  publique et l'attachement audio utilisent ce même propriétaire. Elle
  conserve les identifiants déjà enregistrés et étend la clé de progression
  à l'identité du propriétaire de la variante. Elle accompagne la version du
  client et de la fonction audio qui transmettent ces clés.
- Si deux comptes partagent le même fichier SQLite et reçoivent un même
  identifiant distant, SQLite attribue un identifiant local distinct au
  second compte. La correspondance persiste pour le pull, les écrits,
  la progression, les événements et l'audio.
- La file envoie chaque liste avant ses concepts et variantes, puis envoie
  la progression et les événements. Après l'accusé d'une variante, le
  provisionnement audio s'exécute en arrière-plan, à raison d'une requête à
  la fois et de 256 variantes distinctes en attente. Un échec ou une file
  audio pleine laisse la synthèse de l'appareil disponible. SQLite adopte le
  chemin canonique si la variante, son mot, sa langue et ses parents sont
  encore valides. La demande utilise la session du propriétaire capturé
  à la mise en file. Un changement de compte invalide la réponse et
  empêche les demandes restantes de partir sous le nouveau compte.
  Le changement de chemin ne déclenche aucun nouvel envoi.
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
  Le client supprime le vocabulaire via ces tombstones. La suppression
  physique est réservée au serveur. À partir de la migration 020, elle
  retire définitivement l'identité de la liste, du concept ou de la variante
  pour ce propriétaire. PostgreSQL refuse aussi un envoi concurrent avec
  la purge. La file lit le tombstone canonique après ce refus et l'applique
  dans SQLite avec les mêmes règles que les autres accusés de suppression.
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
  suppression locale, il obtient une nouvelle génération. Si plusieurs copies
  existent déjà, la recherche retrouve la plus ancienne encore active et
  départage les dates identiques par identifiant. Chaque copie et ses éditions
  restent disponibles.
- SQLite 13 conserve les jetons historiques ambigus dans une retenue durable.
  Il reprend aussi les jetons que SQLite 11 ou le serveur avaient rangés en
  provenance sur des listes historiques. Les imports modernes conservent leur
  provenance, y compris avec un alias SQLite pour leur UUIDv5 distant. Une
  publication historique est reconnue sur une liste publique active si le
  propriétaire, l'identifiant distant et le jeton correspondent. La même
  preuve sur une autre identité établit la provenance de la copie, y compris
  pour deux listes du même compte. Le pull peut confirmer une publication et
  la file ou l'ouverture du lien peut compléter le rapprochement.
  Les changements locaux restent prioritaires, notamment les changements de
  visibilité et les nouvelles publications explicites. Après rapprochement,
  une édition en attente est appliquée par champ pour protéger les autres
  métadonnées distantes. Hors ligne, sur erreur ou sans preuve, le jeton reste
  en retenue et la branche reste disponible localement. Une modification
  explicite du partage ou une suppression peut être envoyée. Si le lien a
  déjà été écrasé sur le serveur et que sa source a disparu, sa nature reste
  indéterminée.
  La confirmation du jeton identifie la liste ; elle n'établit pas l'origine
  de tous ses écarts de métadonnées. Avant une édition, SQLite conserve la
  version locale de référence et calcule le patch depuis les champs modifiés.
  Les écarts historiques sans base fiable restent visibles et conservés sur
  l'appareil, y compris après accusé, récupération ou redémarrage, sans être
  envoyés comme des modifications certaines. Une édition ultérieure de ces
  champs peut être envoyée. Une base d'édition déjà connue n'est pas remplacée
  par la dernière réponse réseau lors de la confirmation du jeton.
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
  Une nouvelle référence doit viser une variante active dans une branche
  possédée ou visible. Les références historiques inchangées restent
  modifiables.
- Dans le schéma des défis, une nouvelle référence doit viser une liste
  active visible par la personne qui écrit. Les mises à jour de résultat
  restent permises lorsque les participants et la référence sont inchangés.
- Une liste visible aux amis exige une amitié confirmée. Le serveur enregistre
  l'expéditeur de la demande, puis seul son destinataire peut l'accepter.
  La migration 024 fait hériter les concepts et variantes actifs de la visibilité
  de leur liste, avec la clé propriétaire dans chaque relation. Le retrait du
  consentement ferme les lectures suivantes. Aucun tombstone de la branche
  n'est visible aux tiers ; le propriétaire conserve ses lectures de
  synchronisation. Ce partage de lecture n'accorde pas de droit d'écriture.
  L'acceptation et l'ajout de l'amitié se font dans une même transaction.
  Les amitiés historiques restent visibles dans la liste sociale. Une nouvelle
  demande acceptée est nécessaire pour leur donner accès aux listes d'amis.
- Chaque note calcule FSRS à partir de la progression courante, dans la
  transaction qui enregistre la réponse. Deux passages de la même carte
  incrémentent les compteurs et appliquent les transitions successives, même
  si le quiz a chargé les deux cartes en même temps. Le retour du quiz
  utilise l'intervalle réellement enregistré. Pour une première note, la
  réservation d'un alias vérifie uniquement la clé primaire candidate.

## Récupération distante

- Une métadonnée locale non synchronisée n'est pas remplacée par une copie
  distante vivante. Les autres enfants continuent cependant à être restaurés.
- Le pull capture l'état local complet du compte avant de lire les données
  d'une phase de restauration.
  Dans la transaction d'application, il préserve toute liste, tout concept,
  toute variante et toute progression dont la ligne a changé, y compris son
  statut d'accusé, pendant la récupération. Une suppression distante attend
  un autre pull si une ligne de la branche affectée a changé entre-temps. La
  tentative reste incomplète tant que cette suppression est reportée.
- Une suppression distante de liste invalide ses concepts et variantes et
  retire la progression locale associée. Une progression distante ancienne
  ne doit pas faire réapparaître des cartes supprimées. La suppression locale
  d'un concept retire sa progression dans la transaction de suppression et
  conserve son tombstone dans la file sortante.
- Le nombre de mots suit les concepts actifs après une restauration ou
  l'accusé d'un concept supprimé. Ce recalcul libère la place dans le quota
  local et préserve les métadonnées qui attendent leur propre envoi. Si la
  récupération des concepts échoue, une liste déjà locale garde son compteur.
- Après la restauration du contenu, une requête jointe identifie les variantes
  encore actives. Les progressions identiques sont ignorées et les autres
  mises à jour sont regroupées dans la transaction du pull. Si une
  progression arrive avant sa variante, SQLite la conserve avec le curseur
  et la réévalue après le contenu des phases suivantes, y compris après
  redémarrage. La comparaison avec l'état local au moment de sa lecture
  préserve une progression modifiée entre-temps.
- L'authentification, y compris une connexion depuis l'écran d'accueil,
  déclenche la récupération puis le seeding idempotent avant le plateau.
  Les appelants d'une même session partagent la récupération en cours. Un
  enrichissement du profil conserve la même tentative. Une récupération
  incomplète conserve les données reçues et reste en attente de nouvelle
  tentative. Le seeding local et l'ouverture du plateau restent disponibles
  hors ligne. Un budget de 15 secondes couvre toute la lecture distante.
  Une panne de transport ou une expiration arrête les prochaines lectures
  et conserve les pages déjà reçues. SQLite enregistre le curseur avec les
  pages appliquées pour que la reprise avance après un délai ou un
  redémarrage. La migration PostgreSQL 017 numérote les changements validés
  par compte. Si le numéro a avancé depuis le début du parcours, SQLite
  poursuit avec des fenêtres paginées de listes modifiées, de leurs contenus
  et de progressions modifiées. Le curseur et les bornes de rattrapage
  persistent entre les tentatives. Une suppression ou une insertion derrière
  le curseur d'identifiants rejoint ainsi la restauration. L'inventaire
  initial et les fenêtres de rattrapage incluent les tombstones des listes,
  concepts et variantes purgés. Les traces conservent les identifiants et
  le lien parent nécessaire à la synchronisation. L'inventaire permet aussi
  de retirer une purge déjà validée d'un cache sans curseur compatible.
  La migration 020 ajoute ces garanties et l'inventaire aux installations
  ayant appliqué la version historique de 017, en conservant leurs données
  et les purges de listes déjà journalisées. Le journal des purges de
  concepts et de variantes commence à l'installation de 020.
  Le rapprochement
  des starters attend la fin de la couverture et la confirmation de son
  dernier numéro. Au retour du réseau, le shell relance la récupération en
  attente avant d'envoyer les modifications locales.
  Un retour réseau
  pendant un pull est retenu et ouvre une tentative si le pull échoue.
  En cas d'indisponibilité du profil distant, une session déjà signée fournit
  l'identité locale pour le seeding et l'ouverture du plateau. Un profil reçu
  plus tard enrichit la session si elle est toujours active. Après un
  changement de compte ou une déconnexion, une ancienne réponse de profil
  ne peut plus restaurer l'identité précédente.
- Un lien ouvert au démarrage peut importer dès la restauration d'une session
  locale signée, même si le profil distant est encore en cours de chargement.
  Le repository exige un identifiant de compte avant toute création ou import.
- Les créations de listes starter partagent une exécution en cours par
  compte et paire ordonnée. La session observe la paire dès sa restauration,
  y compris au démarrage par lien partagé et lors d'un changement dans
  l'en-tête. Un import échoué ne positionne pas le marqueur de complétion.
- Les nouvelles listes starter utilisent l'identité du compte, de la paire
  et du catalogue. Le complément utilise les mêmes identifiants de concepts
  et de variantes que l'import. Il tient compte des suppressions déjà
  enregistrées, y compris pour une langue dont tous les mots ont été supprimés.
  La migration 023 garde l'identité catalogue minimale des nouvelles purges
  starter dans l'inventaire, les fenêtres de rattrapage et les accusés. Elle
  garde l'origine, la paire et le seed ID d'une liste, le seed ID d'un
  concept et la langue d'une variante. Un nouveau cache reconnaît ainsi
  ces suppressions même lorsque leurs UUID historiques sont aléatoires.
  Les anciennes traces restent protégées par UUID. Pour une trace déjà
  réduite à l'UUID et au parent, les clés catalogue effacées sont
  irrécupérables depuis le journal.
  Une liste distante reçue sans son contenu complet attend la récupération
  de ses concepts avant le complément du catalogue.
  Les brouillons créés avant la première restauration restent étudiables sur
  l'appareil. La file vérifie leur retenue dans la transaction qui sélectionne
  la progression et les événements à envoyer. Une identité starter confirmée
  se conserve dans SQLite. Une modification hors ligne de cette liste ou
  d'une carte ne la remet pas en brouillon après un redémarrage.
- Au retour du réseau, le brouillon adopte les identifiants d'une liste
  starter existante, y compris les anciens UUID aléatoires. La transaction
  reprend les champs explicitement modifiés et rattache les révisions et les
  événements aux variantes reconnues. Les détails de liste et les quiz
  déjà ouverts suivent les identifiants adoptés. Les ajouts et éditions
  valident la destination active et résolvent les anciens identifiants
  dans leur transaction. Un événement dont les références ont changé repasse
  en attente et seul un accusé pour ses champs courants clôt son envoi.
  Un brouillon en conflit d'identité ou avec deux
  historiques FSRS pour la même carte reste disponible localement avec ses
  données et reste hors de la file sortante, même si ses identifiants sont
  déjà les mêmes que sur le serveur. Le même traitement préserve les anciens
  brouillons dont l'état initial est inconnu.

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
Une session de cartes dues dans les deux sens complète son plafond depuis
le sens disponible. La variante principale fournit ensemble le mot prononcé
et son extrait audio. Les autres variantes restent acceptées.
La disponibilité de pratique suit la source, la paire et le sens choisi.
Le compteur et le chargeur utilisent les mêmes critères de carte jouable,
avec une variante de réponse active. La feuille distribue les cartes annoncées
une fois chacune et complète, si nécessaire, depuis l'autre sens ou depuis
les cartes déjà planifiées de la liste sélectionnée. Le configurateur de
liste conserve ses répétitions lorsqu'il complète un paquet court.
Si la dernière carte disparaît avant le chargement, le quiz affiche un état
vide récupérable.

Les tests d'intégration de récupération, d'envoi et d'export/import servent de
preuves exécutables. La validation sur deux appareils reste nécessaire avant
une ouverture bêta.
