# Audit sécurité — vava_magic 2.6.3 — 29 octobre 2026 (T-010)

Relecture indépendante du module par l'agent `vava-securite`, dans le modèle de menace de `docs/plan/SECURITE_RESEAU.md`
(client entièrement contrôlé : Lua arbitraire, RPC avec n'importe quels arguments et à n'importe quelle fréquence,
rejeu, position mensongère, outils de développement de la NUI ; ni le serveur ni la base). Chaque affirmation renvoie
à une ligne du code lu ; les choix tranchés de `CLAUDE.md` et les limites documentées dans le README de la magie ne
sont pas relevés comme des problèmes.

## Périmètre

Lus en entier (tous les chemins relatifs à `modules/vava_magic/`) :

| Fichiers | Rôle en une phrase |
| --- | --- |
| `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `shared/text.lua`, `shared/progression.lua`, `shared/geometry.lua` | version 2.6.3, bornes et limites de débit, noms des RPC et évènements, nettoyage UTF-8, règles de progression, calculs de position partagés |
| `bridge/server.lua`, `bridge/client.lua` | seuls contacts avec le core et les autres modules (personnage, droits, inventaire, santé, base, notifications) |
| `server/core.lua`, `main.lua`, `casting.lua`, `spells.lua`, `sheets.lua`, `mana.lua`, `progression.lua`, `combat.lua`, `states.lua`, `obstacles.lua`, `zones.lua`, `grounds.lua`, `combos.lua`, `projectiles.lua`, `registers.lua`, `sigils.lua`, `admin.lua`, `api.lua`, `commands.lua`, `world.lua` | déclaration des RPC, incantation commune, fiche, mana, XP, dégâts et journal, états, zones, combinaisons, projectiles, registres, sigils, commandes du Conseil, exports |
| `server/spells/*.lua` (11 sorts) | validation et effet de chaque sort |
| `client/*.lua`, `client/spells/*.lua` | ce que le client déclare au serveur (visée, impacts, cibles verrouillées, parchemins, réponses aux offres) et ce qu'il croit des évènements reçus |
| `web/index.html`, `web/js/*.js` (16 fichiers) | interface NUI : construction du DOM, retours vers le jeu, sons |
| `sql/0001_magic.sql`, `README.md` | tables, règles annoncées (comparées au code) |

Lus hors du module pour vérifier ce dont la magie dépend : `server/core/rpc.lua` et `shared/lib/schema.lua` (chaîne de
contrôle d'un RPC, refus de NaN et ±inf, bornes par défaut 256 o / 64 éléments, `maxInFlightPerPlayer = 8`),
`shared/core/hooks.lua:163-181` (`runBefore` renvoie `false, 'hook_error'` quand un handler lève : garde fermée),
`server/players/characters.lua:560-590` et `server/players/fields.lua:100-109` (aucun RPC client n'écrit un champ de
personnage ; `visibility = 'private'` n'est jamais envoyé au client), `server/core/ratelimit.lua:43-56`,
`config/server.lua:23-33,92-93`, `modules/vava_admin/server/api.lua:35-80`, `modules/vava_health/server/api.lua:58-63`,
`docs/plan/rapports/T-006.md`.

Non lus en entier : `web/css/style.css` (aucune donnée joueur n'y entre), `web/js/devmock.js` (aperçu navigateur ;
vérifié : il se retire dès que la page tourne en jeu, `devmock.js:11` `if (Bridge.inGame) return null`, et le `grep`
des puits HTML n'y trouve rien), `docs/tests/magie.md`, le reste du core et des autres modules.

Corrections annoncées par T-006, retrouvées dans le code : `combat.affects` refuse un joueur à terre
(`server/combat.lua:62-67`) ; `world.freeze` ne libère pas un joueur retenu par le Conseil (`server/world.lua:97-100`)
et le client ne fige ni ne libère plus rien (aucun `FreezeEntityPosition` dans `client/states.lua`) ; verrou à la
portée du sort prêt (`client/targeting.lua:49`) ; `/lancer` refusé arme en main (`client/controls.lua:381`) ;
`/sort` d'un non-mage (`client/controls.lua`, commande `sort`) ; `combat.flushAll` à l'arrêt (`server/combat.lua:108`,
`server/main.lua:146`) ; échecs du Conseil en français (`server/admin.lua:283-312`) ; couleurs de la Lueur en `enum`
(`server/spells/lueur.lua:186`) ; refigeage après une action du Conseil (`server/states.lua:249`, 2.6.3).

## Points d'entrée

Tous les RPC passent par `core.rpc.register` avec `args` et `rateLimit` (`server/main.lua:86-104`,
`server/casting.lua:317-323`, `server/spells.lua` → `addRpc`). Débits : `capacity / refillPerSecond`
(`config.lua:1100-1113`). Aucun `RegisterNetEvent` serveur dans le module (vérifié : seul `bridge/client.lua:113` en a
un, côté client). Aucun state bag n'est lu côté serveur (vérifié par `grep`).

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
| --- | --- | --- | --- | --- | --- |
| `vava_magic:sheet` | RPC | aucun argument | 3 / 0,2 | fiche chargée (`main.lua:68-73`) | `admin` renvoyé pour l'affichage seul ; le droit est revérifié à chaque `/magie` |
| `vava_magic:select` | RPC | chaîne ≤ 32, `^[%w_]*$` | 8 / 2 | fiche, mage, sort connu **et** déclaré (`sheets.lua:338-349`) | `emit` sans réponse |
| `vava_magic:castCancel` | RPC | entier 1..2³¹ | 10 / 2 | sa propre incantation, même numéro (`casting.lua:299`) | rien n'est consommé |
| `vava_magic:sigils` | RPC | aucun | 6 / 1 | fiche | ne renvoie que rangs et noms (jamais un sigil) |
| `vava_magic:sigilOffer` | RPC | aucun | 3 / 0,2 | position serveur, plus proche à 3 m choisi par le serveur, une offre par joueur, délai 60 s après un refus (`sigils.lua:141-157`) | voir MINEUR 6 |
| `vava_magic:sigilAnswer` | RPC | entier, bool, chaîne ≤ 96 o, bool | 6 / 1 | offre à soi et à l'étape `offer` (`:171`), nom nettoyé ≤ 24 signes (`:178`), distance revérifiée (`:180`), mémoire pleine | |
| `vava_magic:sigilName` | RPC | entier, bool, chaîne ≤ 96 o | 6 / 1 | offre à soi, étape `naming` (`:216`), nom, distance | |
| `vava_magic:sigilRename` · `sigilForget` | RPC | rang 1..60, chaîne ≤ 96 o | 6 / 1 | rang dans sa propre liste (`:246-263`) | |
| `vava_magic:sigilScramble` | RPC | aucun | 2 / 0,05 | mage, sort connu, recharge 6 h dans la fiche, mana 60 dépensée avant la base, rendue si elle échoue (`:279-291`) | bloque sur la base ; voir MINEUR 9 |
| `vava_magic:registerTear` | RPC | entier, page ≤ 2⁵³ | 6 / 1 | registre **porté** (métadonnée lue dans l'inventaire, `registers.lua:102,177`) ; `DELETE … WHERE id = ? AND register_id = ?` (`:33`) | une page d'un autre registre est hors d'atteinte |
| `vava_magic:begin:<sort>` (11) | RPC | propre au sort : 3 `COORD` ±20 000 (mur, brume, secousse, rempart) ; cible 1..65535 facultative (projectiles) ; Murmure : liste 1..8 d'entiers 1..60, texte 1..1 400 o, bool ; Lueur : `enum` + 3 `COORD` facultatifs | 8 / 2 | fiche, mage, sort connu, pas d'incantation en cours, pas à terre, pas en véhicule, états durs, délai global, recharge, position et vie serveur, hook `castStarting` (fermé sur erreur), validation du sort (portée depuis la position serveur, hauteur, zones protégées, cible), mana (`casting.lua:185-213`) | la mana n'est que vérifiée ici, dépensée à la fin |
| `vava_magic:finish:<sort>` (11) | RPC | numéro d'incantation + propre au sort : 3 directions ±1,01 (projectiles), 2 (Vague), rien ailleurs | 8 / 2 | incantation à soi et au bon numéro, durée (−300 ms), déplacement, vie, à terre (`casting.lua:241-264`) ; `mana.spend` avant l'effet (`:271`) ; `finishing` interdit tout doublon (`:275`) | effets : positions serveur uniquement ; direction libre normalisée par le serveur |
| `vava_magic:projectileImpact` | RPC | lancer 1..2³¹, cible 0..65535, 3 `COORD` | 8 / 3 | lancer à soi et non résolu, **consommé avant toute vérification** (`projectiles.lua:173-176`) ; portée + 2 m, fenêtre de temps avec ping, angle 25° + virage ; rempart sur le trajet (`:183`) ; cible réelle (personnage en jeu, pas soi) à 2,5 m du point (`:187-189`) ; dégâts, états et éclats seulement par `combat.damage` (zones protégées, à terre) | voir MINEUR 1 |
| `vava_magic:lightOff` | RPC | `enum` light / anchors | 6 / 1 | ses propres lumières et orbes (`lueur.lua:185`) | |
| `vava_magic:lightColor` | RPC | `enum` des couleurs de la config | 6 / 1 | mage, niveau qui le permet (`lueur.lua:166-172`) | |
| `/magie <action> [id] …` | commande serveur (`RegisterCommand`, non restreinte) | arguments texte libres, convertis par `tointeger(tonumber())` | aucune | `Bridge.IsAdmin` à chaque appel (`admin.lua:284` → `bridge/server.lua:84-90` : console, sinon `vava_admin:can`, sinon ACE ; export en erreur = refus), cible = personnage en jeu | journal `vava_admin:log` pour chaque action ; voir MINEUR 2 et 5 |
| `isMage`, `spellLevel`, `mana` | exports serveur | types vérifiés (`api.lua`) | — | lecture seule | |
| registre `vava_magic:spells` | registre du core | `spells.validate` (`spells.lua:49-73`) ; schémas d'arguments compilés par le core en mode réseau (`any` refusé) | — | ressources serveur seulement | |
| objets `grimoire`, `registre` | `onUse` de l'inventaire | possession vérifiée par `vava_inventory` | débit de l'inventaire | `registers.open` : numéro lu dans la métadonnée de l'exemplaire utilisé (`registers.lua:143`) | |
| `core:character:loaded/unloading`, `core:player:dropped`, `core:character:deleted`, `core:module:ready`, `vava_admin:action`, `core:registry:added/removed` | hooks `after` écoutés | — | — | ménage complet au départ (`main.lua:56-66`) | |
| `ready`, `close`, `composer:send`, `offer:answer`, `naming:answer`, `confirm:answer`, `register:tear`, `grimoire:color`, `wheel:choose` | callbacks NUI | types vérifiés côté Lua ; `xpcall` (`client/nui.lua:72-80`) | — | chacun repasse par un RPC validé ; aucun effet serveur direct | `offer:answer` exige l'identifiant de l'offre affichée (`client/sigils.lua:75-77`) |
| `vava_magic:casting`, `glow`, `light`, `conditions`, `orb` | state bags | posés par le seul serveur (`world.lua:118`) | — | jamais lus côté serveur ; chez les autres clients, une lumière n'est dessinée que si chaque champ est un nombre dans les bornes de la config (`client/ambient.lua:115-130`) | un client qui forge le state bag de son propre ped n'obtient qu'un effet cosmétique |
| évènements serveur → client (24) | `RegisterNetEvent` client | chaque champ typé à la réception (`client/*.lua`) ; `DAMAGE` : part 0 < p ≤ 1 (`bridge/client.lua:114`) ; `PUSH` : vitesse ≤ 20 (`client/states.lua:168`) | — | — | un client ne peut pas les déclencher chez un autre |

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

1. `server/projectiles.lua:135-136` et `:187-189` — **contrôle d'axe neutralisé par le virage, cible d'impact non
   liée au verrou** — `limit = angleDeg + homing × écoulé` : avec une cible verrouillée au niveau 4-5 (Boule de feu
   70°/s), la limite dépasse 180° après ~2,3 s, dans la fenêtre de temps permise (`latest` ≈ 4,4 s + ping) ; l'impact
   peut alors être annoncé n'importe où dans la portée, sur n'importe quel joueur (`target` n'est jamais comparé à
   `launch.target`). Gain pour le tricheur : aucun au-delà de ce que le README accepte déjà (le serveur ne voit pas les
   murs : la visée libre, direction choisie par le client à la fin, atteint déjà quiconque est à portée) ; il reste une
   désynchronisation visible (le projectile vole vers A, B est touché) et une phrase du README inexacte
   (`README.md:369`, « dans l'axe annoncé »). Correction : refuser `target ~= 0 and launch.target and target ~=
   launch.target` ; borner le virage (`min(turned, 90)`) ou juger l'angle par rapport à la direction actuelle vers la
   cible verrouillée ; corriger la phrase du README.
2. `server/admin.lua:316` — **`/magie` sans limite de débit** — la commande est enregistrée non restreinte, tout client
   peut l'invoquer en rafale (hors chat, par le repli de commande de FiveM) ; chaque appel ouvre un thread, appelle
   l'export `vava_admin:can` et renvoie une ligne de chat. Effet : surcoût CPU minime, réponse à l'émetteur seul.
   Correction : un jeton par joueur (horodatage dans une table locale, un refus silencieux sous 2 s), comme le font les
   RPC.
3. `shared/text.lua:14` et `:24-31` — **nettoyage limité aux contrôles ASCII** — `text.clean` ne retire que `\0-\31` et
   `\127` : les signes invisibles ou de direction d'Unicode (U+200B, U+202E, C1 U+0080-U+009F, U+FEFF…) et les balises
   `~…~` de GTA traversent un murmure et un nom de contact. Le murmure est dessiné au-dessus des mains par un canal
   natif qui interprète ces balises (`client/ambient.lua:146-155`, `drawFragments` `:345`) et affiché à la cible en
   `textContent` (`web/js/murmurs.js:18`). Effet : cosmétique (message « vide », texte renversé, retours à la ligne ou
   couleur dans les fragments vus à 3 m) ; aucun gain, aucun HTML. Correction : la règle de `vava_voice` 1.2.2 (refus
   des signes de contrôle ou invisibles) dans `text.clean`, et `~` remplacé par une espace.
4. `server/casting.lua:255-264` — **véhicule non revérifié à la fin** — le début refuse `in_vehicle` (`:195`) mais la
   fin ne relit que déplacement, vie et à terre ; pendant une incantation longue (Murmure 4 à 6 s, 1,5 m de marge), un
   lanceur peut s'asseoir dans un véhicule adjacent et finir son sort installé. Gain : nul (un murmure, une lueur ou un
   rempart depuis un siège). Correction : `world.inVehicle(src)` → `'in_vehicle'` avant `mana.spend`.
5. `server/admin.lua:256-269` avec `:79-80` — **`donner … registre` : cible partie pendant l'attente de la base** —
   `registers.create()` bloque ; si le personnage visé part entre-temps, `bridge.AddItem` échoue (ligne orpheline dans
   `vava_magic_registers`), puis `details(target)` indexe `sheets.get(target)` qui vaut `nil` : erreur du thread,
   commande sans réponse. Conseil seulement, aucun client n'y accède. Correction : revérifier `sheets.get(target)`
   après chaque attente, créer la ligne après la remise réussie (ou la supprimer si `AddItem` refuse).
6. `client/sigils.lua:44-53` et `client/nui.lua:48-57` — **une offre de sigil prend le focus de la cible sans son
   accord** — `nui.open` ferme sans réponse la fenêtre déjà ouverte (un parchemin en cours d'écriture est perdu) et
   donne la souris à la page ; un voisin à 3 m peut le provoquer toutes les 30 s (offre ignorée) ou 60 s (refusée), une
   fois par couple. Borné depuis 2.6.0, mais c'est une interruption imposée en plein jeu (combat compris). Correction :
   une invite non modale (touche pour répondre) ou ne pas fermer une fenêtre existante tant qu'elle n'a pas répondu.
7. `bridge/server.lua:276-282` et `bridge/client.lua:107-116` — **sans `vava_health`, les dégâts sont déclaratifs** —
   `ApplyDamage` envoie un évènement à la victime, renvoie `true`, et `combat.damage` journalise une blessure que seul
   le client de la victime applique ; `Bridge.IsDowned` répond toujours « non ». Documenté (README, dépendances : « sans
   elle : la victime applique la blessure elle-même ») et déjà suivi par T-110 (T-006, « la vie GTA appartient au
   client »). Rappel : ne pas ouvrir la magie sans `vava_health` démarré avant elle.
8. `server/sheets.lua:316-333` avec `server/sigils.lua:279-296` — **brouillage et départ pendant l'attente de la
   base** — si le joueur se déconnecte pendant l'`UPDATE`, `bySigil[nouveau] = src` est posé pour un joueur parti et
   `scrambledAt` est écrit dans une fiche déjà déchargée (jamais sauvegardée) : à la reconnexion la recharge de 6 h est
   perdue, et la mana est pleine. Gain : brouiller plus tôt, pour 60 de mana. Correction : au retour de la base,
   vérifier `loaded[src] == sheet` avant d'écrire, sinon seulement la base.
9. Documentation et constantes — `docs/api.md:1003` annonce « La magie (2.6.2) » pour un fxmanifest en 2.6.3 ;
   `README.md:369` (voir le point 1) ; `shared/constants.lua` : `EVENTS.ADMIN` et `config.lua` :
   `errors.their_sigils_full` ne sont utilisés nulle part (vérifié par `grep`).

## Points solides

- Une seule porte réseau : 36 RPC à schéma strict et débit propre, zéro évènement serveur brut ; NaN, ±inf, tables
  géantes et chaînes longues sont arrêtés par le core avant le module ; la Murmure borne son texte en octets (1 400) puis
  en signes (300) et ses destinataires par le niveau.
- Rien de ce qui compte n'est cru du client : positions (`world.position`), vie, véhicule, à terre, cible verrouillée
  (`lockedPosition`), point visé (`zones.aimed` : portée depuis la position serveur, hauteur, zones protégées), direction
  normalisée par le serveur, impact validé puis unique par lancer ; dégâts, états, combinaisons, XP, mana, recharges,
  zones, remparts (positions des joueurs et véhicules lues côté serveur, plafonds 48 blocs / 60 zones) et orbes sont
  tous décidés et créés par le serveur.
- La mana est réservée à la fin, avant l'effet, et rendue si le sort refuse ; `finishing` et l'identité des incantations
  ferment les doublons ; chaque minuterie (états, lancers, offres, zones, remparts, lumières) revérifie l'identité de ce
  qu'elle touche, ce qui neutralise la réutilisation d'un numéro de joueur ; déconnexion, changement de personnage et
  arrêt du module nettoient tout (incantation, états et gel, offres, lancers, orbes, remparts, zones, journal écrit en
  une requête bornée).
- Les hooks `before` (`castStarting`, `stateApplying`) sont des gardes fermées : un handler en erreur refuse.
- SQL : onze requêtes (sigils 4, registres 5, journal 2), toutes paramétrées via `core.db` ; le lot du journal est
  construit par répétition de `(?, …)`, jamais par concaténation d'une valeur.
- NUI : aucun `innerHTML` ni `insertAdjacentHTML` ; tout texte passe par `textContent` (`web/js/ui.js:34`) ; icônes,
  couleurs et fichiers `.ogg` ne viennent que de la config, jamais du réseau ; chaque retour de page repasse par un RPC.
- Conseil : droit revérifié côté serveur à chaque commande, console admise, échec en français et code brut en console,
  chaque action au journal du Registre ; la fiche `vava_magic:sheet` est privée et seul le serveur sait l'écrire.

VERDICT : OK
