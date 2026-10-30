# Audit réseau et performance — vAvA_core 0.8.1 — 30 octobre 2026 (T-011)

## Périmètre

Rôle réseau du core : porte RPC (`server/core/rpc.lua`, `client/core/rpc.lua`), diffusion des champs de personnage
(`server/players/sync.lua`, `client/players/session.lua`), ordre d'apparition (`server/players/spawn.lua`,
`client/players/spawn.lua`). Lus en entier : ces six fichiers, `client/init.lua`, `server/players/fields.lua`
(visibilités), `scripts/audit-reseau.sh` et `scripts/audit-exceptions.txt`. Survolés : `server/players/accounts.lua`,
`persistence.lua`, `positions.lua` (aucun envoi vers les clients).

Mesures statiques : `./scripts/audit-reseau.sh` sur `main` (f7b0231) : aucun BLOQUANT, avertissements GlobalState
(7 lignes, voir récolte, agriculture, artisanat, inventaire), `Wait(0)` (14 lignes, toutes justifiées sauf revue de
T-018, voir les rapports des modules), un `innerHTML` (hors périmètre réseau).

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| `RPC_RESPONSE` (réponse à un `call`) | `server/core/rpc.lua:97-102` | l'appelant seul ; rien pour un `emit` (id 0) | 20 o + valeurs du handler (de 30 o à plusieurs Ko : Codex, inventaire, menus) | une par appel client, bornée par la limite de débit de chaque RPC |
| `CLIENT_REQUEST` (`callClient`) | `server/core/rpc.lua:301` | un joueur | 30 o + arguments | à la demande d'un module, rare |
| `CHARACTER_LOADED` | `server/players/sync.lua:64-67` | le joueur | identité + champs `owner` et `public` : 0,5 à 3 Ko (apparence, raccourcis, besoins, santé, préférences du Codex…) | une fois par personnage chargé |
| `CHARACTER_FIELDS` | `server/players/sync.lua:23-31` | le joueur | valeur complète de chaque champ changé, regroupée par tick (`SetTimeout(0)`) | à chaque écriture d'un champ `owner`/`public` : besoins 1/min, santé au plus 1/10 s, main, raccourcis, préférences |
| `CHARACTER_UNLOADED` | `server/players/sync.lua:96` | le joueur | 10 o | au déchargement |
| `SPAWN` | `server/players/spawn.lua:47` | le joueur | 80 o | à chaque apparition |

Aucun envoi à tous : tous les `TriggerClientEvent` du core ciblent une source.

## GlobalState et state bags

| Écriture | Fichier:ligne | Taille | Fréquence | Qui en a besoin |
|---|---|---|---|---|
| Champs `public` dans le state bag du joueur (`Player(src).state`, répliqué) | `server/players/sync.lua:68-71`, `:81-83`, `:92-95` | valeur du champ | à chaque écriture du champ | aujourd'hui un seul champ public : `vava_inventory:hands` (voir `reseau-vava_inventory.md`) |

Le core n'écrit rien dans GlobalState.

## Boucles client

| Boucle | Fichier:ligne | Au repos | En action | Remarque |
|---|---|---|---|---|
| attente de session | `client/players/spawn.lua:167-173` | `cfg.sessionPollMs`, s'arrête dès la session active | — | une fois au démarrage |
| attentes bornées d'apparition (modèle, fondu, collisions) | `client/players/spawn.lua:64-71` | — | `cfg.pollMs`, bornées par délai | pendant une apparition seulement |

Aucune boucle permanente, aucun `Wait(0)` côté client (l'état des lieux de `SECURITE_RESEAU.md` citait encore
`client/players/spawn.lua` : corrigé). Le seul `Wait(0)` du core est serveur (`server/players/accounts.lua:232`, une
cession de tour), sans coût client.

## Props, NUI, fichiers web

Le core ne crée aucun prop, n'a pas d'interface NUI et aucun fichier web.

## BLOQUANT

Aucun.

## IMPORTANT

- `server/core/rpc.lua:97-102`, `:301` et `server/players/sync.lua:30`, `:64` — **aucune mesure de taille, aucun envoi
  latent** — toutes les réponses RPC et tous les champs partent en `TriggerClientEvent` fiable, quelle que soit leur
  taille. Les réponses volumineuses existent déjà (ouverture du Codex : catalogue complet à chaque ouverture, estimé
  10 à 30 Ko ; instantané de l'inventaire avec définitions ; menus d'artisanat) et l'Atelier en ajoutera (catalogues
  de gestes, effets, sorts, techniques). Un gros évènement fiable occupe le canal du joueur et retarde les autres
  messages (latence ressentie). Correction (T-013) : `core.net` estime la taille sérialisée (`msgpack.pack`) de chaque
  envoi et de chaque réponse ; au-delà d'un seuil en config (ex. 8 Ko), la réponse part par
  `TriggerLatentClientEvent` avec un débit borné (ex. 64 Ko/s), le client RPC acceptant les deux évènements.
- `scripts/audit-reseau.sh:47-48` — **le garde-fou ne voit pas un envoi à tous écrit autrement que `-1`** — il ne
  cherche que le littéral `-1` : `vava_voice/server/zones.lua:73,75` envoie à `EVERYONE` (constante qui vaut `-1`,
  `:23`) sans être signalé, et une boucle `for src in pairs(sessions.all()) do TriggerClientEvent(...)`
  (`vava_chat/server/api.lua:71`) non plus. Correction (T-013) : signaler aussi les constantes valant `-1` utilisées
  comme cible et les boucles sur tous les joueurs qui envoient (motif `GetPlayers`/`sessions.all` suivi d'un
  `TriggerClientEvent`) ; inscrire `vava_voice/server/zones.lua` dans `audit-exceptions.txt` en attendant T-014, après
  relecture du porteur du projet.

## MINEUR

- `server/players/sync.lua:77-84` — **champ public reçu deux fois par son propriétaire** — un champ `public` part au
  propriétaire dans `CHARACTER_FIELDS` et aussi par le state bag répliqué. Le propriétaire lit déjà le state bag (ou
  l'inverse) : n'envoyer `CHARACTER_FIELDS` que pour les champs `owner`, ou documenter le doublon. Environ 110 o par
  changement de main aujourd'hui.
- `server/players/sync.lua:79-80` — **un champ part toujours en entier** — un module qui range une liste dans un
  champ `owner` renvoie la liste complète à chaque petite modification (préférences du Codex : jusqu'à 36 entrées,
  environ 1,8 Ko à chaque commande lancée depuis le Codex, alors que le client ne lit pas ce champ). Règle à écrire
  dans `docs/api.md` : `owner` seulement si le client lit le champ ; sinon `private` et un envoi ciblé.

## Points solides

- Une seule porte d'entrée, des réponses envoyées au seul appelant, `emit` sans réponse : aucun trafic inutile.
- Les champs d'un même tick partent en un seul évènement par joueur (`sync.lua:19-52`) ; rien n'est jamais envoyé
  pour un champ `private` ; à la sélection, les state bags publics sont vidés.
- Apparition sans boucle permanente ; toutes les attentes sont bornées.

## À vérifier en jeu

- Taille réelle des réponses RPC les plus lourdes (ouverture du Codex, de l'inventaire, menu d'une forge) avec le
  compteur de T-013.
- Ping d'un joueur pendant l'ouverture du Codex à 64 joueurs (pas de pic visible attendu en dessous de 16 Ko).

VERDICT : À CORRIGER
