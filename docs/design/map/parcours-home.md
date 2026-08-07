# Accueil : page langue + parcours A1→C2

**Statut : 🟢 modèle décidé · 🟠 détails proposés** · écran S1 · flux F0/F10 ·
spec : `../v2-ux-architecture.md §6.1` · wireframe : `../diagrams/v2-home-parcours.svg`

## Décidé (utilisateur, 2026-08-06)
- L'accueil montre la langue courante (la dernière étudiée si plusieurs)
- Carte d'aperçu de la progression en tête
- Parcours A1→C2 : cartes de niveau extensibles, progression x/20 leçons
- Carte étendue = liste scrollable des leçons, fenêtrée autour de la
  courante (ex. à la 7ᵉ : 5-6-7-8-9, 5 et 6 cochées)
- Démarrer un niveau supérieur exige de réussir un test prouvant la
  maîtrise des niveaux précédents
- (2026-08-07) L'accueil porte une carte « Chemin du jour » qui OUVRE
  l'écran dédié S18 — le jour ne vit plus dans une carte aperçu
- (2026-08-07) L'onglet « Étudier » est branché sur les quiz et les
  leçons de grammaire — nouvel écran requis (l'actuel setup est trop
  encombré) ; 🟠 supposé : cet onglet EST l'accueil et porte chemin +
  progression + parcours

## Proposé — pas encore vetté (Claude)
- Carte Chemin du jour : pastilles ● ○ ○ ○, prochaine étape, chip
  Continuer, chevron ; carte progression séparée (position CEFR + barre) ;
  bilan hebdo se glisse au-dessus le dimanche
- Série (flamme) dans l'en-tête — la carte héro sombre v1 meurt
- Sélecteur de langue = chip drapeau + autonyme dans l'en-tête
- Nœuds de 3 types : Vocabulaire · Grammaire (règle) · Mélange
- Niveaux partiellement remplis autorisés (« 13 leçons disponibles »)
- Une « leçon » ne compte que les moments d'apprentissage (jamais les
  révisions FSRS)

## À trancher 🔴
- Cartes de niveau vs sentier sinueux façon Duolingo (Q1 — reco : cartes)
- « Voir les 20 leçons » : inline vs bottom sheet (Q5)
- Visibilité du test de saut sur niveau verrouillé (Q6)
- Groupes de grammaire : 6 nœuds plats vs sous-carte de groupe (Q7)

Liens : [[daily-chain]] · [[level-test]] · [[grammar-flow]] · [[vocab-flow]]
