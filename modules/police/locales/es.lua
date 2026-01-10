--[[
    vAvA_police - Traducción Española
]]

Locale = Locale or {}

Locale['es'] = {
    -- General
    ['police'] = 'Policía',
    ['open_menu'] = 'Presiona ~INPUT_CONTEXT~ para abrir el menú',
    ['no_players_nearby'] = 'No hay jugadores cerca',
    ['player_not_online'] = 'El jugador ya no está en línea',
    ['action_cancelled'] = 'Acción cancelada',
    
    -- Menú de interacción
    ['citizen_interaction'] = 'Interacción con Ciudadano',
    ['handcuff'] = 'Esposar / Desamarrar',
    ['search'] = 'Cachear',
    ['escort'] = 'Escoltar',
    ['put_in_vehicle'] = 'Meter en vehículo',
    ['remove_from_vehicle'] = 'Sacar del vehículo',
    ['fine'] = 'Dar multa',
    ['jail'] = 'Enviar a prisión',
    ['identity_check'] = 'Control de identidad',
    ['check_licenses'] = 'Verificar licencias',
    ['confiscate_items'] = 'Confiscar objetos',
    
    -- Esposas
    ['handcuffed'] = 'Estás esposado(a)',
    ['unhandcuffed'] = 'Te han quitado las esposas',
    ['handcuffed_target'] = 'Has esposado a ~y~%s~s~',
    ['unhandcuffed_target'] = 'Has quitado las esposas a ~y~%s~s~',
    
    -- Cacheo
    ['search_in_progress'] = 'Cacheo en progreso...',
    ['searched_target'] = 'Has cacheado a ~y~%s~s~',
    ['being_searched'] = 'Te están cacheando',
    ['found_items'] = 'Objetos encontrados: %s',
    ['no_items_found'] = 'No se encontraron objetos',
    ['illegal_items_confiscated'] = 'Objetos ilegales confiscados: %s',
    
    -- Escolta
    ['escorting'] = 'Estás escoltando a ~y~%s~s~',
    ['being_escorted'] = 'Te están escoltando',
    ['escort_stopped'] = 'Escolta detenida',
    
    -- Vehículo
    ['put_in_vehicle_success'] = 'Ciudadano metido en el vehículo',
    ['remove_from_vehicle_success'] = 'Ciudadano sacado del vehículo',
    ['no_vehicle_nearby'] = 'No hay vehículo cerca',
    ['vehicle_full'] = 'El vehículo está lleno',
    
    -- Multas
    ['fine_issued'] = 'Multa emitida: ~g~$%s~s~ por ~y~%s~s~',
    ['fine_received'] = 'Has recibido una multa de ~r~$%s~s~\nMotivo: ~y~%s~s~',
    ['fine_paid'] = 'Multa pagada: ~g~$%s~s~',
    ['fine_not_enough_money'] = 'No tienes suficiente dinero',
    ['select_fine_type'] = 'Seleccionar tipo de multa',
    ['traffic_violations'] = 'Infracciones de tráfico',
    ['admin_violations'] = 'Infracciones administrativas',
    ['criminal_violations'] = 'Infracciones penales',
    ['custom_fine'] = 'Multa personalizada',
    ['enter_custom_amount'] = 'Ingresa el monto de la multa',
    ['enter_fine_reason'] = 'Ingresa el motivo de la multa',
    
    -- Prisión
    ['jail_time'] = 'Tiempo de prisión: ~y~%s~s~ minutos',
    ['sent_to_jail'] = 'Has enviado a ~y~%s~s~ a prisión por ~r~%s~s~ minutos',
    ['jailed'] = 'Has sido encarcelado(a) por ~r~%s~s~ minutos\nMotivo: ~y~%s~s~',
    ['time_remaining'] = 'Tiempo restante: ~r~%s~s~ minutos',
    ['released_from_jail'] = 'Has sido liberado(a) de prisión',
    ['work_to_reduce'] = 'Trabaja para reducir tu condena',
    ['work_point'] = 'Presiona ~INPUT_CONTEXT~ para trabajar',
    ['working'] = 'Trabajando... (~y~-%s~s~ segundos)',
    ['time_reduced'] = 'Tiempo reducido en ~g~%s~s~ minutos',
    ['enter_jail_time'] = 'Ingresa tiempo de prisión (minutos)',
    ['enter_jail_reason'] = 'Ingresa motivo del encarcelamiento',
    
    -- Antecedentes penales
    ['criminal_record'] = 'Antecedentes Penales',
    ['no_criminal_record'] = 'Sin antecedentes',
    ['record_added'] = 'Registro añadido a los antecedentes',
    ['view_record'] = 'Ver antecedentes',
    ['offense'] = 'Delito',
    ['fine_amount'] = 'Monto multa',
    ['jail_time_served'] = 'Tiempo prisión',
    ['date'] = 'Fecha',
    ['officer'] = 'Oficial',
    
    -- Tableta
    ['tablet'] = 'Tableta Policial',
    ['open_tablet'] = 'Abrir tableta',
    ['search_person'] = 'Buscar persona',
    ['search_vehicle'] = 'Buscar vehículo',
    ['search_plate'] = 'Buscar por matrícula',
    ['recent_alerts'] = 'Alertas recientes',
    ['active_units'] = 'Unidades activas',
    ['enter_name'] = 'Ingresa nombre',
    ['enter_plate'] = 'Ingresa matrícula',
    ['person_info'] = 'Información Persona',
    ['vehicle_info'] = 'Información Vehículo',
    ['no_results'] = 'Sin resultados',
    ['name'] = 'Nombre',
    ['dob'] = 'Fecha de nacimiento',
    ['gender'] = 'Género',
    ['phone'] = 'Teléfono',
    ['job'] = 'Trabajo',
    ['owner'] = 'Propietario',
    ['model'] = 'Modelo',
    ['plate'] = 'Matrícula',
    ['color'] = 'Color',
    
    -- Vestuario
    ['cloakroom'] = 'Vestuario',
    ['civilian_outfit'] = 'Ropa civil',
    ['police_outfit'] = 'Uniforme policial',
    ['outfit_changed'] = 'Ropa cambiada',
    
    -- Armería
    ['armory'] = 'Armería',
    ['take_weapon'] = 'Tomar arma',
    ['deposit_weapon'] = 'Depositar arma',
    ['weapon_taken'] = 'Arma tomada: ~y~%s~s~',
    ['weapon_deposited'] = 'Arma depositada: ~y~%s~s~',
    ['insufficient_grade'] = 'Rango insuficiente',
    ['ammo'] = 'Municiones',
    ['ammo_taken'] = 'Municiones tomadas: ~y~%s~s~',
    
    -- Garaje
    ['vehicle_garage'] = 'Garaje Policial',
    ['spawn_vehicle'] = 'Sacar vehículo',
    ['store_vehicle'] = 'Guardar vehículo',
    ['vehicle_spawned'] = 'Vehículo sacado: ~y~%s~s~',
    ['vehicle_stored'] = 'Vehículo guardado',
    ['no_vehicle_nearby_to_store'] = 'No hay vehículo cerca',
    ['spawn_point_blocked'] = 'Punto de spawn bloqueado',
    
    -- Radar
    ['radar_on'] = 'Radar ~g~ACTIVADO~s~',
    ['radar_off'] = 'Radar ~r~DESACTIVADO~s~',
    ['radar_speed'] = 'Velocidad detectada: ~y~%s~s~ km/h',
    ['radar_limit'] = 'Límite: ~y~%s~s~ km/h',
    ['radar_speeding'] = '~r~EXCESO DE VELOCIDAD~s~',
    ['radar_target'] = 'Vehículo: ~y~%s~s~',
    ['radar_no_target'] = 'Ningún vehículo detectado',
    
    -- Dispatch / Alertas
    ['dispatch_alert'] = 'ALERTA DISPATCH',
    ['alert_code'] = 'Código',
    ['alert_location'] = 'Ubicación',
    ['alert_set_waypoint'] = 'Presiona ~INPUT_CONTEXT~ para GPS',
    ['alert_respond'] = 'Presiona ~INPUT_PICKUP~ para responder',
    ['alert_responded'] = 'Alerta atendida por ~y~%s~s~',
    ['backup_requested'] = 'REFUERZO SOLICITADO por ~y~%s~s~',
    ['request_backup'] = 'Solicitar refuerzo',
    ['backup_sent'] = 'Solicitud de refuerzo enviada',
    
    -- Servicio
    ['on_duty'] = 'Ahora estás ~g~en servicio~s~',
    ['off_duty'] = 'Ahora estás ~r~fuera de servicio~s~',
    ['duty_toggle'] = 'Entrar/Salir de servicio',
    
    -- Permisos
    ['no_permission'] = 'Sin permisos',
    ['insufficient_rank'] = 'Rango insuficiente',
    
    -- Varios
    ['press_to_interact'] = 'Presiona ~INPUT_CONTEXT~ para interactuar',
    ['cancelled'] = 'Cancelado',
    ['confirm'] = 'Confirmar',
    ['cancel'] = 'Cancelar',
    ['yes'] = 'Sí',
    ['no'] = 'No',
    ['close'] = 'Cerrar',
    ['back'] = 'Atrás',
    ['submit'] = 'Enviar'
}
