--[[
    Test des nouvelles commandes d'argent vAvA_core
    Usage: exec test_money_commands.lua dans la console
]]

print('=== TEST DES COMMANDES D\'ARGENT vAvA ===')

-- Test 1: Vérifier les fonctions vCore
if vCore and vCore.GetPlayerMoney then
    print('✓ Fonctions vCore money détectées')
else
    print('✗ Fonctions vCore money NON détectées')
end

-- Test 2: Vérifier les joueurs en ligne
local players = {}
for _, playerId in ipairs(GetPlayers()) do
    local player = vCore.GetPlayer(tonumber(playerId))
    if player then
        table.insert(players, {
            id = playerId,
            name = player:GetName(),
            cash = vCore.GetPlayerMoney(tonumber(playerId), 'cash'),
            bank = vCore.GetPlayerMoney(tonumber(playerId), 'bank'),
            black_money = vCore.GetPlayerMoney(tonumber(playerId), 'black_money')
        })
    end
end

print('=== JOUEURS EN LIGNE ===')
for _, p in pairs(players) do
    print(string.format('ID: %s | %s | Cash: $%s | Bank: $%s | Black: $%s', 
        p.id, p.name, 
        vCore.Utils.FormatMoney(p.cash), 
        vCore.Utils.FormatMoney(p.bank),
        vCore.Utils.FormatMoney(p.black_money)
    ))
end

-- Test 3: Commandes disponibles
print('=== COMMANDES D\'ARGENT DISPONIBLES ===')
print('/givemoney [id] [cash/bank/black_money] [montant]')
print('/removemoney [id] [cash/bank/black_money] [montant]')
print('/setmoney [id] [cash/bank/black_money] [montant]')
print('/checkmoney [id]')

print('=== FIN DES TESTS ===')