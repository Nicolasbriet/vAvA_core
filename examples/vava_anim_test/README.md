# vava_anim_test — tester des animations personnalisées

Ressource de **test** (serveur de développement seulement : aucun contrôle, tout joueur peut s'en servir). Elle
diffuse aux clients les fichiers `.ycd` posés dans son dossier `stream/` et donne des commandes pour les jouer.

## Mettre une animation

1. Copier le fichier dans `stream/` : le **nom du fichier est le nom du dictionnaire** (`vava_sword_1h.ycd` →
   dictionnaire `vava_sword_1h`).
2. `ensure vava_anim_test` (ou `restart` si elle tournait déjà : un fichier ajouté n'est diffusé qu'au redémarrage).
3. En jeu : `/epee` (raccourci de la config pour `vava_sword_1h`, haut du corps en boucle), ou `/anim vava_sword_1h`.

Un **raccourci** par animation à tester se déclare dans `config.lua` → `shortcuts` (`command`, `label`, `dict`,
`clip` ou nil pour sonder, `flag`). Avec `vAvA_core`, toutes ces commandes apparaissent dans le **Codex** (chapitre
« Tests ») et dans les suggestions du chat, avec leurs arguments ; sans lui, elles marchent quand même.

Le **nom du clip** à l'intérieur du dictionnaire dépend de l'outil qui a produit le `.ycd` (Blender Sollumz,
CodeWalker…). Sans le donner, `/anim <dictionnaire>` essaie les noms courants (`vava_sword_1h`, `vava_sword_1h_clip`,
`clip`, `idle`, `attack`…) et joue le premier qui répond, en listant les autres. Si rien ne répond, ouvrir le `.ycd`
dans CodeWalker (RPF Explorer) : les clips y sont listés ; puis `/anim <dictionnaire> <clip>`.

## Commandes

| Commande | Effet |
| --- | --- |
| `/anim <dictionnaire> [clip] [drapeau] [durée ms]` | charge le dictionnaire, joue le clip (sondé si absent) ; drapeau 1 (boucle) et durée du clip par défaut |
| `/anim` | rejoue la dernière animation |
| `/epee` | joue `vava_sword_1h` sans rien taper (raccourci de la config) |
| `/animstop` | arrête l'animation |
| `/animprop [modèle] [os] [x y z] [rx ry rz]` | accroche un accessoire à la main droite (os 57005) pour juger la pose ; sans argument, le retire |
| `/animflags` | rappelle les drapeaux utiles |

Drapeaux (ils s'additionnent) : `0` corps entier une fois · `1` boucle · `2` garder la dernière image · `16` haut du
corps · `32` le joueur garde la main · `48` haut du corps + main · `49` haut du corps + main + boucle.

Exemples : `/anim vava_sword_1h` · `/anim vava_sword_1h attack 0` (une fois, corps entier) ·
`/anim vava_sword_1h idle 49` (haut du corps en boucle, en marchant) · `/animprop w_me_machete_lr` ·
`/animprop w_me_machete_lr 57005 0.1 0.03 -0.02 -100 0 0` (décalage et rotation ajustés).

Les retours s'affichent dans le chat et dans la console F8 : clip joué et sa durée, clip inexistant (durée nulle),
personnage non libre, dictionnaire inconnu (fichier absent de `stream/` ou ressource non redémarrée).

## Passer en production

Quand l'animation convient, elle se déclare dans le module qui s'en sert (ex. `anims` de la config de
`vava_gathering` ou `vava_crafting`) avec le dictionnaire et le clip trouvés ici ; le `.ycd` se diffuse alors depuis
ce module (son propre `stream/`), et cette ressource de test n'a pas à tourner.
