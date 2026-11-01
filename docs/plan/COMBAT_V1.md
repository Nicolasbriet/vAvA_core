# Combat v1 — référence de conception

Référence des agents pour la phase 4. Maquette de l'éditeur de techniques : `docs/maquettes/Combat.html`.

## Principe

Un combat **maison** : le corps à corps natif de GTA est coupé, `vava_combat` joue ses propres techniques, le
**serveur** décide si un coup touche et combien il fait. Les techniques sont des **données** au format que l'Atelier
éditera plus tard (T-121) : en v1 elles sont écrites en config, et l'éditeur ne fera que remplacer la config.

Ordre de construction, à ne pas inverser : chaîne de dégâts commune → moteur de techniques avec 4 techniques en
config → défense et endurance → test à plusieurs et réglages → éditeur dans l'Atelier.

## Ce qui existe déjà et doit être réutilisé

- `vava_health` : la vie, la mise à terre, la réanimation, les exports `damage` / `heal`.
- `vava_magic` : verrouillage de cible (`client/targeting.lua`), états chancelant / renversé / ralenti / gelé et
  immunité aux contrôles enchaînés (`server/states.lua`), décisions serveur.
- `vava_inventory` : objet en main (`hands`), métadonnées (qualité, solidité, créateur).
- `vava_crafting` : qualité de forge, solidité, réparation.
- `vava_skills` : compétences et rangs, pour débloquer les techniques et donner l'XP de combat.

## 1. La chaîne de dégâts commune (T-110)

**Tous** les dégâts du jeu passent par une seule fonction serveur, dans `vava_health` (qui possède la vie, tenue par le
serveur) :

```lua
exports.vava_health:hit(target, {
    amount = 12,              -- points avant modificateurs (100 = une vie pleine)
    kind = 'tranchant',       -- tranchant | contondant | percant | feu | eau | terre | lumiere | esprit | pur |
                              --   privation | monde (identifiants ASCII : « percant » sans cédille)
    source = attackerSrc,     -- joueur à l'origine, ou nil
    technique = 'taille_descendante',
    tags = { melee = true },  -- pour les conditions (« frappé au corps à corps »)
})
-- → { id, amount = 9, applied = 9, blocked = 3, absorbed = 0, resisted = 0, added = 0, downed = false, health = … }
--   ou nil, err
```

Le module à l'origine n'est pas dans le paquet : `vava_health` pose lui-même `origin` (la ressource qui appelle
l'export), pour qu'aucun module ne signe au nom d'un autre. Paquet complet, codes et contrat des modificateurs :
`docs/api.md`, § `vava_health` ; spécification : `docs/plan/specs/T-110.md`.

Ordre fixe, chaque étape est remplie par des **modificateurs** enregistrés par les modules (registre
`vava_health:modifiers`, une étape fixe et une priorité de 0 à 99 dans l'étape ; au plus un modificateur par étape et
par module) :

1. annulation (`annulation` : immunité, zone sûre ; la cible déjà à terre est écartée avant la chaîne) ;
2. esquive en cours (`esquive` : fenêtre d'invulnérabilité) ;
3. parade réussie (`parade` : dégâts annulés, l'attaquant chancelle) ;
4. blocage (`blocage` : réduction selon bouclier ou arme, coût d'endurance pour le défenseur) ;
5. boucliers magiques (`bouclier` : absorption, `vava_magic`) ;
6. résistances (`resistance` : élément, armure de `vava_equipment` plus tard ; faiblesse possible) ;
7. application à la vie, hooks `vava_health:hit` (after) pour les effets « quand le porteur est touché ».

Un modificateur **rend un résultat** (`cancel`, `blocked`, `absorbed`, `resisted`, `added`) borné par la chaîne ; il
ne modifie rien lui-même. Un hook `vava_health:hit` `before` permet de refuser un coup (trêve, prison).

La magie est migrée sur cette chaîne (T-116) : un bouclier de l'Égide de givre protège alors aussi d'un coup
d'épée. Les dégâts natifs de GTA entre joueurs sont annulés côté serveur (évènement de dégâts d'arme du moteur, plus
explosions, feux et projectiles lancés par un joueur), pour qu'aucun coup ne passe hors de la chaîne ; chute, noyade
et feu du décor restent natifs, lus par le serveur et passés au hook `after` comme pertes du « monde ».

## 2. Armes (T-111)

- Une arme est un **objet d'inventaire signé** (qualité, solidité, créateur) tenu en main. Correspondance objet →
  modèle d'arme vanilla en config, marquée `-- PLACEHOLDER` : épée → machette, hache → hachette, masse → marteau ou
  batte, dague → couteau, bâton → queue de billard ou batte. Bouclier : accessoire accroché à l'avant-bras.
- Contrôles natifs du corps à corps, armes à feu et roue des armes coupés pendant le jeu.
- Catégories d'armes (`une_main`, `deux_mains`, `dague`, `baton`, `bouclier`) qui déterminent les styles possibles.
- Dégâts de base par catégorie × multiplicateur de qualité de forge (config) ; chaque coup porté use l'arme ; une
  arme à 0 de solidité inflige des dégâts réduits et doit être réparée.

## 3. Une technique (T-112)

Format de données (identique en config v1 et dans l'Atelier ensuite) :

```lua
taille_descendante = {
    label = 'Taille descendante',
    style = 'epee_une_main',
    type = 'legere',                  -- legere | lourde | parade | blocage | esquive | garde
    gesture = { dict = 'vava_sword_1h', clip = 'attack', flag = 0 },   -- PLACEHOLDER tant que l'animation est provisoire
    phases = { windup = 320, active = 160, recovery = 420 },           -- ms
    hit = { range = 2.2, angle = 70 },                                 -- m, degrés
    damage = 1.0,                     -- multiplicateur des dégâts de l'arme
    stamina = 12,
    parryable = true, staggers = false, chain = { 'estoc_rapide' },
    learn = { skill = 'armes_une_main', level = 20 },
}
```

`hit.angle` est l'**ouverture totale** de l'arc, centrée sur l'avant ; la tolérance d'angle s'ajoute au **demi-angle**
(70° et + 10° : 45° de chaque côté) (T-112).

**Champs selon le type** (T-113) : même table, mêmes noms ; pour `blocage`, `parade` et `esquive`, `phases.windup` admet
0, `damage`, `parryable`, `staggers` et `hit.range` sont refusés, `hit.angle` est l'arc protégé (une esquive n'a pas de
`hit`), `stamina` le coût d'un coup bloqué, d'une parade ou d'un pas ; `active` est la tenue minimale de la garde, la
fenêtre de parade ou l'invulnérabilité. `garde` (posture) est contrôlé comme une attaque et refusé à l'usage.

Déroulement d'un coup :
1. Le joueur appuie : le client **joue tout de suite** l'animation (réactivité) et appelle le RPC
   `vava_combat:use` (id de technique, cible verrouillée éventuelle).
2. Le serveur vérifie : technique connue du style de l'arme en main, compétence suffisante, endurance, délai depuis
   le dernier coup, état (pas à terre, pas ligoté, pas gelé). Refus → le client interrompt l'animation.
3. Le serveur programme la **fenêtre de frappe** (`windup` plus tard, durée `active`). À l'ouverture, il lit les
   **positions serveur** de l'attaquant et des joueurs proches, garde ceux qui sont dans la portée et l'angle
   (tolérance de portée et d'angle en config pour la latence, bornée), puis appelle la chaîne de dégâts.
4. Le résultat part à l'attaquant, à la cible et aux joueurs proches qui doivent voir la réaction (chancellement) :
   **jamais à tout le serveur**. L'animation elle-même est synchronisée par le moteur, rien d'autre à envoyer.
   Le montant du coup (chiffres des coups, T-155) ne part qu'à l'attaquant et à la cible, jamais aux témoins.

Enchaînement : une technique listée dans `chain` peut démarrer pendant la `recovery` de la précédente.

## 4. Défense (T-113)

- **Blocage** (maintenir) : réduit les dégâts de face (angle en config), plus fort avec un bouclier ; chaque coup
  bloqué coûte de l'endurance ; à 0, la garde est brisée (chancelant).
- **Parade** (appui bref) : ouvre une fenêtre courte (≈ 200 ms en config). Un coup `parryable` qui tombe dedans est
  annulé et l'attaquant chancelle. Délai de récupération après une parade ratée, pour empêcher le spam.
- **Esquive** : pas de côté ou roulade, courte invulnérabilité (≈ 250 ms), coût d'endurance, délai.
- Toutes ces fenêtres sont tenues **par le serveur** ; le client ne fait que demander.

Décisions de T-113 (`vava_combat` 1.3.0, spec `docs/plan/specs/T-113.md`, recommandations retenues le 31 octobre 2026) :
- **Touches** : R (appui bref : parade ; maintenu : garde, levée à la fin de la fenêtre de parade), Espace (pas de côté,
  mode combat actif seulement : le saut y est coupé ; arme en main seulement en v1).
- **Fenêtres** posées à l'acceptation de la demande (`vava_combat:use`), sans minuterie ; garde abaissée par
  `vava_combat:lower` (tenue minimale 200 ms, puis 250 ms avant de frapper ; pas de riposte directe depuis la garde).
  Aucune compensation de latence (parade sans préparation).
- **Ce qu'on évite, pare, bloque** : pas de côté contre `melee` et `ranged` (projectiles de sorts compris), jamais
  `area`, `overTime`, `undodgeable`, `native`, `reflected` ; parade et garde : corps à corps seulement, de face (arc 120°,
  160° bouclier au bras). Le coup non parable (Fendant) se bloque ou s'esquive.
- **Parade réussie** : coup annulé, attaquant chancelant 0,9 s même pendant son immunité, qu'elle renouvelle ; parade
  ratée : 600 ms sans parade après la fin de sa fenêtre.
- **Blocage** : part arrêtée de l'arme tenue ou du bouclier au bras (fiche `block`), montré « bloqué » même partiel, le
  Fendant bloqué ne fait pas chanceler. **Garde brisée** : chancellement 1,2 s, ni garde ni parade ; depuis T-114,
  quand un coup bloqué coûte au moins ce qui reste d'endurance (le compteur provisoire de T-113 est retiré : mêmes
  seuils depuis une jauge pleine, 4 coups bloqués, 6 au bouclier, un lourd compte 2).
- **Usure** : l'arme qui pare, le bouclier (sinon l'arme) qui bloque ; rien sur une esquive.
- **Issues** dans `vava_combat:hit` : `parry`, `block`, `break` (à la place de `hit`) ; `dodge` et `absorb` tues.

## 5. Endurance (T-114)

Jauge serveur de 0 à 100, affichée dans le HUD ; se recharge après un délai sans effort ; consommée par les coups,
le blocage, l'esquive, et la course plus tard si on le souhaite. Faim et soif basses ralentissent la recharge
(`vava_needs`).

Décisions de T-114 (`vava_combat` 1.6.0, `vava_hud` 1.8.0, spec `docs/plan/specs/T-114.md`, recommandations retenues le
2 novembre 2026) :
- **Où vit la jauge** : en mémoire du serveur, par personnage en jeu, jamais sauvegardée (pleine à l'arrivée et au
  relevé) ; **aucune minuterie** : valeur, reprise de la recharge et pente, le niveau se calcule à la lecture (comme la
  mana).
- **Dépenses** à l'acceptation du geste, manqué ou non, mannequin compris : Taille 12, Estoc 9, Revers 11, Fendant 25,
  Parade 6, Pas de côté 20 ; **coup bloqué** : 25 (lourd × 2, bouclier × 0,67) ; tenir la garde ne coûte rien et
  n'arrête pas la recharge, mais il faut 25 pour la lever. Rien pour courir (hors T-114), incanter, être frappé.
- **Seuil** : coût entier exigé (refus « Vous êtes à bout de souffle. ») ; un coup bloqué qui coûte au moins ce qui reste
  brise la garde.
- **Recharge** 20 / s après 1 s sans dépense ; faim ou soif à 30 ou moins × 0,75, à 10 ou moins × 0,5 (le besoin le
  plus bas, relu au plus toutes les 30 s, à un geste).
- **Réseau** : l'état de sa seule jauge dans la réponse de `vava_combat:use` et un évènement court
  `vava_combat:stamina` (coup bloqué, chute) ; rien au repos, rien à un autre joueur ; la page de `vava_hud` anime la
  remontée.
- **HUD** : médaillon « Endurance » en dernier, montré en mode combat éveillé ou tant qu'il n'est pas plein (puis 3 s) ;
  ambre sous 25 %, rouge sous 10 %.
- Magie : aucun lien (les sorts ne coûtent pas d'endurance). Délais de la parade ratée et du pas de côté gardés (à revoir
  à T-119). `/armes voir` montre la jauge ; aucune commande ne la change.

## 6. Styles et progression (T-115)

Un style = une catégorie d'arme + une liste de techniques attribuées aux touches (légère, lourde, défense,
esquive). Compétences de combat dans `vava_skills` (armes à une main, à deux mains, dagues, bâton, bouclier) ; les
techniques avancées se débloquent par rang ; XP donnée au serveur pour les coups portés **sur une vraie cible**
(pas sur un mannequin au-delà d'un niveau, pour éviter le farm), bonus de mentorat avec un maître d'armes. Mannequin
d'entraînement (T-156, `vava_combat` 1.5.0) : aucune XP en T-156 ; le hook `vava_combat:trained` sert à T-115, qui n'en
donnera plus à partir du niveau `dummies.xpMaxLevel` (9) de la compétence de l'arme — la Parade (niveau 10) se gagne
face à quelqu'un.

## Hors v1

Arcs et arbalètes (réutiliseront les projectiles de la magie), combat à cheval, créatures hostiles, armes de jet,
désarmement.

## Tests

- Unitaires : ordre de la chaîne de dégâts, géométrie de l'arc (portée, angle, tolérance), endurance, fenêtres de
  parade et d'esquive (logique pure dans `shared/`).
- En jeu, **à plusieurs** : sensations à 30, 80 et 150 ms de ping ; spam des touches ; coups à travers un mur ;
  parade au dernier moment ; déconnexion en plein échange de coups ; resmon pendant un combat à 6.

## Réglages de départ (config, à ajuster en jeu)

Tolérance de portée + 0,25 m, tolérance d'angle + 10° (resserrées, sans contrôle des murs : décision du porteur du
projet, 31 octobre 2026, T-112), dégainer 0,8 s et rengainer 1,5 s, fenêtre de parade 200 ms, invulnérabilité d'esquive
250 ms, recharge de l'endurance 20 / s après 1 s sans effort, garde brisée 1,2 s ; coûts d'endurance (T-114) : Taille
12, Estoc 9, Revers 11, Fendant 25, Garde 25 par coup léger bloqué, Parade 6, Pas de côté 20.
