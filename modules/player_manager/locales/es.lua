--[[
    vAvA_player_manager - Locales ES
    Traducción española
]]

Locales = Locales or {}

Locales['es'] = {
    -- Selector
    ['selector_title'] = 'Selección de personaje',
    ['create_character'] = 'Crear personaje',
    ['delete_character'] = 'Eliminar',
    ['play_character'] = 'Jugar',
    ['confirm_delete'] = '¿Estás seguro de eliminar este personaje?',
    ['last_played'] = 'Última conexión',
    ['playtime'] = 'Tiempo de juego',
    ['job'] = 'Trabajo',
    ['no_characters'] = 'Sin personajes',
    ['create_first'] = 'Crea tu primer personaje',
    ['max_characters'] = 'Personajes: %s/%s',
    
    -- Creation
    ['creation_title'] = 'Creación de personaje',
    ['firstname'] = 'Nombre',
    ['lastname'] = 'Apellido',
    ['dateofbirth'] = 'Fecha de nacimiento',
    ['sex'] = 'Sexo',
    ['male'] = 'Hombre',
    ['female'] = 'Mujer',
    ['nationality'] = 'Nacionalidad',
    ['story'] = 'Historia',
    ['background'] = 'Tu profesión antes de Los Santos',
    ['reason'] = '¿Por qué viniste a Los Santos?',
    ['goal'] = '¿Cuál es tu objetivo principal?',
    ['create_btn'] = 'Crear',
    ['cancel_btn'] = 'Cancelar',
    ['required_field'] = 'Campo obligatorio',
    ['invalid_dob'] = 'Fecha de nacimiento inválida',
    ['too_young'] = 'Edad mínima: %s años',
    ['too_old'] = 'Edad máxima: %s años',
    
    -- ID Card
    ['id_card'] = 'Tarjeta de identidad',
    ['show_id'] = 'Mostrar ID',
    ['citizen_id'] = 'ID Ciudadano',
    ['phone_number'] = 'Teléfono',
    ['issued_date'] = 'Fecha de emisión',
    ['valid_until'] = 'Válido hasta',
    ['id_shown_to'] = 'Mostraste tu ID a %s',
    ['id_shown_by'] = '%s te muestra su tarjeta de identidad',
    
    -- Licenses
    ['licenses'] = 'Licencias',
    ['no_licenses'] = 'Sin licencias',
    ['obtain_license'] = 'Obtener',
    ['license_valid'] = 'Válida',
    ['license_expired'] = 'Caducada',
    ['license_suspended'] = 'Suspendida',
    ['exam_required'] = 'Examen requerido',
    ['go_to_exam'] = 'Ir a examen',
    ['cost'] = 'Costo',
    ['validity'] = 'Validez',
    ['days'] = 'días',
    ['unlimited'] = 'Ilimitado',
    ['driver_license'] = 'Licencia de conducir',
    ['weapon_license'] = 'Licencia de armas',
    ['business_license'] = 'Licencia comercial',
    ['hunting_license'] = 'Licencia de caza',
    ['fishing_license'] = 'Licencia de pesca',
    ['pilot_license'] = 'Licencia de piloto',
    ['boat_license'] = 'Licencia de barco',
    
    -- Stats
    ['statistics'] = 'Estadísticas',
    ['playtime_hours'] = 'Tiempo de juego (horas)',
    ['distance_walked_km'] = 'Distancia caminada (km)',
    ['distance_driven_km'] = 'Distancia en vehículo (km)',
    ['total_deaths'] = 'Muertes totales',
    ['total_arrests'] = 'Arrestos',
    ['jobs_completed'] = 'Misiones completadas',
    ['money_earned'] = 'Dinero ganado',
    ['money_spent'] = 'Dinero gastado',
    
    -- History
    ['history'] = 'Historial',
    ['event_type'] = 'Tipo',
    ['event_date'] = 'Fecha',
    ['event_amount'] = 'Cantidad',
    ['no_history'] = 'Sin historial',
    ['load_more'] = 'Cargar más',
    
    -- Events
    ['character_login'] = 'Conexión',
    ['character_logout'] = 'Desconexión',
    ['job_change'] = 'Cambio de trabajo',
    ['name_change'] = 'Cambio de nombre',
    ['bank_deposit'] = 'Depósito bancario',
    ['bank_withdraw'] = 'Retiro bancario',
    ['bank_transfer'] = 'Transferencia',
    ['property_buy'] = 'Compra propiedad',
    ['property_sell'] = 'Venta propiedad',
    ['vehicle_buy'] = 'Compra vehículo',
    ['vehicle_sell'] = 'Venta vehículo',
    ['arrest'] = 'Arresto',
    ['fine'] = 'Multa',
    ['jail'] = 'Prisión',
    ['death'] = 'Muerte',
    ['revive'] = 'Reanimación',
    ['license_obtained'] = 'Licencia obtenida',
    ['license_revoked'] = 'Licencia revocada',
    ['license_suspended'] = 'Licencia suspendida',
    
    -- Notifications
    ['character_created'] = '¡Personaje creado con éxito!',
    ['character_deleted'] = 'Personaje eliminado',
    ['character_selected'] = 'Bienvenido %s %s',
    ['license_obtained_msg'] = 'Obtuviste: %s',
    ['license_revoked_msg'] = 'Tu licencia %s ha sido revocada',
    ['license_expired_msg'] = 'Tu licencia %s ha caducado',
    ['insufficient_funds'] = 'Fondos insuficientes',
    ['exam_required_msg'] = 'Debes aprobar un examen para esta licencia',
    
    -- Errors
    ['error_occurred'] = 'Ocurrió un error',
    ['character_not_found'] = 'Personaje no encontrado',
    ['access_denied'] = 'Acceso denegado',
    ['license_not_found'] = 'Licencia no encontrada',
    ['max_chars_reached'] = 'Límite de personajes alcanzado',
    
    -- Commands
    ['cmd_characters'] = 'Abrir selector de personajes',
    ['cmd_deletechar'] = 'Eliminar personaje',
    ['cmd_resetchar'] = 'Reiniciar personaje',
    ['cmd_givelicense'] = 'Dar licencia',
    ['cmd_revokelicense'] = 'Revocar licencia',
    ['cmd_showid'] = 'Mostrar tarjeta ID',
    ['cmd_checkid'] = 'Ver tarjeta ID',
    ['cmd_showlicenses'] = 'Ver mis licencias',
    ['cmd_stats'] = 'Ver estadísticas'
}

return Locales['es']
