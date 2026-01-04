-- Добавление цвета для участников заведения (преподавателей)
-- Цвет используется для отображения занятий в расписании

ALTER TABLE institution_members
ADD COLUMN IF NOT EXISTS color TEXT;

COMMENT ON COLUMN institution_members.color IS 'Hex color code for schedule display (e.g. 4CAF50)';
