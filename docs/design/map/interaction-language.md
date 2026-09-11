# Langage d'interaction — plonger, réviser, approfondir

**Statut : 🟢 décidé (utilisateur, 2026-09-11)** · règle transverse de
navigation, de leçon et de quiz.

Ce document définit la métaphore à employer selon l'intention de l'action.
Elle évite d'utiliser la carte comme décoration générique : une carte ne
représente une pile physique que lorsqu'on révise réellement des flashcards.

## Décidé (utilisateur, 2026-09-11)

### 1. Ouvrir un écran = plonger dans l'élément

- Pour la navigation courante — ouvrir une liste, un niveau, une fiche,
  les réglages, le setup d'un quiz ou une autre destination — la transition
  donne l'impression de **plonger dans l'élément touché**.
- L'élément source se développe et devient l'écran de destination ; le retour
  fait le mouvement inverse vers la source réelle.
- Ces destinations ne sont pas des cartes empilées ou inclinées. Leur mise en
  page reste une surface d'application normale, adaptée au contenu.
- La transition sert à établir la continuité spatiale, pas à retarder l'action :
  elle doit rester brève, interruptible, et être remplacée par un fondu simple
  si `prefers-reduced-motion` est actif.

### 2. Réviser un quiz = dépiler des flashcards

- La pile de cartes légèrement inclinées est réservée aux **quiz et révisions
  de vocabulaire**, où elle représente littéralement les flashcards à traiter.
- Une seule carte est active ; les tranches des suivantes rendent visible ce
  qu'il reste. Après une réponse, la carte quitte la pile puis la suivante
  devient active.
- Cette métaphore ne s'étend pas au setup, aux listes, au parcours, aux
  réglages ou aux écrans d'ouverture de session.

### 3. Approfondir un exemple de leçon = ouvrir une carte contextuelle

- Une leçon est une surface de lecture, pas une pile. Un exemple, un mot ou
  une règle peut toutefois être cliquable.
- Cette action ouvre une **carte-popup contextuelle** qui apporte l'information
  complémentaire sans faire perdre la position dans la leçon : détail de
  l'exemple, variante, traduction, explication ou audio.
- À la fermeture, la leçon réapparaît exactement au même point. La popup a un
  bouton fermer explicite, se ferme avec Échap, rend le focus au déclencheur
  et ne doit pas contenir une pile de navigation.

### 4. Scroll = rare mais toujours annoncé

- Le scroll est réduit autant que possible, sans être interdit. Il est admis
  lorsqu'il conserve un contenu lisible et évite de le découper artificiellement
  (leçon longue, liste, réglages, détail riche).
- Lorsqu'une surface est scrollable, cet état doit être perceptible sans essai :
  contenu qui se prolonge sous le bord, chevron vers le bas, ou libellé bref
  selon le contexte. Le seul bord coupé ne doit pas masquer une action primaire.
- Les contenus courts et les étapes d'un quiz restent entièrement visibles
  autant que possible. Une taille de texte système augmentée doit pouvoir
  introduire un scroll plutôt que couper ou réduire le texte.

## Raccourci de décision

| Intention utilisateur | Traitement visuel |
| --- | --- |
| Aller vers une destination | plongée / zoom depuis l'élément touché |
| Répondre à une série de mots | pile de flashcards à dépiler |
| Lire plus sur un élément de leçon | carte-popup contextuelle |
| Lire un contenu réellement long | scroll visible et signalé |

Liens : [[navigation]] · [[quiz-canvas]] · [[lesson-viewer]] ·
[[pratique-libre]]
