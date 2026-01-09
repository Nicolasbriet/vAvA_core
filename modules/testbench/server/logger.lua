--[[
    vAvA_testbench - Logger
    Système de logs avec niveaux et export
]]

Logger = {}

-- Configuration
local logs = {}
local maxLogs = 1000

-- Niveaux de log
Logger.LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARNING = 3,
    ERROR = 4,
    CRITICAL = 5
}

local levelNames = {
    [1] = 'DEBUG',
    [2] = 'INFO',
    [3] = 'WARNING',
    [4] = 'ERROR',
    [5] = 'CRITICAL'
}

local levelColors = {
    [1] = '^6', -- Cyan
    [2] = '^2', -- Green
    [3] = '^3', -- Yellow
    [4] = '^1', -- Red
    [5] = '^8^1' -- Dark Red
}

-- === LOG PRINCIPAL ===
function Logger.Log(level, message, data)
    local config = TestbenchConfig.LogLevel
    
    -- Vérifier si ce niveau est activé
    local levelName = levelNames[level]
    if not config[levelName] then
        return
    end
    
    local logEntry = {
        level = levelName,
        message = message,
        data = data,
        timestamp = os.time() * 1000,
        date = os.date('%Y-%m-%d %H:%M:%S')
    }
    
    -- Ajouter au tableau de logs
    table.insert(logs, logEntry)
    
    -- Limiter la taille
    if #logs > maxLogs then
        table.remove(logs, 1)
    end
    
    -- Afficher dans la console
    Logger.PrintToConsole(logEntry, level)
    
    -- Exporter si nécessaire
    if TestbenchConfig.Export.AutoSave then
        Logger.AutoExport()
    end
    
    return logEntry
end

-- === MÉTHODES SHORTCUT ===
function Logger.Debug(message, data)
    return Logger.Log(Logger.LEVELS.DEBUG, message, data)
end

function Logger.Info(message, data)
    return Logger.Log(Logger.LEVELS.INFO, message, data)
end

function Logger.Warning(message, data)
    return Logger.Log(Logger.LEVELS.WARNING, message, data)
end

function Logger.Error(message, data)
    return Logger.Log(Logger.LEVELS.ERROR, message, data)
end

function Logger.Critical(message, data)
    return Logger.Log(Logger.LEVELS.CRITICAL, message, data)
end

-- === AFFICHAGE CONSOLE ===
function Logger.PrintToConsole(entry, level)
    if not TestbenchConfig.Notifications.Console then
        return
    end
    
    local color = levelColors[level] or '^7'
    local prefix = string.format('%s[TESTBENCH]^7', color)
    local levelStr = string.format('[%s]', entry.level)
    
    print(string.format('%s %s %s^0', prefix, levelStr, entry.message))
    
    -- Afficher les données si présentes
    if entry.data and TestbenchConfig.DevMode then
        print(string.format('^6  Data: %s^0', json.encode(entry.data, { indent = true })))
    end
end

-- === TEST LOGS ===
function Logger.LogTest(testName, status, duration, message)
    local emoji = {
        passed = '✅',
        failed = '❌',
        skipped = '⏭️',
        warning = '⚠️'
    }
    
    local level = status == 'passed' and Logger.LEVELS.INFO or Logger.LEVELS.ERROR
    local msg = string.format('%s Test: %s - Status: %s (%dms) - %s',
        emoji[status] or '🧪',
        testName,
        status:upper(),
        duration,
        message or ''
    )
    
    return Logger.Log(level, msg, {
        test = testName,
        status = status,
        duration = duration
    })
end

function Logger.LogTestStart(testName)
    return Logger.Info('🧪 Starting test: ' .. testName, { test = testName })
end

function Logger.LogTestEnd(testName, result)
    return Logger.LogTest(testName, result.status, result.duration, result.message)
end

-- === MODULE LOGS ===
function Logger.LogModuleScan(moduleName, testsFound)
    return Logger.Info(string.format('📦 Module scanned: %s (%d tests found)', 
        moduleName, testsFound), {
        module = moduleName,
        testsCount = testsFound
    })
end

function Logger.LogModuleLoad(moduleName, success)
    if success then
        return Logger.Info('📥 Module loaded: ' .. moduleName, { module = moduleName })
    else
        return Logger.Error('❌ Failed to load module: ' .. moduleName, { module = moduleName })
    end
end

-- === SCENARIO LOGS ===
function Logger.LogScenarioStart(scenarioName)
    return Logger.Info('🎬 Starting scenario: ' .. scenarioName, { scenario = scenarioName })
end

function Logger.LogScenarioEnd(scenarioName, results)
    local success = results.failed == 0
    local level = success and Logger.LEVELS.INFO or Logger.LEVELS.WARNING
    
    local msg = string.format('🎬 Scenario completed: %s - Passed: %d, Failed: %d',
        scenarioName, results.passed, results.failed)
    
    return Logger.Log(level, msg, {
        scenario = scenarioName,
        results = results
    })
end

-- === PERFORMANCE LOGS ===
function Logger.LogPerformance(operation, duration, details)
    local level = Logger.LEVELS.DEBUG
    
    if duration > 1000 then
        level = Logger.LEVELS.WARNING
    elseif duration > 5000 then
        level = Logger.LEVELS.ERROR
    end
    
    local msg = string.format('⏱️ Performance: %s took %dms', operation, duration)
    
    return Logger.Log(level, msg, {
        operation = operation,
        duration = duration,
        details = details
    })
end

-- === EXPORT ===
function Logger.GetLogs(filters)
    if not filters then
        return logs
    end
    
    local filtered = {}
    
    for _, log in ipairs(logs) do
        local match = true
        
        -- Filtrer par niveau
        if filters.level and log.level ~= filters.level then
            match = false
        end
        
        -- Filtrer par timestamp
        if filters.since and log.timestamp < filters.since then
            match = false
        end
        
        if filters.until_time and log.timestamp > filters.until_time then
            match = false
        end
        
        -- Filtrer par message
        if filters.search and not string.find(log.message:lower(), filters.search:lower()) then
            match = false
        end
        
        if match then
            table.insert(filtered, log)
        end
    end
    
    return filtered
end

function Logger.ClearLogs()
    local count = #logs
    logs = {}
    Logger.Info('🗑️ Logs cleared (' .. count .. ' entries removed)')
    return count
end

function Logger.ExportToFile(filename)
    if not TestbenchConfig.Export.Enabled then
        Logger.Warning('Export disabled in config')
        return false
    end
    
    local data = {
        exported_at = os.date('%Y-%m-%d %H:%M:%S'),
        total_logs = #logs,
        logs = logs,
        config = {
            devMode = TestbenchConfig.DevMode,
            language = TestbenchConfig.Language
        }
    }
    
    local json_data = json.encode(data, { indent = true })
    
    local filepath = TestbenchConfig.Export.SavePath .. filename
    local success = SaveResourceFile(GetCurrentResourceName(), filepath, json_data, -1)
    
    if success then
        Logger.Info('💾 Logs exported to: ' .. filepath)
        return true, filepath
    else
        Logger.Error('❌ Failed to export logs to: ' .. filepath)
        return false, nil
    end
end

function Logger.AutoExport()
    -- Auto-export seulement si beaucoup de logs
    if #logs < 500 then
        return
    end
    
    local filename = string.format('testbench_logs_%s.json', os.date('%Y%m%d_%H%M%S'))
    Logger.ExportToFile(filename)
end

-- === STATISTICS ===
function Logger.GetStatistics()
    local stats = {
        total = #logs,
        by_level = {
            DEBUG = 0,
            INFO = 0,
            WARNING = 0,
            ERROR = 0,
            CRITICAL = 0
        },
        recent = {
            last_hour = 0,
            last_day = 0
        }
    }
    
    local now = os.time() * 1000
    local oneHour = 3600 * 1000
    local oneDay = 86400 * 1000
    
    for _, log in ipairs(logs) do
        -- Par niveau
        stats.by_level[log.level] = (stats.by_level[log.level] or 0) + 1
        
        -- Recent
        if now - log.timestamp < oneHour then
            stats.recent.last_hour = stats.recent.last_hour + 1
        end
        
        if now - log.timestamp < oneDay then
            stats.recent.last_day = stats.recent.last_day + 1
        end
    end
    
    return stats
end

-- === SEARCH ===
function Logger.Search(query, options)
    options = options or {}
    local results = {}
    
    for _, log in ipairs(logs) do
        if string.find(log.message:lower(), query:lower()) then
            table.insert(results, log)
            
            -- Limiter les résultats
            if options.limit and #results >= options.limit then
                break
            end
        end
    end
    
    return results
end

-- === FORMATTING ===
function Logger.FormatLog(log, format)
    format = format or 'text'
    
    if format == 'text' then
        return string.format('[%s] [%s] %s', log.date, log.level, log.message)
    elseif format == 'json' then
        return json.encode(log)
    elseif format == 'html' then
        local color = {
            DEBUG = '#6c757d',
            INFO = '#28a745',
            WARNING = '#ffc107',
            ERROR = '#dc3545',
            CRITICAL = '#8B0000'
        }
        
        return string.format(
            '<div style="color: %s; padding: 5px; border-left: 3px solid %s;">[%s] [%s] %s</div>',
            color[log.level] or '#fff',
            color[log.level] or '#fff',
            log.date,
            log.level,
            log.message
        )
    end
    
    return tostring(log.message)
end

-- === EXPORTS ===
return Logger
