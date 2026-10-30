# Audit sécurité — vava_chat 1.1.1 — 29 octobre 2026 (T-010)

## Périmètre

Rôle : le chat du royaume à la place de la ressource `chat` de FiveM (`provide 'chat'`, `fxmanifest.lua:23`) :
`/ooc`, `/me`, `/do` à portée, `/mp` et `/r`, `/staff` (Conseil), onglets, journal de modération 7 jours.

Lu en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `shared/text.lua`, `sql/0001_chat.sql`,
`server/{core,links,sessions,audience,logs,messages,compat,api,commands,main}.lua`,
`client/{core,nui,layout,suggestions,compat,outbox,commands,overhead,input,visibility,main}.lua`, `web/index.html`,
`web/js/{bridge,ui,lines,tabs,suggest,composer,layout,chat,app}.js`. Côté core, ce dont dépendent les affirmations :
`server/core/rpc.lua` (chaîne de contrôle), `shared/lib/schema.lua` (bornes), `server/core/ratelimit.lua`,
`config/server.lua` (limites globales, bornes de nom), `server/players/characters.lua` (`unload`, `withSession`).
Voisins : `vava_codex/server/suggestions.lua` et `catalog.visible`, `vava_admin/server/api.lua` (`rankOf`).

Non lu : `web/css/style.css` (pas de code), `web/js/devmock.js` (aperçu hors jeu : en jeu `Bridge.post` ne l'appelle
pas, `web/js/bridge.js:22`), `docs/tests/chat.md`. Le comportement de FXServer sur les ACE des commandes non restreintes
n'a pas pu être vérifié hors jeu : il est signalé comme tel (MINEUR 1).

Corrections de T-008 retrouvées dans le code : profil redemandé quand le rang change (`client/main.lua:141-146`),
suggestions décrites remplacées et non ajoutées (`client/suggestions.lua:146-173`), `/staff` réservé au Conseil
(`client/commands.lua:141`, `client/suggestions.lua:123-128` et `:85`).

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vava_chat:send` | RPC (`server/main.lua:72`) | `KIND` enum `ooc/me/do/mp/staff` (`:26`), `TEXT` chaîne ≤ 1100 octets (`:27`), `PLAYER` entier 0–65535 (`:28`), `CHAT` entier 0–2^31−1 (`:29`) | 6 puis 1/s (`config.lua:81`) ; global core 40 puis 20/s | session du personnage (`messages.lua:65`) ; UTF-8 valide, contrôles et `^0-9` retirés, 250 signes (`:67-70`, `shared/text.lua:28-59`) ; `/mp` : correspondant par conversation ou numéro, jamais soi-même (`:41-54`) ; `/staff` : rang relu à chaque message (`:78-79`, `links.lua:62-69`) ; `/ooc` `/me` `/do` : positions et monde de routage lus côté serveur (`audience.lua:20-38`) ; hook `vava_chat:sending` (`:88`) | destinataires choisis par le serveur, jamais `-1` ; nom = personnage (`links.lua:51-55`) ; journal `/ooc` `/mp` `/staff` (`:110-111`) |
| `vava_chat:profile` | RPC (`server/main.lua:73`) | `{}` | 4 puis 1 toutes les 5 s (`config.lua:82`) | session (`:34-35`) ; commandes filtrées par ACE (`compat.lua:60-72`) ; suggestions du Codex filtrées par ses droits (`vava_codex/server/catalog.lua:103-107`), appel isolé (`compat.lua:82-90`) | voir MINEUR 1 (noms de commandes) |
| `__cfx_internal:commandFallback` | évènement réseau hors RPC (`server/compat.lua:97-104`) | `type == 'string'` et ≤ 512 octets (`:100`) ; nom nettoyé puis coupé à 32 signes (`:101-103`) | seau par joueur 3 puis 1 toutes les 2 s (`:34-46`, `config.lua:83`), purgé au départ (`:93-95`, `main.lua:83`) | aucune action : un avis au seul joueur (`:103`) | ne lance rien ; une valeur refusée avant le seau (type, taille) coûte un test ; voir « Points solides » |
| `addMessage(cible, message)` | export serveur (`server/api.lua:55-73`) | cible entier connecté ou −1 (`:57`) ; texte nettoyé lignes gardées, 500 signes (`:61-64`) ; auteur 32 signes (`:65`) ; couleur 3 entiers 0–255 (`:25-32`) | — (ressources serveur) | −1 = joueurs en jeu seulement (`:71`) | modèles HTML jamais lus (`read`, `:38-50`) |
| `core:character:loaded` / `unloading` / `core:player:dropped` / `vava_admin:action` / `core:module:ready|stopped` | hooks `after` (`server/main.lua:78-91`) | payload du core | — | rang relu au tick suivant (`:56-66`, `sessions.lua:98-109`) | évènement `vava_chat:profile` au seul joueur visé |
| `chat:addMessage`, `chatMessage`, `chat:addSuggestion(s)`, `chat:removeSuggestion`, `chat:clear`, `__cfx_internal:serverPrint`, `chat:addTemplate`, `chat:add/removeMode` | évènements client (`client/compat.lua:81-101`) | args ≤ 8, texte 500 signes, auteur 32, couleur bornée (`:31-79`), listes ≤ 400 (`:87`) | — | — (serveur → client, ou local) | modèles et modes acceptés sans effet (`:96-98`) |
| `vava_chat:message` / `gone` / `profile` / `notice` | évènements client (`client/main.lua:116-151`) | genre connu, `id` > 0, nom ≤ 96 o, texte ≤ 1100 o, `chat` > 0, rang ≤ 64 o, détail ≤ 160 o | — | — | données vérifiées avant la page |
| `ready`, `close`, `submit`, `layout` | callbacks NUI (`client/nui.lua:74`, `client/input.lua:58-75`, `client/layout.lua:58-62`) | `submit` : texte ≤ 1260 octets, onglet ≤ 16 octets, `chat` entier 1–2^31−1 ; `layout` : parts d'écran bornées (`layout.lua:32-35`) | — | `submit` → RPC `vava_chat:send` ou `ExecuteCommand` local (`client/commands.lua:99-128`) | rien côté serveur sans RPC ; chaque callback isolé par `xpcall` (`nui.lua:55-65`) |
| `vava_chat_logs` | SQL (`server/logs.lua:19-22,50,120`) | `?` partout ; `LIMIT %d` tiré de la config (`:22`) | — | — | insertion groupée inscrite dans `scripts/audit-exceptions.txt` |

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

- `server/compat.lua:60-72` et `client/suggestions.lua:194-217` — **noms des commandes du Conseil et des métiers
  suggérés à tous** — les commandes enregistrées sans restriction (`RegisterCommand(…, false)` :
  `vava_magic/server/admin.lua:316`, `vava_skills/server/admin.lua:139`, `vava_crafting/server/admin.lua:69`,
  `vava_farming/server/admin.lua:96`, `vava_gathering/server/admin.lua:77`, `vava_inventory/server/catalog.lua:298` ;
  côté client `conseil` `vava_admin/client/main.lua:24`, `zonesvoix` `vava_voice/client/main.lua:100`,
  `vava_cameras/client/main.lua:25`) passent le filtre `IsPlayerAceAllowed(src, 'command.' .. name)` puisque FXServer
  accorde `command.<nom>` à `builtin.everyone` pour une commande non restreinte ; seuls `^vava_` et `^[+-_]` sont
  cachés (`config.lua:78`). Fuite de noms seulement : chaque commande revérifie le droit côté serveur, et c'est le même
  comportement que la ressource `chat` d'origine. Correction : nourrir `hidden` par le registre `core:commands`
  (`scope = 'admin'` ou `permission`) ou enregistrer ces commandes restreintes avec un ACE donné par vava_admin. À
  confirmer en jeu : `/m` chez un joueur sans rang doit montrer `/magie` sans aide.
- `server/messages.lua:73-75` — **aucun moyen d'ignorer un correspondant** — un joueur peut écrire en privé à
  n'importe quel numéro, 1 message par seconde sans fin ; seul le hook `vava_chat:sending` (`:88`) permettrait à un
  module de poser une sourdine, et le journal sert la modération après coup. Correction : liste « ignorer » par
  personnage (champ privé) consultée dans `resolvePeer`, ou refus d'un `/mp` vers un joueur qui n'a jamais répondu
  au-delà de N messages.
- `server/main.lua:27` — **`TEXT` sans motif ancré** — écart à la règle 2 de `CLAUDE.md` (motif sur chaque chaîne) :
  le texte libre passe par le schéma avec sa seule borne d'octets, le nettoyage se fait ensuite (`shared/text.lua:28`).
  Les classes `%c`/`%s` de Lua suivant la langue du système (commentaire `text.lua:5-6`), un motif octet par octet
  `'^[^\0-\8\11-\31\127]*$'` refuserait tôt les caractères de contrôle sans toucher à l'UTF-8 ; purement défensif.

## Points solides

- Une seule porte réseau de joueur : deux RPC à schéma fermé (enum, entiers bornés, octets bornés) et à débit limité ;
  le repli de commande hors RPC (`server/compat.lua:97-104`) n'exécute rien, répond au seul joueur, est borné en taille
  et en débit, et ses contrôles vont du moins cher au plus cher.
- Rien n'est cru du client : portées, monde de routage, nom du personnage, rang du Conseil et correspondant d'un
  `/mp` sont lus ou choisis par le serveur ; `/staff` relit le rang à chaque message (un rang retiré ferme le canal
  aussitôt).
- Aucun envoi à `-1` : chaque message part aux seuls destinataires calculés ; l'export `addMessage(-1, …)` parcourt
  les sessions en jeu.
- Page : aucun `innerHTML` (vérifié par grep sur `web/js/*.js`) ; tout texte passe par `textContent` ou
  `createTextNode` (`web/js/ui.js:33-52`) ; la couleur d'un message système est reconstruite de trois entiers validés
  (`client/compat.lua:31-40`, `web/js/lines.js:106-107`) ; les modèles HTML de l'ancien chat sont ignorés.
- SQL paramétré et groupé par constantes, purge par tranches, file bornée (`server/logs.lua`) ; journal des genres
  sensibles (`/ooc`, `/mp`, `/staff`) ; chaque callback NUI et chaque appel inter-ressources est isolé.

VERDICT : OK
