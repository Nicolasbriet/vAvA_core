--[[
    vava_skills/config_client.lua
    Rôle : réglages des compétences que lit le client : touche du livre et son libellé, texte affiché quand le livre
           ne répond pas. Téléchargé par chaque joueur ; le serveur le lit aussi. Tout le reste (compétences, rangs,
           XP, rouille, pénurie, mentorat, leçons, droits, débits, textes du serveur) est dans config.lua, servi au
           seul serveur (T-132).
    Dépendances : shared/constants.lua
]]

VavaSkills.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.3.0)

    -- Touche par défaut, réglable par le joueur (Paramètres > Raccourcis > FiveM).
    keys = { open = 'K' },
    labels = { open = 'Ouvrir le livre des compétences' },

    -- Textes affichés par le client. Les notifications du serveur sont dans config.lua (messages.*).
    messages = {
        unavailable = 'Le livre des compétences est indisponible pour le moment.',
    },
}
