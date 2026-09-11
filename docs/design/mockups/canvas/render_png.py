#!/usr/bin/env python3
"""Rend chaque artboard .dc.html en PNG via Edge headless.

Les .dc.html s'affichent tels quels dans un navigateur (<x-dc> et
<helmet> sont des balises inconnues, leur contenu et leurs styles
s'appliquent quand même) — donc pas besoin du runtime de l'éditeur.
"""
import json, pathlib, subprocess, sys

EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
HERE = pathlib.Path(__file__).parent
OUT = HERE.parent / "export"
OUT.mkdir(exist_ok=True)

manifest = json.loads((HERE / "canvas.json").read_text(encoding="utf-8"))
sizes = {a["file"].replace(".dc.html", ""): (a["w"], a["h"]) for a in manifest["artboards"]}
titles = {a["file"].replace(".dc.html", ""): a.get("title", "") for a in manifest["artboards"]}
pages = {p["id"]: p["name"] for p in manifest["pages"]}
page_of = {a["file"].replace(".dc.html", ""): a["page"] for a in manifest["artboards"]}

ok, fail = [], []
for name, (w, h) in sizes.items():
    src = HERE / f"{name}.dc.html"
    if not src.exists():
        fail.append(name); continue
    # le plan du flux est déjà énorme : rendu en 1x, les écrans en 2x
    scale = 1 if w > 1000 else 2
    dest = OUT / f"{name}.png"
    cmd = [EDGE, "--headless", "--disable-gpu", "--hide-scrollbars",
           f"--force-device-scale-factor={scale}",
           "--virtual-time-budget=3000",            # laisse charger la webfont
           f"--screenshot={dest}", f"--window-size={w},{h}",
           src.resolve().as_uri()]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    if dest.exists() and dest.stat().st_size > 2000:
        ok.append((name, dest.stat().st_size))
    else:
        fail.append(name)
        print(f"  echec {name}: {r.stderr.strip()[:120]}", file=sys.stderr)

print(f"{len(ok)} PNG ecrits dans {OUT}")
if fail:
    print(f"echecs: {', '.join(fail)}")

# index lisible à côté des images
lines = ["# VocabApp — index des écrans exportés", "",
         "PNG rendus depuis les sources `.dc.html` (dossier `canvas/`).",
         "Écrans en 2x (780x1688), plan du flux en 1x.", ""]
by_page = {}
for name, _ in ok:
    by_page.setdefault(page_of.get(name, "?"), []).append(name)
for pid, names in by_page.items():
    lines.append(f"## {pages.get(pid, pid)}")
    lines.append("")
    for n in names:
        lines.append(f"- `{n}.png` — {titles.get(n, '')}")
    lines.append("")
(OUT / "INDEX.md").write_text("\n".join(lines), encoding="utf-8")
print(f"index: {OUT / 'INDEX.md'}")
