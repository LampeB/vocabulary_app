# État actuel — documentation, V3 et V0

**Date : 29 septembre 2026**

## Verdict

Le noyau métier est cohérent et les règles de prérequis restent correctement
implémentées. La documentation n'était toutefois plus synchronisée avec les
lots V3, voix/audio et tests livrés après les audits du 12 septembre.

Cette note est un constat de transition ; `PROJECT_STATUS.md` et
`design/v3-sentier-de-cartes.md` deviennent les points d'entrée vivants.

## Ce qui est livré et vérifiable

- Listes libres et quiz direct, sans cursus obligatoire.
- Gate de leçon : 80 % pondéré de mots gradués, avec au moins 70 % dans chaque
  liste prérequise.
- Paires V0 sélectionnables : FR→KO, EN→KO et KO→FR.
- Slice V3 fonctionnelle : entrée, plateau, chemin quotidien, liste,
  configurateur, flashcards/mains-libres et bilan.
- Architecture voix : `VoiceTurnMachine`, `AudioDirector`, `SttRace`,
  adaptateurs système/Whisper/ElevenLabs et laboratoire de corpus.
- Audio quiz : assets pré-générés, cache local et nettoyage des clips dormants.
- CI hôte sur chaque push/PR ; neuf suites Patrol Android sont disponibles par
  déclenchement manuel.

## Ce qui reste partiel ou non livré

- La boucle pédagogique V0 complète : découverte, écho non noté, plan quotidien
  figé/persistant, vraie complétion et validation sur appareil des trois paires.
- Le contenu relu KO→FR, les pages de leçon et les popups contextuels.
- Localisation FR/EN/KO exhaustive et thème clair exhaustif pour V3.
- Application stricte de plongée, de la règle « pile uniquement au quiz » et de
  l'indication de scroll.
- Validation visuelle V3 et essais réels microphone/réseau/deux appareils.

## Corrections documentaires faites avec ce lot

- Création d'un portail `docs/README.md` et mise à jour de `PROJECT_STATUS.md`.
- Ajout de la spécification V3 versionnée.
- Les plans V0, voix/STT et couverture de test indiquent désormais clairement
  leur statut et leurs limites ; les documents historiques restent datés.
