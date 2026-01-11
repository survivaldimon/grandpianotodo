-- Добавить поле для хранения кабинетов по умолчанию для участника
-- null = не настроено (показать промпт)
-- [] = пропущено (показывать все кабинеты)
-- ['id1', 'id2'] = выбранные кабинеты

ALTER TABLE institution_members
ADD COLUMN IF NOT EXISTS default_room_ids JSONB DEFAULT NULL;

COMMENT ON COLUMN institution_members.default_room_ids IS
'Кабинеты по умолчанию: null = не настроено, [] = все, [...] = выбранные ID';
