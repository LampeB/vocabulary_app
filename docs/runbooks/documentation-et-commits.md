# Documentation et commits

## Première installation sur un poste

Sous Windows, depuis la racine du dépôt.

```powershell
powershell -ExecutionPolicy Bypass -File tool/install-git-hooks.ps1
```

Sous Linux ou macOS, utiliser PowerShell 7.

```bash
pwsh -NoProfile -File tool/install-git-hooks.ps1
```

Le script configure Git pour utiliser les hooks versionnés dans `.githooks/`
et rend le hook exécutable sur Unix. Git conserve le mode `100755` du hook
et ses fins de ligne LF à chaque checkout. Refaire l'installation après un
nouveau clone ou si `git config --get core.hooksPath` renvoie une autre valeur.
La CI Ubuntu installe le hook dans un dépôt jetable et vérifie qu'un vrai
`git commit` contenant un chemin interdit est refusé.

## Avant un commit

1. Lire [l'état du projet](../../PROJECT_STATUS.md) et la spécification liée.
2. Mettre à jour le document canonique affecté ; mettre à jour l'état du projet
   lorsqu'une fonctionnalité, une limite ou une priorité change réellement.
3. Préparer les fichiers puis committer. Le hook vérifie les liens Markdown et
   refuse les changements applicatifs/configuration sans fichier de
   documentation préparé. Il refuse aussi les artefacts générés ou la
   configuration privée et exige le formatage des fichiers Dart préparés.
   Les chemins Git sont lus avec leur séparateur NUL. Les accents et les sauts
   de ligne restent attachés à leur nom de fichier pendant le contrôle.
   Garder le jeton de déploiement dans `supabase/.env.deploy` sur son poste.
   Le garde refuse ce fichier dans l'index et dans une PR. Le modèle
   [`supabase/.env.deploy.example`](../../supabase/.env.deploy.example) peut
   être versionné.

Pour vérifier une branche entière avant d'ouvrir une PR :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/check-pr-policy.ps1 -BaseRef origin/main
```

## Exemption rare

Pour une modification purement mécanique qui ne change aucun contrat, lancer :

```powershell
$env:DOCS_EXEMPT = '1'
git commit -m "chore: description" -m "Docs: exempt — raison mécanique précise"
Remove-Item Env:DOCS_EXEMPT
```

Ne jamais employer cette exemption pour éviter de trancher une question produit
ou technique. Poser la question, puis documenter la réponse est le comportement
attendu.
