-- ═══════════════════════════════════════════════════════════════════════════
-- Migration des personnages de vava_characters vers characters
-- ═══════════════════════════════════════════════════════════════════════════

-- Migrer les personnages existants
INSERT INTO characters (
    identifier,
    firstname,
    lastname,
    dob,
    gender,
    money,
    job,
    gang,
    position,
    status,
    inventory,
    metadata,
    created_at,
    last_played
)
SELECT 
    license as identifier,
    firstname,
    lastname,
    CONCAT(DAY(FROM_UNIXTIME(birthdate/1000)), '/', MONTH(FROM_UNIXTIME(birthdate/1000)), '/', YEAR(FROM_UNIXTIME(birthdate/1000))) as dob,
    gender,
    COALESCE(money, '{"cash":5000,"bank":10000,"black_money":0}') as money,
    COALESCE(job, '{"name":"unemployed","grade":0}') as job,
    '{"name":"none","grade":0}' as gang,
    COALESCE(position, '{"x":-269.4,"y":-955.3,"z":31.2,"heading":205.0}') as position,
    '{"hunger":100,"thirst":100,"stress":0}' as status,
    COALESCE(inventory, '[]') as inventory,
    COALESCE(metadata, '{}') as metadata,
    FROM_UNIXTIME(created_at/1000) as created_at,
    FROM_UNIXTIME(last_played/1000) as last_played
FROM vava_characters
WHERE is_deleted = 0
ON DUPLICATE KEY UPDATE
    firstname = VALUES(firstname),
    lastname = VALUES(lastname),
    last_played = VALUES(last_played);

-- Vérification
SELECT COUNT(*) as 'Personnages migrés' FROM characters;
