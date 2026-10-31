# vava_gathering — la récolte du royaume

Bûcheronnage, minage, herboristerie, pêche et pistes de gibier, sur une terre qui se fatigue : chaque zone a une
**vitalité** que les récoltes font baisser et que le temps répare lentement ; une zone épuisée se voit (souches, filons
ternes) et rapporte peu ; poussée à zéro, elle garde une **cicatrice**. Les outils se tiennent **en main** et s'usent ;
la qualité de ce qu'on ramasse dépend de la compétence, de l'outil et de la santé de la terre, et chaque pile porte son
palier et sa provenance. Le serveur décide de tout et demande l'XP à `vava_skills`.

**Version 1.8.0 (T-102) : la récolte dans l'Atelier.** Le Conseil (droit `metiers`) trace une zone au sol, y pose ses
arbres, filons et buissons un par un en visant là où ils doivent pousser, les essaie seul (à blanc), puis publie : les
joueurs proches voient les points sortir de terre dans la seconde, sans redémarrage, et ceux qui sont loin ne reçoivent
rien. La config n'est plus que la **graine** de l'atelier « Récolte » : au premier démarrage, chaque zone et chaque nœud
y deviennent la version 1 ; ensuite **la base de l'Atelier fait foi**. Sans `vava_atelier`, la récolte tourne sur sa
graine.

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
`subscribeSlack`), `map`, `waterKinds`, `keys`, `labels`, `tools` (le seul genre de chaque outil), `resources` (libellé,
outil requis, geste, modèles `prop`) et `anims`. Depuis 1.8.0 (T-102, relecture T-141 S-3 et R-3), chaque entrée a une
part client et une part serveur : `zones` et `nodes` (graine de l'Atelier), `resourceStats` (objet, compétence,
difficulté, XP, rendement, durée, pêche, pièce en plus), `toolStats` (puissance, bonus, usure), `looks` et `editor` sont
dans `config.lua` ; ce que le joueur doit voir d'une zone et de ses points (nom, type, lieu, ressource) lui arrive par
l'état de la zone. `resources` et `resourceStats`, `tools` et `toolStats` portent les mêmes identifiants, sinon le
module refuse de démarrer avec le nom en cause ; une ressource sans `prop.model` aussi. `config.lua` porte tout le
reste, lu par le seul serveur, dont
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
| Atelier : droit (1.8.0) | `metiers` (Sénéchal et au-dessus, décision déjà prise) | `editor.right` |
| Atelier : rayon d'une zone | 10 à 300 m, 60 m au premier tracé | `editor.zoneRadius` |
| Atelier : un point hors de sa zone | 5 m au plus (un tronc au bord) | `editor.nodeSlack` |
| Atelier : écart entre deux points d'une zone | 2 m au moins, au sol | `editor.spacing` |
| Atelier : chevauchement de deux zones | 10 m au plus (décision du 31 octobre 2026) | `editor.overlapTolerance` |
| Atelier : plafonds | 256 zones ; 120 points par zone (deux clés d'état par point, 256 clés par zone du core) | `editor.maxZones`, `editor.maxNodesPerZone` |
| Atelier : diffusion de garde | une zone notée depuis plus de 2 s sans fin de lot part au passage suivant de la boucle lente | `editor.flushGraceMs` |
| Atelier : types de lieu | Forêt, Mine, Prairie, Eau (chaque valeur a son icône dans `map.kinds`) | `editor.zoneKinds` |
| Atelier : valeurs de départ | fatigue 2 % par récolte, repos 4 % par heure, cicatrice 48 h, 3 récoltes, repousse 10 min | `editor.defaults` |
| Atelier : bornes de l'abondance | repos de la terre 12 % par heure au plus, repousse d'une récolte 5 min au moins (relecture lore : « ressources exploitées avec mesure ») | `editor.restMax`, `editor.regrowMin` |
| Apparence d'un point | celle de sa ressource (`resources[…].prop`), dite au Conseil (« chêne de GTA, modèle provisoire ») | `looks` |
| Liste de la carte | redemandée une fois par séance, 2 demandes puis une toutes les 20 s | `rateLimits.map` |
| Essai à blanc | « [Essai] Chêne : 3 × Bûche de chêne (commun). Rien n'est donné pendant un essai. » | `messages.trialHarvest`, `trialFailed` |

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
seulement la ressource). Une zone hors des bornes d'une zone du core (nœuds à plus de 500 m de son centre, plus de 120
nœuds depuis 1.8.0 — 255 avant —, `streaming.radius` + `streaming.subscribeSlack` au-delà de 500 m) refuse le module au
démarrage, avec la zone en cause dans la console. Une zone refusée en cours de route par le core (`full` : trop de zones, état total trop
gros) est écrite en console une fois, rappelée toutes les 10 min avec le nombre de refus, et retentée toutes les 10 s ;
ses nœuds n'apparaissent pas chez les joueurs.
Identifiants : 48 octets au plus pour une zone, 46 pour un nœud (clé `n:<nœud>`), sinon le module refuse de démarrer.

**L'état d'une zone est public** : sous OneSync, la position que lit le serveur est déclarée par le client, un client
modifié peut recevoir l'état de n'importe quelle zone. Il n'y a donc rien de secret dedans (bande, cicatrice, charges,
tout ce qui se voit déjà sur place), et chaque action revérifie côté serveur, au moment de l'action, la distance réelle
au nœud (au début et à la fin du geste), le personnage, l'outil, le délai et les charges, sans se fier à l'abonnement.

Le client ne mesure que les nœuds des zones qu'il suit ; il crée leurs props, les remplace par le modèle épuisé et met à
jour l'invite dès qu'une zone arrive, change ou part (sans attendre le passage suivant de sa boucle). Une zone quittée
reprend ses valeurs par défaut (pleine) et perd ses points : elle n'a alors aucun prop à portée. Le Conseil
(`/recolte vitalite`, `/recolte recharger`) et les autres modules (`setVitality`) changent l'état en jeu : les joueurs
proches le voient aussitôt, sans reconnexion.

Depuis 1.8.0 (T-102), l'état porte aussi **`def`** → `{ nom, type, x, y, z, rayon }` et **`p:<nœud>`** →
`{ ressource, x, y, z, cap }`, en listes au format compact (longueurs en centimètres entiers, cap en dixièmes de
degré entiers ; le client divise) : le client ne lit plus aucune zone ni
aucun nœud dans sa config, une zone ou un point publiés dans l'Atelier paraissent sans redémarrage. Le modèle d'un point
est celui de sa ressource. Ni coût, ni repos, ni cicatrice réglée, ni charges maximales, ni repousse, ni nom d'un
point n'y entrent (part serveur) : changer la fatigue d'une zone n'envoie **rien** aux joueurs. Taille : ≈ 0,3 Ko pour
une zone de 5 points, ≈ 2 Ko pour 50, ≈ 4,9 Ko pour 120 points aux identifiants courts, sous le seuil du latent
(≈ 15,9 Ko au pire, identifiants de 46 octets ; ≈ 9 et ≈ 19,5 Ko avant le format compact). Le client garde 120 points
au plus par zone et ignore une valeur mal formée. Une récolte (charges, bande) ne fait qu'un passage de la boucle des
props chez les abonnés : les points d'une zone ne sont regroupés de nouveau que si un lieu ou la `def` change (0,26 →
0,002 ms par différence pour 120 points, mesure hors jeu).

`cellSize` du core (cases de 256 m) est gardé : les zones de récolte sont grandes (zones d'exemple : rayon 60 à 120 m,
cercle d'intérêt de 160 à 220 m) et peu nombreuses ; elles ajoutent une poignée de candidates par case, là où les cases de 128 m ne font
gagner qu'en ville, sur des zones de quelques mètres (rapport T-015).

Sur la **carte**, chaque zone a son blip (icône et couleur par genre dans `map.kinds`, nom de la zone, visible sur la
petite carte à l'approche et toujours sur la grande) et le cercle translucide de son rayon. Depuis 1.8.0, la liste
n'est **jamais poussée** : chaque client la garde en stockage local (KVP `vava_gathering:map`, avec sa version, 16 Ko
et 256 zones au plus, contrôlée à la relecture et oubliée si elle est abîmée), pose ses blips à l'entrée en jeu, puis
la redemande une fois par séance (RPC `vava_gathering:map`, ≈ 30 o si rien n'a changé, ≈ 60 o par zone sinon) ; une
zone suivie qui porte sa `def` corrige son blip sans rien demander. Une zone nouvelle et lointaine paraît sur la carte à
la prochaine connexion, ou en approchant (décision du 31 octobre 2026). Blips retirés à la sélection.
`map.blips = false` les coupe.

### Atelier de la récolte (1.8.0, T-102)

Atelier gardé `vava_gathering:zones` (« Récolte », famille monde, droit `metiers`), maquette `docs/maquettes/Recolte.html` :

- **Zone** (cercle) : nom (unique, sans accents ni casse), type de lieu, et repliés sous « Réglages de la zone » :
  fatigue par récolte, repos de la terre, durée d'une cicatrice. Le rayon n'est pas un champ : il se règle à la molette
  en plaçant la zone. Étapes « La zone · Les points · Publier ».
- **Point** (orienté, enfant d'une zone) : nom (« Chêne 4 », donné tout seul à la pose), ressource, récoltes avant
  repos, repousse d'une récolte. Un point naît d'un clic dans sa zone (« Poser des points », valeurs du bloc
  « Prochain point à poser ») ; son apparence est celle de sa ressource.
- **Règles** (le module seul en juge) : `validate` — nom unique, type connu, lieu exigé à l'essai et à la publication,
  rayon de 10 à 300 m, chevauchement de 10 m au plus avec une autre zone publiée (hors celles retirées par le même lot) ;
  point : ressource connue, un poisson dans l'eau et rien d'autre dans l'eau, dedans sa zone (+ 5 m) si la zone n'est
  pas dans le lot. `validateLot` — la zone après le lot : 120 points au plus, chacun dans le cercle neuf, 2 m entre deux
  points, cercle englobant de 500 m. `placeCheck` (au clic, avant d'écrire) — chevauchement, 256 zones, 120 points.
- **Rechargement à chaud** : `apply` et `remove` changent le catalogue tout ou rien (un refus ne change rien) ; la
  vitalité et les charges d'une zone ou d'un point qui revient sont reprises de la base (les lignes ne sont jamais
  effacées : un retour en arrière retrouve la terre comme elle était) ; les charges sont ramenées au nouveau maximum ;
  une récolte en cours sur un point changé ou retiré est oubliée (`unknown_node` à la fin). Aucun objet de joueur n'est
  touché.
- **Diffusion** (consignes R-12 de l'Atelier) : `apply` et `remove` ne font que **noter** la zone ; au dernier appel du
  lot (`info.last`), chaque zone notée part une fois : déclarée entière si elle est nouvelle, déplacée si son cercle
  d'intérêt change puis sa **différence** (clés changées et retirées, par paquets de 64 dans le même tour : une seule
  différence par abonné), retirée du core si elle n'existe plus ; la liste de la carte prend une nouvelle version. Garde :
  une zone notée depuis plus de `editor.flushGraceMs` part au passage suivant de la boucle lente (10 s).
- **Essai à blanc** (« Tester la récolte », décision du 31 octobre 2026) : la zone essayée et ses points ne partent
  qu'à leur auteur (`vava_gathering:trial`, entier puis en différences ; `vava_gathering:trialEnd` à la fin), jamais
  dans l'état de la zone ; chez lui, ils remplacent l'affichage de la zone du même nom (les points dont le retrait est
  préparé sont cachés) et l'invite porte « Essai ». Seul l'auteur peut récolter un point d'essai, avec tous les
  contrôles d'une vraie récolte (personnage, pas à terre, distance au début et à la fin, outil en main du bon genre et
  non brisé, durée, jeton, délai) ; à la fin, quantité et palier sont calculés et dits, **rien n'est donné** (ni objet,
  ni XP, ni usure, ni vitalité, ni charge réelle, ni hook `harvesting` / `harvested`), une charge d'essai est prise.
- **Consigne au Conseil** (relecture lore, risque R-2) : une zone publiée fait sortir ses arbres de terre dans la
  seconde sous les yeux des joueurs proches ; publier hors de leur vue, ou l'annoncer en jeu (une coupe ordonnée, une
  mine rouverte par le Conseil…).
- **Arrêt de l'Atelier** : `stop` ou `restart vava_atelier` met fin à tous les essais en cours (leurs auteurs retrouvent
  l'affichage publié).
- **Graine** : sans l'Atelier (absent ou pas encore synchronisé), la récolte tourne sur `config.zones` et
  `config.nodes`, avec un avertissement en console ; l'atelier se redéclare au hook `vava_atelier:editorsReady`.

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
| `config_client.lua` | réglages lus par le client (invite, streaming, carte, touches, genre des outils, part client des ressources, animations) : téléchargé par chaque joueur, ouvre `VavaGathering.config` |
| `config.lua` | tous les autres réglages, servi au seul serveur (en tête des `server_scripts`) : complète la table ; zones et nœuds (graine de l'Atelier), part serveur des ressources et des outils, apparences, atelier |
| `shared/geometry.lua`, `shared/proximity.lua`, `shared/zonestate.lua` | purs, lus par le client et le serveur : distances, groupes du streaming, lecture de l'état des zones (`def`, `p:`, essai, liste de la carte) |
| `shared/season.lua`, `shared/catch.lua`, `shared/editing.lua`, `shared/zonebuild.lua` | purs, servis au seul serveur : facteurs de saison, prise d'un poisson ; atelier « Récolte » (formulaires, conversions, règles, liste de la carte) ; construction de l'état des zones (format compact, cercle, différences, paquets) |
| `client/props.lua`, `blips.lua`, `interact.lua`, `fishing.lua`, `main.lua` | points dans le monde (props locaux à portée, boucle lente arrêtée sans zone suivie, essai de l'Atelier chez son auteur) ; carte ; invite et geste ; barre de tension ; entrée du client |
| `server/catalog.lua`, `zones.lua`, `nodes.lua`, `share.lua` | catalogue mutable ; vitalité et charges (lignes de la base gardées) ; zones du core et différences de l'Atelier |
| `server/atelier.lua`, `trials.lua`, `map.lua` | déclaration de l'atelier et fonctions lues par l'Atelier ; essais à blanc par auteur ; liste de la carte (RPC `map`) |

Fichiers téléchargés par chaque joueur (1.7.0, T-132) : `shared/constants.lua`, `config_client.lua`, les trois
`shared/*.lua` lus par le client, les sept `client/*.lua`, la page et les dessins des objets ; `config.lua`,
`shared/season.lua`, `shared/catch.lua`, `shared/editing.lua` et `shared/zonebuild.lua` sont servis au seul serveur.
Poids du Lua livré (1.8.0) : 71,0 Ko (23,9 Ko compressés), contre 65,5 Ko (22,7) en 1.7.0 : `config_client.lua` perd
4,3 Ko (zones, nœuds, parts serveur), `client/props.lua` et `client/blips.lua` gagnent la lecture de `def` et `p:`,
l'essai et la liste de la carte ; la construction de l'état est servie au seul serveur, et les en-têtes des fichiers
livrés sont courts (relecture réseau R-1 : 82,9 → 71,0 Ko). Le détail des fichiers est dans ce README.

**Mise à jour vers 1.8.0 (T-102)** : `zones` et `nodes` ont quitté `config_client.lua` pour `config.lua` ; la part
serveur des ressources et des outils est passée dans `resourceStats` et `toolStats`. Un `config_client.lua` d'avant
1.8.0 gardé par l'installeur porte encore des zones et des nœuds : ils sont ignorés et la console le dit
(« config_client.lua d'avant 1.8.0 : ses zones et nœuds sont ignorés … »). La graine `prairie_haute` passe à un rayon de
75 m (100 avant) pour respecter la règle de chevauchement de l'Atelier.

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

Exports : `getZone(id)`, `getZones()` (ordre de la graine, puis de création dans l'Atelier), `setVitality(id, 0–100)`,
`nodeState(id)`, `getResource(id)`, `getTool(objet)`, `getSession(joueur)`. RPC `vava_gathering:map` (1.8.0) ;
évènements `vava_gathering:trial` et `trialEnd` (au seul auteur d'un essai). Hooks : `vava_gathering:harvesting` (before, annulable : `{ source, characterId, node, zone,
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
16. **Atelier** (1.8.0) **(3 joueurs)** : créer une zone et cinq points en jeu, les essayer à blanc, publier ; un joueur
    proche les voit apparaître sans redémarrage, un joueur loin ne reçoit rien (`/vava_reseau`). Procédure :
    `docs/tests/atelier.md` § 19 à 24, et `docs/tests/metiers.md` § 3.5 (récolte d'un point publié par l'Atelier).

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
- **1.8.0 (T-102)** : zone et points publiés vus d'un joueur proche en moins d'une seconde, sans redémarrage ; rien chez
  un joueur loin (`/vava_reseau joueur <n°>`) ; changer seulement la fatigue d'une zone n'envoie rien ; essai à blanc vu
  et récolté par son seul auteur (besace, XP et hache inchangées) ; liste de la carte gardée (≈ 30 o à la reconnexion
  suivante) ; `restart vava_gathering` après des changements en jeu : zones et points de la base, pas de la graine ;
  récolte d'un point publié par l'Atelier identique à celle d'un point de la graine (invite, durée, qualité, vitalité).
