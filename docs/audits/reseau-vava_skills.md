# Audit réseau et performance — vava_skills 1.1.3 — 30 octobre 2026 (T-011)

## Périmètre

Compétences, rangs, mentorat, leçons, pénuries. Lus : `server/progression.lua` (`:60-75`), `server/mentoring.lua`
(`:50-70`, `:215-230`), `server/lessons.lua` (`:80-131`), `server/shortages.lua`, `server/main.lua` (RPC),
`client/main.lua` ; relevés par recherche : envois, boucles, state bags.

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| `SKILL` (une compétence et le budget) | `server/progression.lua:72` | le joueur | environ 120 o : **la seule compétence changée** | à chaque gain d'XP |
| `MENTORSHIP` | `server/mentoring.lua:63-66` | le maître ou l'apprenti concerné | 100-300 o | à chaque changement d'un mentorat |
| `PROPOSAL` | `server/mentoring.lua:224` | le joueur sollicité | 100 o | par proposition |
| `RECIPE`, `LESSON` | `server/lessons.lua:86`, `:129-130` | l'élève ; le maître et l'élève | 100-150 o | par recette apprise, par leçon |
| `NOTIFY` | `bridge/server.lua:195` | le joueur | 50-150 o | messages |
| réponse `sheet` (livre des compétences) | RPC `server/main.lua:69` | le demandeur | fiche complète : 1 à 3 Ko | à l'ouverture du livre |
| réponse `shortages` | RPC `server/main.lua:89` | le demandeur | liste courte | à la demande ; recalcul serveur toutes les 30 min (`server/shortages.lua:98-107`) sans aucun envoi |

## GlobalState, state bags, props

Aucun.

## Boucles

Aucune côté client. Côté page : minuteur d'une seconde seulement tant qu'une proposition attend
(`web/js/view-mentoring.js:178`). Côté serveur : recompte des pénuries toutes les 30 min, une requête groupée.

## NUI et fichiers web

`web/` : 296 527 o, dont 213 553 o communs (T-012) ; `web/js/devmock.js` (7 755 o) livré.

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

Aucun.

## Points solides

- Modèle « différence » appliqué : un gain d'XP n'envoie que la compétence changée (`progression.lua:72`) ; la fiche
  complète seulement à l'ouverture du livre.
- Pénuries calculées côté serveur, lues à la demande : rien n'est diffusé.

VERDICT : OK
