--[[
    vAvA_core - Permission Diagnostic Tool
    Outil de diagnostic des permissions
    
    Commandes:
    - /vava_debug_perms       → Affiche vos permissions actuelles
    - /vava_test_ace [ace]    → Test un ACE spécifique
    - /vava_list_aces         → Liste tous les ACE disponibles
]]

-- /vava_debug_perms - Diagnostic complet des permissions
RegisterCommand('vava_debug_perms', function(source, args, rawCommand)
    if source <= 0 then return end
    
    local player = vCore.GetPlayer(source)
    local identifier = vCore.Players.GetIdentifier(source)
    local identifiers = vCore.Players.GetAllIdentifiers(source)
    
    print('=================================================')
    print('[vAvA_core] DIAGNOSTIC PERMISSIONS - ' .. GetPlayerName(source))
    print('=================================================')
    print('Source: ' .. source)
    print('Identifier: ' .. (identifier or 'AUCUN'))
    print('')
    print('--- IDENTIFIANTS ---')
    if identifiers.license then print('License : ' .. identifiers.license) end
    if identifiers.discord then print('Discord : ' .. identifiers.discord) end
    if identifiers.steam then print('Steam   : ' .. identifiers.steam) end
    if identifiers.ip then print('IP      : ' .. identifiers.ip) end
    print('')
    
    if player then
        print('--- PLAYER OBJECT ---')
        print('Group: ' .. (player.group or 'AUCUN'))
        print('Permission Level: ' .. player:GetPermissionLevel())
        print('Is Admin: ' .. tostring(player:IsAdmin()))
        print('')
    else
        print('⚠️ ERREUR: Player object non trouvé!')
        print('Le joueur doit avoir un personnage chargé.')
        print('')
    end
    
    print('--- CONFIG PERMISSIONS ---')
    print('Method: ' .. Config.Permissions.Method)
    print('AcePrefix: ' .. Config.Permissions.AcePrefix)
    print('')
    
    print('--- TEST ACE (txAdmin) ---')
    local aces = {
        'vava.owner',
        'vava.developer',
        'vava.superadmin',
        'vava.admin',
        'vava.mod',
        'vava.helper',
        'txadmin.operator',
        'txadmin.operator.super'
    }
    
    for _, ace in ipairs(aces) do
        local hasAce = IsPlayerAceAllowed(source, ace)
        local status = hasAce and '✅ OUI' or '❌ NON'
        print(string.format('%-30s %s', ace, status))
    end
    
    print('')
    print('--- RECOMMANDATIONS ---')
    
    if not player then
        print('⚠️ Créez et chargez un personnage avant de tester les permissions')
    elseif player:GetPermissionLevel() == 0 then
        print('⚠️ Aucune permission détectée!')
        print('1. Utilisez /vava_getid pour récupérer votre identifiant')
        print('2. Ajoutez cette ligne dans server.cfg:')
        if identifiers.license then
            print('   add_principal identifier.' .. identifiers.license .. ' group.admin')
        end
        print('3. Redémarrez le serveur')
    else
        print('✅ Permissions configurées correctement!')
        print('Niveau: ' .. player:GetPermissionLevel())
    end
    
    print('=================================================')
    
    -- Afficher aussi en jeu
    if player then
        vCore.Notify(source, '~b~Diagnostic envoyé en console serveur!', 'info')
        vCore.Notify(source, '~g~Niveau:~w~ ' .. player:GetPermissionLevel(), 'info')
        vCore.Notify(source, '~g~Admin:~w~ ' .. tostring(player:IsAdmin()), 'info')
    else
        vCore.Notify(source, '~r~Erreur: Player object non trouvé!', 'error')
        vCore.Notify(source, '~y~Chargez un personnage d\'abord', 'info')
    end
end, false)

-- /vava_test_ace - Tester un ACE spécifique
RegisterCommand('vava_test_ace', function(source, args, rawCommand)
    if source <= 0 then return end
    
    if #args < 1 then
        vCore.Notify(source, '~y~Usage: /vava_test_ace [ace_name]', 'info')
        vCore.Notify(source, '~y~Exemple: /vava_test_ace vava.admin', 'info')
        return
    end
    
    local ace = args[1]
    local hasAce = IsPlayerAceAllowed(source, ace)
    
    print('[vAvA_core] Test ACE - ' .. GetPlayerName(source) .. ' → ' .. ace .. ' = ' .. tostring(hasAce))
    
    if hasAce then
        vCore.Notify(source, '~g~✅ Vous avez l\'ACE:~w~ ' .. ace, 'success')
    else
        vCore.Notify(source, '~r~❌ Vous n\'avez PAS l\'ACE:~w~ ' .. ace, 'error')
    end
end, false)

-- /vava_list_aces - Lister tous les ACE disponibles
RegisterCommand('vava_list_aces', function(source, args, rawCommand)
    if source <= 0 then return end
    
    vCore.Notify(source, '~b~=== ACE DISPONIBLES ===', 'info')
    
    local aces = {
        {name = 'vava.owner', desc = 'Propriétaire (Niveau 5)'},
        {name = 'vava.developer', desc = 'Développeur (Niveau 4)'},
        {name = 'vava.superadmin', desc = 'Super Admin (Niveau 3)'},
        {name = 'vava.admin', desc = 'Admin (Niveau 2)'},
        {name = 'vava.mod', desc = 'Modérateur (Niveau 1)'},
        {name = 'vava.helper', desc = 'Helper (Niveau 0)'},
    }
    
    print('=================================================')
    print('[vAvA_core] ACE Disponibles pour ' .. GetPlayerName(source))
    print('=================================================')
    
    for _, data in ipairs(aces) do
        local hasAce = IsPlayerAceAllowed(source, data.name)
        local status = hasAce and '✅' or '❌'
        
        print(string.format('%s %-20s - %s', status, data.name, data.desc))
        
        if hasAce then
            vCore.Notify(source, '~g~✅ ' .. data.name .. '~w~ - ' .. data.desc, 'info')
        end
    end
    
    print('=================================================')
    vCore.Notify(source, '~b~Consultez la console serveur pour détails', 'info')
end, false)

-- /vava_perm_help - Aide sur les permissions
RegisterCommand('vava_perm_help', function(source, args, rawCommand)
    if source <= 0 then return end
    
    vCore.Notify(source, '~b~=== AIDE PERMISSIONS ===', 'info')
    vCore.Notify(source, '~y~/vava_getid~w~ - Voir vos identifiants', 'info')
    vCore.Notify(source, '~y~/vava_debug_perms~w~ - Diagnostic complet', 'info')
    vCore.Notify(source, '~y~/vava_test_ace [ace]~w~ - Tester un ACE', 'info')
    vCore.Notify(source, '~y~/vava_list_aces~w~ - Lister les ACE', 'info')
    vCore.Notify(source, '~b~Consultez GUIDE_PERMISSIONS.md', 'info')
    
    print('[vAvA_core] Aide permissions envoyée à ' .. GetPlayerName(source))
end, false)

print('[vAvA_core] ^2✓^7 Permission diagnostic tools loaded')
