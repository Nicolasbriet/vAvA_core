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

**Tous** les dégâts du jeu passent par une seule fonction serveur, dans `vava_health` (qui possède la vie) :

```lua
exports.vava_health:hit(target, {
    amount = 12,              -- points avant modificateurs
    kind = 'tranchant',       -- tranchant | contondant | perçant | feu | eau | terre | pur
    source = attackerSrc,     -- joueur à l'origine, ou nil
    origin = 'vava_combat',   -- module à l'origine
    technique = 'taille_descendante',
    tags = { melee = true },  -- pour les conditions (« frappé au corps à corps »)
})
-- → { applied = 9, blocked = 3, absorbed = 0, downed = false } ou nil, err
```

Ordre fixe, chaque étape est un **modificateur** enregistré par un module (registre
`vava_health:modifiers`, priorité numérique) :

1. annulation (cible à terre, immunité, zone sûre) ;
2. esquive en cours (fenêtre d'invulnérabilité) ;
3. parade réussie (dégâts annulés, l'attaquant chancelle) ;
4. blocage (réduction selon bouclier ou arme, coût d'endurance pour le défenseur) ;
5. boucliers magiques (absorption, `vava_magic`) ;
6. résistances (élément, armure de `vava_equipment` plus tard) ;
7. application à la vie, hooks `vava_health:hit` (after) pour les effets « quand le porteur est touché ».

La magie est migrée sur cette chaîne (T-116) : un bouclier de l'Égide de givre protège alors aussi d'un coup
d'épée. Les dégâts natifs de GTA entre joueurs sont annulés côté serveur (évènement de dégâts d'arme du moteur),
pour qu'aucun coup ne passe hors de la chaîne.

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

Enchaînement : une technique listée dans `chain` peut démarrer pendant la `recovery` de la précédente.

## 4. Défense (T-113)

- **Blocage** (maintenir) : réduit les dégâts de face (angle en config), plus fort avec un bouclier ; chaque coup
  bloqué coûte de l'endurance ; à 0, la garde est brisée (chancelant).
- **Parade** (appui bref) : ouvre une fenêtre courte (≈ 200 ms en config). Un coup `parryable` qui tombe dedans est
  annulé et l'attaquant chancelle. Délai de récupération après une parade ratée, pour empêcher le spam.
- **Esquive** : pas de côté ou roulade, courte invulnérabilité (≈ 250 ms), coût d'endurance, délai.
- Toutes ces fenêtres sont tenues **par le serveur** ; le client ne fait que demander.

## 5. Endurance (T-114)

Jauge serveur de 0 à 100, affichée dans le HUD ; se recharge après un délai sans effort ; consommée par les coups,
le blocage, l'esquive, et la course plus tard si on le souhaite. Faim et soif basses ralentissent la recharge
(`vava_needs`).

## 6. Styles et progression (T-115)

Un style = une catégorie d'arme + une liste de techniques attribuées aux touches (légère, lourde, défense,
esquive). Compétences de combat dans `vava_skills` (armes à une main, à deux mains, dagues, bâton, bouclier) ; les
techniques avancées se débloquent par rang ; XP donnée au serveur pour les coups portés **sur une vraie cible**
(pas sur un mannequin au-delà d'un niveau, pour éviter le farm), bonus de mentorat avec un maître d'armes.

## Hors v1

Arcs et arbalètes (réutiliseront les projectiles de la magie), combat à cheval, créatures hostiles, armes de jet,
désarmement.

## Tests

- Unitaires : ordre de la chaîne de dégâts, géométrie de l'arc (portée, angle, tolérance), endurance, fenêtres de
  parade et d'esquive (logique pure dans `shared/`).
- En jeu, **à plusieurs** : sensations à 30, 80 et 150 ms de ping ; spam des touches ; coups à travers un mur ;
  parade au dernier moment ; déconnexion en plein échange de coups ; resmon pendant un combat à 6.

## Réglages de départ (config, à ajuster en jeu)

Tolérance de portée + 0,4 m, tolérance d'angle + 15°, fenêtre de parade 200 ms, invulnérabilité d'esquive 250 ms,
recharge de l'endurance 20 / s après 1 s sans effort, garde brisée 1,2 s.
