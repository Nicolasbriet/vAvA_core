-- ═══════════════════════════════════════════════════════════════════════════
-- Script de migration automatique - À exécuter une seule fois
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('migrate_characters', function(source, args)
    if source ~= 0 then
        print('[Migration] Cette commande doit être exécutée depuis la console serveur')
        return
    end
    
    print('[Migration] Démarrage de la migration des personnages...')
    
    -- Vérifier si vava_characters existe
    MySQL.query('SHOW TABLES LIKE "vava_characters"', {}, function(tables)
        if not tables or #tables == 0 then
            print('[Migration] Table vava_characters non trouvée - Migration non nécessaire')
            return
        end
        
        print('[Migration] Table vava_characters trouvée - Migration en cours...')
        
        -- Récupérer tous les personnages de vava_characters
        MySQL.query('SELECT * FROM vava_characters WHERE is_deleted = 0', {}, function(oldChars)
            if not oldChars or #oldChars == 0 then
                print('[Migration] Aucun personnage à migrer')
                return
            end
            
            local migrated = 0
            local total = #oldChars
            
            for _, char in ipairs(oldChars) do
                -- Convertir les données
                local money = char.money or '{"cash":5000,"bank":10000,"black_money":0}'
                local job = char.job or '{"name":"unemployed","grade":0}'
                local position = char.position or '{"x":-269.4,"y":-955.3,"z":31.2,"heading":205.0}'
                local inventory = char.inventory or '[]'
                local metadata = char.metadata or '{}'
                
                -- Convertir la date de naissance
                local dob = '01/01/2000'
                if char.birthdate then
                    local timestamp = math.floor(char.birthdate / 1000)
                    dob = os.date('%d/%m/%Y', timestamp)
                end
                
                -- Insérer dans characters
                MySQL.insert([[
                    INSERT INTO characters (
                        identifier, firstname, lastname, dob, gender,
                        money, job, gang, position, status, inventory, metadata
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE
                        firstname = VALUES(firstname),
                        lastname = VALUES(lastname),
                        money = VALUES(money),
                        job = VALUES(job),
                        position = VALUES(position)
                ]], {
                    char.license,
                    char.firstname,
                    char.lastname,
                    dob,
                    char.gender or 0,
                    money,
                    job,
                    '{"name":"none","grade":0}',
                    position,
                    '{"hunger":100,"thirst":100,"stress":0}',
                    inventory,
                    metadata
                }, function(result)
                    if result then
                        migrated = migrated + 1
                        print(string.format('[Migration] %d/%d - %s %s migré', migrated, total, char.firstname, char.lastname))
                        
                        if migrated >= total then
                            print(string.format('[Migration] ✓ Migration terminée: %d personnages migrés', migrated))
                        end
                    end
                end)
            end
        end)
    end)
end, true)

print('[Migration] Commande /migrate_characters disponible (console serveur uniquement)')
