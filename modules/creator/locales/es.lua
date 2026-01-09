--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                   vAvA Creator - Español                                  ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]--

Locales = Locales or {}

Locales['es'] = {
    -- General
    ['loading'] = 'Cargando...',
    ['error'] = 'Error',
    ['success'] = 'Éxito',
    ['cancel'] = 'Cancelar',
    ['confirm'] = 'Confirmar',
    ['save'] = 'Guardar',
    ['close'] = 'Cerrar',
    ['next'] = 'Siguiente',
    ['previous'] = 'Anterior',
    ['reset'] = 'Reiniciar',
    ['random'] = 'Aleatorio',
    
    -- Character Selection
    ['select_character'] = 'Selección de Personaje',
    ['new_character'] = 'Nuevo Personaje',
    ['play'] = 'Jugar',
    ['delete'] = 'Eliminar',
    ['delete_confirm'] = '¿Estás seguro de que quieres eliminar este personaje?',
    ['slot_empty'] = 'Espacio Vacío',
    ['create_character'] = 'Crear un Personaje',
    
    -- Creator - Steps
    ['step_gender'] = 'Género',
    ['step_morphology'] = 'Morfología',
    ['step_face'] = 'Rostro',
    ['step_hair'] = 'Cabello',
    ['step_skin'] = 'Piel',
    ['step_clothes'] = 'Ropa',
    ['step_identity'] = 'Identidad',
    ['step_summary'] = 'Resumen',
    
    -- Creator - Gender
    ['choose_gender'] = 'Elige el género de tu personaje',
    ['male'] = 'Masculino',
    ['female'] = 'Femenino',
    
    -- Creator - Morphology
    ['heritage'] = 'Herencia Genética',
    ['mother'] = 'Madre',
    ['father'] = 'Padre',
    ['resemblance'] = 'Parecido',
    ['skin_tone'] = 'Tono de Piel',
    
    -- Creator - Face
    ['face_features'] = 'Rasgos Faciales',
    ['nose_width'] = 'Ancho de Nariz',
    ['nose_height'] = 'Altura de Nariz',
    ['nose_length'] = 'Longitud de Nariz',
    ['nose_bridge'] = 'Puente Nasal',
    ['nose_tip'] = 'Punta de Nariz',
    ['eyebrow_height'] = 'Altura de Cejas',
    ['eyebrow_length'] = 'Longitud de Cejas',
    ['cheekbone_height'] = 'Altura de Pómulos',
    ['cheekbone_width'] = 'Ancho de Pómulos',
    ['cheek_width'] = 'Ancho de Mejillas',
    ['eye_opening'] = 'Apertura de Ojos',
    ['lip_thickness'] = 'Grosor de Labios',
    ['jaw_width'] = 'Ancho de Mandíbula',
    ['jaw_length'] = 'Longitud de Mandíbula',
    ['chin_height'] = 'Altura de Mentón',
    ['chin_length'] = 'Longitud de Mentón',
    ['chin_width'] = 'Ancho de Mentón',
    ['chin_dimple'] = 'Hoyuelo del Mentón',
    ['neck_thickness'] = 'Grosor de Cuello',
    
    -- Creator - Hair
    ['hair_style'] = 'Estilo de Cabello',
    ['hair_color'] = 'Color Principal',
    ['hair_highlight'] = 'Reflejos',
    ['beard_style'] = 'Estilo de Barba',
    ['beard_color'] = 'Color de Barba',
    ['eyebrows_style'] = 'Estilo de Cejas',
    ['eyebrows_color'] = 'Color de Cejas',
    
    -- Creator - Skin
    ['blemishes'] = 'Imperfecciones',
    ['ageing'] = 'Envejecimiento',
    ['complexion'] = 'Complexión',
    ['sun_damage'] = 'Daño Solar',
    ['moles'] = 'Lunares',
    ['makeup'] = 'Maquillaje',
    ['lipstick'] = 'Lápiz Labial',
    ['blush'] = 'Rubor',
    ['eye_color'] = 'Color de Ojos',
    ['opacity'] = 'Opacidad',
    
    -- Creator - Clothes
    ['top'] = 'Parte Superior',
    ['undershirt'] = 'Camiseta Interior',
    ['pants'] = 'Pantalones',
    ['shoes'] = 'Zapatos',
    ['texture'] = 'Textura',
    
    -- Creator - Identity
    ['firstname'] = 'Nombre',
    ['lastname'] = 'Apellido',
    ['age'] = 'Edad',
    ['nationality'] = 'Nacionalidad',
    ['story'] = 'Historia',
    ['story_placeholder'] = 'Cuenta la historia de tu personaje...',
    
    -- Nationalities
    ['nationality_american'] = 'Estadounidense',
    ['nationality_french'] = 'Francés',
    ['nationality_english'] = 'Inglés',
    ['nationality_spanish'] = 'Español',
    ['nationality_italian'] = 'Italiano',
    ['nationality_german'] = 'Alemán',
    ['nationality_mexican'] = 'Mexicano',
    ['nationality_canadian'] = 'Canadiense',
    ['nationality_other'] = 'Otro',
    
    -- Creator - Summary
    ['summary'] = 'Resumen',
    ['full_name'] = 'Nombre Completo',
    ['create_btn'] = 'CREAR PERSONAJE',
    
    -- Validation
    ['invalid_firstname'] = 'Nombre inválido',
    ['invalid_lastname'] = 'Apellido inválido',
    ['invalid_age'] = 'Edad inválida',
    ['min_characters'] = 'Mínimo %d caracteres',
    ['character_created'] = '¡Personaje creado con éxito!',
    ['character_deleted'] = 'Personaje eliminado',
    ['welcome'] = '¡Bienvenido %s!',
    
    -- Shops
    ['clothing_shop'] = 'Tienda de Ropa',
    ['barber_shop'] = 'Barbería',
    ['tattoo_shop'] = 'Estudio de Tatuajes',
    ['surgery_shop'] = 'Cirugía Estética',
    ['press_to_open'] = '[E] %s',
    
    -- Clothing Categories
    ['category_tops'] = 'Partes Superiores',
    ['category_pants'] = 'Pantalones',
    ['category_shoes'] = 'Zapatos',
    ['category_accessories'] = 'Accesorios',
    ['category_hats'] = 'Sombreros',
    ['category_glasses'] = 'Gafas',
    ['category_masks'] = 'Máscaras',
    ['category_bags'] = 'Bolsas',
    ['category_ears'] = 'Pendientes',
    ['category_watches'] = 'Relojes',
    ['category_bracelets'] = 'Pulseras',
    
    -- Shops - Actions
    ['buy'] = 'Comprar',
    ['try'] = 'Probar',
    ['price'] = 'Precio',
    ['total'] = 'Total',
    ['cash'] = 'Efectivo',
    ['bank'] = 'Banco',
    ['style'] = 'Estilo',
    ['not_enough_money'] = 'No tienes suficiente dinero',
    ['purchase_success'] = '¡Compra realizada!',
    ['purchase_failed'] = 'Compra fallida',
    
    -- Barber
    ['hair'] = 'Cabello',
    ['beard'] = 'Barba',
    ['eyebrows'] = 'Cejas',
    
    -- Surgery
    ['heritage_tab'] = 'Herencia',
    ['face_tab'] = 'Rostro',
    ['eyes_tab'] = 'Ojos',
    ['surgery_price'] = 'Precio de Cirugía'
}
