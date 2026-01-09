--[[
    vAvA_testbench - Test Runner
    Moteur d'exécution des tests avec sandbox
]]

TestRunner = {}

-- État du runner
local runnerState = {
    isRunning = false,
    currentTest = nil,
    queue = {},
    results = {},
    startTime = 0
}

-- === EXÉCUTION PRINCIPALE ===
function TestRunner.Run(tests, options)
    options = options or {}
    
    if runnerState.isRunning then
        return { success = false, error = 'Tests already running' }
    end
    
    runnerState.isRunning = true
    runnerState.queue = tests
    runnerState.results = {}
    runnerState.startTime = os.time()
    
    local results = {
        passed = 0,
        failed = 0,
        skipped = 0,
        total = #tests,
        duration = 0,
        details = {}
    }
    
    -- Exécuter les tests
    for _, test in ipairs(tests) do
        if not runnerState.isRunning then
            results.skipped = results.skipped + 1
            break
        end
        
        local result = TestRunner.RunSingle(test, options)
        
        table.insert(results.details, result)
        
        if result.status == 'passed' then
            results.passed = results.passed + 1
        elseif result.status == 'failed' then
            results.failed = results.failed + 1
        else
            results.skipped = results.skipped + 1
        end
        
        -- Petit délai entre les tests
        if options.delay then
            Wait(options.delay)
        end
    end
    
    results.duration = os.time() - runnerState.startTime
    runnerState.isRunning = false
    
    return results
end

-- === EXÉCUTION D'UN TEST UNIQUE ===
function TestRunner.RunSingle(test, options)
    options = options or {}
    runnerState.currentTest = test
    
    local result = {
        name = test.name,
        type = test.type or 'unit',
        status = 'pending',
        message = '',
        error = nil,
        duration = 0,
        timestamp = os.time() * 1000,
        assertions = {
            total = 0,
            passed = 0,
            failed = 0
        }
    }
    
    local startTime = os.clock()
    
    -- Créer le contexte de test
    local context = TestRunner.CreateContext(test, options)
    
    -- Exécuter dans un environnement protégé
    local success, err = pcall(function()
        if test.setup then
            test.setup(context)
        end
        
        if test.run then
            test.run(context)
        elseif test.fn then
            test.fn(context)
        end
        
        if test.teardown then
            test.teardown(context)
        end
    end)
    
    local duration = (os.clock() - startTime) * 1000
    result.duration = math.floor(duration)
    
    -- Analyser les résultats
    if not success then
        result.status = 'failed'
        result.error = tostring(err)
        result.message = 'Test crashed: ' .. tostring(err)
    elseif context.assertions.failed > 0 then
        result.status = 'failed'
        result.message = string.format('%d/%d assertions failed', 
            context.assertions.failed, 
            context.assertions.total)
    else
        result.status = 'passed'
        result.message = string.format('All %d assertions passed', context.assertions.passed)
    end
    
    result.assertions = context.assertions
    
    -- Vérifier le timeout
    if options.timeout and duration > options.timeout then
        result.status = 'failed'
        result.message = string.format('Test timeout: %dms > %dms', duration, options.timeout)
    end
    
    runnerState.currentTest = nil
    return result
end

-- === CRÉATION DU CONTEXTE DE TEST ===
function TestRunner.CreateContext(test, options)
    local context = {
        test = test,
        data = {},
        assertions = {
            total = 0,
            passed = 0,
            failed = 0,
            errors = {}
        },
        
        -- Assertions
        assert = {},
        expect = {},
        
        -- Utilities
        utils = {},
        
        -- Sandbox
        sandbox = options.sandbox or TestbenchConfig.Sandbox
    }
    
    -- === ASSERTIONS ===
    
    -- assert.isTrue
    context.assert.isTrue = function(value, message)
        context.assertions.total = context.assertions.total + 1
        if value == true then
            context.assertions.passed = context.assertions.passed + 1
            return true
        else
            context.assertions.failed = context.assertions.failed + 1
            local err = message or 'Expected true, got ' .. tostring(value)
            table.insert(context.assertions.errors, err)
            return false
        end
    end
    
    -- assert.isFalse
    context.assert.isFalse = function(value, message)
        return context.assert.isTrue(value == false, message or 'Expected false')
    end
    
    -- assert.equals
    context.assert.equals = function(actual, expected, message)
        context.assertions.total = context.assertions.total + 1
        if actual == expected then
            context.assertions.passed = context.assertions.passed + 1
            return true
        else
            context.assertions.failed = context.assertions.failed + 1
            local err = message or string.format('Expected %s, got %s', tostring(expected), tostring(actual))
            table.insert(context.assertions.errors, err)
            return false
        end
    end
    
    -- assert.notEquals
    context.assert.notEquals = function(actual, expected, message)
        context.assertions.total = context.assertions.total + 1
        if actual ~= expected then
            context.assertions.passed = context.assertions.passed + 1
            return true
        else
            context.assertions.failed = context.assertions.failed + 1
            local err = message or string.format('Expected not %s', tostring(expected))
            table.insert(context.assertions.errors, err)
            return false
        end
    end
    
    -- assert.isNil
    context.assert.isNil = function(value, message)
        return context.assert.equals(value, nil, message or 'Expected nil')
    end
    
    -- assert.isNotNil
    context.assert.isNotNil = function(value, message)
        return context.assert.notEquals(value, nil, message or 'Expected not nil')
    end
    
    -- assert.isType
    context.assert.isType = function(value, expectedType, message)
        return context.assert.equals(type(value), expectedType, 
            message or string.format('Expected type %s', expectedType))
    end
    
    -- assert.throws
    context.assert.throws = function(fn, message)
        context.assertions.total = context.assertions.total + 1
        local success, err = pcall(fn)
        if not success then
            context.assertions.passed = context.assertions.passed + 1
            return true
        else
            context.assertions.failed = context.assertions.failed + 1
            local errMsg = message or 'Expected function to throw error'
            table.insert(context.assertions.errors, errMsg)
            return false
        end
    end
    
    -- expect (alias pour assert)
    context.expect = context.assert
    
    -- === UTILITIES ===
    
    -- Mock functions
    context.utils.mock = function(fn)
        local mock = {
            calls = {},
            returns = nil,
            fn = fn
        }
        
        local mockFn = function(...)
            local args = {...}
            table.insert(mock.calls, args)
            
            if mock.returns then
                return mock.returns
            elseif mock.fn then
                return mock.fn(...)
            end
        end
        
        mock.mockReturn = function(value)
            mock.returns = value
            return mockFn
        end
        
        mock.wasCalled = function()
            return #mock.calls > 0
        end
        
        mock.wasCalledWith = function(...)
            local expectedArgs = {...}
            for _, call in ipairs(mock.calls) do
                if TestRunner.CompareArgs(call, expectedArgs) then
                    return true
                end
            end
            return false
        end
        
        return mockFn, mock
    end
    
    -- Wait/Delay
    context.utils.wait = function(ms)
        Wait(ms)
    end
    
    -- Random data
    context.utils.randomString = function(length)
        local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
        local result = ''
        for i = 1, length do
            local rand = math.random(1, #chars)
            result = result .. string.sub(chars, rand, rand)
        end
        return result
    end
    
    context.utils.randomInt = function(min, max)
        return math.random(min, max)
    end
    
    return context
end

-- === UTILITAIRES ===
function TestRunner.CompareArgs(actual, expected)
    if #actual ~= #expected then
        return false
    end
    
    for i, v in ipairs(expected) do
        if actual[i] ~= v then
            return false
        end
    end
    
    return true
end

function TestRunner.Stop()
    runnerState.isRunning = false
    runnerState.queue = {}
end

function TestRunner.IsRunning()
    return runnerState.isRunning
end

function TestRunner.GetCurrentTest()
    return runnerState.currentTest
end

function TestRunner.GetResults()
    return runnerState.results
end

-- === SANDBOX (Isolation) ===
function TestRunner.CreateSandbox(options)
    local sandbox = {
        enabled = options.Enabled,
        fakeDB = options.FakeDatabase,
        fakeEconomy = options.FakeEconomy,
        fakeInventory = options.FakeInventory
    }
    
    if not sandbox.enabled then
        return nil
    end
    
    -- Créer des mocks pour isoler les tests
    local mocks = {}
    
    if sandbox.fakeDB then
        mocks.db = TestRunner.CreateFakeDatabase()
    end
    
    if sandbox.fakeEconomy then
        mocks.economy = TestRunner.CreateFakeEconomy()
    end
    
    if sandbox.fakeInventory then
        mocks.inventory = TestRunner.CreateFakeInventory()
    end
    
    return mocks
end

function TestRunner.CreateFakeDatabase()
    local fakeData = {}
    
    return {
        execute = function(query, params)
            print('[FAKE DB] Execute:', query)
            return { affectedRows = 1 }
        end,
        
        fetchAll = function(query, params)
            print('[FAKE DB] FetchAll:', query)
            return fakeData[query] or {}
        end,
        
        insert = function(query, params)
            print('[FAKE DB] Insert:', query)
            return math.random(1, 1000)
        end
    }
end

function TestRunner.CreateFakeEconomy()
    return {
        addMoney = function(source, amount)
            print('[FAKE ECONOMY] AddMoney:', source, amount)
            return true
        end,
        
        removeMoney = function(source, amount)
            print('[FAKE ECONOMY] RemoveMoney:', source, amount)
            return true
        end,
        
        getMoney = function(source)
            print('[FAKE ECONOMY] GetMoney:', source)
            return 10000
        end
    }
end

function TestRunner.CreateFakeInventory()
    return {
        addItem = function(source, item, amount)
            print('[FAKE INVENTORY] AddItem:', source, item, amount)
            return true
        end,
        
        removeItem = function(source, item, amount)
            print('[FAKE INVENTORY] RemoveItem:', source, item, amount)
            return true
        end,
        
        getItem = function(source, item)
            print('[FAKE INVENTORY] GetItem:', source, item)
            return { name = item, count = 5 }
        end
    }
end

-- === EXPORTS ===
return TestRunner
