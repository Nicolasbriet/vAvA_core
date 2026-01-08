--[[
    vAvA_core - English Translations
]]

Locales = Locales or {}

Locales['en'] = {
    -- ═══════════════════════════════════════════════════════════════════════
    -- GENERAL
    -- ═══════════════════════════════════════════════════════════════════════
    ['welcome'] = 'Welcome to %s!',
    ['goodbye'] = 'See you soon!',
    ['loading'] = 'Loading...',
    ['error'] = 'An error occurred',
    ['success'] = 'Success!',
    ['cancelled'] = 'Cancelled',
    ['confirm'] = 'Confirm',
    ['cancel'] = 'Cancel',
    ['yes'] = 'Yes',
    ['no'] = 'No',
    ['close'] = 'Close',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- PLAYER
    -- ═══════════════════════════════════════════════════════════════════════
    ['player_loaded'] = 'Data loaded successfully',
    ['player_saved'] = 'Data saved',
    ['player_not_found'] = 'Player not found',
    ['character_created'] = 'Character created successfully',
    ['character_deleted'] = 'Character deleted',
    ['character_select'] = 'Character Selection',
    ['character_limit'] = 'You have reached the character limit',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- MONEY
    -- ═══════════════════════════════════════════════════════════════════════
    ['money_received'] = 'You received $%s',
    ['money_removed'] = 'You lost $%s',
    ['money_set'] = 'Your money has been set to $%s',
    ['money_not_enough'] = 'You don\'t have enough money',
    ['money_bank_received'] = 'You received $%s in your bank account',
    ['money_bank_removed'] = '$%s has been withdrawn from your bank account',
    ['money_cash'] = 'Cash',
    ['money_bank'] = 'Bank',
    ['money_black'] = 'Black Money',
    ['money_transfer'] = 'Transfer completed',
    ['money_transfer_received'] = 'You received a transfer of $%s',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- JOB
    -- ═══════════════════════════════════════════════════════════════════════
    ['job_changed'] = 'You are now %s (%s)',
    ['job_not_authorized'] = 'You are not authorized to do this',
    ['job_on_duty'] = 'You are now on duty',
    ['job_off_duty'] = 'You are now off duty',
    ['job_salary_received'] = 'You received your salary: $%s',
    ['job_hired'] = 'You have been hired as %s',
    ['job_fired'] = 'You have been fired',
    ['job_promoted'] = 'You have been promoted to %s',
    ['job_demoted'] = 'You have been demoted to %s',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- INVENTORY
    -- ═══════════════════════════════════════════════════════════════════════
    ['inventory'] = 'Inventory',
    ['inventory_full'] = 'Your inventory is full',
    ['inventory_weight'] = 'Weight: %s / %s',
    ['item_received'] = 'You received %sx %s',
    ['item_removed'] = 'You lost %sx %s',
    ['item_used'] = 'You used %s',
    ['item_not_found'] = 'Item not found',
    ['item_not_enough'] = 'You don\'t have enough %s',
    ['item_dropped'] = 'You dropped %sx %s',
    ['item_picked_up'] = 'You picked up %sx %s',
    ['item_cannot_use'] = 'You cannot use this item',
    ['item_give'] = 'You gave %sx %s',
    ['item_give_received'] = 'You received %sx %s from %s',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- STATUS
    -- ═══════════════════════════════════════════════════════════════════════
    ['status_hunger'] = 'Hunger',
    ['status_thirst'] = 'Thirst',
    ['status_stress'] = 'Stress',
    ['status_health'] = 'Health',
    ['status_armor'] = 'Armor',
    ['status_hungry'] = 'You are hungry!',
    ['status_thirsty'] = 'You are thirsty!',
    ['status_stressed'] = 'You are stressed!',
    ['status_dying'] = 'You are dying!',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- VEHICLES
    -- ═══════════════════════════════════════════════════════════════════════
    ['vehicle'] = 'Vehicle',
    ['vehicle_spawned'] = 'Vehicle retrieved from garage',
    ['vehicle_stored'] = 'Vehicle stored',
    ['vehicle_not_owned'] = 'This vehicle doesn\'t belong to you',
    ['vehicle_no_keys'] = 'You don\'t have the keys',
    ['vehicle_locked'] = 'Vehicle locked',
    ['vehicle_unlocked'] = 'Vehicle unlocked',
    ['vehicle_impounded'] = 'Your vehicle has been impounded',
    ['vehicle_insurance'] = 'Vehicle Insurance',
    ['vehicle_no_insurance'] = 'This vehicle is not insured',
    ['vehicle_repaired'] = 'Vehicle repaired',
    ['vehicle_no_garage'] = 'No garage nearby',
    ['vehicle_already_out'] = 'This vehicle is already out',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- ADMIN
    -- ═══════════════════════════════════════════════════════════════════════
    ['admin_no_permission'] = 'You don\'t have permission',
    ['admin_player_teleported'] = 'Player teleported',
    ['admin_player_healed'] = 'Player healed',
    ['admin_player_revived'] = 'Player revived',
    ['admin_player_kicked'] = 'Player kicked',
    ['admin_player_banned'] = 'Player banned',
    ['admin_player_unbanned'] = 'Player unbanned',
    ['admin_money_given'] = 'Money given',
    ['admin_money_removed'] = 'Money removed',
    ['admin_item_given'] = 'Item given',
    ['admin_item_removed'] = 'Item removed',
    ['admin_job_set'] = 'Job set',
    ['admin_vehicle_spawned'] = 'Vehicle spawned',
    ['admin_vehicle_deleted'] = 'Vehicle deleted',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- SECURITY
    -- ═══════════════════════════════════════════════════════════════════════
    ['security_banned'] = 'You are banned from this server',
    ['security_ban_reason'] = 'Reason: %s',
    ['security_ban_expire'] = 'Expires: %s',
    ['security_ban_permanent'] = 'Permanent ban',
    ['security_kicked'] = 'You have been kicked',
    ['security_kick_reason'] = 'Reason: %s',
    ['security_rate_limit'] = 'Too many requests, please wait',
    ['security_suspicious'] = 'Suspicious activity detected',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- UI / NOTIFICATIONS
    -- ═══════════════════════════════════════════════════════════════════════
    ['notify_info'] = 'Information',
    ['notify_success'] = 'Success',
    ['notify_warning'] = 'Warning',
    ['notify_error'] = 'Error',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- COMMANDS
    -- ═══════════════════════════════════════════════════════════════════════
    ['cmd_help'] = 'Display help',
    ['cmd_me'] = 'RP Action',
    ['cmd_do'] = 'RP Description',
    ['cmd_ooc'] = 'Out of character message'
}
