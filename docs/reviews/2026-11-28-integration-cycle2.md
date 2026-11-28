# Intégration — deuxième cycle, 28 novembre 2026

## Ouverture autorisée

L'utilisateur demande de mettre en place les corrections renforcées tout en
conservant la liberté des relecteurs, puis de relancer un cycle de vingt
passes. La [décision](../decisions/2026-11-28-review-corrections-and-cycles.md)
et la [spécification](../pr-validation.md) en fixent les limites.

Le [premier cycle](2026-11-27-integration.md) reste conservé avec ses vingt
passes non convergées. Ses derniers constats sont corrigés dans
`48b12ee21c22bb20c3f005078c20b41e1edd72c6` : 1 249 tests hôte, analyse
propre, couverture 76,0 % et huit checks CI verts. Ce résultat ne constitue
aucune passe propre indépendante du deuxième cycle.

## Préparation du premier candidat

- Missions des quatre relecteurs maintenues ouvertes ; zones examinées et
  limites brièvement rapportées, sans grille exhaustive obligatoire.
- Profil de correction versionné : cause/invariant, recherche de réutilisation,
  cas voisins et consommateurs partagés, effets du changement et preuves
  pertinentes, dans les fichiers attribués et sans décision produit inventée.
- Identifiants stables `C2-P<pass>-<numéro>` pour les constats consolidés ;
  rapports originaux et doublons conservés avec leur sévérité.
- Preuve du bot version 2 : cycle explicite commun aux huit rapports, deux
  passes consécutives 1–20 sur la même tête/base, attestation du propriétaire
  et provenance des huit checks CI. Les 26 tests du bot passent localement.

La première passe du cycle 2 (relecture cumulée 21) commence après le commit
commun de ces consignes et de leur garde. Aucun verdict n'est acquis à
l'ouverture : **0/2**, plafond **20 passes par profil**. Aucun mélange de cycles
ou réemploi d'un verdict d'une ancienne tête n'est autorisé.

Tous les constats Bloquant et Important d'une passe sont réunis avant les
corrections. Les modifications du lot sont livrées ensemble, puis les quatre
instances fraîches relisent le nouveau SHA. Une nouvelle modification remet
les compteurs propres à zéro. Deux passes collectives propres sur un même
commit permettent l'approbation, puis la fusion protégée lorsque la CI est
verte. Un troisième cycle exige une nouvelle décision utilisateur.
