# vava_atelier — l'Atelier du Conseil

Le Conseil façonne le royaume depuis le jeu : `F9` (ou `/atelier`) ouvre un livre de travail où chaque membre ne voit
que les ateliers que son rang lui ouvre (le monde pour un Sénéchal, tout pour un Souverain), ses brouillons et le
journal des derniers changements. Chaque réglage s'y présente en mots du jeu, avec une phrase d'aide, et le serveur dit
tout de suite ce qui ne va pas. Les joueurs ne voient jamais l'Atelier ; ils en voient les effets.

**Version 1.0.0 (T-100) : le socle.** Cadre, accueil, droits, formulaire générique, « Vérifier », journal.

**Version 1.1.0 (T-101) : les définitions gardées.** Un atelier dont le module déclare `apply` et `remove` est
**gardé** : chaque fiche vit en base (`vava_atelier_definitions`, une ligne par version), se prépare en brouillon,
s'essaie chez son seul auteur, se publie d'un clic après un résumé (« 2 points ajoutés, 1 retiré »), se retire du
royaume et se rétablit depuis son historique. La config du module est la **graine** : au premier démarrage, chaque
entrée devient la version 1 ; ensuite **la base fait foi**. Archives JSON et retour à l'original par
`/atelier_archives`. Les ateliers réels des modules (agriculture, artisanat…) viennent avec T-103 à T-106 ; en
attendant, l'accueil les montre « Bientôt ». Un atelier sans `apply` reste **en lecture** (comportement de 1.0.0 :
« Vérifier » seul).

**Version 1.3.0 (T-102) : l'outil de placement.** Une fiche qui a un lieu se pose **en jeu** : le membre vise depuis la
caméra, voit l'aperçu vert ou rouge avec sa raison, tourne à la molette, pose d'un clic, annule avec `Ctrl+Z` ; un cercle
se règle à la molette, un tracé se dessine sommet par sommet. Le serveur revérifie chaque pose (position lue par lui,
portée, règles du type, module) et n'écrit qu'un brouillon. « Tester » d'un atelier joué en jeu (la récolte) range la
page : le membre essaie seul, `F9` le ramène. Premier atelier réel : la récolte (`vava_gathering` 1.8.0).

**Version 1.4.0 (T-157) : le code du Conseil livré au seul Conseil.** Rien ne change pour un habitant, sinon qu'il ne
télécharge plus les registres du Conseil : il ne reçoit qu'une **amorce** (touche et commande, notifications, réponse de
`/atelier_archives`, chargeur, page vide). L'outil de placement, la séance, le relais et la page entière partent chez
un membre la première fois qu'il ouvre l'Atelier d'une version (« On apporte les registres de l'Atelier : un
instant… », quelques secondes une fois), puis sont gardés dans son stockage local. Voir « Code livré au seul Conseil ».

## Ce qu'un module déclare

Un module **n'écrit aucune interface** : il déclare un éditeur au registre `vava_atelier:editors` (clé
`<ressource>:<nom>`, un module ne déclare que sous son nom) avec ses types, un formulaire par type et cinq fonctions :
`index(kind)` (ce qui est en vigueur), `read(kind, id)` (valeurs d'une entrée, table plate), `validate(kind, data, ctx)`
(seul juge des règles du jeu), et, facultatives, `options(source)` (listes de valeurs) et `compare(kind, data)`
(encadré « Pour comparer »). Le formulaire générique dessine huit widgets : `slider`, `segmented`, `select`, `toggle`,
`text`, `duration`, `item`, `model`. Contrat complet, bornes et exemple : `docs/api.md` → `vava_atelier`, et
`examples/vava_example_atelier`.

Le module ajoute ses éditeurs dans son `setup` si `core.registry.exists('vava_atelier:editors')`, **et** au hook
`vava_atelier:editorsReady` (redémarrage de l'Atelier : le registre et ses entrées disparaissent avec lui).

Pour être **gardé** (T-101), il déclare en plus `apply(kind, def, info)` et `remove(kind, id, info)` (rechargement à
chaud, tout ou rien, idempotents), et s'il le veut `trial` / `endTrial` (montrer une fiche à son seul auteur), `diff`
(résumé d'un changement), `format` et `upgrade` (montée d'une data d'un format plus ancien), `validateLot(lot, ctx)`
(le lot entier d'une publication groupée, data et lieux compris, **une fois** ; `validate` n'en reçoit que des
références légères dans `ctx.bundle`, sans data ni lieu). `index` et `read` ne
servent plus qu'à la graine et à la synchronisation ; `read(kind, id, { original = true })` et
`index(kind, { original = true })` rendent l'original de la config (retour à l'original). Contrat d'aller-retour :
après `apply(kind, def)`, `read(kind, def.id)` rend la même data, le même `place`, le même `parent`.

### Outil de placement (1.3.0, T-102)

Un type qui déclare `placement` (`point`, `oriented`, `circle`, `polygon` ; `door` attend T-106) peut ajouter des
**règles de placement** déclarées (données, jugées par la même logique pure côté client pour l'aperçu et côté serveur
pour la décision : `shared/placerules.lua`) et de quoi poser des enfants en série :

| Clé (par type) | Rôle |
|---|---|
| `rules.inside = { slack }` | dans le lieu du parent (cercle : rayon + `slack` ; tracé : dedans ou à `slack` m du bord) ; type à parent placé seulement |
| `rules.spacing` | au moins n m au sol des autres fiches du même type et du même parent (retirées et la fiche elle-même ignorées) |
| `rules.radius = { min, max, default }` | cercle : rayon permis, et rayon du premier tracé |
| `rules.vertices = { min, max }` | tracé : sommets permis (dans `config.place.polygonPoints`) ; un tracé qui se croise est toujours refusé |
| `template` | type à parent : champs du bloc « Prochain … à poser » ; leurs valeurs partent avec chaque clic |
| `autoTitle` | type à parent : titre d'un enfant nouveau = libellé du choix + premier numéro libre (« Chêne 4 ») |
| `hintField`, `hintFormat` | indice d'une ligne de la liste des enfants : un texte, ou `{ one, many }` accordé (« 1 récolte », « 3 récoltes ») |
| `ghost = { field, models? }` | modèle fantôme suivi d'un champ (avec son apparence : « chêne de GTA, modèle provisoire ») |

Par éditeur : `trialPlay` (l'essai se joue en jeu), `texts.banner` (titre du bandeau du volet, « Atelier de la
récolte ») et `placeCheck(kind, place, ctx)` (facultatif : ce que les règles
déclarées ne savent pas dire, chevauchement de deux zones par exemple). Le placement n'appelle pas `validate` : celui-ci
reste juge de tout, lieu compris, à l'essai et à la publication. Contrat complet : `docs/api.md` → `vava_atelier`,
« Outil de placement ».

**Touches de la visée** (contrôles du jeu, indépendants de la disposition du clavier, sauf `Z`) : clic « Poser ici »
(cercle, point, point orienté ; tracé : ajouter un sommet) ; molette « Tourner » (±15°) ou « Rayon » (±5 m), `Maj`
tenue pour le pas fin (±1°, ±0,5 m) ; clic droit « Choisir un point » (le plus proche à 2,5 m : le clic suivant le
déplace ; clic droit de nouveau : le lâcher) ou un sommet ; `Ctrl` + `Z` « Annuler » (commande-touche
`+vava_atelier_annuler` sur `Z`, suit la disposition du clavier, AZERTY compris ; déclarée au registre `core:commands`) :
sommet non envoyé retiré, création abandonnée (`discard`), déplacement rendu (`place` avec le lieu d'avant), 20 gestes au
plus ; `Entrée` « Fermer le tracé » ; `Échap` « Quitter » (tracé commencé : un second appui sous 2 s l'abandonne). La
bannière de `vava_pause` est bloquée pendant la visée, `Échap` et `P` du jeu sont neutralisés. Refus sur place : pas de
séance, page de côté, personnage non apparu, en véhicule ou à cheval (« Descendez de votre monture pour placer. »).

**Ce que voit le membre, lui seul** : l'anneau du parent, l'anneau ou le tracé du candidat, le fantôme du candidat
(objet local, translucide, sans collision), les étiquettes des 12 éléments les plus proches à 40 m (« nouveau » en vert,
« retiré » en rouge, l'élément choisi en bleu), et les fantômes des enfants pas encore publiés à 60 m (12 au plus).
Étiquettes dessinées par le jeu (décision du 31 octobre 2026). Tout disparaît en quittant la fiche, en fermant
l'Atelier, au déchargement et à l'arrêt de la ressource.

**Essai joué** (`trialPlay`) : après « Tester », la page se range (un bandeau seul : « Mode essai : vous seul voyez ces
points · F9 : revenir à l'Atelier »), le jeu reprend la main, la séance reste ouverte ; `F9` (ou `/atelier`) rend la page
telle qu'elle était. Le hook client `vava_atelier:state` dit `{ open = false, suspended = true }` pendant ce temps.

## Cycle de vie d'une fiche gardée

| Statut | Qui le voit | En jeu |
|---|---|---|
| brouillon | les membres qui ont le droit de l'atelier ; seul son tenant l'écrit | rien |
| essai | idem | chez l'auteur seul (`trial` du module) |
| publiée | le Conseil | chez les joueurs concernés (`apply`, diffusion du module) |
| archivée | le Conseil (historique) | rien ; rétablissable (sauf une version de retrait) |

- **Une version prend son numéro à la publication** ; un brouillon n'a pas de numéro (l'essai montre celui qu'il
  prendrait : « Essai, version 4 »).
- **Un brouillon par fiche**, tenu par son auteur ; tout membre du même droit peut le **reprendre** (journalisé, l'ancien
  tenant prévenu). Une révision (`rev`) sur chaque écriture et un jeton sur chaque résumé : on publie exactement ce qu'on
  a lu.
- **Enregistrer** : le brouillon est gardé dès que sa forme est juste ; les règles du module sont alors des
  avertissements, exigées à l'essai et à la publication. Une fiche nouvelle prend un identifiant tiré de son nom
  (« Forêt de Brume » → `foret_de_brume`), jamais changé.
- **Essai** : un par membre, fini à la fermeture de l'Atelier, au départ, au bout de `trial.maxMinutes`, à la reprise du
  brouillon, au retrait de l'atelier, au redémarrage.
- **Publier** : le lot comprend la fiche et les brouillons de ses fiches enfants du même tenant (une transaction, une
  ligne de journal). La base d'abord, puis le module ; un refus du module rend la base comme avant et resynchronise
  l'atelier. Une fiche identique à la publiée ne se publie pas.
- **Revenir à une version** : une copie devient une nouvelle version (« rétablie de la version 2 »). Rétablir une fiche
  retirée rétablit aussi les enfants retirés avec elle.
- **Retirer du royaume** : un brouillon de retrait, publié comme le reste ; publier le retrait d'une fiche parent retire
  aussi ses enfants publiés. Toutes les versions restent.
- **Graine et synchronisation** : à chaque déclaration d'un atelier gardé, un fil importe en version 1 chaque entrée du
  module jamais vue en base (une fiche connue, même retirée, n'est jamais réimportée sans commande), puis rapproche le
  module de la base (empreintes : `apply` de ce qui diffère, `remove` de ce qu'il a sans version publiée). L'atelier
  répond « L'atelier se met à jour » pendant ce temps.

## Commande `/atelier_archives`

Conseil et console (auteur « Console »), 2 s entre deux commandes d'un membre et une seule à la fois (console
comprise), réponse dans son chat ou la console. Un membre doit avoir son personnage chargé et un nom au Registre :
rien ne s'écrit sans son nom au journal (une ligne refusée par le journal est écrite en console).

| Action | Droit | Effet |
|---|---|---|
| `etat [atelier]` | Conseil (ateliers visibles) | publiées, brouillons, essais, retirées, « à synchroniser », refusées en jeu |
| `original <atelier>` | Souverain | résumé du retour à l'original de tout l'atelier (fiches changées, rétablies, nouvelles ; les fiches créées dans l'Atelier ne sont pas touchées), puis `confirmer` |
| `original_fiche <atelier> <type> <fiche>` | droit de l'atelier | la même chose pour une fiche (« Identique à l'original : rien à faire ») |
| `exporter <atelier\|tout>` | Souverain | écrit `echanges/atelier_<date>_<heure>.json` (versions publiées seulement, lues par paquets de 25 ; poids brut compté avant tout décodage) ; un export par minute, tous membres confondus ; refusé au-delà de 4 Mo (l'import le refuserait : copier les ateliers un par un) |
| `importer <fichier>` | Souverain | lit, contrôle, résume par atelier (tout ou rien par atelier), puis `confirmer` |
| `confirmer` | celui de l'opération, relu | l'exécute si elle a moins de 60 s et que rien n'a changé depuis le résumé (revu pour chaque atelier juste avant de l'écrire) |

Un retour à l'original ou un import publie de nouvelles versions (`origin` seed ou import), n'en retire jamais, garde
les brouillons, puis le module les applique et l'atelier est resynchronisé.

## Règles (config.lua, config_client.lua, config_conseil.lua)

Depuis 1.2.0 (T-132), les réglages sont dans des fichiers distincts et chacun n'est écrit qu'une fois :
`config_client.lua` (marqués **(client)** ci-dessous) porte ce que lit le client de chaque joueur (l'amorce) et que relit
le serveur ; depuis 1.4.0 (T-157), `config_conseil.lua` (marqués **(conseil)**) porte ce que lit le seul client d'un
membre du Conseil (outil de placement, textes de la séance) : il part dans le paquet du Conseil, jamais chez un
habitant, et le serveur le lit aussi (en tête des `server_scripts`, avant `config.lua`) ; il ne contient **rien de
secret**. `config.lua` porte tout le reste, lu par le seul serveur. Chacun complète la table ouverte par
`config_client.lua` sans réécrire une clé posée avant lui.

| Clé | Défaut | Rôle |
|---|---|---|
| `keys.open` / `labels.open` / `command` **(client)** | `F9` / « Ouvrir l'Atelier du Conseil » / `atelier` | touche (réglable par le joueur, Raccourcis › FiveM), son libellé et commande |
| `families` | monde (`metiers`), société (`staff`), arts (`staff`) | familles de l'accueil, dans l'ordre ; `floor` : droit minimal d'un atelier de la famille |
| `rights.allowed` | `{ 'metiers', 'staff' }` | droits qu'un éditeur peut demander, du plus faible au plus fort ; tout autre droit est refusé à la déclaration |
| `rights.open` | `metiers` | droit pour ouvrir l'Atelier |
| `rights.overrides` | `{}` | `['<éditeur>'] = 'metiers' \| 'staff'` : choix du porteur du projet, prime sur le droit déclaré et le plancher |
| `upcoming` | dix cartes | ateliers attendus, montrés « Bientôt » tant que leur éditeur n'est pas déclaré |
| `limits.editors` | 32 | éditeurs au plus |
| `limits.indexEntries` | 1 000 | entrées gardées d'une liste de module (au-delà : tronqué, avertissement console) |
| `limits.pageSize` / `optionsPage` / `searchHits` | 50 / 30 / 20 | tailles des pages et de la recherche |
| `limits.optionsMax` | 500 | valeurs gardées d'une source de module |
| `limits.cacheMs` | 5 000 | durée de vie d'une liste ou d'une source lue chez un module |
| `limits.slowCallbackMs` | 50 | fonction d'un éditeur signalée en console au-delà |
| `limits.refusalLogMs` | 60 000 | une ligne de refus (droit) en console au plus par joueur et par intervalle |
| `limits.descriptorBytes` | 32 768 | poids au plus du descripteur d'un atelier (codage canonique) ; au-delà, l'atelier est refusé au chargement, retiré du registre, avec une ligne en console |
| `limits.busyMs` | 10 000 | verrou d'une lecture (`busy`) tenu au-delà, par un appel resté en suspens : repris, avec une ligne en console |
| `journal.retentionDays` | 365 | lignes plus anciennes retirées au démarrage |
| `journal.homeLines` / `pageLines` | 5 / 25 | lignes de l'accueil, d'une page du journal entier |
| `journal.flood` | 60 lignes / 10 s | écritures au plus par ressource appelante (export `journal`) |
| `journal.mirror` | `true` | recopie de chaque ligne au journal du Registre |
| `rateLimits.*` | voir le fichier | débits des RPC : `home`, `editor`, `read`, `check`, `lookup`, `close` ; T-101 : `write` (4, 0,5/s), `preview` (5, 1/s), `publish` (2, 0,2/s) |
| `definitions.maxBytes` | 16 384 | poids au plus d'une fiche gardée (JSON de data + lieu) |
| `definitions.perKind` | 1 000 | fiches vivantes au plus par type |
| `drafts.perMember` / `homeLines` | 20 / 5 | brouillons tenus au plus par un membre ; brouillons montrés sur l'accueil |
| `history.keep` / `pageLines` / `purgeOnStart` / `purgeDelayMs` | 20 / 20 / `true` / 60 000 | versions figées gardées par fiche (jamais la publiée ni la dernière d'une fiche retirée ; purge des fiches d'un lot après chaque publication ou retour en arrière) ; lignes d'une page ; purge au démarrage ; son attente après editorsReady (les synchronisations d'abord) |
| `trial.maxMinutes` / `perMember` | 30 / 1 | durée au plus d'un essai ; essais au plus par membre |
| `bundle.maxChildren` | 200 | fiches enfants au plus dans une publication groupée |
| `sync.sliceMs` / `retryMs` / `retries` | 4 / 10 000 / 3 | travail au plus (ms) entre deux pauses d'un fil de synchronisation ou d'archives ; nouvel essai si la base est muette ; essais au plus |
| `archives.command` / `folder` / `maxBytes` / `confirmMs` / `cooldownMs` / `exportCooldownMs` | `atelier_archives` / `echanges` / 4 Mo / 60 000 / 2 000 / 60 000 | commande, dossier des archives (jamais servi aux joueurs), fichier lu ou écrit au plus, délai de confirmation, délai entre deux commandes d'un membre, délai entre deux exports (tous membres confondus) |
| `place.maxXY` / `maxZ` / `maxRadius` / `polygonPoints` | 50 000 / 5 000 / 500 / 3 à 32 | bornes d'un lieu (formes point, orienté, cercle, polygone, porte) |
| `placement.reach` / `polygonFactor` **(conseil)** | 60 m / 2 | portée d'une pose (centre, 3D) ; un sommet de tracé à 120 m au plus (au sol) — relus par le serveur |
| `placement.aim`, `labels`, `ghosts`, `steps`, `pickRadius`, `undoMax`, `refreshMs`, `sortMs`, `quitConfirmMs` **(conseil)** | 80 m, 17 / 12 à 40 m / 12 à 60 m, alpha 160, 3 s / 15°, 1°, 5 m, 0,5 m / 2,5 m / 20 / 100 ms / 500 ms / 2 s | visée, étiquettes, fantômes, pas de la molette, choix au clic droit, annulations, rythme de l'aperçu et du tri, second `Échap` |
| `placement.colors`, `ringAlpha`, `markers`, `controls`, `disabled`, `undoKey`, `keybar` **(conseil)** | maquette `Recolte` | teintes, marqueurs, contrôles lus et neutralisés, touche `Z`, barre des touches par mode |
| `placement.texts` **(conseil)** | — | aperçu et refus (« Trop loin de vous (72 m) : approchez-vous. », « Hors de %s. », « Trop près de « %s » (%s m). »…) ; le serveur rend les mêmes |
| `placement.bucket` / `childrenMax` | 0 / 200 | instance où l'on place (ailleurs : « Vous êtes hors du monde commun (intérieur, cachot…) : revenez-y pour placer. ») ; lignes au plus d'une réponse `children` |
| `rateLimits.place` / `children` | 6, 2 / s / 4, 1 / s | poser ou déplacer ; lieux d'une fiche |
| `texts.changes.place` | — | résumés d'un lieu changé (« déplacée de 12 m », « rayon de 120 m à 140 m », « tournée de 40° », « tracé redessiné (6 sommets) », « posée ») |
| `texts.refused`, `sayAuthor` **(client)** | — | textes affichés par l'amorce hors de la page : refus d'un RPC, nom des réponses de `/atelier_archives` au chat (`sayAuthor`, ancien `texts.archives.author`) |
| `texts.loading`, `loadFailed` **(client)** | « On apporte les registres de l'Atelier : un instant… » / « Les registres de l'Atelier n'ont pas pu être ouverts : prévenez un développeur. » | T-157 : premier envoi d'une version ; fichier du paquet ou page en erreur (160 octets au plus, contrôlés au démarrage) |
| `delivery.pageWaitMs` / `bootWaitMs` **(client)** | 5 000 / 5 000 | T-157 : attente au plus de la page vide (« prête »), puis de son compte rendu après ses scripts (1 000 à 30 000, contrôlés au démarrage : le module refuse de démarrer sinon) |
| `texts.modeLine`, `revoked`, `trialLineDefault`, `trialEndedFeed` **(conseil)** | — | textes de la séance : bandeaux du volet, révocation, fin d'essai |
| `delivery.hourlyPackages` | 3 | T-157 : paquets entiers envoyés au plus à un même joueur par heure glissante (1 à 20 ; au-delà : `rate_limited`) |
| `rateLimits.code` | 12, puis 1 / 5 s | T-157 : description du paquet et ses morceaux (8 au plus) |
| `texts` (le reste) | — | textes envoyés par le serveur (erreurs de champ, verbes du journal, libellés du Registre, résumés, réponses de `/atelier_archives`) ; l'interface a les siens (`web/js/strings.js`) |

**Droit effectif d'un atelier** : la surcharge de `rights.overrides` si elle est permise ; sinon le plus fort du droit
déclaré et du plancher de sa famille. Un Sénéchal (`metiers`) ne voit donc que le monde ; seule la config peut lui ouvrir
un atelier de la société ou des arts. Un plancher, une surcharge ou `rights.open` hors de `rights.allowed` : l'Atelier
refuse de démarrer (« config.lua, droits : rights.overrides['…'] = '…' : pas un droit permis (metiers, staff) »).

## Code livré au seul Conseil (1.4.0, T-157)

Le code client réservé au Conseil (neuf fichiers Lua et la page) n'est plus servi par FiveM : il est listé dans deux
directives du manifeste, `vava_conseil_lua` (ordre d'exécution) et `vava_conseil_web` (ordre d'insertion, celui de
`web/dev/index.html`), que FXServer garde comme métadonnées sans les servir.

- **Au démarrage**, le serveur (`server/delivery.lua`) lit ces fichiers sur la copie déployée, ramène `\r\n` à `\n`,
  refuse un octet nul, **compile** chaque fichier Lua sans l'exécuter, assemble le paquet (`shared/codepack.lua` :
  « VAVAPAQ1 », puis chaque fichier précédé de son genre, son chemin et sa taille), calcule son empreinte (FNV-1a 64
  bits, `shared/digest.lua`) et le coupe en morceaux de 64 Ko. Console : `paquet du Conseil : 24 fichiers, 245 560
  octets, 4 morceaux, empreinte …`. Un paquet qui ne se construit pas **n'arrête pas** le module (les modules déclarent
  leurs éditeurs, les RPC répondent) : erreur en console, et le membre lit « L'Atelier est indisponible pour le
  moment. ».
- **Au premier F9** d'une séance de jeu, le chargeur (`client/loader.lua`) demande la description du paquet (RPC
  `code`, `('', 0)`), relit son stockage local (KVP de la ressource, morceaux de 32 Ko, empreinte écrite en dernier) et
  ne s'en sert que si l'empreinte, la taille **et l'empreinte recalculée** valent celles que le serveur vient
  d'annoncer ; sinon il télécharge les morceaux l'un après l'autre (réponse latente du core, 64 Ko/s), vérifie taille et
  empreinte, garde le paquet. Chaque fichier Lua est exécuté par `load(code, '@@vava_atelier/<chemin>', 't', env)` :
  texte seul, dans un environnement du paquet (lectures dans `_G`, écritures gardées à part avec un avertissement),
  sous son nom d'origine (une erreur se lit `vava_atelier/client/placer.lua:123: …`). Puis la page vide reçoit sa
  feuille et ses scripts (`bootPiece`, `bootEnd`) et les insère (`web/boot.js`, contrat :
  `docs/plan/rapports/T-157-contrat.md`) ; l'Atelier s'ouvre.
- **Refus** : hors du Conseil, `not_allowed` (« L'Atelier est réservé au Conseil. ») et le stockage local est effacé ;
  un rang retiré pendant un téléchargement arrête le morceau suivant ; un rang retiré Atelier ouvert ferme la séance
  (comme en 1.3.0) et efface le stockage. Un fichier qui lève une erreur, ou une page qui signale un script en erreur :
  « Les registres de l'Atelier n'ont pas pu être ouverts… », plus d'essai jusqu'au prochain redémarrage de la ressource
  ou à la reconnexion. Page muette : le F9 suivant ne refait que l'amorce de la page.
- `/atelier_archives` répond au chat sans paquet chargé (l'amorce l'écoute) ; `Ctrl+Z` de la visée n'est déclaré qu'au
  client d'un membre qui a ouvert l'Atelier (`client/keys.lua`, dernier fichier du paquet).

## Sécurité

- **Le serveur décide de tout.** Chaque RPC revérifie : personnage chargé, Registre du Conseil prêt, droit d'ouvrir
  l'Atelier (relu auprès de `vava_admin`, jamais gardé), session ouverte par ce compte, atelier déclaré, droit effectif
  de l'atelier (relu), type et champ déclarés. Une seule lecture ou vérification de module à la fois par joueur
  (`busy`, repris au bout de 10 s si l'appel reste en suspens). Un refus pour droit écrit une ligne en console, une
  fois par minute et par joueur.
- Le client n'envoie que des identifiants, une page, un texte de recherche borné et des valeurs rangées par carte
  (`n` nombres, `s` chaînes, `b` booléens : 40 / 24 / 24 entrées, 1 200 octets par chaîne). L'Atelier contrôle la forme
  (bornes, pas, choix, jeux de caractères, objet existant, valeur d'une source) ; le module juge le reste.
- Le client ne reçoit jamais un atelier qu'il ne voit pas, ni une fonction d'un module, ni le droit d'un atelier, ni
  qui détient quel droit. Seuls `shared/constants.lua` et `config_client.lua` (touche, commande, textes de refus et
  des bandeaux) sont téléchargés par les joueurs ; `config.lua` (familles, droits, bornes, débits, journal, textes du
  serveur) est servi au seul serveur (1.2.0, T-132). Rien de secret n'y est de toute façon : le serveur applique chaque
  borne et relit chaque droit.
- `<` et `>` sont refusés dans tout texte saisi ; un caractère de contrôle ou invisible (espace sans largeur, marque de
  sens d'écriture, séparateur de ligne, U+FEFF…) aussi. L'interface pose chaque texte venu du serveur par
  `textContent`.
- Toute fonction d'un module est appelée isolée (`pcall`) et chronométrée : une erreur, une réponse d'une autre forme
  ou un module arrêté donnent `editor_error`, jamais une erreur du serveur.
- Un module n'écrit au journal qu'au nom de ses propres ateliers (ressource appelante vérifiée), avec le droit effectif
  de l'atelier, et au plus 60 lignes par 10 s. La recopie au journal du Registre ne part qu'une fois la ligne écrite.
- Un descripteur d'atelier plus lourd que 32 Ko est refusé au chargement : chaque borne d'une déclaration peut être
  tenue alors que leur produit (8 types × 40 champs) ferait un envoi démesuré.
- **T-101** : chaque écriture exige le nom du membre au Registre (jamais « Console » pour un joueur : `not_ready`),
  une ligne refusée par le journal est écrite en console ; une écriture validée en base est toujours journalisée (et ses
  hooks partent), même si l'atelier change pendant ce temps. Un lot relu après sa transaction (une requête sur son
  numéro, révision comprise) est défait s'il est incomplet, et l'annulation ne touche que les lignes de ce lot ; les
  verrous des fiches, revérifiés juste avant la transaction, restent épinglés jusqu'à la fin de l'écriture (relecture,
  module, annulation) ; une suite impossible (relecture échouée, atelier changé) écrit le journal et rapproche les
  fiches du lot. Le verrou « une demande à la
  fois » est tenu par joueur (fermer puis rouvrir l'Atelier ne le libère pas) ; plafonds d'essais et de brouillons
  recomptés sans attente avant d'écrire (places de brouillon réservées le temps d'une écriture).
- **T-101** : chaque écriture revérifie l'atelier gardé et disponible, la fiche, le tenant (compte), la révision et,
  pour une publication ou un retour en arrière, le jeton du résumé (on publie exactement ce qu'on a lu) ; une écriture à
  la fois par fiche. Rien de la page n'est gardé sans passer par la forme, le monde et, à l'essai et à la publication,
  le module. Une fiche pèse au plus 16 Ko ; 1 000 fiches vivantes par type, 20 brouillons par membre, 200 enfants par
  lot. Toutes les requêtes sont paramétrées. Les archives ne sont lues et écrites que dans `echanges/`, sous un nom
  `^[A-Za-z0-9_-]+\.json$` (64 octets), 4 Mo au plus, décodées isolées, chaque fiche revue comme une saisie ; import et
  export réservés au Souverain et à la console, import en deux temps. L'Atelier n'envoie **aucune définition** aux
  joueurs : chaque module diffuse les siennes, aux seuls joueurs concernés (zone du core pour ce qui est posé dans le
  monde, catalogue versionné pour les arts, essai à l'auteur seul).
- **T-102** : le serveur ne croit **aucun lieu** du client. Chaque pose relit la séance, le personnage et le droit
  effectif, l'instance (`placement.bucket`), la position du personnage (lue par le serveur), la forme du lieu (clés de
  la forme seulement, nombres finis, bornes, arrondis), la portée (60 m ; 120 m au sol par sommet), la fiche (nouvelle :
  valeurs du modèle par la forme et le monde, parent vivant, plafonds ; existante : vivante, sans valeurs), les règles
  déclarées avec le parent et les frères lus en base, puis `placeCheck` ; l'écriture passe par la table de décision
  `lc.placePlan` (tenant, révision) sous les verrous de la fiche et de son parent, brouillon du parent copié de sa
  publiée dans la même transaction. Un client qui ment sur sa position ne pose que des **brouillons** : rien n'existe en
  jeu avant la publication, qui repasse par `validate` et `validateLot`. Un envoi à la fois côté client, débit 6 puis
  2 / s côté serveur. Les fantômes sont des objets locaux (`isNetwork = false`) : personne d'autre ne les voit. Chaque
  valeur reçue de la page (`placeStart`, `templateChanged`, `goTo`) est bornée par le Lua ; « Marquer … sur la carte » ne pose que le
  repère GPS (pas de téléportation, décision du 31 octobre 2026).
- **T-157** : le code du Conseil n'est **pas un secret** (le dépôt est public) : sa livraison à la demande économise la
  bande passante et ne déplace aucune décision vers le client ; chaque RPC de l'Atelier revérifie comme avant. Le RPC
  `code` relit le personnage, le Registre et le droit d'ouvrir l'Atelier **à chaque appel** (description et chaque
  morceau), ne répond qu'à l'appelant, refuse une empreinte qui n'est plus celle du serveur (`stale`) et tient un budget
  de 3 paquets par heure et par joueur (≈ 735 Ko), en plus du débit (12, puis 1 toutes les 5 s). Le client n'exécute que
  le texte de la réponse de ce RPC ou de son propre stockage local, **après** l'avoir comparé à l'empreinte que le
  serveur vient d'annoncer dans cette séance : aucun évènement réseau, rappel de la page, export ou commande ne mène à
  `load` ; mode `'t'` (jamais de code précompilé), environnement du paquet (`_G` jamais écrit). FNV-1a protège contre
  l'usure, la coupure et la version périmée, pas contre le propriétaire du disque (qui exécute déjà ce qu'il veut chez
  lui, sans pouvoir de plus). `config.lua` ne peut entrer dans un paquet (audit, règle C ; `config_split_spec`, T5) ;
  `load(` est refusé par l'audit partout ailleurs dans `modules/` et `examples/`.

## Réseau et coût

| Envoi | Cible | Taille |
|---|---|---|
| RPC `home` | l'appelant | 2 à 4 Ko la 1re fois ; ≈ 1 Ko ensuite (accueil stable gardé par la page, empreinte comme le Codex ; étiquettes, journal récent et rang à chaque fois) |
| RPC `editor` | l'appelant | 2 à 12 Ko la 1re fois (32 Ko au plus, `limits.descriptorBytes`) ; ≈ 60 o ensuite |
| RPC `check`, `options`, `search` | l'appelant | ≤ 5 Ko (pages bornées) |
| RPC `list` | l'appelant | ≤ 5 Ko d'habitude, ≈ 10 Ko au pire (50 lignes aux titres et indices les plus longs) |
| RPC `read` | l'appelant | 1 à 5 Ko d'habitude ; ≈ 22 Ko au pire (40 champs aux textes les plus longs, libellés, avertissements), envoyé en latent au-delà de 8 Ko |
| RPC `journal` | l'appelant | ≤ 5 Ko d'habitude, ≤ 12 Ko au pire (25 lignes aux textes les plus longs) |
| évènement `vava_atelier:revoked` | le seul membre dont la session est ouverte et qui perd le droit d'ouvrir l'Atelier | ≈ 30 o |
| évènement `vava_atelier:editorGone` | les seuls membres dont la session est sur l'atelier retiré | ≈ 60 o |
| RPC `save`, `trial`, `endTrial`, `discard`, `retire`, `take`, `publish`, `restore` | l'appelant | ≤ 2 Ko (`{ done, rev, state, footer… }`) |
| RPC `preview` | l'appelant | ≤ 2 Ko (8 lignes de 160 octets au plus, 4 avertissements, jeton) |
| RPC `history`, `version`, `removed` | l'appelant | ≤ 3 Ko d'habitude, ≈ 7 Ko au pire (20 versions aux résumés les plus longs) ; comme `read` (≈ 22 Ko au pire, latent au-delà de 8 Ko) ; ≤ 5 Ko |
| évènement `vava_atelier:entryChanged` | les seuls membres dont la séance a **cette fiche** ouverte (droit de l'atelier relu), sauf l'auteur du changement ; le tenant d'un essai qui prend fin sans qu'il l'ait demandé ; l'ancien tenant d'un brouillon repris ; T-102 : une pose l'écrit aussi sur la fiche parent | ≈ 90 o |
| RPC `place` (T-102) | l'appelant | ≈ 0,4 Ko aller-retour |
| RPC `children` (T-102) | l'appelant | 0,2 Ko (vide), ≈ 0,7 Ko pour 5 points, ≈ 22 Ko au pire (200 lignes, latent au-delà de 8 Ko) |
| RPC `code` (T-157) | l'appelant | description : ≈ 25 o aller, ≈ 60 o retour ; morceau : 64 Ko au plus, **latent** (64 Ko/s), 4 morceaux pour le paquet de 1.4.0 (245 560 o) ; refus ≈ 20 o. Habitant : 1 refus par F9 ; membre : une fois par version, puis la description seule à chaque séance |

Trois formes de réponse sont pensées pour ne rien envoyer deux fois :

- **Accueil** (`home`) : `{ version, content?, tags, drafts, journal, rank }`. `content` (`{ families, cards,
  footnote }`, carte `{ editor, family, label, description, icon, upcoming }`) ne porte que la partie stable et ne part
  que si son empreinte `version` a changé ; les étiquettes des cartes, qui bougent avec le nombre d'entrées, partent à
  chaque fois à part : `tags = { [atelier] = { text = '2 panneaux', tone? } }` (ateliers visibles seulement ; `tone`
  absent : `count` ; un atelier qui ne répond pas n'a pas d'étiquette ; une carte « Bientôt » n'en a jamais, la page
  écrit « Bientôt » d'après `upcoming`).
- **Fiche** (`read`) : `{ id, title, values, labels, warnings?, compare?, state, footer }` ;
  `labels = { [champ] = { label, image?, provisional? } }` nomme la valeur courante de chaque champ à liste distante
  (`select` ou `model` à `source`, `item`), tirée de la source gardée et des objets du royaume ; une valeur vide,
  inconnue de sa liste ou dont la liste ne répond pas n'a pas de libellé. La page n'appelle plus `options` à
  l'ouverture d'une fiche.
- **Journal** (`journal`) : `{ lines, more, next }`, ligne `{ id, lead, title, summary?, actor, when, editor? }` ;
  quand la demande est filtrée sur un atelier, `editor` est omis (la page le tient de son filtre).

Téléchargé par chaque joueur à la connexion (1.2.0, T-132) : `shared/constants.lua`, `config_client.lua` et les cinq
`client/*.lua` (≈ 30,6 Ko de Lua, ≈ 11,2 Ko compressés, contre ≈ 52,2 et 17,7 avant), et la page (≈ 122 Ko) ;
`config.lua` (≈ 21 Ko) et la logique de `shared/` sont servis au seul serveur. Retoucher `config.lua` ne fait rien
retélécharger aux joueurs. **1.3.0 (T-102)** : l'outil de placement est livré à tous (`shared/placerules.lua`,
`shared/aim.lua`, `client/placer.lua`, `ghosts.lua`, `drawing.lua`, et `placement` dans `config_client.lua`) :
≈ 105,2 Ko de Lua (32,9 Ko compressés ; 115,6 et 36,5 avant la relecture réseau R-1 : en-têtes des fichiers livrés
courts, commentaires de fonction de l'outil sur une ligne), et la page ≈ 154,1 Ko (48,3 Ko compressés, + 9,6 Ko,
accepté par le porteur du projet). La cible de la spec pour le Lua (≤ 18 Ko bruts ajoutés) n'est **pas** tenue
(≈ + 75 Ko bruts, dont ≈ 58 Ko de code) : pistes T-154 (Lua livré sans commentaires) et T-157 (code de l'Atelier livré
au seul Conseil, décision du porteur du projet). `shared/aim.lua` est en tête des `client_scripts` (lu par le seul
client).

**1.4.0 (T-157)** : mesuré par `scripts/poids-client.sh --detail vava_atelier`, chaque joueur télécharge **55 273 o
(20 960 compressés)** au lieu de 262 381 o (82 448 compressés) : Lua 42 485 o (15 847), page 8 212 o (3 437 :
`index.html` et `boot.js`), manifeste 4 576 o (1 676). Le paquet du Conseil (ligne `vava_atelier@conseil`) pèse
245 560 o (92 780 de Lua, 152 127 de page, en-têtes compris), non compressé (il part en latent) : un membre le reçoit
une fois par version (≈ 4 s), en 5 RPC ; ensuite, une description par séance (≈ 85 o) et ≈ 0,2 s de relecture locale.
Exemple, 60 joueurs dont 4 membres, une version : 60 × 262 Ko ≈ 15,7 Mo avant, 60 × 55 Ko + 4 × 246 Ko ≈ 4,3 Mo après.
Client : aucune boucle ajoutée ; le chargement coûte ≈ 20 ms de Lua sur une image, une fois par séance de jeu.

Visée (T-102) : une seule boucle par image, **seulement pendant la visée**, chez le seul membre qui place (≤ 0,15 ms
visée : un lancer de rayon asynchrone par image, un seul en vol ; ≤ 3 marqueurs d'aire ; ≤ 12 étiquettes ; le fantôme
du candidat repositionné à chaque image, les autres au tri toutes les 500 ms ; règles réévaluées toutes les 100 ms ou
dès que le candidat bouge). Aucun message à la page ni au serveur à chaque image : la page reçoit `placing`, `placed`,
`placeRefused`, `undone`, `suspended` aux seuls changements ; le serveur ne reçoit que des intentions (`place`,
`discard`). Hors visée et pendant l'essai joué : 0,00 ms.

Rien d'autre ne part : aucun envoi à tous, aucun GlobalState, aucun state bag ; un joueur hors du Conseil ne reçoit
rien de `vava_atelier` (`/vava_reseau ressource vava_atelier`). Une séance de travail type (ouvrir une fiche, trois
sauvegardes, un essai, un résumé, une publication) : ≈ 12 Ko, tous vers le seul membre. Serveur : une sauvegarde coûte
deux ou trois requêtes hors `validate` ; une publication, une transaction de 2 à 3 + n requêtes et les appels au module ;
la synchronisation d'un atelier de 1 000 fiches, quatre requêtes sans données (têtes, ≈ 200 o par fiche) et ≈ 1 000
`read` du module comparés aux empreintes gardées ; seules les publiées qui diffèrent sont relues (par paquets de 25)
et décodées ; pauses du fil toutes les 4 ms (`sync.sliceMs`) ; après un refus du module ou un import, seules les
fiches du lot sont rapprochées. Mémoire : têtes sans données, ≈ 200 o par fiche. Client : **aucune boucle**, aucun prop, aucun dessin ;
0,00 ms au repos, ≤ 0,05 ms interface ouverte. Serveur : un accueil coûte une requête (5 lignes) et un `index` par
atelier visible (gardé 5 s) ; une fiche, son `read` et, si elle a un champ à `source`, la liste de cette source (gardée
5 s) ; un « Vérifier », moins de 2 ms hors la fonction `validate` du module. Qui détient tous les droits permis lit le
journal à rebours sur la clé primaire, sans filtre de droit.

## Installation

`ensure vava_atelier` juste après `ensure vava_admin`. Dépendances : `vAvA_core` ≥ 0.11.0, `vava_ui` (polices et
textures par `nui://vava_ui/…`, déclaré en dépendance), `vava_admin` ≥ 1.8.0 (relu à chaque appel ; sans lui,
« Le Registre du Conseil s'éveille : réessayez dans un instant. »). `vava_admin` n'est volontairement **pas** déclaré
en `dependency` du manifeste : FiveM arrêterait l'Atelier à chaque arrêt du Registre sans le relancer. Facultatifs :
`vava_inventory` (objets du widget `item`), `vava_hud` (notifications). La migration `sql/0001_journal.sql` crée la
table `vava_atelier_journal` (≈ 200 octets par ligne, ≈ 4 Mo pour 365 jours de travail du Conseil) ;
`sql/0002_definitions.sql` crée `vava_atelier_definitions` (une ligne par version, 0,3 à 2 Ko ; 20 versions gardées par
fiche). Le dossier `echanges/` reçoit les archives (jamais dans `files`, ses `.json` ne sont pas suivis par le dépôt).

**Mise à jour vers 1.2.0 (T-132)** : la touche, la commande et les textes affichés par le client ont quitté
`config.lua` pour `config_client.lua` (`texts.archives.author` devient `texts.sayAuthor`). Un `config.lua` modifié et
gardé par l'installeur de la Chancellerie (le nouveau posé en `config.lua.nouveau`) garde l'ancienne forme : le module
démarre, mais la console le signale (« config.lua garde la forme d'avant 1.2.0 … ») et un réglage client changé dans ce
fichier reste sans effet. Reportez vos réglages dans `config.lua` et `config_client.lua` d'après les nouveaux fichiers.

**Mise à jour vers 1.4.0 (T-157)** : `placement` et quatre textes de la séance (`modeLine`, `revoked`,
`trialLineDefault`, `trialEndedFeed`) quittent `config_client.lua` pour le nouveau `config_conseil.lua` ;
`config_client.lua` gagne `delivery` et deux textes (`loading`, `loadFailed`), `config.lua` gagne `rateLimits.code` et
`delivery.hourlyPackages`. Un `config_client.lua` ou un `config.lua` de 1.3.0 gardé par l'installeur fait refuser le
démarrage avec sa raison (« config_client.lua, delivery.pageWaitMs : entier de 1000 à 30000 attendu », « config.lua,
rateLimits.code : débit attendu », « config.lua, delivery.hourlyPackages : entier de 1 à 20 attendu ») : reportez vos
réglages d'après les nouveaux fichiers (`*.nouveau`). Un `config.lua` de 1.3.0 ne réécrit rien de `config_conseil.lua`
(il n'écrit que `bucket` et `childrenMax` dans `placement`).

**L'ordre compte** : tant que l'Atelier n'a pas synchronisé un module gardé, ce module tourne sur sa config. Ne pas
arrêter `vava_atelier` en jeu : un module redémarré pendant ce temps reviendrait à sa config jusqu'au retour de
l'Atelier (il est alors resynchronisé).

## Fichiers

| Fichier | Rôle |
|---|---|
| `config_client.lua` | réglages lus par le client de chaque joueur (touche, commande, textes de l'amorce, attentes du chargeur) : téléchargé par chaque joueur, ouvre `VavaAtelier.config` |
| `config_conseil.lua` | T-157 : réglages du seul client du Conseil (outil de placement, textes de la séance) : dans le paquet, et au serveur (avant `config.lua`) |
| `config.lua` | tous les autres réglages, servi au seul serveur (en tête des `server_scripts`, après `config_conseil.lua`) : complète la table |
| `shared/digest.lua`, `shared/codepack.lua` | T-157, purs, livrés à tous (serveur et chargeur) : empreinte FNV-1a 64 bits ; format du paquet, noms, découpe UTF-8 (`atelier_codepack_spec.lua`) |
| `server/delivery.lua` | T-157 : construction du paquet au démarrage, RPC `code`, budget horaire (`atelier_delivery_spec.lua`) |
| `client/notice.lua`, `client/loader.lua` | T-157, amorce : notifications, refus, réponse de `/atelier_archives` ; chargeur (stockage local, morceaux, empreinte, `load`, amorce de la page) (`atelier_loader_client_spec.lua`) |
| `shared/formschema.lua` | pur : contrôle d'une déclaration d'éditeur (testé : `tests/spec/atelier_formschema_spec.lua`) |
| `shared/formvalues.lua` | pur : valeurs reçues → data du module, et l'inverse, défauts (`atelier_formvalues_spec.lua`) |
| `shared/text.lua` | pur : UTF-8, longueur en caractères, jeux de caractères, recherche sans accents (`atelier_text_spec.lua`) |
| `shared/rights.lua` | pur : droit effectif, droits détenus, ateliers visibles, réglages de droits de la config (`atelier_rights_spec.lua`) |
| `shared/journaltext.lua` | pur : phrase et âge d'une ligne du journal (`atelier_journaltext_spec.lua`) |
| `shared/fingerprint.lua` | pur : empreinte, copie de celle du Codex (`atelier_fingerprint_spec.lua`), et taille du codage (plafond d'un descripteur) |
| `shared/place.lua`, `slug.lua`, `changes.lua` | pur : formes de lieu ; identifiant tiré d'un nom ; résumés (`atelier_place_spec.lua`, `atelier_slug_spec.lua`, `atelier_changes_spec.lua`) |
| `shared/stored.lua`, `lifecycle.lua`, `exchange.lua` | pur : fiche gardée ⇄ data du module ; transitions, lots, cascades, purge, pied de fiche ; archives JSON (`atelier_stored_spec.lua`, `atelier_lifecycle_spec.lua`, `atelier_exchange_spec.lua`) |
| `server/store.lua`, `index.lua`, `calls.lua` | requêtes paramétrées ; têtes en mémoire et verrous ; appels aux fonctions de rechargement des modules |
| `server/trials.lua`, `sync.lua`, `lifecycle.lua`, `history.lua` | essais ; réparation, graine et synchronisation ; écritures et lecture d'une fiche ; historique, versions, retirées, purge |
| `server/archives.lua`, `providers.lua` | /atelier_archives ; listes, indices, brouillons et étiquettes de l'accueil lus en base |
| `bridge/server.lua` | seul contact : personnage, Registre du Conseil, objets du royaume, envois, appels des fonctions des modules |
| `server/editors.lua` | registre des éditeurs : validateur, propriétaire, cache, descripteurs |
| `server/access.lua` | sessions et contrôle de chaque appel |
| `server/home.lua`, `entries.lua`, `check.lua`, `journal.lua` | accueil ; listes, fiches, valeurs, recherche ; « Vérifier » ; journal |
| `server/commands.lua`, `api.lua`, `main.lua` | Codex ; exports ; module, RPC, hooks |
| `client/nui.lua`, `client/core.lua`, `client/main.lua` | amorce : seul pont avec la page ; API du core ; touche et commande (chargeur puis séance), déchargement, arrêt, export `isOpen` |
| `client/session.lua`, `relay.lua`, `keys.lua` | paquet : ouverture, versions gardées, évènements, essai joué ; retours de la page → RPC ; `Z` d'annulation |
| `shared/placerules.lua`, `shared/aim.lua` | purs (T-102) : règles de placement, les mêmes pour l'aperçu (paquet) et la décision (serveur) ; visée (candidat, molette, pile d'annulation, choix, étiquettes, barre des touches), dans le paquet seul (`atelier_placerules_spec.lua`, `atelier_aim_spec.lua`) |
| `server/placement.lua` | RPC `place` et `children` (T-102, `atelier_placement_spec.lua`) |
| `client/placer.lua`, `ghosts.lua`, `drawing.lua` | paquet, outil de placement : états, LA boucle par image de la visée, envois, annulation ; fantômes locaux ; marqueurs, anneaux, tracés, étiquettes |
| `sql/0003_parent_index.sql` | index des enfants d'une fiche (`editor`, `parent`) |
| `web/index.html`, `web/boot.js` | amorce de la page, livrée à tous (T-157) : balisage vide ; insère la feuille et les scripts reçus du chargeur |
| `web/css/`, `web/js/` | la page de l'Atelier, dans le paquet du Conseil (`vava_conseil_web`) |
| `web/dev/` | jamais livré : `web/dev/index.html?screen=…` ouvre la page entière hors jeu avec `web/dev/devmock.js` ; `essais.js` |

## À vérifier en jeu

Procédure complète : [docs/tests/atelier.md](../../docs/tests/atelier.md). En priorité : rendu fidèle aux maquettes
`Main`, `Recolte` (volet) et `Confrerie` (cadre) ; polices de `vava_ui` sans erreur CORS ; refus des appels directs
(atelier 2-3) ; fermeture à la révocation (atelier 2-4) ; journal recopié au Registre (atelier 6-1) ; ateliers redéclarés
après `restart vava_atelier` (atelier 7-2) ; valeur choisie nommée sans appel `options` (atelier 3-4) ; étiquettes de
l'accueil présentes quand le contenu est gardé (atelier 8-4) ; config de droits fausse et descripteur trop lourd
refusés (atelier 7-6, 7-7).

T-101 : publication puis retour en arrière vus d'un joueur proche sans redémarrage (atelier 12-2, 13-2) ; rien chez un
joueur loin (12-3) ; essai vu de son seul auteur (11-2) ; reprise de brouillon (14-2) ; base qui fait foi après un
changement de config (15-1) ; essais rendus aux brouillons après un redémarrage (17-2) ; refus d'`apply` sans trace en
jeu (17-4) ; rendu des étiquettes et des boîtes fidèle aux maquettes.

T-102 : visée et touches, AZERTY compris (atelier 19, 20-10) ; `Échap` sans bannière (19-8) ; `resmon` en visée
≤ 0,15 ms et 0,00 ms après (19-9) ; fantômes et étiquettes vus du seul membre (20-8) ; essai joué : page rangée, `F9`
la rend (21) ; publication vue d'un proche en moins d'une seconde, rien chez un joueur loin (22-2, 22-3) ; appels
directs refusés (24) ; fantômes retirés et focus rendu à l'arrêt de la ressource (24-6) ; rendu du volet fidèle à la
maquette `Recolte`.

T-157 : ligne `paquet du Conseil : 24 fichiers…` au démarrage, directives lues en forme de table (atelier 25-1) ; un
habitant ne reçoit aucun code et n'a plus la liaison « Atelier : annuler le dernier placement » (25-3, 25-4) ; premier
F9 d'un membre ≈ 4 à 5 s, puis ouverture immédiate et, après reconnexion, sans téléchargement (25-5 à 25-7) ; tout
l'Atelier comme en 1.3.0, Ctrl+Z compris (25-8) ; erreurs nommées sans `@@` (25-12, 25-13) ; rang retiré pendant et
après un téléchargement (25-14, 25-15) ; `resmon` 0,00 ms au repos (25-18).
