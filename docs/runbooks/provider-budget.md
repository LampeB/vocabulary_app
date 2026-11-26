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
2. Déployer la migration `010_provider_quota_buckets.sql` avant les Edge
   Functions. Sans elle, les fonctions échouent fermées (`503`) plutôt que
   d'appeler un fournisseur sans limite.
   L'API de quotas n'est exécutable que par `service_role` : les fonctions
   valident la session avec Auth, puis transmettent l'identité vérifiée au
   serveur. Les seuils sont définis dans SQL, jamais dans le client.
3. Vérifier qu'aucune clé fournisseur n'est présente dans `.env.json`, les
   journaux ou l'application. Elles restent exclusivement dans les secrets
   Supabase.

## Pendant la bêta

- Les deux moteurs STT cloud partagent **300 requêtes par jour UTC** et
  **80 par heure UTC**, ainsi qu'une seule requête simultanée par utilisateur.
  Le bail serveur dure 90 secondes et se libère à la fin de chaque requête ;
  les appels fournisseur sont interrompus après 60 secondes, les uploads après
  5 secondes. Un crash conserve le verrou jusqu'à son expiration.
- Les captures acceptées sont du PCM16 mono 16 kHz (brut ElevenLabs ou WAV).
  Le serveur vérifie leur format et les **30 secondes réelles** ; une simple
  limite d'octets ne suffit pas pour un format compressé ou un autre débit.
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

La CI `PR / Provider boundaries` type-check les cinq fonctions, vérifie les
frontières Auth/audio via les tests Deno et exécute
`supabase/tests/provider_quota.sql` sur un PostgreSQL jetable. Les tests SQL
ne doivent jamais être lancés sur la base réelle. Les migrations ne sont pas
déployées automatiquement par ce contrôle.

## Passage à plusieurs utilisateurs

Revoir les limites par utilisateur, le budget global et les coûts réels avant
d'ouvrir les inscriptions. Les plafonds actuels sont volontairement adaptés à
un unique testeur ; ils ne constituent pas une politique de production.
