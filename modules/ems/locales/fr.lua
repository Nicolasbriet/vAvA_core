Locales = Locales or {}

Locales['fr'] = {
    -- Général
    ['not_ems'] = 'Vous devez être membre de l\'EMS',
    ['too_far'] = 'Vous êtes trop loin du patient',
    ['missing_equipment'] = 'Vous n\'avez pas l\'équipement nécessaire',
    
    -- États médicaux
    ['normal'] = 'Normal',
    ['light_pain'] = 'Douleur légère',
    ['moderate_pain'] = 'Douleur modérée',
    ['severe_pain'] = 'Douleur sévère',
    ['bleeding'] = 'Saignement',
    ['unconscious'] = 'Inconscient',
    ['coma'] = 'Coma',
    ['cardiac_arrest'] = 'Arrêt cardiaque',
    ['dead'] = 'Mort',
    
    -- Blessures
    ['injury_received'] = 'Vous avez été blessé',
    ['bodypart_treated'] = '%{part} soignée (%{count} blessures)',
    ['contusion'] = 'Contusion',
    ['open_wound'] = 'Plaie ouverte',
    ['simple_fracture'] = 'Fracture simple',
    ['open_fracture'] = 'Fracture ouverte',
    ['gunshot_entry'] = 'Blessure par balle (entrée)',
    ['gunshot_exit'] = 'Blessure par balle (sortie)',
    ['burn_first'] = 'Brûlure 1er degré',
    ['burn_second'] = 'Brûlure 2e degré',
    ['burn_third'] = 'Brûlure 3e degré',
    ['head_trauma'] = 'Traumatisme crânien',
    ['internal_injury'] = 'Lésion interne',
    ['internal_bleeding'] = 'Hémorragie interne',
    
    -- Parties du corps
    ['head'] = 'Tête',
    ['neck'] = 'Cou',
    ['chest'] = 'Torse',
    ['abdomen'] = 'Abdomen',
    ['left_arm'] = 'Bras gauche',
    ['right_arm'] = 'Bras droit',
    ['left_leg'] = 'Jambe gauche',
    ['right_leg'] = 'Jambe droite',
    
    -- Diagnostic
    ['examining_patient'] = 'Examen du patient...',
    ['diagnosis_failed'] = 'Échec du diagnostic',
    
    -- Sang & transfusions
    ['blood_incompatible'] = 'Groupe sanguin incompatible !',
    ['blood_stock_empty'] = 'Stock de sang insuffisant',
    ['blood_stock_updated'] = 'Stock de sang %{type} mis à jour : %{units} unités',
    ['transfusion_success'] = 'Transfusion effectuée avec succès',
    ['transfusion_received'] = 'Vous avez reçu une transfusion sanguine',
    
    -- Don de sang
    ['blood_donation_title'] = 'Don de sang',
    ['blood_donation_confirm'] = 'Voulez-vous faire un don de sang ?',
    ['blood_donation_cooldown'] = 'Vous devez attendre %{time} jours avant de donner à nouveau',
    ['blood_donation_health_too_low'] = 'Votre santé est trop faible pour donner votre sang',
    ['blood_donation_success'] = 'Don de sang effectué ! Vous avez reçu %{reward}$',
    ['blood_donation_effects_end'] = 'Les effets du don de sang se dissipent',
    
    -- Appels d'urgence
    ['emergency_call'] = 'Appel d\'urgence',
    ['describe_emergency'] = 'Décrivez l\'urgence',
    ['emergency_called'] = 'Les secours ont été appelés',
    ['emergency_call_received'] = 'Appel d\'urgence : %{code} - %{location}',
    ['code_red'] = 'Code Rouge',
    ['code_orange'] = 'Code Orange',
    ['code_yellow'] = 'Code Jaune',
    ['code_blue'] = 'Code Bleu',
    
    -- Mort & Respawn
    ['you_are_dead'] = 'Vous êtes inconscient',
    ['waiting_ems'] = 'En attente des secours EMS...',
    ['can_respawn'] = 'Vous pouvez réapparaître à l\'hôpital',
    ['press_respawn'] = 'Appuyez sur [E] pour réapparaître',
    ['respawn_cost'] = 'Frais hospitaliers : %{cost}$',
    ['revived'] = 'Vous avez été réanimé',
    
    -- Équipement
    ['medical_gloves'] = 'Gants médicaux',
    ['bandage'] = 'Bandage',
    ['splint'] = 'Attelle',
    ['antiseptic'] = 'Antiseptique',
    ['oxygen_portable'] = 'Oxygène portable',
    ['compress'] = 'Pansement compressif',
    ['defibrillator'] = 'Défibrillateur',
    ['iv_nacl'] = 'Perfusion NaCl',
    ['iv_plasma'] = 'Perfusion Plasma',
    ['iv_ringer'] = 'Ringer Lactate',
    ['morphine'] = 'Morphine',
    ['adrenaline'] = 'Adrénaline',
    ['suture_kit'] = 'Kit de suture',
    ['chest_kit'] = 'Kit thoracique',
    ['backboard'] = 'Planche dorsale',
    ['intubation_kit'] = 'Kit d\'intubation',
    ['ventilator'] = 'Ventilateur mécanique',
    ['surgery_kit'] = 'Kit chirurgie d\'urgence',
    ['resuscitation_kit'] = 'Kit réanimation avancée',
    ['ultrasound'] = 'Échographie portable',
    ['transfusion_kit'] = 'Kit transfusion',
    
    -- Véhicules
    ['ambulance'] = 'Ambulance standard',
    ['ambulance2'] = 'Ambulance de réanimation',
    ['polmav'] = 'Hélicoptère médical',
    
    -- Hôpital
    ['hospital_main'] = 'Pillbox Hill Medical Center',
    ['reception'] = 'Réception',
    ['emergency'] = 'Urgences',
    ['triage'] = 'Tri',
    ['surgery'] = 'Bloc opératoire',
    ['icu'] = 'Réanimation',
    ['pharmacy'] = 'Pharmacie',
    ['radiology'] = 'Radiologie',
    ['laboratory'] = 'Laboratoire',
    ['bloodbank'] = 'Banque de sang'
}

function Lang(key, args)
    local locale = EMSConfig.Locale or 'fr'
    local str = Locales[locale][key] or key
    
    if args then
        for k, v in pairs(args) do
            str = string.gsub(str, '%%{' .. k .. '}', v)
        end
    end
    
    return str
end
