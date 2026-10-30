--[[
    vava_codex/content/royaume.lua
    Rôle : pages du chapitre « Le royaume » (texte du gardien du lore, T-023), dont la seule page réservée au Conseil (« Siéger au Conseil », `audience = 'admin'` : jamais dans
           l'index d'un joueur, refusée par le RPC). Chaque page dit le jeu tel qu'il est codé : une règle qui change
           dans un module cité fait relire la page (voir les sources en tête de chaque page).
    Dépendances : content/chapters.lua (VavaCodex.seed)
]]

local pages = VavaCodex.seed.pages

-- Sources : vava_magic (mage éveillé par le Conseil, sans détail de commande : décision 11 de la spec T-023 ; mana
-- qui revient lentement, rien à vide, recharges et délai entre deux sorts ; incantation brisée par le mouvement, un
-- coup, un contrôle dur ou la touche vava_magic_annuler ; roue : touche vava_magic_roue maintenue, sort préparé dans
-- les mains ; viser, lancer mains vides et à pied, verrouiller : touches vava_magic_viser, vava_magic_lancer,
-- vava_magic_verrou ; frisson de la cible ; mode magie qui s'endort, réveillé en visant ; cinq niveaux par sort ;
-- éléments feu, eau, terre, lumière, esprit ; /grimoire, pages illisibles pour un non-mage ; Murmure et sigils :
-- /sigil offrir face à face, sigil brouillé ; fragments du murmure lus des témoins tout proches ; registre des
-- murmures porté sur soi, historique qui suit l'objet ; combinaisons inscrites au grimoire, les autres comptées sans
-- être nommées ; zones protégées ; rien à terre). Ne rien dire des combinaisons, des chiffres ni des sorts à venir.
pages[#pages + 1] = {
    id = 'magie', chapter = 'royaume', order = 10,
    title = 'La magie', summary = 'Elle répond à certains, et se paie toujours.',
    audience = 'player', permission = '', requires = 'vava_magic',
    body = [==[
La magie ne répond pas à tous, et elle ne s’apprend pas comme un métier. Ceux à qui elle a répondu le sentent, et
le Conseil sait en reconnaître les signes. Si vous croyez qu’elle vous a répondu, faites-le-lui savoir.

## Ce qu’elle coûte
Chaque sort puise dans une réserve de force, la mana, qui ne revient que lentement : rien ne se lance à vide.
Chaque sort a aussi son temps de repos, et l’on ne lance pas deux sorts coup sur coup.

Une incantation se brise si l’on bouge trop, si l’on est frappé ou ébranlé, ou si on l’interrompt soi-même
([[touche:vava_magic_annuler]]).

## Lancer un sort
- Maintenez [[touche:vava_magic_roue]] : la roue des sorts s’ouvre. Relâchez sur un sort pour le préparer dans vos
  mains.
- Visez avec [[touche:vava_magic_viser]], lancez avec [[touche:vava_magic_lancer]], les mains vides et à pied.
- [[touche:vava_magic_verrou]] désigne une cible ; quand vous incantez contre elle, un frisson la parcourt.

Laissée sans usage un moment, la magie s’assoupit dans vos mains : visez pour la réveiller.

Les sorts grandissent avec la pratique. On connaît le feu, l’eau et la terre, et des sorts de lumière et d’esprit.
Le grimoire ([[commande:grimoire]]) garde ce que vous savez ; pour qui n’a pas le don, ses pages restent
illisibles.

## Le Murmure
Il porte vos mots au loin, jusqu’à ceux dont vous avez reçu le sigil. Un sigil se confie face à face
([[commande:sigil offrir]]), et l’on peut brouiller le sien pour couper les liens anciens. Qui se tient tout près
d’un mage qui murmure en saisit parfois quelques mots.

Un registre des murmures, porté sur soi, garde ce que l’on envoie et ce que l’on reçoit. S’il change de mains, ses
pages le suivent.

## Ce qui reste à découvrir
Les éléments mêlés donnent parfois autre chose que ce que l’on attendait. Ce que l’on découvre s’inscrit au
grimoire ; le reste se tait. Certains lieux sont protégés : nul n’y lance de sort, et aucun sort n’y blesse.

> À terre, on ne lance rien, et aucun sort ne vous touche.
]==],
}

-- Sources : vava_admin (rôle du Conseil, trois rangs ; /signaler avec un message, délai entre deux signalements,
-- avis de prise en charge et de clôture ; « Message du Conseil » en privé ; annonces à tous ; aide : rejoindre,
-- soigner, nourrir, libérer ; Registre et journal de chaque action) ; vava_chat (insigne des messages du Conseil hors
-- du rôle). Esprit de la décision 6 de la spec T-023 : le Conseil répare, il n'enrichit personne. Ne rien dire des
-- sanctions ni des droits de chaque rang (page suivante, réservée), ni que « le Conseil donne ».
pages[#pages + 1] = {
    id = 'conseil', chapter = 'royaume', order = 20,
    title = 'Le Conseil', summary = 'Ceux qui veillent sur le royaume, et comment les joindre.',
    audience = 'player', permission = '', requires = 'vava_admin',
    body = [==[
Le Conseil veille sur le royaume, hors du rôle. Il compte trois rangs : Gardien, Sénéchal et Souverain. Ceux qui y
siègent ont accepté cette charge pour que chacun puisse jouer en paix.

## Le joindre
- [[commande:signaler]], suivi de quelques mots : votre signalement part au Conseil. Vous êtes prévenu quand un
  membre le prend en charge, puis quand il est clos.
- Dites où vous êtes, ce qui s’est passé et qui est en cause : on vous aidera plus vite.
- Laissez passer un moment entre deux signalements.

Le Conseil peut vous écrire en privé. Dans le chat, ses messages hors du rôle portent un insigne ; quand il
s’adresse au royaume tout entier, son annonce paraît devant chacun.

## Ce qu’il fait
Il vient en aide à un personnage bloqué, ou blessé par un souci hors du rôle, et veille au respect du règlement.
Il répare ce qu’un tel souci a défait ; il n’enrichit personne. Ce que vous possédez, vous le devez à votre
travail et aux autres.

## Ce qu’il ne fait pas
Le Conseil ne joue pas vos histoires à votre place. Une querelle, un vol, une parole trahie se règlent dans le
rôle, entre vous ; il n’y entre que si le règlement est en cause.

> Chacune de ses actions est inscrite au registre du Conseil.
]==],
}

-- Sources : vava_admin (droits cumulés de chaque rang, config.ranks et docs/api.md § vava_admin ; actions qui
-- contraignent protégées par le rang ; vol libre : droit tools ; Registre : touche conseil ; journal) ; vava_voice et
-- vava_time (zones de voix, ciel et heure : droit tools) ; vava_skills (fondateurs : droit staff) ; vava_chat (canal
-- du Conseil /staff, non déclaré au registre : sans jeton) ; vava_atelier (touche atelier, droit metiers ; socle 1.0.0
-- sans éditeur réel : « ses ateliers ouvrent peu à peu ») ; vava_gathering, vava_crafting, vava_farming,
-- vava_skills (/recolte zones, /artisanat stations, /agriculture parcelles, /metiers voir : droit metiers) ;
-- vava_arrival (/accueil etat : droit give) ; vava_magic (/magie fiche ; mage éveillé par le Conseil) et vava_time
-- (/ciel) : droit tools. Ne rien dire des commandes de console, des comptes ni des réglages techniques ; la durée
-- maximale d'un ban (config.ranks[].maxBanHours) n'est pas citée.
pages[#pages + 1] = {
    id = 'conseil_sieger', chapter = 'royaume', order = 30,
    title = 'Siéger au Conseil', summary = 'Rangs, droits et outils, et l’esprit dans lequel on s’en sert.',
    audience = 'admin', permission = '', requires = 'vava_admin',
    body = [==[
Cette page n’est lue que des membres du Conseil. Elle dit ce que chaque rang peut faire, et l’esprit dans lequel
on le fait.

## Les rangs
Les droits s’ajoutent d’un rang à l’autre.
- *Gardien* : voir qui est en jeu, le rejoindre ou l’amener, immobiliser, soigner et nourrir, écrire, avertir,
  expulser, traiter les signalements, l’écran des joueurs.
- *Sénéchal* : en plus, bannir pour un temps borné, fouiller une besace, donner, annoncer au royaume, les outils
  (vol libre, ciel et heure, zones de voix, magie), observer, le journal, la liste des bans, les métiers.
- *Souverain* : en plus, lever un ban, nommer au Conseil et nommer les fondateurs d’un savoir, bannir sans terme.

Ce qui contraint quelqu’un (déplacer, immobiliser, avertir, expulser, bannir, fouiller, observer) ne vise jamais
un membre de rang égal ou supérieur.

## Les outils
- Le Registre du Conseil : [[touche:conseil]].
- Le canal du Conseil : /staff dans le chat, lu des seuls membres.
- L’Atelier : [[touche:atelier]] (droit des métiers), où le Conseil façonnera le royaume ; ses ateliers ouvrent
  peu à peu.
- Les métiers : [[commande:recolte zones]], [[commande:artisanat stations]], [[commande:agriculture parcelles]],
  [[commande:metiers voir]] (droit des métiers).
- L’accueil des nouveaux venus : [[commande:accueil etat]] (droit de donner).
- La magie et le ciel : [[commande:magie fiche]], [[commande:ciel]] (droit des outils).

> Toute action du Conseil est inscrite au journal et au Registre.

## L’esprit
Le Conseil répare et arbitre ; il n’enrichit personne.
- Donner, c’est rendre ce qu’un souci hors du rôle a fait perdre, jamais épargner à quelqu’un le besoin des autres.
- Corriger une compétence répare une erreur ; ce n’est pas un raccourci vers la maîtrise.
- Observer ou voler invisible sert à vérifier un signalement, non à suivre une intrigue.
- Une affaire du rôle se règle dans le rôle ; le Conseil n’y entre que si le règlement est en cause.
- C’est au Conseil qu’on vient dire que la magie a répondu : qu’elle reste rare, et que son éveil ait un sens dans
  le rôle.

Un don qui rendrait quelqu’un autosuffisant défait ce qui fait vivre Eldoria : chacun a besoin des autres.
]==],
}
