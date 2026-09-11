#!/usr/bin/env python3
"""Génère PlanDuFlux.dc.html — le graphe d'enchaînement des écrans.

Les nœuds sont les VRAIES maquettes (chaque .dc.html est réinjecté à
l'échelle), pas des étiquettes. Les flèches sont dessinées par-dessus
en SVG. Le graphe part de l'accueil (Parcours).
"""
import re, html, pathlib

S = 0.40                      # échelle des maquettes
SW, SH = int(390 * S), int(844 * S)   # 156 x 337
PITCH = 200                   # pas horizontal entre deux écrans
W = 3120

INK, MUTED, FAINT = "#2B2622", "#756C62", "#8A8073"
PAPER = "#F6F1EA"
CLAY_DEEP, TEAL_DEEP, ROSE = "#C4703F", "#3E736D", "#B0556B"
INDIGO = "#6B6CB0"
ARROW = "#BCAE9B"

HERE = pathlib.Path(__file__).parent

def screen_markup(name):
    """Extrait le corps d'un artboard (tout ce qui suit </helmet>)."""
    src = (HERE / f"{name}.dc.html").read_text(encoding="utf-8")
    body = src.split("</helmet>", 1)[1].split("</x-dc>", 1)[0].strip()
    return body

# ── les bandes : (titre, sous-titre, accent, [(fichier, légende, lien)]) ──
# lien = texte porté par la flèche ENTRANTE ; None = pas de flèche (origine)
BANDS = [
    ("1 · PREMIÈRE OUVERTURE", "une seule fois, à l'installation", CLAY_DEEP, [
        ("Prechargement", "Préchargement", None),
        ("Main", "Bienvenue", "ouverture"),
        ("LangueCible", "Langue cible", "Commencer"),
        ("LangueBase", "Langue de base", "choix fait"),
        ("NiveauDepart", "Point de départ", "choix fait"),
        ("ObjectifQuotidien", "Objectif quotidien", "je débute"),
        ("PremierChemin", "C'est prêt", "budget choisi"),
        ("TestNiveauIntro", "Test — intro", "« j'ai des bases »"),
        ("TestNiveauResultat", "Test — réussi", "≥ 85 %"),
        ("TestNiveauEchoue", "Test — pas encore", "sous le seuil"),
    ]),
    ("2 · NIVEAU 0 — L'ÉCRITURE", "seulement pour les langues à script (coréen) — avant le vocabulaire", INDIGO, [
        ("Niveau0Cluster", "Les groupes de jamo", None),
        ("Niveau0Reconnaitre", "Reconnaître", "on ouvre un groupe"),
        ("Niveau0Discrimination", "Écouter", "à l'oreille"),
        ("Niveau0Syllabe", "Composer une syllabe", "jamo → syllabe"),
    ]),
    ("3 · L'ACCUEIL ET CE QUI EN PART", "le Parcours est le hub : tout y revient", CLAY_DEEP, [
        ("Parcours", "PARCOURS — l'accueil", None),
        ("CheminDuJour", "Chemin du jour", "carte du jour"),
        ("CheminTermine", "Journée complète", "4/4 étapes"),
        ("PratiqueLibre", "Pratique libre", "pastille"),
        ("MenuGeneral", "Menu général", "avatar"),
        ("SelecteurLangue", "Tes langues", "chip de l'en-tête"),
    ]),
    ("4 · APPRENDRE UNE LEÇON", "depuis un nœud du parcours — étalé sur plusieurs jours", TEAL_DEEP, [
        ("Parcours", "PARCOURS", None),
        ("FicheCluster", "Fiche de cluster", "on déplie un nœud"),
        ("LeconExplication", "Leçon 1/6", "on ouvre la leçon"),
        ("LeconExemples", "Leçon 2/6", "swipe"),
        ("LeconQuickCheck", "Leçon 3/6", "swipe"),
        ("LeconIrregulier", "Leçon 4/6", "swipe"),
        ("LeconDialogue", "Leçon 5/6", "swipe"),
        ("LeconFin", "Leçon 6/6", "swipe"),
        ("Reconnaitre", "Reconnaître", "J+1"),
        ("ConstruireP0", "Construire P0", "J+2"),
        ("ConstruireP2", "Construire P2", "2 réussites"),
        ("ConstruireP3", "Écrire P3", "3 réussites"),
        ("MelangeLecon", "Mélange — leçon", "5 leçons faites"),
        ("MelangeDrill", "Mélange — quiz", "≥ 20 questions"),
        ("ClusterValide", "Cluster validé", "≥ 80 %"),
    ]),
    ("5 · LA BOUCLE DU JOUR", "les étapes servies par le chemin — réviser d'abord", TEAL_DEEP, [
        ("CheminDuJour", "Chemin du jour", None),
        ("Decouvrir", "Découvrir", "étape Découvrir"),
        ("Echo", "Écho", "lot terminé"),
        ("Flashcard", "Cartes", "étape Réviser"),
        ("FlashcardRevelee", "Cartes — révélée", "voir la réponse"),
        ("Ecrire", "Écrire", "autre mode"),
        ("Voix", "Voix", "autre mode"),
        ("MainsLibres", "Mains libres", "autre mode"),
        ("Cloze", "Cloze — en contexte", "autre mode"),
        ("FeedbackJuste", "Flood « Juste ! »", "bonne réponse"),
        ("FeedbackARevoir", "Flood « À revoir »", "erreur"),
        ("Resume", "Résumé → Chemin", "fin de session"),
    ]),
    ("6 · CONSULTER", "les onglets — atteignables à tout moment, hors chemin", CLAY_DEEP, [
        ("Parcours", "PARCOURS", None),
        ("VocabTab", "Vocabulaire", "onglet"),
        ("ListeDetail", "Détail de liste", "une liste"),
        ("Familles", "Familles de mots", "un mot"),
        ("LeconsTab", "Leçons", "onglet"),
        ("Progres", "Progrès", "onglet"),
        ("BilanFort", "Bilan — grosse semaine", "dimanche"),
        ("BilanCalme", "Bilan — semaine calme", "variante"),
        ("Amis", "Amis", "onglet"),
        ("AmiProfil", "Profil d'un ami", "un ami"),
    ]),
    ("7 · ÉTATS LIMITES", "pas des étapes : des variantes d'écrans déjà dessinés", ROSE, [
        ("VocabVide", "Vocabulaire — jour 1", None),
        ("HorsLigne", "Parcours — hors ligne", None),
    ]),
]

BAND_H = 470
TOP = 118
X0 = 60

nodes, arrows, chrome = [], [], []

def place(name, x, y, label, accent, origin=False):
    ring = f"2.5px solid {accent}" if origin else "1px solid #DDD2C2"
    nodes.append(
        f'<div style="position:absolute;left:{x}px;top:{y}px;width:{SW}px;height:{SH}px;'
        f'overflow:hidden;border-radius:12px;border:{ring};box-shadow:0 3px 12px rgba(43,38,34,.10);background:#fff">'
        f'<div style="transform:scale({S});transform-origin:0 0;width:390px;height:844px">{screen_markup(name)}</div>'
        f'</div>'
    )
    w = "800" if origin else "650"
    col = accent if origin else INK
    nodes.append(
        f'<div style="position:absolute;left:{x}px;top:{y+SH+7}px;width:{SW}px;text-align:center;'
        f'font-size:11px;font-weight:{w};color:{col};line-height:1.3">{html.escape(label)}</div>'
    )

y = TOP
for title, sub, accent, items in BANDS:
    chrome.append(
        f'<div style="position:absolute;left:30px;top:{y-46}px;width:{W-60}px;height:{BAND_H-16}px;'
        f'border-radius:20px;background:{accent}0D"></div>'
    )
    chrome.append(
        f'<div style="position:absolute;left:60px;top:{y-36}px;font-size:15px;font-weight:800;color:{accent}">'
        f'{html.escape(title)}<span style="font-size:11.5px;font-weight:600;color:{FAINT};margin-left:14px">'
        f'{html.escape(sub)}</span></div>'
    )
    for i, (name, label, link) in enumerate(items):
        x = X0 + i * PITCH
        place(name, x, y, label, accent, origin=(link is None and i == 0))
        if link:
            ax1, ax2 = x - PITCH + SW + 5, x - 7
            ay = y + SH // 2
            arrows.append((ax1, ay, ax2, ay, link))
    y += BAND_H

H = y - BAND_H + SH + 90

# flèches (SVG en surimpression)
paths = [
    '<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6.5" markerHeight="6.5" '
    f'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{ARROW}"/></marker></defs>'
]
for x1, y1, x2, y2, label in arrows:
    paths.append(f'<path d="M{x1},{y1} L{x2},{y2}" stroke="{ARROW}" stroke-width="2" fill="none" marker-end="url(#ah)"/>')
    if label:
        paths.append(
            f'<text x="{(x1+x2)/2}" y="{y1-9}" text-anchor="middle" font-size="9.5" '
            f'font-weight="700" fill="{FAINT}">{html.escape(label)}</text>'
        )
svg = (f'<svg viewBox="0 0 {W} {H}" style="position:absolute;left:0;top:0;width:{W}px;height:{H}px;'
       f'pointer-events:none">' + "".join(paths) + '</svg>')

header = (
    f'<div style="position:absolute;left:60px;top:34px;font-size:26px;font-weight:800;color:{INK}">'
    f'VocabApp — enchaînement des écrans</div>'
    f'<div style="position:absolute;left:585px;top:42px;font-size:13px;font-weight:600;color:{MUTED}">'
    f'on part de l\'accueil ; chaque bande est un parcours complet</div>'
)

doc = f'''<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Figtree:wght@400;500;600;700;800&display=swap">
  <style>
    body {{ margin: 0; }}
    svg text {{ font-family: Figtree, system-ui, sans-serif; }}
    a {{ color: #C4703F; }} a:hover {{ color: #A85A30; }}
  </style>
</helmet>
<div style="position:relative;width:{W}px;height:{H}px;background:{PAPER};font-family:Figtree,system-ui,sans-serif">
{header}
{"".join(chrome)}
{"".join(nodes)}
{svg}
</div>
</x-dc>
</body>
</html>
'''
(HERE / "PlanDuFlux.dc.html").write_text(doc, encoding="utf-8")
print(f"PlanDuFlux.dc.html — {W}x{H}, {sum(len(b[3]) for b in BANDS)} ecrans")

# ── canvas.json généré depuis les MÊMES bandes ───────────────────────────
# (évite que le manifeste et le graphe divergent)
import json

NOTES = {
    1: "1 · PREMIÈRE OUVERTURE — rangée du haut : le chemin nominal. Rangée du bas : la branche « j'ai déjà des bases ».\n\nCible PUIS base (décidé 13/08) · budget 5-10 mots/j réévalué chaque semaine (21/08) · « Niveau 1-6 », jamais A1-C2.\n\n🔴 Ouvert : le placement se fait-il ici (écran 4/6), ou seulement plus tard depuis un niveau verrouillé ?",
    2: "2 · NIVEAU 0 — n'existe que pour les langues à script (coréen ici). Fortement recommandé, jamais obligatoire.\n\nReconnaissance dans les deux sens (romanisation ↔ hangeul, audio ↔ hangeul), jamo → syllabes → mots. Romanisation révisée (RR), et elle s'efface à mesure qu'on lit.\n\nPas de tracé pour l'instant — décidé, réouvrable plus tard.",
    3: "3 · LE HUB — le Parcours est l'accueil et le point de retour de tout.\n\nTaper un nœud le déplie SUR PLACE (le contenu déplié = la fiche de cluster, page suivante).\n\nPratique libre, Menu général et « Tes langues » sont des surcouches : elles ne quittent jamais vraiment le hub. Le sélecteur de langue est le SEUL endroit où l'on change de langue — et démarrer une langue s'y fait en deux temps, cible puis base.",
    4: "4 · APPRENDRE UNE LEÇON — rangée du haut : la leçon (6 pages, dans l'ordre). Rangée du bas : les drills, étalés sur plusieurs jours, puis le Mélange qui ferme le cluster.\n\n⚠️ Les chips de Construire sont VOLONTAIREMENT identiques : les colorer par famille de distracteur donnerait la réponse.\n\nÀ ne pas confondre avec les modes de révision (page suivante) : ici on exerce une LEÇON, là on révise du VOCABULAIRE.",
    5: "5 · LA BOUCLE DU JOUR — Découvrir (le flux « apprendre »), puis les modes de révision, puis ce qui les termine.\n\nLes deux floods sont communs à tous les modes ET aux drills de leçon : plein écran tenu, jamais une teinte, identiques en clair et en sombre (couleurs figées dans app_colors.dart).\n\n🔴 Le cloze est une PROPOSITION : son layout n'a jamais été tranché (quiz-canvas.md). D'où viennent les phrases avant que les leçons existent reste aussi ouvert.",
    6: "6 · CONSULTER — les onglets, atteignables à tout moment, hors chemin.\n\nCRUD actif uniquement sur les listes PERSO ; les listes PARCOURS sont du curriculum, en lecture seule (proposé 13/08, à valider). L'onglet Leçons est entièrement en lecture seule.\n\n⚠️ Progrès : trois chiffres de la carte « rythme » ne sont pas encore calculables — le log d'événements ne couvre pas les drills de leçon. Ticket code à créer.",
    7: "7 · ÉTATS LIMITES — les états où les maquettes heureuses cassent d'habitude.\n\nDeux ici. Restent à faire si utile : liste très longue, mot coréen qui déborde, série perdue, aucune révision due.\n\nLes Défis ne sont pas dessinés : périmètre bloqué sur l'audit M9, et leur maintien n'est pas tranché.",
}
TALL = {"Progres": 1280}
ROW = 1000          # 2e rangée quand une bande dépasse ce nombre d'écrans
WRAP = 8

pages = [{"id": "page-0", "name": "★ Plan du flux"}]
artboards = [{"file": "PlanDuFlux.dc.html", "page": "page-0", "x": 0, "y": 0,
              "w": W, "h": H, "title": "Enchaînement des écrans — les vraies maquettes, reliées",
              "print": "flow"}]
annotations = [{"id": "n-flux", "page": "page-0", "x": 0, "y": -190, "w": 700,
                "text": "L'ENCHAÎNEMENT DES ÉCRANS — commence ici.\n\nCe ne sont pas des étiquettes : chaque nœud est la vraie maquette, réduite. Les flèches portent le déclencheur (« swipe », « J+1 », « ≥ 80 % »…).\n\nLe PARCOURS est le hub ; il réapparaît en tête des bandes 4 et 6 parce que c'est de là qu'on y entre — encadré en clay pour le repérer.\n\nChaque bande a sa page dédiée dans le menu du haut, avec les mêmes écrans en taille réelle et dans le même ordre."}]

seen = set()
for bi, (title, sub, accent, items) in enumerate(BANDS, start=1):
    pid = f"page-{bi}"
    pages.append({"id": pid, "name": title.replace(" · ", " · ")})
    col = 0
    for name, label, link in items:
        if name in seen:      # origine répétée : pas de doublon d'artboard
            continue
        seen.add(name)
        x = (col % WRAP) * 470
        y = (col // WRAP) * ROW
        ab = {"file": f"{name}.dc.html", "page": pid, "x": x, "y": y,
              "w": 390, "h": TALL.get(name, 844), "title": label}
        if name in TALL:
            ab["print"] = "flow"
        artboards.append(ab)
        col += 1
    if bi in NOTES:
        annotations.append({"id": f"n-p{bi}", "page": pid, "x": 0, "y": -190,
                            "w": 620, "text": NOTES[bi]})

(HERE / "canvas.json").write_text(json.dumps({
    "pages": pages, "artboards": artboards, "annotations": annotations,
    "launch": {"view": "canvas", "page": "page-0"},
}, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"canvas.json — {len(pages)} pages, {len(artboards)} artboards")
