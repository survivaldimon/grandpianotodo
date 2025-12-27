-- Миграция: Добавление рабочего времени заведения
-- Описание: Добавляет колонки work_start_hour и work_end_hour для настройки рабочего времени,
-- которое отображается в сетке расписания

-- Добавляем колонки рабочего времени
ALTER TABLE institutions
ADD COLUMN IF NOT EXISTS work_start_hour INTEGER DEFAULT 8,
ADD COLUMN IF NOT EXISTS work_end_hour INTEGER DEFAULT 22;

-- Добавляем ограничения на допустимые значения
ALTER TABLE institutions
ADD CONSTRAINT check_work_start_hour CHECK (work_start_hour >= 0 AND work_start_hour <= 23),
ADD CONSTRAINT check_work_end_hour CHECK (work_end_hour >= 1 AND work_end_hour <= 24),
ADD CONSTRAINT check_work_hours_order CHECK (work_end_hour > work_start_hour);

-- Комментарии к колонкам
COMMENT ON COLUMN institutions.work_start_hour IS 'Начало рабочего времени (час, 0-23). По умолчанию 8.';
COMMENT ON COLUMN institutions.work_end_hour IS 'Конец рабочего времени (час, 1-24). По умолчанию 22.';

-- Добавляем таблицу institutions в Realtime для синхронизации рабочего времени между участниками
ALTER PUBLICATION supabase_realtime ADD TABLE institutions;
