--[[
    vava_admin/shared/requests.lua
    Rôle : logique pure des demandes au Conseil (1.10.0, T-145) : état de la demande d'un compte (la plus récente
           ouverte, sinon la dernière close depuis peu), demandes ouvertes d'un compte, position arrondie au mètre,
           témoins retenus. Servi au seul serveur (testé hors jeu : tests/spec/admin_requests_spec.lua).
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs = type, pairs, ipairs
local floor, huge = math.floor, math.huge

local rules = {}
VavaAdmin.requestRules = rules

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value > -huge and value < huge
end

--- Demandes ouvertes d'un compte.
---@param open table<integer, table>  signalements ouverts { id, accountId, … }
---@param accountId integer
---@return integer
function rules.openCount(open, accountId)
    local count = 0
    for _, report in pairs(open) do
        if report.accountId == accountId then count = count + 1 end
    end
    return count
end

--- État de la demande d'un compte, pour la bannière : la plus récente de ses demandes ouvertes (`claimed` si un membre
--- l'a prise, sinon `sent`), sinon sa dernière demande close depuis moins de `memoryMs` (`closed`), sinon nil. `age` en
--- secondes : depuis l'envoi (ouverte) ou depuis la clôture (close).
---@param open table<integer, table>  signalements ouverts { id, accountId, kind, at, claimedBy? }
---@param closed { id: integer, kind: string, at: integer }|nil  dernière demande close du compte
---@param accountId integer
---@param now integer  GetGameTimer()
---@param memoryMs integer
---@return { id: integer, kind: string, state: string, age: integer }|nil
function rules.statusOf(open, closed, accountId, now, memoryMs)
    local latest = nil
    for _, report in pairs(open) do
        if report.accountId == accountId and (not latest or report.id > latest.id) then latest = report end
    end
    if latest then
        return {
            id = latest.id, kind = latest.kind, state = latest.claimedBy and 'claimed' or 'sent',
            age = floor(((now - latest.at) > 0 and (now - latest.at) or 0) / 1000),
        }
    end
    if closed and now - closed.at < memoryMs then
        return { id = closed.id, kind = closed.kind, state = 'closed', age = floor(((now - closed.at) > 0 and (now - closed.at) or 0) / 1000) }
    end
    return nil
end

--- Position lue par le serveur, arrondie au mètre : { x, y, z } entiers, ou nil si une coordonnée n'est pas un nombre
--- fini.
---@param coords any  vector3 ou { x, y, z }
---@return { x: integer, y: integer, z: integer }|nil
function rules.roundPosition(coords)
    if coords == nil then return nil end
    local x, y, z = coords.x, coords.y, coords.z
    if not (finite(x) and finite(y) and finite(z)) then return nil end
    return { x = floor(x + 0.5), y = floor(y + 0.5), z = floor(z + 0.5) }
end

--- Témoins d'un signalement de joueur : les joueurs proches donnés (auteur exclu), chacun gardé par son numéro de
--- compte et son nom de personnage, `max` au plus, dans l'ordre reçu ; un joueur sans compte ni nom est sauté.
---@param near integer[]  numéros des joueurs proches (core.net.playersNear)
---@param author integer  numéro de l'auteur
---@param max integer
---@param identify fun(src: integer): integer|nil, string|nil  numéro de compte et nom du personnage
---@return { accountId: integer, name: string }[]
function rules.witnesses(near, author, max, identify)
    local out = {}
    if type(near) ~= 'table' then return out end
    for _, src in ipairs(near) do
        if #out >= max then break end
        if src ~= author then
            local accountId, name = identify(src)
            if accountId and name then out[#out + 1] = { accountId = accountId, name = name } end
        end
    end
    return out
end
