# vava_crafting — l'artisanat du royaume

Forge, établi, métier à tisser, alambic, tannerie, fourneau et table d'arcanes : des **stations** publiques ou privées,
avec leur qualité et parfois leur combustible, où l'on réalise des **recettes** connues avec les matières de son choix.
La qualité d'une pièce vient des matériaux, de la main de l'artisan et de la station, et ne dépasse jamais son niveau.
Les outils, armes, armures, bijoux, objets magiques et grandes potions sont des **objets signés** : qualité, solidité,
créateur figé, poinçon, baptême d'un chef-d'œuvre, histoire des réparations. Réaliser une recette transmise devant un
élève lui vaut une leçon. Le serveur décide de tout et demande l'XP à `vava_skills`.

Ordre de démarrage : après `vAvA_core` (≥ 0.11.0 : abonnements de zone), `vava_ui` (≥ 1.0.0, polices, grain, papier et coins des
interfaces ; à ne jamais arrêter sur un serveur ouvert), `vava_inventory` (≥ 1.4.0), `vava_skills` (≥ 1.0.0) et
`vava_gathering` (≥ 1.0.0 : matières et outils de base). Facultatifs : `vava_hud`, `vava_admin` (droit `metiers`),
`vava_chat`, `vava_health` (aucun artisanat à terre).

Rendu hors jeu : `web/index.html?view=menu` (ou `menu&tab=reparation`, `menu&tab=poincon`, `prompt`, `name`) dans un
navigateur, depuis le dépôt (option `--allow-file-access-from-files` pour les polices), avec les données simulées de
`web/dev/devmock.js` (jamais livré).

## Règles (config.lua, config_client.lua)

Depuis 1.6.0 (T-132), les réglages sont dans deux fichiers et chacun n'est écrit qu'une fois : `config_client.lua`
porte ce que lit le client, et le serveur aussi : `masterpiece.nameMin` et `nameMax`, `repair.durationMs`,
`interact.distance` et `interact.moveCancel`, `streaming` (sauf `zoneRadius` et `subscribeSlack`), `keys`, `labels`,
`anims` ; `config.lua` porte tout le reste, lu par le seul serveur (dont le palier, la fenêtre et les lettres du
baptême, les parts de la réparation, les tolérances des gestes, la zone des stations, ajoutés aux tables ouvertes par
`config_client.lua`), et complète la table sans réécrire une clé de `config_client.lua`. Depuis 1.7.0 (T-144), les
**types de stations** (`stationTypes`) sont dans `config.lua` : le client ne les lit plus, le nom du type, sa réserve
de combustible et son modèle arrivent avec le dessin de chaque station, et l'animation d'un geste avec la réponse du
serveur. Une station d'un type déclaré par un autre module (le composteur de `vava_farming`) a donc son invite et son
menu comme les autres.

| Règle | Défaut | Clé |
|---|---|---|
| Qualité | matériaux × 0,5 + niveau × 0,4 + station × 0,1 ± 5, plafonnée par le niveau | `quality` |
| Paliers | Grossier < 20, Commun, Soigné 40, Excellent 60, Chef-d'œuvre 85 ; palier de matière → qualité 10, 30, 50, 72, 92 | `tiers` |
| Matériaux | palier **choisi par ingrédient** parmi ceux possédés (défaut : le plus bas ≥ minimum) ; consommés par pile, les plus anciennes d'abord | menu |
| Objet signé | `signed`, ou `signedIfQuality` (potions) ; non empilable ; solidité initiale `durability` | `recipes[]` |
| Chef-d'œuvre | palier 5 ; baptême pendant 5 min depuis la station ; nom de 2 à 32 lettres | `masterpiece` |
| Poinçon | glyphe parmi 18, un par personnage, dès Compagnon dans une compétence d'artisanat | `mark` |
| Histoire | création + 5 dernières entrées | `history` |
| Réparation | 25 % des ingrédients (arrondi au-dessus), solidité rendue, solidité maximale − 5, niveau ≥ moitié de la recette, XP 25 %, 4 s | `repair` |
| Durée | base × (1 − niveau × 0,004), 1,5 s au moins | `duration` |
| Station tenue | une pièce jamais finie libère la station après 2 min, ou après sa durée + 30 s si c'est plus long | `interact.expireMs`, `interact.expireMarginMs` |
| Leçons | élèves à 10 m qui ont le niveau, recette `transmission` | `lessons` |
| Combustible | forge : charbon ; fourneau : bois de pin ; 1 par pièce, réserve 20 | `stationTypes[].fuel` |
| Props | créés par le client à 80 m ; stations groupées par case de 200 m, seules celles d'une case à portée sont mesurées ; relues toutes les secondes près d'une case, toutes les 2,5 s quand aucune station n'est à moins de 140 m (80 m + 60 m de marge d'approche) (1.3.2) ; aucune boucle tant qu'aucune station n'est connue (1.5.0) | `streaming` |
| Stations connues du joueur | une zone du core par station, de 2 m ; reçue (dessin, combustible, occupation) à 100 m de son bord (80 m des props + 20 m : le chemin d'un cavalier au galop entre deux passages du core), oubliée au-delà de 125 m (marge de sortie du core) (1.5.0) | `streaming.zoneRadius`, `streaming.subscribeSlack` |
| Recettes inconnues des compétences | une ligne en console par recette absente de `vava_skills:recipes`, 5 s après le démarrage, l'ajout d'une recette par un autre module ou le retour de `vava_skills`, 20 s au plus après la première demande ; délai borné de 1 s à 10 min ; verrouillée au menu (1.8.0) | `skillsCheck.delayMs` |
| Journal | pièces Excellent+ (palier ≥ 4), réparations, baptêmes, leçons, Conseil, écritures refusées par la garde ; 180 jours | `logTier`, `logRetentionDays` |
| Signature protégée | créateur, date, poinçon et qualité figés sur tout objet ; sur un objet signé, palier et nom figés, solidité qui ne remonte pas hors d'une réparation (voir plus bas) ; refus journalisés une fois par minute et par objet, module et clé | `guard` (`windowMs`, `maxTracked`, `bornDurability`) |

### Stations

Un **type** (compétences servies, combustible, animation, prop ; `config.lua` ou registre `vava_crafting:stations`,
connu du seul serveur) et des **instances** placées (position, nom, qualité
0–100, propriétaire : nulle = publique, `{ kind = 'character', id }` = privée ; d'autres genres — foyer — se branchent
par `registerAccess`). Une seule pièce à la fois par station. Les stations livrées sont des **exemples** avec des props
du jeu de base. L'animation d'un type, de la config ou d'un autre module, doit être une clé de `anims`
(`config_client.lua`) : sinon le type est refusé au registre (1.7.0), et un type de la config refuse le module.

### Réseau : une zone du core par station (depuis 1.5.0)

Chaque station placée (config, ou `addStation` d'un autre module) est une **zone du core** (`core.zones`, abonnements de
zone de vAvA_core 0.11.0) nommée par son identifiant : cercle de 2 m autour d'elle, marge de 100 m. Son état :

| Clé | Valeur | Quand elle part |
|---|---|---|
| `def` | `{ type, typeLabel, capacity?, label, x, y, z, heading, prop }` : ce qu'il faut pour la dessiner et pour son invite — nom du type, réserve de combustible (absente sans combustible, 1.7.0) — (ni qualité ni propriétaire) | à l'entrée d'un joueur dans la zone (état entier), et si la station est déplacée ou renommée |
| `s` | `{ fuel, busy }` | à l'entrée, puis à chaque changement, en différence (environ 34 o), aux seuls joueurs qui suivent la zone |

- **Qui la reçoit** : le core décide seul, chaque seconde, d'après la position que lit le serveur ; personne ne la
  demande. Un joueur loin de toute station ne reçoit rien et n'en connaît aucune ; au bourg, l'arrivée coûte environ
  1,5 Ko pour les 7 stations livrées (une fois ; nom du type et réserve compris depuis 1.7.0), puis 34 o par
  changement.
- **Plus de GlobalState** : ni l'état `{ fuel, busy }` publié à tous, ni la liste des stations réécrite à chaque
  station ajoutée. Au démarrage, les anciennes clés `vava_crafting:station:<id>` et `vava_crafting:stations` sont
  effacées une fois si elles existent encore (serveur pas redémarré depuis 1.4.0). Seules les stations encore connues
  sont vues : après une mise à jour depuis 1.4.0 qui retire des stations de la config, **redémarrer le serveur**, pas
  seulement la ressource.
- **Station ajoutée, déplacée ou renommée en jeu** (module, Atelier, Conseil) : arrive chez les joueurs proches au
  passage suivant (1 s au plus), sans reconnexion ; les autres la reçoivent en arrivant. Seuls un lieu, un cap, un
  modèle ou un type changés recréent le prop ; un nom, un nom de type ou une réserve changés ne mettent à jour que
  l'invite, aussitôt (1.7.0). Une station de la config que
  le core refuse (plus de place, lieu hors bornes) est écrite en console et retentée par la boucle d'écriture une fois
  par minute au plus ; un état qui n'a pas pu partir est renvoyé au passage suivant de cette boucle (10 s). Une station
  placée par `addStation` que le core refuse n'est pas placée : `false, 'zones_full'` (trop de zones) ou
  `'zone_refused'`. Le déplacement, le renommage et le retrait en jeu (Atelier, Conseil) restent à brancher (T-101,
  T-102) : `stations.share` sait déplacer une station, le retrait demandera un `RemoveZone` au bridge.
- **Arrivée** : une station reçue, déplacée ou oubliée fait aussitôt un passage du client, même quand la boucle tourne
  déjà pour une autre station : son prop n'attend pas un intervalle lent (2,5 s).
- **Menu ouvert** : il suit le combustible et l'occupation reçus par la zone (plus d'évènement `vava_crafting:station`),
  et se ferme si la station est oubliée (joueur éloigné de plus de 125 m, station retirée).
- **Public** : l'état d'une zone est lu par quiconque s'approche (sous OneSync, la position est déclarée par le client) ;
  il ne contient rien de secret. Chaque action (menu, pièce, fin du geste, combustible, réparation) revérifie côté
  serveur, au moment de l'action, la distance réelle, l'accès et l'occupation, sans se fier à l'abonnement.
- **Sons, effets, messages d'une station** (à venir) : aux seuls abonnés de sa zone (`core.zones.subscribers(id)`) ou
  aux joueurs à portée (`core.net.sendNear`), jamais à tous.

### Recettes

`config.recipes` → registre `vava_crafting:recipes` (données complètes) et `vava_skills:recipes` (compétence, niveau,
`transmission`, `fragments`). Une recette : ingrédients (objet, quantité, palier minimal), produit, type de station,
outil requis en main (`tools` : marteau de forge), durée, difficulté, XP, signée ou non, solidité. Une recette transmise
inconnue n'apparaît pas dans le menu ; une recette libre au niveau insuffisant apparaît verrouillée.

**Recette inconnue des compétences** (depuis 1.8.0, T-147) : un autre module qui ajoute une recette à
`vava_crafting:recipes` doit aussi la déclarer à `vava_skills:recipes` (comme `vava_farming`, `vava_provisions`,
`vava_combat`), sinon `vava_skills` ne la connaît pas et la station la refuse (`not_known`). L'artisanat le signale :
une ligne `WARN` par recette absente, avec son nom et le module qui l'a déclarée (« recette 'x' (déclarée par y)
absente de vava_skills:recipes … »), une seule fois, `skillsCheck.delayMs` (5 s) après le démarrage, après l'ajout
d'une recette par un autre module, après le retrait d'une recette des compétences, et de nouveau au retour de
`vava_skills` (le temps que chaque module ait redéclaré les siennes) ; des demandes rapprochées ne repoussent pas le
contrôle au-delà de 4 × le délai (borné de 1 s à 10 min) ; une recette signalée puis déclarée aux compétences relance
le contrôle, et une ligne d'information dit qu'elle est déverrouillée ; registre des compétences absent : une seule
ligne ; lecture du registre en échec : une seule ligne, rien de signalé à tort. Le menu n'envoie plus le champ `known`,
lu par personne. Au menu, une telle recette libre est montrée **verrouillée** (« Indisponible », raison « Cette recette ne peut ni se façonner
ni s'apprendre : prévenez le Conseil. ») au lieu d'être proposée puis refusée au clic ; une recette
transmise inconnue des compétences reste cachée, comme toute recette transmise inconnue. Le serveur reste juge : le
début d'une pièce revérifie `knowsRecipe`.

**Contenu de départ** : charbon de bois et ragoût (fourneau) ; lingots de fer et de cuivre, hache, pioche, faucille,
couteau, épée courte (transmise) à la forge ; marteau de forge, canne à pêche, anneau de cuivre à l'établi ; cuir et
cuir épais (tannerie) ; veste de cuir (couture) ; potion de soin (alambic, signée à partir de 60) ; talisman (table
d'arcanes, transmis, trois fragments). Amorçage : les lingots se fondent sans outil, le marteau se fait à l'établi
sans outil, puis la forge s'ouvre.

### Une pièce

1. `E` près d'une station → menu : recettes connues ici, paliers possédés par ingrédient avec **aperçu de qualité**,
   réparables, combustible, poinçon.
2. Façonner → le serveur vérifie : station à portée, accessible et libre ; recette connue, au niveau ; outil en main du
   bon genre, non brisé ; combustible ; paliers choisis valides et possédés ; place ; hook `vava_crafting:crafting`.
3. Geste et barre du HUD ; se déplacer interrompt.
4. Fin : durée et distance revérifiées (trop loin : la pièce est abandonnée, rien n'est consommé, la station est
   libérée aussitôt), outil et combustible, piles relues et **consommées par instance** au palier choisi, qualité
   tirée, objet signé (`quality`, `tier`, `durability`, `max_durability`, `crafter_id`, `crafter_name`, `mark`,
   `crafted_at`, `history`) ou produit simple (`tier`), **échange atomique**, combustible, XP, leçons, baptême proposé
   pour un chef-d'œuvre, journal, hook `crafted`.

### Réparation

Depuis le menu, sur un objet signé usé ou brisé dont la recette est servie par la station : une part des ingrédients,
la solidité revient à une maximale réduite de 5, l'histoire garde « réparation par … », `broken` disparaît ; le
créateur n'est jamais touché. Finir trop loin abandonne la réparation (rien n'est consommé) et libère la station.

### Signature protégée (depuis 1.3.0)

L'artisanat s'abonne en `before` au hook `vava_inventory:metadata` : un autre module qui écrit des métadonnées
(`setMetadata`, `patchMetadata`) ne peut ni contrefaire ni réécrire une signature, ni réparer un objet signé hors d'une
station.

| Objet | Refusé (code) | Admis |
|---|---|---|
| Tout objet | changer, poser ou retirer `crafter_id`, `crafter_name`, `crafted_at`, `mark`, `quality` (`signature_locked`) | tout le reste |
| Objet signé (`crafter_id` présent) | changer ou retirer `tier`, poser, changer ou retirer `name` (`signature_locked`) ; faire monter, retirer, ou remplacer par autre chose qu'un nombre `max_durability` ou `durability`, retirer `broken` d'un objet brisé, donner à un objet qui n'en avait pas une solidité négative, non numérique, au-dessus du plafond, ou une courante au-dessus de sa maximale (`durability_locked`) | solidité qui baisse (usure de la récolte, dommage), solidité donnée à un objet qui n'en avait pas jusqu'au plafond (`guard.bornDurability`, 100, ou la solidité de sa recette si elle est plus haute), `broken` posé, `history`, `lines`, toute autre clé |
| Objet ordinaire (sans `crafter_id`) | — | tout le reste, palier d'une matière et solidité d'un outil compris |

- Les écritures de l'artisanat lui-même (réparation, baptême) passent : l'inventaire les attribue à `vava_crafting`
  (`owner`, lu par `GetInvokingResource`) **et** elles partent de `Bridge.PatchMetadata`, qui lève un compteur autour
  de son seul appel à l'inventaire. La création d'une pièce passe par l'échange atomique (hook `add`), pas par ce hook.
- Un `setMetadata` d'un autre module sur un objet signé doit donc reporter ces clés telles quelles.
- Le module appelant reçoit toujours `false, code`. Un refus est inscrit au journal (`signature_locked` ou
  `durability_locked` : module, clé, objet, créateur) et signalé en console **une fois par fenêtre** pour un même
  module, un même objet et une même clé (`guard.windowMs`, 60 s) ; les suivants sont comptés et annoncés avec le
  prochain refus signalé (« [n refus semblable(s) tu(s)] », `untold` au journal). Au plus `guard.maxTracked` (500)
  refus distincts suivis à la fois : au-delà, un refus nouveau est seulement compté jusqu'à la purge suivante (une
  fois par fenêtre). Un module qui insiste ne remplit donc ni le journal ni la console (depuis 1.3.1).
- La garde ne vaut que pendant que `vava_crafting` tourne (ses hooks tombent à son arrêt). Elle ne couvre pas un objet
  **créé** déjà signé par un autre module (`add`, `exchange`), qui passe par d'autres hooks.

## Fichiers

| Fichier | Rôle |
|---|---|
| `config_client.lua` | réglages lus par le client (nom d'un chef-d'œuvre, geste de réparation, interaction, streaming, touche, animations) : téléchargé par chaque joueur, ouvre `VavaCrafting.config` |
| `config.lua` | tous les autres réglages, types de stations compris (1.7.0), servi au seul serveur (en tête des `server_scripts`) : complète la table |
| `shared/proximity.lua`, `shared/stationzone.lua` | purs, lus par le client et le serveur : groupes du streaming, carnet des stations reçues |
| `shared/quality.lua` | pur, servi au seul serveur : qualité d'une pièce, paliers |

Fichiers téléchargés par chaque joueur (1.6.0, T-132) : `shared/constants.lua`, `config_client.lua`, les deux
`shared/*.lua` lus par le client, les cinq `client/*.lua`, la page et les dessins des objets ; `config.lua` et
`shared/quality.lua` sont servis au seul serveur.

**Mise à jour vers 1.6.0 (T-132)** : la longueur d'un nom de chef-d'œuvre, la durée de la réparation, la distance
d'interaction, le streaming, la touche, les types de stations et les animations ont quitté `config.lua` pour
`config_client.lua`. Un `config.lua` modifié et gardé par l'installeur de la Chancellerie (le nouveau posé en
`config.lua.nouveau`) garde l'ancienne forme : le module démarre, mais la console le signale (« config.lua garde la
forme d'avant 1.6.0 … ») et un réglage client changé dans ce fichier reste sans effet. Reportez vos réglages dans
`config.lua` et `config_client.lua` d'après les nouveaux fichiers.

**Mise à jour vers 1.7.0 (T-144)** : `stationTypes` a quitté `config_client.lua` pour `config.lua`. Un
`config_client.lua` modifié et gardé par l'installeur garde une table `stationTypes` que plus rien ne lit : sans
effet (le serveur prend ceux de `config.lua`), à retirer ; des types changés à la main dans ce fichier sont à
reporter dans `config.lua`. Un `config.lua` d'avant 1.7.0 gardé avec le `config_client.lua` neuf n'a plus aucune table
`stationTypes` : le module est refusé (« stationTypes absent de config.lua … ») ; reprendre celle de
`config.lua.nouveau`.

## Base de données (sql/0001_crafting.sql)

`vava_crafting_stations` (combustible), `vava_crafting_log`. Le poinçon vit dans le champ de personnage
`vava_crafting:mark`. Écriture groupée toutes les 10 s et à l'arrêt.

## API

Exports : `getStation(id)`, `getStations()`, `addStation(spec)`, `setFuel(id, n)`, `registerAccess(kind, fn(ownerId,
characterId))`, `getRecipe(id)`, `recipesOf(type)`, `getSession(joueur)`, `getMark(personnage)`. `addStation` refuse
depuis 1.5.0 un identifiant de plus de 32 octets (`invalid_id`), une position non finie (`invalid_position`), un nom
qui n'est pas une chaîne de 1 à 128 octets (`invalid_label`), un modèle qui n'est pas une chaîne de 1 à 64 octets
(`invalid_prop`). Hooks : `vava_crafting:crafting`
(before, annulable : `{ source, characterId, station, recipe, item }`), `crafted` (after : `+ quantity, quality, tier,
signed, instanceId`), `repaired` (after : `{ source, characterId, station, recipe, item, instanceId, maxDurability }`).
Hook écouté : `vava_inventory:metadata` (before, garde de la signature, voir plus haut). Détail : `docs/api.md`.

## Conseil (droit `metiers`)

`/artisanat stations` · `/artisanat station <id>` · `/artisanat carburant <id> <n>`.

## Tests en jeu

1. **Amorçage** : bois de pin au fourneau (alimenté en bois) → charbon ; minerai → lingots à la forge (alimentée en
   charbon, sans outil) ; lingot + pin à l'établi → marteau de forge **signé** (Grossier à bas niveau).
2. **Outil en main** : hache à la forge sans marteau → « Il vous faut un marteau de forge en main » ; marteau en main
   (emplacement Mains) → la hache se forge, signée, avec créateur et poinçon s'il est choisi.
3. **Paliers** : deux piles de minerai de paliers différents → le menu propose les deux, l'aperçu de qualité change ;
   la pile du palier choisi est consommée.
4. **Plafond** : à bas niveau, matières de palier 5 → qualité plafonnée au niveau.
5. **Poinçon** : onglet Poinçon verrouillé sous Compagnon ; dès 40, choisir un glyphe → il apparaît sur les objets
   suivants (fiche de l'inventaire).
6. **Chef-d'œuvre** : `/metiers niveau <id> alchimie 100` et herbes de palier 5 → potion palier 5, boîte de baptême,
   nom visible sur la fiche ; après 5 min, trop tard.
7. **Leçon** : un joueur qui connaît l'épée (fondateur) la forge à moins de 10 m d'un élève de forge ≥ 30 → leçon
   notifiée aux deux, visible dans le livre des compétences ; trois leçons → l'élève voit la recette au menu.
8. **Réparation** : hache brisée (métadonnées) → onglet Réparation : coût, bouton ; après le geste : 95 / 95, plus
   brisée, histoire « Réparation par … », créateur intact.
9. **Occupation** : deux joueurs sur la même station → le second lit « Quelqu'un travaille déjà ici ».
10. **Privée** : station avec `owner = { kind = 'character', id = n }` → les autres lisent « ne vous appartient pas ».
11. **À terre** (`vava_health`) : près d'une station, se faire mettre à terre → l'invite disparaît, `E` ne sert qu'à
    rendre l'âme. Tombé pendant une pièce : rien n'est consommé, la station est libérée (« Vous êtes à terre. »).
12. **Signature protégée** : avec la ressource jetable de `docs/tests/metiers.md` § 4 (tests 14 à 17), réécrire le
    créateur ou faire monter la solidité d'une hache signée → refusé (`signature_locked`, `durability_locked`), fiche
    inchangée, ligne au journal ; l'usure de la récolte, la réparation et le baptême marchent toujours.
13. **Props à distance** (1.3.2) : les stations apparaissent à 80 m et disparaissent au-delà, comme avant ; le
    composteur ajouté par l'agriculture aussi ; `resmon` loin de tout puis au bourg : `vava_crafting` plus bas loin de
    tout. Détail : `docs/tests/metiers.md` § 6.
14. **Stations par zone** (1.5.0, deux joueurs) : B loin du bourg ne reçoit rien quand A travaille à la forge
    (`/vava_reseau joueur <B>`) ; B arrive : les stations apparaissent comme avant, `/vava_reseau zones <B>` les cite ;
    A ajoute du charbon : l'invite de B (à la forge) et le menu ouvert suivent. Détail : `docs/tests/metiers.md` § 4.1.
15. **Composteur** (1.7.0, T-144) : au composteur du champ (`vava_farming`), l'invite « Composteur du champ ·
    Composteur » apparaît, sans combustible ; `E` ouvre le menu (recette du compost) ; à la forge, l'invite montre
    toujours « combustible n / 20 ». Détail : `docs/tests/metiers.md` 5-7.
16. **Recette inconnue des compétences** (1.8.0, T-147) : avec la ressource jetable de `docs/tests/metiers.md` § 4.2,
    une recette déclarée à l'artisanat seul → une ligne `WARN` en console (nom, module), « Indisponible » et bouton
    grisé à l'établi ; déclarée ensuite aux compétences → déverrouillée, elle se façonne.

## À vérifier en jeu (1.8.0)

- Démarrage : aucune ligne « … absente de vava_skills:recipes » avec les modules livrés (artisanat, agriculture,
  provisions, combat) ; la ressource jetable du § 4.2 de `docs/tests/metiers.md` en fait apparaître une, une seule.
- Menu : la recette verrouillée se lit (« Indisponible », raison sous le bouton) ; les autres recettes inchangées.

## À vérifier en jeu (1.7.0)

- Invite et menu du composteur du champ (type déclaré par `vava_farming`, inconnu du client) ; invite des stations du
  bourg inchangée (nom du type, combustible de la forge et du fourneau) ; geste joué avec l'animation du type.
- Démarrage : aucune ligne « animation … inconnue » en console ; le composteur est bien déclaré par l'agriculture.

## À vérifier en jeu (1.5.0)

- Cavalier au galop qui arrive au bourg : les props apparaissent à 80 m comme avant (zone reçue à 100 m, passage du
  core d'une seconde), y compris pour la deuxième station d'un trajet (boucle déjà lancée par la première).
- Aucun « instantané redemandé » en `F8` pendant un usage normal (état d'une station puis différences dans l'ordre).
- Coût du passage du core avec les stations (`profiler record`, `docs/tests/metiers.md` 4.1-16).
- Serveur gardé en marche pendant la mise à jour depuis 1.4.0 (`restart vava_crafting`) : les anciennes clés
  GlobalState disparaissent (un nouveau joueur ne les reçoit plus).
