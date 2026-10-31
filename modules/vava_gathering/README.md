# vava_gathering — la récolte du royaume

Bûcheronnage, minage, herboristerie, pêche et pistes de gibier, sur une terre qui se fatigue : chaque zone a une
**vitalité** que les récoltes font baisser et que le temps répare lentement ; une zone épuisée se voit (souches, filons
ternes) et rapporte peu ; poussée à zéro, elle garde une **cicatrice**. Les outils se tiennent **en main** et s'usent ;
la qualité de ce qu'on ramasse dépend de la compétence, de l'outil et de la santé de la terre, et chaque pile porte son
palier et sa provenance. Le serveur décide de tout et demande l'XP à `vava_skills`.

Ordre de démarrage : après `vAvA_core` (≥ 0.11.0, abonnements de zone), `vava_ui` (≥ 1.0.0, polices, grain, papier et coins des
interfaces ; à ne jamais arrêter sur un serveur ouvert), `vava_inventory` (≥ 1.4.0) et `vava_skills` (≥ 1.0.0).
Facultatifs : `vava_hud` (barre de progression, notifications), `vava_admin` (droit `metiers`), `vava_chat`,
`vava_health` (aucune récolte à terre), `vava_time` (saisons : repousse des nœuds et quantité récoltée, lues par
l'export `getSeason`).

Rendu hors jeu : `web/index.html?view=prompt` (ou `tension`, `zones`) dans un navigateur, depuis le dépôt (option
`--allow-file-access-from-files` pour les polices), avec les données simulées de `web/dev/devmock.js` (jamais livré).

## Règles (config.lua, config_client.lua)

Depuis 1.7.0 (T-132), les réglages sont dans deux fichiers et chacun n'est écrit qu'une fois : `config_client.lua`
porte ce que lit le client, et le serveur aussi : `interact.distance` et `interact.moveCancel`, `streaming` (sauf
`subscribeSlack`), `map`, `waterKinds`, `keys`, `labels`, `tools`, `resources`, `zones`, `nodes` et `anims` (entiers :
le client les lit par identifiant ou les parcourt) ; `config.lua` porte tout le reste, lu par le seul serveur, dont
`fishing` entier (la barre de tension part avec la touche : le client n'en lit que `holdRatio`, borné de 0 à 1, sinon
le repli `FISHING_HOLD_RATIO` de `shared/constants.lua`) et, ajoutés aux tables ouvertes par `config_client.lua`, les
tolérances `interact.serverTolerance`, `cooldownMs`, `finishToleranceMs`, `expireMs` et `streaming.subscribeSlack` ;
il complète la table sans réécrire une clé de `config_client.lua`.

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
| Props | créés par le client à 80 m ; nœuds regroupés par zone, seuls ceux d'une zone suivie (1.6.0) et à portée sont mesurés ; relus toutes les secondes près d'une zone, toutes les 2,5 s quand aucun nœud n'est à moins de 140 m (80 m + 60 m de marge d'approche) (1.4.1) ; une zone reçue, changée ou quittée fait aussitôt un passage (1.6.0) | `streaming` |
| État envoyé aux joueurs proches (1.6.0) | bande, cicatrice et charges d'une zone envoyées par le core aux seuls joueurs à moins de 80 m + 20 m du cercle qui englobe ses nœuds (l'état est là avant que le premier prop puisse apparaître), puis ses seuls changements ; la vitalité n'est jamais envoyée | `streaming.radius`, `streaming.subscribeSlack` |
| Zones d'eau | genres de zone dont les textes parlent de l'eau et non de la terre (échec de la bande, épuisement, invite) : `eau` | `waterKinds` |
| Touches | `E` récolter, `O` panneau des zones (réglables dans Paramètres > Raccourcis > FiveM) ; `O` est cité par l'écran de chargement : changer cette touche par défaut oblige à retoucher le conseil de `modules/vava_loading/web/js/strings.js` | `keys` |
| Carte | un blip nommé par zone (icône et couleur selon le genre, courte portée) et le cercle de son rayon ; « Marquer » dans le panneau pose le repère de la carte | `map` |
| Solidité d'un outil sans histoire | 100 au premier usage | `toolDefaults` |

### Zones et nœuds

Une **zone** (identifiant, nom, genre, centre, rayon, coût de vitalité par récolte, régénération par heure, durée de
cicatrice) regroupe des **nœuds** (position, ressource, charges, délai par charge rendue, prop normal et prop épuisé).
La vitalité et les charges sont recalculées à la demande depuis leur dernière date : aucune boucle de croissance.

**Ce qui part chez les joueurs** (1.6.0, abonnements de zone du core, `vAvA_core` ≥ 0.11.0) : chaque zone de récolte
est une zone du core (nom = identifiant de la zone ; centre de la zone ; rayon = la plus grande distance au sol entre ce
centre et ses nœuds, au moins le rayon de la zone ; marge = `streaming.radius` + `streaming.subscribeSlack`, 100 m). Son
état : `zone` → `{ band, scarred }` et `n:<nœud>` → charges. Le core l'envoie entier aux seuls joueurs qui entrent dans
ce cercle (position lue par le serveur, une fois par seconde), puis ses seuls changements, regroupés par tour : une
récolte qui fait changer la bande et les charges ne fait partir qu'une différence d'environ 50 o, aux seuls joueurs de
la zone. Un joueur loin de toute zone ne reçoit rien. La **vitalité n'est jamais envoyée** (elle ne change rien à ce
que voit le joueur ; le panneau `O` la demande au serveur) : seule une bande ou une cicatrice qui change fait partir la
clé `zone`, à la récolte ou au passage de la boucle lente (10 s) quand la zone se remet. Plus aucune écriture dans
GlobalState : les anciennes clés `vava_gathering:zone:<id>` et `vava_gathering:node:<id>` sont effacées une fois au
démarrage si un serveur resté allumé les garde encore (seulement pour les zones et nœuds encore dans la config : après
une mise à jour depuis une version antérieure à 1.6.0 qui retire des zones ou des nœuds, **redémarrer le serveur**, pas
seulement la ressource). Une zone hors des bornes d'une zone du core (nœuds à plus de 500 m de son centre, plus de 255
nœuds, `streaming.radius` + `streaming.subscribeSlack` au-delà de 500 m) refuse le module au démarrage, avec la zone
en cause dans la console. Une zone refusée en cours de route par le core (`full` : trop de zones, état total trop
gros) est écrite en console une fois, rappelée toutes les 10 min avec le nombre de refus, et retentée toutes les 10 s ;
ses nœuds n'apparaissent pas chez les joueurs.
Identifiants : 48 octets au plus pour une zone, 46 pour un nœud (clé `n:<nœud>`), sinon le module refuse de démarrer.

**L'état d'une zone est public** : sous OneSync, la position que lit le serveur est déclarée par le client, un client
modifié peut recevoir l'état de n'importe quelle zone. Il n'y a donc rien de secret dedans (bande, cicatrice, charges,
tout ce qui se voit déjà sur place), et chaque action revérifie côté serveur, au moment de l'action, la distance réelle
au nœud (au début et à la fin du geste), le personnage, l'outil, le délai et les charges, sans se fier à l'abonnement.

Le client ne mesure que les nœuds des zones qu'il suit ; il crée leurs props, les remplace par le modèle épuisé et met à
jour l'invite dès qu'une zone arrive, change ou part (sans attendre le passage suivant de sa boucle). Une zone quittée
reprend ses valeurs par défaut (pleine, charges de la config) : elle n'a alors aucun prop à portée. Le Conseil
(`/recolte vitalite`, `/recolte recharger`) et les autres modules (`setVitality`) changent l'état en jeu : les joueurs
proches le voient aussitôt, sans reconnexion. Les zones et nœuds **créés** en jeu viendront avec l'Atelier (T-102) :
`server/share.lua` sait déjà redéclarer une zone (déplacée, état remplacé) ; les positions et modèles des nœuds devront
alors entrer dans l'état de la zone (aujourd'hui lus dans la config par le client).

`cellSize` du core (cases de 256 m) est gardé : les zones de récolte sont grandes (zones d'exemple : rayon 60 à 120 m,
cercle d'intérêt de 160 à 220 m) et peu nombreuses ; elles ajoutent une poignée de candidates par case, là où les cases de 128 m ne font
gagner qu'en ville, sur des zones de quelques mètres (rapport T-015).

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

## Fichiers

| Fichier | Rôle |
|---|---|
| `config_client.lua` | réglages lus par le client (invite, streaming, carte, touches, outils, ressources, zones et nœuds, animations) : téléchargé par chaque joueur, ouvre `VavaGathering.config` |
| `config.lua` | tous les autres réglages, servi au seul serveur (en tête des `server_scripts`) : complète la table |
| `shared/geometry.lua`, `shared/proximity.lua`, `shared/zonestate.lua` | purs, lus par le client et le serveur : distances, groupes du streaming, état des zones reçu |
| `shared/season.lua`, `shared/catch.lua` | purs, servis au seul serveur : facteurs de saison, prise d'un poisson |

Fichiers téléchargés par chaque joueur (1.7.0, T-132) : `shared/constants.lua`, `config_client.lua`, les trois
`shared/*.lua` lus par le client, les sept `client/*.lua`, la page et les dessins des objets ; `config.lua`,
`shared/season.lua` et `shared/catch.lua` sont servis au seul serveur.

**Mise à jour vers 1.7.0 (T-132)** : l'invite, le streaming, la carte, les genres d'eau, les
touches, les outils, les ressources, les zones et nœuds et les animations ont quitté `config.lua` pour
`config_client.lua`. Un `config.lua` modifié et gardé par l'installeur de la Chancellerie (le nouveau posé en
`config.lua.nouveau`) garde l'ancienne forme : le module démarre, mais la console le signale (« config.lua garde la
forme d'avant 1.7.0 … ») et un réglage client changé dans ce fichier reste sans effet. Reportez vos réglages dans
`config.lua` et `config_client.lua` d'après les nouveaux fichiers.

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
   Bûcheronnage ; solidité de la hache − 2 ; charge − 1 (différence de la zone) ; une seconde récolte dans la seconde
   → refusée.
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
15. **Joueurs proches seulement** (1.6.0) **(2 joueurs)** : A récolte dans la Forêt de Brume, B à plus de 500 m ;
    `/vava_reseau joueur <B>` : aucune ligne `vAvA:zone:*` de `vava_gathering` ; B s'approche : les arbres apparaissent
    à 80 m, `/vava_reseau zones <B>` cite `vava_gathering:foret_brume` ; chaque récolte de A change la charge dans
    l'invite de B (une `vAvA:zone:diff` d'environ 50 o). Détail et mesure `profiler record` : `docs/tests/metiers.md`
    § 3.4.

## À vérifier en jeu

- Arrivée au galop dans une zone (marge de 100 m, passage du core d'une seconde) : l'état est là avant les props, les
  arbres apparaissent toujours à 80 m (jamais d'abord pleins puis en souches).
- Téléportation au milieu d'une zone : props au plus une seconde environ après l'arrivée (avant : jusqu'à 2,5 s).
- Coût du passage des zones avec les zones de récolte (`profiler record`, `docs/tests/metiers.md` § 3.4).
- `restart vava_gathering` en étant dans une zone : props retrouvés dans les deux secondes, sans reconnexion.
- Une récolte qui change la bande d'une zone : une seule `vAvA:zone:diff` chez le joueur proche (charges et bande
  ensemble) ; besace pleine : aucune.
- Loin de toute zone de récolte : `vava_gathering` à 0,00 ms dans `resmon` (boucle des props arrêtée) ; elle repart à
  l'approche d'une zone, props à 80 m comme avant.
