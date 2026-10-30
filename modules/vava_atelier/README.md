# vava_atelier — l'Atelier du Conseil

Le Conseil façonne le royaume depuis le jeu : `F9` (ou `/atelier`) ouvre un livre de travail où chaque membre ne voit
que les ateliers que son rang lui ouvre (le monde pour un Sénéchal, tout pour un Souverain), ses brouillons et le
journal des derniers changements. Chaque réglage s'y présente en mots du jeu, avec une phrase d'aide, et le serveur dit
tout de suite ce qui ne va pas. Les joueurs ne voient jamais l'Atelier ; ils en voient les effets.

**Version 1.0.0 (T-100) : le socle.** Cadre, accueil, droits, formulaire générique, « Vérifier », journal. L'Atelier
n'enregistre encore **aucune définition** : brouillons, essai, publication, versions et import de la config viennent avec
T-101, l'outil de placement en jeu avec T-102. Les ateliers réels des modules (récolte, agriculture, artisanat…) arrivent
avec T-102 à T-106 ; en attendant, l'accueil les montre « Bientôt ».

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
| `journal.retentionDays` | 365 | lignes plus anciennes retirées au démarrage |
| `journal.homeLines` / `pageLines` | 5 / 25 | lignes de l'accueil, d'une page du journal entier |
| `journal.flood` | 60 lignes / 10 s | écritures au plus par ressource appelante (export `journal`) |
| `journal.mirror` | `true` | recopie de chaque ligne au journal du Registre |
| `rateLimits.*` | voir le fichier | débits des RPC : `home`, `editor`, `read`, `check`, `lookup`, `close` |
| `texts` | — | textes vus par les membres (refus, erreurs de champ, verbes du journal, libellés du Registre) ; l'interface a les siens (`web/js/strings.js`) |

**Droit effectif d'un atelier** : la surcharge de `rights.overrides` si elle est permise ; sinon le plus fort du droit
déclaré et du plancher de sa famille. Un Sénéchal (`metiers`) ne voit donc que le monde ; seule la config peut lui ouvrir
un atelier de la société ou des arts.

## Sécurité

- **Le serveur décide de tout.** Chaque RPC revérifie : personnage chargé, Registre du Conseil prêt, droit d'ouvrir
  l'Atelier (relu auprès de `vava_admin`, jamais gardé), session ouverte par ce compte, atelier déclaré, droit effectif
  de l'atelier (relu), type et champ déclarés. Une seule lecture ou vérification de module à la fois par joueur
  (`busy`). Un refus pour droit écrit une ligne en console, une fois par minute et par joueur.
- Le client n'envoie que des identifiants, une page, un texte de recherche borné et des valeurs rangées par carte
  (`n` nombres, `s` chaînes, `b` booléens : 40 / 24 / 24 entrées, 1 200 octets par chaîne). L'Atelier contrôle la forme
  (bornes, pas, choix, jeux de caractères, objet existant, valeur d'une source) ; le module juge le reste.
- Le client ne reçoit jamais un atelier qu'il ne voit pas, ni une fonction, ni un droit, ni la config interne.
- `<` et `>` sont refusés dans tout texte saisi ; l'interface pose chaque texte venu du serveur par `textContent`.
- Toute fonction d'un module est appelée isolée (`pcall`) et chronométrée : une erreur, une réponse d'une autre forme
  ou un module arrêté donnent `editor_error`, jamais une erreur du serveur.
- Un module n'écrit au journal qu'au nom de ses propres ateliers (ressource appelante vérifiée), avec le droit effectif
  de l'atelier, et au plus 60 lignes par 10 s.

## Réseau et coût

| Envoi | Cible | Taille |
|---|---|---|
| RPC `home` | l'appelant | 2 à 4 Ko la 1re fois ; ≈ 1 Ko ensuite (accueil gardé par la page, empreinte comme le Codex) |
| RPC `editor` | l'appelant | 2 à 12 Ko la 1re fois ; ≈ 60 o ensuite |
| RPC `list`, `read`, `check`, `options`, `search`, `journal` | l'appelant | ≤ 5 Ko (pages bornées) |
| évènement `vava_atelier:revoked` | le seul membre dont la session est ouverte et qui perd le droit d'ouvrir l'Atelier | ≈ 30 o |
| évènement `vava_atelier:editorGone` | les seuls membres dont la session est sur l'atelier retiré | ≈ 60 o |

Rien d'autre ne part : aucun envoi à tous, aucun GlobalState, aucun state bag ; un joueur hors du Conseil ne reçoit
rien de `vava_atelier` (`/vava_reseau ressource vava_atelier`). Client : **aucune boucle**, aucun prop, aucun dessin ;
0,00 ms au repos, ≤ 0,05 ms interface ouverte. Serveur : un accueil coûte une requête (5 lignes) et un `index` par
atelier visible (gardé 5 s) ; un « Vérifier », moins de 2 ms hors la fonction `validate` du module.

## Installation

`ensure vava_atelier` juste après `ensure vava_admin`. Dépendances : `vAvA_core` ≥ 0.11.0, `vava_ui` (polices et
textures par `nui://vava_ui/…`, déclaré en dépendance), `vava_admin` ≥ 1.8.0 (relu à chaque appel ; sans lui,
« Le Registre du Conseil s'éveille : réessayez dans un instant. »). `vava_admin` n'est volontairement **pas** déclaré
en `dependency` du manifeste : FiveM arrêterait l'Atelier à chaque arrêt du Registre sans le relancer. Facultatifs :
`vava_inventory` (objets du widget `item`), `vava_hud` (notifications). La migration `sql/0001_journal.sql` crée la
table `vava_atelier_journal` (≈ 200 octets par ligne, ≈ 4 Mo pour 365 jours de travail du Conseil).

## Fichiers

| Fichier | Rôle |
|---|---|
| `shared/formschema.lua` | pur : contrôle d'une déclaration d'éditeur (testé : `tests/spec/atelier_formschema_spec.lua`) |
| `shared/formvalues.lua` | pur : valeurs reçues → data du module, et l'inverse, défauts (`atelier_formvalues_spec.lua`) |
| `shared/text.lua` | pur : UTF-8, longueur en caractères, jeux de caractères, recherche sans accents (`atelier_text_spec.lua`) |
| `shared/rights.lua` | pur : droit effectif, droits détenus, ateliers visibles (`atelier_rights_spec.lua`) |
| `shared/journaltext.lua` | pur : phrase et âge d'une ligne du journal (`atelier_journaltext_spec.lua`) |
| `shared/fingerprint.lua` | pur : empreinte, copie de celle du Codex (`atelier_fingerprint_spec.lua`) |
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
après `restart vava_atelier` (atelier 7-2).
