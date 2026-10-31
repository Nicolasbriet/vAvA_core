--[[
    vava_gathering/server/trials.lua
    Rôle : essais de l'Atelier (T-102, « Tester la récolte »), à blanc : un essai par membre (compte), montré à son SEUL
           auteur. La zone essayée remplace chez lui l'affichage de la zone du même nom (ses points, leurs charges
           d'essai) ; rien n'entre dans l'état de la zone du core (sinon tous les abonnés la verraient). Envois par
           core.net au seul auteur : `vava_gathering:trial` (entier au début, puis différences : zone ou point changé,
           point retiré, charge d'essai prise) et `vava_gathering:trialEnd`. Les charges d'essai sont à part : une
           récolte d'essai (server/harvest.lua) n'en prend qu'une ici, ne donne rien et ne touche ni la vitalité, ni
           les charges réelles. Un essai est oublié au départ de son auteur.
    Dépendances : shared/constants.lua, shared/zonestate.lua, bridge/server.lua
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring

local bridge = VavaGathering.bridge
local zonestate = VavaGathering.zonestate
local EVENTS = VavaGathering.EVENTS

local trials = {}
VavaGathering.trials = trials

---@class vAvA.GatheringTrial
---@field source integer|nil
---@field accountId integer
---@field zone vAvA.ZoneDefinition           zone essayée (définition de l'essai, ou celle du catalogue)
---@field nodes table<string, table>         nœud d'essai : définition (comme le catalogue) + `c` charges d'essai

---@type table<integer, vAvA.GatheringTrial>
local byAccount = {}

--- Valeur d'un nœud d'essai pour le client : ressource, lieu, cap, charges d'essai.
local function nodeOut(node)
    return { r = node.resource.id, x = node.x, y = node.y, z = node.z, h = node.heading or 0.0, c = node.c }
end

local function send(trial, payload)
    if not trial.source then return end
    local ok, code = bridge.SendPacked(trial.source, EVENTS.TRIAL, payload)
    if not ok then VavaGathering.log.warn('essai de %s : envoi refusé (%s)', trial.zone.id, tostring(code)) end
end

--- Nœud d'essai tiré d'une définition (charges d'essai pleines, ou gardées s'il était déjà montré).
local function trialNode(trial, node, previous)
    local out = {}
    for key, value in pairs(node) do out[key] = value end
    out.zone, out.trial = trial.zone, true
    out.c = previous and previous.c and previous.c <= node.charges and previous.c or node.charges
    return out
end

--- Commence (ou recommence) l'essai d'un membre : la zone et ses nœuds, envoyés entiers à l'auteur seul.
---@param source integer|nil
---@param accountId integer
---@param zone vAvA.ZoneDefinition
---@param nodeList table[]  définitions des nœuds montrés (resource : définition du catalogue)
function trials.start(source, accountId, zone, nodeList)
    local trial = { source = source, accountId = accountId, zone = zone, nodes = {} }
    byAccount[accountId] = trial
    local out = {}
    for _, node in ipairs(nodeList) do
        local item = trialNode(trial, node, nil)
        trial.nodes[node.id] = item
        out[node.id] = nodeOut(item)
    end
    send(trial, { zone = zone.id, mode = 'full', def = zonestate.defValue(zone), nodes = out })
end

--- Relance après une sauvegarde ou une pose : la zone (si elle a changé) et les nœuds changés, en différence ; `hidden`
--- : nœuds à ne plus montrer.
---@param source integer|nil
---@param accountId integer
---@param zone vAvA.ZoneDefinition|nil
---@param nodeList table[]|nil
---@param hidden string[]|nil
---@return boolean  faux : aucun essai en cours
function trials.patch(source, accountId, zone, nodeList, hidden)
    local trial = byAccount[accountId]
    if not trial then return false end
    if source then trial.source = source end
    local payload = { zone = trial.zone.id, mode = 'patch' }
    if zone then
        -- mise à jour sur place : les nœuds d'essai gardent leur zone
        for key, value in pairs(zone) do trial.zone[key] = value end
        payload.def = zonestate.defValue(trial.zone)
    end
    if nodeList and #nodeList > 0 then
        payload.nodes = {}
        for _, node in ipairs(nodeList) do
            local item = trialNode(trial, node, trial.nodes[node.id])
            trial.nodes[node.id] = item
            payload.nodes[node.id] = nodeOut(item)
        end
    end
    if hidden and #hidden > 0 then
        payload.hidden = {}
        for _, id in ipairs(hidden) do
            trial.nodes[id] = nil
            payload.hidden[#payload.hidden + 1] = id
        end
    end
    send(trial, payload)
    return true
end

--- Fin de l'essai d'un membre : son auteur, s'il est encore là, rend l'affichage de l'état publié.
---@param accountId integer|nil
---@param source integer|nil
function trials.stop(accountId, source)
    local trial = accountId and byAccount[accountId] or nil
    if not trial then return end
    byAccount[accountId] = nil
    local target = source or trial.source
    if target then bridge.SendPacked(target, EVENTS.TRIAL_END, trial.zone.id) end
end

--- Essai d'un joueur (par sa source), ou nil.
local function ofSource(source)
    for _, trial in pairs(byAccount) do
        if trial.source == source then return trial end
    end
    return nil
end

--- Nœud d'essai de ce joueur (son auteur seul), prioritaire sur le catalogue pour lui ; nil sinon.
---@param source integer
---@param nodeId string
---@return table|nil
function trials.node(source, nodeId)
    local trial = ofSource(source)
    return trial and trial.nodes[nodeId] or nil
end

--- Une charge d'essai prise par une récolte d'essai : vrai s'il en restait, et la différence part à l'auteur.
---@param source integer
---@param nodeId string
---@return boolean
function trials.take(source, nodeId)
    local trial = ofSource(source)
    local node = trial and trial.nodes[nodeId]
    if not node or node.c <= 0 then return false end
    node.c = node.c - 1
    send(trial, { zone = trial.zone.id, mode = 'patch', nodes = { [nodeId] = { c = node.c } } })
    return true
end

--- Joueur parti : son essai n'est plus montré à personne (la fin viendra de l'Atelier).
---@param source integer
function trials.forget(source)
    local trial = ofSource(source)
    if trial then trial.source = nil end
end
