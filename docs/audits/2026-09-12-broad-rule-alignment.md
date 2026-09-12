# Audit étendu — alignement règles, documentation et code

**Date :** 12 septembre 2026  
**Périmètre :** règles produit, UX, contenu, données, synchronisation, sécurité, CI et état V0. Ce document complète l'[audit ciblé V0](2026-09-12-doc-code-alignment.md).

## Lecture rapide

Le socle d'apprentissage est solide : listes libres, quiz, calcul de maîtrise, prérequis hybrides, persistance locale et synchronisation sont réellement implémentés et testés. Les décisions V0 récentes sont bien reprises là où elles ont été intégrées.

Le principal décalage est que les documents de design décrivent largement l'expérience V2 alors que l'application garde encore le shell et les parcours V1. Les écarts de préchargement initial et de contrôle statique ont été corrigés après cet audit.

Légende : **conforme** = livré ; **partiel** = base présente mais incomplète ; **à construire** = décision confirmée mais non livrée ; **à arbitrer** = contradiction réelle ; **différé V0** = hors périmètre volontaire.

## Matrice des règles produit

| Sujet | Constat dans le code | État | Suite recommandée |
|---|---|---|---|
| Pratique libre sans cursus obligatoire | Création/import de liste, ajout de mots et quiz immédiat, y compris pour des mots jamais vus. | **Conforme** | Conserver cette séparation nette avec le parcours guidé. |
| Pré-requis de leçon | Règle appliquée : 80 % pondérés au total et 70 % minimum dans chaque liste requise. Messages FR/EN/KO et tests couvrent le cas 100 % + 60 %. | **Conforme** | Aucune action. |
| Quiz et répétition espacée | Modes de quiz, FSRS, auto-évaluation et statistiques existent. | **Conforme** | Consolider lors de la future refonte visuelle. |
| Drills de grammaire | Les drills sont construits localement, de façon déterministe, depuis les règles et les mots maîtrisés. Le client n'appelle plus de fonction LLM à chaque session. | **Conforme** | Le LLM peut rester un outil interne de rédaction, jamais une dépendance runtime. |
| Chemin quotidien optionnel | L'accueil affiche une amorce « Chemin du jour », mais sans plan figé, route dédiée, achèvement ou streak par paire. | **Partiel** | Construire une verticale complète après le shell V2. |
| Leçons, exemples et popups | Panneau de démarrage de grammaire présent, mais pas de lecteur multi-écrans, popup contextuelle ou restauration du focus. | **À construire** | À inclure dans la verticale leçon. |
| Flashcards inclinées et swipe | Quiz actuel à bouton/carte retournable, sans pile inclinée ni swipe horizontal. | **À construire** | Limiter la pile aux quiz, comme décidé. |
| Langues V0 | Sélecteur quotidien limité à FR→KO, EN→KO et KO→FR ; noyau et listes libres génériques sur six langues. | **Partiel** | Borner clairement l'offre V0 dans l'interface. |
| Interface coréenne | Traductions KO présentes ; sept locales restent techniquement activables. | **Partiel** | Vérifier les écrans V2 en KO. |
| Contenu KO→FR | Packs présents, mais contextes pédagogiques de grammaire rédigés en FR/EN seulement. | **Bloquant contenu beta** | Écrire les explications et exemples KO. |

## UX et navigation

| Règle décidée | Constat | État |
|---|---|---|
| Cinq entrées égales, sans bouton central | AppShell garde quatre onglets et un bouton central « Study ». | **À construire** |
| Navigation par plongée/zoom | Transitions Material par défaut, sans Hero ou transition de plongée systématique. | **À construire** |
| Popups pour approfondir une leçon | Le composant pédagogique n'existe pas encore. | **À construire** |
| Scroll réduit mais signalé | Pas d'indicateur visuel ou flèche sur les écrans à liste. | **À construire** |
| Retour à l'origine après exploration | Certains flux utilisent go et remplacent l'historique. | **Partiel** |
| Préchargeur réellement prêt | Splash fixe de 1,6 s, sans attendre données, seeds ou synchro. | **À corriger** |

Les maps de design signalent parfois ces choix comme « validés », mais elles ne décrivent donc pas encore l'état livré. À l'inverse, navigation.md se déclare encore « proposed » : les statuts documentaires ne sont pas cohérents.

## Données, contenu et documentation

| Sujet | Constat | État |
|---|---|---|
| Modèle multi-langue | Concepts, listes, tests et seeds sont génériques. | **Conforme** |
| Règles de grammaire | Assets : FR=4, EN=4, ES=4, DE=4, IT=4, KO=5 ; grammar-flow.md annonce encore cinq règles A1 par langue latine. | **Doc à corriger** |
| Édition des listes cursus | Évoquée comme conséquence à valider ; pas de statut seeded/lecture seule côté code. | **Décision ouverte** |
| Contribution de contenu | Des docs pointent vers .claude/skills et .claude/agents ; le dépôt utilise .agents/skills/seed-content. | **Doc à corriger** |
| Couverture prérequis | feature-coverage.md mentionne l'ancien helper isListKnown, pas la règle hybride actuelle. | **Doc à corriger** |
| Queue de sync | Certains scénarios la disent future, alors que PushSync et file locale existent et sont testés. | **Doc à corriger** |
| CEFR dans l'interface | feature-roadmap.md les prévoit visibles, progres-suivi.md dit qu'ils ne doivent pas l'être. | **Doc à arbitrer** |
| Révision et mots inconnus | implementation-plan-v2.md interdit encore les mots inconnus en révision, contrairement à la pratique libre sans gate. | **Doc à corriger** |

## Robustesse, builds et sécurité

| Sujet | Constat | État | Suite recommandée |
|---|---|---|---|
| Tests unitaires | flutter test test/unit : **368 passés**. | **Conforme** | Continuer à protéger les règles métier. |
| Tests d'intégration | flutter test test/integration : **159 passés**. | **Conforme** | Ajouter les scénarios du chemin quotidien. |
| Validation des seeds | flutter test test/seed : **9 passés**. | **Conforme** | Exiger ce contrôle pour chaque contenu. |
| Analyse statique complète | Helper Patrol aligné sur les paramètres génériques ; ancien patch Linux non résolu exclu de l'analyse (la dépendance active vient de pub.dev). | **Conforme** | Garder l'exclusion tant que le patch local n'est pas supprimé. |
| CI | Tests et seuil de couverture 47,5 %, mais pas d'analyse, formatage ou build de vérification. | **Partiel** | Bloquer les PR sur analyse + tests, puis ajouter un build Android. |
| Authentification | Email/mot de passe branché ; Google, Apple et suppression de compte explicitement non configurés. | **Partiel** | Ne pas les annoncer avant configuration complète. |
| Offline et sync | Drift, file locale, pull/push et protection contre l'écrasement local sont présents et testés. | **Conforme pour le socle** | Tester deux appareils et les conflits concurrents. |
| Fonctions Supabase | Les proxys voix et fonctions LLM existent ; réglages déployés JWT, limites et rate limiting non vérifiables depuis le dépôt. | **À vérifier avant bêta** | Audit de configuration et quotas/coûts. |
| RevenueCat | Workflows de build avec valeur factice YOUR_REVENUECAT_KEY. | **Différé V0** | Masquer le paiement V0 ou injecter la clé au lancement commercial. |

Social, abonnements et paywall sont bien présents dans le code mais restent **différés V0** par choix produit. Il ne faut pas les développer maintenant ; il faut surtout les masquer ou les présenter comme hors bêta.

## Priorités proposées

1. **Rétablir une documentation canonique.** Corriger les fichiers obsolètes et créer un registre court des décisions V0 avec source et date.
2. **Livrer une verticale V0 visible.** Shell cinq entrées, chemin quotidien optionnel, leçon avec gate/popup, puis quiz en pile avec swipe.
3. **Préparer KO→FR.** Contextes pédagogiques KO, localisation des nouveaux écrans et test de synchronisation sur deux appareils.
4. **Avant ouverture externe.** Auth réellement annoncée, quotas/sécurité Supabase, et fonctions social/paiement masquées.

## Conclusion

Le projet n'a pas un problème de fondation : moteur métier et données sont en bonne forme. Il faut surtout rendre les spécifications fiables, régler deux contradictions concrètes, puis livrer l'expérience V2 en tranches verticales plutôt que d'étendre encore des écrans V1.
