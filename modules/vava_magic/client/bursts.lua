--[[
    vava_magic/client/bursts.lua
    Rôle : effets instantanés annoncés par le serveur aux seuls joueurs proches (nova, vague, secousse qui frappe,
           rempart qui se dresse ou s'effondre). Chaque sort déclare son rendu (`bursts.define`) ; ce fichier vérifie
           l'envoi et le lui confie. Outils communs : son selon la distance (de l'interface, ou natif de GTA quand la
           config en déclare un), tremblement de la caméra des plus proches.
    Dépendances : shared/, config.lua, client/nui.lua
]]

local type = type
local max = math.max
local RegisterNetEvent, PlayerPedId, GetEntityCoords, ShakeGameplayCam, PlaySoundFromCoord =
    RegisterNetEvent, PlayerPedId, GetEntityCoords, ShakeGameplayCam, PlaySoundFromCoord

local nui = VavaMagic.nui
local geometry = VavaMagic.geometry
local soundsCfg = VavaMagic.config.sounds
local EVENTS = VavaMagic.EVENTS

local bursts = {}
VavaMagic.bursts = bursts

---@type table<string, fun(payload: table)>
local renderers = {}

--- Rendu d'un effet instantané : `show(payload)` avec payload = { spell, caster, x, y, z, level, … } (vérifié ici
--- pour les champs communs, par le rendu pour les siens).
---@param spell string
---@param show fun(payload: table)
function bursts.define(spell, show)
    renderers[spell] = show
end

---@param point table
---@return number  distance du joueur local
function bursts.distance(point)
    return geometry.distance(GetEntityCoords(PlayerPedId()), point)
end

--- Son d'un effet : natif de GTA au point même si la config en déclare un (`sounds.native`), sinon celui de la page,
--- plus faible avec la distance (rien au-delà de `sounds.hearing`).
---@param name string|nil
---@param point table
function bursts.sound(name, point)
    if not name then return end
    local native = soundsCfg.native[name]
    if native then
        PlaySoundFromCoord(-1, native.name, point.x, point.y, point.z, native.set, false, 0, false)
        return
    end
    local volume = max(0, 1 - bursts.distance(point) / soundsCfg.hearing)
    if volume > 0 then nui.send('sound', { name = name, volume = volume }) end
end

--- Caméra qui tremble pour qui est à moins de `radius` mètres. `shake` : { name, amplitude }.
---@param point table
---@param radius number
---@param shake table
function bursts.shake(point, radius, shake)
    if bursts.distance(point) <= radius then ShakeGameplayCam(shake.name, shake.amplitude) end
end

---@param value any
---@return boolean
function bursts.isNumber(value)
    return type(value) == 'number' and value == value
end

RegisterNetEvent(EVENTS.BURST, function(payload)
    if type(payload) ~= 'table' or type(payload.spell) ~= 'string' then return end
    if not bursts.isNumber(payload.x) or not bursts.isNumber(payload.y) or not bursts.isNumber(payload.z) then return end
    local show = renderers[payload.spell]
    if show then show(payload) end
end)
