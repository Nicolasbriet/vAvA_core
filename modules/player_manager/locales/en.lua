--[[
    vAvA_player_manager - Locales EN
    English translation
]]

Locales = Locales or {}

Locales['en'] = {
    -- Selector
    ['selector_title'] = 'Character Selection',
    ['create_character'] = 'Create Character',
    ['delete_character'] = 'Delete',
    ['play_character'] = 'Play',
    ['confirm_delete'] = 'Are you sure you want to delete this character?',
    ['last_played'] = 'Last played',
    ['playtime'] = 'Playtime',
    ['job'] = 'Job',
    ['no_characters'] = 'No characters',
    ['create_first'] = 'Create your first character',
    ['max_characters'] = 'Characters: %s/%s',
    
    -- Creation
    ['creation_title'] = 'Character Creation',
    ['firstname'] = 'First Name',
    ['lastname'] = 'Last Name',
    ['dateofbirth'] = 'Date of Birth',
    ['sex'] = 'Gender',
    ['male'] = 'Male',
    ['female'] = 'Female',
    ['nationality'] = 'Nationality',
    ['story'] = 'Story',
    ['background'] = 'Your profession before Los Santos',
    ['reason'] = 'Why did you come to Los Santos?',
    ['goal'] = 'What is your main goal?',
    ['create_btn'] = 'Create',
    ['cancel_btn'] = 'Cancel',
    ['required_field'] = 'Required field',
    ['invalid_dob'] = 'Invalid date of birth',
    ['too_young'] = 'Minimum age: %s years',
    ['too_old'] = 'Maximum age: %s years',
    
    -- ID Card
    ['id_card'] = 'ID Card',
    ['show_id'] = 'Show ID',
    ['citizen_id'] = 'Citizen ID',
    ['phone_number'] = 'Phone',
    ['issued_date'] = 'Issue Date',
    ['valid_until'] = 'Valid Until',
    ['id_shown_to'] = 'You showed your ID to %s',
    ['id_shown_by'] = '%s shows you their ID card',
    
    -- Licenses
    ['licenses'] = 'Licenses',
    ['no_licenses'] = 'No licenses',
    ['obtain_license'] = 'Obtain',
    ['license_valid'] = 'Valid',
    ['license_expired'] = 'Expired',
    ['license_suspended'] = 'Suspended',
    ['exam_required'] = 'Exam required',
    ['go_to_exam'] = 'Go take exam',
    ['cost'] = 'Cost',
    ['validity'] = 'Validity',
    ['days'] = 'days',
    ['unlimited'] = 'Unlimited',
    ['driver_license'] = 'Driver License',
    ['weapon_license'] = 'Weapon License',
    ['business_license'] = 'Business License',
    ['hunting_license'] = 'Hunting License',
    ['fishing_license'] = 'Fishing License',
    ['pilot_license'] = 'Pilot License',
    ['boat_license'] = 'Boat License',
    
    -- Stats
    ['statistics'] = 'Statistics',
    ['playtime_hours'] = 'Playtime (hours)',
    ['distance_walked_km'] = 'Distance walked (km)',
    ['distance_driven_km'] = 'Distance driven (km)',
    ['total_deaths'] = 'Total deaths',
    ['total_arrests'] = 'Arrests',
    ['jobs_completed'] = 'Jobs completed',
    ['money_earned'] = 'Money earned',
    ['money_spent'] = 'Money spent',
    
    -- History
    ['history'] = 'History',
    ['event_type'] = 'Type',
    ['event_date'] = 'Date',
    ['event_amount'] = 'Amount',
    ['no_history'] = 'No history',
    ['load_more'] = 'Load more',
    
    -- Events
    ['character_login'] = 'Login',
    ['character_logout'] = 'Logout',
    ['job_change'] = 'Job change',
    ['name_change'] = 'Name change',
    ['bank_deposit'] = 'Bank deposit',
    ['bank_withdraw'] = 'Bank withdrawal',
    ['bank_transfer'] = 'Bank transfer',
    ['property_buy'] = 'Property purchase',
    ['property_sell'] = 'Property sale',
    ['vehicle_buy'] = 'Vehicle purchase',
    ['vehicle_sell'] = 'Vehicle sale',
    ['arrest'] = 'Arrest',
    ['fine'] = 'Fine',
    ['jail'] = 'Jail',
    ['death'] = 'Death',
    ['revive'] = 'Revive',
    ['license_obtained'] = 'License obtained',
    ['license_revoked'] = 'License revoked',
    ['license_suspended'] = 'License suspended',
    
    -- Notifications
    ['character_created'] = 'Character created successfully!',
    ['character_deleted'] = 'Character deleted',
    ['character_selected'] = 'Welcome %s %s',
    ['license_obtained_msg'] = 'You obtained: %s',
    ['license_revoked_msg'] = 'Your license %s has been revoked',
    ['license_expired_msg'] = 'Your license %s has expired',
    ['insufficient_funds'] = 'Insufficient funds',
    ['exam_required_msg'] = 'You must take an exam for this license',
    
    -- Errors
    ['error_occurred'] = 'An error occurred',
    ['character_not_found'] = 'Character not found',
    ['access_denied'] = 'Access denied',
    ['license_not_found'] = 'License not found',
    ['max_chars_reached'] = 'Character limit reached',
    
    -- Commands
    ['cmd_characters'] = 'Open character selector',
    ['cmd_deletechar'] = 'Delete character',
    ['cmd_resetchar'] = 'Reset character',
    ['cmd_givelicense'] = 'Give license',
    ['cmd_revokelicense'] = 'Revoke license',
    ['cmd_showid'] = 'Show ID card',
    ['cmd_checkid'] = 'Check ID card',
    ['cmd_showlicenses'] = 'Show my licenses',
    ['cmd_stats'] = 'Show statistics'
}

return Locales['en']
