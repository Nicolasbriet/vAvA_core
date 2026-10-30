# Audit sécurité — vava_hud 1.3.0 — 29 octobre 2026 (T-010)

## Périmètre

Rôle : ressource **cliente** seulement : retire l'interface native de GTA, affiche jauges, notifications et barre de
progression pour tous les modules par exports ; aucun script serveur, aucun échange réseau.

Fichiers lus en entier : `fxmanifest.lua`, `config.lua`, `client/main.lua`, `client/nui.lua`, `client/gauges.lua`,
`client/native.lua`, `client/notify.lua`, `client/progress.lua`, `client/core.lua`, `web/index.html`,
`web/js/hud.js`, `web/js/devmock.js`. Pour le contexte : les appelants `modules/vava_inventory/client/main.lua:57-72`
et `modules/vava_needs/client/hud.lua:35-62`, `:89-94`.

Non lus : `web/css/style.css`, polices et images (aucune logique) ; `README.md` (procédures).

## Points d'entrée

Aucun RPC, aucun évènement réseau, aucun state bag : rien de ce module ne touche au serveur, et un client qui le
modifie ne change que son propre affichage. Les entrées sont les exports (appelables par les autres ressources du même
client) et le retour NUI `ready`.

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `defineGauge(id, options)` | export client | `id` `^[%w_%-%.]+:[%w_%-%.]+$` ≤ 64 **préfixé par la ressource appelante** (`gauges.lua:16`, `:56-59`, `main.lua:44-46`) ; `label` 1..32, `icon` ≤ 200 commençant par `nui://` (`:71-72`), `order` entier 0..1000 (`:73`), paliers 0..1 avec `critical ≤ low` (`:74-75`), 12 jauges au plus (`:77`) | — (client) | sans objet : purement visuel | une ressource ne déclare que ses jauges, retirées à son arrêt (`:140-148`, `main.lua:80-87`) |
| `setGauge`, `setGaugeActive`, `removeGauge` | export client | valeur nombre, NaN refusé, ramenée à 0..1 (`gauges.lua:99-100`) ; booléen (`:117`) | — | sans objet | propriété vérifiée (`:98`, `:116`, `:131`) ; rien n'est envoyé si la valeur ne change pas (`:101`, `:118`) |
| `notify(message, kind)` | export client | chaîne non vide tronquée à 200 (`notify.lua:24-26`), `kind` ∈ `info`/`warning`/`danger` (`:27-28`) | — | sans objet | affiché en `textContent` (`hud.js:77`) ; 4 visibles au plus, retirées après 4,5 s (`:79-81`) |
| `progress(id, options)`, `cancelProgress(id)`, `currentProgress()` | export client | `id` même motif et préfixe (`progress.lua:44-47`), `label` 1..60, `durationMs` entier 250..120 000 (`:52-60`, `:97-98`), `cancelable` booléen (`:99`), une seule à la fois (`:100`) | — | sans objet : « purement visuelle, le serveur reste maître du temps » (`docs/api.md`) | seule la ressource qui l'a lancée l'interrompt (`:121-127`) ; fin programmée une fois (`:110-113`) |
| `ready` | NUI | aucun argument lu | — | sans objet | renvoie l'état complet à la page (`nui.lua:23-29`), rejouable sans effet de bord |
| `core:character:spawning` / `selection` / `unloaded` | hook client | payload du core | — | sans objet | visibilité du HUD, progression interrompue (`main.lua:65-78`) |
| messages NUI `init`, `define`, `value`, `active`, `remove`, `visible`, `notify`, `progress`, `progressEnd` | NUI (jeu → page) | `handlers[data.action]` seulement (`hud.js:188-192`) | — | sans objet | textes en `textContent` (`:44`, `:77`) ou attributs ARIA (`:54`, `:142`) ; `img.src` reçoit une icône déjà filtrée `nui://` (`:143`) ; aucun `innerHTML` dans la page |

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

- `modules/vava_hud/client/notify.lua:26` — **troncature par octets d'un message long** — `message:sub(1, 200)` peut couper un caractère UTF-8 en deux (« é », « œ » font deux octets) et laisser un octet invalide en fin de notification ; effet cosmétique, aucun risque d'exécution (`textContent`). Correction : couper sur une frontière de caractère (`utf8.offset(message, 201)`), ou accepter la coupe et le documenter.

## Points solides

- Ressource cliente sans aucune surface réseau : rien à duper côté serveur, rien à rejouer.
- Chaque export vérifie type, longueur, motif et bornes de ce qu'il reçoit, et la propriété par `GetInvokingResource` : une ressource ne touche qu'à ses jauges et à sa progression, purgées à son arrêt.
- Icônes limitées à `nui://` (`gauges.lua:18`, `:72`) : aucune requête vers l'extérieur déclenchée par un module.
- Page web sans `innerHTML` ni évaluation : messages, libellés et indices affichés comme texte, états portés par des classes et des attributs `data-*`/ARIA.
- La barre de progression n'influence aucune décision : la durée réelle d'une action reste revérifiée par le serveur du module appelant.

VERDICT : OK
