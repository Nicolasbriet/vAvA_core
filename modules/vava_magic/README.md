# vava_magic — la magie du royaume

Système de magie pour vAvA_core : fiche magie par personnage, mana, progression sur 5 niveaux, incantation commune et
trois sorts (**Murmure**, **Lueur**, **Boule de feu**), grimoire et registre des murmures (objets), commandes du
Conseil. Le serveur décide de tout ; le client affiche et demande.

## Installation

1. Placer le dossier dans `resources/[vava]/vava_magic` (avec la Chancellerie : il est installé avec vAvA).
2. Dans le `server.cfg`, l'ajouter **après** `vava_inventory`, `vava_hud`, `vava_health` et `vava_admin`, avant
   `vava_chancellerie` :

   ```cfg
   ensure vava_magic
   ```

3. Démarrer le serveur. Les tables sont créées par le core (migration `sql/0001_magic.sql`, jamais rejouée) : rien à
   importer à la main. La fiche magie vit dans le champ `vava_magic:sheet` du personnage, sauvegardé par le core.
4. Faire un premier mage depuis le jeu (membre du Conseil) ou la console du serveur :

   ```
   magie mage 1 oui
   magie apprendre 1 murmure
   magie donner 1 grimoire
   magie donner 1 registre
   ```

| Dépendance | Rôle | Sans elle |
| --- | --- | --- |
| `vAvA_core` ≥ 0.5.0 | personnages, RPC, hooks, base, journal | obligatoire |
| `vava_inventory` ≥ 1.3.0 | grimoire et registre (objets, métadonnées) | pas d'objets ; `/grimoire` reste |
| `vava_hud` | médaillon de mana, notifications | notifications de GTA, pas de médaillon |
| `vava_health` | blessures, état « à terre » | la victime applique la blessure elle-même |
| `vava_admin` | droits et journal du Conseil | permission ACE `magie.admin`, journal en console |
| `chat` | commandes et suggestions | touches seulement |

## Arborescence

```
vava_magic/
  fxmanifest.lua · config.lua · README.md
  shared/   constants.lua · text.lua (UTF-8) · progression.lua · geometry.lua
  bridge/   server.lua · client.lua                 ← seul contact avec le core et les autres modules
  server/   core · world · sheets · mana · spells · progression · combat · registers · sigils · casting
            admin · api · main · spells/murmure · spells/lueur · spells/boule_de_feu
  client/   core · nui · state · messages · mana · keys · aim · casting · ambient · sigils · grimoire
            register · main · spells/murmure · spells/lueur · spells/boule_de_feu
  web/      index.html · css/ · js/ · fonts/ (OFL) · img/ (runes, mana, textures) · items/ (grimoire, registre)
  sql/      0001_magic.sql
```

## Adapter le bridge à un autre core

`bridge/server.lua` et `bridge/client.lua` sont les seuls fichiers qui appellent le core et les autres modules
(inventaire, HUD, santé, Conseil). Pour un autre core, réécrire ces fonctions ; le reste du module ne connaît qu'elles.
Le noyau utilise en plus l'infrastructure du core (`core.rpc` à schéma strict et à débit limité, `core.hooks`,
`core.registry`, `core.log`, `core.modules`) : un autre core doit fournir l'équivalent (surtout la validation des RPC).

| Fonction serveur | Implémentation vAvA |
| --- | --- |
| `GetCharacterId(source)` | `core.players.get(source).characterId` (personnage en jeu) |
| `GetCharacterName(source)` | `core.characters.getActive(source)` |
| `ActivePlayers()` | joueurs dont le personnage est en jeu |
| `IsAdmin(source)` | `vava_admin:can(source, config.admin.permission)` ; sans vava_admin : ACE `magie.admin` ; console : oui |
| `AdminLog(source, libellé, détails)` | `vava_admin:log` (journal du Registre et de la Chancellerie) |
| `Notify(source, message, nature)` | évènement vers le client → `vava_hud:notify` |
| `HasItem` · `AddItem` · `RemoveItem` | `vava_inventory:count` · `add` · `remove` |
| `GetItemMetadata(source, objet)` · `SetItemMetadata(source, id, méta)` | `vava_inventory:getItems` · `setMetadata` (1.3.0) |
| `RegisterUsableItem(objet, définition, rappel)` | objet du registre `vava_inventory:items`, avec `onUse` |
| `DefineSheet` · `LoadSheet` · `SaveSheet` | champ de personnage privé `vava_magic:sheet` |
| `db.*` | `core.db` (requêtes paramétrées des tables du module) |
| `ApplyDamage(cible, part)` · `IsDowned(source)` | `vava_health:damage` · `isDowned` ; sinon l'évènement `vava_magic:damage` |

| Fonction client | Implémentation vAvA |
| --- | --- |
| `Notify(message, nature)` | `vava_hud:notify`, sinon notification de GTA |
| `IsDowned()` | `vava_health:get().downed` |
| `GaugeSet` · `GaugeActive` · `GaugeHide` | médaillon de mana de `vava_hud` |
| `ChatLines` · `ChatSuggestion` | `chat:addMessage` · `chat:addSuggestion` |

## Commandes et touches du joueur

Les touches se règlent dans **Paramètres > Raccourcis > FiveM** (même place en AZERTY et en QWERTY).

| Touche | Commande | Action |
| --- | --- | --- |
| N | `/murmure` | ouvrir le parchemin d'écriture ; `/murmure 1,3 Rendez-vous au moulin` envoie directement |
| L | `/lueur` | allumer, ou éteindre sa lumière |
| J | `/lueur ancrer` | ancrer un orbe là où l'on regarde (niveau 4) |
| K | `/bouledefeu` | lancer une boule de feu : sur la cible verrouillée, sinon vers la caméra |
| Tab | — | appui court : verrouiller le joueur visé (sorts d'attaque), à nouveau : cible suivante ; maintenu : relâcher |
| X | — | interrompre l'incantation |
| — | `/lueur couleur <nom>` · `eteindre` · `dissiper` | couleur (niveau 5), éteindre, dissiper ses orbes ancrés |
| — | `/grimoire` | ouvrir le grimoire (secours ; l'objet l'ouvre aussi) |
| — | `/sigils` | lister les sigils gardés |
| — | `/sigil offrir` | tendre son sigil au plus proche (3 m) |
| — | `/sigil renommer <n°> <nom>` · `oublier <n°>` | gérer ses contacts |
| — | `/sigil brouiller` | nouveau sigil (confirmation, 60 de mana, 6 h de recharge) |

Le registre s'ouvre en l'utilisant dans l'inventaire.

### Verrouiller une cible (sorts d'attaque)

Un sort d'attaque (`lockOn = true` dans sa config : la Boule de feu) peut viser un joueur verrouillé :

- **Tab** verrouille le joueur le plus proche du centre de l'écran, à portée du sort et en vue ; un anneau rouge
  tourne sous lui, vu du seul lanceur. Un nouvel appui passe à la cible suivante, Tab maintenu relâche.
- Le verrou saute si la cible sort de portée, de vue (une seconde), meurt, ou après 20 s sans attaque.
- La cible part avec le début de l'incantation. Le serveur la revérifie (joueur en jeu, à portée, hors zone
  protégée) et **prévient la cible seule** : le bord de son écran rougit (« Un frisson vous parcourt… »), elle a la
  durée de l'incantation pour réagir.
- À la fin, le serveur calcule lui-même la direction vers la cible (le client n'y est pour rien). Niveaux 1 à 3 :
  la boule part droit vers elle, on peut encore l'esquiver. Niveaux 4 et 5 : elle s'incurve vers elle pendant son vol
  (35 puis 70 degrés par seconde, `levels[].homing`). Cible échappée pendant l'incantation : la visée libre reprend.
- Tant qu'on ne lance pas, rien ne passe par le réseau. Pendant l'appui sur Tab, la roue d'armes de GTA est bloquée.

## Commandes du Conseil

Droit `tools` de vava_admin (Sénéchal et Souverain), réglable (`config.admin.permission`) ; aussi depuis la console du
serveur. Chaque commande est inscrite au journal du Registre du Conseil.

| Commande | Effet |
| --- | --- |
| `/magie mage <id> <oui\|non>` | rendre mage, ou retirer la magie |
| `/magie apprendre <id> <sort>` · `oublier <id> <sort>` | apprendre ou retirer un sort |
| `/magie niveau <id> <sort> <1-5>` · `xp <id> <sort> <xp>` | fixer le niveau ou l'XP (le sort est appris s'il ne l'était pas) |
| `/magie mana <id>` | remplir la mana |
| `/magie fiche <id>` | mage, sorts, niveaux, XP, sigils, mana |
| `/magie donner <id> <grimoire\|registre>` | donner un objet (un registre neuf, numéroté) |

`<id>` est le numéro du joueur en jeu ; `<sort>` : `murmure`, `lueur`, `boule_de_feu`.

## Configuration (`config.lua`)

| Section | Contenu |
| --- | --- |
| `mana` | maximum (100), régénération (3 points / 5 s), médaillon (paliers, temps d'affichage après un sort) |
| `progression` | seuils d'XP (0, 100, 300, 700, 1500), coût selon le niveau, part d'XP d'un échec, anti-farm (20 s) |
| `casting` | mètre de tolérance, marges du serveur, délai d'abandon d'une incantation sans fin |
| `persistence` | écriture de la fiche dans le personnage (au plus toutes les 15 s, et au départ) |
| `spells.<sort>` | label, résumé, coût de base, XP, animation, texte d'ambiance, touche, et **5 niveaux** : durée d'incantation, recharge, description, ce que le niveau débloque, valeurs propres au sort |
| `spells.lueur.anchor` · `colors` · `render` | orbe ancré, couleurs du niveau 5, rendu (os, décalages, flottement, scintillement) |
| `spells.boule_de_feu.hit` · `fx` · `light` | contrôles de l'impact, particules, lumière |
| `targeting` | verrouillage des sorts d'attaque : cône, appui long, délais, marge, frisson, anneau |
| `combat` | dégâts entre joueurs, zones protégées (`{ label, x, y, radius }`), journal des dégâts |
| `sigils` | longueur, nombre gardé sans Murmure, nom, échange (3 m, 30 s), brouillage |
| `registers` | pages par registre (200) |
| `items` | grimoire et registre (taille, poids, image) |
| `ambient` | effets vus des autres (15 m, fragments à 3 m, runes, textes) |
| `admin` · `keys` · `commands` · `rateLimits` | droits, touches, commandes, limites de débit |
| `texts` | **tous** les textes vus par les joueurs (refus, messages, chat, journal, interface) |

## Ajouter un sort

1. `server/spells/<nom>.lua` : `VavaMagic.spells.register('<nom>', { config, beginArgs, finishArgs, begin, finish })`.
   `begin(ctx, …)` valide et prépare (`true, données[, coût]` ou `false, code`) ; `finish(ctx, …)` produit l'effet et
   rend `{ success, refund?, result? }`. Intentions propres : `spells.addRpc` ; ménage : `spells.onLeave`, `onStop`.
2. `client/spells/<nom>.lua` : `VavaMagic.casting.start('<nom>', { args, finishArgs, onFinish })` et sa touche
   (`VavaMagic.keys.bind`).
3. `config.lua` : `spells.<nom>` (mêmes champs communs) ; les lister dans le `fxmanifest.lua`.

Un autre module peut aussi ajouter un sort par le registre du core `vava_magic:spells` (voir `docs/api.md`).

## Sécurité et coût

- Le serveur vérifie à chaque incantation : mage, sort connu, niveau, recharge (tenue par personnage, la reconnexion ne
  l'efface pas), mana, une seule incantation, pas à terre ni en véhicule, puis à la fin : durée écoulée, déplacement
  et vie lus côté serveur. Interrompue : rien n'est consommé.
- Boule de feu : un seul impact par lancer, point d'impact dans la portée et dans l'axe annoncé, délai cohérent avec la
  vitesse, cible réelle près du point (position serveur), zones protégées ; les dégâts ne partent qu'ensuite. Le
  serveur ne voit pas les murs : un tricheur ne peut que toucher une cible réellement devant lui, à portée.
- Fragments du Murmure : envoyés par le serveur aux seuls joueurs à moins de 3 m ; jamais dans un state bag.
- Un client peut écrire dans le state bag de son propre ped : au pire un effet cosmétique, sans aucune incidence.

| Fonction | Réseau |
| --- | --- |
| Mana | ~60 o au seul lanceur, à chaque changement ; aucun envoi périodique |
| Incantation | 2 RPC, plus un state bag du ped (~80 o) reçu des joueurs proches |
| Murmure | < 1 Ko par destinataire ; fragments aux seuls joueurs à moins de 3 m |
| Lueur | ~100 o à l'allumage et à l'extinction ; un objet réseau par orbe ancré |
| Boule de feu | ~150 o de lancer aux joueurs proches (150 m), un impact, les dégâts |

Serveur : aucune boucle permanente (mana calculée à la demande ; écritures groupées toutes les 10 à 15 s). Client : une
recherche des effets proches toutes les 250 ms ; le dessin par image ne tourne que si une lumière, un texte ou un
projectile est à portée, ou pendant l'incantation d'un sort qui permet de marcher.

## À vérifier en jeu (noms tirés de GTA V)

| Usage | Animation ou particule | Réglage |
| --- | --- | --- |
| Murmure : tracer des runes | `anim@mp_player_intupperair_synth` / `idle_a` | `spells.murmure.anim` |
| Lueur : incantation | `amb@world_human_stand_fire@male@base` / `base` | `spells.lueur.anim` |
| Boule de feu : charge | `anim@mp_player_intupperknuckle_crunch` / `idle_a` | `spells.boule_de_feu.anim` |
| Boule de feu : jet | `weapons@projectile@grenade_str` / `throw_m_fb_stand` | `spells.boule_de_feu.throwAnim` |
| Traînée, brûlure | `core` / `ent_amb_torch_fire` | `spells.boule_de_feu.fx` |
| Impact | `core` / `ent_sht_flame` | idem |
| Boule éteinte | `core` / `ent_sht_steam` | idem |
| Orbe | marqueur 28 (sphère) et `DrawLightWithRange` | `spells.lueur.render` |
| Touche du grimoire | `GetControlInstructionalButton` | — |

Les sons (carillon, souffle, impact, boule éteinte) sont fabriqués par l'interface (Web Audio) : à juger à l'oreille.

## Tests à faire en jeu

Deux joueurs (A et B) suffisent ; un troisième aide pour le cercle et la zone d'effet.

**Fiche, Conseil, grimoire**
- [ ] `/magie fiche <A>` : non mage, sigil présent ; `/magie mage <A> oui` → message « La magie s'éveille », médaillon de mana absent tant qu'elle est pleine.
- [ ] `/magie apprendre <A> murmure`, `lueur`, `boule_de_feu` ; `/magie donner <A> grimoire` puis l'utiliser : trois pages, niveau I, XP, touches N / L / K affichées.
- [ ] B (non mage) ouvre un grimoire : pages illisibles. Un joueur hors du Conseil tape `/magie` : refusé.
- [ ] Le journal du Registre du Conseil (et la Chancellerie) montre chaque commande.

**Incantation**
- [ ] A lance la Lueur : barre d'incantation, animation, texte « fait naître une lueur… » vu de B à moins de 15 m, puis la lumière.
- [ ] Interrompre par X, en marchant de plus d'un mètre, en se faisant frapper : barre brisée, mana inchangée.
- [ ] Relancer aussitôt : « pas encore prêt (n s) ». Deux sorts à la fois : impossible.
- [ ] Médaillon de mana : apparaît après un sort, remonte de 3 toutes les 5 s, disparaît une fois plein.
- [ ] Se déconnecter et revenir : sorts, XP et sigils gardés, mana pleine.

**Lueur**
- [ ] Niveaux 1-2 : lumière dans la main, qui vacille sans saccade ; s'éteint seule (1 min au niveau 1) ; même touche pour éteindre.
- [ ] `/magie niveau <A> lueur 3` : orbe près de l'épaule. Niveau 4 : J ancre un orbe là où l'on regarde (B le voit, sans objet visible) ; `/lueur dissiper`.
- [ ] Niveau 5 : couleur choisie dans le grimoire, appliquée à la lumière allumée.

**Sigils et Murmure**
- [ ] A et B face à face, `/sigil offrir` : B nomme A, coche « confier le mien », A nomme B. Sans réponse 30 s : offre close. Trop loin : refusé.
- [ ] À sens unique : B murmure à A qui ne le connaît pas → « Une présence inconnue ».
- [ ] A ouvre le parchemin (N) : contacts, compteur de signes, envoi. Pendant l'incantation : B à moins de 3 m lit des mots dorés au-dessus des mains de A ; à 5 m, seulement des runes.
- [ ] B reçoit le parchemin, entend le carillon ; un témoin voit « ses yeux s'illuminent ». Niveau 1 : certains mots arrivent en « … ».
- [ ] B déconnecté : « Le lien reste silencieux », part de mana rendue. Trop loin au niveau 1 (300 m) : « Le lien ne porte pas si loin ».
- [ ] Niveau 3 : position jointe → point de passage chez B. Niveau 4 : cercle de plusieurs contacts.
- [ ] Message avec accents et longueur maximale : tronqué proprement.
- [ ] `/sigils`, `/sigil renommer`, `/sigil oublier`, `/sigil brouiller` (B ne joint plus A par l'ancien sigil).

**Registre**
- [ ] Avec un registre sur soi, envoyer et recevoir : pages datées « À … » / « De … » ; sans registre : rien n'est consigné.
- [ ] Arracher une page. Donner le registre à B : B lit l'historique (il suit l'objet). Un registre neuf est vierge.

**Boule de feu**
- [ ] A lance vers B (à 10 m) : incantation en marchant lentement, jet, projectile et lumière vus de tous, impact en flammes, B blessé (vava_health). Pas d'explosion GTA.
- [ ] Hors de portée ou derrière soi : aucun dégât. Niveau 1 : la boule s'éteint parfois (vapeur, mana dépensée).
- [ ] Tab devant B : anneau rouge sous B (A seul le voit), pas de roue d'armes. Tab encore : cible suivante ; Tab maintenu : relâché. B derrière un mur : verrou perdu.
- [ ] A lance sur B verrouillé : B voit le bord de son écran rougir dès le début de l'incantation ; A se tourne vers B au jet ; la boule part sur B même si A regarde ailleurs.
- [ ] Niveau 1 à 3 : B esquive en se décalant. Niveau 4-5 (`/magie niveau <A> boule_de_feu 5`) : la boule s'incurve et le rattrape.
- [ ] Niveau 3 : un voisin de B est touché aussi (moins fort). Niveau 4 : B brûle quelques secondes.
- [ ] Zone protégée (`combat.protectedZones`) : impossible d'y lancer, personne n'y est blessé. `combat.pvp = false` : aucun dégât.
- [ ] Table `vava_magic_damage_log` : lanceur, cible, dégâts, position.

**Performance**
- [ ] `resmon` : `vava_magic` à ~0,00 ms au repos, quelques centièmes pendant une incantation ou une lumière proche.
