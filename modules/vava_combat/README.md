# vava_combat — les armes et les techniques du royaume

On ne se bat qu'avec ce que le royaume a façonné. Une **épée**, une **hache**, une **masse**, une **dague**, un **bâton
ferré** ou un **bouclier** se forgent ou se façonnent chez un artisan, se tiennent en main (le bouclier s'accroche), s'usent
à chaque coup qui porte et retournent chez l'artisan pour être remis en état (le forgeron pour le fer, le menuisier pour
le bâton et le bouclier). Une pièce de maître frappe un peu plus fort et
dure un peu plus longtemps qu'une pièce grossière, sans rendre son porteur invincible. Les coups de poing et les armes de
GTA disparaissent. L'arme signée garde son forgeron, son poinçon et ses réparations : elle se troque, elle ne s'achète pas.

Version 1.2.0 (T-112) : les **techniques**. Une épée à la main, on frappe à la souris : taille, estoc, revers
s'enchaînent, le fendant fait chanceler. Le coup se voit partir aussitôt, mais il ne porte que si l'adversaire est
vraiment à portée et en face au moment où la lame passe, ce que le **serveur** juge seul. Dégainer et rengainer prennent un
vrai temps : un mage ne passe pas de l'épée au sort d'un claquement de doigts (le mage a besoin d'un garde, le guerrier
d'un mage). Spécifications : `docs/plan/specs/T-111.md` (armes, 1.0.0) et `docs/plan/specs/T-112.md` (techniques) ;
référence : `docs/plan/COMBAT_V1.md`. Les armes, les objets, les recettes, l'usure, le bouclier accroché et la brique
serveur `strike` sont ceux de 1.0.0 (T-111) ; `/frapper_arme` de `examples/vava_example_combat` (développement) essaie
toujours un coup sans technique.

Ordre de démarrage : après `vAvA_core` (≥ 0.10.0 : `core.net`, registre `core:commands`), `vava_inventory`
(≥ 1.7.0 : objet tenu et statebag de la main), `vava_health` (≥ 1.3.0 : chaîne de dégâts), et après `vava_crafting` et
`vava_skills` (recettes ; ils peuvent aussi démarrer après : les recettes sont déclarées à leur annonce). Facultatifs,
isolés dans le bridge : `vava_crafting` ≥ 1.5.0 et `vava_skills` ≥ 1.0.0 (sans eux, ou plus anciens : armes sans recette,
une ligne de console), `vava_hud` (notifications ; sans lui, celles du jeu), `vava_admin` (droit `metiers`, journal du
Registre ; sans lui, ACE `combat.admin`), `vava_chat` (réponses de `/armes` ; sans lui, une notification au seul membre),
`vava_magic` (export `hardControl` s'il existe : un joueur gelé ou renversé ne frappe pas ; tâche T-149).
**Un RPC (`vava_combat:use`), aucune NUI, aucune table SQL.** **À ne pas arrêter sur un serveur ouvert** : pendant
l'arrêt, les armes sont « gardées à part » par l'inventaire, les recettes quittent les stations et les gestes natifs de
GTA reviennent (sans dégâts entre joueurs : `vava_health` les annule).

## Règles (config.lua, config_client.lua)

Les réglages sont dans deux fichiers et chacun n'est écrit qu'une fois (T-132) : `config_client.lua` porte ce que lit le
client, et le serveur aussi ; `config.lua` porte tout le reste, lu par le seul serveur, et complète la table sans réécrire
une clé de `config_client.lua`. Depuis 1.2.0, la fiche d'une arme est coupée en deux : sa **classe** (`weaponClasses` :
catégorie, famille) dans `config_client.lua`, sa **fiche** (`weapons` : type, dégâts, portée, solidité, blocage, modèle
provisoire) dans `config.lua` ; le bouclier accroché garde sa part client (`shield.armWith`, cadences du client) et
`config.lua` y ajoute les délais du serveur (`shield.toggleMs`, `verifyMs`, `missesToDrop`, `pedCheckMs`, `guard*`).
`weaponClasses`, `techniques`, `styles`, `keys`, `refusals` et `effects` sont entiers côté client (lus par une clé
variable) : une technique n'a rien de secret. Les joueurs téléchargent les constantes, `config_client.lua`,
`shared/shield.lua`, `shared/geometry.lua`, `shared/techniques.lua` et les `client/*.lua` ; `config.lua`,
`shared/weapons.lua` et `shared/guard.lua` sont servis au seul serveur.

| Règle | Défaut | Clé |
|---|---|---|
| Catégories (liste fermée de `COMBAT_V1.md`) | `une_main`, `deux_mains`, `dague`, `baton`, `bouclier` ; libellés et ordre en config, les clés sont fixes (le module refuse de démarrer sinon) | `categories` |
| Familles | `epee`, `hache`, `masse`, `dague`, `baton`, `bouclier` (techniques de T-115 ; style = famille + catégorie) | `families` |
| Types de dégâts d'une arme | `tranchant`, `contondant`, `percant` (recoupés au démarrage avec `vava_health:vocabulary()`) | `kinds`, `kindLabels` |
| Classe d'une arme (client) | catégorie, famille (style, place du bouclier, `armed()`) ; mêmes objets que `weapons` (contrôlé au démarrage) | `weaponClasses` |
| Fiche d'une arme (serveur) | type, `damage` (points sur 100 d'un coup de multiplicateur 1,0, qualité 50, arme non émoussée ; 0 exclu à 100), `reachBonus` (mètres ajoutés à la portée d'une technique, −1 à 1,5, T-112), `durability` (solidité d'une pièce neuve, 1 à 10 000), `block` (part arrêtée en bloquant, 0 à 1, T-113), `provisional` (modèle provisoire) ; toute autre clé refuse le module | `weapons` |
| Objets déclarés | six objets (ci-dessous), `stack = 1`, catégorie `arme`, image `nui://vava_combat/web/items/<nom>.svg` posée par le code ; un objet déjà déclaré par une autre ressource n'est pas remplacé (avertissement) | `items` |
| Recettes | six recettes déclarées à `vava_crafting:recipes` (et à `vava_skills:recipes`), **signées**, solidité **tirée de la fiche** (ni `signed` ni `durability` en config : le module refuse sinon) ; une recette refusée est une ligne d'avertissement | `recipes` |
| Qualité → dégâts | facteur linéaire de 0,85 (qualité 0) à 1,15 (qualité 100), 1,00 à 50 ; pile sans qualité : 50 | `quality` |
| Usure | 1 point par coup **qui touche** (arrivé, même entièrement bloqué ou absorbé ; annulé à l'étape `parade`, `blocage` ou `bouclier` : l'arme a touché du fer ou du bois) ; jamais sur une esquive, une annulation (zone, trêve) ni un coup refusé (cible à terre, combats coupés). Chance de **ne pas** user = 40 % × qualité / 100 (une pièce de maître dure 1,7 fois plus longtemps) | `wear.perHit`, `wear.qualitySave`, `wear.cancelledStages` |
| Seuils prévenus au seul porteur | quand la solidité passe sous le quart de la maximale (« l'arme s'émousse »), et à 0 (« l'arme est émoussée ») | `wear.warnRatio`, `messages.worn`, `messages.dull` |
| Arme émoussée | solidité 0 (ou `broken` posé par un autre module) : coups × 0,5, toujours utilisable, jamais `broken` ; la réparation de `vava_crafting` la remet en état (maximale − 5) | `wear.dullFactor` |
| Filet de `strike` | même instance (routing bucket) et positions **lues par le serveur** à 6 m au plus (la vraie portée est jugée par la technique) ; multiplicateur de la technique 0,1 à 3 ; plancher 0,5 point ; plafond 200 ; étiquettes admises `parryable`, `unblockable`, `undodgeable` (`melee` toujours posé) ; export réservé à `vava_example_combat` | `strike` |
| Bouclier accroché (client ; délais du serveur dans `config.lua`) | au **bras** avec une arme à une main ou une dague, dans le **dos** sinon (deux mains, bâton, outil, torche, mains vides) ; 1 s entre deux gestes ; relevé de possession toutes les 5 s, décroché après deux relevés manquants ; montré aux joueurs à 120 m au plus | `shield` |
| Placement du bouclier (client) | modèle et placements au bras (os 61163, avant-bras gauche) et au dos (os 24818, haut du dos) | `shields` (-- PLACEHOLDER) |
| Combat natif coupé (client) | drapeau 122 (corps à corps désactivé), changement d'arme bloqué, armes GTA retirées ; contrôle à 1 Hz ; rendu à GTA à l'arrêt | `natives` |
| Conseil | `/armes`, droit `metiers` (sans `vava_admin` : ACE `combat.admin`), `user` jusqu'à 1 000 points | `admin`, `journal` |
| Techniques (client) | quatre techniques du style `epee_une_main` (ci-dessous), format de `COMBAT_V1.md` § 3 contrôlé au démarrage (bornes des curseurs de la maquette Combat : préparation 80 à 1 500 ms, frappe 40 à 500, récupération 0 à 2 000, 3 000 en tout ; portée 1 à 4 m ; angle 10 à 180° d'ouverture **totale** ; dégâts × 0,5 à × 2 ; endurance 0 à 40 ; chaîne de 4 techniques du même style au plus ; toute autre clé refuse le module ; une technique que rien n'atteint : avertissement) ; gestes `-- PLACEHOLDER` | `techniques` |
| Styles (client) | style = `<famille>_<catégorie>` de l'arme tenue ; technique qui ouvre chaque touche (`legere`, `lourde`) | `styles` |
| Dégainer, rengainer | aucune technique avant **0,8 s** après la prise en main ; une arme rangée laisse les mains prises **1,5 s** (`armed()` : pas de sort) ; gestes `-- PLACEHOLDER` (décision du porteur du projet) | `draw` |
| Chancellement | 0,9 s sans frapper, coup en cours coupé ; aucun autre avant 3 s | `stagger`, `timing.staggerImmunityMs` |
| Cycle d'un coup (serveur) | demande admise 60 ms avant d'être permise (gigue) ; 3 techniques enchaînées au plus après celle qui ouvre ; deux relevés pendant la frappe (ouverture, fin) | `timing` |
| Tolérances (serveur) | **+ 0,25 m** à la portée, **+ 10°** au demi-angle, + 0,4 m à la hauteur (resserrées : décision du porteur du projet ; bornées au démarrage à 1 m, 30°, 1 m) ; aucun contrôle des murs | `tolerance` |
| Géométrie (serveur) | hauteur 1,6 m (+ tolérance), contact sous 0,6 m (l'angle ne compte plus), **un** adversaire par coup, marge de recherche des proches 1 m | `geometry` |
| Bond de l'attaquant (serveur) | 8 m/s + 0,5 m entre la demande et un relevé, sinon coup annulé (console) | `lunge` |
| Réactions (serveur) | joueurs prévenus à 30 m de la cible, dans l'instance de l'attaquant ; avis d'un coup retenu au seul attaquant, un par raison et par 10 s | `reactions`, `notices`, `messages.pvpOff`, `peace`, `held` |
| Débit du RPC (serveur) | 4 d'avance, puis 3 par seconde | `rateLimits.use` |
| Mode combat (client) | endormi après 10 s sans coup ni verrou ; conditions relevées à 200 ms ; touche gardée 250 ms ; virage de 90° au plus au départ du coup ; un même refus redit au plus toutes les 3 s ; contrôles de GTA coupés à chaque image en mode actif (jamais Échap ni P) | `mode` |
| Touches (client) | clic gauche (attaque légère), clic droit (attaque lourde), clic molette (verrouiller ; maintenu : relâcher) ; réglables dans Paramètres > Raccourcis > FiveM | `keys` |
| Verrou (client) | 6 m, 30° autour du centre de l'écran, en vue ; maintenu 0,6 s : relâché ; perdu à 7 m ou hors de vue 4 relevés de suite ; virage de 540°/s vers la cible pendant la préparation et la frappe | `lock` |
| Effets (client) | tressaillement, sang, étincelles (blocage, parade), secousse de caméra, son (aucun par défaut) ; 12 effets par seconde au plus | `effects` (-- PLACEHOLDER) |
| Refus montrés (client) | texte par code du serveur, `false` : rien | `refusals` |
| Réglage en jeu (serveur) | une ligne de console par relevé (distance, angle, portée, issue) ; faux en service | `debug.logSamples` |
| Textes | notifications, réponses des commandes, coups retenus | `messages` |

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

### Les techniques (valeurs de départ, à régler à la porte T-119)

| Technique | Touche | Préparation, frappe, récupération | Portée, angle | Dégâts | Enchaîne sur | Particularité |
|---|---|---|---|---|---|---|
| Taille descendante (`taille_descendante`) | légère, ouvre | 320, 160, 420 ms | 2,2 m, 70° | × 1,0 | Estoc rapide, Fendant | parable |
| Estoc rapide (`estoc_rapide`) | légère | 220, 120, 380 ms | 2,4 m, 40° | × 0,8 | Revers, Fendant | parable |
| Revers (`revers`) | légère | 280, 160, 460 ms | 2,1 m, 90° | × 0,9 | Taille descendante, Fendant | parable |
| Fendant (`fendant`) | lourde, ouvre | 650, 200, 700 ms | 2,3 m, 60° | × 1,8 | rien | non parable, fait chanceler |

Portée réelle = portée de la technique + bonus de l'arme + 0,25 m ; demi-angle = angle / 2 + 10°. Épée courte et Taille
descendante : 2,45 m, 45° de chaque côté, 2,0 m de hauteur. Seule l'**épée à une main** a des techniques en 1.2.0 (les
autres styles viendront avec T-115) : une autre arme en main, le joueur lit « Vous ne connaissez aucune technique pour
cette arme. » et rien ne s'éveille. `learn` (compétence, niveau) est lu par T-115, jamais appliqué ici ; `stamina` par
T-114.

### Un coup de technique

1. Le joueur appuie (mode combat éveillé et actif) : le client choisit la technique (celle qui ouvre la touche, ou la
   suite de la chaîne pendant la récupération), se tourne vers la cible verrouillée ou la caméra (90° au plus), **joue le
   geste aussitôt** et demande `vava_combat:use(technique, cible)`. Une touche pressée un peu tôt (250 ms) est gardée.
2. Le serveur refuse d'abord ce qu'il tient en mémoire (technique inconnue, type de défense, chancellement, arme encore
   dégainée, coup en cours, enchaînement), puis vérifie personnage, arme **réellement tenue**, style de l'arme, à terre,
   véhicule, contrôle de la magie, crochet `vava_combat:using`. Refus : le client coupe le geste (et montre le texte du
   refus, sauf pour un coup trop tôt).
3. Le serveur programme la **fenêtre de frappe** : un relevé à la fin de la préparation, un à la fin de la frappe. À chaque
   relevé, il relit l'attaquant (même personnage, debout, à pied, même arme, bond plausible) et juge les joueurs proches
   de son instance sur les positions et le cap **qu'il lit lui-même** : portée, demi-angle, hauteur ; un adversaire par
   coup (le verrouillé d'abord, puis le plus en face, le plus proche), touché une fois.
4. Le coup passe par `strike` et la chaîne de dégâts (`vava_health:hit`) ; l'arme s'use. L'issue part aux seuls joueurs
   à 30 m de la cible (`vava_combat:hit`) : la cible tressaille ou chancelle, chacun voit l'impact. Un coup retenu
   (combats coupés, lieu de paix, crochet) : un avis à l'attaquant seul.

**Enchaînement** : une technique de la chaîne part pendant la récupération de la précédente (qui est coupée) ; quatre
coups de suite au plus, puis la récupération entière. **Chancellement** : un Fendant qui porte fait chanceler la cible
0,9 s (elle ne frappe plus, son coup en cours est coupé), puis aucun autre chancellement avant 3 s.

### Le mode combat

Arme du royaume en main, **rien ne tourne** tant qu'on ne presse pas une touche du combat. Une touche l'éveille ; il
s'endort après 10 s sans coup ni appui sur le verrou, aussitôt quand la main change ou que le personnage est déchargé.
Éveillé et actif (à pied, debout, pas à terre, pas ligoté, aucune interface ouverte, pas de menu), une seule boucle par
image coupe l'attaque, la visée, le corps à corps et la roue des armes de GTA (jamais Échap ni P, lus par `vava_pause`),
dessine l'anneau sous la cible verrouillée et tourne le personnage vers elle pendant la préparation et la frappe. Mêmes
boutons que la magie : le mode magie dort arme en main, le mode combat ne s'éveille qu'arme en main.

### Dégainer et rengainer

Prendre une arme en main joue le geste de dégainer : aucune technique ne part avant **0,8 s**. La ranger joue le geste
de rengainer : pendant **1,5 s**, `armed()` (serveur et client) dit encore « mains prises », si bien que la magie refuse
d'incanter (« rangez votre arme ») sans que `vava_magic` change. Une arme déjà en main au chargement du personnage est en
garde d'emblée. Le serveur tient ces durées (hook `vava_inventory:hold`) ; le client ne fait que les montrer.

## Données

- **Fiche** (config) : ce qui est commun à toutes les pièces d'un objet.
- **Pile** (métadonnées standard de l'inventaire, écrites par `vava_crafting`) : `quality`, `tier`, `durability`,
  `max_durability`, `crafter_*`, `mark`, `history`, `name`. `vava_combat` n'écrit **que** `durability` (toujours à la
  baisse) et, pour une pile qui n'en porte pas (catalogue, don du Conseil), `max_durability` (= fiche). Jamais `broken`,
  jamais `history`.
- **Champ de personnage** `vava_combat:hungShield` (entier, **privé** : rien n'est envoyé) : numéro de la pile du
  bouclier accroché.
- **Mémoire du serveur** (1.2.0) : dernier coup de chaque joueur (technique, cycle, origine, cibles touchées), instant
  de la prise en main, rengainement en cours, dernière arme vue en main, chancellement et immunité, derniers avis ;
  bornée par le nombre de joueurs, oubliée au déchargement, au départ et à l'arrêt ; au plus deux minuteries par coup.
- Aucune table SQL, aucune migration, aucun champ ni métadonnée nouveaux.

## Réseau

| Quoi | Cible | Taille | Fréquence |
|---|---|---|---|
| RPC `vava_combat:use(technique, cible)` (`core.rpc`, schéma borné : chaîne de 1 à 32 octets `^[a-z0-9_]+$`, entier 0 à 65535) | le serveur ; réponse au seul appelant (`true`, `false, code[, attente]`) | ≈ 40 o + ≈ 15 o | un par coup ; 4 d'avance puis 3 / s |
| `vava_combat:hit` (`core.net.sendNearWith`, instance de l'attaquant) : attaquant, cible, issue | les joueurs apparus à 30 m de la **cible**, dans l'instance de l'attaquant (cible, attaquant, témoins) | ≈ 30 à 40 o | **un** par cible touchée et par coup (un adversaire par coup) ; jamais pour un coup manqué, refusé ou annulé |
| `vava_combat:notify` (`core.net.send`, compté) | le **seul** porteur dont l'arme passe un seuil ; le seul attaquant dont le coup est retenu (combats coupés, lieu de paix, crochet) ; le seul membre du Conseil qui tape `/armes` sans `vava_chat` | ≈ 70 à 160 o | 2 par arme et par cycle d'usure ; un avis par raison et par 10 s ; réponses de commande |
| Statebag de ped `vava_combat:shield` (`{ id, item }`) | OneSync : les joueurs qui ont ce ped à portée | ≈ 30 o | à l'accroche, au décrochage, à un nouveau ped du porteur ; jamais périodique |
| `GlobalState['vava_inventory:heldModels']` (mécanisme de l'inventaire) | tous | + ≈ 450 o | une fois, à la déclaration des objets |
| `vava_health:set` (existant) | la seule cible d'un coup | ≈ 26 o | un par coup appliqué |

Aucun envoi à tous, aucune clé GlobalState propre, aucun state bag nouveau, aucun envoi latent. Les gestes (coup,
réaction, dégainer, rengainer, chancellement) sont joués par chaque client sur son propre ped : OneSync les montre, rien
d'autre à envoyer. Combattant armé au repos, bouclier accroché compris : **0 octet**. Un coup manqué : la requête et sa
réponse, à l'attaquant seul. Mêlée à six vue d'un témoin : ≤ 12 `vava_combat:hit` par seconde (≈ 0,4 Ko/s), 12 effets
par seconde au plus.

Côté client : un contrôle à 1 Hz (trois natives au repos) ; seulement tant qu'un bouclier est en vue, une boucle lente
(1 s) qui ne montre un bouclier qu'à 120 m au plus ; et **une seule boucle par image**, celle du mode combat, qui ne
tourne qu'éveillé (par une touche du combat, l'arme en main) **et** actif, et s'endort après 10 s sans coup. Arme en main
sans rien presser : rien ne tourne. Le verrou n'a pas de boucle propre ; la main est gardée dans un cache local (aucune
lecture du personnage) ; les dictionnaires des gestes du style de l'arme sont chargés à la prise en main.

## Sécurité

- **Le serveur décide de chaque coup** : aucun RPC ne porte un résultat ; la frappe est jugée au relevé du serveur, sur
  les positions et le **cap qu'il lit** (`GetEntityCoords`, `GetEntityHeading` du ped), dans l'instance de l'attaquant
  (`core.net.playersNear`), avec des tolérances bornées au démarrage (≤ + 1 m, ≤ + 30°, ≤ + 1 m). `strike` revérifie la
  distance (6 m) et l'instance. La cible annoncée par le client ne sert qu'à l'ordre des candidats : elle n'allonge ni la
  portée ni l'angle.
- **Délai** : aucun coup ne porte hors de la frappe (deux minuteries du serveur par coup, rien d'autre ne frappe) ; une
  demande pendant un coup est refusée sauf enchaînement admis après la frappe ; quatre coups enchaînés au plus ; une cible
  touchée une fois par coup ; débit du RPC 3 / s ; dégainer (0,8 s) et chancellement (0,9 s) tenus en mémoire du
  serveur ; `vava_health` limite encore à 20 coups par seconde par paire.
- **Technique choisie** : contrôlée contre le style de l'arme **tenue** (lue par le serveur), technique qui ouvre
  obligatoire hors enchaînement, chaîne déclarée en données. Arme échangée ou rangée pendant le coup : hook `hold`, pile
  relue au relevé, puis par `strike`.
- **Bond** : déplacement de l'attaquant borné entre la demande et chaque relevé (8 m/s + 0,5 m), console une fois par
  minute et par joueur. Non fermé : une position mensongère **avant** la demande (OneSync : position déclarée par le
  client, limite connue de `SECURITE_RESEAU.md` § 3 ; portée courte, journal `vava_health_hits` pour le Conseil) ; un coup
  à travers une cloison mince (aucun contrôle des murs : décision du porteur du projet).
- Le serveur lit l'objet **tenu** (`vava_inventory:held`), jamais une donnée du client.
- `strike` : même instance que la cible (`GetPlayerRoutingBucket`), positions lues par le serveur (6 m), options fermées
  et bornées (`weapons.options`, testé), paquet revalidé par `vava_health` ; export réservé à `strike.callers`
  (`GetInvokingResource`, refus `not_allowed`, une ligne de console par minute et par ressource) ; il ne transmet jamais
  la pile lue par une technique (paramètre interne).
- Usure décidée et écrite par le serveur ; la garde de l'artisanat refuse toute remontée hors réparation ; `/armes user`
  ne fait que baisser, journalisé.
- Statebag du bouclier écrit **et gardé** par le serveur (valeur réécrite par un client remise après 250 ms, puis
  espacée jusqu'à 1 s ; valeur sur une entité non suivie effacée ; une ligne de console par joueur et par 10 s). Le
  placement est lu dans la config de chaque client, jamais dans la valeur ; rien n'est décidé d'après elle (T-113 lira
  `shield(src)` côté serveur).
- Aucun objet ne bouge pour accrocher un bouclier : aucune duplication possible.
- Armes et coups natifs de GTA : retirés à 1 Hz côté client, drapeau du corps à corps, touches coupées en mode combat ;
  **dégâts annulés côté serveur** quoi que fasse le client (`vava_health` 1.3.0).

## Conseil (droit `metiers`)

| Commande | Effet |
|---|---|
| `/armes liste` | une ligne par arme (libellé, catégorie, type, coup, solidité, « modèle provisoire »), regroupées en deux messages de chat (sans `vava_chat` : notifications de 200 signes) |
| `/armes voir <n°>` | arme en main (qualité, palier, solidité, coup de base → coup effectif à × 1,0, émoussée) et bouclier accroché (position, solidité) ; **journal** « Combat : armes consultées » |
| `/armes user <n°> <points>` | baisse la solidité de l'arme en main (1 à 1 000 points ; jamais au-dessus), seuils prévenus comme une usure ; écriture refusée (arme partie, garde de l'artisanat) : message à part (`adminFailed`), rien au journal ; sinon **journal** « Combat : arme usée » (avant, après) — essais d'émoussage et de réparation |

Console admise (`armes …`). Déclarée au registre `core:commands` (chapitre « Combat »), avec les trois touches du combat.

## API

**RPC** `vava_combat:use(technique, cible)` → `true` (coup accepté, fenêtre programmée ; aucun résultat : il arrive par
`vava_combat:hit`, ou jamais), `false, code`, `false, code, attente` (ms : `busy`, `chain_limit`, `drawing`, `staggered`)
ou `false, 'refused', raison` (crochet). Codes : `not_ready`, `unknown_technique`, `not_attack`, `not_opener`, `busy`,
`chain_limit`, `staggered`, `drawing`, `no_character`, `no_weapon`, `no_style`, `not_in_style`, `downed`, `vehicle`,
`controlled`, `refused` ; au-delà du débit, `rate_limited` du core.

| Export serveur | Retour |
|---|---|
| `weapon(item)` | copie de la fiche `{ item, label, category, family, kind, damage, reachBonus, durability, block, provisional }` (classe et fiche fusionnées), ou `nil` |
| `weapons()` | liste ordonnée (catégorie, puis libellé) des fiches |
| `armed(src)` | arme en main : `{ instanceId, item, category, family, kind, damage, factor, amount, reachBonus, quality, durability, maxDurability, dull }` (`factor` : qualité × usure ; `amount` : coup à × 1,0) ; pendant le rengainement (1,5 s) : `{ item, category, family, sheathing = true, readyInMs }` ; sinon `nil, code` (`not_ready`, `no_character`, `no_weapon`) |
| `techniques()` | liste (style, puis libellé) de copies `{ id, label, style, type, gesture, phases, hit, damage, stamina, parryable, staggers, chain, learn? }` |
| `technique(id)` | copie d'une technique, ou `nil` |
| `shield(src)` | `{ instanceId, item, block, durability, maxDurability, dull, position, ready }` (`ready` : au bras), ou `nil` : rien d'accroché, inventaire muet (rien n'est affirmé sans la pile), ou pile partie de la besace (décrochée aussitôt) |
| `strike(src, cible, opts)` | résultat de `vava_health:hit` + `weapon = { item, durability, maxDurability, worn, dull }`, ou `nil, code` — `not_allowed`, `not_ready`, `invalid_target`, `no_character`, `downed`, `invalid_options`, `no_weapon`, `too_far`, `health_unavailable`, plus les codes de `hit` ; réservé à `strike.callers` |

| Export client | Retour |
|---|---|
| `armed()` | `{ item, category, family }` de l'arme du personnage local ; pendant le rengainement, `+ sheathing = true` ; sinon `nil` (cache local de la main : affichage et demandes, jamais une décision) |
| `inCombatMode()` | vrai si le mode combat est éveillé et actif |
| `shieldHung()` | objet du bouclier accroché sur son propre ped, ou `nil` |

**Hooks émis** : `vava_combat:using` `before` (annulable, ne cède jamais la main : `{ source, characterId, technique, item,
target? }` — prison, ligotage, trêve ; la raison, 120 octets, est montrée au joueur) ; `vava_combat:shieldHang` `before`
(accroche seule, annulable : `{ source, characterId, instanceId, item }` — prison, interdiction du Conseil ; la raison est
montrée au joueur) et `after` (`+ hang, reason` = `use`, `gone`, `restored`) ; `vava_combat:dulled` `after`
(`{ source, characterId, instanceId, item }`). **Écoutés** : `core:module:ready` (`vava_inventory`, `vava_crafting`,
`vava_skills`), `core:character:spawned`, `core:character:unloading`, `core:player:dropped`, `vava_inventory:move`,
`drop`, `remove`, `hold` (`after` : dégainer, rengainer, coup annulé), `vava_health:downed` (`after` : coup annulé,
chancellement oublié) ; client : `core:character:loaded`, `fieldChanged`, `unloaded` (cache de la main).

### Pour les tâches suivantes

- **T-113** (blocage, parade, esquive) : types `blocage`, `parade`, `esquive`, `garde` déjà admis par le format (refusés
  à l'usage, `not_attack`) ; modificateur de blocage qui lit `block` de l'arme tenue ou, si `shield(src).ready`, du
  bouclier ; use le bouclier par `VavaCombat.wear.apply` (qui relit la pile avant d'écrire) ; à chaque blocage, lire
  `VavaCombat.shields` en interne plutôt que l'export `shield(src)` (relecture réseau R-6 de T-111). Interfaces internes
  prêtes : `VavaCombat.reactions.stagger(src, ms, now)` (l'attaquant paré chancelle), `VavaCombat.swings.cancel(src,
  raison)` et `swings.of(src)`.
- **T-114** (endurance) : `stamina` de chaque technique, lu et contrôlé (0 à 40), jamais dépensé ; jauge et indication de
  la technique au HUD (`inCombatMode()` côté client).
- **T-115** (styles et progression) : `learn` (compétence, niveau) lu et contrôlé, jamais appliqué ; autres styles
  (`hache_une_main`, `masse_une_main`, `dague_dague`, `baton_baton`, et `epee_deux_mains` à décider) ; `techniques()`.
- **T-121** (éditeur des techniques) : `techniques()`, `weapons()`, `provisional` ; le format et ses bornes sont ceux
  de `weapons.checkTechniques`. Fait par T-112 : fiches d'armes coupées en deux (classe client, fiche serveur), délais du
  serveur du bouclier et `guard.delay` sortis de ce que télécharge le joueur (relectures R-2, R-3 et S-2 de T-142).
- **T-149** (la magie et le mode combat) : ni rappel « rangez votre arme » ni anneau de la magie quand
  `exports.vava_combat:inCombatMode()` ou `armed()` ; texte propre pendant le rengainement ; export serveur
  `hardControl(src)` (gelé, renversé, chancelant), que `vava_combat` lit déjà s'il existe (refus `controlled`).
- **T-140** (fait, `vava_magic` 2.10.0) : règle « mains vides » de la magie par `exports.vava_combat:armed()` (client) et
  `armed(src)` (serveur) ; le rengainement de 1.2.0 s'y ajoute sans changement de la magie.

## Assets à brancher

Tous les modèles, gestes et effets sont des remplaçants vanilla (`-- PLACEHOLDER`, `docs/plan/ASSETS_PLACEHOLDERS.md`) :
épée longue → machette, hache d'armes → hachette, masse → batte, dague → dague de GTA, bâton ferré → queue de billard ;
l'Épée courte garde la machette de `vava_crafting`. **Le bouclier rond est le bouclier balistique de GTA, anachronique :
à remplacer en priorité.** Gestes des techniques, de dégainer, de rengainer, de chancellement et de tressaillement :
animations de corps à corps de GTA (`melee@large_wpn@streamed_core`, `melee@knife@streamed_core`,
`reaction@intimidation@1h`, `reaction@shove`, `melee@unarmed@streamed_variations`), à remplacer par les animations
médiévales (`gesture` de chaque technique, `draw`, `stagger`, `effects.flinch`). Le jour où un modèle arrive : changer
`items[…].held.model` de `config.lua` (ou `shields[…]` de `config_client.lua`) et ses placements, puis
`provisional = false` (fiche de l'arme, `config.lua`). Un modèle, un geste ou un effet absent ne fait jamais planter :
une ligne de console, rien d'affiché, le coup est jugé quand même.

Icônes : `web/items/*.svg` (une par objet nouveau, au format de l'objet, fond transparent, ombre comprise).

## Installation

`ensure vava_combat` après `vava_health` et `vava_crafting` (voir l'ordre du `README.md` à la racine). Pour essayer un
coup sans technique en développement : `set vava_env dev` et `ensure vava_example_combat` (1.1.0), puis
`/frapper_arme <n°>`.

**Mise à jour vers 1.2.0 (T-112)** : les fiches des armes sont coupées en deux (classe dans `config_client.lua` →
`weaponClasses`, fiche dans `config.lua` → `weapons`) et les délais du serveur du bouclier passent dans `config.lua`. Un
fichier modifié et gardé par l'installeur de la Chancellerie (le nouveau posé en `.nouveau`) garde l'ancienne forme : le
module **refuse de démarrer** avec un message clair (« config_client.lua d'avant 1.2.0 … » ou « config.lua d'avant
1.2.0 … ») ; reportez vos réglages d'après les nouveaux fichiers.

**Mise à jour vers 1.1.0 (T-132)** : les fiches des armes, le bouclier accroché, le placement des boucliers et les
contrôles natifs ont quitté `config.lua` pour `config_client.lua`.

## Tests

- Hors jeu : `tests/spec/combat_weapons_spec.lua` (catalogue en deux parts, qualité, solidité, montant, usure, options,
  paquet), `combat_shield_spec.lua` (position, placement, valeur du statebag, garde ; position et placement aussi sur la
  seule vue client), `combat_strike_spec.lua` (serveur avec doublures : catalogue, strike et son contexte interne, usure,
  bouclier, garde, `/armes`), `combat_geometry_spec.lua` (avant, cap, angle, arc, tolérances, ordre, bond),
  `combat_techniques_spec.lua` (contrôle du format, cycle, admission, enchaînement, choix d'une technique, style, issue),
  `combat_use_spec.lua` (cycle serveur réel avec doublures : coup qui porte, hors de portée, hors de l'arc, autre
  instance, refus dans l'ordre, annulations, bond, enchaînement, martèlement, issues, chancellement, dégainer et
  rengainer, exports), `combat_hands_client_spec.lua` (cache de la main, rengainement, mode combat, coup prédit puis
  coupé).
- En jeu : [docs/tests/combat.md](../../docs/tests/combat.md) § 2 (armes) et § 3 (techniques).

## À vérifier en jeu

- Drapeau 122 (`DisableMelee`) et touches coupées en mode combat : aucun coup de poing, aucune attaque au couteau
  native, aucune exécution furtive.
- La roue des armes de GTA (`Tab`) avec le HUD natif retiré par `vava_hud` et sans arme : invisible, ou vide et sans
  effet.
- Modèles provisoires présents dans le jeu (`w_me_dagger`, `w_me_hatchet`, `w_me_poolcue`, `w_me_bat`,
  `prop_ballistic_shield`) ; placements à régler (`offset`, `rotation`) : en main, et bouclier au bras et au dos.
- Le bouclier change de place en moins d'une seconde quand la main change, chez le porteur et chez un voisin.
- Gestes et effets provisoires présents (`/anim <dict> <clip>` de `examples/vava_anim_test`), vus des autres joueurs ;
  effet d'impact sur l'os 24818 au bon endroit ; secousse de caméra mesurée.
- Sensations à 30, 80 et 150 ms de ping (portée et angle avec les tolérances resserrées) ; coups à travers un mur fin
  (aucun contrôle) ; cap lu par le serveur pendant un virage rapide ; boutons de la souris partagés avec la magie
  (T-149). Procédure : [docs/tests/combat.md](../../docs/tests/combat.md) § 3 et § 4.
