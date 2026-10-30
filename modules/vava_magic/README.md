# vava_magic — la magie du royaume

Système de magie pour vAvA_core : fiche magie par personnage, mana et sa barre, progression sur 5 niveaux,
incantation commune, **roue des sorts** (Tab) et **mode magie à la souris** (viser, lancer, verrouiller une cible),
**états élémentaires** (brûlure, mouillé, ralenti, chancelant, renversé, gelé, avec immunité aux contrôles durs),
**zones au sol**, **projectiles** et **obstacles**, sorts de feu (**Boule de feu**, **Mur de flammes**, **Nova
ardente**), d'eau (**Trait de glace**, **Vague**, **Brume**) et de terre (**Projectile de roche**, **Secousse**,
**Rempart**), **combinaisons entre éléments** (vapeur, boue, gel…) inscrites au grimoire quand on les découvre,
**Lueur** et **Murmure**, grimoire et registre des murmures (objets), commandes du Conseil. Le serveur décide de tout ;
le client affiche et demande.

Version 2.7.0 : les cinq étapes de la refonte (noyau, roue et contrôles ; états, zones et feu ; eau et terre ;
combinaisons ; finitions : traces au sol, sons par fichier ou natifs, documentation et tests), puis leurs correctifs ;
le registre des murmures s'envoie par lots (2.7.0).
Rien n'a encore été joué en vrai : voir « À vérifier en jeu », « Tests à faire en jeu » et la procédure complète
`docs/tests/magie.md`.

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
   magie tous 1          (le joueur 1 devient mage et apprend tous les sorts au niveau 1)
   magie donner 1 grimoire
   magie donner 1 registre
   ```

| Dépendance | Rôle | Sans elle |
| --- | --- | --- |
| `vAvA_core` ≥ 0.5.0 | personnages, RPC, hooks, base, journal | obligatoire |
| `vava_inventory` ≥ 1.3.0 | grimoire et registre (objets, métadonnées) | pas d'objets ; `/grimoire` reste |
| `vava_hud` | notifications | notifications de GTA (la barre de mana est celle du module) |
| `vava_health` | blessures, état « à terre » (aucun sort ne touche un joueur à terre) | la victime applique la blessure elle-même |
| `vava_admin` | droits et journal du Conseil ; ≥ 1.6.0 : la fin d'un Gel ne libère pas un joueur immobilisé par le Registre | permission ACE `magie.admin`, journal en console |
| `vava_chat` | réponses des commandes et suggestions (évènements `chat:*`, aussi ceux de la ressource « chat » de FiveM) | touches seulement |

## Arborescence

```
vava_magic/
  fxmanifest.lua · config.lua · README.md
  shared/   constants.lua · text.lua (UTF-8) · progression.lua · geometry.lua · pages.lua (lots du registre)
  bridge/   server.lua · client.lua                 ← seul contact avec le core et les autres modules
  server/   core · world · sheets · mana · spells · progression · combat · states (états) · obstacles (remparts…)
            zones (au sol) · grounds (sol mouillé) · combos (combinaisons) · projectiles (noyau commun) · registers
            sigils · casting · admin · api · main
            spells/murmure · lueur · boule_de_feu · mur_de_flammes · nova_ardente · trait_de_glace · vague · brume
            projectile_de_roche · secousse · rempart
  client/   core · nui · state · messages · fx (budget des effets) · hud (barre de mana) · keys · aim · targeting
            casting · controls (mode magie, aperçus) · wheel (roue) · states (états sur soi) · ambient
            zones (rendu, sol mouillé) · clouds (nuées : brume, vapeur) · bursts (effets instantanés)
            projectiles (vol et rendu communs) · combos (mot bref, effets, vapeur, boue) · sigils · grimoire
            register · main
            spells/… (mêmes noms que côté serveur)
  web/      index.html · css/ · js/ (dont wheel, hud, conditions, sound) · fonts/ (OFL) · sounds/ (.ogg facultatifs)
            img/ (runes, textures, spells/, elements/, states/) · items/ (grimoire, registre)
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
| `CanUseMagic()` | ni mort, ni à terre, ni menotté (`IsPedCuffed`), ni assommé |
| `GetLockedTarget()` | cible du verrouillage de ce module (clic molette), numéro serveur ou nil |
| `ApplyMagicDamage(part, lanceur, sort)` | sans vava_health : `ApplyDamageToPed` sur ordre du serveur |
| `ChatLines` · `ChatSuggestion` | `chat:addMessage` · `chat:addSuggestion` |

Les dégâts restent décidés et appliqués par le serveur (`ApplyDamage` → vava_health) : un tricheur ne peut pas ignorer
une blessure. `ApplyMagicDamage` n'est que le repli sans vava_health.

## Commandes et touches du joueur

Les touches et boutons se règlent dans **Paramètres > Raccourcis > FiveM** (même place en AZERTY et en QWERTY).

**La roue des sorts** : **Tab maintenu** ouvre la roue au centre de l'écran (la caméra se fige). Anneau intérieur :
les éléments dont on connaît un sort (Feu, Eau, Terre, Utilitaires) ; anneau extérieur : les sorts de l'élément
survolé, avec icône, niveau, coût en mana, et temps de recharge (sort grisé). Relâcher Tab sur un sort le prépare dans
les mains ; au centre, rien ne change ; sur la main ouverte, « Ranger la magie ». Le sort prêt est gardé par le
serveur et s'affiche près de la barre de mana.

**Le mode magie** : un sort prêt, mains vides, à pied, debout. Le clic gauche lance alors le sort au lieu de frapper.
Il s'endort après 20 s sans viser ni lancer (le clic gauche refrappe comme d'habitude) ; **le clic droit le réveille**.
Sortir une arme ou monter en véhicule le coupe, sans perdre le sort prêt.

| Touche ou bouton | Action |
| --- | --- |
| Tab (maintenu) | roue des sorts |
| Clic droit (maintenu) | viser : réticule aux couleurs de l'élément, grisé hors de portée ; allure un peu ralentie ; aperçu au sol du point visé |
| Clic gauche | lancer le sort prêt (projectiles — Boule de feu, Trait de glace, Projectile de roche : vers le réticule, ou droit devant sans viser ; Mur de flammes, Brume, Secousse, Rempart : au sol visé, rien sans viser ; Nova ardente : autour de soi ; Vague : devant soi, dans la direction du regard ; Lueur : allumer ou éteindre, ancrer un orbe en visant au niveau 4 ; Murmure : ouvrir le parchemin) |
| Clic molette | verrouiller le joueur visé (sorts d'attaque), à nouveau : cible suivante ; maintenu : relâcher |
| Molette | sort suivant ou précédent du même élément (mode magie) |
| X | interrompre l'incantation |

Commandes de secours (chat) :

| Commande | Action |
| --- | --- |
| `/sort <nom>` · `/sort aucun` | préparer un sort sans la roue, ou ranger la magie (un non-mage : « La magie ne vous a jamais répondu. ») |
| `/lancer [sort]` | lancer le sort prêt (ou celui nommé), sans visée ; mains vides, comme le mode magie (arme sortie : refusé). La cible verrouillée n'est transmise à un autre sort nommé que s'il la vise et l'atteint ; sinon il part droit devant (2.6.3) |
| `/murmure` · `/murmure 1,3 <message>` | ouvrir le parchemin, ou envoyer directement |
| `/lueur` · `ancrer` · `couleur <nom>` · `eteindre` · `dissiper` | Lueur : allumer, ancrer là où l'on regarde (niveau 4), couleur (niveau 5), éteindre, dissiper ses orbes |
| `/grimoire` | ouvrir le grimoire (l'objet l'ouvre aussi) |
| `/sigils` · `/sigil offrir` · `renommer <n°> <nom>` · `oublier <n°>` · `brouiller` | gérer ses sigils |

Le registre s'ouvre en l'utilisant dans l'inventaire.

### Registre des murmures

Un objet de l'inventaire : il ne porte que son numéro, l'historique est en base sous ce numéro et suit l'objet (volé ou
donné, il part avec ses pages). Avec un registre sur soi, chaque murmure envoyé (« À … ») ou reçu (« De … ») y est
consigné, jusqu'à 200 pages ; plein, plus rien n'y est écrit et le joueur est prévenu.

- **Ouvrir** (l'utiliser) : seules les pages les plus récentes arrivent, au plus 20 et au plus 7 500 octets estimés
  (`registers.pageSize`, `registers.pageBytes`), avec le nombre total de pages. Une seule page plus lourde que le lot
  part quand même seule : le lecteur avance toujours.
- **Feuilleter** : « tourner les pages plus anciennes », au bas de la liste, demande le lot suivant (RPC
  `vava_magic:registerPages`, curseur : la plus ancienne page reçue ; 5 demandes d'affilée, puis une par seconde). Le
  serveur revérifie **à chaque lot** que le joueur porte ce registre dans sa besace, comme pour arracher une page ;
  donné ou lâché entre-temps : « Vous n'avez pas ce registre sur vous. », rien n'est lu en base.
- Les lots reçus restent dans la page tant que le registre est ouvert (une page arrachée ne décale rien) ; refermé, il
  repart du premier lot. Une page consignée pendant la lecture n'apparaît qu'à la réouverture.
- **Arracher une page** : celui qui porte le registre ; la page disparaît de la base.

### Verrouiller une cible (sorts d'attaque)

Un sort d'attaque (`lockOn = true` dans sa config : les trois projectiles) peut viser un joueur verrouillé :

- **Clic molette** verrouille le joueur le plus proche du centre de l'écran, à portée du **sort prêt dans les mains**
  (un sort d'attaque : sinon, rien) et en vue ; un anneau rouge tourne sous lui, vu du seul lanceur. Un nouveau clic
  passe à la cible suivante, le clic maintenu relâche.
- Le verrou saute si la cible sort de portée du sort prêt (préparer un sort qui porte moins loin, ou qui ne verrouille
  pas, compte aussitôt), de vue (une seconde), meurt, ou après 20 s sans attaque. Le serveur juge la cible à la portée
  du sort lancé : les deux s'accordent.
- La cible part avec le début de l'incantation. Le serveur la revérifie (joueur en jeu, à portée, hors zone
  protégée) et, une fois l'incantation acceptée (mana, recharges, contrôles passés), **prévient la cible seule** : le
  bord de son écran rougit (« Un frisson vous parcourt… »), au plus une fois toutes les 3 s par lanceur
  (`targeting.warnIntervalMs`) : ni une incantation refusée, ni des débuts annulés en rafale ne la font frissonner.
- À la fin, le serveur calcule lui-même la direction vers la cible. Niveaux 1 à 3 : le projectile part droit vers
  elle, on peut encore l'esquiver. Niveaux 4 et 5 : la Boule de feu s'incurve vers elle pendant son vol (35 puis 70
  degrés par seconde, `levels[].homing`), le Trait de glace un peu (20 puis 40) ; le Projectile de roche, lent, jamais.
  Cible échappée pendant l'incantation : la visée reprend.
- Les sorts lisent la cible par `Bridge.GetLockedTarget()` : un autre système de verrouillage se branche là.

## États élémentaires

Posés et retirés par le serveur ; vus de tous les joueurs proches (flammes, gouttes, givre, poussière sur le
personnage) ; le joueur affecté voit leurs icônes et leurs secondes à droite de sa barre de mana.

| État | Effet |
| --- | --- |
| Brûlure | dégâts toutes les secondes ; bord de l'écran rougi |
| Mouillé | aucun effet direct (gouttes sur le personnage) ; sert aux combinaisons (étape 4) |
| Ralenti | allure réduite (jamais cumulé : le plus fort l'emporte), course interdite au-delà de la moitié |
| Chancelant | démarche titubante, caméra qui tangue, **impossible d'incanter** |
| Renversé | chute courte (ragdoll), impossible d'incanter |
| Gelé | immobilisé (le serveur seul fige le personnage et le libère ; à la fin, il reste figé s'il est immobilisé par le Registre du Conseil), course, saut, attaque et visée coupées, givre au bord de l'écran, impossible d'incanter |

**Règle d'équité** : dès qu'un contrôle dur (Chancelant, Renversé, Gelé) touche, la cible est protégée des autres
jusqu'à 6 s après sa fin (`states.hardImmunityMs`) : aucun enchaînement. Les dégâts s'appliquent toujours. Un contrôle
dur brise l'incantation en cours. « Renversé » plutôt qu'« À terre » : ce mot désigne déjà, chez vava_health, un
personnage hors de combat. Un joueur **à terre** n'est la cible d'aucun sort : ni dégâts (refusés par vava_health),
ni état, ni recul (Vague, sol mouillé, brume, boue l'ignorent). Le hook `vava_magic:stateApplying` permet à un autre
module de refuser un état.

Dans GTA, l'allure et la chute d'un personnage sont calculées par le jeu de son joueur : un tricheur pourrait ignorer
un Ralenti ou une chute. Le Gelé, lui, est imposé par le serveur seul (le client ne fige ni ne libère jamais le
personnage) ; l'impossibilité d'incanter est décidée par lui.

## Zones au sol

Le serveur tient chaque zone (forme, position, élément, fin) et vérifie toutes les 500 ms qui s'y trouve, ou l'a
traversée depuis la vérification précédente (un joueur qui court ne passe pas entre deux). Une zone n'est envoyée
qu'aux joueurs à moins de 150 m, y compris ceux qui s'en approchent après coup. Au plus 60 zones dans le royaume.

| Genre | Sort | Effet sur qui s'y tient | Rendu |
| --- | --- | --- | --- |
| `flames` | Mur de flammes | blessure et Brûlure, au plus une fois par seconde (jamais le lanceur) | flammes et lumières le long de la ligne |
| `mist` | Brume | Mouillé dès le niveau 3 ; on n'y voit plus guère | nappes de brume ; voile et flou à l'écran de qui s'y tient |
| `wet` | Vague, Brume (à sa fin) | Mouillé, reposé au plus toutes les 4 s (lanceur compris) | reflet d'eau au sol, gouttes à la naissance |
| `quake` | Secousse | aucun pendant le présage ; au terme, choc (voir plus bas) | anneau aux couleurs de la terre qui se remplit, poussière, craquement |
| `steam` | combinaison Vapeur | légère brûlure chaque seconde ; on n'y voit plus guère | nappes blanches ; voile et flou à l'écran de qui s'y tient |
| `mud` | combinaison Boue | Ralenti fort tant qu'on y reste (reposé toutes les 2 s, sans trou ; 1 à 3 s encore à la sortie) | disque brun au sol, éclaboussure à la naissance |

Un **obstacle** (le Rempart) coupe ce qui voudrait passer à travers lui : projectiles, vague, nova, éclats d'un impact.

## Sorts d'eau et de terre

| Sort | Visée | Ce qu'il fait |
| --- | --- | --- |
| Trait de glace | projectile rapide (cible verrouillée possible) | dégâts modestes, Ralenti (force et durée selon le niveau : 25 % au niveau 1, 45 % au niveau 4, 50 % au niveau 5 ; plus de course au niveau 5 seulement, la course étant coupée à partir de 50 %) et Mouillé |
| Vague | cône devant soi (aperçu au sol : portée de 4 à 10 m, ouverture) | repousse (force selon le niveau), Mouillé, noie la Brûlure et les murs de flammes qu'elle touche (combinaisons), Renversé dès le niveau 4, laisse un sol mouillé devant soi |
| Brume | point au sol (disque de 4 à 10 m) | brume épaisse pour la durée du niveau ; qui s'y tient n'y voit plus guère ; dès le niveau 3, Mouillé et sol mouillé à sa fin. Une nouvelle brume dissipe la précédente |
| Projectile de roche | projectile lent et lourd (cible verrouillée possible) | gros dégâts ; Chancelant dès le niveau 3 ; au niveau 5, éclats autour de l'impact |
| Secousse | point au sol (disque de 3 à 5 m) | le sol se fend (présage de 1,4 à 1 s : le temps de fuir), puis blessure légère et Chancelant (Renversé dès le niveau 4) pour qui s'y tient encore, jamais le lanceur |
| Rempart | point au sol (ligne face au regard ; deux pans en chevron au niveau 5) | mur de pierres levées (objets créés par le serveur) qui monte du sol, arrête les pas et les sorts, puis s'enfonce à la fin de sa durée. Jamais sur un joueur ni un véhicule ; un nouveau fait tomber le précédent |

Les trois projectiles partagent un noyau (`server/projectiles.lua`, `client/projectiles.lua`) : visée, cible
verrouillée, vol, impact validé par le serveur, obstacles. Un nouveau projectile n'a qu'à déclarer son effet à l'impact
(serveur) et sa config de rendu (`projectile`, `fx`, `light`, `sounds`).

## Combinaisons entre éléments

Détectées et décidées par le serveur (`server/combos.lua`) d'après `config.combos` : un **déclencheur** (un sort ou un
élément qui touche une zone au sol d'un genre, ou un joueur dans un état) et un **résultat**. Chacune montre un mot
bref au lanceur (« Vapeur ! »), un effet et un son aux joueurs proches, et **s'inscrit dans son grimoire la première
fois** qu'il la déclenche (page « Combinaisons » : déclencheur, résultat, éléments ; celles qui restent sont comptées
sans être nommées).

| Combinaison | Déclencheur | Résultat |
| --- | --- | --- |
| Vapeur | une Vague ou un Trait de glace touche un Mur de flammes | le mur s'éteint ; un nuage de vapeur (zone `steam`) cache la vue et brûle légèrement, 7 s |
| Dissipation | une Boule de feu traverse une Brume | la brume se dissipe (sans sol mouillé) |
| Boue | une Secousse frappe un sol mouillé | une boue (zone `mud`) ralentit fortement, 30 s |
| Gel | un Trait de glace touche une cible mouillée | la cible est Gelée 2,5 s (contrôle dur, immunité ensuite) ; le Mouillé est consommé, puis le trait la mouille de nouveau aussitôt (son effet ordinaire) |
| Séchage | un sort de feu touche une cible mouillée | dégâts de moitié, Mouillé retiré, pas de Brûlure ce coup-ci |
| Extinction | un sort d'eau touche une cible en Brûlure | la Brûlure s'éteint |
| Roche ardente | un Projectile de roche traverse un Mur de flammes | le bloc s'embrase en vol (traînée de feu) ; à l'impact, dégâts de feu en plus et Brûlure |

Règles de bon sens, sans combinaison : être trempé (sol mouillé, brume) éteint la Brûlure. Le bloc enflammé est prédit
par chaque client pendant le vol (il voit les zones) ; le serveur décide de l'effet à l'impact d'après les zones que le
trajet a traversées.

## Commandes du Conseil

Droit `tools` de vava_admin (Sénéchal et Souverain), réglable (`config.admin.permission`) ; aussi depuis la console du
serveur. Chaque commande est inscrite au journal du Registre du Conseil. **Le numéro de joueur est facultatif** : sans
lui, la commande vise son auteur. Un échec répond en français (« Ce personnage n'est pas mage. », « Sa besace n'a
plus la place. »… `texts.chat.adminErrors`) ; le code brut ne va qu'à la console du serveur.

| Commande | Effet |
| --- | --- |
| `/magie mage [id] <oui\|non>` | rendre mage, ou retirer la magie |
| `/magie apprendre [id] <sort>` · `oublier [id] <sort>` | apprendre ou retirer un sort |
| `/magie niveau [id] <sort> <1-5>` · `xp [id] <sort> <xp>` | fixer le niveau ou l'XP (le sort est appris s'il ne l'était pas) |
| `/magie tous [id]` | tous les sorts au niveau 1 (le personnage devient mage) |
| `/magie maitrise [id]` | tous les sorts au niveau maximal (le personnage devient mage) |
| `/magie vider [id]` | retirer tous les sorts |
| `/magie mana [id]` · `recharges [id]` | remplir la mana · effacer les recharges et le délai global |
| `/magie fiche [id]` | mage, sort prêt, sorts, niveaux, XP, sigils, mana, combinaisons découvertes |
| `/magie donner [id] <grimoire\|registre>` | donner un objet (un registre neuf, numéroté) |
| `/magie nettoyer` | nettoyage d'urgence : retire du monde les effets des sorts (zones au sol, présages, remparts, orbes ancrés) |

`<sort>` : `boule_de_feu`, `mur_de_flammes`, `nova_ardente`, `trait_de_glace`, `vague`, `brume`, `projectile_de_roche`,
`secousse`, `rempart`, `lueur`, `murmure`.

## Configuration (`config.lua`)

| Section | Contenu |
| --- | --- |
| `mana` | maximum (100), régénération (3 points / 5 s), temps d'affichage de la barre après un sort |
| `progression` | seuils d'XP (0, 100, 300, 700, 1500), coût selon le niveau, part d'XP d'un échec, anti-farm (20 s) |
| `casting` | délai global entre deux sorts (1 s), tolérances, barre d'incantation au-delà de 0,5 s |
| `persistence` | écriture de la fiche dans le personnage (au plus toutes les 15 s, et au départ) |
| `elements` | feu, eau, terre, lumière, esprit : nom, groupe de la roue, couleur, particules des mains pendant l'incantation |
| `wheel` | groupes de l'anneau intérieur, dans l'ordre |
| `controls` | mode magie : endormissement (20 s), allure en visant, molette, aperçu au sol |
| `effects` | niveau de détail (complet en deçà de 30 m, rien au-delà de 150 m), plafonds de lumières et de particules, chargement et libération des ressources, traces au sol (`traces` : durée, couleur, taille) |
| `sounds` | portée des sons (60 m), fichiers .ogg qui remplacent les sons fabriqués (`files`), sons natifs de GTA (`native`) |
| `projectiles` | contrôles communs de l'impact (axe, marge sur la cible, portée, délai, joueurs qui voient le lancer, hauteur des mains et du torse) ; un sort peut en changer dans son `hit` |
| `spells.<sort>` | champs communs (voir plus bas) et **5 niveaux** : durée d'incantation, recharge, description, ce que le niveau débloque, valeurs propres au sort |
| `spells.lueur.anchor` · `colors` · `render` | orbe ancré, couleurs du niveau 5, rendu (os, décalages, flottement, scintillement) |
| `spells.<projectile>.projectile` · `fx` · `light` · `sounds` | rendu du vol : objet porteur (caché ou visible, qui tournoie), rayon du test de collision, marqueur, traînée, impact, tremblement, lumière, sons |
| `targeting` | verrouillage des sorts d'attaque : cône, clic long, délais, marge, frisson (durée, intervalle par lanceur et par cible), anneau |
| `states` | contrôles durs et immunité (6 s), durées par défaut, allure minimale, démarche et tremblement du chancelant, particules de chaque état |
| `zones` | vérification (500 ms), distance d'envoi (150 m), plafond du royaume (60) |
| `wetGround` | sol mouillé : durée du Mouillé, intervalle de repose, reflet au sol, gouttes |
| `spells.mur_de_flammes` | portée, longueur et largeur par niveau, durée, dégâts au passage, brûlure, murs par lanceur, flammes et lumières |
| `spells.nova_ardente` | rayon, dégâts, recul (niveau 3), brûlure (niveau 4), gerbes, anneau, éclat |
| `spells.trait_de_glace` | vitesse, portée, dégâts, Ralenti (force, durée), Mouillé, virage ; réaction de givre (`reaction`) |
| `spells.vague` | portée et ouverture du cône, recul, Renversé (niveau 4), Mouillé, sol mouillé, gerbes |
| `spells.brume` | portée, rayon, durée, épaisseur du voile (`density`), Mouillé et sol mouillé (niveau 3), filtre de GTA (`screen.timecycle`), nappes |
| `spells.projectile_de_roche` | vitesse, portée, dégâts, Chancelant (niveau 3), éclats (niveau 5), bloc qui tournoie, tremblement à l'impact |
| `spells.secousse` | portée, rayon, durée du présage, dégâts, contrôle infligé (Chancelant, puis Renversé), anneau, poussière, éclats, tremblement |
| `spells.rempart` | portée, longueur, épaisseur, hauteur, blocs par segment, segments (2 au niveau 5) et angle du chevron, durée, modèle de pierre, enfoncement, montée par paliers, plafond du royaume, marges autour des joueurs et véhicules |
| `combos` | combinaisons : déclencheur (`trigger` : spell ou element, on = zone ou target, zone ou state, projectile), résultat (`result` : remove, zone, state, consume, damageShare, noBurn, carry), textes du grimoire, mot bref, effet et son, nuée de la vapeur, rendu de la boue |
| `combat` | dégâts entre joueurs, points de vie d'un personnage (100), zones protégées (`{ label, x, y, radius }`), journal (lots, rétention : `log.retentionDays`, 30 jours), réaction de la victime par élément (feu, eau, glace, terre), durée du recul |
| `sigils` · `registers` · `items` | sigils (dont le délai après un refus, `refusedMs` : 60 s), registre (200 pages, lots de 20 pages et de 7 500 octets au plus), objets |
| `ambient` | effets vus des autres (15 m, fragments à 3 m, runes, textes) |
| `admin` · `keys` · `commands` · `rateLimits` | droits, touches et boutons, commandes, limites de débit |
| `texts` | **tous** les textes vus par les joueurs (refus, messages, chat, journal, interface) |

Champs communs d'un sort : `order` (roue et grimoire), `label`, `summary`, `element` (clé de `elements`), `type`
(`projectile`, `zone`, `utilitaire`), `icon` (`web/img/spells/<icon>.svg`), `baseCost`, `xp`, `hitXp` (bonus quand le
sort touche, si le lancer a rapporté), `moveSpeed` (marche permise pendant l'incantation), `interruptOnHurt` (vrai par
défaut), `lockOn`, `reaction` (réaction de la victime, sinon celle de l'élément), `aim` (`kind` = `projectile`,
`point`, `self` ou `none` ; `reach` ; `minLevel` ; aperçu au sol : `shape` = `circle`, `line` ou `cone`, et les noms des
champs de niveau qui en donnent la taille : `radius`, `length`, `width`, `segments`, `angle`, ou du sort : `bend`),
`anims` (`start`, `loop`, `release` : `{ dict, clip, flag, ms }`), `ambientText`, `runes`, `levelScale` (taille des
effets par niveau). Les dégâts sont en **points de vie** (sur `combat.healthPoints`).

## Ajouter un sort

1. `server/spells/<nom>.lua` : `VavaMagic.spells.register('<nom>', { config, beginArgs, finishArgs, begin, finish })`.
   `begin(ctx, …)` valide et prépare (`true, données[, coût]` ou `false, code`) ; `finish(ctx, …)` produit l'effet et
   rend `{ success, refund?, result?, rewarded? }`. Facultatif : `started(ctx)`, appelé une fois l'incantation
   acceptée (mana, recharges, contrôles passés), pour ce qui ne doit être annoncé qu'alors (frisson de la cible).
   Intentions propres : `spells.addRpc` ; ménage : `spells.onLeave`, `onStop` ; nettoyage d'urgence du Conseil :
   `spells.onCleanup`.
2. `client/spells/<nom>.lua` : son geste au clic gauche, `VavaMagic.controls.register('<nom>', { cast = function(info) … end })`
   (`info` : `aiming`, `point`, `inRange`, `direction`, `target`), qui appelle
   `VavaMagic.casting.start('<nom>', { args, finishArgs, beforeRelease, onFinish })`.

Raccourcis du noyau : un **projectile** se déclare par `VavaMagic.projectiles.register('<nom>', config, { onImpact,
fizzle? })` côté serveur et `VavaMagic.projectiles.define('<nom>')` côté client (rendu d'après sa config) ; un sort
**posé au sol** par `VavaMagic.controls.registerPoint('<nom>')` (client) et `VavaMagic.zones.aimed(ctx, x, y, z, portée,
hauteur)` (serveur). Un genre de **zone** se déclare par `zones.define(genre, { onTick?, onEnd? })` (serveur) et
`VavaMagic.zoneRender.define(genre, { start, frame?, stop })` (client) ; un **effet instantané** par
`world.broadcast(point, rayon, EVENTS.BURST, { spell, … })` (serveur) et `VavaMagic.bursts.define('<nom>', rendu)`
(client) ; un **obstacle** par `VavaMagic.obstacles.add(function(de, vers) … end)` ; un sol mouillé par
`VavaMagic.grounds.wet{ … }`.
3. `config.lua` : `spells.<nom>` (champs communs) et son icône `web/img/spells/<icon>.svg` (silhouette blanche) ; lister
   ses deux fichiers dans le `fxmanifest.lua`. La roue, le grimoire, `/sort`, `/lancer` et les commandes du Conseil le
   prennent d'eux-mêmes.

Un autre module peut aussi ajouter un sort par le registre du core `vava_magic:spells` (voir `docs/api.md`).

**Ajouter une combinaison** : une entrée dans `config.combos` suffit tant que son déclencheur et son résultat sont de
ceux que `server/combos.lua` comprend (voir le commentaire de la config) : par exemple `{ trigger = { element = 'feu',
on = 'zone', zone = 'mud' }, result = { remove = true } }` pour que le feu sèche la boue. Les sorts appellent le moteur
aux bons moments : `combos.hit(lanceur, cible, sort, dégâts)` avant de blesser (il rend les dégâts ajustés et si la
brûlure est permise), `combos.zone(ctx, zone)` quand un sort touche une zone (les projectiles le font d'eux-mêmes pour
les zones traversées), `combos.sweep` pour un cône, `combos.quake` pour un cercle. Un nouveau genre de zone résultat
demande son `zones.define` (serveur) et son rendu (client).

## Effets et sons

Chaque sort a ses couches d'effets, toutes réglées en config : mains pendant l'incantation (particules de l'élément,
plus grandes selon le niveau, lueur), lancement (geste de relâchement, son), trajet (traînée, lumière, marqueur,
objet qui tournoie), impact (particules, lueur, son, caméra qui tremble), effet persistant (zones, états sur les
joueurs, vus de tous). Le niveau se devine en regardant : `levelScale` grandit les effets, les lumières suivent.

**Niveau de détail** (`effects`) : complet à moins de 30 m de la caméra (toutes les particules, deux mains, lumières),
simplifié jusqu'à 150 m (moins de points, une main, pas d'effets secondaires), rien au-delà. Plafonds de lumières par
image (24) et de particules en boucle (40) pour que plusieurs mages restent fluides ; lots de particules et
dictionnaires d'animation chargés à la demande (attente bornée) et libérés après une minute sans usage ; tout est
nettoyé à l'arrêt du module et au retour à la sélection.

**Traces au sol** (`effects.traces`, vues de chaque client) : sol noirci là où un mur de flammes a brûlé et sous une
nova, fissure après une secousse ; disques sombres qui s'effacent en vingt secondes. Le sol mouillé, lui, est une
vraie zone du serveur (il mouille).

**Sons** (`sounds`) : fabriqués par l'interface (Web Audio), volume selon la distance (rien au-delà de 60 m) : carillon
(murmure reçu), souffle (lancer), impact, boule éteinte, glace brisée, vague, craquement, grondement, sifflement.
Pour les remplacer : déposer des `.ogg` dans `web/sounds/` et les déclarer dans `sounds.files` (`whoosh =
'sounds/whoosh.ogg'`) ; ou déclarer un son natif de GTA dans `sounds.native` (`impact = { name = …, set = … }`, joué
au point de l'effet). Aucun fichier n'est fourni.

## Sécurité et coût

- Le serveur vérifie à chaque incantation : mage, sort connu, niveau, recharge (tenue par personnage, la reconnexion ne
  l'efface pas), mana, une seule incantation, pas à terre ni en véhicule (la cible non plus : un joueur à terre ne
  subit aucun sort), puis à la fin : durée écoulée, déplacement
  et vie lus côté serveur. Interrompue : rien n'est consommé.
- Projectiles : un seul impact par lancer, point d'impact dans la portée et dans l'axe annoncé, délai cohérent avec la
  vitesse, cible réelle près du point (position serveur), zones protégées ; un rempart sur le trajet l'arrête là, quoi
  qu'annonce le client ; les dégâts ne partent qu'ensuite. Le serveur ne voit pas les murs de GTA : un tricheur ne
  peut que toucher une cible réellement devant lui, à portée.
- Vague, Secousse : positions des victimes lues côté serveur ; la direction de la vague est le choix de visée du
  lanceur. Rempart : refusé sur un joueur ou un véhicule (positions serveur), blocs créés, montés et retirés par le
  serveur, plafond de 48 blocs dans le royaume.
- Ce que la Brume cache se joue à l'écran de chacun : un tricheur pourrait ôter le voile (effet cosmétique, comme
  l'allure d'un Ralenti).
- Fragments du Murmure : envoyés par le serveur aux seuls joueurs à moins de 3 m ; jamais dans un state bag.
- Un client peut écrire dans le state bag de son propre ped (ou d'un objet à lui) : au pire un effet cosmétique, sans
  aucune incidence. Le serveur n'en lit aucun ; une lumière (Lueur, orbe) n'est dessinée chez les autres que si
  chacun de ses champs est un nombre dans les bornes de la config.

| Fonction | Réseau |
| --- | --- |
| Mana | ~60 o au seul lanceur, à chaque changement ; aucun envoi périodique (la page anime la remontée) |
| Roue | ~40 o au serveur quand le sort prêt change ; la roue et la visée sont locales |
| États | state bag du ped (~60 o) aux joueurs proches, durées (~80 o) au seul joueur affecté, à chaque changement |
| Zones | ~150 o par zone aux joueurs à moins de 150 m (une fois, ou en approchant), sa fin à ceux qui la connaissent ; vérification serveur toutes les 500 ms, seulement s'il y en a |
| Nova | ~80 o aux joueurs à moins de 120 m ; recul et réaction à la seule victime |
| Incantation | 2 RPC, plus un state bag du ped (~80 o) reçu des joueurs proches |
| Murmure | < 1 Ko par destinataire ; fragments aux seuls joueurs à moins de 3 m |
| Registre des murmures | au seul lecteur : à l'ouverture, un lot de 7,5 Ko au plus (3 Ko pour 20 murmures de 100 signes ; un registre plein envoyait jusqu'à 100 Ko d'un bloc avant 2.7.0) ; puis un lot par demande, au même plafond |
| Lueur | ~100 o à l'allumage et à l'extinction ; un objet réseau par orbe ancré |
| Projectiles | ~150 o de lancer aux joueurs proches (150 m), un impact, les dégâts |
| Vague · Secousse · Rempart | ~100 à 250 o d'effet instantané aux joueurs à moins de 120 m ; recul, réaction et états à la seule victime |
| Brume · sol mouillé · présage · boue | comme les zones ; Mouillé reposé au plus toutes les 4 s, Ralenti de la boue toutes les 2 s, sur un même joueur |
| Combinaisons | ~20 o au lanceur (mot bref), ~100 o d'effet aux joueurs à moins de 150 m ; une vue de la fiche (~200 o) à la première découverte |
| Rempart | 2 à 6 objets réseau figés (synchronisés par OneSync), 8 déplacements à la montée et à la descente |

Serveur : aucune boucle permanente (mana calculée à la demande ; écritures groupées toutes les 10 à 15 s). Client : une
recherche des effets proches toutes les 250 ms, seulement tant qu'un state bag de magie est suivi ou qu'un effet reste
à défaire (rien chez un joueur sans magie autour, 2.7.1) ; le dessin par image ne tourne que si une lumière, un texte, un
projectile, une zone qui dessine (flammes, reflet, présage) est à portée, pendant l'incantation d'un sort qui permet de
marcher, roue ouverte, ou en mode magie éveillé (qui coupe l'attaque de GTA à chaque image ; il s'endort après 20 s
sans action). La brume ne relit la position du joueur que toutes les 200 ms, tant qu'elle est proche. Plafonds de
lumières et de particules, rien au-delà de 150 m.

## À vérifier en jeu (noms tirés de GTA V)

| Usage | Animation, particule ou bouton | Réglage |
| --- | --- | --- |
| Boule de feu : début, maintien | `anim@mp_player_intupperknuckle_crunch` / `enter`, `idle_a` | `spells.boule_de_feu.anims` |
| Boule de feu : jet | `weapons@projectile@grenade_str` / `throw_m_fb_stand` | idem (`release`) |
| Mur de flammes : bras levés | `anim@mp_player_intuppersurrender` / `enter`, `idle_a`, `exit` | `spells.mur_de_flammes.anims` |
| Nova ardente : gerbe | `anim@mp_player_intcelebrationmale@jazz_hands` / `jazz_hands` — **à juger** | `spells.nova_ardente.anims` |
| Réaction au feu | `anim@mp_player_intupperface_palm` / `idle_a` — **à juger** | `combat.reactions.feu` |
| Chancelant : démarche | jeu de mouvements `move_m@drunk@verydrunk`, tremblement `DRUNK_SHAKE` | `states.stagger` |
| Nova : sol qui tremble | tremblement `SMALL_EXPLOSION_SHAKE`, marqueur 25 (anneau) | `spells.nova_ardente.fx` |
| Mur : flammes · embrasement · extinction | `core` / `ent_amb_torch_fire` · `ent_sht_flame` · `ent_sht_steam` (en boucle au sol) | `spells.mur_de_flammes.fx` |
| États : brûlure · mouillé · gelé · chancelant | `core` / `ent_amb_torch_fire` · `ent_sht_water` — **incertain** · `ent_sht_steam` (faute de givre) · `ent_dst_dust` — **incertain** | `states.fx` |
| Lueur : incantation | `amb@world_human_stand_fire@male@base` / `base` | `spells.lueur.anims` |
| Murmure : tracer des runes | `anim@mp_player_intupperair_synth` / `idle_a` | `spells.murmure.anims` |
| Mains du feu, traînée, brûlure | `core` / `ent_amb_torch_fire` | `elements.feu.hands`, `spells.boule_de_feu.fx` |
| Impact · boule éteinte | `core` / `ent_sht_flame` · `ent_sht_steam` | `spells.boule_de_feu.fx` |
| Mains de l'eau | `core` / `ent_amb_waterfall_splash_p` — **incertain** | `elements.eau.hands` |
| Mains de la terre | `core` / `ent_dst_dust` — **incertain** | `elements.terre.hands` |
| Trait de glace : jet · traînée · impact | `weapons@projectile@grenade_str` / `throw_m_fb_stand` · `core` / `ent_sht_steam` · `ent_sht_water` — **incertain** | `spells.trait_de_glace` |
| Vague : bras levés, puis poussés | `anim@mp_player_intuppersurrender` · `anim@mp_player_intcelebrationmale@bro_love` / `bro_love` — **à juger** | `spells.vague.anims` |
| Vague · sol mouillé : gerbes | `core` / `ent_sht_water` — **incertain** ; reflet : marqueur 1 | `spells.vague.fx`, `wetGround` |
| Brume : nappes · flou à l'écran | `core` / `exp_grd_bzgas_smoke` (fumée de la grenade lacrymogène) — **incertain** · filtre `hud_def_blur` | `spells.brume.fx`, `spells.brume.screen` |
| Projectile de roche : bloc | objet `prop_rock_1_b` — **à vérifier** (taille), traînée `ent_dst_dust`, impact `ent_dst_rocks` — **incertain** | `spells.projectile_de_roche` |
| Secousse · Rempart : genou à terre, main au sol | `amb@world_human_gardener_plant@male@enter` · `@base` · `@exit` — **à juger** | `spells.secousse.anims`, `spells.rempart.anims` |
| Secousse : présage · choc | marqueurs 25 (anneau) et 1 (disque), `ent_dst_dust` · `ent_dst_rocks`, `SMALL_EXPLOSION_SHAKE` | `spells.secousse.fx` |
| Rempart : blocs de pierre | objet `prop_rock_4_c` — **à vérifier** (taille, assise, collision) ; poussière `ent_dst_rocks` | `spells.rempart.model`, `sink`, `rise` |
| Vapeur : nappes · jets | `core` / `ent_sht_steam` (en boucle au sol — **à juger**, ponctuel) | `combos.vapeur.cloud`, `combos.vapeur.fx` |
| Boue : éclaboussure · disque | `core` / `ent_sht_water` — **incertain** ; marqueur 1 brun | `combos.boue.fx`, `combos.boue.render` |
| Roche ardente : traînée · impact | `core` / `ent_amb_torch_fire` · `ent_sht_flame` | `combos.roche_ardente.result.carry` |
| Orbe | marqueur 28 (sphère) et `DrawLightWithRange` | `spells.lueur.render` |
| Aperçu au sol | marqueurs 1 (disque) et 28 (point) | `controls.preview` |
| Boutons de la souris | `MOUSE_BUTTON` / `MOUSE_LEFT`, `MOUSE_RIGHT`, `MOUSE_MIDDLE` ; `MOUSE_WHEEL` / `IOM_WHEEL_UP`, `IOM_WHEEL_DOWN` | `keys` |
| Nom des touches au grimoire | `GetControlInstructionalButton` (sinon `keys.<action>.display`) | — |

Les sons (carillon, souffle, impact, boule éteinte, glace brisée, vague, craquement du sol, grondement, sifflement)
sont fabriqués par l'interface (Web Audio) : à juger à l'oreille ; des fichiers `.ogg` ou des sons natifs de GTA les
remplacent (`sounds`). Les noms de sons natifs ne sont pas fournis : à chercher et vérifier en jeu.

Rempart : le serveur monte les blocs par 8 paliers en 0,8 s (`rise`) ; selon la fluidité de la synchronisation,
`rise.steps = 0` les fait paraître d'un coup. Sur un sol en pente, régler `sink` (blocs enfoncés).

## Tests à faire en jeu

Deux joueurs (A et B) suffisent ; un troisième aide pour le cercle et la zone d'effet.

**Fiche, Conseil, grimoire**
- [ ] `/magie fiche <A>` : « Mage : non », « Sigils gardés : 0 » (la fiche ne montre pas le sigil : son propre sigil, de 12 signes, est en base, `vava_magic_sigils`) ; `/magie mage <A> oui` → message « La magie s'éveille », barre de mana absente tant qu'elle est pleine.
- [ ] `/magie tous <A>` (puis `/magie tous` sans numéro, sur soi) ; `/magie donner <A> grimoire` puis l'utiliser : sorts rangés par élément, icônes, niveau I, XP, recharge, incantation, touches de la roue.
- [ ] `/magie maitrise`, `/magie vider`, `/magie recharges`, `/magie nettoyer` (orbe ancré disparu).
- [ ] B (non mage) ouvre un grimoire : pages illisibles. Un joueur hors du Conseil tape `/magie` : refusé.
- [ ] Le journal du Registre du Conseil (et la Chancellerie) montre chaque commande.

**Roue et mode magie**
- [ ] Tab maintenu : la roue s'ouvre, la caméra ne bouge pas, la roue d'armes de GTA n'apparaît pas. Survoler Feu puis la Boule de feu, relâcher : sort prêt, affiché près de la barre de mana.
- [ ] Relâcher au centre : rien ne change ; sur la main ouverte : magie rangée. Échap : rien n'est choisi. Un sort en recharge est grisé avec ses secondes.
- [ ] Clic gauche mains vides : la boule part (pas de coup de poing). Sortir une arme : le clic gauche tire à nouveau normalement, le sort reste prêt.
- [ ] 20 s sans rien faire : le sceau de la barre pâlit, le clic gauche refrappe. Clic droit : réveillé.
- [ ] Clic droit maintenu : réticule orange au centre, gris quand on vise trop loin ; on marche moins vite. Lueur niveau 4 : petite sphère au point visé.
- [ ] Molette en mode magie avec Lueur prête : passe au Murmure (même élément), et retour.
- [ ] Changer les touches dans Paramètres > Raccourcis > FiveM (roue sur une autre touche) : la roue suit.

**Incantation**
- [ ] A lance la Lueur : barre d'incantation, animation, texte « fait naître une lueur… » vu de B à moins de 15 m, puis la lumière.
- [ ] Boule de feu : incantation brève sans barre, flammes dans les deux mains vues de B (plus grandes au niveau 5).
- [ ] Interrompre par X, en marchant de plus d'un mètre, en se faisant frapper : barre brisée, mana inchangée.
- [ ] Relancer dans la seconde : « Laissez la magie retomber un instant » ; puis « pas encore prêt (n s) ». Deux sorts à la fois : impossible.
- [ ] Barre de mana : apparaît après un sort et en mode magie, remonte de 3 toutes les 5 s, disparaît une fois pleine.
- [ ] Se déconnecter et revenir : sorts, XP et sigils gardés, mana pleine.

**Lueur**
- [ ] Niveaux 1-2 : lumière dans la main, qui vacille sans saccade ; s'éteint seule (1 min au niveau 1) ; même touche pour éteindre.
- [ ] `/magie niveau <A> lueur 3` : orbe près de l'épaule. Niveau 4 : clic gauche en visant ancre un orbe au point visé (B le voit, sans objet visible) ; `/lueur dissiper`.
- [ ] Niveau 5 : couleur choisie dans le grimoire, appliquée à la lumière allumée.

**Sigils et Murmure**
- [ ] A et B face à face, `/sigil offrir` : B nomme A, coche « confier le mien », A nomme B. Sans réponse 30 s : offre close. Trop loin : refusé. B refuse : A ne peut lui retendre son sigil qu'au bout de 60 s (message avec les secondes restantes) ; B peut toujours tendre le sien à A.
- [ ] À sens unique : B murmure à A qui ne le connaît pas → « Une présence inconnue ».
- [ ] A, Murmure prêt, clic gauche : le parchemin s'ouvre (contacts, compteur de signes, envoi). Pendant l'incantation : B à moins de 3 m lit des mots dorés au-dessus des mains de A ; à 5 m, seulement des runes.
- [ ] B reçoit le parchemin, entend le carillon ; un témoin voit « ses yeux s'illuminent ». Niveau 1 : certains mots arrivent en « … ».
- [ ] B déconnecté : « Le lien reste silencieux », part de mana rendue. Trop loin au niveau 1 (300 m) : « Le lien ne porte pas si loin ».
- [ ] Niveau 3 : position jointe → point de passage chez B. Niveau 4 : cercle de plusieurs contacts.
- [ ] Message avec accents et longueur maximale : tronqué proprement.
- [ ] `/sigils`, `/sigil renommer`, `/sigil oublier`, `/sigil brouiller` (B ne joint plus A par l'ancien sigil).

**Registre**
- [ ] Avec un registre sur soi, envoyer et recevoir : pages datées « À … » / « De … » ; sans registre : rien n'est consigné.
- [ ] Arracher une page. Donner le registre à B : B lit l'historique (il suit l'objet). Un registre neuf est vierge.
- [ ] Registre de plus de 20 pages : 20 pages à l'ouverture, « tourner les pages plus anciennes » ajoute les suivantes sans doublon ni trou, jusqu'à la première ; registre donné pendant la lecture : le lot suivant est refusé.

**Boule de feu**
- [ ] A vise B (à 10 m) et clique : jet vers le réticule, projectile et lumière vus de tous, impact en flammes, B blessé (vava_health), A gagne son XP et le bonus au toucher. Pas d'explosion GTA.
- [ ] Hors de portée ou derrière soi : aucun dégât. Niveau 1 : la boule s'éteint parfois (vapeur, mana dépensée).
- [ ] Clic molette devant B : anneau rouge sous B (A seul le voit). Encore : cible suivante ; maintenu : relâché. B derrière un mur : verrou perdu.
- [ ] A lance sur B verrouillé : B voit le bord de son écran rougir dès le début de l'incantation ; A se tourne vers B au jet ; la boule part sur B même si A regarde ailleurs.
- [ ] Niveau 1 à 3 : B esquive en se décalant. Niveau 4-5 (`/magie niveau <A> boule_de_feu 5`) : la boule s'incurve et le rattrape.
- [ ] Niveau 3 : un voisin de B est touché aussi (moins fort). Niveau 4 : B brûle quelques secondes.
- [ ] Zone protégée (`combat.protectedZones`) : impossible d'y lancer, personne n'y est blessé. `combat.pvp = false` : aucun dégât.
- [ ] Table `vava_magic_damage_log` : lanceur, cible, dégâts, position ; écrite par lots, et en entier à l'arrêt du module. Les lignes de plus de 30 jours sont retirées au démarrage du module (message en console s'il y en avait), puis chaque jour.

**États (avec `/magie` et un test du Conseil, ou les sorts)**
- [ ] Brûlure (Boule de feu niveau 4, Mur, Nova niveau 4) : flammes sur la victime vues de tous, icône et secondes chez elle, bord de l'écran rougi, dégâts chaque seconde, puis plus rien.
- [ ] Contrôle dur, puis un autre aussitôt : refusé ; l'icône « Protégé » paraît à la fin du premier, 6 s. Les dégâts passent pendant ce temps.
- [ ] Pendant un contrôle dur, tenter d'incanter : « impossible d'incanter » ; une incantation en cours se brise.
- [ ] Se déconnecter gelé et revenir : rien ne reste (personnage libre).

**Mur de flammes**
- [ ] Clic droit sur le sol : bande lumineuse au sol, en travers du regard, à la longueur du niveau ; grise trop loin. Clic gauche sans viser : « Visez le sol ».
- [ ] Le mur s'embrase, flammes et lumière vues de tous (de nuit, il éclaire les murs et les personnages). B le traverse en courant : blessé et brûlé ; il y reste : une blessure par seconde. A n'en souffre pas.
- [ ] Un troisième mur éteint le plus ancien (`/magie recharges` entre deux). Le mur s'éteint seul (fumée). `/magie nettoyer` éteint tout.
- [ ] Zone protégée : impossible d'y dresser un mur. B arrive après coup, de loin : il voit le mur en approchant.

**Nova ardente**
- [ ] Clic droit : disque de son rayon autour de soi. Clic gauche : gerbes en cercle, anneau qui s'élargit, éclat, sol qui tremble pour les proches ; B à moins du rayon est blessé, C plus loin non, A jamais.
- [ ] Niveau 3 : B est repoussé ; niveau 4 : B brûle ; niveau 5 : rayon de 6 m. XP et bonus au toucher pour A.

**Trait de glace**
- [ ] A vise B et lance : éclat blanc rapide, traînée de vapeur, lueur bleutée ; B blessé un peu, icônes Ralenti et Mouillé, il marche moins vite, givre bref à l'écran.
- [ ] Niveau 4 : B court encore (Ralenti 45 %, ce que le grimoire annonce depuis 2.6.3) ; verrouillé, le trait s'incurve un peu vers lui. Niveau 5 : B ne peut plus courir.

**Vague**
- [ ] Clic droit : cône bleu au sol devant soi, qui suit le regard. Clic gauche : gerbes d'eau qui balaient le cône, son de vague ; B devant est repoussé et mouillé ; C derrière, rien.
- [ ] B en Brûlure (Boule de feu niveau 4) : la vague l'éteint. Un mur de flammes dans le cône s'éteint (fumée) ; un autre, derrière, reste.
- [ ] Niveau 4 : B est renversé. Un reflet d'eau reste au sol devant A ; qui y marche est mouillé.

**Brume**
- [ ] Clic droit : disque au sol visé. Clic gauche : nappes de brume vues du dehors ; B dedans : écran voilé et flou, qui part dès qu'il sort.
- [ ] Niveau 3 : B dedans est mouillé ; à la fin, un reflet d'eau reste au sol. Une seconde brume dissipe la première.

**Projectile de roche**
- [ ] Bloc de pierre visible qui tournoie, lent : B peut l'esquiver en se décalant. Touché : gros dégâts, éclats, caméra qui tremble pour les proches.
- [ ] Niveau 3 : B chancelle (impossible d'incanter un instant). Niveau 5 : un voisin de B est touché aussi.

**Secousse**
- [ ] Clic gauche sur le sol visé : anneau terreux au sol qui se remplit, poussière, craquement ; B en sort à temps : rien. B reste : blessé et chancelant au choc (éclats, caméra qui tremble). A dans son propre cercle : rien.
- [ ] Niveau 4 : B est renversé. `/magie nettoyer` pendant le présage : aucun choc.

**Rempart**
- [ ] Clic droit : ligne au sol face au regard ; niveau 5 : deux pans en chevron. Clic gauche : les pierres montent du sol, poussière, le sol tremble pour les proches.
- [ ] B ne passe pas à travers ; une Boule de feu lancée sur B derrière le mur s'écrase contre lui ; une vague ne passe pas.
- [ ] Viser B ou un véhicule : « Quelqu'un ou quelque chose occupe cet endroit ». Un second rempart fait tomber le premier ; à sa fin, il s'enfonce et disparaît.
- [ ] `/magie nettoyer` et arrêt de la ressource : aucune pierre ne reste dans le monde.

**Combinaisons** (A lance ; B subit ; `/magie fiche` compte les découvertes)
- [ ] Vapeur : B dresse un mur de flammes, A le balaie d'une Vague (ou le traverse d'un Trait de glace) : le mur s'éteint, un nuage blanc le remplace, sifflement ; A voit « Vapeur ! » et « Une combinaison s'inscrit dans votre grimoire » (la première fois seulement). Qui se tient dans la vapeur voit flou et perd un point par seconde.
- [ ] Dissipation : B pose une Brume, A la traverse d'une Boule de feu : la brume disparaît sur-le-champ, aucun sol mouillé.
- [ ] Boue : A lance une Vague (sol mouillé devant lui), puis une Secousse dessus : au choc, un disque brun remplace le reflet d'eau ; B qui y marche est très ralenti pendant 30 s.
- [ ] Gel : B mouillé (vague, sol mouillé, brume niveau 3) ; A le touche d'un Trait de glace : B est gelé 2,5 s (givre, icône), puis « Protégé » ; un second trait pendant la protection ne le gèle pas.
- [ ] Séchage : B mouillé ; A le touche d'une Boule de feu niveau 4 : dégâts de moitié, plus mouillé, pas de brûlure. Même chose dans un Mur de flammes et sous une Nova.
- [ ] Extinction : B en Brûlure ; A lui envoie une Vague ou un Trait de glace : la brûlure s'éteint, « Éteint ! ». B qui marche sur un sol mouillé cesse aussi de brûler (sans combinaison).
- [ ] Roche ardente : B dresse un mur de flammes, A lance un Projectile de roche à travers : le bloc s'enflamme en vol (traînée de feu, lueur), impact en flammes, dégâts de feu en plus et B brûle.
- [ ] Grimoire : page « Combinaisons » après les sorts, avec celles découvertes (déclencheur, résultat, deux icônes) et le compte de celles qui restent ; avant toute découverte, l'invitation à mêler les éléments.
- [ ] `/magie nettoyer` retire aussi vapeur et boue.

**Immunité aux contrôles durs**
- [ ] Enchaîner Secousse (Chancelant), puis Projectile de roche niveau 3, puis Gel : seul le premier contrôle passe ; les suivants pendant la protection ne font que leurs dégâts ; « Protégé » 6 s après la fin du premier.
- [ ] Pendant un Chancelant ou un Gelé, B ne peut pas incanter ; son incantation en cours se brise.

**Effets, traces, sons, niveau de détail**
- [ ] Mur de flammes éteint, Nova, Secousse : une trace sombre reste au sol et s'efface en vingt secondes.
- [ ] Déposer un `whoosh.ogg` dans `web/sounds/` et le déclarer : il remplace le souffle fabriqué ; déclarer un son natif pour `impact` : il se joue au point d'impact.
- [ ] Deux mages de niveaux 1 et 5 lancent le même sort côte à côte : la différence se voit (taille, lumière, particules) et s'entend.
- [ ] S'éloigner à plus de 30 m d'un mur de flammes : moins de flammes ; à plus de 150 m : plus rien ; revenir : tout revient.
- [ ] Arrêt de la ressource en pleine action (`restart vava_magic`) : plus aucune particule, lumière, voile ni pierre ne reste ; les joueurs gelés sont libres ; à son retour, les fiches sont intactes.

**Performance**
- [ ] Recherche endormie (2.7.1) : un joueur sans aucune magie autour n'a aucun thread de recherche ; dès qu'un mage proche incante, allume une Lueur ou subit un état, les effets apparaissent comme avant (dans le quart de seconde), et disparaissent quand tout cesse. Détail : `docs/tests/magie.md` § 15.
- [ ] `resmon` : `vava_magic` à ~0,00 ms au repos, quelques centièmes pendant une incantation ou une lumière proche ; une brume, une vapeur ou un sol mouillé proches restent à quelques centièmes.
