# vava_combat — les armes du royaume

On ne se bat qu'avec ce que le royaume a façonné. Une **épée**, une **hache**, une **masse**, une **dague**, un **bâton
ferré** ou un **bouclier** se forgent ou se façonnent chez un artisan, se tiennent en main (le bouclier s'accroche), s'usent
à chaque coup qui porte et retournent chez l'artisan pour être remis en état (le forgeron pour le fer, le menuisier pour
le bâton et le bouclier). Une pièce de maître frappe un peu plus fort et
dure un peu plus longtemps qu'une pièce grossière, sans rendre son porteur invincible. Les coups de poing et les armes de
GTA disparaissent. L'arme signée garde son forgeron, son poinçon et ses réparations : elle se troque, elle ne s'achète pas.

Version 1.0.0 (T-111) : le **squelette** que T-112 complétera. Catalogue des armes, objets et recettes, dégâts selon la
qualité et l'usure, usure, bouclier accroché, combat natif coupé, commandes du Conseil, et la **brique serveur
`strike`** (paquet, chaîne de dégâts, usure). **Aucun coup donné par un joueur** dans cette version : les techniques, la
fenêtre de frappe et le mode combat arrivent avec T-112 ; en attendant, `/frapper_arme` de
`examples/vava_example_combat` (développement seulement) essaie un coup. Spécification : `docs/plan/specs/T-111.md`.

Ordre de démarrage : après `vAvA_core` (≥ 0.10.0 : `core.net.send`, registre `core:commands`), `vava_inventory`
(≥ 1.7.0 : objet tenu et statebag de la main), `vava_health` (≥ 1.3.0 : chaîne de dégâts), et après `vava_crafting` et
`vava_skills` (recettes ; ils peuvent aussi démarrer après : les recettes sont déclarées à leur annonce). Facultatifs,
isolés dans le bridge : `vava_crafting` ≥ 1.5.0 et `vava_skills` ≥ 1.0.0 (sans eux, ou plus anciens : armes sans recette,
une ligne de console), `vava_hud` (notifications ; sans lui, celles du jeu), `vava_admin` (droit `metiers`, journal du
Registre ; sans lui, ACE `combat.admin`), `vava_chat` (réponses de `/armes` ; sans lui, une notification au seul membre).
**Aucun RPC, aucune NUI, aucune table SQL.** **À ne pas arrêter sur un serveur ouvert** : pendant l'arrêt, les armes sont
« gardées à part » par l'inventaire, les recettes quittent les stations et les gestes natifs de GTA reviennent (sans
dégâts entre joueurs : `vava_health` les annule).

## Règles (config.lua)

| Règle | Défaut | Clé |
|---|---|---|
| Catégories (liste fermée de `COMBAT_V1.md`) | `une_main`, `deux_mains`, `dague`, `baton`, `bouclier` ; libellés et ordre en config, les clés sont fixes (le module refuse de démarrer sinon) | `categories` |
| Familles | `epee`, `hache`, `masse`, `dague`, `baton`, `bouclier` (techniques de T-115 ; style = famille + catégorie) | `families` |
| Types de dégâts d'une arme | `tranchant`, `contondant`, `percant` (recoupés au démarrage avec `vava_health:vocabulary()`) | `kinds`, `kindLabels` |
| Fiche d'une arme | catégorie, famille, type, `damage` (points sur 100 d'un coup de multiplicateur 1,0, qualité 50, arme non émoussée ; 0 exclu à 100), `reachBonus` (mètres ajoutés à la portée d'une technique, −1 à 1,5, T-112), `durability` (solidité d'une pièce neuve, 1 à 10 000), `block` (part arrêtée en bloquant, 0 à 1, T-113), `provisional` (modèle provisoire) ; toute autre clé refuse le module | `weapons` |
| Objets déclarés | six objets (ci-dessous), `stack = 1`, catégorie `arme`, image `nui://vava_combat/web/items/<nom>.svg` posée par le code ; un objet déjà déclaré par une autre ressource n'est pas remplacé (avertissement) | `items` |
| Recettes | six recettes déclarées à `vava_crafting:recipes` (et à `vava_skills:recipes`), **signées**, solidité **tirée de la fiche** (ni `signed` ni `durability` en config : le module refuse sinon) ; une recette refusée est une ligne d'avertissement | `recipes` |
| Qualité → dégâts | facteur linéaire de 0,85 (qualité 0) à 1,15 (qualité 100), 1,00 à 50 ; pile sans qualité : 50 | `quality` |
| Usure | 1 point par coup **qui touche** (arrivé, même entièrement bloqué ou absorbé ; annulé à l'étape `parade`, `blocage` ou `bouclier` : l'arme a touché du fer ou du bois) ; jamais sur une esquive, une annulation (zone, trêve) ni un coup refusé (cible à terre, combats coupés). Chance de **ne pas** user = 40 % × qualité / 100 (une pièce de maître dure 1,7 fois plus longtemps) | `wear.perHit`, `wear.qualitySave`, `wear.cancelledStages` |
| Seuils prévenus au seul porteur | quand la solidité passe sous le quart de la maximale (« l'arme s'émousse »), et à 0 (« l'arme est émoussée ») | `wear.warnRatio`, `messages.worn`, `messages.dull` |
| Arme émoussée | solidité 0 (ou `broken` posé par un autre module) : coups × 0,5, toujours utilisable, jamais `broken` ; la réparation de `vava_crafting` la remet en état (maximale − 5) | `wear.dullFactor` |
| Filet de `strike` | positions **lues par le serveur** à 6 m au plus (la vraie portée est jugée par T-112) ; multiplicateur de la technique 0,1 à 3 ; plancher 0,5 point ; plafond 200 ; étiquettes admises `parryable`, `unblockable`, `undodgeable` (`melee` toujours posé) ; export réservé à `vava_example_combat` | `strike` |
| Bouclier accroché | au **bras** avec une arme à une main ou une dague, dans le **dos** sinon (deux mains, bâton, outil, torche, mains vides) ; 1 s entre deux gestes ; relevé de possession toutes les 5 s, décroché après deux relevés manquants | `shield` |
| Placement du bouclier | modèle et placements au bras (os 61163, avant-bras gauche) et au dos (os 24818, haut du dos) | `shields` (-- PLACEHOLDER) |
| Combat natif coupé | drapeau 122 (corps à corps désactivé), changement d'arme bloqué, armes GTA retirées ; contrôle à 1 Hz ; rendu à GTA à l'arrêt | `natives` |
| Conseil | `/armes`, droit `metiers` (sans `vava_admin` : ACE `combat.admin`), `user` jusqu'à 1 000 points | `admin`, `journal` |
| Textes | notifications, réponses des commandes | `messages` |

### Les armes (valeurs de départ, à régler à la porte T-119)

| Objet | Catégorie | Famille | Type | Dégâts | Portée | Solidité | Blocage | Recette |
|---|---|---|---|---|---|---|---|---|
| Épée courte (`epee_courte`) | une main | épée | tranchant | 12 | 0 | 150 | 0,40 | **adoptée** : objet et recette de `vava_crafting` (forge 30, transmise) |
| Épée longue (`epee_longue`) | deux mains | épée | tranchant | 17 | +0,4 | 160 | 0,50 | forge 50, marteau, transmise : 4 lingots de fer (palier 3), 1 chêne, 1 cuir |
| Hache d'armes (`hache_d_armes`) | une main | hache | tranchant | 14 | −0,1 | 140 | 0,30 | forge 25, marteau : 2 lingots de fer (palier 2), 1 chêne |
| Masse d'armes (`masse_d_armes`) | une main | masse | contondant | 13 | −0,1 | 180 | 0,30 | forge 25, marteau : 3 lingots de fer, 1 chêne |
| Dague (`dague`) | dague | dague | perçant | 8 | −0,5 | 100 | 0,15 | forge 15, marteau : 1 lingot de fer, 1 cuir |
| Bâton ferré (`baton_ferre`) | bâton | bâton | contondant | 9 | +0,6 | 120 | 0,45 | menuiserie 10, établi : 2 chênes, 1 lingot de fer |
| Bouclier rond (`bouclier_rond`) | bouclier | bouclier | contondant | 5 | −0,6 | 150 | 0,70 | menuiserie 20, établi : 3 pins, 1 lingot de fer, 1 cuir |

Une vie pleine vaut 100 : à qualité moyenne, de 6 (Épée longue) à 13 (Dague) coups francs mettent à terre selon
l'arme, 20 au bouclier. Le combattant dépend du forgeron, du
menuisier, du tanneur et du bûcheron pour s'armer et se faire réparer ; porter une arme ne demande aucune compétence (les
compétences de combat de T-115 débloqueront des techniques, pas le port). Les outils (hache de bûcheron, couteau de
chasse) **ne sont pas des armes**.

### Un coup (brique serveur `strike`)

Montant = dégâts de la fiche × facteur de qualité × (émoussée : 0,5) × multiplicateur de la technique, arrondi au dixième,
borné à [0,5 ; 200]. Exemple : Épée courte de qualité 64, × 1,0 → 12 × 1,042 = 12,5 ; la même émoussée → 6,3. Le paquet
part à `vava_health:hit` (`kind` de la fiche, `weapon` = nom de l'objet, `tags.melee`) ; débit, cible à terre, combats
coupés, hooks et modificateurs sont ceux de la chaîne. Puis, si le coup a touché, l'arme s'use (une écriture au plus par
coup, regroupée en base par l'inventaire).

### Le bouclier

« Utiliser » le Bouclier rond (double-clic, raccourci) l'accroche ou le décroche ; il reste dans la besace (place et
poids). Il est décroché dès qu'il en sort (jeté, déposé, retiré par un module, pris lors d'une fouille). À terre, on ne
peut pas l'accrocher. Il est gardé à la reconnexion et à la réapparition. Les autres joueurs le voient au bras ou dans le
dos de son porteur, à portée de vue seulement.

## Données

- **Fiche** (config) : ce qui est commun à toutes les pièces d'un objet.
- **Pile** (métadonnées standard de l'inventaire, écrites par `vava_crafting`) : `quality`, `tier`, `durability`,
  `max_durability`, `crafter_*`, `mark`, `history`, `name`. `vava_combat` n'écrit **que** `durability` (toujours à la
  baisse) et, pour une pile qui n'en porte pas (catalogue, don du Conseil), `max_durability` (= fiche). Jamais `broken`,
  jamais `history`.
- **Champ de personnage** `vava_combat:hungShield` (entier, **privé** : rien n'est envoyé) : numéro de la pile du
  bouclier accroché.
- Aucune table SQL, aucune migration.

## Réseau

| Quoi | Cible | Taille | Fréquence |
|---|---|---|---|
| `vava_combat:notify` (`core.net.send`, compté) | le **seul** porteur dont l'arme passe un seuil ; le seul membre du Conseil qui tape `/armes` sans `vava_chat` | ≈ 70 à 160 o | 2 par arme et par cycle d'usure ; réponses de commande |
| Statebag de ped `vava_combat:shield` (`{ id, item }`) | OneSync : les joueurs qui ont ce ped à portée | ≈ 30 o | à l'accroche, au décrochage, à un nouveau ped du porteur ; jamais périodique |
| `GlobalState['vava_inventory:heldModels']` (mécanisme de l'inventaire) | tous | + ≈ 450 o | une fois, à la déclaration des objets |
| `vava_health:set` (existant) | la seule cible d'un coup | ≈ 26 o | un par coup |

Aucun RPC, aucun envoi à tous, aucune clé GlobalState propre, aucun envoi latent. Combattant armé et bouclier accroché au
repos : 0 octet. Côté client : un contrôle à 1 Hz (trois natives au repos) et, seulement tant qu'un bouclier est en vue,
une boucle lente (1 s) ; **aucune boucle par image** (la coupure image par image des touches appartiendra au mode combat
de T-112).

## Sécurité

- Le serveur lit l'objet **tenu** (`vava_inventory:held`), jamais une donnée du client ; aucune entrée réseau ne peut
  demander un coup, une usure ou une accroche hors des chemins existants de l'inventaire (`hold`, `use` et leurs limites).
- `strike` : positions lues par le serveur (6 m), options fermées et bornées (`weapons.options`, testé), paquet revalidé
  par `vava_health` ; export réservé à `strike.callers` (`GetInvokingResource`, refus `not_allowed`, une ligne de console
  par minute et par ressource).
- Usure décidée et écrite par le serveur ; la garde de l'artisanat refuse toute remontée hors réparation ; `/armes user`
  ne fait que baisser, journalisé.
- Statebag du bouclier écrit **et gardé** par le serveur (valeur réécrite par un client remise après 250 ms, puis
  espacée jusqu'à 1 s ; valeur sur une entité non suivie effacée ; une ligne de console par joueur et par 10 s). Le
  placement est lu dans la config de chaque client, jamais dans la valeur ; rien n'est décidé d'après elle (T-113 lira
  `shield(src)` côté serveur).
- Aucun objet ne bouge pour accrocher un bouclier : aucune duplication possible.
- Armes et coups natifs de GTA : retirés à 1 Hz côté client, drapeau du corps à corps ; **dégâts annulés côté serveur**
  quoi que fasse le client (`vava_health` 1.3.0).

## Conseil (droit `metiers`)

| Commande | Effet |
|---|---|
| `/armes liste` | une ligne par arme (libellé, catégorie, type, coup, solidité, « modèle provisoire ») |
| `/armes voir <n°>` | arme en main (qualité, palier, solidité, coup de base → coup effectif à × 1,0, émoussée) et bouclier accroché (position, solidité) ; **journal** « Combat : armes consultées » |
| `/armes user <n°> <points>` | baisse la solidité de l'arme en main (1 à 1 000 points ; jamais au-dessus), seuils prévenus comme une usure ; **journal** « Combat : arme usée » (avant, après) — essais d'émoussage et de réparation |

Console admise (`armes …`). Déclarée au registre `core:commands` (chapitre « Combat »).

## API

| Export serveur | Retour |
|---|---|
| `weapon(item)` | copie de la fiche `{ item, label, category, family, kind, damage, reachBonus, durability, block, provisional }`, ou `nil` |
| `weapons()` | liste ordonnée (catégorie, puis libellé) des fiches |
| `armed(src)` | `{ instanceId, item, category, family, kind, damage, factor, amount, reachBonus, quality, durability, maxDurability, dull }` (`factor` : qualité × usure ; `amount` : coup à × 1,0), ou `nil, code` (`not_ready`, `no_character`, `no_weapon`) |
| `shield(src)` | `{ instanceId, item, block, durability, maxDurability, dull, position, ready }` (`ready` : au bras), ou `nil` |
| `strike(src, cible, opts)` | résultat de `vava_health:hit` + `weapon = { item, durability, maxDurability, worn, dull }`, ou `nil, code` — `not_allowed`, `not_ready`, `invalid_target`, `no_character`, `downed`, `invalid_options`, `no_weapon`, `too_far`, `health_unavailable`, plus les codes de `hit` ; réservé à `strike.callers` |

| Export client | Retour |
|---|---|
| `armed()` | `{ item, category, family }` de l'arme du personnage local, ou `nil` (lu dans le champ de l'inventaire : affichage et demandes, jamais une décision) |
| `shieldHung()` | objet du bouclier accroché sur son propre ped, ou `nil` |

**Hooks émis** : `vava_combat:shieldHang` `before` (accroche seule, annulable : `{ source, characterId, instanceId, item }`
— prison, interdiction du Conseil ; la raison est montrée au joueur) et `after` (`+ hang, reason` = `use`, `gone`,
`restored`) ; `vava_combat:dulled` `after` (`{ source, characterId, instanceId, item }`). **Écoutés** :
`core:module:ready` (`vava_inventory`, `vava_crafting`, `vava_skills`), `core:character:spawned`,
`core:character:unloading`, `core:player:dropped`, `vava_inventory:move`, `drop`, `remove` (`after`).

### Pour les tâches suivantes

- **T-112** appelle `VavaCombat.strike.run(src, cible, { technique, damage, tags, part })` après sa géométrie
  (`hit.range + weapon.reachBonus`, angle) ; lit le style par `catalog.weapon(held.item)` ; ajoute son mode combat.
- **T-113** : modificateur de blocage qui lit `block` de l'arme tenue ou, si `shield(src).ready`, du bouclier ; use le
  bouclier par `VavaCombat.wear.apply`.
- **T-116** : règle « mains vides » de la magie par `exports.vava_combat:armed()` (client) et `armed(src)` (serveur).
- **T-121** : l'éditeur des techniques lit `weapons()` et affiche `provisional`.

## Assets à brancher

Tous les modèles sont des remplaçants vanilla (`-- PLACEHOLDER`, `docs/plan/ASSETS_PLACEHOLDERS.md`) : épée longue →
machette, hache d'armes → hachette, masse → batte, dague → dague de GTA, bâton ferré → queue de billard ; l'Épée courte
garde la machette de `vava_crafting`. **Le bouclier rond est le bouclier balistique de GTA, anachronique : à remplacer
en priorité.** Le jour où un modèle arrive : changer `items[…].held.model` (ou `shields[…]`) et ses placements, puis
`provisional = false`. Un modèle absent ne fait jamais planter : une ligne de console, rien d'affiché.

Icônes : `web/items/*.svg` (une par objet nouveau, au format de l'objet, fond transparent, ombre comprise).

## Installation

`ensure vava_combat` après `vava_health` et `vava_crafting` (voir l'ordre du `README.md` à la racine). Pour essayer un
coup en développement : `set vava_env dev` et `ensure vava_example_combat` (1.1.0), puis `/frapper_arme <n°>`.

## Tests

- Hors jeu : `tests/spec/combat_weapons_spec.lua` (catalogue, qualité, solidité, montant, usure, options, paquet),
  `combat_shield_spec.lua` (position, placement, valeur du statebag, garde), `combat_strike_spec.lua` (serveur avec
  doublures : catalogue, strike, usure, bouclier, garde, `/armes`).
- En jeu : [docs/tests/combat.md](../../docs/tests/combat.md) § 2.

## À vérifier en jeu

- Drapeau 122 (`DisableMelee`) : aucun coup de poing, aucune attaque au couteau native, aucune exécution furtive ; sinon
  les gestes natifs restent visibles mais sans dégâts (filet de `vava_health`), et le mode combat de T-112 les coupera.
- La roue des armes de GTA (`Tab`) avec le HUD natif retiré par `vava_hud` et sans arme : invisible, ou vide et sans
  effet. Si elle gêne, tâche de suivi : coupure de la touche 37 pendant qu'elle est maintenue seulement.
- Modèles provisoires présents dans le jeu (`w_me_dagger`, `w_me_hatchet`, `w_me_poolcue`, `w_me_bat`,
  `prop_ballistic_shield`) ; placements à régler (`offset`, `rotation`) : en main, et bouclier au bras et au dos.
- Le bouclier change de place en moins d'une seconde quand la main change, chez le porteur et chez un voisin.
- La magie ne regarde aujourd'hui que l'arme GTA : un mage peut lancer un sort l'épée à la main (décision attendue, spec
  § 13-1).
