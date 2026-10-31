# vava_provisions — les vivres du royaume

L'eau d'Eldoria est à tous, mais il faut aller la chercher, la porter et garder de quoi la contenir. Une **outre
vide** se remplit à un **puits**, une **fontaine** ou une **source** ; on y boit aussi quelques gorgées quand on a soif.
Boire une outre d'eau rend l'outre vide, qui finit par se fendre : une outre neuve se demande à un tanneur (un cuir
donne deux outres), et une outre bien faite tient plus longtemps qu'une outre grossière : le savoir du tanneur compte. Un puits ou une source se vide quand on y puise trop, et se remplit avec le temps ; la fontaine du
bourg est sans fond. Personne n'emporte d'eau sans contenant, et le contenant vient du chasseur et du tanneur.

Le module est le propriétaire des objets `eau` (Outre d'eau) et `outre` (Outre vide), et plus tard du `pain` (tâche à
part). Le serveur décide de tout : le client désigne le point d'eau le plus proche, le serveur relit la distance, ce
que le joueur porte et sa soif, et choisit de remplir ou de boire.

Ordre de démarrage : après `vAvA_core` (≥ 0.11.0 : abonnements de zone, `core.net`), `vava_ui` (≥ 1.0.0 : polices et
grain de l'invite ; à ne jamais arrêter sur un serveur ouvert) et `vava_inventory` (≥ 1.8.0) ; conseillé après
`vava_farming` et avant `vava_codex` et `vava_arrival` (la Chancellerie le place seule). Facultatifs, lus par le bridge
et isolés : `vava_needs` (boire au point d'eau ; sans lui, on ne fait que remplir), `vava_crafting` et `vava_skills`
(recette de l'outre, avant ou après ce module ; sans eux, aucune outre neuve ne se fabrique), `vava_health` (rien à
terre), `vava_hud` (notifications ; sans lui, celles du jeu), `vava_admin` (droit `metiers`, journal du Registre ; sans
lui, ACE `metiers.admin`), `vava_chat` (réponses de `/eau` ; sans lui, une notification au seul membre).

Rendu hors jeu de l'invite : `web/index.html?label=Puits%20du%20lavoir&verb=Puiser&key=E` dans un navigateur, depuis le
dépôt (`web/dev/devmock.js`, jamais livré ; option `--allow-file-access-from-files` pour les polices de `vava_ui`).

## Règles (config.lua, config_client.lua)

Depuis 1.1.0 (T-132), les réglages sont dans deux fichiers et chacun n'est écrit qu'une fois : `config_client.lua`
porte ce que lit le client, et le serveur aussi : `kinds` (entières : le client les lit par sorte et les passe au
carnet des points), `interact.distance`, `streaming` (sauf `zoneRadius` et `subscribeSlack`), `anims`, `keys`,
`labels`, `messages` montrés au joueur (lus clé par clé par `shared/texts.lua`) ; `config.lua` porte tout le reste,
lu par le seul serveur (dont `interact.serverTolerance`, `streaming.zoneRadius`, `streaming.subscribeSlack` et, depuis
1.2.0, les textes du Conseil `messages.admin` et `messages.journal`, ajoutés aux tables ouvertes par
`config_client.lua`), et complète la table sans réécrire une clé de `config_client.lua`.

| Règle | Défaut | Clé |
|---|---|---|
| Objets déclarés s'ils manquent | `eau` (Outre d'eau : 1 × 2, pile de 5, 700 g, soif + 40, `boisson` — définition de `vava_arrival` 1.0.0 gardée telle quelle) et `outre` (Outre vide : 1 × 2, pile de 5, 150 g, `divers`) ; image `nui://vava_provisions/web/items/<nom>.svg` ajoutée à la déclaration ; un objet déjà déclaré par une autre ressource n'est pas remplacé (avertissement en console) | `items` |
| Remplir | un appui remplit au plus 5 outres vides : outres prises pile par pile (les plus anciennes d'abord, tous paliers confondus) et eau donnée **en un seul échange tout ou rien** ; chaque Outre d'eau garde le palier de son outre (`{ tier }`, seule métadonnée gardée), une outre sans palier donne une Outre d'eau sans palier (1.3.0, T-135) | `fill` |
| Outre rendue | boire une Outre d'eau rend une Outre vide **du même palier**, sauf quand elle se fend (avis au buveur) ; sans place dans la besace, elle est abandonnée (avis) ; une outre au plus par unité réellement bue | `containers` |
| Usure selon le palier | risque de fente à chaque Outre d'eau bue, selon le palier de l'outre (savoir du tanneur) : Grossière 15 %, Commune 10 %, Soignée 5 %, Excellente 2,5 %, Chef-d'œuvre 1 % ; sans palier (dotation, outres d'avant 1.3.0) 10 % — **valeurs provisoires** (T-135), à trancher ; liste de 1 à 5 risques de 0 à 1, jamais plus haut qu'au palier d'avant, un palier absent de la liste prend le risque sans palier (1.3.0) | `containers.eau.tearChanceByTier`, `containers.eau.tearChance` |
| Outres neuves | recette « Outre » à la tannerie (`vava_crafting`, compétence Tannerie, niveau 0, 6 s, 1 cuir → 2 outres, 8 XP), ni signée ni transmise ; ajoutée aux registres de l'artisanat et des compétences dès qu'ils sont là | `recipe` |
| Boire au point d'eau | soif + 20, refusé dès 95 (même seuil que `vava_needs`) ; la réserve n'est pas touchée | `drink` |
| Délai | 3 s entre deux actions d'un même joueur (puiser ou boire), tenu par le serveur | `cooldownMs` |
| Sortes de points | **puits** : 40 puisages, + 1 par minute ; **source** : 15 puisages, + 1 toutes les 3 min ; **fontaine** : sans fond ; on boit aux trois | `kinds` |
| Points d'eau | Fontaine du bourg, Puits du lavoir, Source de la Rivière Claire (exemples `-- PLACEHOLDER`) ; la config est la graine, l'Atelier les reprendra | `points` |
| Nombre de points | 256 au plus (config et ajouts) | `maxPoints` |
| Portée | invite et usage à 2 m (client) ; le serveur accepte jusqu'à 3,5 m (latence), distance 3D lue sur le ped | `interact` |
| Props | locaux, créés à 80 m, groupés par case de 200 m ; un passage par seconde près d'un groupe, toutes les 2,5 s au-delà de 140 m ; zone du core de 2 m connue à 100 m | `streaming` |
| Gestes | puiser : `WORLD_HUMAN_GARDENER_PLANT` 2,5 s ; boire : `mp_player_intdrink` `loop_bottle`, haut du corps, 2,5 s (`-- PLACEHOLDER`, animations vanilla) | `anims` |
| Touche | `E` (réglable par le joueur), libellé « Puiser ou boire (point d'eau proche) » | `keys`, `labels` |
| Conseil | `/eau`, droit `metiers` (Sénéchal et au-dessus, comme `/agriculture`), ACE `metiers.admin`, 1 s entre deux commandes d'un membre (console exceptée) | `admin` |
| Débit | RPC `vava_provisions:draw` : 3 d'avance, puis 1 toutes les 2 s, par joueur | `rateLimits.draw` |
| Textes | notifications de 200 octets au plus, texte brut ; libellé du journal du Registre de 32 octets au plus | `messages` |

La config est vérifiée au démarrage (`rules.validateConfig`) : une valeur hors bornes refuse le module avec le chemin
fautif (« config : points[2].label : invalid_label »).

Bilan d'une outre : la soif passe de 100 à 0 en 3 h (`vava_needs`), une Outre d'eau vaut 40, soit environ 0,8 outre
par heure de jeu ; une outre sans palier fait en moyenne 10 usages, donc 12 h de jeu environ. Les deux outres de la
dotation donnent environ 24 h de jeu avant de devoir passer chez un tanneur (en moyenne : le tirage est indépendant à
chaque gorgée). Selon le palier (valeurs provisoires) : Grossière environ 7 usages (8 h), Commune 10 (12 h), Soignée 20
(25 h), Excellente 40 (50 h), Chef-d'œuvre 100 (125 h). Une outre de débutant s'use plus vite que celle de la dotation ;
celle d'un tanneur confirmé dure deux à quatre fois plus : on revient chez lui, et on s'adresse à lui plutôt qu'au
premier venu.

### Palier de l'outre (1.3.0, T-135)

Le palier est la métadonnée `tier` (1 Grossier, 2 Commun, 3 Soigné, 4 Excellent, 5 Chef-d'œuvre) que `vava_crafting`
pose sur l'outre neuve (`{ tier }`, produit simple). Le serveur le suit seul, d'un bout à l'autre :

1. **au point d'eau**, après le hook `drawing`, il relit les piles d'outres vides du joueur (`getItems`) et les prend
   pile par pile par leur identifiant ; chaque Outre d'eau donnée porte `{ tier }` de son outre (aucune métadonnée
   pour une outre sans palier). Une outre partie pendant le hook : moins d'outres remplies ; aucune : « Il vous faut une
   outre vide… » ;
2. **à la gorgée**, un abonné `before` de `vava_inventory:use` (priorité 1000, après les autres abonnés ; il ne refuse
   jamais) relève le palier de la pile d'Outres d'eau visée, car la pile disparaît avec sa dernière unité ; en phase
   `after`, si l'unité a été bue, le risque de fente est celui de ce palier et l'Outre vide rendue porte `{ tier }`.
   Sans relevé (pile introuvable, inventaire muet, gorgée commencée avant un redémarrage du module), l'outre est
   traitée sans palier. Au plus 8 relevés gardés par joueur (gorgées refusées par un autre abonné), oubliés quand il
   part ou change de personnage.

Empilement (règle de `vava_inventory` : métadonnées strictement identiques) : deux outres du même palier s'empilent, et
une outre rendue rejoint les outres neuves de son palier ; deux paliers différents, ou un palier et une outre sans
palier, font deux piles (et ne fusionnent pas à la main). Une autre métadonnée qu'un module poserait sur une outre
(origine, nom) n'est pas gardée : seul le palier passe.

### Au point d'eau, pas à pas

Le serveur choisit (`rules.decide`), dans cet ordre :

1. outres vides en besace **et** au moins un puisage disponible → remplir `min(outres, 5, disponible)` outres ;
2. sinon, la sorte permet de boire, la soif est lue (`vava_needs`) et sous 95 → boire quelques gorgées (avec
   « Trop peu d'eau pour remplir une outre… » si l'on avait des outres vides) ;
3. sinon, des outres vides → « à sec » et l'attente en minutes ;
4. sinon, la soif est lue → « Vous n'avez pas soif. Pour emporter de l'eau, il vous faut une outre vide. » (on
   n'arrive ici que sans outre vide) ;
5. sinon → « Il vous faut une outre vide pour emporter de l'eau. ».

Avant d'agir, le hook `vava_provisions:drawing` (annulable) laisse un autre module refuser (source empoisonnée, puits
gardé, confrérie) : sa raison est montrée au joueur, coupée à 200 octets. Après lui, le serveur relit le personnage et
la distance (le hook a pu céder la main). Si le remplissage est refusé par la besace (pleine, trop lourde) et que le
joueur a soif là où l'on peut boire, il boit sur place (« Votre besace est pleine. Vous buvez quelques gorgées… ») ;
les puisages réservés sont rendus et le délai de 3 s est posé.

### Où poser les points d'eau

La fontaine est sans fond : c'est voulu, mais elle ne doit pas rendre le reste inutile. Placer les **fontaines au cœur
du bourg** (là où l'on se croise), et les **puits et sources dans les hameaux, aux champs, près des mines et des
chantiers**, loin d'une fontaine : là-bas, l'eau se compte et se tarit, et **porter l'eau devient un service** qu'on rend
ou qu'on troque.

### Recettes qui consomment de l'eau

Aucune aujourd'hui. Une recette future qui consomme `eau` doit rendre `outre` dans sa sortie, sinon l'outre est
perdue.

## Données

Aucune table SQL, aucune migration, aucun champ de personnage.

- Les **points** sont la config (graine) ; plus tard, les définitions de l'Atelier.
- Les **réserves** vivent en mémoire et repartent pleines à chaque démarrage du module (au pire 40 outres de plus pour
  un bien sans valeur marchande). Rien n'est journalisé des puisages : puiser à un puits public n'est ni un échange,
  ni un don, ni un retrait d'un stock déposé par des joueurs.
- Le réglage d'une réserve par le Conseil (`/eau reserve`) va au journal du Registre (`vava_admin`).
- Une outre de la tannerie porte `{ tier }` (règle de l'artisanat) ; l'Outre d'eau qu'on en tire et l'outre vide
  rendue après la gorgée gardent ce palier (1.3.0, T-135), qui règle son usure. Une outre sans palier (dotation de
  `vava_arrival`, catalogue, outres d'avant 1.3.0) reste sans métadonnées : elle s'empile avec les autres outres sans
  palier, jamais avec une outre d'un palier. Rien n'est écrit en base par ce module : le palier vit dans la pile de
  l'inventaire.

## Réseau

| Quoi | Cible | Taille | Fréquence |
|---|---|---|---|
| état de la zone d'un point (`def` : sorte, nom, lieu ; cap s'il n'est pas nul, modèle s'il diffère de celui de la sorte, que le client lit dans sa config), envoyé par le core | les seuls joueurs à moins de 102 m du point (rayon 2 + marge 100, au sol), décidés par le serveur sur la position qu'il lit | ~160 o par point | une fois à l'arrivée ; de nouveau seulement si la définition change (Atelier, plus tard) |
| RPC `vava_provisions:draw` (identifiant du point, 32 octets, motif ancré) | — | ~45 o montants, ~40 o de réponse | à chaque appui, 3 d'avance puis 1 par 2 s |
| `vava_provisions:notice` (`torn` ou `lost`) | le **seul** joueur qui vient de boire une outre d'eau fendue ou sans place | ~35 o | selon le palier de l'outre, de 1 % (Chef-d'œuvre) à 15 % (Grossière) des outres bues, 10 % sans palier (`torn`) |
| `vava_provisions:notify` (texte) | le **seul** membre du Conseil qui a tapé `/eau`, sans `vava_chat` | 50 à 120 o par ligne | à la demande |

Rien d'autre : aucun envoi à tous, aucun `sendNear`, aucun GlobalState, aucun state bag. La réserve n'est jamais
publiée (elle changerait à chaque puisage) : le joueur l'apprend en puisant, le Conseil par `/eau points`. Le geste est
une animation locale du ped, que les autres voient par la synchronisation du moteur. L'état d'une zone est public pour
quiconque peut s'en approcher : il n'y a rien de secret dedans, et l'abonnement n'accorde rien (distance relue à
chaque appel).

Côté client : **aucune boucle loin de tout point d'eau** (0,00 ms) ; près d'un point, une mesure par seconde (≤ 0,01 ms)
qui crée et retire les props locaux et calcule l'invite ; l'invite n'est envoyée à la page que quand elle change ; un
thread par geste accepté (`Wait` de la durée du geste, jamais `Wait(0)`).

## Sécurité

Le RPC `vava_provisions:draw` revérifie, dans l'ordre : personnage actif ; une demande à la fois par joueur (`busy`,
rendu même en erreur) ; délai de 3 s ; à terre (`vava_health`) ; point connu ; **distance réelle** du ped (3,5 m, 3D) ;
outres vides **réellement possédées** (compte de l'inventaire) ; soif lue côté serveur ; réserve ; choix de l'action ;
hook annulable, puis personnage et distance relus, et les piles d'outres relues (identifiants et paliers lus par le
serveur dans la besace : le client ne dit rien du palier). Les payloads des hooks sont reconstruits par le serveur à chaque
appel (un abonné de `drawing` ne change rien à `drawn`). Remplir : les puisages sont **réservés avant** l'échange (rien ne cède la main entre la lecture et la
réservation), l'échange est **tout ou rien**, et la réserve est rendue s'il échoue — deux joueurs sur la dernière
unité : un seul est servi. L'outre rendue ne l'est que si l'inventaire dit `consumed` (une unité réellement retirée),
dans un thread, pour le même personnage. Limite connue de OneSync : la position du ped est déclarée par son client ;
le gain d'un tricheur serait de l'eau, sans valeur marchande.

## Conseil (droit `metiers`)

`/eau points` : chaque point, son identifiant, sa sorte et sa réserve (« 12 / 40 puisages » ou « sans fond »), dans le
chat du seul membre (lecture seule) ; les lignes sont regroupées en messages de 480 octets au plus (`admin.replyBytes`,
sous les 500 signes de `vava_chat`), 60 points au plus (`admin.listMax`), puis « … et N autres points d'eau. ».
`/eau reserve <point> <nombre>` : fixe ce qu'on peut encore puiser à un puits ou une source (0 à sa capacité ; refusé
pour une fontaine sans fond) ; inscrit au journal du Registre (« Réserve d'eau fixée », point, ancienne et nouvelle
réserve). Console du serveur : `eau points`, `eau reserve …`. Sans droit : rien, aucune réponse.
Les deux actions sont au Codex (chapitre « Vivres »), la liste des points par l'export `codexList('points')`.

## API

- Exports serveur : `getPoints()`, `getPoint(id)`, `pointNear(source, radius?)`, `codexList(name)` (voir
  `docs/api.md` § `vava_provisions`).
- Hooks émis : `vava_provisions:drawing` (`before`, annulable), `vava_provisions:drawn` (`after`).
- Hooks écoutés : `vava_inventory:use` (before, priorité 1000 : palier relevé, jamais de refus ; after),
  `core:module:ready` (inventaire, artisanat, compétences),
  `core:character:unloading`, `core:player:dropped`.

## Atelier (plus tard)

Rien n'est déclaré au registre `vava_atelier:editors` dans 1.0.0. Les données sont prêtes : un point est une table plate
`{ id, kind, label, x, y, z, heading, model }` ; `rules.validatePoint` est le seul juge ; `points.put(def)` déclare ou
déplace la zone et garde la réserve d'un point qui garde sa sorte ; `points.drop(id)` le retire. Un point **en essai**
ne passera pas par sa zone mais par `core.net.send` à son seul auteur.

## Installation

`ensure vava_provisions` après `ensure vava_farming` et avant `ensure vava_codex` et `ensure vava_arrival` (la
Chancellerie le place seule). Aucune migration. `vava_arrival` 1.1.0 ne déclare plus `eau` : démarré avant
`vava_provisions`, il reporte la dotation d'un personnage qui apparaît entre-temps et la reprend à l'annonce de ce
module. Les piles d'`eau` et d'`outre` en besace quand le module ne tourne pas sont gardées à part par l'inventaire et
rendues à sa déclaration : rien n'est perdu.

**Assets à brancher** (`-- PLACEHOLDER`) : modèles des sortes (`kinds.*.model` : puits, fontaine, rocher de source)
et gestes (`anims`) dans `config_client.lua`, coordonnées des points (`points`) dans `config.lua`. Un point posé sur un décor de la carte prend
`model = ''` (aucun prop). Ne jamais poser un point à moins de 5 m d'une autre cible de la touche `E` (puits de
`vava_farming`, stations, nœuds de récolte) : deux invites sur la même touche. Placement : voir « Où poser les points
d'eau » (fontaines au cœur du bourg, puits et sources dans les hameaux).

**Mise à jour vers 1.1.0 (T-132)** : les sortes de points d'eau, la portée de l'invite, le streaming, les gestes, la
touche et les textes ont quitté `config.lua` pour `config_client.lua`. Un `config.lua` modifié et gardé par
l'installeur de la Chancellerie (le nouveau posé en `config.lua.nouveau`) garde l'ancienne forme : le module démarre,
mais la console le signale (« config.lua garde la forme d'avant 1.1.0 … ») et un réglage client changé dans ce fichier
reste sans effet. Reportez vos réglages dans `config.lua` et `config_client.lua` d'après les nouveaux fichiers.

**Mise à jour vers 1.3.0 (T-135)** : `containers.eau.tearChanceByTier` (risque de fente selon le palier) s'ajoute à
`config.lua`. Un `config.lua` de 1.2.0 modifié et gardé par l'installeur ne l'a pas : le module démarre, et toutes les
outres gardent le risque sans palier (`tearChance`, une fois sur dix) ; reportez la ligne d'après `config.lua.nouveau`.
Le palier est gardé dès 1.3.0 quel que soit ce réglage. Les Outres d'eau remplies avant 1.3.0 n'ont pas de palier :
elles rendent une outre sans palier.

**Mise à jour vers 1.2.0 (T-143)** : les textes du Conseil (`messages.admin`, réponses de `/eau` ; `messages.journal`,
libellé du journal du Registre) ont quitté `config_client.lua` pour `config.lua`, et les règles (`shared/rules.lua`)
ne sont plus servies aux joueurs : les textes qu'ils voient sont formés par `shared/texts.lua`. Un `config.lua` de
1.1.0 modifié et gardé par l'installeur n'a pas ces textes : le module refuse alors de démarrer (« config.lua d'avant
1.2.0 : messages.admin et messages.journal … y manquent ») ; reportez-les d'après `config.lua.nouveau`. À l'inverse,
un `config_client.lua` de 1.1.0 gardé les sert encore aux joueurs sans servir : la console le signale
(« config_client.lua garde les textes du Conseil d'avant 1.2.0 … ») ; retirez-les d'après `config_client.lua.nouveau`.

## Fichiers

| Fichier | Rôle |
|---|---|
| `config_client.lua` | réglages lus par le client (sortes de points d'eau, portée, streaming, gestes, touche, textes montrés au joueur) : téléchargé par chaque joueur, ouvre `VavaProvisions.config` |
| `config.lua` | tous les autres réglages, servi au seul serveur (en tête des `server_scripts`) : complète la table |
| `shared/texts.lua`, `shared/pointzone.lua`, `shared/proximity.lua` | purs, lus par le client et le serveur : textes montrés au joueur, carnet des points, groupes du streaming |
| `shared/rules.lua` | pur, servi au seul serveur : validation des points et de la config, réserves, choix de l'action, `/eau` (1.2.0, T-143), palier de l'outre (lu, gardé, risque de fente, remplissage pile par pile : 1.3.0, T-135) |

Fichiers téléchargés par chaque joueur (1.2.0, T-132 et T-143) : `shared/constants.lua`, `config_client.lua`,
`shared/texts.lua`, `shared/pointzone.lua`, `shared/proximity.lua`, les cinq `client/*.lua`, la page de l'invite et
les dessins des objets ; `config.lua` et `shared/rules.lua` sont servis au seul serveur.

## Tests

Hors jeu : `tests/spec/provisions_rules_spec.lua` (règles pures, textes et config), `tests/spec/provisions_pointzone_spec.lua`
(état de zone et carnet du client), `tests/spec/provisions_client_view_spec.lua` (carnet, invite et textes sur la
seule vue client : `config_client.lua` sans `config.lua`), `tests/spec/provisions_server_spec.lua` (puiser, boire, réserves, outre rendue,
palier gardé et risque selon le palier, objets, recette, `/eau`, démarrage réel sur un core simulé),
`tests/spec/provisions_outre_tier_spec.lua` (palier de l'outre sur l'inventaire réel : empilement par palier, remplir,
boire jusqu'à la dernière unité, tirage, gorgée refusée), `tests/spec/props_proximity_spec.lua` (streaming). En
jeu : `docs/tests/eau.md`.

## À vérifier en jeu

- Le geste `WORLD_HUMAN_GARDENER_PLANT` (puiser) et `mp_player_intdrink` (boire) tiennent 2,5 s et s'arrêtent net
  (eau 5 et 6).
- Le prop `prop_barrel_01a` posé au sol (`PlaceObjectOnGroundProperly`) aux coordonnées d'exemple ; `z` des points au
  niveau du sol, sinon le serveur répond `too_far` (eau 4).
- Aucune autre invite sur `E` à moins de 2 m des trois points d'exemple (stations, puits de l'agriculture, nœuds). La
  source d'exemple a été posée à (-118, -876) pour rester à 10 m du nœud de truite de la Rivière Claire.
- La recette « Outre » apparaît au menu de la Tannerie du bourg et se réalise (eau 19).
- Palier de l'outre (1.3.0) : une outre de la tannerie remplie puis bue revient au même palier, badge compris, et
  rejoint la pile de son palier ; deux paliers ne s'empilent pas (eau 28 à 31). La relecture des piles par l'abonné
  `before` de `vava_inventory:use` (appel à l'inventaire pendant son propre hook, lecture seule) ne fait ni erreur ni
  refus en console (eau 30).
