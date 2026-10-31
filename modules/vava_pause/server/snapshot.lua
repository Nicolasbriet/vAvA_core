--[[
    vava_pause/server/snapshot.lua
    Rôle : réponse à l'ouverture de la bannière, sans attente de la base : savoir-faire, confrérie (revalidée ; une
           réponse invalide donne la bannière royale et une ligne de console au plus par intervalle), habitants présents
           (compte gardé quelques secondes), Conseil prêt et état de la demande du joueur, touches si la version gardée
           par le client a changé. À terre (décision 2 du porteur du projet) : seulement `{ downed = true }`, les
           rubriques de la bannière réduite (Paramètres du jeu, Quitter) n'ayant besoin de rien du serveur.
    Dépendances : shared/constants.lua, config_client.lua, config.lua, shared/snapshot.lua, server/core.lua,
                  bridge/server.lua, server/keys.lua
]]

local tonumber, tostring, ipairs = tonumber, tostring, ipairs
local GetGameTimer, GetPlayers = GetGameTimer, GetPlayers

local core = VavaPause.core
if not core then return end

local cfg = VavaPause.config
local rules = VavaPause.snapshot
local bridge = VavaPause.bridge
local keys = VavaPause.keys
local KINDS = VavaPause.KINDS
local ACTIVE = 'active'

local compose = {}
VavaPause.compose = compose

local people = { count = 0, at = nil }
local lastGuildWarn = nil

--- Personnages en jeu (sessions actives), compte gardé `people.cacheMs`.
---@return integer
local function peopleCount()
    local now = GetGameTimer()
    if people.at and now - people.at < cfg.people.cacheMs then return people.count end
    local count = 0
    for _, id in ipairs(GetPlayers()) do
        local session = core.players.get(tonumber(id))
        if session and session.state == ACTIVE then count = count + 1 end
    end
    people.count, people.at = count, now
    return count
end

--- Confrérie revalidée, ou nil (bannière royale).
---@param src integer
---@return table|nil
local function guildOf(src)
    local raw = bridge.guildOf(src)
    if raw == nil then return nil end
    local guild, reason = rules.guild(raw, cfg.guild.charges, cfg.royal.charge)
    if guild then return guild end
    local now = GetGameTimer()
    if not lastGuildWarn or now - lastGuildWarn >= cfg.guild.warnEveryMs then
        lastGuildWarn = now
        VavaPause.log.warn('%s.%s : bannière invalide (%s), bannière royale montrée', cfg.guild.resource,
            cfg.guild.export, tostring(reason))
    end
    return nil
end

--- Instantané de l'ouverture.
---@param src integer
---@param knownKeys string  version des touches gardée par le client ('' : aucune)
---@param downed boolean
---@return table
function compose.open(src, knownKeys, downed)
    if downed then return { downed = true } end
    local version = keys.version()
    local answer = {
        skills = rules.skills(bridge.getSkills(src), cfg.snapshot.maxSkills),
        guild = guildOf(src),
        people = peopleCount(),
        council = bridge.councilReady(),
        request = rules.request(bridge.requestOf(src), KINDS),
        keysVersion = version,
    }
    if knownKeys ~= version then answer.keys = keys.list() end
    return answer
end
