# Audit réseau et performance — vava_chat 1.1.1 — 30 octobre 2026 (T-011)

## Périmètre

Chat du royaume : `/ooc`, `/me`, `/do` à portée, messages privés, canal du Conseil, textes au-dessus des têtes,
compatibilité avec la ressource `chat` de FiveM. Lus en entier : `server/messages.lua`, `server/audience.lua`,
`server/api.lua`, `server/sessions.lua` (`:55-109`), `client/visibility.lua`, `client/overhead.lua` (`:60-149`),
`config.lua` (portées, intervalles).

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| `MESSAGE` (`/ooc`, `/me`, `/do`) | `server/messages.lua:31-33`, `:102-106` | l'auteur et les joueurs en jeu à moins de 20 m (`/ooc`) ou 15 m (`/me`, `/do`), positions serveur, même instance (`server/audience.lua:20-38`) | 60 o + texte (500 signes au plus) | par message |
| `MESSAGE` (privé) | `server/messages.lua:94-99` | le correspondant et l'auteur | idem | par message |
| `MESSAGE` (Conseil) | `server/messages.lua:80` | les membres du Conseil en jeu | idem | par message |
| `GONE` | `server/sessions.lua:64` | les seuls correspondants du joueur qui part | 10 o | au départ |
| `PROFILE` | `server/sessions.lua:104` | le joueur | 30 o | rang changé |
| `NOTICE` (commande inconnue) | `server/compat.lua:103` | le joueur | 40 o | rare |
| `chat:addMessage` (export) | `server/api.lua:67-72` | un joueur, ou **tous les joueurs en jeu** avec la cible -1 | 60 o + texte | à la demande d'un autre module ; seule la forme ciblée est employée dans le dépôt |
| réponse du profil (commandes permises et suggestions du Codex) | `server/main.lua:31-38` | le joueur | quelques Ko | une fois par apparition |

## GlobalState, state bags, props

Aucun.

## Boucles client

| Boucle | Fichier:ligne | Au repos | En action | Remarque |
|---|---|---|---|---|
| visibilité (menu pause, écran noir) | `client/visibility.lua:37-42` | **300 ms, permanente** | idem | message à la page seulement au changement |
| textes au-dessus des têtes | `client/overhead.lua:85-118` | — | par image tant qu'une bulle vit (8 s) ; ligne de vue relue toutes les 300 ms | justifié |
| profil au démarrage | `client/main.lua:73-85` | — | 4 essais espacés de 3 s | borné |

## NUI et fichiers web

Messages à la page à chaque message reçu et au changement de visibilité. `web/` : 280 062 o, dont 213 553 o communs
(T-012) ; `web/js/devmock.js` (5 430 o) livré.

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

- `server/api.lua:71` — **envoi à tous écrit comme une boucle** — `addMessage(-1, …)` parcourt tous les joueurs en
  jeu : c'est un envoi à tous que `audit-reseau.sh` ne voit pas. Inutilisé dans le dépôt ; à documenter comme
  l'annonce du Conseil (rare, réservée) et à inscrire aux exceptions, ou à retirer de l'export.
- `client/visibility.lua:37-42` — **seconde boucle de visibilité** — `vava_hud` relit le même état (menu pause, écran
  noir) toutes les 250 ms (`vava_hud/client/main.lua:90-95`) ; une seule boucle (dans le HUD, avec un hook client
  `vava_hud:visible`) suffirait. À décider après la mesure du resmon.

## Points solides

- Portées calculées par le serveur sur les positions serveur, même instance de routage ; l'auteur toujours inclus ;
  journal groupé côté serveur.
- Bulles au-dessus des têtes : par image seulement tant qu'une bulle vit, ligne de vue relue à 300 ms.

## À vérifier en jeu

- `/vava_reseau` : un `/ooc` à 25 m d'un autre joueur ne lui parvient pas.

VERDICT : OK
