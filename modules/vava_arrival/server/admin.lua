--[[
    vava_arrival/server/admin.lua
    Rôle : commande du Conseil `/accueil` (droit `give` de vava_admin, repli ACE ; console permise) : état de la
           dotation et de l'accueil d'un personnage en jeu (lecture seule), dotation redonnée (sans limite du compte),
           accueil rejoué. Délai entre deux commandes d'un même membre. Chaque action est inscrite au journal du module
           et au Registre du Conseil ; la réponse va au seul membre qui a tapé la commande (ou à la console).
    Dépendances : shared/constants.lua, config.lua, shared/rules.lua, server/core.lua, bridge/server.lua,
                  server/journal.lua, server/store.lua, server/kit.lua, server/welcome.lua
]]

local format = string.format
local RegisterCommand, CreateThread, GetGameTimer = RegisterCommand, CreateThread, GetGameTimer

local bridge = VavaArrival.bridge
local journal = VavaArrival.journal
local store = VavaArrival.store
local kit = VavaArrival.kit
local welcome = VavaArrival.welcome
local rules = VavaArrival.rules
local cfg = VavaArrival.config.admin
local messages = VavaArrival.config.messages.admin
local labels = VavaArrival.config.messages.journal
local CONSOLE = bridge.CONSOLE

local admin = {}
VavaArrival.admin = admin

-- membre du Conseil → heure de sa dernière commande (GetGameTimer)
local lastUse = {}

---@param target integer
---@return string
local function nameOf(target)
    return bridge.GetCharacterName(target) or format('joueur %d', target)
end

--- /accueil etat : entrée en mémoire, sinon ligne en base ; aucune écriture.
local function state(source, target, characterId)
    local row = store.entry(characterId)
    if not row then
        local read = store.read(characterId)
        if read == false then return bridge.Chat(source, messages.unavailable) end
        row = read
    end
    bridge.Chat(source, rules.describe(row, messages, { name = nameOf(target), source = target, characterId = characterId }))
end

--- /accueil redoter : échange atomique, ligne « donnée », journaux.
local function regive(source, target, characterId)
    local name = nameOf(target)
    local ok, code = kit.regive(target, characterId, bridge.GetAccountId(target), source)
    if not ok then
        if code == 'busy' then return bridge.Chat(source, messages.busy) end
        return bridge.Chat(source, format(messages.regiveFailed, name, rules.codeLabel(code, messages.codes)))
    end
    bridge.AdminLog(source, labels.regive, { joueur = target, personnage = characterId })
    bridge.Chat(source, format(messages.regiven, name))
end

--- /accueil rejouer : ligne créée (« aucune » dotation) ou accueil remis à zéro, puis accueil envoyé tout de suite.
local function replay(source, target, characterId)
    local entry = store.entry(characterId)
    if entry and entry.busy then return bridge.Chat(source, messages.busy) end
    if entry then entry.busy = true end
    local accountId = bridge.GetAccountId(target)
    local written = store.replay(characterId, accountId, bridge.Now())
    if entry then entry.busy = false end
    if not written then return bridge.Chat(source, messages.unavailable) end
    entry = store.entry(characterId)
    if not entry then
        -- personnage sans entrée (arrivé avant l'accueil) : ligne relue, suivie jusqu'à son départ
        local row = store.read(characterId)
        if not row then return bridge.Chat(source, messages.unavailable) end
        if bridge.ActiveCharacterId(target) ~= characterId then return bridge.Chat(source, format(messages.noCharacter, target)) end
        entry = store.put(target, accountId, characterId, row, true)
    end
    local name = nameOf(target)
    local sent, code = welcome.replay(entry)
    if not sent then return bridge.Chat(source, format(messages.replayFailed, name, rules.codeLabel(code, messages.codes))) end
    journal.write('admin_replay', { characterId = characterId, accountId = accountId, actorAccountId = bridge.GetAccountId(source), details = {} })
    bridge.AdminLog(source, labels.replay, { joueur = target, personnage = characterId })
    bridge.Chat(source, format(messages.replayed, name))
end

local ACTIONS = { etat = state, redoter = regive, rejouer = replay }

--- Commande /accueil (jeu ou console). Sans droit : rien, aucune réponse.
---@param source integer
---@param args string[]
function admin.command(source, args)
    if not bridge.IsAllowed(source, cfg.permission) then return end
    if source ~= CONSOLE then
        local now = GetGameTimer()
        local last = lastUse[source]
        if last and now - last < cfg.cooldownMs then return bridge.Chat(source, messages.wait) end
        lastUse[source] = now
    end
    local action, target = rules.parseCommand(args)
    if not action then return bridge.Chat(source, format(messages.usage, cfg.command)) end
    CreateThread(function()
        local characterId = bridge.ActiveCharacterId(target)
        if not characterId then return bridge.Chat(source, format(messages.noCharacter, target)) end
        ACTIONS[action](source, target, characterId)
    end)
end

--- Joueur parti : son délai est oublié.
---@param source integer
function admin.forget(source)
    lastUse[source] = nil
end

--- Enregistre la commande. Appelé pendant le setup du module.
function admin.start()
    RegisterCommand(cfg.command, admin.command, false)
end
