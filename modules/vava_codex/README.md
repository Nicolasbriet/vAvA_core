# vava_codex — le Codex

Toutes les commandes et toutes les touches du serveur dans un livre ouvert : classées par chapitre (un par module),
cherchées, composées par un formulaire selon le type de chaque argument, lancées. Signets, dernières pages et réglage
« rester ouvert » par personnage. Onglet des touches, avec la touche réellement liée par le joueur. Onglet de lecture
(1.5.0) : le chapitre « Premiers pas » et le guide des métiers, écrits côté serveur.

Le Codex ne contient aucune commande : il lit le registre `core:commands` du core, que chaque module remplit depuis
sa config (`server/commands.lua`, voir `docs/api.md` → « Registre des commandes »). Le serveur décide de ce que chaque
joueur voit (public, droit du Conseil, console en lecture seule) ; la ligne est lancée chez le joueur comme s'il
l'avait tapée, et chaque commande garde ses contrôles.

## Ce qui passe sur le réseau (1.2.0)

La page garde le contenu (entrées, chapitres, commandes non décrites) et les préférences d'une ouverture à l'autre. À
chaque ouverture, le client envoie leurs deux versions ; le serveur recalcule ce que le joueur peut voir avec ses droits
du moment, en prend l'empreinte (`shared/fingerprint.lua`) et ne renvoie que ce qui a changé. Mesuré hors jeu avec les
déclarations de tous les modules du dépôt (taille msgpack estimée) :

| Ouverture | Joueur (35 entrées) | Souverain (52 entrées) |
| --- | --- | --- |
| Avant 1.2.0, à chaque `F1` | 7,5 Ko | 16,9 Ko |
| Première ouverture, ou contenu changé | 7,5 Ko | 17,0 Ko |
| Ouverture suivante sans changement | 56 o | 56 o |
| Préférences seules changées (24 signets, 12 pages au plus) | 1 Ko au plus | 1 Ko au plus |

Le contenu repart dès qu'il change, quelle qu'en soit la cause : module démarré ou arrêté, rang donné ou retiré, droit
d'un rang, ACE, commande non décrite apparue. Les préférences repartent après un signet, un réglage, une commande
lancée (du Codex ou du chat) ou un changement de personnage. Les touches du joueur sont relues dans le jeu à chaque
ouverture. Le champ `vava_codex:prefs` est lu du seul serveur (`private`) : il ne part plus vers le client à chaque
commande lancée. Coût serveur d'une ouverture : environ 1 ms pour un joueur, 2 ms pour un Souverain (calcul du
contenu et de son empreinte, mesuré hors jeu), borné par `rateLimits.open`.

## Ouvrir le livre à un chapitre (1.4.0)

Export client `openAt(chapitre)` : ouvre le Codex par le même chemin que `F1` (RPC `vava_codex:open`, empreintes,
préférences), puis la page ouvre le chapitre demandé dans l'onglet des commandes (recherche vidée). Rend `true`
(ouverture lancée) ou `false, code` :

| Code | Cas |
| --- | --- |
| `invalid_chapter` | pas une chaîne, vide, plus de 64 octets, ou hors du motif des identifiants du core (`^[%w_%-%.:]+$`) |
| `no_character` | aucun personnage chargé |
| `busy` | livre déjà ouvert, menu pause, ou une autre interface a le focus (`IsNuiFocused()`) |

Le chapitre part dans le message `open` de la page (`focus`, absent pour `F1` et `/codex`) ; rien d'autre ne change
sur le réseau. Un chapitre inconnu laisse le livre à son index, sans message. Aujourd'hui l'identifiant d'un chapitre
est le nom du module qui déclare ses commandes : `openAt('vava_inventory')` ouvre le chapitre Inventaire.

Depuis 1.5.0, l'identifiant est résolu dans cet ordre : page de lecture (onglet Lecture, cette page), chapitre de
lecture (onglet Lecture, première page du chapitre), chapitre de commandes. `vava_arrival` ouvre le Codex à son
`codex.chapter` (`premiers_pas`) à la première venue d'un personnage : le livre s'ouvre sur Lecture, chapitre
« Premiers pas », page « Vivre à Eldoria ». L'export `openAt` et le champ `focus` du message `open` n'ont pas changé.

## Pages de lecture (1.5.0)

Un onglet **Lecture**, premier des trois (`F1` ouvre toujours le livre sur Commandes, comme avant) : un vrai livre
pour le nouveau venu, en trois chapitres et douze pages. Chaque page renvoie vers les autres pages et vers les gens
d'Eldoria ; les touches qu'elle cite sont celles que le joueur a réellement liées.

| Chapitre | Pages (identifiant, module requis) |
| --- | --- |
| Premiers pas (`premiers_pas`) | Vivre à Eldoria (`bienvenue`, aucun), Se parler (`se_parler`, `vava_chat`), Troquer et partager (`troquer`, `vava_inventory`), La faim et la soif (`faim_soif`, `vava_needs`), À terre et soins (`a_terre`, `vava_health`) |
| Les métiers (`metiers`) | Apprendre un métier (`apprendre`, `vava_skills`), La récolte (`recolte`, `vava_gathering`), L'artisanat (`artisanat`, `vava_crafting`), L'agriculture (`agriculture`, `vava_farming`) |
| Le royaume (`royaume`) | La magie (`magie`, `vava_magic`), Le Conseil (`conseil`, `vava_admin`), Siéger au Conseil (`conseil_sieger`, `vava_admin`, **réservée au Conseil**) |

**Où vit le texte.** Dans `content/*.lua` (`chapters.lua` : la graine et les chapitres ; `premiers_pas.lua`,
`metiers.lua`, `royaume.lua` : les pages), chargés comme `server_scripts` : jamais téléchargés par les clients, ni pris
dans `config.lua` (partagé avec le client). Au démarrage, chaque page est analysée et validée (`shared/pages.lua`) ;
une page fautive est écrite en console (`page « … » refusée : … (ligne N)`) et écartée seule, les autres restent. Un
lien vers une page refusée, ou vers une page que tous les lecteurs de la page qui le porte ne peuvent pas lire (page
du Conseil depuis une page publique, page à droit depuis une page sans ce droit), fait refuser la page qui le porte.

**Format d'une page** (table plate) :

| Champ | Règle |
| --- | --- |
| `id` | minuscules, chiffres, `_`, commence par une lettre, 32 octets au plus, jamais `vava…` ; unique parmi pages et chapitres |
| `chapter`, `order` | chapitre déclaré dans `chapters.lua` ; rang de 0 à 999 (tri, puis `id`) |
| `title`, `summary` | 48 et 120 octets au plus, sans `<`, `>` ni caractère de contrôle ; le résumé s'affiche sous le titre et se cherche |
| `audience`, `permission` | `'player'` (tous) ou `'admin'` (Conseil) ; droit `vava_admin` facultatif, seulement avec `'admin'` ; une page à droit est cachée tant que `vava_admin` n'est pas démarré (aucun repli ACE pour elle) |
| `requires` | `''` ou un nom de ressource : la page n'apparaît que si elle est démarrée |
| `body` | texte entre `[==[` et `]==]` (les `]]` des jetons n'y ferment rien), 6 000 octets au plus |

Le corps : paragraphes séparés par une ligne vide (les lignes d'un paragraphe se joignent) ; `## Intertitre` ;
`- élément` et `1. élément` (deux espaces en tête de ligne continuent l'élément) ; `> note` (encadré) ; jetons
`[[F1]]` (touche écrite telle quelle), `[[touche:vava_inventory]]` (touche liée par le joueur à cette entrée du
registre `core:commands`), `[[commande:me]]`, `[[commande:metiers voir]]` (lien vers la ligne de l'onglet Commandes),
`[[page:troquer]]`, `[[page:troquer|le troc]]` ; `*italique*`. Interdits : `<`, `>` ailleurs qu'en tête de ligne, les
caractères de contrôle (tabulation comprise). Bornes : 40 blocs, 12 éléments par liste, 40 jetons, 1 200 octets par
paragraphe ou note, 400 par élément, 80 par intertitre ; la réponse envoyée (`{ id, hash, body }`) pèse 7 500 o au
plus, hors enveloppe du core. Ces bornes sont en tête de `shared/pages.lua` (servi au seul serveur) ; le client n'en
relit que l'identifiant (`READING.MAX_ID`, `READING.ID_PATTERN` de `shared/constants.lua`).

**Une règle change, la page se relit.** Chaque page dit le jeu tel qu'il est codé. Au-dessus de chaque page, un
commentaire liste ses **sources** (modules et réglages) : quand l'une change, relire la page. Les nombres réglables en
config (durées, distances, quantités) ne sont jamais cités ; seuls les nombres fixés par le jeu le sont (niveaux 0 à
100, paliers des rangs). Les touches et commandes sont citées par leur nom au registre : `tests/spec/codex_pages_spec.lua`
échoue si l'une est renommée, et la commande de console `vava_codex_pages` liste celles qui manquent au registre du
serveur en marche.

**Réseau.** L'index des pages visibles (titre, résumé, empreinte : ~1,6 Ko pour un joueur avec la graine provisoire,
2,3 Ko visés avec les textes définitifs) part avec le contenu du Codex, dans la même empreinte : il ne repart que s'il
change (page modifiée, module arrêté, rang changé). Le texte d'une page part à la demande, quand le joueur l'ouvre
(RPC `vava_codex:page`, au seul joueur, `rateLimits.page` : 6 d'affilée puis 1 par seconde), et la page le garde tant
que son empreinte ne change pas : un joueur ne paie que ce qu'il lit. La première ouverture d'une session peut dépasser
8 Ko et partir en latent (préavis du core, rien à faire). Aucun évènement, aucun GlobalState, aucun state bag.
Quand l'Atelier éditera les pages à chaud (T-101 et suivantes), l'index devra avoir sa propre empreinte : aujourd'hui
il est dans celle du contenu, et une page changée renverrait tout le contenu du Codex à chaque joueur.

**Droits.** Index filtré à chaque ouverture ; le RPC revérifie à chaque appel (module requis démarré ; page du Conseil :
membre, et son droit s'il y en a un) et répond `unknown_page` pour une page absente, refusée, réservée ou arrêtée :
rien ne trahit l'existence d'une page réservée. `reading.enabled = false` ferme l'onglet et le RPC (`disabled`).

| Réglage | Défaut | Rôle |
| --- | --- | --- |
| `reading.enabled` | `true` | onglet Lecture, index et RPC `page` |
| `reading.errors` | textes français | texte de chaque code d'erreur du format (console ; l'Atelier plus tard) |
| `rateLimits.page` | `{ capacity = 6, refillPerSecond = 1 }` | RPC `vava_codex:page`, par joueur |
| `pagesCommand` | `vava_codex_pages` | commande de console : bilan des pages |
| `messages.pages` | textes | lignes de la console (chargement, refus, bilan, introuvables) |

Plus tard (T-101 et suivantes), l'Atelier éditera chapitres et pages : `content/*.lua` sera la graine importée, la
validation et les codes d'erreur sont déjà ceux de `shared/pages.lua` et `reading.errors`.

## Le Codex en panneau (1.6.0)

La bannière du royaume (`vava_pause`, menu pause) ouvre le Codex **dans son panneau**, à droite de ses rubriques, sans
copie du livre : c'est toujours la page de `vava_codex` qui le dessine, dans un rectangle donné par l'hôte, sans voile.

| Export client | Retour |
| --- | --- |
| `openDocked(chapitre\|nil, { left, top, width, height })` | `true` (ouverture lancée) ou `false, code` : `not_allowed` (appelant autre que `docked.host`), `invalid_chapter` (même motif qu'`openAt`), `invalid_rect`, `no_character`, `busy` (livre ouvert ou en cours d'ouverture, menu de GTA ouvert) |
| `closeDocked()` | `true`, ou `false, 'not_allowed'` — referme le livre s'il est en panneau, ou annule son ouverture en cours |

- Rectangle en pourcentages de l'écran (`vw`, `vh`), validé par `shared/dock.lua` (pur) : nombres finis, bord gauche
  et haut ≥ 0, largeur et hauteur ≥ 10, rien au-delà de 100 ; aucun autre champ.
- Même chemin que `F1` (RPC `vava_codex:open`, empreintes, préférences) ; le message `open` de la page porte `dock`
  (le rectangle) en plus. `openDocked` ne se refuse pas parce qu'une interface a le focus : l'hôte le rend juste avant.
- Crochet client **`vava_codex:closed`** (`after`, `{ docked, reason }`) à chaque fermeture du livre, en panneau ou
  non, échec de l'ouverture compris : `reason` = `close` (Échap, `closeDocked`, `F1`), `run` (une commande lancée a
  fermé le livre : l'hôte se ferme aussi, la commande ouvre peut-être une interface), `failed` (réponse du serveur
  absente ou refusée ; en panneau, aucune notification : l'hôte dit que le Codex est fermé), `unloaded`, `stopped`.
- Arrêt de l'hôte livre en panneau ouvert : le livre se referme, souris et clavier rendus au jeu.

| Réglage | Défaut | Rôle |
| --- | --- | --- |
| `docked.host` | `'vava_pause'` | seule ressource qui peut ouvrir ou fermer le livre en panneau |

Rien ne change sur le réseau (le rectangle ne quitte pas le client). Page : classe `is-docked`, livre placé par
`--dock-left/top/width/height`, barre d'aide masquée ; hors jeu, `web/index.html?dock=1`.

## Prérequis

`vAvA_core` ≥ 0.7.0 et `vava_ui` ≥ 1.0.0 (polices, grain et ornements du livre, par `nui://vava_ui/…` ; déclaré en
dépendance, à ne jamais arrêter sur un serveur ouvert). Facultatifs : `vava_admin` (rangs et droits du Conseil ; sans lui, ACE `vava_codex.staff` et les
ACE déclarés avec les commandes), `vava_hud` (notifications), `vava_chat` (dernières pages des commandes tapées).

Touche par défaut (`keys.open`, `F1`) : elle est citée par l'écran de chargement et par l'accueil. La changer oblige à
retoucher les conseils de `modules/vava_loading/web/js/strings.js` et `messages.codexHint` de `vava_arrival`.

## Fichiers

| Fichier | Rôle |
| --- | --- |
| `config.lua` | touche (`F1`) et commande (`/codex`), bornes des signets et dernières pages, commandes non décrites, ACE, rayon des joueurs proposés hors du Conseil (`players.nearbyRadius`), débits, textes |
| `bridge/server.lua` | seul point de contact avec le core et les modules : joueurs (tous, ou les seuls proches), Conseil, exports `codexList`, commandes du jeu |
| `server/catalog.lua` | entrées visibles d'un joueur, chapitres, non décrites, valeurs d'un argument |
| `shared/prefs.lua` | logique pure : préférences ramenées aux maximums de la config (testée : `tests/spec/codex_prefs_spec.lua`) |
| `shared/fingerprint.lua` | logique pure : empreinte d'une valeur (version du contenu et des préférences), réponse à l'ouverture (testée : `tests/spec/codex_fingerprint_spec.lua`) |
| `shared/dock.lua` | logique pure, lue par le client : rectangle du livre en panneau (1.6.0 ; testée : `tests/spec/codex_dock_spec.lua`) |
| `shared/pages.lua` | logique pure : analyse d'un corps de page en blocs, validation des chapitres et des pages, construction (liens, tri, empreinte, poids), références citées (testée : `tests/spec/codex_pages_spec.lua`) |
| `content/*.lua` | pages de lecture : graine et chapitres (`chapters.lua`), pages de chaque chapitre ; serveur seul |
| `server/reading.lua` | chargement des pages, index visible d'un joueur, page demandée (droits revérifiés), commande `vava_codex_pages` (testé : `tests/spec/codex_reading_spec.lua`) |
| `server/prefs.lua` | champ de personnage : signets, dernières pages, réglage |
| `server/main.lua` | déclaration du module, RPC |
| `client/keys.lua` | touche réellement liée par le joueur (lue dans le jeu) |
| `client/main.lua` | ouverture, relais des gestes, lancement par `ExecuteCommand`, exports `noteCommand`, `openAt`, `openDocked` et `closeDocked`, crochet `vava_codex:closed` |
| `web/` | le livre : `index.html` s'ouvre dans un navigateur depuis le dépôt (`?staff=0` : vue d'un simple joueur ; `?focus=<chapitre>` : ouverture par `openAt`, par exemple `?focus=vava_gathering` ; option `--allow-file-access-from-files` pour les polices), avec les données simulées de `web/dev/devmock.js` (jamais livré) |

## Tests en jeu

1. `F1` : le livre s'ouvre, le curseur est dans la recherche. `Échap` le ferme. `/codex` fait de même. Changer la
   touche dans Paramètres › Raccourcis › FiveM : la nouvelle touche ouvre le Codex et l'onglet Touches la montre.
2. En simple joueur : seules les commandes publiques (chat, signalement, magie, Chancellerie…) et les touches ; aucun
   sceau « Conseil », aucune section « Non décrites ».
3. Au Conseil (`vava_conseil <compte> souverain`) : les commandes du Conseil apparaissent avec leur sceau, celles de la
   console grisées et non lançables, la section « Non décrites » en bas de « Tout ».
4. Taper « vital » : deux résultats, « État des zones » (sa description parle de vitalité) puis « Fixer la vitalité
   d'une zone » ; la première est choisie d'office, `↓` choisit la seconde (taper « fixer la vital » ne garde qu'elle).
   `Entrée` passe au premier champ ; la liste des zones vient du serveur (vraies zones) ; choisir. La vitalité est vide
   (« Il manque « vitalité ». », « Lancer » grisé) tant qu'elle n'est pas choisie : régler le curseur ou taper une
   valeur, `Entrée` : la commande part, le chat répond, la ligne monte dans « Dernières pages ».
5. `/metiers niveau` : la liste des joueurs en jeu porte les noms de personnage ; la liste des compétences vient du
   registre ; le niveau (« de 0 à 100 ») n'a aucune valeur d'office ; une valeur tapée hors bornes ou à virgule part
   ramenée dans les bornes et arrondie (150 → 100, 42,7 → 43) ; la ligne composée s'écrit en direct.
   En simple joueur, `/mp` : la liste ne propose que les joueurs à moins de 5 m (`players.nearbyRadius`), dans la même
   instance ; un joueur plus loin n'y est pas, mais son numéro tapé à la main reste accepté. Au Conseil : tous.
6. Signet depuis le détail : un ruban apparaît en haut du livre ; cliquer le ruban ouvre la commande ; au-delà de
   `favorites.max`, refus propre. Abaisser `favorites.max` ou `recent.max` sous ce qu'un personnage a déjà : à
   l'ouverture suivante ses listes sont tronquées (premiers signets, dernières pages les plus récentes) et « Lancer »
   fonctionne.
7. Réglage « Rester ouvert » décoché : « Lancer » ferme le Codex. Coché : il reste ouvert, sauf pour une commande qui
   ouvre une interface (`/conseil`, `/grimoire`, `/catalogue`…), qui le ferme d'abord.
8. Onglet Touches : toutes les touches par chapitre ; cliquer une touche montre son cabochon en grand.
9. Taper une commande dans le chat (`/me …`) : elle apparaît dans « Dernières pages » à la prochaine ouverture (greffe
   vava_chat). Taper deux fois `/mp <n°> …` : une seule ligne « Message privé » (seule une sous-commande déclarée,
   comme `/metiers niveau …`, est retenue ; rien du message n'est gardé).
10. Se déconnecter puis revenir : signets, dernières pages et réglage retrouvés (champ de personnage).
11. Livre ouvert : `restart vava_codex` : le livre disparaît, souris et clavier reviennent au jeu ; `F1` le rouvre.
12. Ouvrir, fermer, rouvrir sans rien changer : le livre est le même (signets, dernières pages, touches) et le serveur
    ne renvoie que deux versions (compteur réseau ou `netgraph`). Donner un rang (`vava_conseil <compte> senechal`), ou
    `restart` d'un module qui déclare des commandes : à l'ouverture suivante, le contenu change aussitôt.
13. `openAt` (1.4.0) : avec `vava_arrival`, `codex.chapter = 'vava_inventory'` et un nouveau personnage, le livre
    s'ouvre seul au chapitre Inventaire, clavier et souris pris, `Échap` le ferme. Avec un chapitre inconnu : le livre
    s'ouvre à son index, sans erreur en F8. `F1` ensuite : le livre s'ouvre là où il a été laissé, comme d'habitude
    (aucun chapitre imposé). Détail : `docs/tests/accueil.md`.
14. Pages de lecture (1.5.0) : console `pages de lecture : 12 chargées, 0 refusées` ; onglet Lecture en trois chapitres
    (onze pages en simple joueur, douze au Conseil avec le sceau sur « Siéger au Conseil ») ; liens, cabochons des
    touches du joueur, commandes qui ouvrent leur ligne ; nouveau personnage : le livre s'ouvre sur « Vivre à
    Eldoria ». Procédure complète : `docs/tests/codex.md` § 16.
15. Codex en panneau (1.6.0) : bannière (`Échap`) → Codex : le livre s'ouvre à droite de la bannière, sans voile ;
    recherche, chapitres et lecture fonctionnent ; `Échap` jusqu'à fermer le livre rend la main à la bannière ; une
    commande qui ouvre une interface ferme livre et bannière. Procédure complète : `docs/tests/pause.md` § 4.

Hors jeu : `tests/spec/codex_prefs_spec.lua`, `codex_dock_spec.lua`, `codex_fingerprint_spec.lua`, `codex_pages_spec.lua` (format, bornes,
graine du dépôt : aucune page refusée, touches et commandes citées connues, aucun mot moderne, poids réseau),
`codex_reading_spec.lua` (chargement, index selon les droits, page demandée, console) ; essais de la page :
`web/dev/essais.js` (node).

## À vérifier en jeu

- Lisibilité d'une page longue dans CEF (défilement de la page de droite, police, liens au survol).
- Cabochon d'une touche de souris (`[[touche:vava_magic_viser]]`) : nom montré par `GetControlInstructionalButton`
  (sinon `keyDisplay`).
- Codex en panneau (1.6.0) : focus rendu par la bannière puis pris par le livre sans image où ni l'un ni l'autre n'a la
  main ; ordre des deux pages à l'écran (le rectangle ne recouvre ni la bannière ni sa plaque).
- Première ouverture d'un joueur en latent (≈ 10 Ko avec les textes définitifs) : aucune attente visible à l'arrivée
  d'un nouveau venu.
