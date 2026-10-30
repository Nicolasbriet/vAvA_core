# vava_chat — le chat du royaume

Chat pour vAvA_core, à la place de la ressource `chat` de FiveM : hors-RP de proximité, `/me` et `/do` (aussi
au-dessus de la tête), messages privés, canal du Conseil, onglets, fenêtre déplaçable. Le serveur choisit chaque
destinataire : aucun message ne part à tout le serveur.

## Installation

1. Placer le dossier dans `resources/[vava]/vava_chat` (avec la Chancellerie : il est installé avec vAvA).
2. Dans le `server.cfg`, **remplacer** `ensure chat` par `ensure vava_chat`, juste après `vAvA_core` :

   ```cfg
   ensure vAvA_core
   ensure vava_chat
   ```

   Ne pas garder `ensure chat` : les deux chats s'afficheraient. Le manifeste déclare `provide 'chat'` : une ressource
   qui dépend de `chat` démarre avec celle-ci.
3. Démarrer le serveur. La table du journal est créée par le core (migration `sql/0001_chat.sql`, jamais rejouée).
4. **Règlement du serveur** : y écrire que les messages `/ooc`, `/mp` et `/staff` sont gardés 7 jours pour la
   modération.

| Dépendance | Rôle | Sans elle |
| --- | --- | --- |
| `vAvA_core` ≥ 0.5.0 | personnages, RPC, hooks, base, journal | obligatoire |
| `vava_admin` | membres du Conseil et leur rang (`/staff`, insigne) | permission ACE `vava_chat.staff`, sans rang |

## Ce que fait le joueur

| Commande | Qui reçoit | Affichage | Gardé |
| --- | --- | --- | --- |
| texte sans commande dans **Général**, ou `/ooc <message>` | joueurs à 20 m | « HRP · [n°] Prénom Nom : … », insigne pour le Conseil | 7 jours |
| `/me <action>` | joueurs à 15 m | « * Prénom Nom tire son épée * » en doré, et 8 s au-dessus de la tête | non |
| `/do <description>` | joueurs à 15 m | « * La porte est verrouillée * (Prénom Nom) » en gris-bleu, et au-dessus de la tête | non |
| `/mp <n°> <message>` | ce joueur, plus une copie à l'expéditeur | sceau de cire, « De … » / « À … » | 7 jours |
| `/r <message>` | le dernier qui vous a écrit en privé | idem | 7 jours |
| `/staff <message>` | les membres du Conseil en jeu, de tout rang | « Conseil · Rang · [n°] Nom : … » | 7 jours |
| `/chat reinit` | — | remet le chat à sa place par défaut | — |

Les portées sont mesurées par le serveur, entre joueurs du même monde de routage. Le nom affiché est toujours celui du
personnage, jamais le pseudo FiveM. Les commandes marchent dans tous les onglets et depuis la console F8.

**Les onglets** (le tri se fait sur le PC du joueur : aucun envoi en plus) :

| Onglet | Contenu | Texte sans commande |
| --- | --- | --- |
| **Général** | tout, plus les messages des autres ressources | `/ooc` |
| **Actions** | `/me` et `/do` | rien : un rappel de `/me` et `/do` s'affiche |
| **Conseil** (membres seulement) | `/staff` | part au Conseil |
| **un par correspondant** | la conversation privée, ouverte au premier message reçu ou envoyé | part à ce joueur |

- Une pastille compte les messages non lus. Un onglet privé se ferme par sa croix ; il se grise quand le correspondant
  part (sa saisie se ferme) et reprend vie s'il revient sous un nouveau numéro. Les onglets privés durent le temps du
  personnage : retour à la sélection, tout est oublié.
- Cliquer le nom d'un auteur hors-RP prépare `/mp <n°>` ; cliquer une ligne privée dans Général ouvre sa conversation.

**La fenêtre** : touche **T** (réglable dans Paramètres > Raccourcis > FiveM ; le chat s'ouvre au relâchement, la lettre
n'est pas tapée). Entrée envoie et ferme, Échap ferme, ↑ ↓ parcourent l'historique, Tab complète une commande (encore
Tab : la suivante). Ouverte, on la déplace en la saisissant par son bandeau et on l'agrandit par son coin ; la place
est gardée sur le PC du joueur. Fermée, les derniers messages paraissent sur de fins rubans puis s'effacent au bout de
12 s. Le chat se cache sous le menu pause, pendant un écran noir et en sélection du personnage.

## Pour les autres ressources

Les évènements de la ressource `chat` de FiveM marchent tels quels, en local (`TriggerEvent`) ou depuis le serveur
(`TriggerClientEvent`) : `chat:addMessage`, `chatMessage`, `chat:addSuggestion`, `chat:addSuggestions`,
`chat:removeSuggestion`, `chat:clear`. Leurs messages arrivent dans Général, **en texte brut** : les modèles HTML
(`chat:addTemplate`, `templateId`) ne sont jamais interprétés, seuls leurs `args` sont lus (`args[1]` = auteur s'il y en
a plusieurs), et les codes couleur `^0`–`^9` sont retirés. `chat:addMode` et `chat:removeMode` sont acceptés sans effet.
Les exports de l'ancienne ressource (`exports.chat:addMessage`, `registerMessageHook`, `registerMode`) ne sont pas
repris : utiliser l'export ci-dessous ou les hooks.

| Export serveur | Retour |
| --- | --- |
| `addMessage(cible, message)` | `true`, ou `false, code` — `cible` : numéro d'un joueur connecté ; `-1` (envoi à tous) est refusé depuis 1.2.0 (`invalid_target`) : l'annonce à tout le royaume est celle du Registre du Conseil. `message` : texte, `{ author?, text, color? = { r, g, b } }` ou `{ args, color? }` |

| Hook | Phase | Payload |
| --- | --- | --- |
| `vava_chat:sending` | `before` (annulable) | `{ source, characterId, kind, text, target? }` — `kind` : `ooc`, `me`, `do`, `mp`, `staff` ; `target` : source du destinataire d'un `/mp`. Renvoyer `false, 'raison'` refuse le message (sourdine, prison…) : le joueur voit la raison |
| `vava_chat:sent` | `after` | le même, plus `recipients` : nombre de joueurs qui l'ont reçu, auteur compris pour `/ooc`, `/me`, `/do` et `/staff` ; pour un `/mp`, 1 (le destinataire : la copie de l'expéditeur n'est pas comptée) |

Une commande inconnue répond « Commande inconnue : /… » au seul joueur (l'ancienne ressource la diffusait à tous).

## Journal de modération

Table `vava_chat_logs` : date (secondes), genre, personnage et nom de l'auteur, personnage et nom du destinataire d'un
`/mp` (0 et vide sinon), nombre de destinataires, texte. Écrit par lots (une requête pour au plus 50 messages, au plus
tard toutes les 10 s), effacé au bout de 7 jours (au démarrage puis toutes les heures, par tranches de 5 000). Si la
base ne répond plus, jusqu'à 2 000 messages attendent en mémoire. À l'arrêt du module, la file part en base ; si le
core a déjà fermé l'accès à la base (FiveM ne dit pas lequel apprend l'arrêt en premier), les derniers messages (au plus
10 s) sont perdus et la console le dit.

```sql
-- les messages d'un personnage sur 24 h
SELECT FROM_UNIXTIME(`at`), `kind`, `author`, `target`, `message` FROM `vava_chat_logs`
WHERE `character_id` = 12 AND `at` > UNIX_TIMESTAMP() - 86400 ORDER BY `id`;
```

Une page de lecture dans la Chancellerie viendra dans un second temps.

## Configuration (`config.lua`)

| Clé | Rôle |
| --- | --- |
| `maxLength`, `maxBytes` | 250 signes par message (un « é » compte pour un), borne réseau en octets |
| `ranges` | portées de `/ooc` (20 m), `/me` et `/do` (15 m) |
| `staff.ace` | sans vava_admin : permission ACE du canal du Conseil |
| `log` | genres gardés, durée, lots, purge |
| `overhead` | texte au-dessus de la tête : durée, distance, lignes, police, couleurs |
| `ui` | messages gardés par onglet, historique, effacement, place par défaut, taille minimale |
| `key`, `commands` | touche d'ouverture, noms des commandes |
| `commandList` | commandes des autres ressources proposées en suggestion (motifs cachés : `vava_…`, touches `+`/`-`) |
| `rateLimits` | 6 messages d'affilée puis 1 par seconde ; profil ; avis « commande inconnue » |
| `texts` | **tous** les textes vus par les joueurs |

## Sécurité et coût

- Chaque message est une intention (RPC du core, schéma strict, limite de débit) ; le serveur nettoie le texte
  (UTF-8 valide, caractères de contrôle, codes couleur, espaces) et le borne à 250 signes.
- Les destinataires sont choisis par le serveur, d'après les positions qu'il lit lui-même ; chaque message est envoyé
  aux seuls destinataires, jamais à `-1`. Un `/mp` répond par un numéro de conversation qui n'est jamais réutilisé tant
  que le serveur tourne : un onglet resté ouvert ne peut pas écrire à quelqu'un qui aurait repris le même numéro.
- La page n'affiche que du texte brut (`textContent`) : aucun HTML venu d'un joueur ou d'une ressource n'est
  interprété. Au-dessus de la tête, les codes de GTA (`~r~`…) sont retirés.
- Aucune boucle par image au repos : visibilité relue toutes les 300 ms ; le texte au-dessus des têtes n'est dessiné
  que tant qu'un `/me` ou `/do` récent est à portée (ligne de vue relue toutes les 300 ms).
- Le profil (Conseil, commandes du serveur, suggestions selon les droits) est demandé une fois à l'apparition. Quand un
  rang change, le serveur prévient le seul joueur visé, qui le redemande : onglet Conseil, `/staff` et suggestions du
  Conseil suivent, sans reconnexion. `/staff` n'est suggéré qu'aux membres du Conseil.

## Arborescence

```
vava_chat/
├── fxmanifest.lua · config.lua
├── shared/   constants.lua (protocole) · text.lua (texte UTF-8)
├── server/   core · links (personnage, Conseil) · sessions (conversations) · audience (destinataires)
│             logs (journal) · messages (envoi) · compat (commande inconnue, commandes) · api · main
├── client/   core · nui · layout (place) · suggestions · compat (évènements chat:*) · outbox (envoi, avis)
│             commands · overhead (au-dessus de la tête) · input (touche, saisie) · visibility · main
├── web/      index.html · css/style.css · js/ (lines, tabs, suggest, composer, layout, chat, app, devmock)
└── sql/      0001_chat.sql
```

Pour travailler le rendu sans le jeu : `web/index.html?view=open` (ou `passive`, `actions`, `mp`, `gone`, `staff`,
`suggest`, `all`) dans un navigateur.

## Tests à faire en jeu

À deux joueurs au moins (A et B), puis un troisième loin.

1. T ouvre le chat sans taper de « t » ; Échap le ferme ; le menu pause le cache.
2. A écrit « Bonjour » dans Général : B le voit (« HRP · [n°] Nom »), le troisième joueur loin ne le voit pas.
3. A tape `/me salue` : la ligne dorée apparaît dans Général et Actions, et au-dessus de la tête de A pour B, avec les
   accents (« é », « à ») bien rendus. Derrière un mur, B ne voit pas le texte au-dessus de la tête.
4. Dans Actions, un texte sans commande ne part pas et le rappel s'affiche.
5. A tape `/mp <n° de B> salut` : un onglet « Nom de B » s'ouvre chez A, un onglet « Nom de A » chez B avec une pastille.
   B répond dans l'onglet sans commande, puis A répond avec `/r`.
6. B se déconnecte : l'onglet de A se grise et sa saisie se ferme.
7. Un membre du Conseil voit l'onglet Conseil et l'insigne sur ses messages hors-RP ; `/staff` n'atteint que le
   Conseil ; un joueur sans rang ne se voit pas suggérer `/staff` et, s'il le tape, reçoit « Ce canal est réservé au
   Conseil ». Nommé au Conseil en cours de partie (`vava_conseil <compte> gardien`), il a l'onglet, `/staff` et les
   suggestions de son rang sans se reconnecter ; révoqué, il les perd de même.
8. Déplacer la fenêtre par son bandeau, l'agrandir par son coin, se reconnecter : elle est à la même place.
   `/chat reinit` la remet en place.
9. Joueur sans rang (ou Gardien) : `/m` puis Tab complète `/me`, encore Tab : `/mp`. Chez un membre du Conseil qui a
   le droit `tools` (Sénéchal et au-dessus, avec le Codex), les six suggestions de `/m` sont `/magie` et ses premières
   sous-commandes, décrites elles aussi et premières dans l'ordre alphabétique : Tab tourne entre elles ; taper `/me`
   avant Tab. `/commandeinconnue` : « Commande inconnue » pour soi seul.
10. Les messages de la magie (`/magie`, grimoire) arrivent dans Général.
11. Dans la base, `vava_chat_logs` contient les `/ooc`, `/mp` et `/staff`, pas les `/me` ni les `/do`.
