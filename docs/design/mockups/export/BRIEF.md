# VocabApp — brief de reprise UX/UI

Dossier de passation. 50 écrans dessinés, plus la carte de leur
enchaînement. À lire avant de toucher aux maquettes : plusieurs
choix qui semblent arbitraires sont en fait des décisions prises et
motivées.

---

## 1. Ce qu'est l'app

Application mobile (Flutter) d'apprentissage de langues. Vocabulaire
en répétition espacée (FSRS) **plus** un curriculum de leçons.
Six langues étudiables — fr · en · it · de · es · ko — dans **n'importe
quelle paire** : la langue de base varie d'une langue étudiée à l'autre
pour un même utilisateur.

Les maquettes montrent le cas **français → espagnol**.

---

## 2. Système de design — valeurs exactes

Tirées de `lib/core/theme/app_colors.dart` et `app_theme.dart`.
**À ne pas arrondir ni « harmoniser ».**

### Typographie
**Figtree** (Google Fonts), poids 400/500/600/700/800.

### Fonds
| rôle | hex |
|---|---|
| fond d'app (tous les écrans) | `#F6F1EA` |
| surface secondaire | `#EFE7DB` |
| cartes, champs, lignes | `#FFFFFF` |
| fond immersif sombre | `#241F1B` |
| carte sur fond sombre | `#2E2823` |

### Texte
| rôle | hex |
|---|---|
| texte principal | `#2B2622` |
| secondaire | `#756C62` |
| libellés, méta | `#6F695F` |
| légendes, inactif | `#8A8073` |
| bordures, rails | `#ECE3D7` / `#DDD2C2` |
| sur fond sombre | `#F6F1EA` / `#CFC6BA` / `#9A9086` |

### Accents
| rôle | hex |
|---|---|
| teal — progression, correct, valider | `#4C8C86` |
| teal clair | `#6BA39D` |
| clay — micro, voix, CTA, série | `#D08358` |
| clay clair | `#E0A079` |
| clay foncé (texte sur clair, AA) | `#C4703F` |
| rose — destructif uniquement | `#B0556B` |

### Boutons pleins — ne pas utiliser les accents bruts
Le blanc sur `clay`/`teal` ne passe pas AA. Variantes assombries :
- CTA clay : `#A85A30`
- CTA teal : `#3E726D`

### Retours de correction — figés, hors thème
- juste : `#2FA98C` · à revoir : `#E8693C`

Un **flood plein écran tenu**, jamais une teinte, identique en clair et
en sombre : il doit être perceptible en vision périphérique.

### Palette de listes (l'utilisateur en choisit une)
`#D08358` `#4C8C86` `#6B6CB0` `#B0556B` `#7A7066`

---

## 3. Règles de langue — non négociables

1. **« Niveau 1 » à « Niveau 6 », jamais « A1 »–« C2 ».** Les libellés
   CEFR sonnent comme une promesse de certification (risque juridique
   et marketing). Le CEFR reste une cible **interne** : tags de contenu,
   objectifs pédagogiques. Jamais à l'écran.
2. **« Leçons », jamais « Grammaire ».** Chaque langue a son propre
   équilibre : grammaire, conjugaison, écriture, prononciation. Le
   coréen aura beaucoup de prononciation, l'espagnol de la conjugaison.
   « Grammaire » serait trompeur.
3. **L'en-tête affiche la PAIRE** (« FR ↔ ES »), pas la langue cible
   seule — voir §1.
4. **Tutoiement**, ton direct et sans condescendance.
5. Aucune phrase d'exemple ne doit être absurde : tout ce qu'on montre
   doit être **dicible en voyage ou en conversation réelle**.

---

## 4. Les parcours (voir `PlanDuFlux.png`)

1. **Première ouverture** — préchargement → 6 étapes → l'accueil.
   Branche « j'ai des bases » vers le test de niveau.
2. **L'accueil** — le Parcours est le hub, tout y revient.
3. **Apprendre une leçon** — fiche de cluster → 6 pages de leçon →
   J+1 Reconnaître → J+2 la rampe Construire → Mélange → cluster validé.
4. **La boucle du jour** — Découvrir, l'écho, les 4 modes de révision,
   les floods, le résumé.
5. **Consulter** — les onglets, hors chemin.
6. **États limites** — variantes, pas des étapes.

### Mécaniques qu'il ne faut pas casser en redessinant

- **La rampe de distracteurs (Construire).** P0 : les bons chips
  seulement. P2 : trois familles de leurres — même verbe autrement
  conjugué, variante de genre, mot hors phrase. P3 : plus de chips,
  saisie libre. ⚠️ **Les chips doivent rester visuellement identiques** :
  les colorer par famille donnerait la réponse.
- **Les portes de vocabulaire.** Une leçon s'ouvre à 80 % de mots connus
  sur ses listes prérequises. La porte s'affiche **sur la leçon qu'elle
  bloque**, pas dans un encart séparé.
- **Le Mélange** est l'examen du cluster : ≥ 20 questions sur ≥ 4 leçons,
  aucun item de vocabulaire pur, barre à 80 %.
- **Budget de mots : 5 à 10 par jour**, réévalué chaque semaine selon ce
  que l'utilisateur a réellement suivi. Le bilan « semaine calme » est
  l'endroit où l'ajustement devient visible.
- **Le chemin du jour est figé** à sa génération. Ce qui arrive à
  échéance ensuite attend le lendemain.
- **Jamais de culpabilisation.** Hier disparaît sans reproche ; échouer
  un test ne coûte ni série ni progression.

---

## 5. Ce qui reste ouvert (à trancher, pas à supposer)

- Le placement se fait-il pendant l'onboarding (écran 4/6) ou seulement
  plus tard, depuis un niveau verrouillé ? Les deux sont dessinés.
- Familles de mots : gratuit ou premium ?
- Défis : périmètre bloqué sur un audit technique — l'entrée est
  volontairement en pointillés, il n'y a rien à dessiner encore.
- Le CRUD réservé aux listes PERSO (les listes du parcours en lecture
  seule) est une proposition, pas une décision.

## 6. Ce qui n'est pas encore dessiné

- **Les Défis.** Périmètre bloqué sur un audit technique, et leur
  maintien même n'est pas tranché. L'entrée est volontairement en
  pointillés dans l'écran Amis — il n'y a rien à dessiner tant que la
  feature n'est pas décidée.
- États limites manquants : liste très longue, mot coréen qui déborde,
  série perdue, aucune révision due.
- Écrans derrière Paramètres et Abonnement.

### Points d'attention sur ce qui vient d'être ajouté

- **Le cloze est une PROPOSITION.** Son layout n'a jamais été tranché
  (`quiz-canvas.md` le marque encore ouvert), et la provenance des
  phrases avant que les leçons existent reste une question ouverte.
  À traiter comme une piste, pas comme une décision.
- **Le Niveau 0** (4 écrans) suit des axes décidés — reconnaissance
  romanisation ↔ hangeul et audio ↔ hangeul, jamo → syllabes → mots,
  romanisation révisée qui s'efface avec la progression, pas de tracé.
  Le découpage en groupes de jamo, lui, est une proposition.
- Les écrans coréens utilisent **Noto Sans KR** pour le hangul ;
  Figtree n'a pas les glyphes.

## 7. Contraintes techniques à respecter

- Cibles tactiles ≥ 44 px.
- Le mode **Mains libres** doit rester utilisable sans regarder l'écran
  (marche, conduite) — d'où le fond sombre et les grandes zones.
- L'app est **hors-ligne d'abord** : révisions et listes sont locales,
  seules les leçons non téléchargées et l'audio premium demandent le
  réseau.
- 7 locales d'interface : prévoir des libellés qui s'allongent.

---

## 8. Contenu du dossier

- `PlanDuFlux.png` — la carte d'enchaînement, à regarder en premier
- `*.png` — les 50 écrans, 2× (780 × 1688)
- `INDEX.md` — la liste par parcours
- Sources modifiables : `../canvas/*.dc.html`
