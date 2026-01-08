--[[
    vAvA_core - Server Logs
    Système de logs centralisé
]]

vCore = vCore or {}

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTION PRINCIPALE
-- ═══════════════════════════════════════════════════════════════════════════

---Ajoute un log
---@param logType string
---@param identifier string
---@param message string
---@param data? table
function vCore.Log(logType, identifier, message, data)
    if not Config.Security.Logging.enabled then return end
    
    -- Log en DB
    vCore.DB.AddLog(logType, identifier, message, data)
    
    -- Log console si debug
    if Config.Debug then
        vCore.Utils.Debug('[LOG:' .. logType .. ']', identifier, message)
    end
    
    -- Log Discord si configuré
    if Config.Security.Logging.discord.enabled and Config.Security.Logging.discord.webhook ~= '' then
        vCore.LogDiscord(logType, identifier, message, data)
    end
end

---Envoie un log vers Discord
---@param logType string
---@param identifier string
---@param message string
---@param data? table
function vCore.LogDiscord(logType, identifier, message, data)
    local webhook = Config.Security.Logging.discord.webhook
    if webhook == '' then return end
    
    -- Couleurs par type
    local colors = {
        info = 3447003,      -- Bleu
        warning = 16776960,  -- Jaune
        error = 15158332,    -- Rouge
        debug = 10181046,    -- Violet
        economy = 3066993,   -- Vert
        inventory = 15844367,-- Or
        job = 1752220,       -- Teal
        vehicle = 9807270,   -- Gris
        admin = 15105570,    -- Orange
        security = 15158332  -- Rouge
    }
    
    local embed = {
        {
            title = '📋 ' .. string.upper(logType),
            description = message,
            color = colors[logType] or 3447003,
            fields = {
                {
                    name = 'Identifiant',
                    value = identifier or 'N/A',
                    inline = true
                },
                {
                    name = 'Serveur',
                    value = Config.ServerName,
                    inline = true
                }
            },
            footer = {
                text = os.date('%d/%m/%Y %H:%M:%S')
            }
        }
    }
    
    -- Ajouter les données si présentes
    if data then
        table.insert(embed[1].fields, {
            name = 'Données',
            value = '```json\n' .. json.encode(data) .. '\n```',
            inline = false
        })
    end
    
    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({
        username = 'vCore Logs',
        avatar_url = 'https://i.imgur.com/oBQXXXX.png',
        embeds = embed
    }), {['Content-Type'] = 'application/json'})
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORT
-- ═══════════════════════════════════════════════════════════════════════════

exports('Log', function(logType, identifier, message, data)
    vCore.Log(logType, identifier, message, data)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- LOGS AUTOMATIQUES
-- ═══════════════════════════════════════════════════════════════════════════

-- Log des événements économiques
AddEventHandler(vCore.Events.MONEY_ADDED, function(source, moneyType, amount, reason)
    local player = vCore.GetPlayer(source)
    if player then
        vCore.Log('economy', player:GetIdentifier(), 
            'Argent ajouté: ' .. moneyType .. ' +$' .. amount,
            {type = moneyType, amount = amount, reason = reason}
        )
    end
end)

AddEventHandler(vCore.Events.MONEY_REMOVED, function(source, moneyType, amount, reason)
    local player = vCore.GetPlayer(source)
    if player then
        vCore.Log('economy', player:GetIdentifier(), 
            'Argent retiré: ' .. moneyType .. ' -$' .. amount,
            {type = moneyType, amount = amount, reason = reason}
        )
    end
end)

-- Log des événements job
AddEventHandler(vCore.Events.JOB_CHANGED, function(source, job)
    local player = vCore.GetPlayer(source)
    if player then
        vCore.Log('job', player:GetIdentifier(), 
            'Job changé: ' .. job.name .. ' (Grade ' .. job.grade .. ')',
            job
        )
    end
end)

-- Log des événements inventaire
AddEventHandler(vCore.Events.ITEM_ADDED, function(source, itemName, amount, metadata)
    local player = vCore.GetPlayer(source)
    if player then
        vCore.Log('inventory', player:GetIdentifier(), 
            'Item ajouté: ' .. amount .. 'x ' .. itemName,
            {item = itemName, amount = amount, metadata = metadata}
        )
    end
end)

AddEventHandler(vCore.Events.ITEM_REMOVED, function(source, itemName, amount)
    local player = vCore.GetPlayer(source)
    if player then
        vCore.Log('inventory', player:GetIdentifier(), 
            'Item retiré: ' .. amount .. 'x ' .. itemName,
            {item = itemName, amount = amount}
        )
    end
end)
