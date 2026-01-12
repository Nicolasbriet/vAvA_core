-- Test rapide des nouvelles commandes sans erreurs
print('=== TEST CORRECTIONS LOGS ===')

-- Vérifier que vCore.Log existe
if vCore and vCore.Log then
    print('✓ vCore.Log disponible')
    
    -- Test du système de log (simulation)
    vCore.Log('test', 'license:test', 'Test des corrections de logs', {
        action = 'log_fix_test',
        timestamp = os.time()
    })
    print('✓ vCore.Log fonctionne')
else
    print('✗ vCore.Log NON disponible')
end

-- Vérifier que vCore.Utils.FormatMoney existe
if vCore and vCore.Utils and vCore.Utils.FormatMoney then
    print('✓ vCore.Utils.FormatMoney disponible')
    
    -- Test de formatage
    local testAmount = 12345
    local formatted = vCore.Utils.FormatMoney(testAmount)
    print('✓ Test formatage: ' .. testAmount .. ' → ' .. formatted)
else
    print('✗ vCore.Utils.FormatMoney NON disponible')
end

print('=== FIN DES TESTS ===')