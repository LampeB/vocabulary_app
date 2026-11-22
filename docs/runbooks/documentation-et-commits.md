# Documentation et commits

## Première installation sur un poste

Depuis la racine du dépôt :

```powershell
powershell -ExecutionPolicy Bypass -File tool/install-git-hooks.ps1
```

Cette commande configure Git pour utiliser les hooks versionnés dans
`.githooks/`. Refaire l'opération après un nouveau clone ou si
`git config --get core.hooksPath` ne renvoie pas `.githooks`.

## Avant un commit

1. Lire [l'état du projet](../../PROJECT_STATUS.md) et la spécification liée.
2. Mettre à jour le document canonique affecté ; mettre à jour l'état du projet
   lorsqu'une fonctionnalité, une limite ou une priorité change réellement.
3. Préparer les fichiers puis committer. Le hook vérifie les liens Markdown et
   refuse les changements applicatifs/configuration sans fichier de
   documentation préparé.

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
