--[[
    vava_admin/server/staff.lua
    Rôle : membres du Conseil (compte → rang), chargés au démarrage et tenus à jour en mémoire : aucune requête pour
           vérifier un droit. Un « acteur » est celui qui agit : un membre en jeu, la console, plus tard le panneau
           web ; toutes les actions passent par lui (droits, rang, nom au journal). Chaque changement de rang prévient
           ses écouteurs (1.11.0 : outils retirés, server/invulnerability.lua).
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/ranks.lua, server/store.lua
]]

local pairs, ipairs, tonumber, tostring, pcall = pairs, ipairs, tonumber, tostring, pcall
local sort = table.sort
local GetPlayers = GetPlayers

local ranks = VavaAdmin.ranks
local store = VavaAdmin.store

local staff = {}
VavaAdmin.staff = staff

---@class vAvA.AdminActor
---@field source integer|nil     joueur en jeu ; nil : console (ou panneau web)
---@field accountId integer|nil
---@field rank vAvA.AdminRank
---@field label string           nom au journal : « Sénéchal Aldric Morvan »
---@field web? boolean          compte du panneau web (Chancellerie), posé par server/web.lua

---@type table<integer, string>  compte → nom du rang
local members = {}
-- prévenus après chaque changement de rang d'un compte (server/invulnerability.lua : outils retirés, 1.11.0)
local listeners = {}

--- Ajoute un écouteur des changements de rang : fn(compte, rang d'avant, rang d'après), rangs nil hors du Conseil.
---@param fn fun(accountId: integer, before: vAvA.AdminRank|nil, after: vAvA.AdminRank|nil)
function staff.onRankChanged(fn)
    listeners[#listeners + 1] = fn
end

--- Prévient les écouteurs, chacun isolé : un écouteur en erreur n'empêche ni les autres ni le changement.
---@param accountId integer
---@param before string|nil
---@param after string|nil
local function changed(accountId, before, after)
    if before == after then return end
    local beforeRank, afterRank = before and ranks.get(before) or nil, after and ranks.get(after) or nil
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn, accountId, beforeRank, afterRank)
        if not ok then VavaAdmin.log.error('changement de rang du compte n° %d : %s', accountId, tostring(err)) end
    end
end

--- Nom du personnage actif d'un joueur, ou nil.
---@param src integer
---@return string|nil
function staff.characterName(src)
    local character = VavaAdmin.core.characters.getActive(src)
    if not character then return nil end
    return character.firstName .. ' ' .. character.lastName
end

--- Charge les membres. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function staff.load()
    local rows, err = store.staff()
    if not rows then return false, err end
    for _, row in ipairs(rows) do
        if ranks.get(row.rank) then
            members[row.account_id] = row.rank
        else
            VavaAdmin.log.warn("rang inconnu '%s' pour le compte n° %d : ignoré", tostring(row.rank), row.account_id)
        end
    end
    return true
end

---@param accountId integer|nil
---@return vAvA.AdminRank|nil
function staff.rankOfAccount(accountId)
    return accountId and ranks.get(members[accountId]) or nil
end

--- Acteur d'un joueur en jeu, ou nil s'il ne siège pas au Conseil.
---@param src integer
---@return vAvA.AdminActor|nil
function staff.actorOf(src)
    local session = VavaAdmin.core.players.get(src)
    local rank = session and staff.rankOfAccount(session.accountId)
    if not rank then return nil end
    local name = staff.characterName(src) or ('compte n° ' .. session.accountId)
    return { source = src, accountId = session.accountId, rank = rank, label = rank.label .. ' ' .. name }
end

---@return vAvA.AdminActor
function staff.console()
    return { source = nil, accountId = nil, rank = ranks.CONSOLE, label = ranks.CONSOLE.label }
end

---@param actor vAvA.AdminActor
---@param permission string
---@return boolean
function staff.can(actor, permission)
    return actor.rank.permissions[permission] == true
end

--- L'acteur peut-il agir sur ce compte ? Jamais sur un membre de rang égal ou supérieur.
---@param actor vAvA.AdminActor
---@param accountId integer|nil
---@return boolean
function staff.outranks(actor, accountId)
    local rank = staff.rankOfAccount(accountId)
    return rank == nil or actor.rank.level > rank.level
end

--- Nomme (rangName) ou révoque (nil) un membre. L'acteur ne nomme qu'à un rang inférieur au sien et ne touche
--- qu'aux membres de rang inférieur.
---@param actor vAvA.AdminActor
---@param accountId integer
---@param rankName string|nil
---@return boolean ok
---@return string|nil code
function staff.set(actor, accountId, rankName)
    if actor.accountId == accountId then return false, 'self' end
    if not staff.outranks(actor, accountId) then return false, 'outranked' end
    local ok, err
    local before = members[accountId]
    if rankName then
        local rank = ranks.get(rankName)
        if not rank then return false, 'unknown_rank' end
        if rank.level >= actor.rank.level then return false, 'outranked' end
        ok, err = store.setStaff(accountId, rankName, actor.accountId)
        if ok then members[accountId] = rankName end
    else
        if not members[accountId] then return false, 'not_staff' end
        ok, err = store.removeStaff(accountId)
        if ok then members[accountId] = nil end
    end
    if not ok then
        VavaAdmin.log.error('Conseil non mis à jour : %s', tostring(err))
        return false, 'db_error'
    end
    changed(accountId, before, members[accountId])
    return true
end

--- Rang imposé par la Chancellerie à un compte relié à un compte du panneau (nil : révoqué), hors des règles de rang
--- d'un acteur : le panneau en est la source. Renvoie true et ce qui a changé ('granted', 'revoked' ou nil).
---@param accountId integer
---@param rankName string|nil
---@return boolean ok
---@return string|nil changed  ou code d'erreur
function staff.force(accountId, rankName)
    if rankName and not ranks.get(rankName) then return false, 'unknown_rank' end
    if members[accountId] == rankName then return true, nil end
    local ok, err
    if rankName then
        ok, err = store.setStaff(accountId, rankName, nil)
    else
        ok, err = store.removeStaff(accountId)
    end
    if not ok then
        VavaAdmin.log.error('Conseil non mis à jour : %s', tostring(err))
        return false, 'db_error'
    end
    local before = members[accountId]
    members[accountId] = rankName
    changed(accountId, before, rankName)
    return true, rankName and 'granted' or 'revoked'
end

--- Membres du Conseil, avec leur personnage s'ils sont en jeu.
---@return table[]
function staff.list()
    local online = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local session = src and VavaAdmin.core.players.get(src)
        if session and session.accountId then online[session.accountId] = src end
    end
    local out = {}
    for accountId, rankName in pairs(members) do
        local rank = ranks.get(rankName)
        local src = online[accountId]
        out[#out + 1] = {
            accountId = accountId, rank = rankName, rankLabel = rank.label, level = rank.level,
            source = src, character = src and staff.characterName(src) or nil,
        }
    end
    sort(out, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return a.accountId < b.accountId
    end)
    return out
end

--- Joueurs en jeu siégeant au Conseil avec ce droit (signalements, alertes).
---@param permission string
---@return integer[]
function staff.onlineWith(permission)
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local actor = src and staff.actorOf(src)
        if actor and staff.can(actor, permission) then out[#out + 1] = src end
    end
    return out
end
