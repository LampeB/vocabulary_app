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
2. Déployer les migrations `010_provider_quota_buckets.sql`,
   `012_security_boundaries.sql` et `015_vocabulary_owner_namespace.sql`
   avant les Edge Functions. Un contrôle de
   quota indisponible interrompt la demande au fournisseur et renvoie `503`.
   Entre 007 et 012, le bucket `vocab-audio` reste fermé aux rôles client.
   Après 012, leurs droits de lecture suivent le manifeste et le propriétaire.
   L'écriture dans le bucket reste réservée au rôle serveur, y compris en
   présence d'une politique Storage permissive préexistante.
   Sur un projet historique qui attend encore 012, appliquer d'abord la
   version corrigée de 007. Suivre le [runbook d'activation](e2e-account.md#activation-supabase).
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
Le script lit le [manifeste des fonctions déployables](../../supabase/functions/deployable-functions.json),
vérifie les types, exécute les tests avec `--frozen`, prépare les bundles
verrouillés et démarre leurs points d'entrée dans un test sans accès réseau
ni résolution npm. Les bundles temporaires sont supprimés à la fin.
[Bundling Deno](https://docs.deno.com/runtime/reference/bundling/).

Pour déployer, actualiser `origin/main` avec `git fetch origin main`, relever
son SHA complet et vérifier la validation de ce commit sur GitHub. Préparer
les migrations requises sur le projet ciblé et utiliser la CLI Supabase
(version 3.4 ou ultérieure), authentifiée localement. Depuis un checkout
propre du commit validé, lancer la commande suivante.

```bash
python3 tool/deploy-edge-functions.py --project-ref <ref-du-projet> --commit <sha-validé-origin-main>
```

Le script compare le SHA à la référence locale `origin/main`, puis extrait
de ce commit le manifeste, les sources, le verrou et la sonde de démarrage.
Il valide cette copie et transmet les bundles autonomes du manifeste à la
CLI, qui demande confirmation pour le projet désigné. La vérification du
résultat de la revue et de la CI sur GitHub appartient à l'opérateur.
[Déploiement Supabase](https://supabase.com/docs/reference/cli/supabase-functions-deploy).

Pour une mise à jour de dépendance, modifier les imports exacts, puis lancer
`deno check --config supabase/functions/deno.json --frozen=false supabase/functions/*/index.ts`.
Relire le diff du verrou et repasser le script sans projet avant de commiter.

## Frontières des contenus et des audios

- Les corps JSON des assistants sont lus en flux, avec un maximum de 32 Kio
  et 5 secondes. Un mot facturé est limité à 256 caractères ; les contextes,
  listes et règles ont aussi des bornes avant tout débit de quota.
- L'assistant vocabulaire omet le thème de traduction quand il est absent.
  Pour les suggestions, il échantillonne des paires issues des mêmes concepts
  en deux lectures groupées de variantes. Le contexte transmis contient au
  plus 80 paires et chaque côté tient dans 256 unités UTF-16. L'enveloppe
  JSON entière respecte la limite de 32 Kio encodée en UTF-8.
- Les appels IA et TTS ont un délai de 60 secondes sans retry automatique
  Anthropic. Une réservation SQL exclusive de 90 secondes protège chaque clip
  manquant. Le provisionnement ouvre un délai commun de 60 secondes avant
  l'acquisition et l'applique à la nouvelle lecture du cache, au débit de
  quota, au rendu, à l'envoi dans Storage et à l'attachement. À l'échéance,
  les requêtes HTTP sont annulées. Une expiration du délai ou un résultat
  incertain après le début du rendu conserve la réservation jusqu'à son
  expiration.
- Seule l'erreur d'objet `NoSuchKey` dans la réponse de métadonnées Storage
  permet la génération. Une panne ou un `404` sans code d'objet renvoie
  `503` avant le débit de quota ou l'appel TTS.
  [Codes d'erreur Supabase Storage](https://supabase.com/docs/guides/storage/debugging/error-codes).
- Pour un clip en cache comme pour une génération, le serveur attache le
  chemin seulement à une variante toujours active dont le mot et la langue
  correspondent au clip. Une édition ou une suppression concurrente renvoie
  `409` sans chemin. Le résultat `ready` indique le chemin, le mot et la langue
  de la variante confirmée.
- Le provisionnement ne lit que les variantes actives du compte vérifié et
  de ses listes et concepts actifs. Une variante absente, supprimée ou hors
  de ce périmètre donne la même réponse `404` avant le cache, le quota et le
  rendu.
- Le provisionnement utilisateur écrit exclusivement sous `users/<UUID>/`.
  Le champ `origin` d'une liste n'autorise jamais une publication sous `seed/`.
  Seul `seed-audio-publish`, administrateur, publie le catalogue partagé.
  Envoyer une clé moderne `sb_secret_…` dans `apikey`, ou un JWT historique
  `service_role` dans `Authorization: Bearer …`. La fonction vérifie la clé
  présentée sur la route d'administration Supabase Auth avant toute publication.
  `tool/generate_seed_audio.mjs` envoie cette clé uniquement à l'origine HTTPS
  configurée du projet et refuse les redirections.
  [Authentification des routes administrateur Supabase](https://supabase.com/kb/troubleshooting/auth-error-401-unauthorized_missing_api_key-on-admin-endpoints-ac2afd).
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
