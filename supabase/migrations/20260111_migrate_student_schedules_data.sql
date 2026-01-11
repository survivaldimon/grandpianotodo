-- Миграция данных: Перенос student_schedules в bookings
-- Дата: 2026-01-11
-- Описание: Переносит существующие постоянные расписания учеников в таблицу bookings
--           и помечает старые данные как устаревшие (deprecated)

-- ============================================
-- 0. Подготовка: убираем NOT NULL с колонки date
-- ============================================
-- Для weekly бронирований date = NULL (они повторяются по дню недели)
ALTER TABLE bookings ALTER COLUMN date DROP NOT NULL;

-- ============================================
-- 1. Перенос данных из student_schedules в bookings
-- ============================================
-- Переносим все активные и неархивированные расписания
INSERT INTO bookings (
  id,
  institution_id,
  created_by,
  date,               -- NULL для weekly
  start_time,
  end_time,
  description,
  recurrence_type,
  day_of_week,
  valid_from,
  valid_until,
  student_id,
  teacher_id,
  subject_id,
  lesson_type_id,
  is_paused,
  pause_until,
  replacement_room_id,
  replacement_until,
  last_generated_date,
  created_at,
  updated_at,
  archived_at
)
SELECT
  gen_random_uuid(),  -- Новый ID
  ss.institution_id,
  ss.created_by,
  NULL,               -- date = NULL для еженедельных
  ss.start_time,
  ss.end_time,
  NULL,               -- description
  'weekly',           -- recurrence_type
  ss.day_of_week,
  ss.valid_from,
  ss.valid_until,
  ss.student_id,
  ss.teacher_id,
  ss.subject_id,
  ss.lesson_type_id,
  ss.is_paused,
  ss.pause_until,
  ss.replacement_room_id,
  ss.replacement_until,
  NULL,               -- last_generated_date (начнём генерировать с текущей даты)
  ss.created_at,
  ss.updated_at,
  CASE WHEN ss.is_active = FALSE THEN NOW() ELSE NULL END  -- archived_at
FROM student_schedules ss
WHERE NOT EXISTS (
  -- Не дублировать если уже мигрировано (по ключевым полям)
  SELECT 1 FROM bookings b
  WHERE b.institution_id = ss.institution_id
    AND b.student_id = ss.student_id
    AND b.teacher_id = ss.teacher_id
    AND b.day_of_week = ss.day_of_week
    AND b.start_time = ss.start_time
    AND b.end_time = ss.end_time
    AND b.recurrence_type = 'weekly'
);

-- ============================================
-- 2. Создаём mapping старых ID на новые для связей
-- ============================================
-- Временная таблица для маппинга
CREATE TEMP TABLE schedule_booking_mapping AS
SELECT
  ss.id AS schedule_id,
  b.id AS booking_id
FROM student_schedules ss
JOIN bookings b ON
  b.institution_id = ss.institution_id
  AND b.student_id = ss.student_id
  AND b.teacher_id = ss.teacher_id
  AND b.day_of_week = ss.day_of_week
  AND b.start_time = ss.start_time
  AND b.end_time = ss.end_time
  AND b.recurrence_type = 'weekly';

-- ============================================
-- 3. Перенос связей с кабинетами в booking_rooms
-- ============================================
INSERT INTO booking_rooms (booking_id, room_id)
SELECT
  sbm.booking_id,
  ss.room_id
FROM student_schedules ss
JOIN schedule_booking_mapping sbm ON sbm.schedule_id = ss.id
WHERE ss.room_id IS NOT NULL
  AND NOT EXISTS (
    -- Не дублировать если связь уже есть
    SELECT 1 FROM booking_rooms br
    WHERE br.booking_id = sbm.booking_id
      AND br.room_id = ss.room_id
  );

-- ============================================
-- 4. Перенос исключений из schedule_exceptions в booking_exceptions
-- ============================================
INSERT INTO booking_exceptions (
  id,
  booking_id,
  exception_date,
  reason,
  created_at,
  created_by
)
SELECT
  gen_random_uuid(),
  sbm.booking_id,
  se.exception_date,
  se.reason,
  se.created_at,
  se.created_by
FROM schedule_exceptions se
JOIN schedule_booking_mapping sbm ON sbm.schedule_id = se.schedule_id
WHERE NOT EXISTS (
  -- Не дублировать если исключение уже есть
  SELECT 1 FROM booking_exceptions be
  WHERE be.booking_id = sbm.booking_id
    AND be.exception_date = se.exception_date
);

-- Удаляем временную таблицу
DROP TABLE IF EXISTS schedule_booking_mapping;

-- ============================================
-- 5. Добавляем колонку для пометки миграции в student_schedules
-- ============================================
ALTER TABLE student_schedules
ADD COLUMN IF NOT EXISTS migrated_to_bookings BOOLEAN DEFAULT FALSE;

-- Помечаем все мигрированные записи
UPDATE student_schedules
SET migrated_to_bookings = TRUE
WHERE EXISTS (
  SELECT 1 FROM bookings b
  WHERE b.institution_id = student_schedules.institution_id
    AND b.student_id = student_schedules.student_id
    AND b.teacher_id = student_schedules.teacher_id
    AND b.day_of_week = student_schedules.day_of_week
    AND b.start_time = student_schedules.start_time
    AND b.end_time = student_schedules.end_time
    AND b.recurrence_type = 'weekly'
);

-- ============================================
-- 6. Добавляем колонку archived_at в student_schedules (если отсутствует)
-- ============================================
ALTER TABLE student_schedules
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

-- Помечаем неактивные как архивированные
UPDATE student_schedules
SET archived_at = NOW()
WHERE is_active = FALSE
  AND archived_at IS NULL;

-- ============================================
-- 7. Логирование результатов миграции
-- ============================================
DO $$
DECLARE
  migrated_schedules_count INTEGER;
  migrated_exceptions_count INTEGER;
  migrated_rooms_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO migrated_schedules_count
  FROM student_schedules WHERE migrated_to_bookings = TRUE;

  SELECT COUNT(*) INTO migrated_exceptions_count
  FROM booking_exceptions be
  WHERE EXISTS (
    SELECT 1 FROM bookings b
    WHERE b.id = be.booking_id
      AND b.recurrence_type = 'weekly'
      AND b.student_id IS NOT NULL
  );

  SELECT COUNT(*) INTO migrated_rooms_count
  FROM booking_rooms br
  WHERE EXISTS (
    SELECT 1 FROM bookings b
    WHERE b.id = br.booking_id
      AND b.recurrence_type = 'weekly'
      AND b.student_id IS NOT NULL
  );

  RAISE NOTICE 'Миграция завершена:';
  RAISE NOTICE '  - Перенесено расписаний: %', migrated_schedules_count;
  RAISE NOTICE '  - Перенесено исключений: %', migrated_exceptions_count;
  RAISE NOTICE '  - Создано связей с кабинетами: %', migrated_rooms_count;
END $$;

-- ============================================
-- 8. Комментарии
-- ============================================
COMMENT ON COLUMN student_schedules.migrated_to_bookings IS 'Флаг миграции: TRUE = запись перенесена в таблицу bookings';
COMMENT ON COLUMN student_schedules.archived_at IS 'Дата архивации (soft delete)';
