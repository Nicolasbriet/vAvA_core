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
`/atelier_archives`. L'outil de placement en jeu vient avec T-102 ; les ateliers réels des modules (récolte,
agriculture, artisanat…) avec T-102 à T-106 ; en attendant, l'accueil les montre « Bientôt ». Un atelier sans `apply`
reste **en lecture** (comportement de 1.0.0 : « Vérifier » seul).

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

## Règles (config.lua)

| Clé | Défaut | Rôle |
|---|---|---|
| `keys.open` / `command` | `F9` / `atelier` | touche (réglable par le joueur, Raccourcis › FiveM) et commande |
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
| `texts` | — | textes vus par les membres (refus, erreurs de champ, verbes du journal, libellés du Registre) ; l'interface a les siens (`web/js/strings.js`) |

**Droit effectif d'un atelier** : la surcharge de `rights.overrides` si elle est permise ; sinon le plus fort du droit
déclaré et du plancher de sa famille. Un Sénéchal (`metiers`) ne voit donc que le monde ; seule la config peut lui ouvrir
un atelier de la société ou des arts. Un plancher, une surcharge ou `rights.open` hors de `rights.allowed` : l'Atelier
refuse de démarrer (« config.lua, droits : rights.overrides['…'] = '…' : pas un droit permis (metiers, staff) »).

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
  qui détient quel droit. Comme dans tous les modules du dépôt, `config.lua` et `shared/constants.lua` sont des
  scripts partagés : **chaque joueur connecté** reçoit ces deux fichiers (familles et planchers, cartes « Bientôt »,
  noms des droits et surcharges, bornes, débits, textes). Rien n'y est secret : aucune clé, aucun compte, aucune liste
  de membres ; connaître une borne ou un débit ne permet pas de les franchir, puisque le serveur les applique et relit
  chaque droit auprès du Registre à chaque appel. Une tâche du backlog traitera la séparation client / serveur des
  configs pour tout le dépôt.
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
| évènement `vava_atelier:entryChanged` | les seuls membres dont la séance a **cette fiche** ouverte (droit de l'atelier relu), sauf l'auteur du changement ; le tenant d'un essai qui prend fin sans qu'il l'ait demandé ; l'ancien tenant d'un brouillon repris | ≈ 90 o |

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

**L'ordre compte** : tant que l'Atelier n'a pas synchronisé un module gardé, ce module tourne sur sa config. Ne pas
arrêter `vava_atelier` en jeu : un module redémarré pendant ce temps reviendrait à sa config jusqu'au retour de
l'Atelier (il est alors resynchronisé).

## Fichiers

| Fichier | Rôle |
|---|---|
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
| `client/nui.lua` | seul pont avec la page |
| `client/session.lua`, `relay.lua`, `main.lua` | ouverture, versions gardées, évènements ; retours de la page → RPC ; touche et commande |
| `web/` | la page unique ; `index.html?screen=…` s'ouvre hors jeu avec `web/dev/devmock.js` (jamais livré) |

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
