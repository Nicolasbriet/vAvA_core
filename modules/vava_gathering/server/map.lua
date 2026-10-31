--[[
    vava_gathering/server/map.lua
    Rôle : liste des zones de la carte (T-102) : jamais poussée à personne. Chaque client la garde en stockage local
           avec sa version et la redemande à son apparition (RPC `vava_gathering:map`, au seul appelant) : ≈ 30 octets
           quand rien n'a changé, la liste entière (≈ 60 octets par zone) sinon. Version = empreinte de la liste
           (shared/editing.lua), recalculée après chaque diffusion d'un changement de l'Atelier.
    Dépendances : shared/constants.lua, shared/editing.lua, server/core.lua, bridge/server.lua, server/catalog.lua
]]

local catalog = VavaGathering.catalog
local editing = VavaGathering.editing
local bridge = VavaGathering.bridge

local map = {}
VavaGathering.map = map

-- liste courante et sa version
local current, version = {}, ''

--- Recalcule la liste et sa version (démarrage, après une diffusion).
function map.refresh()
    current = editing.mapList(catalog.zones())
    version = editing.mapVersion(current)
end

---@return string
function map.version()
    return version
end

--- RPC map : personnage chargé ; `{ version }` si le client a déjà cette version, sinon `{ version, zones }`.
---@param source integer
---@param known string  version gardée par le client ('' : aucune)
---@return boolean ok
---@return table|string
function map.rpc(source, known)
    if not bridge.GetCharacterId(source) then return false, 'no_character' end
    if known == version then return true, { version = version } end
    return true, { version = version, zones = current }
end
