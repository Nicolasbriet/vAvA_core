--[[
    vava_magic/config.lua
    Rôle : réglages de la magie lus par le seul serveur (servi au seul serveur, jamais téléchargé par les joueurs) :
           régénération de la mana, XP, délais et marges de l'incantation, fiche, contrôles des projectiles à
           l'impact, verrouillage (frisson), durées des états et contrôles durs, zones, sol mouillé, combat entre
           joueurs, protections, tirage et échange des sigils, registre, objets, ambiance (yeux), droits, commandes
           du Conseil, limites de débit, textes du serveur. Complète la table ouverte par config_client.lua (sorts,
           combinaisons, touches, textes affichés par le client…) sans en réécrire une clé (T-132). Modifiable sans
           toucher au code.
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaMagic.config

config.coreVersion = '0.5.0'

-- Mana : régénération, `regenPoints` points toutes les `regenMs` ms. Avec des recharges courtes, c'est la mana qui
-- borne le combat : les coûts des sorts sont réglés en conséquence.
config.mana.regenPoints = 3
config.mana.regenMs = 5000

-- Progression (seuils et coûts : config_client.lua).
config.progression.failureShare = 0.5     -- un échec rapporte cette part de l'XP
config.progression.antiFarmMs = 20000     -- un même sort ne rapporte de l'XP qu'une fois par intervalle

-- Incantation commune à tous les sorts : délais et marges du serveur.
config.casting.globalCooldownMs = 1000   -- délai entre deux sorts, quels qu'ils soient
config.casting.maxMove = 1.0             -- mètres parcourus au plus (sorts sans `moveSpeed`)
config.casting.moveMargin = 0.5          -- marge du serveur sur la distance (positions réseau)
config.casting.finishToleranceMs = 300   -- fin acceptée un peu avant la durée (latence)
config.casting.graceMs = 4000            -- au-delà de la durée, une incantation sans fin est abandonnée

-- Fiche : écrite dans le personnage (le core la sauvegarde par lots) au plus toutes les `flushMs`, et au départ.
config.persistence = { flushMs = 15000 }

-- Projectiles (boule de feu, trait de glace, projectile de roche) : contrôles du serveur à l'impact, communs à
-- tous (positions lues côté serveur) ; un sort peut en changer certains dans son propre `hit`.
config.projectiles.angleDeg = 25           -- écart permis entre la direction du lancer et le point d'impact
config.projectiles.targetMargin = 2.5      -- mètres entre le point d'impact annoncé et la cible
config.projectiles.rangeMargin = 2.0       -- mètres au-delà de la portée
config.projectiles.timeMarginMs = 450      -- avance permise sur le temps de vol (latence)
config.projectiles.broadcastRadius = 150.0 -- joueurs qui voient le lancer
config.projectiles.launchGraceMs = 3000    -- délai d'un impact après la fin du vol
config.projectiles.targetHeight = 0.3      -- cible verrouillée : visée au torse, au-dessus de la position du ped

-- Verrouillage d'une cible : un frisson au plus par lanceur et par cible pendant ce délai (incantation acceptée).
config.targeting.warnIntervalMs = 3000

-- États élémentaires : après un contrôle dur (`hard`), la cible en est protégée `hardImmunityMs` ; les dégâts, eux,
-- s'appliquent toujours.
config.states.hard = { stagger = true, knockdown = true, frozen = true }
config.states.hardImmunityMs = 6000
config.states.durations = { burn = 3000, wet = 12000, slow = 3000, stagger = 1500, knockdown = 1800, frozen = 2000 }

-- Zones au sol (mur de flammes, brume, sol mouillé, présage d'une secousse ; plus tard boue, vapeur), décidées
-- par le serveur : forme, position, élément, fin. Le serveur vérifie toutes les `tickMs` qui s'y trouve (ou les a traversées) ; chaque
-- zone n'est envoyée qu'aux joueurs à moins de `syncRadius`, y compris ceux qui s'en approchent après coup.
config.zones = { tickMs = 500, syncRadius = 150.0, maxActive = 60 }

-- Sol mouillé : qui s'y tient est Mouillé, reposé au plus toutes les `refreshMs` sur un même joueur.
config.wetGround.wetMs = 6000
config.wetGround.refreshMs = 4000

-- Combat entre joueurs. Dégâts des sorts en points de vie, sur `healthPoints` pour un personnage en pleine santé
-- (un coup ne retire jamais plus d'une vie pleine). Chaque coup passe par la chaîne de dégâts de vava_health
-- (exports.vava_health:hit) : son interrupteur `chain.pvp` et ses modificateurs (parades, boucliers, résistances)
-- s'appliquent aux sorts comme aux lames. Sans vava_health, aucun sort ne blesse personne. Un projectile, ses
-- éclats et le présage d'une Secousse lancés debout blessent encore si le lanceur tombe avant l'impact
-- (vava_health ≥ 1.4.0 : `chain.launchedMaxMs`).
-- false : les sorts offensifs se voient et se lancent, mais ne blessent ni ne poussent, gèlent ou ralentissent
-- personne (filtre de la magie) ; `chain.pvp = false` de vava_health (≥ 1.4.0) fait de même
config.combat.pvp = true
config.combat.healthPoints = 100
-- type de dégât de la chaîne pour chaque élément (vava_health `chain.kinds`) ; un élément absent frappe `pur`
-- (ignoré des résistances). La glace (Trait de glace) est de l'eau ; une brûlure mord toujours par le feu.
config.combat.kinds = { feu = 'feu', eau = 'eau', terre = 'terre', lumiere = 'lumiere', esprit = 'esprit' }
-- ancien journal des dégâts des sorts (`vava_magic_damage_log`) : plus écrit depuis 2.9.0 (les coups sont au
-- journal de vava_health, `vava_health_hits`) ; ses lignes plus anciennes que `retentionDays` jours sont retirées
-- au démarrage du module, puis une fois par jour (0 : jamais)
config.combat.log = { retentionDays = 30 }

-- Protections magiques, tenues par le serveur et portées par la chaîne de dégâts de vava_health : un bouclier
-- absorbe les coups (sorts et lames) jusqu'à sa réserve (modificateur `vava_magic:protections`, étape bouclier) ;
-- une résistance retire une part des dégâts d'un type, une faiblesse en ajoute une (`vava_magic:resistances`,
-- étape resistance ; la plus forte de chaque sens l'emporte, jamais cumulées). Aucun des onze sorts n'en pose
-- encore (sorts de protection à venir) ; le Conseil en pose pour l'essai (`/magie proteger`).
config.protections = {
    maxShields = 4,              -- boucliers en cours sur un même joueur (au-delà : refusé)
    maxResistances = 4,          -- résistances et faiblesses en cours sur un même joueur
    maxPoints = 200,             -- réserve d'un bouclier, en points de vie (deux vies pleines)
    defaultDurationMs = 60000,   -- durée d'une protection posée sans durée
    maxDurationMs = 600000,      -- durée la plus longue (10 min)
    kinds = { 'feu', 'eau', 'terre', 'lumiere', 'esprit' }, -- types auxquels on peut résister (vava_health `chain.kinds`)
    ignoredKinds = { privation = true }, -- ni bouclier ni zone de paix contre la faim et la soif
    -- noms des modificateurs (console, journal des coups, /chaine de l'exemple de combat ; 48 octets au plus)
    labels = { zones = 'Zones de paix (magie)', shields = 'Boucliers de la magie', resistances = 'Résistances de la magie' },
}

-- Sigils : tirage, échange face à face, recharge du brouillage.
config.sigils.length = 12
config.sigils.alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'
config.sigils.offerRange = 3.0      -- échange face à face (mètres)
config.sigils.rangeMargin = 0.5
config.sigils.offerMs = 30000       -- délai pour accepter ou refuser
config.sigils.refusedMs = 60000     -- après un refus, délai avant de tendre de nouveau son sigil au même joueur
config.sigils.retries = 5           -- tirages d'un sigil libre
config.sigils.scramble.cooldownMs = 21600000 -- brouiller : 6 h de recharge

-- Registre des murmures (objet) : l'historique suit l'objet ; il est en base sous le numéro du registre.
-- Il s'envoie par lots, les pages les plus récentes d'abord : à l'ouverture le premier lot, puis un lot de plus
-- chaque fois que le lecteur feuillette vers les plus anciennes (le serveur revérifie qu'il porte le registre).
config.registers = {
    maxPages = 200,
    contactMax = 160,
    pageSize = 20,     -- pages par lot (au plus)
    -- poids d'un lot (octets, estimé : correspondant + texte + 52 par page) ; un lot s'arrête avant de le
    -- dépasser (au moins une page) : reste sous 8 Ko (seuil de T-013, taille réelle à mesurer en jeu)
    pageBytes = 7500,
}

-- Objets déclarés dans vava_inventory.
config.items = {
    grimoire = {
        name = 'grimoire', label = 'Grimoire', category = 'divers',
        description = 'Un livre de cuir sombre aux fermoirs de laiton ; ses pages ne parlent qu\'aux mages.',
        width = 2, height = 2, weight = 900, stack = 1, image = 'nui://vava_magic/web/items/grimoire.svg',
    },
    registre = {
        name = 'registre', label = 'Registre des murmures', category = 'divers',
        description = 'Un carnet relié où se couchent d\'eux-mêmes les murmures échangés.',
        width = 1, height = 2, weight = 450, stack = 1, image = 'nui://vava_magic/web/items/registre.svg',
    },
}

-- Effets vus par les autres joueurs : yeux qui s'illuminent (Murmure), en ms.
config.ambient.glowMs = 5000

-- Commandes du Conseil : droit vava_admin (sans vava_admin : permission ACE `ace`).
config.admin = { permission = 'tools', ace = 'magie.admin' }

-- Commandes du Conseil (`/magie`) : sous-commandes et mots.
config.commands.adminActions = {
    mage = 'mage', learn = 'apprendre', forget = 'oublier', level = 'niveau', xp = 'xp',
    all = 'tous', master = 'maitrise', clear = 'vider', mana = 'mana', cooldowns = 'recharges',
    sheet = 'fiche', give = 'donner', cleanup = 'nettoyer', protect = 'proteger',
}
-- `/magie proteger [id] bouclier <points> [secondes]` · `resistance <type> <pour cent> [secondes]` (négatif :
-- faiblesse) · `aucune`
config.commands.protectWords = { shield = 'bouclier', resistance = 'resistance', none = 'aucune' }
config.commands.yes = 'oui'
config.commands.no = 'non'

config.rateLimits = {
    sheet = { capacity = 3, refillPerSecond = 0.2 },
    select = { capacity = 8, refillPerSecond = 2 },
    cast = { capacity = 8, refillPerSecond = 2 },
    cancel = { capacity = 10, refillPerSecond = 2 },
    sigils = { capacity = 6, refillPerSecond = 1 },
    offer = { capacity = 3, refillPerSecond = 0.2 },
    answer = { capacity = 6, refillPerSecond = 1 },
    edit = { capacity = 6, refillPerSecond = 1 },
    scramble = { capacity = 2, refillPerSecond = 0.05 },
    light = { capacity = 6, refillPerSecond = 1 },
    impact = { capacity = 8, refillPerSecond = 3 },
    register = { capacity = 6, refillPerSecond = 1 },
    registerPages = { capacity = 5, refillPerSecond = 1 },
}

-- Textes envoyés par le serveur (français, univers médiéval) : messages au joueur, commandes du Conseil, journal.
local notify = config.texts.notify
notify.levelUp = '%s, niveau %d : %s'
notify.learned = 'Un savoir nouveau s\'éveille en vous : %s.'
notify.forgotten = 'Le sort %s s\'efface de votre mémoire.'
notify.allLearned = 'Tous les sorts s\'éveillent en vous.'
notify.allForgotten = 'Tous vos sorts s\'effacent de votre mémoire.'
notify.becameMage = 'La magie s\'éveille en vous.'
notify.lostMagic = 'La magie s\'est retirée de vous.'
notify.manaRefilled = 'Votre mana est pleine.'
notify.cooldownsReset = 'Vos sorts sont tous prêts.'
notify.murmurDelivered = 'Votre murmure a trouvé son chemin.'
notify.murmurPartial = 'Votre murmure a trouvé %d destinataire(s) sur %d.'
notify.murmurSilent = 'Le lien reste silencieux.'
notify.murmurTooFar = 'Le lien ne porte pas si loin.'
notify.refund = '%d de mana vous reviennent.'
notify.registerFull = 'Votre registre est plein : ce murmure n\'y est pas consigné.'
notify.sigilAccepted = 'Votre sigil a été accepté.'
notify.sigilRefused = 'Votre sigil a été refusé.'
notify.sigilExpired = 'L\'offre de sigil est restée sans réponse.'
notify.sigilKept = 'Vous gardez ce sigil sous le nom « %s ».'
notify.sigilRenamed = 'Sigil renommé : « %s ».'
notify.sigilForgotten = 'Vous oubliez le sigil « %s ».'
notify.sigilScrambled = 'Votre sigil se brouille : l\'ancien n\'existe plus.'
notify.lightOff = 'Votre lueur s\'éteint.'
notify.anchored = 'L\'orbe se fige en ce lieu.'
notify.dispelled = 'Vos orbes se dissipent.'
notify.colorSet = 'Votre lumière prend la couleur « %s ».'
notify.fizzle = 'La boule de feu s\'éteint entre vos mains.'
notify.burning = 'Les flammes vous mordent !'
notify.immune = 'Vous reprenez pied : plus rien ne vous déséquilibre un moment.'
notify.comboDiscovered = 'Une combinaison s\'inscrit dans votre grimoire : %s.'
-- sans vava_health : le lanceur le sait, au plus une fois par minute
notify.noHarm = 'Votre magie gronde sans mordre : en ce moment, nul ne peut en être blessé.'
notify.shieldBroken = 'Votre bouclier de magie se brise.'
notify.protected = 'Une protection magique vous enveloppe.'
notify.unprotected = 'Vos protections magiques se dissipent.'

local chat = config.texts.chat
chat.adminUsage = 'Usage : /magie <action> [id] … — mage [id] <oui|non> · apprendre [id] <sort> · oublier [id] <sort> · niveau [id] <sort> <1-5> · xp [id] <sort> <xp> · tous [id] · maitrise [id] · vider [id] · mana [id] · recharges [id] · fiche [id] · donner [id] <grimoire|registre> · proteger [id] <bouclier <points> [s] | resistance <type> <pour cent> [s] | aucune> · nettoyer'
chat.adminForbidden = 'Ces commandes sont réservées au Conseil.'
chat.adminNoTarget = 'Aucun personnage en jeu sous ce numéro.'
chat.adminUnknownSpell = 'Sort inconnu. Sorts : %s'
chat.adminDone = 'C\'est fait.'
chat.adminCleaned = 'Nettoyé : %d effet(s) retiré(s) du monde.'
-- échec d'une commande : texte par code (le code brut ne va qu'à la console du serveur)
chat.adminFailed = 'La commande n\'a pas abouti.'
chat.adminErrors = {
    not_mage = 'Ce personnage n\'est pas mage.',
    db_error = 'Les archives ne répondent pas : réessayez plus tard.',
    no_space = 'Sa besace n\'a plus la place.',
    too_heavy = 'Sa besace est trop lourde.',
    no_character = 'Aucun personnage en jeu sous ce numéro.',
    inventory_unavailable = 'L\'inventaire ne répond pas.',
    not_ready = 'L\'inventaire n\'est pas encore prêt.',
    unknown_item = 'L\'inventaire ne connaît pas cet objet.',
    too_many = 'Ce personnage porte déjà autant de protections qu\'il se peut.',
    -- /magie proteger : rangs du Registre
    outranked = 'Ce personnage siège au Conseil à votre rang ou au-dessus : ses protections ne vous regardent pas.',
    staff_only = 'Vous protéger vous-même ou affaiblir autrui est réservé au Souverain.',
}
chat.sheetTitle = 'Fiche magie de %s (joueur n° %d)'
chat.sheetMage = 'Mage : %s · sort choisi : %s'
chat.sheetSpell = '— %s : niveau %d (%d XP)'
chat.sheetNoSpell = '— aucun sort'
chat.sheetSigils = 'Sigils gardés : %d · mana : %d / %d'
chat.sheetCombos = 'Combinaisons découvertes : %d / %d'
chat.sheetProtections = 'Protections : %d bouclier(s), %s points · %d résistance(s) ou faiblesse(s)'
chat.yes = 'oui'
chat.no = 'non'
chat.none = 'aucun'

-- journal du Registre du Conseil (32 signes au plus)
config.texts.logs = {
    mage = 'Magie : mage', learn = 'Magie : sort appris', forget = 'Magie : sort retiré', level = 'Magie : niveau de sort',
    xp = 'Magie : XP de sort', all = 'Magie : tous les sorts', master = 'Magie : maîtrise de tout',
    clear = 'Magie : sorts retirés', mana = 'Magie : mana remplie', cooldowns = 'Magie : recharges effacées',
    sheet = 'Magie : fiche consultée', give = 'Magie : objet donné', cleanup = 'Magie : nettoyage du monde',
    protect = 'Magie : protection',
}
