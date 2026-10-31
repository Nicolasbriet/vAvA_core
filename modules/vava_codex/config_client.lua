--[[
    vava_codex/config_client.lua
    Rôle : réglages du Codex que lit le client : touche et commande d'ouverture, nombre de dernières pages, « rester
           ouvert » par défaut, hôte du livre en panneau (1.7.0), texte du livre indisponible. Téléchargé par chaque joueur ; le serveur le lit aussi.
           Tout le reste (signets, commandes non décrites, droits sans vava_admin, joueurs proposés, pages de lecture,
           débits, textes du serveur) est dans config.lua, servi au seul serveur (T-132).
    Dépendances : shared/constants.lua
]]

VavaCodex.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.6.0)

    -- Touche par défaut, réglable par le joueur (Paramètres > Raccourcis > FiveM), et commande du chat.
    keys = { open = 'F1' },
    labels = { open = 'Ouvrir le Codex (commandes et touches)' },
    command = 'codex',

    -- Dernières pages gardées par personnage (commandes lancées, du Codex ou du chat). Signets : config.lua.
    recent = { max = 12 },

    -- Après « Lancer » : rester ouvert, sauf réglage contraire du joueur ; une commande qui ouvre une interface
    -- (`ui = true` dans sa déclaration) ferme toujours le Codex d'abord.
    keepOpenDefault = true,

    -- Codex « en panneau » (1.7.0) : seule ressource qui peut ouvrir le livre dans un rectangle de son écran, sans voile
    -- (exports client openDocked et closeDocked) ; la bannière du royaume (vava_pause) l'ouvre à droite de ses rubriques.
    docked = { host = 'vava_pause' },

    -- Texte affiché par le client. Les réponses du serveur et la console sont dans config.lua (messages.*).
    messages = {
        unavailable = 'Le Codex est indisponible pour le moment.',
    },
}
