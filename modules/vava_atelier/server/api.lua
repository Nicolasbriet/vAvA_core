--[[
    vava_atelier/server/api.lua
    Rôle : exports serveur pour les autres modules : écrire au journal du Conseil au nom de ses propres ateliers
           (jamais au nom d'un autre : la ressource appelante doit porter le préfixe de l'atelier), savoir si un membre
           a le droit effectif d'un atelier (RPC propres des modules, T-102 et suivantes), savoir si sa session est
           ouverte. `VavaAtelier.journal.write` est la même écriture, sans contrôle de propriétaire (appel interne).
           T-101 : `codexList('ateliers')`, ateliers gardés (arguments de /atelier_archives dans le Codex). Aucun
           export ne livre une définition : chaque module ne reçoit que les siennes, par `apply`.
    Dépendances : shared/constants.lua, config.lua, bridge/server.lua, server/core.lua, server/editors.lua,
                  server/access.lua, server/journal.lua, server/archives.lua
]]

local type = type
local GetInvokingResource = GetInvokingResource

local core = VavaAtelier.core
if not core then return end

local Bridge = VavaAtelier.bridge
local editors = VavaAtelier.editors
local access = VavaAtelier.access
local journal = VavaAtelier.journal

--- Écrit une ligne au journal : `true`, ou `false, code` (invalid_args, unknown_editor, not_owner, not_allowed,
--- flood). L'écriture en base ne fait pas attendre l'appelant ; le numéro de la ligne est donné par le hook
--- vava_atelier:journal.
exports('journal', function(source, entry)
    local owner = GetInvokingResource()
    if type(owner) ~= 'string' then return false, 'not_owner' end
    return journal.write(source, entry, owner)
end)

--- Vrai si l'atelier est déclaré et que le joueur en a le droit effectif (relu auprès du Registre).
exports('can', function(source, editorId)
    if type(source) ~= 'number' or type(editorId) ~= 'string' then return false end
    local editor = editors.get(editorId)
    return editor ~= nil and Bridge.AdminReady() and Bridge.Can(source, editor.right)
end)

--- Vrai si le joueur a une session ouverte.
exports('isOpen', function(source)
    return type(source) == 'number' and access.isOpen(source)
end)

--- Listes du Codex (arguments de /atelier_archives) : `ateliers` → { { value, label } } des ateliers gardés ; toute
--- autre liste : {}.
exports('codexList', function(list)
    if list ~= 'ateliers' then return {} end
    return VavaAtelier.archives.codexList()
end)
