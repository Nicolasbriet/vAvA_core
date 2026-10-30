--[[
    vava_magic/server/registers.lua
    Rôle : registres des murmures. Le registre est un objet de l'inventaire : l'objet ne porte que son numéro (ses
           métadonnées restent petites), l'historique est en base sous ce numéro. Il suit donc l'objet, pas le
           personnage : volé ou perdu, il part avec ses pages ; un registre neuf est vierge et reçoit son numéro à sa
           première ouverture (ou au premier murmure consigné).
      - Consigner : si le joueur porte un registre, le dernier qu'il a ouvert (sinon le premier trouvé) ; plein, rien
        n'y est écrit et le joueur est prévenu.
      - Ouvrir : en l'utilisant ; seul le premier lot part (les pages les plus récentes, `registers.pageSize` au plus,
        sous `registers.pageBytes` octets), avec le nombre total de pages.
      - Feuilleter : les lots plus anciens, demandés un par un (curseur : numéro de la plus ancienne page reçue), à
        celui qui porte le registre, revérifié à chaque lot.
      - Arracher une page : celui qui porte le registre.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/sheets.lua
]]

local ipairs, tonumber, tostring = ipairs, tonumber, tostring
local time = os.time
local TriggerClientEvent = TriggerClientEvent

local bridge = VavaMagic.bridge
local sheets = VavaMagic.sheets
local text = VavaMagic.text
local pages = VavaMagic.pages
local cfg = VavaMagic.config
local limits = cfg.registers
local notify = cfg.texts.notify
local EVENTS = VavaMagic.EVENTS
local ITEM = cfg.items.registre.name
-- clé des métadonnées de l'objet : numéro du registre
local META_KEY = 'registre'

local INSERT_REGISTER = 'INSERT INTO `vava_magic_registers` (`created_at`) VALUES (?)'
local SELECT_LATEST = 'SELECT `id`, `written_at`, `direction`, `contact`, `body` FROM `vava_magic_register_pages` WHERE `register_id` = ? ORDER BY `id` DESC LIMIT ?'
local SELECT_BEFORE = 'SELECT `id`, `written_at`, `direction`, `contact`, `body` FROM `vava_magic_register_pages` WHERE `register_id` = ? AND `id` < ? ORDER BY `id` DESC LIMIT ?'
local COUNT_PAGES = 'SELECT COUNT(*) FROM `vava_magic_register_pages` WHERE `register_id` = ?'
local INSERT_PAGE = 'INSERT INTO `vava_magic_register_pages` (`register_id`, `written_at`, `direction`, `contact`, `body`) VALUES (?, ?, ?, ?, ?)'
local DELETE_PAGE = 'DELETE FROM `vava_magic_register_pages` WHERE `id` = ? AND `register_id` = ?'

local registers = {}
VavaMagic.registers = registers

registers.META_KEY = META_KEY

---@type table<integer, integer>  numéro de registre → nombre de pages (lu en base une fois)
local counts = {}

---@param metadata table
---@return integer|nil
local function idOf(metadata)
    return sheets.integer(tonumber(metadata[META_KEY]))
end

--- Nouveau registre en base. Bloque le thread. Renvoie son numéro ou nil.
---@return integer|nil
function registers.create()
    local id, err = bridge.db.insert(INSERT_REGISTER, { time() })
    if err or not id then
        VavaMagic.log.error('registre non créé : %s', tostring(err))
        return nil
    end
    id = sheets.integer(tonumber(id))
    if id then counts[id] = 0 end
    return id
end

--- Métadonnées d'un registre neuf (objet donné par le Conseil…).
---@param id integer
---@return table
function registers.metadata(id)
    return { [META_KEY] = id }
end

--- Donne son numéro à un registre vierge porté par le joueur.
---@param src integer
---@param instanceId integer
---@return integer|nil
local function assign(src, instanceId)
    local id = registers.create()
    if not id then return nil end
    if not bridge.SetItemMetadata(src, instanceId, registers.metadata(id)) then return nil end
    return id
end

--- Registre porté par le joueur où consigner : le dernier ouvert s'il l'a sur lui, sinon le premier trouvé. Un
--- registre vierge reçoit son numéro. Bloque le thread. nil si le joueur n'en porte pas.
---@param src integer
---@return integer|nil
function registers.carried(src)
    local list = bridge.GetItemMetadata(src, ITEM)
    if #list == 0 then return nil end
    local sheet = sheets.get(src)
    local preferred = sheet and sheet.register
    local first = nil
    for _, instance in ipairs(list) do
        local id = idOf(instance.metadata)
        if id and id == preferred then return id end
        first = first or id
    end
    if first then return first end
    return assign(src, list[1].instanceId)
end

---@param src integer
---@param id integer
---@return boolean
local function holds(src, id)
    for _, instance in ipairs(bridge.GetItemMetadata(src, ITEM)) do
        if idOf(instance.metadata) == id then return true end
    end
    return false
end

---@param id integer
---@return integer|nil
local function countOf(id)
    if counts[id] then return counts[id] end
    local value, err = bridge.db.scalar(COUNT_PAGES, { id })
    if err then return nil end
    counts[id] = sheets.integer(tonumber(value)) or 0
    return counts[id]
end

--- Consigne un murmure dans le registre que porte le joueur. Bloque le thread.
---@param src integer
---@param direction integer  VavaMagic.DIRECTION
---@param contact string
---@param body string
---@return boolean archived
function registers.archive(src, direction, contact, body)
    local id = registers.carried(src)
    if not id then return false end
    local count = countOf(id)
    if not count then return false end
    if count >= limits.maxPages then
        bridge.Notify(src, notify.registerFull, 'warning')
        return false
    end
    local _, err = bridge.db.insert(INSERT_PAGE, { id, time(), direction, text.truncate(contact, limits.contactMax), body })
    if err then return false end
    counts[id] = count + 1
    return true
end

--- Lot de pages d'un registre, les plus récentes d'abord : le premier, ou celui qui précède la page `before`. Bloque
--- le thread.
---@param id integer
---@param before integer|nil  numéro de la plus ancienne page déjà reçue
---@return table[]|nil list
---@return boolean|string more  il reste des pages plus anciennes ; sinon le code d'erreur
local function batch(id, before)
    local fetch = limits.pageSize + 1
    local rows, err
    if before then
        rows, err = bridge.db.query(SELECT_BEFORE, { id, before, fetch })
    else
        rows, err = bridge.db.query(SELECT_LATEST, { id, fetch })
    end
    if err then return nil, 'db_error' end
    return pages.take(rows, limits.pageSize, limits.pageBytes)
end

--- Ouvre un registre utilisé par le joueur (l'inventaire n'utilise qu'un objet de sa propre besace) : premier lot et
--- nombre total de pages.
---@param src integer
---@param instance { instanceId: integer, metadata: table }
function registers.open(src, instance)
    local id = idOf(instance.metadata) or assign(src, instance.instanceId)
    if not id then
        bridge.Notify(src, cfg.texts.errors.db_error, 'danger')
        return
    end
    local sheet = sheets.get(src)
    if sheet and sheet.register ~= id then
        sheet.register = id
        sheets.touch(src)
    end
    local list, more = batch(id)
    if not list then
        bridge.Notify(src, cfg.texts.errors.db_error, 'danger')
        return
    end
    -- registre lu en entier : son compte est exact
    if not more then counts[id] = #list end
    TriggerClientEvent(EVENTS.REGISTER, src, {
        id = id, pages = list, more = more, count = countOf(id) or #list, max = limits.maxPages,
    })
end

--- Lot plus ancien d'un registre que le joueur porte (mêmes contrôles qu'à l'ouverture : l'objet est dans sa besace).
--- Bloque le thread.
---@param src integer
---@param id integer
---@param before integer  numéro de la plus ancienne page déjà reçue
---@return boolean ok
---@return table|string result  { pages, more }, ou le code du refus
function registers.pages(src, id, before)
    if not holds(src, id) then return false, 'no_register' end
    local list, more = batch(id, before)
    if not list then return false, more end
    return true, { pages = list, more = more }
end

--- Arrache une page d'un registre que le joueur porte. Bloque le thread.
---@param src integer
---@param id integer
---@param pageId integer
---@return boolean ok
---@return string|nil code
function registers.tear(src, id, pageId)
    if not holds(src, id) then return false, 'no_register' end
    local affected, err = bridge.db.update(DELETE_PAGE, { pageId, id })
    if err then return false, 'db_error' end
    if (sheets.integer(tonumber(affected)) or 0) < 1 then return false, 'unknown_page' end
    if counts[id] and counts[id] > 0 then counts[id] = counts[id] - 1 end
    return true
end

-- utiliser un registre l'ouvre
bridge.RegisterUsableItem(ITEM, cfg.items.registre, registers.open)
