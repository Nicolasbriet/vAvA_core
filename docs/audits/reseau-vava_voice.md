# Audit réseau et performance — vava_voice 1.2.2 — 30 octobre 2026 (T-011)

## Périmètre

Voix de proximité (Mumble de FiveM), portées, zones de voix éditées par le Conseil, médaillon du HUD. Lus en entier :
`config.lua`, `server/zones.lua`, `server/presence.lua`, `server/main.lua` (RPC), `client/main.lua`,
`client/mumble.lua`, `client/ring.lua`, `client/editor.lua` (boucle), `client/zones.lua`, `fxmanifest.lua`.

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| `ZONE` (`set`, zone complète) | `server/zones.lua:73` | **tous les joueurs** (`EVERYONE = -1`, `:23`) | environ 110 o (id, nom, x, y, z, rayon, hauteur, effet) | à chaque création ou modification d'une zone par le Conseil |
| `ZONE` (`remove`, id) | `server/zones.lua:75` | **tous les joueurs** | 20 o | à chaque suppression |
| `LIMIT` | `server/presence.lua:37` | le joueur | 10 o | changement de plafond de portée (à terre, réanimé) |
| réponse `zones` (liste complète) | RPC `server/main.lua:89` | le demandeur | 110 o × nombre de zones | à chaque apparition |

## GlobalState et state bags

Aucun. La parole passe par Mumble (salons de FiveM), hors des évènements du jeu.

## Boucles client

| Boucle | Fichier:ligne | Au repos | En action | Remarque |
|---|---|---|---|---|
| joueurs à portée | `client/main.lua:119-124` → `client/mumble.lua:107-133` | 250 ms, en jeu seulement ; parcourt `GetActivePlayers` | idem | Mumble n'est touché que si la liste change |
| médaillon (parle ou non) | `client/main.lua:127-138` | 150 ms | idem | HUD prévenu au seul changement |
| zone de voix courante | `client/main.lua:141-146` | 500 ms | idem | |
| cercle de portée | `client/ring.lua:29-42` | — | par image, 1,5 s après un appui | justifié |
| éditeur des zones | `client/editor.lua:79-87` | — | par image tant que l'éditeur (Conseil) est ouvert | justifié |
| attente de connexion | `client/mumble.lua:68` | 250 ms, bornée (120 essais) | — | |

Trois boucles permanentes en jeu : environ 12 réveils par seconde au repos, la plus coûteuse étant le parcours des
joueurs à portée (une distance par joueur dans la zone de culling).

## Props, NUI, fichiers web

Aucun prop. NUI (éditeur, médaillon) : messages au seul changement. Dossier `web/` : 290 616 o, dont 243 457 o de
polices et textures communes (voir T-012) ; `web/fonts/cinzel_decorative_400.woff2` (14 416 o) est livré mais aucune
règle `@font-face` ne le charge (`web/css/style.css:11` ne déclare que la graisse 700).

## BLOQUANT

- `server/zones.lua:23`, `:73`, `:75` — **envoi à tous les joueurs** — chaque création, modification ou suppression
  d'une zone de voix part chez tous les joueurs connectés, y compris à l'autre bout de la carte. Coût faible (110 o ×
  joueurs, au rythme des éditions du Conseil) mais c'est la règle `TriggerClientEvent(nom, -1, …)` de CLAUDE.md, et
  l'envoi échappe à `audit-reseau.sh` parce que la cible est une constante (voir `reseau-vAvA_core.md`). Déjà prévu par
  T-014 (zones de voix reprises par les abonnements de zone) : ligne précisée dans T-014. En attendant, le porteur du
  projet peut inscrire l'exception (rare, réservée au Conseil, 110 o) dans `scripts/audit-exceptions.txt`.

## IMPORTANT

Aucun.

## MINEUR

- `client/main.lua:119-146` — **trois boucles permanentes** (250, 150 et 500 ms) — elles pourraient n'en faire qu'une
  (150 ms, avec un compteur pour les deux autres cadences) : un thread et un réveil au lieu de trois. À décider après
  la mesure du resmon au repos à la porte T-019 (cible ≤ 0,02 ms).
- `web/fonts/cinzel_decorative_400.woff2` — **police livrée et jamais chargée** (14 416 o par joueur) — à retirer de
  `files` ou avec la mutualisation de T-012.

## Points solides

- Mumble n'est sollicité que si la liste des joueurs à portée change ; la lueur du médaillon ne part au HUD qu'au
  changement.
- Les boucles par image (cercle, éditeur) ne vivent que le temps de leur état.
- Liste des zones demandée à l'apparition (RPC), avec quelques essais bornés.

## À vérifier en jeu

- resmon de `vava_voice` au repos, seul puis à 10 joueurs proches (les trois boucles).
- Avec T-014 : un joueur loin d'une zone créée ne reçoit plus rien (`/vava_reseau`).

VERDICT : À CORRIGER
