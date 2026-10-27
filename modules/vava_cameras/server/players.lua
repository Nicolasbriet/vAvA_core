--[[
    vava_cameras/server/players.lua
    Rôle : joueurs que le Conseil peut regarder : connectés, avec leur nom (celui du personnage en jeu, sinon le
           pseudo) et s'ils sont en jeu (un joueur en sélection de personnage n'a pas encore d'image à montrer).
    Dépendances : server/core.lua
]]

local ipairs, tonumber, sort = ipairs, tonumber, table.sort
local GetPlayers, GetPlayerName = GetPlayers, GetPlayerName

local players = {}
VavaCameras.players = players

---@param src integer
---@return string
function players.label(src)
    local character = VavaCameras.core.characters.getActive(src)
    if character then return character.firstName .. ' ' .. character.lastName end
    return GetPlayerName(src) or ('joueur n° ' .. src)
end

--- Personnage apparu (son image existe) ?
---@param src integer
---@return boolean
function players.active(src)
    local session = VavaCameras.core.players.get(src)
    return session ~= nil and session.state == 'active'
end

--- Joueurs connectés : liste { source, label, active }, par numéro.
---@return table[]
function players.list()
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and VavaCameras.core.players.get(src) then
            out[#out + 1] = { source = src, label = players.label(src), active = players.active(src) }
        end
    end
    sort(out, function(a, b) return a.source < b.source end)
    return out
end
