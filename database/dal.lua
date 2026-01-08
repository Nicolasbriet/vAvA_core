--[[
    vAvA_core - Data Access Layer (DAL) pour oxmysql
]]

vCore = vCore or {}
vCore.DB = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- REQUÊTES DE BASE
-- ═══════════════════════════════════════════════════════════════════════════

---Exécute une requête SELECT
---@param query string
---@param params? table
---@return table
function vCore.DB.Query(query, params)
    local result = MySQL.query.await(query, params or {})
    return result or {}
end

---Exécute une requête SELECT et retourne le premier résultat
---@param query string
---@param params? table
---@return table|nil
function vCore.DB.Single(query, params)
    local result = MySQL.single.await(query, params or {})
    return result
end

---Exécute une requête SELECT et retourne une valeur scalaire
---@param query string
---@param params? table
---@return any
function vCore.DB.Scalar(query, params)
    local result = MySQL.scalar.await(query, params or {})
    return result
end

---Exécute une requête INSERT
---@param query string
---@param params? table
---@return number InsertId
function vCore.DB.Insert(query, params)
    local result = MySQL.insert.await(query, params or {})
    return result
end

---Exécute une requête UPDATE/DELETE
---@param query string
---@param params? table
---@return number AffectedRows
function vCore.DB.Execute(query, params)
    local result = MySQL.update.await(query, params or {})
    return result
end

---Exécute une requête préparée
---@param query string
---@param params? table
---@return any
function vCore.DB.Prepare(query, params)
    local result = MySQL.prepare.await(query, params or {})
    return result
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TRANSACTIONS
-- ═══════════════════════════════════════════════════════════════════════════

---Exécute plusieurs requêtes dans une transaction
---@param queries table Liste de {query, params}
---@param callback? function
---@return boolean success
function vCore.DB.Transaction(queries, callback)
    local success = true
    
    MySQL.transaction.await(function()
        for _, q in ipairs(queries) do
            local ok = MySQL.query.await(q.query, q.params)
            if not ok then
                success = false
                break
            end
        end
        return success
    end)
    
    if callback then
        callback(success)
    end
    
    return success
end

-- ═══════════════════════════════════════════════════════════════════════════
-- REQUÊTES ASYNCHRONES (CALLBACKS)
-- ═══════════════════════════════════════════════════════════════════════════

---Exécute une requête SELECT asynchrone
---@param query string
---@param params? table
---@param callback function
function vCore.DB.QueryAsync(query, params, callback)
    MySQL.query(query, params or {}, function(result)
        callback(result or {})
    end)
end

---Exécute une requête SELECT asynchrone et retourne le premier résultat
---@param query string
---@param params? table
---@param callback function
function vCore.DB.SingleAsync(query, params, callback)
    MySQL.single(query, params or {}, function(result)
        callback(result)
    end)
end

---Exécute une requête INSERT asynchrone
---@param query string
---@param params? table
---@param callback function
function vCore.DB.InsertAsync(query, params, callback)
    MySQL.insert(query, params or {}, function(result)
        callback(result)
    end)
end

---Exécute une requête UPDATE/DELETE asynchrone
---@param query string
---@param params? table
---@param callback function
function vCore.DB.ExecuteAsync(query, params, callback)
    MySQL.update(query, params or {}, function(result)
        callback(result)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPERS SPÉCIFIQUES
-- ═══════════════════════════════════════════════════════════════════════════

---Recherche un utilisateur par identifiant
---@param identifier string
---@return table|nil
function vCore.DB.GetUserByIdentifier(identifier)
    return vCore.DB.Single('SELECT * FROM users WHERE identifier = ?', {identifier})
end

---Recherche les personnages d'un utilisateur
---@param identifier string
---@return table
function vCore.DB.GetCharacters(identifier)
    return vCore.DB.Query('SELECT * FROM characters WHERE identifier = ?', {identifier})
end

---Recherche un personnage par ID
---@param charId number
---@return table|nil
function vCore.DB.GetCharacter(charId)
    return vCore.DB.Single('SELECT * FROM characters WHERE id = ?', {charId})
end

---Sauvegarde un joueur
---@param player vPlayer
---@return boolean
function vCore.DB.SavePlayer(player)
    local data = player:ToTable()
    
    local query = [[
        UPDATE characters SET
            money = ?,
            job = ?,
            gang = ?,
            position = ?,
            status = ?,
            inventory = ?,
            metadata = ?
        WHERE id = ?
    ]]
    
    local affected = vCore.DB.Execute(query, {
        json.encode(data.money),
        json.encode(data.job),
        json.encode(data.gang),
        json.encode(data.position),
        json.encode(data.status),
        json.encode(data.inventory),
        json.encode(data.metadata),
        data.charId
    })
    
    return affected > 0
end

---Crée un nouveau personnage
---@param identifier string
---@param firstName string
---@param lastName string
---@param dob string
---@param gender number
---@return number charId
function vCore.DB.CreateCharacter(identifier, firstName, lastName, dob, gender)
    local query = [[
        INSERT INTO characters (identifier, firstname, lastname, dob, gender, money, job, gang, position, status, inventory, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]
    
    local defaultMoney = json.encode(Config.Players.StartingMoney)
    local defaultJob = json.encode({name = Config.Jobs.DefaultJob, grade = Config.Jobs.DefaultGrade})
    local defaultGang = json.encode({name = 'none', grade = 0})
    local defaultPosition = json.encode(Config.Players.DefaultSpawn)
    local defaultStatus = json.encode(Config.Players.StartingStatus)
    local defaultInventory = json.encode({})
    local defaultMetadata = json.encode({})
    
    return vCore.DB.Insert(query, {
        identifier,
        firstName,
        lastName,
        dob,
        gender,
        defaultMoney,
        defaultJob,
        defaultGang,
        defaultPosition,
        defaultStatus,
        defaultInventory,
        defaultMetadata
    })
end

---Supprime un personnage
---@param charId number
---@return boolean
function vCore.DB.DeleteCharacter(charId)
    local affected = vCore.DB.Execute('DELETE FROM characters WHERE id = ?', {charId})
    return affected > 0
end

---Vérifie si un joueur est banni
---@param identifier string
---@return table|nil
function vCore.DB.GetBan(identifier)
    return vCore.DB.Single([[
        SELECT * FROM bans 
        WHERE identifier = ? 
        AND (expire_at IS NULL OR expire_at > NOW())
    ]], {identifier})
end

---Ajoute un ban
---@param identifier string
---@param reason string
---@param expireAt? string
---@param bannedBy string
---@return number
function vCore.DB.AddBan(identifier, reason, expireAt, bannedBy)
    return vCore.DB.Insert([[
        INSERT INTO bans (identifier, reason, expire_at, banned_by, created_at)
        VALUES (?, ?, ?, ?, NOW())
    ]], {identifier, reason, expireAt, bannedBy})
end

---Retire un ban
---@param identifier string
---@return boolean
function vCore.DB.RemoveBan(identifier)
    local affected = vCore.DB.Execute('DELETE FROM bans WHERE identifier = ?', {identifier})
    return affected > 0
end

---Ajoute un log
---@param type string
---@param identifier string
---@param message string
---@param data? table
function vCore.DB.AddLog(type, identifier, message, data)
    vCore.DB.InsertAsync([[
        INSERT INTO logs (type, identifier, message, data, created_at)
        VALUES (?, ?, ?, ?, NOW())
    ]], {type, identifier, message, json.encode(data or {})}, function() end)
end

---Récupère les véhicules d'un joueur
---@param identifier string
---@return table
function vCore.DB.GetPlayerVehicles(identifier)
    return vCore.DB.Query('SELECT * FROM vehicles WHERE owner = ?', {identifier})
end

---Ajoute un véhicule
---@param owner string
---@param plate string
---@param model string
---@param props? table
---@return number
function vCore.DB.AddVehicle(owner, plate, model, props)
    return vCore.DB.Insert([[
        INSERT INTO vehicles (owner, plate, model, props, state, garage)
        VALUES (?, ?, ?, ?, 'garaged', 'default')
    ]], {owner, plate, model, json.encode(props or {})})
end

---Met à jour l'état d'un véhicule
---@param plate string
---@param state string
---@return boolean
function vCore.DB.UpdateVehicleState(plate, state)
    local affected = vCore.DB.Execute('UPDATE vehicles SET state = ? WHERE plate = ?', {state, plate})
    return affected > 0
end

---Récupère un item par nom
---@param itemName string
---@return table|nil
function vCore.DB.GetItem(itemName)
    return vCore.DB.Single('SELECT * FROM items WHERE name = ?', {itemName})
end

---Récupère tous les items
---@return table
function vCore.DB.GetAllItems()
    return vCore.DB.Query('SELECT * FROM items')
end
