--[[
    vava_codex/content/royaume.lua
    Rôle : pages du chapitre « Le royaume » (texte provisoire, sobre : le texte définitif est celui du gardien du
           lore), dont la seule page réservée au Conseil (« Siéger au Conseil », `audience = 'admin'` : jamais dans
           l'index d'un joueur, refusée par le RPC). Chaque page dit le jeu tel qu'il est codé : une règle qui change
           dans un module cité fait relire la page (voir les sources en tête de chaque page).
    Dépendances : content/chapters.lua (VavaCodex.seed)
]]

local pages = VavaCodex.seed.pages

-- Sources : vava_magic (mage fait par le Conseil, sans détail de commande : décision 11 de la spec T-023 ; mana et
-- recharge, incantation brisée, touches vava_magic_annuler, vava_magic_roue, vava_magic_viser, vava_magic_lancer,
-- vava_magic_verrou ; mains vides et à pied ; progression des sorts ; éléments ; /grimoire ; Murmure et sigils :
-- /sigil offrir ; registre des murmures ; combinaisons découvertes ; lieux protégés ; rien à terre). Ne rien dire
-- des combinaisons, des chiffres ni des sorts à venir.
pages[#pages + 1] = {
    id = 'magie', chapter = 'royaume', order = 10,
    title = 'La magie', summary = 'Elle répond à certains, et se paie toujours.',
    audience = 'player', permission = '', requires = 'vava_magic',
    body = [==[
La magie ne répond pas à tous, et elle ne s’apprend pas comme un métier. Si vous pensez qu’elle vous a répondu,
faites-le savoir au Conseil.

## Ce qu’elle coûte
Chaque sort puise dans une réserve de force, qui revient lentement ; rien ne se lance à vide, et chaque sort a son
temps de repos. Une incantation se brise si l’on bouge trop, si l’on est frappé, ou par
[[touche:vava_magic_annuler]].

## Lancer un sort
- La roue des sorts : maintenir [[touche:vava_magic_roue]].
- Viser : [[touche:vava_magic_viser]].
- Lancer : [[touche:vava_magic_lancer]], les mains vides et à pied.
- Désigner une cible : [[touche:vava_magic_verrou]].

Les sorts grandissent avec la pratique. On connaît le feu, l’eau, la terre, et des sorts de lumière et d’esprit.
Le grimoire ([[commande:grimoire]]) garde ce que l’on sait.

## Le Murmure
Il atteint au loin ceux dont on a reçu le sigil ; un sigil s’échange face à face ([[commande:sigil offrir]]). Un
registre peut garder les murmures.

## Ce qui reste à découvrir
Les éléments mêlés donnent parfois autre chose : ce que l’on découvre s’inscrit au grimoire. Certains lieux sont
protégés.

> À terre, on ne lance rien, et aucun sort ne vous touche.
]==],
}

-- Sources : vava_admin (rôle du Conseil, trois rangs, /signaler un à la fois et ses suites, réponse en privé, Registre
-- du Conseil) ; vava_chat (insigne des messages du Conseil hors du rôle). Ne rien dire des sanctions ni des droits de
-- chaque rang (page suivante, réservée), ni que « le Conseil donne ».
pages[#pages + 1] = {
    id = 'conseil', chapter = 'royaume', order = 20,
    title = 'Le Conseil', summary = 'Ceux qui veillent sur le royaume, et comment les joindre.',
    audience = 'player', permission = '', requires = 'vava_admin',
    body = [==[
Le Conseil veille sur le royaume, hors du rôle. Il compte trois rangs : Gardien, Sénéchal et Souverain.

## Le joindre
- Par [[commande:signaler]] : un signalement à la fois ; vous êtes prévenu quand il est pris en charge, puis quand
  il est clos.
- Il peut vous répondre en privé ; ses messages hors du rôle portent un insigne.

## Ce qu’il fait
Il aide un personnage bloqué, ou blessé par un souci hors du rôle, et veille aux règles du serveur. Chacune de ses
actions est inscrite au registre du Conseil.
]==],
}

-- Sources : vava_admin (droits cumulés de chaque rang, docs/api.md § vava_admin ; Registre : touche conseil ; journal) ;
-- vava_chat (canal du Conseil /staff, non déclaré au registre : sans jeton) ; vava_atelier (touche atelier, droit
-- metiers) ; vava_gathering, vava_crafting, vava_farming, vava_skills (/recolte zones, /artisanat stations,
-- /agriculture parcelles, /metiers voir : droit metiers) ; vava_arrival (/accueil etat : droit give) ; vava_magic
-- (/magie fiche) et vava_time (/ciel) : droit tools. Ne rien dire des commandes de console, des comptes ni des
-- réglages techniques.
pages[#pages + 1] = {
    id = 'conseil_sieger', chapter = 'royaume', order = 30,
    title = 'Siéger au Conseil', summary = 'Rangs, droits et outils, et l’esprit dans lequel on s’en sert.',
    audience = 'admin', permission = '', requires = 'vava_admin',
    body = [==[
Cette page n’est lue que des membres du Conseil.

## Les rangs
Les droits s’ajoutent d’un rang à l’autre.
- *Gardien* : voir, rejoindre, immobiliser, soigner, écrire, avertir, expulser, traiter les signalements, l’écran
  des joueurs.
- *Sénéchal* : en plus, bannir pour un temps limité, les inventaires, donner, annoncer, les outils, observer, le
  journal, les bans, les métiers.
- *Souverain* : en plus, lever un ban, nommer, bannir sans terme.

## Les outils
- Le Registre du Conseil : [[touche:conseil]].
- Le canal du Conseil : /staff dans le chat.
- L’Atelier : [[touche:atelier]] (droit métiers).
- Les métiers : [[commande:recolte zones]], [[commande:artisanat stations]], [[commande:agriculture parcelles]],
  [[commande:metiers voir]].
- L’accueil des nouveaux venus : [[commande:accueil etat]] (droit donner).
- La magie et le ciel : [[commande:magie fiche]], [[commande:ciel]] (droit outils).

> Toute action du Conseil est inscrite au journal et au Registre.

## L’esprit
Le Conseil répare et arbitre ; il n’enrichit personne. Un don qui rendrait un joueur autosuffisant défait ce qui
fait vivre Eldoria : le besoin des autres.
]==],
}
