# vava_gathering — la récolte du royaume

Bûcheronnage, minage, herboristerie, pêche et pistes de gibier, sur une terre qui se fatigue : chaque zone a une
**vitalité** que les récoltes font baisser et que le temps répare lentement ; une zone épuisée se voit (souches, filons
ternes) et rapporte peu ; poussée à zéro, elle garde une **cicatrice**. Les outils se tiennent **en main** et s'usent ;
la qualité de ce qu'on ramasse dépend de la compétence, de l'outil et de la santé de la terre, et chaque pile porte son
palier et sa provenance. Le serveur décide de tout et demande l'XP à `vava_skills`.

Ordre de démarrage : après `vAvA_core` (≥ 0.6.0), `vava_ui` (≥ 1.0.0, polices, grain, papier et coins des
interfaces ; à ne jamais arrêter sur un serveur ouvert), `vava_inventory` (≥ 1.4.0) et `vava_skills` (≥ 1.0.0).
Facultatifs : `vava_hud` (barre de progression, notifications), `vava_admin` (droit `metiers`), `vava_chat`,
`vava_health` (aucune récolte à terre), `vava_time` (saisons : repousse des nœuds et quantité récoltée, lues par
l'export `getSeason`).

Rendu hors jeu : `web/index.html?view=prompt` (ou `tension`, `zones`) dans un navigateur, depuis le dépôt (option
`--allow-file-access-from-files` pour les polices), avec les données simulées de `web/dev/devmock.js` (jamais livré).

## Règles (config.lua)

| Règle | Défaut | Clé |
|---|---|---|
| Bandes de vitalité | > 60 plein ; 60–25 réduit (rendement × 0,6, palier − 1, 25 % d'échec) ; < 25 épuisée (× 0,2, − 2, 50 %) | `bands` |
| Cicatrice | à 0 ; régénération × 0,2 pendant `scarHours` de la zone | `scar`, `zones[].scarHours` |
| Réaction de la terre | 3 cicatrices en 7 jours → hook `vava_gathering:earthReaction` | `earthReaction` |
| Saisons (`vava_time`, facultatif) | facteurs par saison et par compétence de la ressource. Repousse des charges : printemps herbes, gibier et poissons × 1,25 ; automne herbes × 0,75, gibier × 1,25 ; hiver herbes × 0,25, poissons et gibier × 0,5, bois × 0,75 (0 : rien ne repousse, sans rien accumuler). Au changement de saison, l'avance prise sur la prochaine charge est gardée et recomptée au nouveau rythme (1.3.1). Facteurs bornés à [0, 10] (invalide ou infini : 1) ; pendant le démarrage de `vava_time` (saison pas encore connue), aucun nœud ne repousse (1.3.2). Unités récoltées : automne gibier × 1,25, hiver herbes × 0,5 (au moins une). Minage : aucune saison. Sans `vava_time` : aucun effet | `seasons.regen`, `seasons.yield` |
| Interaction | 2,5 m (+ 1,5 m de tolérance serveur), 1,5 s entre deux récoltes, geste oublié après 30 s | `interact` |
| Durée du geste | base de la ressource × (1 − niveau × 0,004) ÷ puissance de l'outil, 1,2 s au moins | `duration` |
| Qualité | score = niveau × 0,5 + outil × 0,3 + vitalité × 0,2 + bonus de l'outil ± 8 → paliers à 20, 40, 60, 85 ; provenance écrite | `quality` |
| Pêche | touche entre 4 et 14 s ; barre de tension 6 s, zone à tenir 35–65 % qui dérive, 60 % du temps dans la zone | `fishing` |
| Prise (tirée par le serveur, ligne tenue) | le poisson se décroche : 25 % au niveau 0 de Pêche, 2 % au niveau 100, linéaire entre les deux (13,5 % au niveau 50), quel que soit l'état de l'eau (décision du 30 octobre 2026 : supplément de la bande `catch.bands` à 0, gardé dans la config pour pouvoir le remettre ; l'eau fatiguée ou épuisée ne joue que par l'échec de la bande, 25 % / 50 %, avec son message d'eau) ; parts invalides comptées pour 0, chance ramenée dans [0, 1] (1.4.0) | `fishing.catch` |
| Props | créés par le client à 80 m ; nœuds regroupés par zone, seuls ceux d'une zone à portée sont mesurés ; relus toutes les secondes près d'une zone, toutes les 2,5 s quand aucun nœud n'est à moins de 140 m (80 m + 60 m de marge d'approche) (1.4.1) | `streaming` |
| Zones d'eau | genres de zone dont les textes parlent de l'eau et non de la terre (échec de la bande, épuisement, invite) : `eau` | `waterKinds` |
| Carte | un blip nommé par zone (icône et couleur selon le genre, courte portée) et le cercle de son rayon ; « Marquer » dans le panneau pose le repère de la carte | `map` |
| Solidité d'un outil sans histoire | 100 au premier usage | `toolDefaults` |

### Zones et nœuds

Une **zone** (identifiant, nom, genre, centre, rayon, coût de vitalité par récolte, régénération par heure, durée de
cicatrice) regroupe des **nœuds** (position, ressource, charges, délai par charge rendue, prop normal et prop épuisé).
La vitalité et les charges sont recalculées à la demande depuis leur dernière date : aucune boucle de croissance. L'état
est publié aux clients par deux state bags globaux (`vava_gathering:zone:<id>` : bande, cicatrice, vitalité entière ;
`vava_gathering:node:<id>` : charges), écrits au seul changement et relus toutes les 10 s pour que les props reviennent
quand une zone se remet.

Sur la **carte**, chaque zone a son blip (icône et couleur par genre dans `map.kinds`, nom de la zone, visible sur la
petite carte à l'approche et toujours sur la grande) et le cercle translucide de son rayon. Le client les pose depuis
la config à l'entrée en jeu et les retire à la sélection : rien ne circule. `map.blips = false` les coupe.

Les zones et nœuds livrés sont des **exemples** autour du point d'apparition par défaut, avec des modèles du jeu de base :
à remplacer par les lieux et les props du royaume.

### Ressources, outils, objets

Une **ressource** dit ce qu'un nœud produit : objet, compétence, genre d'outil requis en main (ou aucun : les herbes se
cueillent à la main), difficulté et XP (passées telles quelles à `vava_skills`), fourchette d'unités, durée, animation,
pièce supplémentaire possible (peau d'une piste). Les **outils** sont déclarés au registre du core `vava_gathering:tools`
(objet → genre, puissance, bonus de rendement et de qualité, usure) : la config les y verse, un autre module peut en
ajouter. Le module déclare ses **objets** à l'inventaire (bûches, minerais, herbes, poissons, viandes, peaux, cinq
outils de base avec leur accessoire en main), images dans `web/items`.

### Une récolte

1. Le client montre l'invite près d'un nœud (« [E] Couper — Chêne · 3 charges », et ce qu'il faut en main).
2. `E` → le serveur vérifie : personnage, nœud, distance (position lue côté serveur), charges, outil en main du bon
   genre et non brisé, place dans la besace, cooldown, hook `vava_gathering:harvesting` (annulable) ; il calcule la
   durée et rend un jeton.
3. Le client joue le geste et la barre du HUD ; se déplacer ou rappuyer interrompt.
4. À la fin, le serveur revérifie durée et distance, l'outil toujours en main, l'use (brisé à 0), tire l'échec de la
   bande, le rendement et le palier, ajoute la pile (`{ tier, origin }`), consomme une charge et de la vitalité, demande
   l'XP, et prévient le joueur.

### La pêche

Canne en main, `E` lance la ligne ; le serveur tire le moment de la touche et prévient le pêcheur ; la barre de tension
s'affiche : tenir la touche fait monter l'aiguille, la relâcher la fait descendre, la zone à tenir dérive ; au bout du
temps, le client dit s'il a tenu. Ce qu'il dit ne peut que **faire rater** (1.4.0) : ligne relâchée, la prise
s'échappe ; ligne tenue, le **serveur tire la prise** selon le seul niveau de Pêche (lu au lancer ; l'état de l'eau n'y entre pas)
(`fishing.catch`, règle pure `shared/catch.lua`) : un débutant perd encore une prise sur quatre, un maître presque
jamais (« Au dernier moment, le poisson se décroche. »). Puis l'échec de la bande s'applique comme à
toute récolte. Touche, durée, distance, charge, vitalité, rendement et XP sont au serveur. Une prise échappée ou
décrochée ne consomme rien (ni charge, ni vitalité, ni usure, ni XP). Décision du porteur du projet (30 octobre 2026) :
le serveur tire la réussite.

## Base de données (sql/0001_gathering.sql)

`vava_gathering_zones` (vitalité, date, cicatrice, épuisements récents), `vava_gathering_nodes` (charges, date),
`vava_gathering_log` (épuisements, cicatrices, réactions, actions du Conseil ; 90 jours). Écriture groupée toutes les
10 s et à l'arrêt.

## API

Exports : `getZone(id)`, `getZones()`, `setVitality(id, 0–100)`, `nodeState(id)`, `getResource(id)`, `getTool(objet)`,
`getSession(joueur)`. Hooks : `vava_gathering:harvesting` (before, annulable : `{ source, characterId, node, zone,
resource, item }`), `harvested` (after : `+ quantity, tier, band, extra? `), `zoneDepleted`, `zoneScarred`,
`earthReaction` (after : `{ zone, … }`). Détail : `docs/api.md`.

## Conseil (droit `metiers`)

`/recolte zones` · `/recolte zone <id>` · `/recolte noeud <id>` · `/recolte vitalite <zone> <0-100>` ·
`/recolte recharger <noeud>`. Inscrit au journal du module et au Registre.

## Tests en jeu

1. **Invite et outil** : approcher un chêne sans rien en main → « Il vous faut une hache en main » ; prendre la hache
   (emplacement Mains) → « [E] Couper — Chêne · 3 charges ».
2. **Récolte** : `E`, geste et barre ; bûches de chêne dans la besace avec palier et « Forêt de Brume » ; XP de
   Bûcheronnage ; solidité de la hache − 2 ; charge − 1 (state bag) ; une seconde récolte dans la seconde → refusée.
3. **Interruption** : marcher pendant le geste → arrêt, rien n'est pris.
4. **Épuisement** : `/recolte vitalite foret_brume 20` → props remplacés (souches), récolte à rendement effondré, échecs
   fréquents ; `/recolte vitalite foret_brume 0` → cicatrice, journal ; `/recolte vitalite foret_brume 100` → retour.
5. **Charges** : vider un nœud (3 récoltes) → « plus rien à prendre » ; attendre `regenMs` → une charge revient.
6. **Herbes** : lavande à la main (aucun outil) ; sauge avec la faucille.
7. **Pistes** : couteau en main sur une piste de lièvre → viande, parfois une peau.
8. **Pêche** : canne en main au bord de la Rivière Claire : ligne lancée, touche, barre de tension tenue → truite le
   plus souvent ; relâchée → « La prise s'est échappée », aucune charge consommée. Ligne tenue au niveau 0 : environ
   une prise sur quatre se décroche (« Au dernier moment, le poisson se décroche. »), sans charge
   ni usure ; Pêche portée à 100 (`/metiers niveau <joueur> peche 100`) : presque jamais. En eaux fatiguées ou
   épuisées, les textes parlent de l'eau (« Ces eaux sont fatiguées : le poisson vous échappe. », « … l'eau a besoin de
   repos. », invite « Ces eaux sont épuisées : la pêche sera maigre. »). Détail : `docs/tests/metiers.md`.
9. **Panneau** : touche `O` → zones, vitalité, bandes, cicatrices, distances ; « Marquer » pose le repère de la carte
   sur la zone et ferme le panneau (l'itinéraire part aussitôt).
10. **Carte** : en jeu, un blip nommé par zone et le cercle de son rayon sur la grande carte (icônes : gibier, foreuse,
    feuille, barque ; numéros à changer dans `map.kinds` s'ils déplaisent) ; retour à la sélection → plus aucun ;
    `map.blips = false` → aucun.
11. **Redémarrage** : `restart vava_gathering` → vitalités et charges retrouvées (écriture à l'arrêt), props recréés,
    blips retirés puis reposés.
12. **À terre** (`vava_health`) : près d'un chêne, hache en main, se faire mettre à terre → l'invite disparaît ; `E` ne
    sert qu'à rendre l'âme. Tombé pendant le geste : rien n'est pris, aucune charge consommée (« Vous êtes à terre. »).
13. **Saisons** (`vava_time`) : voir `docs/tests/temps.md` (section des métiers) — en hiver, la sauge vidée revient
    quatre fois moins vite et la récolte d'herbes est divisée par deux ; `stop vava_time` → plus aucun effet.
14. **Props à distance** (1.4.1) : venir de loin à cheval vers la Forêt de Brume → les arbres apparaissent à 80 m comme
    avant ; s'éloigner → ils disparaissent ; `resmon` loin de toute zone puis dans une zone : `vava_gathering` plus bas
    loin de tout. Détail : `docs/tests/metiers.md` § 6.
