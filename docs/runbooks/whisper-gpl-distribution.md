# Distribution de Whisper local — frontière de licence

Whisper local Android est intégré avec `packages/ponderin_whisper`. Ce paquet
est un pont minimal propre à Ponderin, qui lie le sous-module MIT
`ggml-org/whisper.cpp`. L'ancien wrapper `whisper_flutter_new`, GPL-3.0, est
interdit dans ce dépôt et ne doit jamais être réintroduit.

La CI exécute `tool/check-whisper-license.ps1` à chaque PR pour vérifier la
révision du moteur, son texte MIT et l'absence de l'ancien wrapper. Ce contrôle
est un garde-fou technique, pas un avis juridique.

## Avant toute diffusion externe

Le workflow [Validate release APK build](../../.github/workflows/build-apk.yml)
s'arrête après la compilation Android. Pour un essai privé, construire l'APK
sur son poste avec [la commande locale](../../README.md#getting-started).
La publication d'un binaire dans les artefacts de ce dépôt public ou sur un
service de test par navigateur, y compris Appetize, reste différée jusqu'aux
vérifications ci-dessous.

1. Exécuter le contrôle de licence, puis générer et archiver l'inventaire des
   dépendances et licences du livrable réellement distribué (APK, AAB ou IPA).
2. Conserver les avis MIT de `whisper.cpp` et du modèle, référencés dans
   `packages/ponderin_whisper/THIRD_PARTY_NOTICES.md`, avec les informations
   légales du livrable.
3. Vérifier à nouveau la licence de toute nouvelle dépendance native ou de tout
   modèle avant intégration ; GPL/AGPL et toute licence inconnue sont bloquantes
   sans décision juridique écrite.
4. Choisir puis ajouter une licence pour le code propre à Ponderin avant toute
   diffusion : le dépôt n'en a pas encore et ce choix produit/juridique est
   volontairement ouvert.
5. Valider l'intégration iOS séparément avant de promettre Whisper local sur
   cette plateforme ; le pont actuel est Android-only.

## Interdiction de diffusion

Ne pas diffuser un binaire si le contrôle de licence échoue, si les notices MIT
ne peuvent pas être fournies, ou si l'inventaire contient une licence GPL/AGPL
ou inconnue non approuvée. Les builds de développement internes ne remplacent
pas cette étape.
