# vava_characters_ui — le Registre des âmes

L'écran par lequel on entre dans le royaume : la liste de ses personnages (« Registre des âmes »), jouer,
supprimer, et l'éditeur de création en sept étapes (identité, héritage, visage, cheveux, peau, maquillage, tenue)
avec un aperçu en direct. Ressource **cliente uniquement** : la liste, la création, la sélection et la suppression sont
des intentions envoyées au serveur, qui décide de tout ; l'apparence passe par `vava_appearance`.

Ordre de démarrage : après `vAvA_core`, `vava_ui` (≥ 1.0.0 : polices, grain et ornements de la page) et
`vava_appearance` (dépendances déclarées : arrêter l'une d'elles arrête aussi cet écran ; ne jamais arrêter `vava_ui`
sur un serveur ouvert).
Core ≥ 0.3.0 ; ≥ 0.8.0 pour vérifier les noms à la saisie avec les règles du serveur (sans elles, seul le serveur juge
et un nom refusé l'est à la création).

## Ce que fait le joueur

- **Sélection** (au hook `core:character:selection` : connexion, retour à la sélection) : une carte par personnage
  (« Jouer », corbeille avec confirmation) puis les emplacements libres, jusqu'au maximum du compte envoyé par le
  serveur. `Échap` ne ferme pas cet écran : on n'en sort qu'en jouant un personnage.
- **Création** : sept onglets guidés, caméra « Silhouette » ou « Visage » selon l'onglet, « Aléatoire » et
  « Réinitialiser » par onglet, rotation du ped au glisser ou par `Q` / `E`. « Créer le personnage » demande une
  confirmation (le nom ne pourra plus changer), puis le personnage est créé avec son apparence (RPC
  `vava_appearance:create`) et joué aussitôt.
- L'écran se ferme au hook `core:character:loaded` : l'apparition qui suit est celle du core.

## Hook et export (1.2.0)

Pour l'écran de chargement (`vava_loading`), qui passe à la sélection sans écran noir quand elle est prête :

| Nom | Genre | Quand, ce qu'il rend |
|---|---|---|
| `vava_characters_ui:shown` | hook client (after), payload `{}` | à la fin de l'ouverture : scène, caméra, liste des personnages, page et focus en place, fondu d'entrée lancé ; une fois par ouverture (connexion, retour à la sélection) |
| `isShown()` | export client | `true` entre la fin de l'ouverture et la fermeture (personnage joué, arrêt de la ressource), sinon `false` ; lu par `vava_loading` à son démarrage s'il a manqué le hook |

Rien d'autre ne change : l'écran ne sait rien du chargement, il annonce seulement qu'il est affiché.

## Règles (config_client.lua)

Ressource cliente uniquement : tous ses réglages sont lus par le client, dans `config_client.lua` (nommé `config.lua`
avant 1.3.0, T-132 : `config.lua` est réservé aux réglages du seul serveur, jamais téléchargés). **Mise à jour vers
1.3.0** : un `config.lua` modifié est gardé par l'installeur de la Chancellerie, qui le signale (« reportez vos
réglages dans config_client.lua »), mais il n'est plus au manifeste et n'est plus lu : reportez vos réglages dans
`config_client.lua`, puis supprimez l'ancien fichier.

| Règle | Défaut | Clé |
|---|---|---|
| Ressource et RPC de l'apparence | `vava_appearance`, `vava_appearance:create` | `appearanceResource`, `createRpc` |
| Modèles d'aperçu | `mp_m_freemode_01`, `mp_f_freemode_01` (doivent suivre `spawn.models` du core) | `models` |
| Scène de l'aperçu | piste de McKenzie, Grapeseed (provisoire, `-- PLACEHOLDER`) ; distincte du point d'apparition du core | `scene` |
| Passants retirés autour de la scène | 25 m (sur ce client seulement) | `clearRadius` |
| Caméras (vue d'ensemble, silhouette, visage) | distance, hauteur, décalage, cible, champ de vision | `cameras` |
| Transition entre deux caméras, fondu | 550 ms, 500 ms | `cameraTransitionMs`, `fadeMs` |
| Rotation la plus forte par message | 45° | `rotationMaxStep` |
| Attentes bornées (modèle, sol, intervalle) | 10 s, 4 s, 50 ms | `modelTimeoutMs`, `collisionTimeoutMs`, `pollMs` |

### Noms

Les règles des prénoms et noms sont celles du serveur (`characters.name` dans `config/server.lua` du core : longueur
en caractères, lettres permises, séparateurs). Le core les envoie avec la liste des personnages ; l'éditeur vérifie la
saisie exactement comme lui (espaces de bord retirés, chaque caractère pris dans les lettres ou les séparateurs, un
séparateur jamais en tête, en fin ni doublé) et en tire le rappel sous le champ (« 2 à 24 lettres. Espace, apostrophe
et trait d'union autorisés entre deux lettres. »). Rien n'est recopié en dur : changer la config du core suffit. Le
serveur revérifie tout à la création.

### Scène

Le ped d'aperçu est **local** : aucun autre joueur ne le voit, et plusieurs joueurs créent au même endroit sans se
gêner. Mais les vrais joueurs qui passent dans la scène, eux, s'y voient : elle ne doit donc être ni au point
d'apparition du core (`spawn.defaultPoint`, où apparaissent les nouveaux venus) ni dans un lieu de passage. La position
est celle du centre du ped ; le sol est cherché juste en dessous, et les caméras se placent depuis l'orientation de la
scène (faire pivoter le ped ne les déplace pas).

## Arrêt et redémarrage

- Ressource redémarrée pendant la sélection : l'écran se rouvre seul (le core dit que le joueur attend un personnage).
- À l'arrêt de la ressource écran ouvert, tout ce qu'elle avait posé est retiré : ped d'aperçu, caméra scriptée, mise
  au point de la carte, radar caché, souris et clavier. L'écran redevient noir, comme l'attente de sélection du core,
  jusqu'au redémarrage.

## Sécurité et coût

- Aucune RPC propre : la ressource appelle l'API client du core (`core.characters.list`, `select`, `delete`) et la RPC
  de `vava_appearance`. Les retours de l'interface sont vérifiés (état de l'écran, identifiants entiers, rotation
  bornée) avant d'agir, et le serveur revérifie tout.
- Aucune boucle : seules des attentes bornées pendant le chargement d'un modèle ou du sol. L'aperçu n'envoie que la
  partie modifiée, au plus une fois par image et par réglage, une seule requête en vol (`web/js/bridge.js`).
- Les noms de personnage s'affichent par `textContent` ; `innerHTML` ne sert qu'aux icônes écrites dans
  `web/js/icons.js`.

## Assets à brancher

| Valeur | Remplaçant actuel | Quand l'asset arrive |
|---|---|---|
| `scene` | piste de McKenzie (Grapeseed), cap 115° | la scène de création de la carte médiévale ; régler ensuite `cameras` si le cadrage le demande |
| `models` | peds « freemode » de GTA | seulement si le core change `spawn.models` |

## Hors jeu

`web/index.html` s'ouvre dans un navigateur depuis le dépôt (option `--allow-file-access-from-files` pour les polices)
avec des données simulées (`web/dev/devmock.js`, jamais livré), règles de nom comprises : la ligne hors jeu de la page
charge `modules/vava_ui/web/dev/horsjeu.js` puis le devmock. `?screen=creator&tab=hair&sex=f` ouvre directement
l'éditeur sur un onglet. En jeu, polices, grain, cadre et losanges arrivent de `vava_ui` (`nui://vava_ui/…`).

## Fichiers

| Fichier | Rôle |
|---|---|
| `config_client.lua` | scène, caméras, modèles, temporisations (`config.lua` avant 1.3.0) |
| `client/main.lua` | cycle de vie de l'écran, retours de l'interface, nettoyage à l'arrêt |
| `client/camera.lua` | caméras de la scène et transitions |
| `client/preview.lua` | ped d'aperçu local (créé, pivoté, retiré) |
| `client/nui.lua` | pont avec la page (messages, retours isolés) |
| `web/` | la page : sélection, éditeur, contrôles, textes (`strings.js`), blason ; données simulées dans `web/dev/` (jamais livrées) |

## À vérifier en jeu

Procédure complète : `docs/tests/personnage.md` (sections 1 à 4 et 9). En priorité :

1. **Scène** (3-12, 2-1) : cadrage des trois caméras et ped posé au sol à la nouvelle scène provisoire ; **(2 joueurs)**
   un joueur au point d'apparition n'apparaît pas dans la scène de celui qui crée.
2. **Noms** (2-2 à 2-5) : le rappel sous le champ et chaque refus suivent `characters.name` ; `Łucja` est refusé dès
   la saisie.
3. **Arrêt** (9-2, 9-3) : `restart vava_characters_ui` dans l'éditeur ne laisse ni ped d'aperçu, ni caméra figée, ni
   souris prise ; la sélection revient avec sa liste.
4. `F8` par-dessus l'écran de sélection (§ 0.2 de la procédure).
5. **Passage depuis l'écran de chargement** (1.2.0, `docs/tests/chargement.md` § 3) : à la connexion, l'éclair de
   `vava_loading` se dissout sur la sélection déjà en place, sans image noire ; la souris répond aussitôt.
