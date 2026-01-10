-- ========================================
-- CONFIGURATION JOB EMS - vAvA_core
-- ========================================

-- Ce fichier doit être ajouté à la configuration des jobs dans vAvA_core
-- Chemin: vAvA_core/jobs/ (créer si n'existe pas)

return {
    name = 'ambulance',
    label = 'EMS',
    defaultDuty = true,
    
    grades = {
        [0] = {
            name = 'stagiaire',
            label = 'Stagiaire EMS',
            salary = 500,
            isboss = false
        },
        [1] = {
            name = 'ambulancier',
            label = 'Ambulancier',
            salary = 750,
            isboss = false
        },
        [2] = {
            name = 'paramedic',
            label = 'Paramedic',
            salary = 1000,
            isboss = false
        },
        [3] = {
            name = 'medecin',
            label = 'Médecin',
            salary = 1500,
            isboss = false
        },
        [4] = {
            name = 'chirurgien',
            label = 'Chirurgien',
            salary = 2000,
            isboss = false
        },
        [5] = {
            name = 'chef',
            label = 'Chef des Services',
            salary = 2500,
            isboss = true
        }
    }
}
