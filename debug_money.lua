-- Commande de debug pour vérifier le système d'argent
RegisterCommand('debugmoney', function(source, args, rawCommand)
    if source > 0 and not HasAdminPermission(source, 'command.checkmoney') then
        vCore.Notify(source, 'Vous n\'avez pas la permission', 'error')
        return
    end
    
    local targetId = source
    if #args >= 1 then
        targetId = tonumber(args[1])
        if not targetId then
            vCore.Notify(source, 'ID invalide', 'error')
            return
        end
    end
    
    local player = vCore.GetPlayer(targetId)
    if not player then
        vCore.Notify(source, 'Joueur introuvable', 'error')
        return
    end
    
    -- Récupérer les infos du joueur
    local playerData = player:GetData()
    local cash = vCore.GetPlayerMoney(targetId, 'cash')
    local bank = vCore.GetPlayerMoney(targetId, 'bank') 
    local blackMoney = vCore.GetPlayerMoney(targetId, 'black_money')
    
    print(string.format('[DEBUG MONEY] Joueur: %s (ID: %s)', player:GetName(), targetId))
    print(string.format('[DEBUG MONEY] Cash: %s', cash))
    print(string.format('[DEBUG MONEY] Bank: %s', bank))
    print(string.format('[DEBUG MONEY] Black Money: %s', blackMoney))
    print(string.format('[DEBUG MONEY] Total: %s', cash + bank + blackMoney))
    
    if playerData.money then
        print('[DEBUG MONEY] PlayerData.money:')
        for moneyType, amount in pairs(playerData.money) do
            print(string.format('  %s: %s', moneyType, amount))
        end
    else
        print('[DEBUG MONEY] ERREUR: PlayerData.money est nil!')
    end
    
    local msg = string.format('DEBUG: %s - Cash: %s | Bank: %s | Black: %s', 
        player:GetName(),
        vCore.Utils.FormatMoney(cash),
        vCore.Utils.FormatMoney(bank),
        vCore.Utils.FormatMoney(blackMoney)
    )
    
    if source > 0 then
        vCore.Notify(source, msg, 'info')
    end
end, false)

print('[vAvA_core] Debug money command loaded')