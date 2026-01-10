--[[
    vAvA_player_manager - Server Database
    Fonctions d'accès base de données
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- PERSONNAGES
-- ═══════════════════════════════════════════════════════════════════════════

function GetCharacters(license, callback)
    MySQL.query('SELECT * FROM player_characters WHERE license = ? ORDER BY last_played DESC', {license}, function(result)
        callback(result or {})
    end)
end

function GetCharacter(citizenId, callback)
    MySQL.single('SELECT * FROM player_characters WHERE citizenid = ?', {citizenId}, function(result)
        callback(result)
    end)
end

function GetCharacterCount(license, callback)
    MySQL.scalar('SELECT COUNT(*) FROM player_characters WHERE license = ?', {license}, function(count)
        callback(count or 0)
    end)
end

function CreateCharacter(data, callback)
    MySQL.insert('INSERT INTO player_characters (citizenid, license, firstname, lastname, dateofbirth, sex, nationality, money_cash, money_bank) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        data.citizenid,
        data.license,
        data.firstname,
        data.lastname,
        data.dateofbirth,
        data.sex,
        data.nationality,
        data.money_cash,
        data.money_bank
    }, function(id)
        callback(id ~= nil)
    end)
end

function UpdateCharacter(citizenId, data, callback)
    local fields = {}
    local values = {}
    
    for key, value in pairs(data) do
        table.insert(fields, key .. ' = ?')
        table.insert(values, value)
    end
    
    table.insert(values, citizenId)
    
    MySQL.update('UPDATE player_characters SET ' .. table.concat(fields, ', ') .. ' WHERE citizenid = ?', values, function(affectedRows)
        if callback then callback(affectedRows > 0) end
    end)
end

function DeleteCharacter(citizenId, callback)
    MySQL.update('DELETE FROM player_characters WHERE citizenid = ?', {citizenId}, function(affectedRows)
        callback(affectedRows > 0)
    end)
end

function ResetCharacter(citizenId, callback)
    MySQL.update('UPDATE player_characters SET money_cash = 5000, money_bank = 25000, job = "unemployed", job_grade = 0, gang = "none", gang_grade = 0, is_dead = 0 WHERE citizenid = ?', {citizenId}, function(affectedRows)
        callback(affectedRows > 0)
    end)
end

function UpdatePlaytime(citizenId, seconds)
    MySQL.update('UPDATE player_characters SET playtime = playtime + ? WHERE citizenid = ?', {seconds, citizenId})
end

-- ═══════════════════════════════════════════════════════════════════════════
-- APPARENCE
-- ═══════════════════════════════════════════════════════════════════════════

function GetAppearance(citizenId, callback)
    MySQL.single('SELECT * FROM player_appearance WHERE citizenid = ?', {citizenId}, function(result)
        callback(result)
    end)
end

function SaveAppearance(citizenId, data, callback)
    MySQL.query('INSERT INTO player_appearance (citizenid, model, skin, tattoos) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE model = VALUES(model), skin = VALUES(skin), tattoos = VALUES(tattoos)', {
        citizenId,
        data.model or 'mp_m_freemode_01',
        json.encode(data.skin or {}),
        json.encode(data.tattoos or {})
    }, function()
        if callback then callback(true) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TENUES
-- ═══════════════════════════════════════════════════════════════════════════

function GetOutfits(citizenId, callback)
    MySQL.query('SELECT * FROM player_outfits WHERE citizenid = ? ORDER BY created_at DESC', {citizenId}, function(result)
        callback(result or {})
    end)
end

function SaveOutfit(citizenId, outfitName, outfitData, callback)
    MySQL.insert('INSERT INTO player_outfits (citizenid, outfit_name, outfit_data) VALUES (?, ?, ?)', {
        citizenId,
        outfitName,
        json.encode(outfitData)
    }, function(id)
        if callback then callback(id ~= nil) end
    end)
end

function DeleteOutfit(outfitId, callback)
    MySQL.update('DELETE FROM player_outfits WHERE id = ?', {outfitId}, function(affectedRows)
        if callback then callback(affectedRows > 0) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- STATISTIQUES
-- ═══════════════════════════════════════════════════════════════════════════

function GetStats(citizenId, callback)
    MySQL.single('SELECT * FROM player_stats WHERE citizenid = ?', {citizenId}, function(result)
        callback(result)
    end)
end

function InitializeStats(citizenId)
    MySQL.insert('INSERT INTO player_stats (citizenid) VALUES (?)', {citizenId})
end

function UpdateStat(citizenId, statName, value, callback)
    MySQL.update('UPDATE player_stats SET ' .. statName .. ' = ' .. statName .. ' + ? WHERE citizenid = ?', {value, citizenId}, function(affectedRows)
        if callback then callback(affectedRows > 0) end
    end)
end

function SetStat(citizenId, statName, value, callback)
    MySQL.update('UPDATE player_stats SET ' .. statName .. ' = ? WHERE citizenid = ?', {value, citizenId}, function(affectedRows)
        if callback then callback(affectedRows > 0) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HISTORIQUE
-- ═══════════════════════════════════════════════════════════════════════════

function GetHistory(citizenId, limit, callback)
    MySQL.query('SELECT * FROM player_history WHERE citizenid = ? ORDER BY created_at DESC LIMIT ?', {citizenId, limit}, function(result)
        callback(result or {})
    end)
end

function AddHistory(citizenId, eventType, description, eventData, amount, relatedPlayer, callback)
    MySQL.insert('INSERT INTO player_history (citizenid, event_type, event_description, event_data, amount, related_player) VALUES (?, ?, ?, ?, ?, ?)', {
        citizenId,
        eventType,
        description,
        eventData and json.encode(eventData) or nil,
        amount,
        relatedPlayer
    }, function(id)
        if callback then callback(id ~= nil) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HISTOIRE
-- ═══════════════════════════════════════════════════════════════════════════

function GetStory(citizenId, callback)
    MySQL.single('SELECT * FROM player_story WHERE citizenid = ?', {citizenId}, function(result)
        callback(result)
    end)
end

function SaveStory(citizenId, storyData, callback)
    MySQL.query('INSERT INTO player_story (citizenid, background, reason_for_coming, main_goal, notes) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE background = VALUES(background), reason_for_coming = VALUES(reason_for_coming), main_goal = VALUES(main_goal), notes = VALUES(notes)', {
        citizenId,
        storyData.background or nil,
        storyData.reason_for_coming or nil,
        storyData.main_goal or nil,
        storyData.notes or nil
    }, function()
        if callback then callback(true) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

function GenerateCitizenId()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local citizenId = ''
    
    for i = 1, 3 do
        citizenId = citizenId .. chars:sub(math.random(1, #chars), math.random(1, #chars))
    end
    
    citizenId = citizenId .. math.random(10000, 99999)
    
    return citizenId
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('GetCharacters', GetCharacters)
exports('GetCharacter', GetCharacter)
exports('GetCharacterCount', GetCharacterCount)
exports('CreateCharacter', CreateCharacter)
exports('UpdateCharacter', UpdateCharacter)
exports('DeleteCharacter', DeleteCharacter)
exports('ResetCharacter', ResetCharacter)
exports('UpdatePlaytime', UpdatePlaytime)

exports('GetAppearance', GetAppearance)
exports('SaveAppearance', SaveAppearance)

exports('GetOutfits', GetOutfits)
exports('SaveOutfit', SaveOutfit)
exports('DeleteOutfit', DeleteOutfit)

exports('GetStats', GetStats)
exports('InitializeStats', InitializeStats)
exports('UpdateStat', UpdateStat)
exports('SetStat', SetStat)

exports('GetHistory', GetHistory)
exports('AddHistory', AddHistory)

exports('GetStory', GetStory)
exports('SaveStory', SaveStory)

exports('GenerateCitizenId', GenerateCitizenId)
