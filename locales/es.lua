--[[
    vAvA_core - Traducciones Español
]]

Locales = Locales or {}

Locales['es'] = {
    -- ═══════════════════════════════════════════════════════════════════════
    -- GENERAL
    -- ═══════════════════════════════════════════════════════════════════════
    ['welcome'] = '¡Bienvenido a %s!',
    ['goodbye'] = '¡Hasta pronto!',
    ['loading'] = 'Cargando...',
    ['error'] = 'Ha ocurrido un error',
    ['success'] = '¡Éxito!',
    ['cancelled'] = 'Cancelado',
    ['confirm'] = 'Confirmar',
    ['cancel'] = 'Cancelar',
    ['yes'] = 'Sí',
    ['no'] = 'No',
    ['close'] = 'Cerrar',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- JUGADOR
    -- ═══════════════════════════════════════════════════════════════════════
    ['player_loaded'] = 'Datos cargados correctamente',
    ['player_saved'] = 'Datos guardados',
    ['player_not_found'] = 'Jugador no encontrado',
    ['character_created'] = 'Personaje creado correctamente',
    ['character_deleted'] = 'Personaje eliminado',
    ['character_select'] = 'Selección de personaje',
    ['character_limit'] = 'Has alcanzado el límite de personajes',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- DINERO
    -- ═══════════════════════════════════════════════════════════════════════
    ['money_received'] = 'Has recibido $%s',
    ['money_removed'] = 'Has perdido $%s',
    ['money_set'] = 'Tu dinero se ha establecido en $%s',
    ['money_not_enough'] = 'No tienes suficiente dinero',
    ['money_bank_received'] = 'Has recibido $%s en tu cuenta bancaria',
    ['money_bank_removed'] = 'Se han retirado $%s de tu cuenta bancaria',
    ['money_cash'] = 'Efectivo',
    ['money_bank'] = 'Banco',
    ['money_black'] = 'Dinero negro',
    ['money_transfer'] = 'Transferencia completada',
    ['money_transfer_received'] = 'Has recibido una transferencia de $%s',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- TRABAJO
    -- ═══════════════════════════════════════════════════════════════════════
    ['job_changed'] = 'Ahora eres %s (%s)',
    ['job_not_authorized'] = 'No estás autorizado para hacer esto',
    ['job_on_duty'] = 'Estás en servicio',
    ['job_off_duty'] = 'Ya no estás en servicio',
    ['job_salary_received'] = 'Has recibido tu salario: $%s',
    ['job_hired'] = 'Has sido contratado como %s',
    ['job_fired'] = 'Has sido despedido',
    ['job_promoted'] = 'Has sido ascendido a %s',
    ['job_demoted'] = 'Has sido degradado a %s',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- INVENTARIO
    -- ═══════════════════════════════════════════════════════════════════════
    ['inventory'] = 'Inventario',
    ['inventory_full'] = 'Tu inventario está lleno',
    ['inventory_weight'] = 'Peso: %s / %s',
    ['item_received'] = 'Has recibido %sx %s',
    ['item_removed'] = 'Has perdido %sx %s',
    ['item_used'] = 'Has usado %s',
    ['item_not_found'] = 'Objeto no encontrado',
    ['item_not_enough'] = 'No tienes suficiente %s',
    ['item_dropped'] = 'Has tirado %sx %s',
    ['item_picked_up'] = 'Has recogido %sx %s',
    ['item_cannot_use'] = 'No puedes usar este objeto',
    ['item_give'] = 'Has dado %sx %s',
    ['item_give_received'] = 'Has recibido %sx %s de %s',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- ESTADO
    -- ═══════════════════════════════════════════════════════════════════════
    ['status_hunger'] = 'Hambre',
    ['status_thirst'] = 'Sed',
    ['status_stress'] = 'Estrés',
    ['status_health'] = 'Salud',
    ['status_armor'] = 'Armadura',
    ['status_hungry'] = '¡Tienes hambre!',
    ['status_thirsty'] = '¡Tienes sed!',
    ['status_stressed'] = '¡Estás estresado!',
    ['status_dying'] = '¡Te estás muriendo!',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- VEHÍCULOS
    -- ═══════════════════════════════════════════════════════════════════════
    ['vehicle'] = 'Vehículo',
    ['vehicle_spawned'] = 'Vehículo sacado del garaje',
    ['vehicle_stored'] = 'Vehículo guardado',
    ['vehicle_not_owned'] = 'Este vehículo no te pertenece',
    ['vehicle_no_keys'] = 'No tienes las llaves',
    ['vehicle_locked'] = 'Vehículo bloqueado',
    ['vehicle_unlocked'] = 'Vehículo desbloqueado',
    ['vehicle_impounded'] = 'Tu vehículo ha sido confiscado',
    ['vehicle_insurance'] = 'Seguro del vehículo',
    ['vehicle_no_insurance'] = 'Este vehículo no tiene seguro',
    ['vehicle_repaired'] = 'Vehículo reparado',
    ['vehicle_no_garage'] = 'No hay garaje cercano',
    ['vehicle_already_out'] = 'Este vehículo ya está fuera',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- ADMIN
    -- ═══════════════════════════════════════════════════════════════════════
    ['admin_no_permission'] = 'No tienes permiso',
    ['admin_player_teleported'] = 'Jugador teletransportado',
    ['admin_player_healed'] = 'Jugador curado',
    ['admin_player_revived'] = 'Jugador reanimado',
    ['admin_player_kicked'] = 'Jugador expulsado',
    ['admin_player_banned'] = 'Jugador baneado',
    ['admin_player_unbanned'] = 'Jugador desbaneado',
    ['admin_money_given'] = 'Dinero dado',
    ['admin_money_removed'] = 'Dinero retirado',
    ['admin_item_given'] = 'Objeto dado',
    ['admin_item_removed'] = 'Objeto retirado',
    ['admin_job_set'] = 'Trabajo establecido',
    ['admin_vehicle_spawned'] = 'Vehículo spawneado',
    ['admin_vehicle_deleted'] = 'Vehículo eliminado',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- SEGURIDAD
    -- ═══════════════════════════════════════════════════════════════════════
    ['security_banned'] = 'Estás baneado de este servidor',
    ['security_ban_reason'] = 'Razón: %s',
    ['security_ban_expire'] = 'Expira: %s',
    ['security_ban_permanent'] = 'Ban permanente',
    ['security_kicked'] = 'Has sido expulsado',
    ['security_kick_reason'] = 'Razón: %s',
    ['security_rate_limit'] = 'Demasiadas solicitudes, espera un momento',
    ['security_suspicious'] = 'Actividad sospechosa detectada',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- UI / NOTIFICACIONES
    -- ═══════════════════════════════════════════════════════════════════════
    ['notify_info'] = 'Información',
    ['notify_success'] = 'Éxito',
    ['notify_warning'] = 'Advertencia',
    ['notify_error'] = 'Error',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- COMANDOS
    -- ═══════════════════════════════════════════════════════════════════════
    ['cmd_help'] = 'Mostrar ayuda',
    ['cmd_me'] = 'Acción RP',
    ['cmd_do'] = 'Descripción RP',
    ['cmd_ooc'] = 'Mensaje fuera de personaje'
}
