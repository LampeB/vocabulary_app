# Budget des fournisseurs IA — bêta

Cette procédure applique la décision de la note
[STT et audio](../stt-improvement-plan.md) : un seul testeur, budget de
**20 EUR/mois**, alerte à 12 EUR, restriction à 16 EUR et arrêt des appels
cloud à 20 EUR.

## Avant de tester

1. Dans chaque tableau de bord Anthropic, OpenAI et ElevenLabs, configurer une
   alerte à 12 EUR équivalent et un plafond mensuel à 20 EUR lorsqu'il est
   proposé. Les fournisseurs facturent parfois en USD : convertir ce seuil
   prudemment et conserver une marge.
2. Déployer les migrations, dont `010_provider_quota_buckets.sql` et
   `012_security_boundaries.sql`, avant les Edge
   Functions. Sans elle, les fonctions échouent fermées (`503`) plutôt que
   d'appeler un fournisseur sans limite.
   L'API de quotas n'est exécutable que par `service_role` : les fonctions
   valident la session avec Auth, puis transmettent l'identité vérifiée au
   serveur. Les seuils sont définis dans SQL, jamais dans le client.
   Le bail de génération audio et les nouvelles règles Storage sont requis
   avant le nouveau provisionnement.
3. Vérifier qu'aucune clé fournisseur n'est présente dans `.env.json`, les
   journaux ou l'application. Elles restent exclusivement dans les secrets
   Supabase.
4. Déployer le tombstone HTTP 410 de `elevenlabs-proxy` ou supprimer cette
   fonction du projet hébergé. Le client actuel ne l'appelle plus ; conserver
   son ancienne version déployée laisserait un contournement des quotas.

## Préparer et déployer les Edge Functions

La CI et le déploiement utilisent Deno **2.9.6** et le même
[verrou versionné](../../supabase/functions/deno.lock). Les imports fixent
SupabaseJS à **2.119.2** et Anthropic à **1.14.0**, et le verrou fixe les
versions et les empreintes de leurs dépendances transitives.
[Verrouillage Deno](https://docs.deno.com/runtime/packages/#lockfile-and-reproducible-installs).

Depuis la racine du dépôt, lancer `python3 tool/deploy-edge-functions.py`.
Le script vérifie les types, exécute les tests avec `--frozen`, prépare les
bundles verrouillés et démarre leurs points d'entrée dans un test sans accès
réseau ni résolution npm. Les bundles temporaires sont supprimés à la fin.
[Bundling Deno](https://docs.deno.com/runtime/reference/bundling/).

Une fois les migrations requises appliquées sur le projet ciblé, utiliser
la CLI Supabase (version 3.4 ou ultérieure), authentifiée localement, puis
`python3 tool/deploy-edge-functions.py --project-ref <ref-du-projet>`. Le script
vérifie à nouveau les bundles et transmet à la CLI uniquement les points
d'entrée autonomes de son dossier temporaire. La CLI demande confirmation
pour le projet désigné. Utiliser ce chemin pour éviter un nouveau calcul du
graphe par le service de déploiement.
[Déploiement Supabase](https://supabase.com/docs/reference/cli/supabase-functions-deploy).

Pour une mise à jour de dépendance, modifier les imports exacts, puis lancer
`deno check --config supabase/functions/deno.json --frozen=false supabase/functions/*/index.ts`.
Relire le diff du verrou et repasser le script sans projet avant de commiter.

## Frontières des contenus et des audios

- Les corps JSON des assistants sont lus en flux, avec un maximum de 32 Kio
  et 5 secondes. Un mot facturé est limité à 256 caractères ; les contextes,
  listes et règles ont aussi des bornes avant tout débit de quota.
- Les appels IA et TTS ont un délai de 60 secondes sans retry automatique
  Anthropic. Deux demandes du même clip manquant partagent une réservation
  SQL exclusive de 90 secondes ; le cache est revérifié après réservation.
- Le provisionnement utilisateur écrit exclusivement sous `users/<UUID>/`.
  Le champ `origin` d'une liste n'autorise jamais une publication sous `seed/`.
  Seul `seed-audio-publish`, administrateur, publie le catalogue partagé.
  La lecture partagée exige aussi une entrée dans `published_audio_assets`,
  écrite uniquement par ce publieur. Après migration, republier le catalogue
  pour établir ce manifeste : les anciens objets sous `seed/` non attestés
  cessent d'être publics, y compris ceux qui auraient contenu un texte privé.
- Storage vérifie le propriétaire dans le chemin privé généré côté serveur,
  indépendamment du champ `audio_path` modifiable dans une variante. Les
  audios publiés du catalogue restent lisibles aux utilisateurs authentifiés.
  Sur l'appareil, les accès aux clips privés vérifient également le propriétaire
  avant de consulter le disque ou les téléchargements en cours. Les noms du
  cache écartent les anciens fichiers créés avant le manifeste de publication.
- La migration 012 crée également `review_events` et sa politique limitée au
  propriétaire ; un historique ne peut pas être écrit ou lu pour un autre compte.

## Pendant la bêta

- Les deux moteurs STT cloud partagent **300 requêtes par jour UTC** et
  **80 par heure UTC**, ainsi qu'une seule requête simultanée par utilisateur.
  Le bail serveur dure 90 secondes et se libère à la fin de chaque requête ;
  les appels fournisseur sont interrompus après 60 secondes, les uploads après
  5 secondes. Un crash conserve le verrou jusqu'à son expiration.
- Les captures acceptées sont du PCM16 mono 16 kHz (brut ElevenLabs ou WAV).
  Le serveur vérifie leur format et les **30 secondes réelles** ; une simple
  limite d'octets ne suffit pas pour un format compressé ou un autre débit.
- Les deux proxys bornent `expected_word` à 256 caractères avant le débit de
  quota ou l'appel au fournisseur. Le champ reste facultatif.
- Les limites quotidiennes restantes sont : traduction 200, suggestions 25,
  grammaire 20 et audio 500. Le provisionnement audio ne consomme le quota
  qu'après un cache miss. Une requête refusée pour concurrence ou plafond STT
  ne consomme aucun des deux compteurs STT.

- Relever hebdomadairement l'usage réel et garder les alertes actives.
- À 16 EUR, désactiver les générateurs IA non essentiels ; Whisper local et la
  reconnaissance du téléphone restent utilisables.
- À 20 EUR, couper les clés ou le budget fournisseur jusqu'au mois suivant.
  Ne pas hausser le plafond pour contourner l'alerte : documenter d'abord la
  décision dans la note architecture.

## Contrôles reproductibles

La CI `PR / Provider boundaries` vérifie les fonctions, les
frontières Auth/audio via les tests Deno et exécute
`supabase/tests/provider_quota.sql` et les frontières multi-comptes dans
`supabase/tests/security_boundaries.sql` sur un PostgreSQL jetable. Les tests SQL
ne doivent jamais être lancés sur la base réelle. Les migrations ne sont pas
déployées automatiquement par ce contrôle.

## Passage à plusieurs utilisateurs

Revoir les limites par utilisateur, le budget global et les coûts réels avant
d'ouvrir les inscriptions. Les plafonds actuels sont volontairement adaptés à
un unique testeur ; ils ne constituent pas une politique de production.
