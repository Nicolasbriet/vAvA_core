--[[
    vava_codex/content/chapters.lua
    Rôle : graine des pages de lecture du Codex (1.5.0) : la table `VavaCodex.seed` que remplissent les fichiers de
           content/, et les chapitres de lecture. Servi au seul serveur (server_scripts) : jamais téléchargé par les
           clients. Analysé et validé au setup par server/reading.lua (shared/pages.lua), puis oublié.
           Chapitre : { id, label, order } ; id en minuscules, chiffres et « _ » (32 au plus, jamais « vava… ») ;
           rang de 0 à 999. Format d'une page : README du module, § « Pages de lecture ».
    Dépendances : shared/constants.lua (VavaCodex)
]]

VavaCodex.seed = {
    chapters = {
        { id = 'premiers_pas', label = 'Premiers pas', order = 10 },
        { id = 'metiers', label = 'Les métiers', order = 20 },
        { id = 'royaume', label = 'Le royaume', order = 30 },
    },
    pages = {},
}
