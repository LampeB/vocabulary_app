# V3 — Sentier de cartes

**Statut : implémentation partielle, référence active au 29 septembre 2026.**

Cette note est la référence versionnée du design V3. Le code Flutter et cette
note décrivent ce qui est réellement livré ; le prototype HTML du plateau ne
sert qu'à discuter l'intention visuelle.

## Intention

V3 est un environnement calme d'étang : fond vert sombre, ondulations lentes,
surfaces papier, typographie DM Serif Display pour les titres, Space Grotesk
pour le corps, Space Mono pour les libellés et Noto Serif KR pour le coréen.

La métaphore ne doit pas transformer toute l'application en collection de
cartes :

| Intention | Traitement V3 voulu |
| --- | --- |
| Ouvrir une destination | plongée/zoom court depuis l'élément sélectionné |
| Réviser une série de vocabulaire | pile de flashcards fixe, flip puis swipe |
| Approfondir un exemple de leçon | popup contextuelle, sans perdre la lecture |
| Lire beaucoup de contenu | scroll réduit et explicitement annoncé |

La règle détaillée demeure [interaction-language.md](map/interaction-language.md).

## Slice V3 actuellement livrée

| Étape | Écran / code | État |
| --- | --- | --- |
| Préchargement | `SplashScreen` | attend la restauration d'authentification puis le seed local avant de quitter l'écran |
| Entrée | `WelcomeScreen`, `AuthScreen` | V3, clair/sombre |
| Plateau | `V3HomeScreen` | paire active, activité du jour, parcours, listes et activité libre |
| Chemin du jour | `DailyPathScreen` | révisions dues, entrée de liste et entrée Leçons ; le chemin reste optionnel |
| Liste/prérequis | `ListDetailScreen` | liste, pratique flashcards, mains-libres et ajout de mot |
| Configuration | `StartSessionScreen` | langue → liste/source → mode → sens → quantité |
| Pratique libre du plateau | `FreePracticeSheet` | feuille Quoi → Sens → Mode, paire de l'en-tête et lancement direct |
| Révision | `QuizScreen` en flashcards ou mains-libres | pile, flip, swipe, mains-libres et bilan |

Les points d'entrée fonctionnels de cette slice sont donc continus. Cela ne
signifie pas que la définition de sortie de la boucle V0 complète est atteinte
(voir `../v0-daily-loop-plan.md`).

### Corrections d'intégration — 27 novembre 2026

- Après comparaison, l'utilisateur confirme la feuille à trois choix pour
  la pratique libre du plateau. Son contrat est dans
  [pratique-libre.md](map/pratique-libre.md). Le configurateur complet demeure
  celui des leçons et des autres entrées existantes.

- Le détail d'une liste affiche et modifie les deux langues dans leur ordre
  `langA` → `langB`. Les suggestions thématiques utilisent cette même paire
  pour leur contexte, leur requête et l'ajout des variantes.
- Le choix bidirectionnel utilise « Les deux sens » pour toute paire. Les
  anciens bilans, qui ne conservent pas les deux codes de langue, affichent
  le sens relatif de la liste au lieu d'affirmer FR/KR.
- Le contexte des suggestions est chargé par une requête groupée et borné
  aux limites du service. Un ajout multiple conserve les mots refusés dans
  la sélection, indique les ajouts réussis et propose l'écran d'abonnement
  lorsque le quota local est atteint ; il ne ferme pas silencieusement la feuille.
- Le bouton de pratique d'une leçon transmet sa règle exacte et sa paire au
  configurateur, qui les conserve dans le quiz. Une leçon française ne doit
  jamais basculer dans le curriculum coréen.
- Les flashcards gardent le glissement et proposent aussi deux boutons de
  notation localisés, accessibles au clavier et aux lecteurs d'écran.
  Le bouton de révision associe un texte et un fond contrastés dans les deux
  thèmes.
- Le nombre choisi pour une révision des cartes dues sert de plafond.
  La session ne répète pas une carte pour remplir les places restantes.
- Le plateau distingue mots/listes disponibles et acquis. L'absence de cartes
  dues ne prouve aucune activité terminée : le chemin montre une recommandation
  sans faux compteur de complétion ni estimation de mots inédits.
  Un chargement ou un échec du compteur ne vaut pas zéro : le plateau, le chemin
  et le configurateur distinguent ces états, proposent une relance locale en
  cas d'échec, et conservent les entrées indépendantes vers listes et leçons.
  Les options des sélecteurs de langues utilisent les autonymes du helper
  commun, y compris dans le formulaire de création d'une liste ; les consignes
  rédigées dans la langue de l'interface conservent leurs noms traduits.
- Les feuilles papier du plateau utilisent une encre explicite dans les deux
  thèmes. Les ondulations s'arrêtent avec la réduction des animations ou un
  sous-arbre inactif ; le prototype de parcours sans route est retiré.
- Le verdict conserve ses fonds de couleur, avec texte et rappel contrastés.
  Continuer est un bouton focalisable : une seconde activation Entrée après
  la réponse fait avancer la révision. La paire d'une nouvelle liste libre
  est mémorisée sans changer le contexte guidé choisi dans l'en-tête.

- Le bootstrap reste observé au-dessus du routeur : un import froid et un
  changement de paire d'en-tête déclenchent aussi le seeding local. L'import
  peut avancer dès que l'identité locale est connue, avant le profil distant.
- La connexion et la restauration peuvent utiliser l'identité locale lorsque
  le profil distant est indisponible. Un rafraîchissement échoué conserve le
  dernier profil enrichi du compte actif, dont le nom choisi, la série et
  l'abonnement. Seule une lecture réussie sans ligne déclenche une création
  conditionnelle. Une création concurrente est relue et conservée ; une ancienne
  réponse ne peut enrichir un autre compte ni une session fermée.
  Un échec temporaire du renouvellement du jeton conserve la session locale ;
  un événement de déconnexion du SDK reste appliqué normalement.
- Le lien initial et sa première répétition dans le stream ne sont traités
  qu'une fois ; les liens ouverts ensuite restent disponibles.
- Après un import froid, Retour depuis la liste mène à la bibliothèque.
  Après un lien ouvert dans l'application, il retrouve l'écran d'entrée.
- Les deux entrées de préparation d'une liste depuis le chemin quotidien
  poussent la bibliothèque sur la pile : son bouton Retour retrouve le chemin.
- Deux imports successifs conservent chacun leur résultat dans leur route.
  Un import recouvert attend de redevenir visible avant d'ouvrir son détail
  ou d'afficher son erreur ; il ne remplace ni ne dépile l'import suivant.
- Les feuilles de paire et de mode utilisent le signal de défilement commun
  lorsqu'un choix dépasse de leur surface, visible dès l'ouverture à texte
  doublé en paysage. Les erreurs de reset distinguent réseau et fréquence ;
  les autres échecs utilisent un texte neutre, sans conclure que l'adresse
  n'existe pas.
- Le dialogue de reset place son titre, son champ et ses actions dans une
  surface défilante signalée. Les actions restent atteignables à 568 × 320,
  texte doublé et clavier de 180 pixels, dans les trois locales V0.
- Chaque route de quiz possède sa séance : ouvrir un quiz depuis le détail
  d'un import ne remplace ni les cartes, ni le score, ni la pause du quiz
  recouvert. Seule la route visible peut écouter. Une fermeture en attente
  d'arrêt audio attend de retrouver sa propre route avant de la dépiler.
- Les actions d'inscription et de connexion de l'accueil, puis la validation
  du formulaire, sont des boutons accessibles par Tab et Entrée.
- Les deux commandes par icône du pied de liste ont des noms localisés
  distincts pour les lecteurs d'écran. Leurs fonds, comme celui du bouton
  de connexion de l'accueil, sont explicites dans les deux thèmes : l'encre
  claire ne repose plus sur un fond blanc translucide en thème sombre.
- Les erreurs d'authentification sont traduites dans l'interface à partir de
  motifs indépendants de la langue (identifiants, pseudo/e-mail déjà utilisé,
  confirmation, fréquence, réseau). Un message brut du fournisseur n'est pas
  affiché. Les compteurs de révision indiquent des cartes jouables : un concept
  dû dans les deux sens représente deux cartes, pas deux mots.
  Le texte d'erreur de connexion, les validations de formulaire et l'action
  d'envoi du reset atteignent 4,5:1 sur leurs surfaces rendues dans les deux
  thèmes. L'encre d'erreur et son contraste inverse sont adaptés au thème ;
  une teinte d'accent utilisée en fond ne sert pas directement au petit texte.
- Un échec technique de lecture des cartes affiche un message générique
  FR/EN/KO ; son détail reste réservé au diagnostic debug. Le bouton Retour
  est focalisable et retrouve l'écran d'origine avec Tab puis Entrée. Les
  messages dédiés de changement de compte et de grammaire écrite restent distincts.
  Cette frontière couvre aussi les exceptions après sélection des cartes,
  pendant leur enrichissement SQLite ou le chargement de grammaire. Un
  ancien chargement qui échoue ne peut pas remplacer une séance plus récente.
- Les aides de détail de leçon et les traductions d'aperçu du configurateur
  atteignent au moins 4,5:1 sur leur surface effectivement rendue, dans les
  deux thèmes ; le contraste tient compte de l'encre et du fond teinté.
  Les titres de groupes de listes respectent le même seuil. L'explication
  d'une règle limitée à l'écrit reste lisible sans subir l'opacité de son
  option vocale désactivée.
  Les consignes de langue des modes Écrit et Voix utilisent aussi une encre
  de petit texte adaptée au papier texturé en clair, et une encre claire en
  sombre. Le statut hors ligne du shell conserve son fond orange avec texte
  et icône foncés ; les mesures de texte rendu atteignent 4,5:1 dans les deux
  thèmes. Ces corrections ne déclarent pas la migration V3 du shell terminée.
- La série compare des dates civiles, y compris lors des journées de 23 ou
  25 heures. La fin de quiz et le suivi social utilisent le même calcul.
- Au bilan, le quiz capture le compte, les résultats et le jour civil. Son
  historique SQLite reste enregistré quand l'utilisateur quitte le bilan ou
  relance un quiz pendant la lecture du nom de la liste ou de la maîtrise.
  Si le compte est encore connecté, la série utilise le jour de fin du quiz,
  même lorsque la lecture du profil traverse minuit. Une date de profil
  déjà plus récente est préservée. Le client envoie le compte et le jour à
  `record_study_day` ; le serveur conserve ces journées de façon idempotente
  et recalcule la série dans la même transaction, même lorsqu'une journée
  plus ancienne arrive après la suivante. Le record acquis est conservé.
- Le bilan signale son défilement avant le premier geste lorsque son contenu
  dépasse l'écran ; Recommencer et Retour restent atteignables à texte doublé.
- La popup d'exemple suit le même principe : titre, traduction et fermeture
  défilent ensemble avec un signal visible en cas de débordement. Le libellé
  d'approfondissement revient à la ligne si nécessaire ; fermer la popup
  restitue la position de la leçon.
- Le squelette du splash s'adapte au paysage. Le splash et le verdict peuvent
  défiler lorsque la hauteur ou le texte agrandi l'exigent, avec un signal de
  défilement ; Continuer reste atteignable à 320 × 568, texte doublé.
- L'aperçu de leçon du configurateur défile aussi avec un signal explicite :
  le contenu réel et son bouton de pratique restent accessibles à 320 × 568,
  texte doublé. Les libellés des sections peuvent revenir à la ligne.
- Le bouton de lancement du configurateur garde un minimum de 52 pixels et
  grandit avec son libellé ; le pied réserve sa hauteur réelle. Le texte
  « Commencer · 100 cartes » reste entier à 320 × 568 et texte doublé,
  sans recouvrir le contenu, puis lance la quantité choisie.
- Dans le lecteur de leçon, une hauteur disponible inférieure à 400 pixels
  ou un titre agrandi d'au moins 50 % place le titre, la page et la pagination
  dans le même défilement signalé.
  Le contenu garde un espace de lecture dans le shell en paysage à texte
  doublé ; le swipe horizontal, Précédent/Suivant et la pratique restent actifs.
- Les titres du configurateur et du détail de liste font partie du contenu
  défilant : leur hauteur suit les grandes polices et les noms longs, sans
  rognage par la barre d'application. Les commandes Retour des parcours
  liste/leçon/configuration exposent un libellé localisé aux lecteurs d'écran.
- Un prérequis absent utilise le libellé localisé du catalogue. Une liste
  résolue garde son nom, même si ses statistiques ne sont pas disponibles ;
  aucun identifiant technique n'est affiché à l'apprenant.
- La feuille compte les cartes jouables pour la source, la paire et le sens
  choisis avant d'activer le lancement. Un pool devenu vide au chargement
  propose Réessayer ou Retour, sans produire un bilan à zéro.
- Le titre et les mots de l'aperçu partagent un défilement signalé et paresseux.
  Le signal se met à jour après chargement ou redimensionnement sans geste.
- Les locales partielles DE/ES/IT/JA utilisent les chaînes françaises de repli
  lorsque leur copie manque, via la configuration de localisation commune.
  Cela ne vaut pas traduction complète de ces parcours hors V0.

## Limites connues à corriger avant de qualifier V3 de complète

1. **Localisation.** Les textes du plateau, chemin, accueil/auth et splash,
   ainsi que les commandes de sortie, passent par les traductions FR/EN/KO.
   L'audit des autres flux de révision reste à compléter avant livraison V0.
2. **Thèmes.** Les entrées, la liste et le canvas de révision supportent les
   deux thèmes, mais le plateau, le chemin quotidien et le splash utilisent
   encore volontairement une surface sombre V3. Il faut soit concevoir leur
   variante claire, soit expliciter que le plateau est toujours sombre.
3. **Piles hors quiz.** Les ornements de feuilles/piles du plateau et du chemin
   sont retirés. La pile physique inclinée reste réservée aux flashcards.
4. **Plongée et scroll.** La transition `DiveInPage` couvre le chemin quotidien
   et le lecteur de grammaire, pas toutes les destinations V3. Le plateau et
   le chemin signalent désormais leur scroll. Le chemin utilise des hauteurs
   intrinsèques : les textes agrandis peuvent défiler sans chevauchement.
5. **Leçons.** Le lecteur existe, mais la leçon V0 complète (pages validées,
   popup d'exemple, écho non noté, contenu KO→FR relu) n'est pas terminée.
6. **Tests visuels.** Les tests couvrent les comportements et les routes, pas
   une validation screenshot/golden du rendu V3 sur les deux thèmes et trois
   locales. Un test de régression vérifie néanmoins le chemin à 320 × 568,
   texte doublé, en français, anglais et coréen.

## Sources et code

- Palette partagée : `lib/core/theme/v3_colors.dart`.
- Plateau et ondulations : `lib/presentation/screens/home/v3_home_screen.dart`
  et `lib/presentation/widgets/v3_pond.dart`.
- Révision : `lib/presentation/design/v3/` et
  `lib/presentation/screens/quiz/quiz_screen.dart`.
- Aperçu HTML du plateau : `mockups/v3-home-plateau-preview.html`.

Les écrans non migrés doivent être conçus à partir de ces règles et des
décisions de [map/](map/app-map.md), pas à partir d'anciens prototypes.
