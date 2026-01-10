-- ========================================
-- TESTS TESTBENCH - vAvA_ems
-- ========================================

local Tests = {}

-- ========================================
-- TESTS UNITAIRES - Signes Vitaux
-- ========================================

Tests['test_vital_signs_initialization'] = {
    category = 'unit',
    description = 'Vérifier que les signes vitaux sont correctement initialisés',
    run = function()
        local vitals = EMSConfig.NormalVitalSigns
        
        assert(vitals.pulse == 75, 'Pouls initial incorrect')
        assert(vitals.bloodPressureSystolic == 120, 'Tension systolique initiale incorrecte')
        assert(vitals.bloodPressureDiastolic == 80, 'Tension diastolique initiale incorrecte')
        assert(vitals.oxygenSaturation == 98, 'Saturation O2 initiale incorrecte')
        assert(vitals.temperature == 37.0, 'Température initiale incorrecte')
        assert(vitals.painLevel == 0, 'Niveau de douleur initial incorrect')
        assert(vitals.bloodVolume == 100, 'Volume sanguin initial incorrect')
        
        return true, 'Signes vitaux correctement initialisés'
    end
}

Tests['test_vital_signs_limits'] = {
    category = 'unit',
    description = 'Vérifier que les limites des signes vitaux sont cohérentes',
    run = function()
        local limits = EMSConfig.CriticalLimits
        
        assert(limits.pulse.min < limits.pulse.max, 'Limites de pouls incohérentes')
        assert(limits.pulse.critical_low > limits.pulse.min, 'Seuil critique bas du pouls incohérent')
        assert(limits.pulse.critical_high < limits.pulse.max, 'Seuil critique haut du pouls incohérent')
        
        assert(limits.bloodVolume.critical < limits.bloodVolume.max, 'Seuil critique volume sanguin incohérent')
        assert(limits.bloodVolume.critical > limits.bloodVolume.min, 'Seuil critique volume sanguin incohérent')
        
        return true, 'Limites des signes vitaux cohérentes'
    end
}

-- ========================================
-- TESTS UNITAIRES - Blessures
-- ========================================

Tests['test_injury_types_valid'] = {
    category = 'unit',
    description = 'Vérifier que tous les types de blessures sont valides',
    run = function()
        local injuryTypes = EMSConfig.InjuryTypes
        
        assert(#injuryTypes > 0, 'Aucun type de blessure défini')
        
        for _, injuryType in ipairs(injuryTypes) do
            assert(type(injuryType) == 'string', 'Type de blessure invalide: ' .. tostring(injuryType))
            assert(#injuryType > 0, 'Type de blessure vide')
        end
        
        return true, string.format('%d types de blessures validés', #injuryTypes)
    end
}

Tests['test_body_parts_valid'] = {
    category = 'unit',
    description = 'Vérifier que toutes les parties du corps sont valides',
    run = function()
        local bodyParts = EMSConfig.BodyParts
        
        assert(#bodyParts > 0, 'Aucune partie du corps définie')
        
        for _, bodyPart in ipairs(bodyParts) do
            assert(type(bodyPart) == 'string', 'Partie du corps invalide: ' .. tostring(bodyPart))
            assert(#bodyPart > 0, 'Partie du corps vide')
        end
        
        return true, string.format('%d parties du corps validées', #bodyParts)
    end
}

Tests['test_injury_severity_valid'] = {
    category = 'unit',
    description = 'Vérifier que les niveaux de sévérité sont valides',
    run = function()
        local severity = EMSConfig.InjurySeverity
        
        assert(severity.MINOR == 1, 'Sévérité MINOR incorrecte')
        assert(severity.MODERATE == 2, 'Sévérité MODERATE incorrecte')
        assert(severity.SEVERE == 3, 'Sévérité SEVERE incorrecte')
        assert(severity.CRITICAL == 4, 'Sévérité CRITICAL incorrecte')
        
        return true, 'Niveaux de sévérité validés'
    end
}

-- ========================================
-- TESTS UNITAIRES - Groupes Sanguins
-- ========================================

Tests['test_blood_types_valid'] = {
    category = 'unit',
    description = 'Vérifier que tous les groupes sanguins sont valides',
    run = function()
        local bloodTypes = EMSConfig.BloodTypes
        
        assert(#bloodTypes == 8, 'Nombre de groupes sanguins incorrect (attendu: 8)')
        
        local expectedTypes = {'O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'}
        for _, expected in ipairs(expectedTypes) do
            local found = false
            for _, bloodType in ipairs(bloodTypes) do
                if bloodType == expected then
                    found = true
                    break
                end
            end
            assert(found, 'Groupe sanguin manquant: ' .. expected)
        end
        
        return true, 'Tous les groupes sanguins sont présents'
    end
}

Tests['test_blood_compatibility'] = {
    category = 'unit',
    description = 'Vérifier la cohérence de la compatibilité sanguine',
    run = function()
        local compatibility = EMSConfig.BloodCompatibility
        
        -- O- est donneur universel mais ne peut recevoir que de O-
        assert(#compatibility['O-'] == 1, 'O- doit pouvoir recevoir uniquement de O-')
        assert(compatibility['O-'][1] == 'O-', 'O- doit pouvoir recevoir de O-')
        
        -- AB+ est receveur universel
        assert(#compatibility['AB+'] == 8, 'AB+ doit pouvoir recevoir de tous les groupes')
        
        -- O+ peut recevoir de O- et O+
        assert(#compatibility['O+'] == 2, 'O+ doit pouvoir recevoir de O- et O+')
        
        return true, 'Compatibilité sanguine cohérente'
    end
}

Tests['test_blood_stock_initialization'] = {
    category = 'unit',
    description = 'Vérifier que le stock de sang initial est correct',
    run = function()
        local stock = EMSConfig.InitialBloodStock
        
        for _, bloodType in ipairs(EMSConfig.BloodTypes) do
            assert(stock[bloodType] ~= nil, 'Stock initial manquant pour ' .. bloodType)
            assert(type(stock[bloodType]) == 'number', 'Stock initial invalide pour ' .. bloodType)
            assert(stock[bloodType] >= 0, 'Stock initial négatif pour ' .. bloodType)
        end
        
        return true, 'Stock de sang initial correctement configuré'
    end
}

-- ========================================
-- TESTS UNITAIRES - Équipement Médical
-- ========================================

Tests['test_medical_equipment_structure'] = {
    category = 'unit',
    description = 'Vérifier la structure de l\'équipement médical',
    run = function()
        local equipment = EMSConfig.MedicalEquipment
        
        assert(equipment.basic ~= nil, 'Équipement basique manquant')
        assert(equipment.advanced ~= nil, 'Équipement avancé manquant')
        assert(equipment.critical ~= nil, 'Équipement critique manquant')
        
        assert(#equipment.basic > 0, 'Aucun équipement basique défini')
        assert(#equipment.advanced > 0, 'Aucun équipement avancé défini')
        assert(#equipment.critical > 0, 'Aucun équipement critique défini')
        
        return true, 'Structure de l\'équipement médical valide'
    end
}

Tests['test_equipment_grades'] = {
    category = 'unit',
    description = 'Vérifier que les grades d\'équipement sont cohérents',
    run = function()
        local grades = EMSConfig.EquipmentGrades
        
        assert(grades[0] == 'basic', 'Grade 0 doit être basic')
        assert(grades[1] == 'basic', 'Grade 1 doit être basic')
        assert(grades[2] == 'advanced', 'Grade 2 doit être advanced')
        assert(grades[3] == 'critical', 'Grade 3 doit être critical')
        assert(grades[4] == 'critical', 'Grade 4 doit être critical')
        
        return true, 'Grades d\'équipement cohérents'
    end
}

-- ========================================
-- TESTS D'INTÉGRATION - Système Médical
-- ========================================

Tests['test_medical_states_progression'] = {
    category = 'integration',
    description = 'Vérifier la progression logique des états médicaux',
    run = function()
        local states = EMSConfig.MedicalStates
        
        local orderedStates = {
            states.NORMAL,
            states.LIGHT_PAIN,
            states.MODERATE_PAIN,
            states.SEVERE_PAIN,
            states.BLEEDING,
            states.UNCONSCIOUS,
            states.COMA,
            states.CARDIAC_ARREST,
            states.DEAD
        }
        
        for _, state in ipairs(orderedStates) do
            assert(type(state) == 'string', 'État médical invalide: ' .. tostring(state))
        end
        
        return true, 'Progression des états médicaux cohérente'
    end
}

Tests['test_bleeding_rates'] = {
    category = 'integration',
    description = 'Vérifier que les taux de saignement sont progressifs',
    run = function()
        local rates = EMSConfig.BleedingRates
        
        assert(rates.none < rates.slow, 'Taux de saignement incohérent: none >= slow')
        assert(rates.slow < rates.active, 'Taux de saignement incohérent: slow >= active')
        assert(rates.active < rates.critical, 'Taux de saignement incohérent: active >= critical')
        
        assert(rates.none == 0, 'Taux de saignement "none" doit être 0')
        assert(rates.critical > 0, 'Taux de saignement "critical" doit être > 0')
        
        return true, 'Taux de saignement cohérents'
    end
}

-- ========================================
-- TESTS D'INTÉGRATION - Appels d'Urgence
-- ========================================

Tests['test_emergency_codes_structure'] = {
    category = 'integration',
    description = 'Vérifier la structure des codes d\'urgence',
    run = function()
        local codes = EMSConfig.EmergencyCalls.codes
        
        assert(codes.RED ~= nil, 'Code RED manquant')
        assert(codes.ORANGE ~= nil, 'Code ORANGE manquant')
        assert(codes.YELLOW ~= nil, 'Code YELLOW manquant')
        assert(codes.BLUE ~= nil, 'Code BLUE manquant')
        
        assert(codes.RED.priority == 1, 'Priorité RED incorrecte')
        assert(codes.ORANGE.priority == 2, 'Priorité ORANGE incorrecte')
        assert(codes.YELLOW.priority == 3, 'Priorité YELLOW incorrecte')
        assert(codes.BLUE.priority == 4, 'Priorité BLUE incorrecte')
        
        return true, 'Codes d\'urgence correctement structurés'
    end
}

Tests['test_emergency_call_settings'] = {
    category = 'integration',
    description = 'Vérifier les paramètres des appels d\'urgence',
    run = function()
        local settings = EMSConfig.EmergencyCalls
        
        assert(type(settings.enabled) == 'boolean', 'enabled doit être un booléen')
        assert(type(settings.autoDetect) == 'boolean', 'autoDetect doit être un booléen')
        assert(type(settings.autoDetectDelay) == 'number', 'autoDetectDelay doit être un nombre')
        assert(type(settings.cooldown) == 'number', 'cooldown doit être un nombre')
        
        assert(settings.autoDetectDelay > 0, 'autoDetectDelay doit être positif')
        assert(settings.cooldown > 0, 'cooldown doit être positif')
        
        return true, 'Paramètres des appels d\'urgence valides'
    end
}

-- ========================================
-- TESTS D'INTÉGRATION - Hôpital
-- ========================================

Tests['test_hospital_zones'] = {
    category = 'integration',
    description = 'Vérifier que toutes les zones hospitalières sont définies',
    run = function()
        local zones = EMSConfig.Hospital.zones
        
        local requiredZones = {
            'reception', 'emergency', 'triage', 'surgery', 'icu',
            'pharmacy', 'radiology', 'laboratory', 'bloodbank'
        }
        
        for _, zoneName in ipairs(requiredZones) do
            assert(zones[zoneName] ~= nil, 'Zone hospitalière manquante: ' .. zoneName)
            
            local zone = zones[zoneName]
            assert(type(zone) == 'vector3', 'Coordonnées invalides pour ' .. zoneName)
        end
        
        return true, 'Toutes les zones hospitalières sont définies'
    end
}

Tests['test_hospital_beds'] = {
    category = 'integration',
    description = 'Vérifier que les lits d\'hôpital sont correctement configurés',
    run = function()
        local beds = EMSConfig.Hospital.beds
        
        assert(#beds > 0, 'Aucun lit d\'hôpital défini')
        
        for i, bed in ipairs(beds) do
            assert(bed.coords ~= nil, 'Coordonnées manquantes pour le lit ' .. i)
            assert(type(bed.occupied) == 'boolean', 'Statut "occupied" invalide pour le lit ' .. i)
        end
        
        return true, string.format('%d lits d\'hôpital validés', #beds)
    end
}

Tests['test_hospital_costs'] = {
    category = 'integration',
    description = 'Vérifier que les coûts hospitaliers sont cohérents',
    run = function()
        local costs = EMSConfig.Hospital.costs
        
        assert(costs.checkup > 0, 'Coût checkup doit être positif')
        assert(costs.emergency > costs.checkup, 'Coût emergency doit être > checkup')
        assert(costs.surgery > costs.emergency, 'Coût surgery doit être > emergency')
        assert(costs.hospitalization > 0, 'Coût hospitalization doit être positif')
        assert(costs.bloodTransfusion > 0, 'Coût bloodTransfusion doit être positif')
        
        return true, 'Coûts hospitaliers cohérents'
    end
}

-- ========================================
-- TESTS DE COHÉRENCE - Configuration
-- ========================================

Tests['test_config_locale'] = {
    category = 'consistency',
    description = 'Vérifier que la locale est valide',
    run = function()
        local locale = EMSConfig.Locale
        
        assert(locale ~= nil, 'Locale non définie')
        assert(type(locale) == 'string', 'Locale doit être une chaîne')
        
        local validLocales = {'fr', 'en', 'es'}
        local isValid = false
        for _, valid in ipairs(validLocales) do
            if locale == valid then
                isValid = true
                break
            end
        end
        
        assert(isValid, 'Locale invalide: ' .. locale)
        
        return true, 'Locale valide: ' .. locale
    end
}

Tests['test_config_job'] = {
    category = 'consistency',
    description = 'Vérifier que le job EMS est défini',
    run = function()
        local job = EMSConfig.EMSJob
        
        assert(job ~= nil, 'Job EMS non défini')
        assert(type(job) == 'string', 'Job EMS doit être une chaîne')
        assert(#job > 0, 'Job EMS vide')
        
        return true, 'Job EMS défini: ' .. job
    end
}

Tests['test_config_save_settings'] = {
    category = 'consistency',
    description = 'Vérifier les paramètres de sauvegarde',
    run = function()
        local save = EMSConfig.Save
        
        assert(type(save.interval) == 'number', 'interval doit être un nombre')
        assert(save.interval > 0, 'interval doit être positif')
        assert(type(save.onDeath) == 'boolean', 'onDeath doit être un booléen')
        assert(type(save.onDisconnect) == 'boolean', 'onDisconnect doit être un booléen')
        
        return true, 'Paramètres de sauvegarde valides'
    end
}

Tests['test_config_hud_settings'] = {
    category = 'consistency',
    description = 'Vérifier les paramètres du HUD',
    run = function()
        local hud = EMSConfig.HUD
        
        assert(type(hud.enabled) == 'boolean', 'enabled doit être un booléen')
        assert(type(hud.onlyForEMS) == 'boolean', 'onlyForEMS doit être un booléen')
        assert(type(hud.position) == 'string', 'position doit être une chaîne')
        assert(type(hud.updateInterval) == 'number', 'updateInterval doit être un nombre')
        assert(hud.updateInterval > 0, 'updateInterval doit être positif')
        
        local validPositions = {'top-left', 'top-right', 'bottom-left', 'bottom-right'}
        local isValid = false
        for _, valid in ipairs(validPositions) do
            if hud.position == valid then
                isValid = true
                break
            end
        end
        
        assert(isValid, 'Position HUD invalide: ' .. hud.position)
        
        return true, 'Paramètres HUD valides'
    end
}

-- ========================================
-- EXPORT DES TESTS
-- ========================================

return Tests
