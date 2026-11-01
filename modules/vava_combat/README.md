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
d'un mage). Spécifications : `docs/plan/specs/T-111.md` (armes, 1.0.0), `docs/plan/specs/T-112.md` (techniques) et
`docs/plan/specs/T-113.md` (défense) ; référence : `docs/plan/COMBAT_V1.md`.

Version 1.3.0 (T-113) : la **défense**. On lève la garde en maintenant **R** : les coups de face sont amortis, bien
mieux derrière un bouclier, jusqu'à ce que la garde cède sous les coups. Un appui bref sur **R** au bon moment **pare** :
la lame adverse est détournée et l'attaquant chancelle, ouvert à la riposte. **Espace** fait un pas de côté qui laisse
passer le coup. L'arme qui pare et le bouclier qui bloque s'usent et retournent chez l'artisan ; le serveur seul tient
les fenêtres, le client ne fait que demander. Les armes, les objets, les recettes, l'usure, le bouclier accroché et la brique
serveur `strike` sont ceux de 1.0.0 (T-111) ; `/frapper_arme` de `examples/vava_example_combat` (développement) essaie
toujours un coup sans technique.

Version 1.5.0 (T-156) : les **mannequins d'entraînement**. Dans la cour d'armes, des mannequins de paille attendent sur
leur poteau : on y essaie une taille, un enchaînement, le Fendant, une Boule de feu ; le mannequin encaisse, se balance
et se redresse seul, et le chiffre de chaque coup monte au-dessus de lui (chez celui qui frappe). Personne n'est blessé ;
l'arme s'use un peu, comme à l'exercice (un coup sur quatre). On y répète seul ses gestes ; on ne progresse pas au-delà
des premiers rangs sans un partenaire ou un maître (aucune XP ici ; T-115 la plafonnera au niveau 9). Spécification :
`docs/plan/specs/T-156.md`.

Version 1.6.0 (T-114) : l'**endurance**. Chaque coup, chaque parade, chaque pas de côté coûte du souffle ; une garde qui
encaisse se vide jusqu'à céder. Un médaillon « Endurance » s'allume à côté de la santé quand on prend les armes, descend
à chaque effort et remonte seul après une seconde de répit, plus lentement le ventre vide ou la gorge sèche. À bout de
souffle, on ne frappe plus : il faut rompre, reculer, laisser un compagnon prendre le relais. La jauge est tenue par le
serveur seul ; elle remplace le compteur provisoire de garde brisée de 1.3.0 **aux mêmes seuils** (4 coups bloqués à
l'épée, 6 au bouclier). Spécification : `docs/plan/specs/T-114.md`.

Ordre de démarrage : après `vAvA_core` (≥ 0.10.0 : `core.net`, registre `core:commands`), `vava_inventory`
(≥ 1.7.0 : objet tenu et statebag de la main), `vava_health` (≥ 1.6.0 : chaîne de dégâts, coup d'essai des
mannequins), et après `vava_crafting` et
`vava_skills` (recettes ; ils peuvent aussi démarrer après : les recettes sont déclarées à leur annonce). Facultatifs,
isolés dans le bridge : `vava_crafting` ≥ 1.5.0 et `vava_skills` ≥ 1.0.0 (sans eux, ou plus anciens : armes sans recette,
une ligne de console), `vava_hud` (notifications ; sans lui, celles du jeu), `vava_admin` (droit `metiers`, journal du
Registre ; sans lui, ACE `combat.admin`), `vava_chat` (réponses de `/armes` ; sans lui, une notification au seul membre),
`vava_magic` (export `hardControl`, `vava_magic` ≥ 2.12.0, T-149 : un joueur gelé, renversé ou chancelant par un sort
ne frappe pas, refus `controlled` ; plus ancien, arrêté ou en erreur : aucun refus de ce côté), `vava_needs` (export
serveur `get`, 1.6.0 : la faim et la soif ralentissent la recharge de l'endurance ; sans lui, recharge pleine),
`vava_hud` ≥ 1.8.0 pour la jauge d'endurance animée (plus ancien : la jauge ne bouge qu'à chaque état reçu ; sans lui,
pas de jauge, le combat ne change pas).
**Deux RPC (`vava_combat:use`, `vava_combat:lower`), aucune NUI, aucune table SQL.** **À ne pas arrêter sur un serveur ouvert** : pendant
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
variable) : une technique n'a rien de secret. `dummies` (1.5.0) est coupée au second niveau : modèles, distances,
balancement, éclats et liste dans `config_client.lua`, part du serveur (usure, témoins, appelants, plafonds) ajoutée par
`config.lua`. `endurance` (1.6.0) est entière dans `config.lua` (le client n'en lit rien : pente et reprise lui
arrivent dans chaque état), `gauge` entière dans `config_client.lua` (le serveur la contrôle seulement). Les joueurs
téléchargent les constantes, `config_client.lua`, `shared/dummies.lua`, `shared/shield.lua`, `shared/heading.lua`,
`shared/techniques.lua`, `shared/endurance.lua` et les `client/*.lua` ; `config.lua`, `shared/weapons.lua`,
`shared/guard.lua`, `shared/stamina.lua` et `server/stamina.lua` sont servis au seul serveur.

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
| Techniques défensives (client) | Garde (`blocage`), Parade (`parade`), Pas de côté (`esquive`) du style `epee_une_main` (ci-dessous) ; format selon le type : préparation dès 0 ms, ni `damage`, ni `parryable`, ni `staggers`, ni `hit.range` (refusés au démarrage) ; `hit.angle` = arc protégé ; une esquive n'a pas de `hit` ; `stamina` = coût d'un coup **léger** bloqué (Garde : 25, exigé pour la lever ; un lourd × 2, au bouclier × 0,67), d'une parade (6), d'un pas (20) | `techniques` |
| Styles (client) | style = `<famille>_<catégorie>` de l'arme tenue ; technique qui ouvre chaque touche (`legere`, `lourde`, `blocage`, `parade`, `esquive`, chacune d'une technique de son type ; une touche absente ne fait rien) | `styles` |
| Défense (client) | garde brisée 1,2 s (chancellement, ni garde ni parade) et son geste ; 1,5 s entre deux pas de côté (connu du client : rien n'est demandé avant ; tenu par le serveur) ; sprint coupé garde levée (8 contrôles au plus, jamais Échap ni P) ; gestes du pas de côté selon la direction tenue (avant, gauche, droite ; sinon celui de la technique) | `defense.guardBrokenMs`, `dodgeCooldownMs`, `brokenGesture`, `guardBlocked`, `dodgeGestures` (-- PLACEHOLDER) |
| Défense (serveur) | parade ratée → aucune autre parade avant fin de fenêtre + 0,6 s ; pas de côté : évite `melee` et `ranged` (projectiles de sorts compris), jamais `undodgeable`, `area`, `overTime`, `native`, `reflected`, et n'est appelé ni pour la faim (`privation`) ni pour les pertes du monde (`kinds`) ; garde et parade : `melee` seulement ; arc protégé + 40° au bouclier ; la garde cède quand un coup bloqué coûte au moins ce qui reste d'endurance (1.6.0 ; `defense.guardBreak` de 1.3.0 retiré : présent dans un ancien `config.lua`, une ligne de console, sans effet) ; priorité des modificateurs 50 ; 64 décisions en attente au plus, oubliées après 1 s | `defense.parry`, `dodge`, `block`, `parryTags`, `modifierPriority`, `memoMax`, `memoMs` |
| Endurance (serveur, 1.6.0, T-114) | jauge de 0 à 100 par personnage en jeu, jamais sauvegardée (pleine à l'arrivée et au relevé) ; recharge **20 / s** (1 à 100) **1 s** (0 à 10 000 ms) après la dernière dépense ; coup bloqué : `stamina` de la Garde × 2 pour un coup lourd (1 à 5) × 0,67 au bouclier encore accroché (0,1 à 1) ; faim ou soif (le besoin le plus bas, `vava_needs`) à 30 ou moins : × 0,75, à 10 ou moins : × 0,5 (4 paliers au plus, `at` 0 à 100, `factor` 0,1 à 1), relues au plus une fois par 30 s (1 000 à 300 000 ms) et par combattant, à un geste. Absente (ancien `config.lua`) : le module refuse de démarrer avec la marche à suivre | `endurance.regenPerSecond`, `regenDelayMs`, `block.heavyWeight`, `block.shieldFactor`, `needs`, `needsReadMs` |
| Jauge d'endurance (client, 1.6.0) | médaillon « Endurance » de `vava_hud`, icône `web/icons/endurance.svg`, ordre 60 (dernier : n'en décale aucun), anneau ambre sous 25 % (plus de quoi lever la garde), rouge et lueur sous 10 % ; montré en mode combat éveillé, ou tant qu'il n'est pas plein, puis 3 s (0 à 30 000 ms) ; marge de prédiction 2 points (0 à 10) : une demande ne part que si la jauge vue d'ici en manque au plus autant. Contrôlé au démarrage par le serveur (bornes de `vava_hud`, icône `nui://vava_combat/…`) | `gauge` |
| Dégainer, rengainer | aucune technique avant **0,8 s** après la prise en main ; une arme rangée laisse les mains prises **1,5 s** (`armed()` : pas de sort) ; gestes `-- PLACEHOLDER` (décision du porteur du projet) | `draw` |
| Chancellement | 0,9 s sans frapper, coup en cours coupé ; aucun autre avant 3 s | `stagger`, `timing.staggerImmunityMs` |
| Cycle d'un coup (serveur) | demande admise 60 ms avant d'être permise (gigue) ; 3 techniques enchaînées au plus après celle qui ouvre ; deux relevés pendant la frappe (ouverture, fin) ; un coup **annulé** (quelle qu'en soit la cause) garde sa récupération et son compte d'enchaînement, comme s'il était allé au bout | `timing` |
| Tolérances (serveur) | **+ 0,25 m** à la portée, **+ 10°** au demi-angle, + 0,4 m à la hauteur (resserrées : décision du porteur du projet ; bornées au démarrage à 1 m, 30°, 1 m) ; aucun contrôle des murs | `tolerance` |
| Géométrie (serveur) | hauteur 1,6 m (+ tolérance), contact sous 0,6 m (l'angle ne compte plus), **un** adversaire par coup, marge de recherche des proches 1 m | `geometry` |
| Bond de l'attaquant (serveur) | 8 m/s + 0,5 m entre la demande et un relevé, sinon coup annulé (console) ; large pendant une longue préparation (5,7 m au Fendant) : à resserrer à la porte T-119 (≈ 4 à 5 m/s) | `lunge` |
| Réactions (serveur) | joueurs prévenus à 30 m de la cible, dans l'instance de l'attaquant ; issues jamais envoyées aux témoins : `dodge`, `absorb` (jamais `parry` ni `break`, refusés au démarrage) ; avis d'un coup retenu au seul attaquant, un par raison et par 10 s | `reactions`, `notices`, `messages.pvpOff`, `peace`, `held` |
| Chiffres des coups (serveur, 1.4.0, T-155) | activés ; le montant du coup (dixièmes, après modificateurs) à l'attaquant et à la cible, jamais aux témoins ; « Esquivé » et « Absorbé » chez les deux seuls participants ; `enabled = false` : comme en 1.3.0. Quatre booléens contrôlés au démarrage | `numbers` (`enabled`, `attacker`, `target`, `witnesses`) |
| Mannequins (client, 1.5.0, T-156) | trois mannequins de la cour provisoire de Paleto (identifiant, place, cap, modèle, instance, libellé facultatifs) ; modèle sac de frappe, repli botte de foin ; props **locaux** créés à 60 m, retirés au-delà de 70 m ; boucle toutes les 0,5 s à moins de 90 m d'un mannequin, 2 s sinon ; point visé 1 m au-dessus du pied, chiffre à 1,9 m ; balancement 0,9 s, 14°, deux allers-retours ; éclats ; 64 mannequins au plus. Contrôlé au démarrage par le seul serveur (`weapons.checkDummies` : refus du module avec la raison) ; le client ne fait qu'indexer la liste | `dummies` (-- PLACEHOLDER : modèles, places, éclats) |
| Mannequins (serveur, 1.5.0) | libellé par défaut « Mannequin de paille » (outils, Atelier) ; un coup sur quatre use l'arme (la paille use peu le fil) ; témoins du balancement à 15 m (0 : aucun), au plus un envoi par mannequin et par 0,8 s ; `dummyHit` réservé à `vava_magic`, lanceur à 80 m au plus ; `dummiesNear` : 8 au plus, rayon 50 m au plus ; niveau 9 : plafond d'XP lu par T-115 | `dummies.wearChance`, `witnessRadius`, `witnessMinMs`, `callers`, `spellMaxDistance`, `nearMax`, `nearMaxRadius`, `xpMaxLevel` |
| Débit des RPC (serveur) | `use` et `lower` : 4 d'avance, puis 3 par seconde chacun | `rateLimits.use`, `rateLimits.lower` |
| Mode combat (client) | endormi après 10 s sans coup ni verrou (jamais garde levée) ; conditions relevées à 200 ms ; touche gardée 250 ms ; virage de 90° au plus au départ du coup ; un même refus redit au plus toutes les 3 s ; contrôles de GTA coupés à chaque image en mode actif, saut (22) et recharger (45) compris (jamais Échap ni P : 199, 200, 322 refusés au démarrage ; 32 au plus) | `mode` |
| Touches (client) | clic gauche (attaque légère), clic droit (attaque lourde), clic molette (verrouiller ; maintenu : relâcher), **R** (appui bref : parer ; maintenu : se garder), **Espace** (pas de côté, mode combat actif seulement : le saut de GTA y est coupé) ; réglables dans Paramètres > Raccourcis > FiveM | `keys` |
| Verrou (client) | 6 m, 30° autour du centre de l'écran, en vue ; maintenu 0,6 s : relâché ; perdu à 7 m ou hors de vue 4 relevés de suite ; virage de 540°/s vers la cible pendant la préparation et la frappe | `lock` |
| Effets (client) | tressaillement, sang, étincelles (blocage, parade), secousse de caméra, son (aucun par défaut) ; 12 effets par seconde au plus | `effects` (-- PLACEHOLDER) |
| Refus montrés (client) | texte par code du serveur, `false` : rien ; 200 octets au plus (contrôlé au démarrage, 1.6.0) ; `exhausted` : « Vous êtes à bout de souffle. » | `refusals` |
| Réglage en jeu (serveur) | une ligne de console par relevé (distance, angle, portée, issue) ; faux en service | `debug.logSamples` |
| Textes | notifications, réponses des commandes, coups retenus, endurance vue par le Conseil (`inspectEndurance`, `enduranceSlowed`) | `messages` |

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
| Garde (`garde_epee`) | R maintenue | mise en garde 100, tenue minimale 200, garde abaissée 250 ms | arc 120° (160° au bouclier) | — | rien (pas de riposte directe) | 25 d'endurance par coup léger bloqué (lourd 50 ; au bouclier 16,8 et 33,5) ; 25 exigés pour la lever, rien dépensé à la levée |
| Parade (`parade_epee`) | R, appui bref | 0, **fenêtre 200**, 250 ms | arc 120° | — | Garde (R maintenue) | 6 d'endurance, réussie ou ratée |
| Pas de côté (`pas_de_cote`) | Espace | élan 50, **invulnérable 250**, 350 ms | — | — | rien | 20 d'endurance |

Endurance des attaques (1.6.0) : Taille 12, Estoc 9, Revers 11, Fendant 25, payée à l'acceptation, que le coup porte ou
non (manqué, paré, esquivé, sur un mannequin).

Format (`config_client.lua` → `techniques`, `COMBAT_V1.md` § 3, identique dans l'Atelier) : clé = identifiant
(`^[a-z0-9_]+$`, 32 octets) ; `phases` en ms ; `hit.range` en mètres (plus le bonus de l'arme) ; `hit.angle` = ouverture
**totale** de l'arc, centrée sur l'avant ; `damage` = multiplicateur des dégâts de l'arme ; `chain` = techniques du même
style qui peuvent partir pendant la récupération. Portée réelle = portée de la technique + bonus de l'arme + 0,25 m ;
demi-angle = angle / 2 + 10°. Épée courte et Taille
descendante : 2,45 m, 45° de chaque côté, 2,0 m de hauteur. Seule l'**épée à une main** a des techniques en 1.3.0 (les
autres styles viendront avec T-115) : une autre arme en main, le joueur lit « Vous ne connaissez aucune technique pour
cette arme. » et rien ne s'éveille. `learn` (compétence, niveau) est lu par T-115, jamais appliqué ici ; `stamina` est
le coût d'endurance (1.6.0).

### Un coup de technique

1. Le joueur appuie (mode combat éveillé et actif) : le client choisit la technique (celle qui ouvre la touche, ou la
   suite de la chaîne pendant la récupération), se tourne vers la cible verrouillée ou la caméra (90° au plus), **joue le
   geste aussitôt** et demande `vava_combat:use(technique, cible)`. Une touche pressée un peu tôt (250 ms) est gardée.
2. Le serveur refuse d'abord ce qu'il tient en mémoire (technique inconnue, type de défense, chancellement, arme encore
   dégainée, souffle, coup en cours, enchaînement), puis vérifie personnage, arme **réellement tenue**, style de l'arme, à terre,
   véhicule, contrôle de la magie, crochet `vava_combat:using`. Refus : le client coupe le geste (et montre le texte du
   refus, sauf pour un coup trop tôt).
3. Le serveur programme la **fenêtre de frappe** : un relevé à la fin de la préparation, un à la fin de la frappe. À chaque
   relevé, il relit l'attaquant (même personnage, debout, à pied, même arme, bond plausible) et juge les joueurs proches
   de son instance sur les positions et le cap **qu'il lit lui-même** : portée, demi-angle, hauteur ; un adversaire par
   coup (le verrouillé d'abord, puis le plus en face, le plus proche), touché une fois.
4. Le coup passe par `strike` et la chaîne de dégâts (`vava_health:hit`) ; l'arme s'use. L'issue part aux seuls joueurs
   à 30 m de la cible (`vava_combat:hit`) : la cible tressaille ou chancelle, chacun voit l'impact. L'attaquant et la
   cible voient en plus le montant du coup au-dessus de la cible (chiffres des coups, 1.4.0, par `vava_hud`) ; les
   témoins, jamais. Un coup retenu (combats coupés, lieu de paix, crochet) : un avis à l'attaquant seul.

**Enchaînement** : une technique de la chaîne part pendant la récupération de la précédente (qui est coupée) ; quatre
coups de suite au plus, puis la récupération entière. Un coup annulé (chancellement, à terre, arme changée, véhicule,
bond) compte comme allé au bout : on ne gagne rien à couper son propre coup. **Chancellement** : un Fendant qui porte fait chanceler la cible
0,9 s (elle ne frappe plus, son coup en cours est coupé), puis aucun autre chancellement avant 3 s.

### La défense

1. **Parer** (R, appui bref) : le geste part aussitôt ; le serveur ouvre la fenêtre **à l'arrivée de la demande**, sans
   préparation, pour 200 ms. Un coup `parryable` de corps à corps qui arrive de face (arc 120° + 10° de chaque côté ;
   au contact, l'angle ne compte plus) dans cette fenêtre est annulé à l'étape `parade` : l'attaquant chancelle 0,9 s
   (même s'il était encore protégé d'un chancellement : sa protection repart de zéro), son coup et sa suite déjà
   demandée sont coupés, son arme et celle du défenseur s'usent. Le **Fendant** n'est pas parable : il porte et fait
   chanceler (on le bloque ou on l'esquive). Une parade qui n'a rien paré interdit toute autre parade pendant 0,6 s
   après sa fin.
2. **Se garder** (R maintenue) : à la fin de la fenêtre de parade, la garde se lève (100 ms, puis tenue au moins
   200 ms). Un coup de corps à corps de face (arc 120°, 160° bouclier au bras) est amorti : part arrêtée de l'arme tenue
   (Épée courte 0,40) ou du **bouclier accroché au bras** (Bouclier rond 0,70) ; émoussé : moitié moins. Ce qui bloque
   s'use (le bouclier s'il sert, sinon l'arme). Un coup de dos porte entièrement. Pas d'attaque garde levée, pas de
   course ; relâcher R l'abaisse (250 ms avant de frapper). Chaque coup bloqué coûte de l'endurance (25 à l'épée, 16,8
   au bouclier, le double pour un coup lourd) ; un coup bloqué qui coûte au moins ce qui reste **brise la garde** :
   chancellement 1,2 s, ni garde ni parade pendant ce temps, « Votre garde est brisée. » (depuis une jauge pleine : au
   4e coup léger, au 6e au bouclier). La garde ne se lève qu'avec 25 d'endurance (de quoi bloquer un coup).
3. **Pas de côté** (Espace, mode combat actif seulement) : roulade selon la direction tenue ; invulnérable 250 ms
   après 50 ms d'élan, contre les coups de corps à corps et les projectiles (sorts compris), jamais contre une zone, un
   effet qui dure ni un coup `undodgeable`. 1,5 s entre deux départs. Rien ne s'use, rien n'est envoyé aux autres.

Exemples (Épée courte qualité 50, Taille 12) : garde à l'épée 4,8 arrêtés, 7,2 perdus ; au bouclier 8,4 arrêtés,
3,6 perdus ; bouclier émoussé 4,2 arrêtés. Fendant (21,6) au bouclier : 15,1 arrêtés, 6,5 perdus, sans chancellement.
Un geste défensif est un coup au sens du cycle (T-112) : annulé (main changée, à terre, chancellement), il garde sa
récupération ; une garde annulée est fermée avec sa tenue minimale. Sous un contrôle dur de la magie (gelé, renversé,
chancelant), ni parade, ni garde, ni pas de côté ne protègent.

### L'endurance (1.6.0, T-114)

- **Jauge** : 0 à 100 par personnage en jeu, tenue par le serveur en dixièmes, jamais sauvegardée (pleine à l'arrivée, au
  relevé d'une mise à terre, après un retour à la sélection). **Aucune minuterie, aucune boucle** : le niveau se calcule
  à chaque lecture (valeur à un instant, reprise de la recharge, pente), comme la mana de `vava_magic`.
- **Dépenses**, toutes à l'**acceptation** du geste (un geste refusé ne coûte rien) : attaques (12, 9, 11, 25), parade
  (6), pas de côté (20), coup bloqué (25 × poids × bouclier). Rien pour tenir la garde, courir, incanter, être frappé
  sans bloquer. Un coup qui met à terre ne coûte rien au défenseur (la mise à terre l'emporte).
- **Recharge** : 20 points par seconde, 1 s après la dernière dépense ; tenir la garde ne l'arrête pas. Faim ou soif à
  30 ou moins : 15 / s ; à 10 ou moins : 10 / s (le besoin le plus bas). De vide à plein : 6 s (7,7 s ventre creux,
  11 s affamé).
- **À bout de souffle** : un geste dont le coût dépasse ce qui reste est refusé (« Vous êtes à bout de souffle. »), avec
  l'attente avant qu'il soit payable ; le client ne demande même pas ce que sa jauge (vue de chez lui, à 2 points près)
  ne paie pas. Seuls les gestes plus chers sont retenus : à 10 points, une Taille part encore.
- **Rythme** : Tailles toutes les 0,9 s depuis une jauge pleine : huit, puis une toutes les 1,6 s environ (1 s de répit, 0,6 s de recharge) ; neuf pas de côté de
  suite ; après une garde brisée, la garde ne se relève pas avant 2,25 s. Deux Fendants **à moins d'une seconde**
  (deux attaquants) brisent la garde à l'épée ; un seul attaquant, ses Fendants espacés de 1,55 s, la brise au
  troisième (0,55 s de recharge entre deux). Alterner pas de côté et parades ratées ne protège plus ≈ 35 % du temps
  (1.3.0) mais ≈ 15 % une fois le souffle épuisé (≤ 17 % de 10 à 60 s : essai).
- **Ce que voit le joueur** : le médaillon « Endurance » de `vava_hud` (animé par la page : une mise à jour par état,
  aucune boucle), ambre sous 25 %, rouge sous 10 %. Les autres ne voient rien de sa jauge.

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

### Les mannequins d'entraînement (1.5.0, T-156)

- **Coup d'arme** : un mannequin est une cible du relevé d'une technique **après les joueurs** (un joueur dans l'arc
  est toujours frappé d'abord : un mannequin ne protège personne et ne vole aucun coup), avec les mêmes portée, angle,
  hauteur, instance et l'arme réellement tenue ; un seul par coup, aucun si un joueur a été frappé ; il ne compte pas
  dans les adversaires d'un coup : frappé au premier relevé, il n'empêche pas de frapper un joueur entré dans l'arc
  avant le second (relecture sécurité S-1). Le paquet est **le même** qu'un coup sur un joueur ; le montant vient de `vava_health:trial` (coup
  d'essai : rien d'appliqué, aucun hook, aucun journal). Jamais `strike`, jamais `hit`, jamais les réactions.
- **Issue** : le montant seul ; le **Fendant** y ajoute « Chancelle » sans rien poser (on apprend ce que fait la
  technique) ; jamais « À terre » ni « Garde brisée » ; un mannequin ne pare, ne bloque, n'esquive ni n'absorbe rien
  (aucun modificateur ne s'inscrit aux coups d'essai en 1.5.0).
- **Zones de paix, combats coupés** : le mannequin reste frappable à l'arme (personne n'est blessé : une cour d'armes
  peut être en ville). Les sorts gardent les règles de la magie.
- **Usure** : un coup qui userait l'arme ne l'use qu'**une fois sur quatre** (`wearChance`), même pile relue, mêmes avis
  au porteur ; une Épée courte de qualité 50 perd un point tous les ≈ 5 coups (≈ 750 coups pour l'émousser). Les sorts
  n'usent rien.
- **XP** : aucune. Hook `vava_combat:trained` à chaque coup qui atteint un mannequin, pour T-115 (XP plafonnée sous
  `dummies.xpMaxLevel`, 9 : la Parade, niveau 10, se gagne face à quelqu'un) et T-121 (essai d'une technique).
- **Sorts** (`vava_magic` ≥ 2.14.0) : projectiles (impact et éclats), Nova ardente, Secousse, par `dummiesNear` et
  `dummyHit` ; ni état, ni poussée, ni brûlure, ni bonus d'XP.
- **Client** : props locaux à portée (jamais réseau), balancement à chaque coup (s'écarte de l'attaquant, se redresse
  seul), éclats ; le chiffre et le son chez l'attaquant seul. Un mannequin dans une autre instance est dessiné quand
  même (le client ne connaît pas son instance de façon sûre) ; le serveur refuse les coups venus d'une autre instance
  (T-137).
- **Plus tard** : la liste devient une définition de l'Atelier (éditeur `vava_combat:cour`, « Cour d'armes », tâche
  proposée au backlog) ; même forme de données (spec § 5.2), seule la source change (`dummies.replace`).

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
  1.3.0 : geste défensif en cours (fenêtre = paire d'instants, **aucune minuterie** ; garde : part bloquée et bouclier
  lus une fois), dernière parade, dernier pas de côté, fin de garde brisée (oubliés aussi
  à la mise à terre) ; décisions des modificateurs en attente de leur suite (64 au plus, retirées dans le même tour,
  oubliées après 1 s).
  1.5.0 : mannequins chargés (64 au plus) ; par mannequin, instant du dernier balancement envoyé aux témoins ; par coup,
  mannequins déjà frappés ; oubliés à l'arrêt.
  1.6.0 : une jauge d'endurance par joueur qui a fait un geste (personnage, valeur, instant, reprise, pente, part due
  aux besoins, dernière lecture de `vava_needs`), oubliée au déchargement, au départ, à la mise à terre, à l'arrêt ;
  le compteur provisoire de 1.3.0 disparaît.
- Aucune table SQL, aucune migration, aucun champ ni métadonnée nouveaux.

## Réseau

| Quoi | Cible | Taille | Fréquence |
|---|---|---|---|
| RPC `vava_combat:use(technique, cible)` (`core.rpc`, schéma borné : chaîne de 1 à 32 octets `^[a-z0-9_]+$`, entier 0 à 65535) | le serveur ; réponse au seul appelant (`true, valeur, reprise, pente` ; `false, code[, attente]` ; `false, 'exhausted', attente, valeur, reprise, pente`) | ≈ 40 o + ≈ 24 o (≈ 35 o à bout de souffle) | un par coup, par parade, par pas de côté, par garde levée ; 4 d'avance puis 3 / s |
| `vava_combat:stamina` (1.6.0, `core.net.send`, compté) : valeur (dixièmes), ms avant la recharge, pente (dixièmes / s) | le **seul porteur** de la jauge, quand elle change hors de sa demande : coup bloqué (défenseur), remise à plein à la mise à terre si elle n'était pas pleine | ≈ 32 o | un par coup bloqué, un par chute ; **jamais au repos** ni pendant une remontée ; jamais à l'attaquant ni aux témoins |
| RPC `vava_combat:lower()` (aucun argument) | le serveur ; réponse au seul appelant (`true`, `false, 'no_guard'`) | ≈ 25 o + ≈ 10 o | un par garde abaissée ; 4 d'avance puis 3 / s ; **rien pendant la tenue** |
| `vava_combat:hit` (`core.net.playersNear` dans l'instance de l'attaquant, puis `core.net.send` à une liste) : attaquant, cible, issue (`hit`, `stagger`, `down`, `block`, `parry`, `break`, `dodge`, `absorb`) et, pour l'attaquant et la cible seulement (1.4.0), le montant en dixièmes ou `false` | les joueurs apparus à 30 m de la **cible**, dans l'instance de l'attaquant (cible, attaquant paré, témoins) ; `dodge` et `absorb` aux deux seuls participants | ≈ 23 à 32 o comptés par `core.net` (nom + charge) ; 4e valeur des participants : 1 o (`false`, jusqu'à 127 dixièmes), 2 o (jusqu'à 255), 3 o au-delà | **un** par cible touchée et par coup de technique (un adversaire par coup), en **deux envois** au plus (participants, témoins ; un sans témoin) ; un coup paré, bloqué ou qui brise la garde envoie son issue **à la place** de `hit` ; jamais pour un coup manqué, refusé ou annulé, ni pour un coup d'une autre ressource ; une esquive ou un coup absorbé : ≈ 25 o à chacun des deux seuls participants (rien en 1.3.0) |
| `vava_combat:notify` (`core.net.send`, compté) | le **seul** porteur dont l'arme passe un seuil ; le seul attaquant dont le coup est retenu (combats coupés, lieu de paix, crochet) ; le seul membre du Conseil qui tape `/armes` sans `vava_chat` | ≈ 70 à 160 o | 2 par arme et par cycle d'usure ; un avis par raison et par 10 s ; réponses de commande |
| Statebag de ped `vava_combat:shield` (`{ id, item }`) | OneSync : les joueurs qui ont ce ped à portée | ≈ 30 o | à l'accroche, au décrochage, à un nouveau ped du porteur ; jamais périodique |
| `GlobalState['vava_inventory:heldModels']` (mécanisme de l'inventaire) | tous | + ≈ 450 o | une fois, à la déclaration des objets |
| `vava_health:set` (existant) | la seule cible d'un coup | ≈ 26 o | un par coup appliqué |
| `vava_combat:dummy` (1.5.0, `core.net.send` à une liste) : mannequin `n`, attaquant, issue et montant (dixièmes, ou `false` pour un mot ; absent si les chiffres sont coupés) | l'**attaquant** (ou le lanceur) seul | 26 à 32 o comptés par `core.net` | un par coup qui atteint un mannequin |
| `vava_combat:dummy` (balancement seul : `n`, attaquant) | les joueurs à 15 m du **mannequin**, dans son instance, sans l'attaquant (`core.net.playersNear`) | 20 à 23 o comptés par `core.net` | au plus **un par mannequin et par 0,8 s**, quel que soit le nombre d'attaquants ; aucun si `witnessRadius = 0` |

Aucun envoi à tous, aucune clé GlobalState propre, aucun state bag nouveau, aucun envoi latent. Les gestes (coup,
réaction, dégainer, rengainer, chancellement) sont joués par chaque client sur son propre ped : OneSync les montre, rien
d'autre à envoyer ; de même pour la garde, la parade et le pas de côté. Combattant armé au repos, bouclier accroché
compris : **0 octet** ; garde levée puis baissée : 3 RPC (parade, garde, `lower` : ≈ 145 o), rien pendant la tenue.
Attente d'une parade ratée ou d'un pas de côté : propre à sa touche chez le client, elle ne retient ni la garde ni les
attaques ; le délai du pas de côté est connu du client, qui ne demande rien avant. Un coup manqué : la requête et sa
réponse, à l'attaquant seul. Mêlée à six vue d'un témoin : ≤ 12 `vava_combat:hit` par seconde (≈ 0,4 Ko/s), 12 effets
par seconde au plus.

Endurance (1.6.0) : au repos, armé ou non, jauge pleine ou en recharge : **0 octet** (aucune synchronisation périodique,
la page de `vava_hud` anime la remontée) ; un geste : + 9 o dans la réponse déjà envoyée ; une garde qui encaisse
quatre coups : ≈ 130 o au seul défenseur ; faim et soif n'envoient rien (la pente part avec la réponse du geste
suivant) ; rien de plus du client vers le serveur. Mêlée à six, au pire : ≈ 0,4 Ko/s en tout (≈ 65 o/s par joueur).
L'endurance n'entre jamais dans `vava_combat:hit` (elle révélerait la jauge du défenseur).

Mannequins (1.5.0) : leur présence ne coûte rien (la liste est dans la config) ; rien ne part tant que personne ne
frappe ; aucun RPC nouveau (un coup part par `use`, un sort par les RPC de la magie). Séance de 10 min à 1,5 coup / s
avec deux témoins : ≈ 25 Ko pour l'attaquant, ≈ 33 Ko pour les témoins. Au pire (3 mannequins, 8 joueurs dont 3 qui
frappent sans relâche) : ≈ 0,83 Ko/s sortants pour tout le serveur, ≈ 82 o/s au plus reçus par un témoin. Client : boucle des mannequins toutes les 2 s
loin d'une cour (≤ 64 distances), 0,5 s près, seulement personnage apparu ; balancement : une native par image et par
mannequin qui bouge, pendant 0,9 s au plus après le dernier coup.

Côté client : un contrôle à 1 Hz (trois natives au repos) ; seulement tant qu'un bouclier est en vue, une boucle lente
(1 s) qui ne montre un bouclier qu'à 120 m au plus ; et **une seule boucle par image**, celle du mode combat, qui ne
tourne qu'éveillé (par une touche du combat, l'arme en main) **et** actif, et s'endort après 10 s sans coup. Arme en main
sans rien presser : rien ne tourne. Le verrou n'a pas de boucle propre ; la main est gardée dans un cache local (aucune
lecture du personnage) ; les dictionnaires des gestes du style de l'arme sont chargés à la prise en main.

## Sécurité

- **Défense (1.3.0)** : aucun RPC ne porte un résultat ; parade, garde et pas de côté sont des fenêtres posées par le
  serveur **à l'acceptation** de la demande (une réservation n'ouvre rien) et comparées à son horloge quand un coup
  arrive ; seuls les trois modificateurs de la chaîne décident, sur la mémoire du module et les positions et le cap lus
  par le serveur (même personnage, à pied, sans contrôle dur de la magie). Parade : fenêtre ≤ 500 ms (format), 200 par
  défaut, 0,6 s sans parade après un raté, une seule place à la fois (pas de parade sous une garde ni pendant un coup) ;
  pas de côté : invulnérabilité ≤ 500 ms (250), 1,5 s entre deux départs ; garde : de face seulement, part arrêtée < 1,
  aucune attaque garde levée (`guarding`), brisée quand l'endurance est vide (1.6.0). Un geste défensif annulé garde son
  cycle.
  Bouclier relu en mémoire (numéro de pile accrochée) à chaque coup ; usure par `wear.apply`, qui relit la pile, hors
  de la chaîne. Non fermé : le cap déclaré par le client (OneSync) — la parade reste une affaire de **temps** tenue par
  le serveur, le blocage n'arrête qu'une part ; journal `vava_health_hits` (étape d'annulation, montant bloqué).

- **Endurance (1.6.0)** : tenue par le serveur seul ; aucun RPC ni argument ne porte une valeur d'endurance (le client
  n'affiche qu'une projection) ; refus `exhausted` en mémoire avant la réservation et tout export, puis revérifié et
  dépensé au **dernier pas** de la vérification, sans rien qui cède la main ensuite (un coup bloqué pendant un crochet
  qui cède la main est vu) ; dépense une fois, à l'acceptation ; coût d'un coup bloqué selon la technique **lue par le
  serveur** et ce qui bloque au moment du coup ; faim et soif lues par le serveur (`vava_needs:get`, isolé), jamais par
  le client ; jauge jamais envoyée à un autre que son porteur.
- **Le serveur décide de chaque coup** : aucun RPC ne porte un résultat ; la frappe est jugée au relevé du serveur, sur
  les positions et le **cap qu'il lit** (`GetEntityCoords`, `GetEntityHeading` du ped), dans l'instance de l'attaquant
  (`core.net.playersNear`), avec des tolérances bornées au démarrage (≤ + 1 m, ≤ + 30°, ≤ + 1 m). `strike` revérifie la
  distance (6 m) et l'instance. La cible annoncée par le client ne sert qu'à l'ordre des candidats : elle n'allonge ni la
  portée ni l'angle.
- **Délai** : aucun coup ne porte hors de la frappe (deux minuteries du serveur par coup, rien d'autre ne frappe) ; une
  demande pendant un coup est refusée sauf enchaînement admis après la frappe ; quatre coups enchaînés au plus ; une cible
  touchée une fois par coup ; débit du RPC 3 / s ; dégainer (0,8 s) et chancellement (0,9 s) tenus en mémoire du
  serveur ; `vava_health` limite encore à 20 coups par seconde par paire. Un coup annulé, quelle qu'en soit la cause,
  garde sa récupération et son compte d'enchaînement (relecture sécurité S-1) : se mettre soi-même en véhicule, faire
  un bond ou changer d'arme ne libère jamais plus tôt. Une demande admise **réserve** sa place avant le premier export
  ou crochet (S-2) : deux demandes simultanées ne passent jamais toutes les deux, même si un crochet `using` cède la
  main ; un refus (ou une erreur, `pcall`) rend la place au premier coup d'avant non refusé, tel quel, seulement si
  elle est encore à cette réservation (contre-relecture C-1).
- **Technique choisie** : contrôlée contre le style de l'arme **tenue** (lue par le serveur), technique qui ouvre
  obligatoire hors enchaînement, chaîne déclarée en données. Arme échangée ou rangée pendant le coup : hook `hold`, pile
  relue au relevé, puis par `strike`.
- **Bond** : déplacement de l'attaquant borné entre la demande et chaque relevé (8 m/s + 0,5 m), console une fois par
  minute et par joueur. Non fermé : une position mensongère **avant** la demande (OneSync : position déclarée par le
  client, limite connue de `SECURITE_RESEAU.md` § 3 ; portée courte, journal `vava_health_hits` pour le Conseil) ; un coup
  à travers une cloison mince (aucun contrôle des murs : décision du porteur du projet). Le bond permis grandit avec la
  préparation (5,7 m pendant le Fendant) : `lunge.maxSpeed` à resserrer à la porte T-119 (S-3).
- **Cap** : lu par le serveur sur le ped, mais c'est celui que le client déclare (OneSync) ; l'angle arrête les ratés
  honnêtes, pas un client modifié qui se tourne au bon moment (comme les murs, S-4). Aucune borne de l'écart de cap
  entre la demande et le relevé : le virage légitime vers la cible verrouillée (540°/s) la rendrait sans effet ; la
  portée, elle, reste tenue.
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
- **Mannequins (1.5.0)** : aucun RPC nouveau ; portée, angle, hauteur et instance jugés par le serveur sur ses positions
  (filet de 6 m entre l'attaquant et le mannequin) ; montant tiré de l'arme réellement tenue et de `vava_health:trial`
  (rien d'appliqué, débit propre de 20 essais par seconde) ; `dummyHit` réservé à `dummies.callers`
  (`GetInvokingResource`, `not_allowed`, une ligne de console par minute et par ressource), lanceur à personnage actif,
  même instance, 80 m au plus ; `dummiesNear` en lecture seule (places publiques). Un coup d'essai ne déclenche ni
  défense, ni incantation brisée, ni journal, ni XP. Liste contrôlée au démarrage par le seul serveur (bornes,
  identifiants uniques, champs connus, 64 au plus) ; le client relit chaque valeur de `vava_combat:dummy` (numéro,
  joueur, issue, montant).
- Armes et coups natifs de GTA : retirés à 1 Hz côté client, drapeau du corps à corps, touches coupées en mode combat ;
  **dégâts annulés côté serveur** quoi que fasse le client (`vava_health` 1.3.0).

## Conseil (droit `metiers`)

| Commande | Effet |
|---|---|
| `/armes liste` | une ligne par arme (libellé, catégorie, type, coup, solidité, « modèle provisoire »), regroupées en deux messages de chat (sans `vava_chat` : notifications de 200 signes) |
| `/armes voir <n°>` | arme en main (qualité, palier, solidité, coup de base → coup effectif à × 1,0, émoussée), bouclier accroché (position, solidité) et endurance (1.6.0 : « Endurance : 42,5 / 100, recharge 15 / s (ralentie par la faim ou la soif) », lecture seule : aucune commande ne la change) ; **journal** « Combat : armes consultées » |
| `/armes user <n°> <points>` | baisse la solidité de l'arme en main (1 à 1 000 points ; jamais au-dessus), seuils prévenus comme une usure ; écriture refusée (arme partie, garde de l'artisanat) : message à part (`adminFailed`), rien au journal ; sinon **journal** « Combat : arme usée » (avant, après) — essais d'émoussage et de réparation |

Console admise (`armes …`). Déclarée au registre `core:commands` (chapitre « Combat »), avec les trois touches du combat.

## API

**RPC** `vava_combat:use(technique, cible)` → `true, valeur, reprise, pente` (coup accepté, fenêtre programmée ; geste
défensif : fenêtre ouverte ; aucun résultat : il arrive par `vava_combat:hit`, ou jamais ; 1.6.0 : état de **sa**
jauge d'endurance après la dépense — dixièmes 0 à 1 000, ms avant la reprise de la recharge 0 à 10 000, dixièmes par
seconde 0 à 1 000 —, jamais un instant du serveur), `false, code`, `false, code, attente` (ms : `busy`, `chain_limit`,
`drawing`, `staggered`, `guard_broken`, `parry_cooldown`, `dodge_cooldown`), `false, 'exhausted', attente, valeur,
reprise, pente` (1.6.0 : coût plus grand que ce qui reste ; attente jusqu'à ce qu'il soit payable, 30 000 au plus) ou
`false, 'refused', raison` (crochet). Codes : `not_ready`, `unknown_technique`, `not_attack` (type `garde`),
`not_opener`, `busy`, `chain_limit`, `guarding` (garde levée : l'abaisser d'abord), `staggered`, `drawing`,
`guard_broken`, `parry_cooldown`, `dodge_cooldown`, `exhausted`, `no_character`, `no_weapon`, `no_style`, `not_in_style`, `downed`,
`vehicle`, `controlled`, `refused`, `error` ; au-delà du débit, `rate_limited` du core. Pour un geste défensif, la cible
est ignorée.

**RPC** `vava_combat:lower()` → `true` (garde abaissée, ou abaissement noté sur une garde encore réservée),
`false, 'no_guard'` (aucune garde levée), `false, 'not_ready'`.

| Export serveur | Retour |
|---|---|
| `weapon(item)` | copie de la fiche `{ item, label, category, family, kind, damage, reachBonus, durability, block, provisional }` (classe et fiche fusionnées), ou `nil` |
| `weapons()` | liste ordonnée (catégorie, puis libellé) des fiches |
| `armed(src)` | arme en main : `{ instanceId, item, category, family, kind, damage, factor, amount, reachBonus, quality, durability, maxDurability, dull }` (`factor` : qualité × usure ; `amount` : coup à × 1,0) ; pendant le rengainement (1,5 s) : `{ item, category, family, sheathing = true, readyInMs }` ; sinon `nil, code` (`not_ready`, `no_character`, `no_weapon`) |
| `techniques()` | liste (style, puis libellé) de copies `{ id, label, style, type, gesture, phases, hit?, damage?, stamina, parryable?, staggers?, chain, learn? }` (champs selon le type : un geste défensif n'a ni `damage`, ni `parryable`, ni `staggers`, une esquive pas de `hit`) |
| `technique(id)` | copie d'une technique, ou `nil` |
| `shield(src)` | `{ instanceId, item, block, durability, maxDurability, dull, position, ready }` (`ready` : au bras), ou `nil` : rien d'accroché, inventaire muet (rien n'est affirmé sans la pile), ou pile partie de la besace (décrochée aussitôt) |
| `strike(src, cible, opts)` | résultat de `vava_health:hit` + `weapon = { item, durability, maxDurability, worn, dull }`, ou `nil, code` — `not_allowed`, `not_ready`, `invalid_target`, `no_character`, `downed`, `invalid_options`, `no_weapon`, `too_far`, `health_unavailable`, plus les codes de `hit` ; réservé à `strike.callers` |
| `dummiesNear(point, rayon)` | 1.5.0 : `{ { n, id, x, y, z, distance } }` (centre visé, distance 3D), triés par distance puis numéro, `nearMax` (8) au plus ; point illisible, rayon hors de ]0, 50] ou module pas prêt : `{}` ; lecture seule, toute ressource |
| `dummyHit(n, paquet)` | 1.5.0 : `{ outcome, amount }` ou `nil, code` — `not_allowed` (hors `dummies.callers`), `not_ready`, `invalid_dummy`, `no_character` (source sans personnage actif), `too_far` (autre instance, ou plus de 80 m), codes de `vava_health:trial`, `health_unavailable` ; paquet transmis tel quel à `trial` ; envoi au lanceur et hook `trained` ; `outcome = nil` : coup retenu, rien d'envoyé |
| `dummies()` | 1.5.0 : `{ { n, id, label, x, y, z, heading, bucket, model } }` (pied du mannequin, copies) — T-121, Conseil |

| Export client | Retour |
|---|---|
| `armed()` | `{ item, category, family }` de l'arme du personnage local ; pendant le rengainement, `+ sheathing = true` ; sinon `nil` (cache local de la main : affichage et demandes, jamais une décision) |
| `inCombatMode()` | vrai si le mode combat est éveillé et actif |
| `shieldHung()` | objet du bouclier accroché sur son propre ped, ou `nil` |

**Hooks émis** : `vava_combat:using` `before` (annulable, ne cède jamais la main : `{ source, characterId, technique, item,
target?, kind }` — `kind` : type de la technique ; prison, ligotage, trêve : un refus vaut aussi pour parer, se garder,
esquiver ; la raison, 120 octets, est montrée au joueur) ; `vava_combat:defended` `after` (`{ source (défenseur),
characterId, outcome = 'dodge' | 'parry' | 'block' | 'break', technique, attacker?, attackerTechnique?, hitId }`, une
fois par coup défendu : XP de défense de T-115, chiffres de T-155) ; `vava_combat:shieldHang` `before`
(accroche seule, annulable : `{ source, characterId, instanceId, item }` — prison, interdiction du Conseil ; la raison est
montrée au joueur) et `after` (`+ hang, reason` = `use`, `gone`, `restored`) ; `vava_combat:dulled` `after`
(`{ source, characterId, instanceId, item }`) ; `vava_combat:trained` `after` (1.5.0 : `{ source, characterId, dummy,
n, kind = 'melee' | 'spell', technique?, item?, spell?, amount, outcome }`, une fois par coup qui atteint un mannequin,
jamais pour un coup retenu ; XP plafonnée de T-115, retour d'essai de T-121). **Écoutés** : `core:module:ready` (`vava_inventory`, `vava_crafting`,
`vava_skills`), `core:character:spawned`, `core:character:unloading`, `core:player:dropped`, `vava_inventory:move`,
`drop`, `remove`, `hold` (`after` : dégainer, rengainer, coup annulé), `vava_health:downed` (`after` : coup annulé,
chancellement oublié, défense oubliée), `vava_health:hit` (`after` : suites d'une défense), `core:module:ready` de
`vava_health` (modificateurs redéclarés) ; client : `core:character:loaded`, `fieldChanged`, `unloaded` (cache de la
main) ; `core:character:spawning`, `selection`, `unloaded` (boucle des mannequins).

**Évènement** `vava_combat:stamina(valeur, reprise, pente)` (1.6.0, serveur → le seul porteur) : sa jauge a changé
hors de sa demande (coup bloqué, remise à plein à la mise à terre) ; trois entiers bornés (`VavaCombat.ENDURANCE_*` de
`shared/constants.lua`), relus par `endurance.read`, sinon ignorés.

**Interne** (1.6.0) : `VavaCombat.stamina.block(cible, garde, poids, bouclier, maintenant, personnage)` (serveur
seul) remplace `VavaCombat.defense.spend` de 1.3.0 : un coup bloqué, rend vrai si la garde cède.

**Évènement** `vava_combat:dummy(n, attaquant[, issue, dixièmes|false])` (1.5.0, serveur → clients ciblés) : à
l'attaquant, l'issue et, si `numbers.enabled` et `numbers.attacker`, le montant en dixièmes ou `false` pour un mot ; aux
témoins, `n` et l'attaquant seuls (balancement). Le client relit chaque valeur (`n` d'un mannequin connu, joueur 1 à
65 535, issue de `OUTCOMES`, montant entier 0 à 2 000) et ignore le reste.

**Modificateurs** (registre `vava_health:modifiers`, déclarés au démarrage et à chaque démarrage de `vava_health`) :
`vava_combat:esquive` (étape `esquive`, tous les types de dégâts), `vava_combat:parade` (`parade`) et
`vava_combat:blocage` (`blocage`), ces deux-là pour `tranchant`, `contondant`, `percant` ; priorité 50. Aucun ne cède
la main ; personne ne se défend : une lecture de table, aucune native.

### Pour les tâches suivantes

- **T-113** (fait, 1.3.0) : Garde, Parade, Pas de côté en données ; fenêtres tenues par le serveur sans minuterie ;
  trois modificateurs ; suites dans le hook `vava_health:hit` after ; compteur provisoire de garde brisée ; touches R et
  Espace ; issues `parry`, `block`, `break`.
- **T-114** (fait, 1.6.0) : endurance tenue par le serveur (`shared/stamina.lua`, `server/stamina.lua`), refus
  `exhausted`, garde brisée quand elle est vide (compteur provisoire, `defense.spend`, `defense.addPoints`,
  `config.defense.guardBreak` retirés), faim et soif par `vava_needs:get`, état au seul porteur, jauge de `vava_hud`
  1.8.0 animée par la page. Aucun export `guarding()` (inutile : la jauge est menée par ce module).
- **T-115** : coûts des techniques des autres armes ; une compétence pourrait alléger un coût ou hâter la recharge (un
  facteur de plus dans `stamina.rateOf`, à décider alors) ; l'endurance n'entre pas dans l'XP.
- **T-119** (endurance) : valeurs (20 / s, 1 s, coûts 12 / 9 / 11 / 25, Garde 25, parade 6, pas 20, bouclier × 0,67,
  lourd × 2, paliers de faim et soif, seuils d'affichage) ; `parry_cooldown` et `dodge_cooldown` peuvent baisser
  maintenant que l'endurance borne la défense ; deux Fendants d'un même attaquant ne brisent plus la garde (recharge
  entre eux), à juger ; montrer aux autres un combattant essoufflé (geste, son).
- **T-121** : curseur « Endurance » de la maquette `Combat.html` à relibeller selon le type (Garde : « coût d'un coup
  bloqué » ; Parade, Pas de côté : « coût du geste ») ; aide : « Ce que coûte le geste ; à vide, on ne frappe plus, la
  garde cède. »
- **Plus tard** : course (pente négative en mode combat, à proposer), effet « Renforcer » de la magie (modificateur de
  pente posé par un export à ajouter alors), réglage « Jauges toujours visibles » (`vava_pause` + `vava_hud`).
- **T-115** (styles et progression) : `learn` (compétence, niveau) lu et contrôlé, jamais appliqué (la Parade demande
  le niveau 10) ; autres styles (`hache_une_main`, `masse_une_main`, `dague_dague`, `baton_baton`, et `epee_deux_mains`
  à décider), et leurs techniques défensives ; XP de défense par le hook `vava_combat:defended` sur une vraie cible ;
  `techniques()`.
- **T-119** (réglages) : fenêtre de parade et sa préparation, invulnérabilité, délais, arcs protégés, parts bloquées des
  fiches (épée 0,40 peut-être trop faible face à 4 coups), sensations à 30, 80 et 150 ms de ping
  (aucune compensation de latence : le défenseur lent anticipe d'un aller de son ping).
- **T-155** (chiffres des coups, fait en 1.4.0) : montant en 4e valeur de `vava_combat:hit` (dixièmes, ou `false`
  pour un mot) aux seuls participants désignés par `config.numbers` ; `dodge` et `absorb` à eux seuls, jamais aux
  témoins ; un coup d'une autre ressource défendu n'envoie toujours rien (le hook `vava_combat:defended` en porte
  l'issue).
- **T-119** (chiffres des coups) : voir si les témoins doivent voir les mots (`parry`, `break`) ou les chiffres
  (`numbers.witnesses`, une clé, pas une refonte).
- **T-156** (fait, 1.5.0) : mannequins en config, coup d'essai `vava_health:trial`, envois `vava_combat:dummy`, hook
  `trained`, exports `dummiesNear`, `dummyHit`, `dummies`. Un mannequin n'est jamais défendu (les modificateurs ne
  décident que pour un joueur) ; un calcul « à blanc » ne déclenche aucune suite.
- **T-115** (XP) : XP de combat par `vava_combat:trained` tant que le niveau dans la compétence de l'arme est **sous**
  `config.dummies.xpMaxLevel` (9) ; aucune XP de défense sur un mannequin ; mentorat : auprès de son maître, l'apprenti
  progresse plus vite sous le plafond, sans le lever (au-delà, le maître se fait partenaire : la Parade se gagne face à
  quelqu'un) ; à décider avec T-115. Débit d'XP par personnage ; éclats et Nova comptés comme un seul gain (relecture
  sécurité S-4).
- **T-121** (éditeur des techniques) : « Essayer contre un mannequin » : `dummies()`, technique en essai jouée par son
  auteur sur le mannequin le plus proche, chiffre par T-155, `trained` pour le retour.
- **Cour d'armes dans l'Atelier** (tâche proposée au backlog, après T-102) : éditeur `vava_combat:cour` (famille
  `monde`, droit `metiers`), sorte `dummy`, schéma de la spec § 5.1, placement `prop` ; la liste de la config devient la
  version 1 ; diffusion par une zone `core.zones` par mannequin (`dummy:<id>`) ; la liste quitte `config_client.lua`
  pour `config.lua` ; `server/dummies.lua` garde son interface (`dummies.replace`).
- **T-137** : instance des mannequins côté client.
- **T-121** (éditeur des techniques) : `techniques()`, `weapons()`, `provisional` ; le format et ses bornes sont ceux
  de `weapons.checkTechniques`. Fait par T-112 : fiches d'armes coupées en deux (classe client, fiche serveur), délais du
  serveur du bouclier et `guard.delay` sortis de ce que télécharge le joueur (relectures R-2, R-3 et S-2 de T-142).
- **T-149** (fait, `vava_magic` 2.12.0 ; aucun changement de code ici) : la magie lit `armed()` côté client (arme
  du royaume en main : ni rappel ni anneau de la magie ; `sheathing` : « Vous rengainez votre arme… ») ; export serveur
  `hardControl(src)` → `'frozen'`, `'knockdown'`, `'stagger'` ou `nil`, lu par `bridge.MagicHardControl` à l'étape 13
  de l'admission (refus `controlled`, « Vous ne pouvez pas frapper ainsi. »). Essai de bout en bout (export réel de la
  magie lu par ce bridge) : `tests/spec/magic_combat_mode_spec.lua`.
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

Mannequins (1.5.0) : **sac de frappe de GTA** (`prop_beach_punchbag`) en attendant le mannequin de paille sur son poteau
(aperçu de `docs/maquettes/Combat.html`), **botte de foin** (`prop_haybale_03`) en repli, éclats de bois
(`core` / `ent_dst_wood_splinter`) en attendant la paille, trois places derrière le poste de Paleto Bay : `dummies` de
`config_client.lua`. Un modèle introuvable : une ligne de console par modèle, le repli à sa place ; les deux introuvables :
aucun prop, le mannequin reste frappable (le serveur ne lit que sa place).

Icônes : `web/items/*.svg` (une par objet nouveau, au format de l'objet, fond transparent, ombre comprise).

## Fichiers

Les en-têtes des fichiers servis aux joueurs sont courts (relecture réseau R-2 de T-112) : le détail est ici.

| Fichier | Servi | Rôle |
|---|---|---|
| `shared/constants.lua` | tous | table du module (seule globale `VavaCombat`) ; RPC, évènements ciblés, statebag et champ privé du bouclier, hooks émis, catégories (liste fermée de `COMBAT_V1.md`), types de techniques et issues, états de l'inventaire lus par le client, bornes et motifs de validation |
| `config_client.lua` | tous | réglages que lit le client (le serveur les lit aussi) : `weaponClasses`, `techniques`, `styles` et `keys` entiers (lus par une clé variable) ; tout le reste dans `config.lua` (T-132) |
| `shared/shield.lua` | tous | où porter le bouclier (bras ou dos, selon la main du même ped), quel placement montrer (lu dans la config de chaque client, jamais dans la valeur), valeur `{ id, item }` publiable, deux valeurs égales (garde), ped visé par un statebag ; règles recopiées de `vava_inventory/shared/held.lua` |
| `shared/heading.lua` | tous | cap d'un point vers un autre (0 = nord, croissant vers l'ouest) : le client se tourne vers sa cible ; le serveur le reprend dans `geometry.headingTo` |
| `shared/techniques.lua` | tous | style d'une arme (`<famille>_<catégorie>`), cycle d'un coup (`plan`), technique d'une touche côté client (`pick` : libre, l'ouvreur ; pendant la récupération, la première de la chaîne du type de la touche ; sinon l'attente) |
| `shared/geometry.lua` | serveur | avant d'un cap, distance au sol et écart de hauteur, angle à plat, arc d'une technique et cible dans l'arc, ordre des candidats, bond plausible ; jamais d'erreur sur une valeur non finie |
| `shared/admission.lua` | serveur | admission d'une demande : libre → l'ouvreur seul (`not_opener`) ; pendant la récupération (frappe finie, à `earlyMs` près) → une technique de `chain` dans la limite de `chainMax` (`chain_limit`) ; sinon `busy` et l'attente |
| `shared/weapons.lua`, `shared/guard.lua` | serveur | constantes du seul serveur (types défensifs, types qu'on peut demander, hooks `defended` et `trained`), contrôle de la config (mannequins compris : `checkDummies`), qualité, solidité, usure, issue d'un coup, options de `strike` ; délai de la garde du statebag |
| `bridge/client.lua` | tous | seul point de contact du client : notification (`vava_hud`, sinon celle du jeu) ; main du personnage local (`owner` de `vava_inventory:hands`) gardée en cache, tenue par `core:character:loaded`, `fieldChanged`, `unloaded` (aucune lecture du personnage à chaque appel, rapport T-140 R-1) ; changement de main annoncé ; à terre (`vava_health:get`) ; nom du statebag de la main |
| `client/natives.lua` | tous | drapeau de ped 122, changement d'arme bloqué, armes GTA retirées (menu de triche, `/arme` de l'exemple) ; ces bascules tiennent jusqu'au changement de ped : contrôle à `natives.pollMs` (trois natives par seconde au repos) ; rendues à GTA à l'arrêt (`restoreOnStop`) ; le filet reste l'annulation serveur de `vava_health` |
| `client/shields.lua` | tous | patron de `vava_inventory/client/hands.lua` : objet **local** sans collision attaché au ped du porteur (bras ou dos), réattaché sans être recréé quand la main change ; boucle lente seulement tant qu'un bouclier est suivi (ped ou modèle attendu, objet détaché, ped disparu, distance de `showRadius`) ; modèle invalide : une ligne de console, aucun nouvel essai avant que la valeur change |
| `client/hands.lua` | tous | arme du royaume en main (jamais un bouclier) et son style ; prise en main : geste de dégainer, en garde après `draw.drawMs` ; arme rangée : geste de rengainer et `sheathing` pendant `draw.sheatheMs` ; main restaurée (chargement, redémarrage) : en garde d'emblée ; gestes du style chargés à l'avance, ceux de l'ancien style rendus ; geste ponctuel (dégainer, rengainer, chancellement, tressaillement) : dictionnaire rendu juste après le geste ; dictionnaire absent : rien n'est joué, une ligne de console par nom et par minute |
| `client/keys.lua` | tous | une commande par action, liée par `RegisterKeyMapping` (souris par défaut) ; déclarées au registre `core:commands` par `server/commands.lua` (Codex) |
| `client/targeting.lua` | tous | règles de `vava_magic/client/targeting.lua` : appui court → le joueur le plus proche du centre de l'écran (`lock.range`, `coneDeg`, en vue) ; nouvel appui : le suivant ; maintenu `holdMs` : relâché ; perdu hors de portée (+ `rangeMargin`), hors de vue `lostChecks` relevés de suite, mort, ou au sommeil du mode ; candidats faits à l'appui seulement |
| `shared/defense.lua` | serveur | règles pures de la défense : fenêtre ouverte, garde abaissée (tenue minimale), attaquant de face, étiquettes, part bloquée, montant bloqué, délais de la parade ratée et du pas de côté, poids d'un coup bloqué |
| `server/defense.lua` | serveur | refus en mémoire (garde brisée, délais), cache de la garde, geste accepté, RPC `lower`, trois modificateurs (esquive, parade, blocage ; une lecture de table si personne ne se défend), décisions notées puis suites au hook `vava_health:hit` after (attaquant paré, coup bloqué payé par `stamina.block` et garde brisée, usure différée, issue imposée, hook `defended`) |
| `shared/endurance.lua` | tous | 1.6.0 : niveau d'un état de la jauge à un instant, lecture bornée d'un état reçu, instant où elle est pleine (table `VavaCombat.endurance`) |
| `shared/stamina.lua` | serveur | 1.6.0 : règles pures de l'endurance : coût d'une technique, dépense, coût et suite d'un coup bloqué, attente, part laissée par la faim et la soif, pente, changement de pente, état envoyé (table `VavaCombat.stamina`, jamais lue par un fichier client) |
| `server/stamina.lua` | serveur | 1.6.0 : jauges en mémoire (sans minuterie), refus `exhausted`, préparation (faim et soif), prise au dernier pas, coup bloqué, état au seul porteur, remise à plein à la mise à terre, oubli, lecture du Conseil |
| `client/endurance.lua` | tous | 1.6.0 : table `VavaCombat.gaugeView` : état reçu daté à l'arrivée, niveau projeté, médaillon de `vava_hud` (déclaré, mis à jour avec sa remontée, retiré en différé : un `SetTimeout` au plus), visibilité, prédiction du coût ; aucune boucle |
| `client/defense.lua` | tous | table `VavaCombat.stance` : R (appui : parade ; maintenue : garde à la fin de la fenêtre de parade ; relâchée : `lower`), Espace (pas de côté, direction lue une fois) ; aucune boucle (`tick` appelé par la boucle du mode : garde demandée, sprint coupé) ; garde tombée sans `lower` au chancellement et à la garde brisée |
| `client/attack.lua` | tous | technique choisie par `pick`, personnage tourné vers la cible verrouillée ou la caméra (`faceMaxDeg`), geste aussitôt, demande dans un thread ; refus ou transport en échec : geste coupé, texte (un par code et par `noticeMs`), attente du serveur respectée ; touche pressée trop tôt gardée (`bufferMs`) ; virage vers la cible pendant la préparation et la frappe ; chancellement : geste coupé, cycle gardé (comme au serveur) |
| `client/mode.lua` | tous | patron de `vava_magic/client/controls.lua` : éveil par une touche du combat si l'arme a un style (sinon le texte, une fois par arme sortie) ; actif à pied, debout, pas à terre, pas ligoté, sans interface ni menu (relevé à `conditionsMs`) ; sommeil après `idleMs` sans coup ni appui sur le verrou, ou aussitôt que la main change ou le personnage est déchargé ; boucle par image seulement éveillée et active (contrôles coupés, anneau, verrou, touche gardée, virage) |
| `client/reactions.lua` | tous | cible : chancellement (geste, coup coupé, secousse) ou tressaillement (si elle ne frappe pas) ; attaquant : son de touche réglé, pour `hit`, `stagger`, `down` ; tous : effet d'impact sur le ped de la cible (sang ; étincelles pour un blocage ou une parade), `effects.maxPerSecond` au plus ; aucun objet créé |
| `shared/dummies.lua` | tous | index des mannequins (1.5.0) : numéro = place dans la liste, centre visé ; table `VavaCombat.dummyRules` (le contrôle de la liste est au seul serveur, `shared/weapons.lua`) |
| `server/dummies.lua` | serveur | mannequins chargés, candidat d'un relevé (après les joueurs, instance lue seulement si un mannequin est près), coup d'arme à blanc (`vava_health:trial`), coup de sort (`dummyHit`), usure réduite, envois `vava_combat:dummy` (attaquant, témoins au plus un par 0,8 s), hook `trained`, `dummiesNear`, `dummies()` ; table `VavaCombat.dummies` |
| `client/dummies.lua` | tous | table `VavaCombat.dummyProps` : liste indexée sous `pcall` (illisible : une ligne, aucun prop), props locaux streamés (patron de `vava_gathering/client/props.lua`), boucle lente seulement personnage apparu, modèle de repli, modèle qui ne se charge pas gardé sans prop jusqu'à la sortie de portée (une ligne par modèle),
 balancement (une boucle par image le temps du balancement, ≤ 0,9 s), éclats, chiffre et son chez l'attaquant ; tout retiré au déchargement, à la sélection et à l'arrêt |
| `client/main.lua` | tous | notifications et état d'endurance du serveur, exports client, démarrage des contrôles natifs, du suivi des boucliers et des mannequins |

## Installation

`ensure vava_combat` après `vava_health` et `vava_crafting` (voir l'ordre du `README.md` à la racine). Pour essayer un
coup sans technique en développement : `set vava_env dev` et `ensure vava_example_combat` (1.1.0), puis
`/frapper_arme <n°>`.

**Mise à jour vers 1.5.0 (T-156)** : demande `vava_health` 1.6.0 (coup d'essai). `config_client.lua` gagne `dummies`
(modèles, distances, balancement, éclats, liste) et `config.lua` sa part du serveur (`config.dummies.wearChance`…). Un
fichier modifié et gardé par l'installeur (le nouveau posé en `.nouveau`) fait **refuser le démarrage** (« dummies :
table attendue », « dummies.wearChance … ») : reportez la table d'après les nouveaux fichiers.

**Mise à jour vers 1.4.0 (T-155)** : `config.lua` gagne `numbers` (quatre booléens). Un `config.lua` modifié et gardé
par l'installeur (le nouveau posé en `.nouveau`) fait **refuser le démarrage** (« numbers attendu … ») : reportez
`config.numbers` d'après le nouveau fichier. Les chiffres s'affichent par `vava_hud` ≥ 1.7.0 (sans lui, rien ne
s'affiche et le combat est inchangé).

**Mise à jour vers 1.3.0 (T-113)** : `config_client.lua` gagne trois techniques, les touches `blocage`, `parade`,
`esquive` du style, la table `defense`, les touches `garde` et `esquive`, deux contrôles coupés (22, 45) et cinq refus ;
`config.lua` gagne `rateLimits.lower`, la part du serveur de `defense`, `reactions.silent` et `messages.modifiers`. Un
fichier modifié et gardé par l'installeur (le nouveau posé en `.nouveau`) fait **refuser le démarrage** (« defense :
table attendue », « rateLimits.lower … ») : reportez vos réglages d'après les nouveaux fichiers.

**Mise à jour vers 1.2.0 (T-112)** : les fiches des armes sont coupées en deux (classe dans `config_client.lua` →
`weaponClasses`, fiche dans `config.lua` → `weapons`) et les délais du serveur du bouclier passent dans `config.lua`. Un
fichier modifié et gardé par l'installeur de la Chancellerie (le nouveau posé en `.nouveau`) garde l'ancienne forme : le
module **refuse de démarrer** avec un message clair (« config_client.lua d'avant 1.2.0 … » ou « config.lua d'avant
1.2.0 … ») ; reportez vos réglages d'après les nouveaux fichiers.

**Mise à jour vers 1.1.0 (T-132)** : les fiches des armes, le bouclier accroché, le placement des boucliers et les
contrôles natifs ont quitté `config.lua` pour `config_client.lua`.

**Mise à jour vers 1.6.0 (T-114)** : `config.lua` gagne `endurance` (et deux textes, `messages.inspectEndurance`,
`enduranceSlowed`) et perd `defense.guardBreak` ; `config_client.lua` gagne `gauge` et le refus `exhausted`, et la
Garde coûte 25 (au lieu de 8). Un `config.lua` modifié et gardé par l'installeur (le nouveau posé en `.nouveau`) fait
**refuser le démarrage** (« config.lua : réglage `endurance` absent … ») : reportez vos changements depuis
`config.lua.nouveau` ; `defense.guardBreak` resté en place ne gêne pas (une ligne de console). De même pour un
`config_client.lua` gardé (« réglage `gauge` absent »). Jauge animée avec `vava_hud` ≥ 1.8.0.

## Tests

- Hors jeu : `tests/spec/combat_weapons_spec.lua` (catalogue en deux parts, qualité, solidité, montant, usure, options,
  paquet), `combat_shield_spec.lua` (position, placement, valeur du statebag, garde ; position et placement aussi sur la
  seule vue client), `combat_strike_spec.lua` (serveur avec doublures : catalogue, strike et son contexte interne, usure,
  bouclier, garde, `/armes`), `combat_geometry_spec.lua` (avant, cap, angle, arc, tolérances, ordre, bond),
  `combat_techniques_spec.lua` (contrôle du format, cycle, admission, enchaînement, choix d'une technique, style, issue),
  `combat_use_spec.lua` (cycle serveur réel avec doublures : coup qui porte, hors de portée, hors de l'arc, autre
  instance, refus dans l'ordre, annulations, bond, contrôle dur de la magie, enchaînement, martèlement, issues,
  chancellement, dégainer et rengainer, exports ; bridge : export `hardControl` relu au démarrage de la magie),
  `combat_hands_client_spec.lua` (cache de la main, rengainement, mode combat, coup prédit puis coupé ; R, Espace,
  garde brisée), `combat_defense_spec.lua` (règles pures de la défense ; serveur réel avec une chaîne d'essai : parade,
  pas de côté, garde, bouclier, garde brisée, abaissement, annulations, réservation, modificateurs, réseau, démarrage),
  `combat_numbers_spec.lua` (1.4.0 : montant envoyé, destinataires des chiffres, `numbers` au démarrage),
  `combat_dummies_spec.lua` (1.5.0 : règles de la liste, issue « comme si », part du serveur ; relevés réels sur un
  mannequin : après les joueurs, portée, angle, hauteur, instance, une fois par coup, Fendant, usure 1 sur 4, hook,
  envois et témoins au plus un par 0,8 s ; `dummyHit`, `dummiesNear`, `dummies()`), `combat_dummies_client_spec.lua`
  (props streamés à 60 / 70 m, cadence de la boucle, repli du modèle, déchargement, arrêt ; `vava_combat:dummy` relu,
  chiffre chez l'attaquant seul, balancement qui s'arrête de lui-même), `combat_endurance_spec.lua` (1.6.0 : règles
  pures de la jauge ; serveur réel : réponses de `use`, refus avant la réservation, prise au dernier pas, garde, bouclier,
  Fendants, mise à terre, parade, pas de côté, borne de l'alternance pas / parades, faim et soif, `/armes voir`,
  réseau ; bridge `NeedsValues`), `combat_endurance_client_spec.lua` (1.6.0 : état reçu, jauge du HUD, visibilité,
  demandes retenues, aucune boucle).
- En jeu : [docs/tests/combat.md](../../docs/tests/combat.md) § 2 (armes), § 3 (techniques), § 4 (défense), § 7
  (chiffres des coups), § 8 (mannequins) et § 9 (endurance).

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
  (aucun contrôle) ; cap lu par le serveur pendant un virage rapide ; boutons de la souris partagés avec la magie et
  frappe refusée gelé ou renversé par un sort (T-149). Procédure : [docs/tests/combat.md](../../docs/tests/combat.md)
  § 3 à § 6.
- Défense (1.3.0) : gestes provisoires de garde, de parade et de roulade (`anim@melee@machete@streamed_core@`,
  `move_strafe@roll`) présents et vus des autres (garde en boucle synchronisée) ; R et Espace en AZERTY ; une touche
  liée (Espace, R) répond-elle encore quand le saut (22) et recharger (45) sont coupés ; parade au dernier moment à
  150 ms de ping ; sprint coupé garde levée.
- Chiffres des coups (1.4.0) : chez l'attaquant et la cible seulement, jamais chez un témoin ; « Esquivé » et
  « Absorbé » chez les deux seuls participants ; taille de `vava_combat:hit` par `/vava_reseau` ([docs/tests/combat.md](../../docs/tests/combat.md) § 7).
- Mannequins (1.5.0) : modèles provisoires présents (`prop_beach_punchbag`, `prop_haybale_03`) et posés au sol à leur
  place ; effet `core` / `ent_dst_wood_splinter` présent ; sens du balancement (il doit s'écarter de l'attaquant : signe
  de l'inclinaison selon l'ordre de rotation 2) ; chiffre à 1,9 m au-dessus du pied ; resmon près d'une cour ; un
  mannequin à 60-70 m ne clignote pas ([docs/tests/combat.md](../../docs/tests/combat.md) § 8).
- Endurance (1.6.0) : médaillon à la droite des autres sans en décaler aucun, icône lisible à 720p et en 4K, ambre et
  rouge lisibles sur le cuir ; remontée d'un seul mouvement régulier (transition CSS dans CEF) ; à 150 ms de ping, un
  coup refusé alors que l'anneau montrait assez reste rare et se recale aussitôt ; `/vava_reseau` : aucun
  `vava_combat:stamina` au repos ni chez un témoin ([docs/tests/combat.md](../../docs/tests/combat.md) § 9).
