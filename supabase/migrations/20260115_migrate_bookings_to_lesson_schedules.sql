-- Миграция данных: bookings → lesson_schedules
-- Дата: 2026-01-15
-- Описание:
--   Переносит еженедельные бронирования учеников из таблицы bookings
--   в новую таблицу lesson_schedules.
--   Оригинальные записи bookings НЕ удаляются (они архивируются).
--   Эта миграция идемпотентна — повторный запуск не создаст дубликатов.

-- ============================================================================
-- 1. МИГРАЦИЯ WEEKLY BOOKINGS С УЧЕНИКОМ В LESSON_SCHEDULES
-- ============================================================================

-- Вставляем записи только если они ещё не существуют
-- Используем проверку на уникальность по комбинации полей
INSERT INTO lesson_schedules (
  institution_id,
  room_id,
  teacher_id,
  student_id,
  group_id,
  subject_id,
  lesson_type_id,
  day_of_week,
  start_time,
  end_time,
  valid_from,
  valid_until,
  is_paused,
  pause_until,
  replacement_room_id,
  replacement_until,
  created_by,
  created_at,
  archived_at
)
SELECT
  b.institution_id,
  br.room_id,
  b.teacher_id,
  b.student_id,
  NULL AS group_id,  -- Групповые занятия мигрируются отдельно
  b.subject_id,
  b.lesson_type_id,
  b.day_of_week,
  b.start_time,
  b.end_time,
  b.valid_from,
  b.valid_until,
  b.is_paused,
  b.pause_until,
  b.replacement_room_id,
  b.replacement_until,
  b.created_by,
  b.created_at,
  b.archived_at
FROM bookings b
JOIN booking_rooms br ON br.booking_id = b.id
WHERE b.recurrence_type = 'weekly'
  AND b.student_id IS NOT NULL
  AND NOT EXISTS (
    -- Проверяем, что такая запись ещё не существует
    SELECT 1 FROM lesson_schedules ls
    WHERE ls.institution_id = b.institution_id
      AND ls.room_id = br.room_id
      AND ls.teacher_id = b.teacher_id
      AND ls.student_id = b.student_id
      AND ls.day_of_week = b.day_of_week
      AND ls.start_time = b.start_time
      AND ls.end_time = b.end_time
  );

-- ============================================================================
-- 2. МИГРАЦИЯ ИСКЛЮЧЕНИЙ (BOOKING_EXCEPTIONS → LESSON_SCHEDULE_EXCEPTIONS)
-- ============================================================================

-- Сначала создаём временную таблицу для маппинга booking_id → schedule_id
CREATE TEMP TABLE IF NOT EXISTS booking_to_schedule_map AS
SELECT
  b.id AS booking_id,
  ls.id AS schedule_id
FROM bookings b
JOIN booking_rooms br ON br.booking_id = b.id
JOIN lesson_schedules ls ON
  ls.institution_id = b.institution_id
  AND ls.room_id = br.room_id
  AND ls.teacher_id = b.teacher_id
  AND ls.student_id = b.student_id
  AND ls.day_of_week = b.day_of_week
  AND ls.start_time = b.start_time
  AND ls.end_time = b.end_time
WHERE b.recurrence_type = 'weekly'
  AND b.student_id IS NOT NULL;

-- Вставляем исключения
INSERT INTO lesson_schedule_exceptions (schedule_id, exception_date, reason, created_at)
SELECT
  m.schedule_id,
  be.exception_date,
  be.reason,
  be.created_at
FROM booking_exceptions be
JOIN booking_to_schedule_map m ON m.booking_id = be.booking_id
WHERE NOT EXISTS (
  SELECT 1 FROM lesson_schedule_exceptions lse
  WHERE lse.schedule_id = m.schedule_id
    AND lse.exception_date = be.exception_date
);

-- Удаляем временную таблицу
DROP TABLE IF EXISTS booking_to_schedule_map;

-- ============================================================================
-- 3. АРХИВАЦИЯ МИГРИРОВАННЫХ BOOKINGS
-- ============================================================================

-- Опционально: архивируем мигрированные бронирования
-- Раскомментировать после проверки, что миграция прошла успешно
/*
UPDATE bookings b
SET archived_at = NOW()
WHERE b.recurrence_type = 'weekly'
  AND b.student_id IS NOT NULL
  AND b.archived_at IS NULL
  AND EXISTS (
    SELECT 1 FROM lesson_schedules ls
    JOIN booking_rooms br ON br.booking_id = b.id
    WHERE ls.institution_id = b.institution_id
      AND ls.room_id = br.room_id
      AND ls.teacher_id = b.teacher_id
      AND ls.student_id = b.student_id
      AND ls.day_of_week = b.day_of_week
      AND ls.start_time = b.start_time
      AND ls.end_time = b.end_time
  );
*/

-- ============================================================================
-- 4. СТАТИСТИКА МИГРАЦИИ
-- ============================================================================

-- Показываем результаты миграции
DO $$
DECLARE
  v_schedules_count INTEGER;
  v_exceptions_count INTEGER;
  v_bookings_to_migrate INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_schedules_count FROM lesson_schedules;
  SELECT COUNT(*) INTO v_exceptions_count FROM lesson_schedule_exceptions;
  SELECT COUNT(*) INTO v_bookings_to_migrate
  FROM bookings b
  JOIN booking_rooms br ON br.booking_id = b.id
  WHERE b.recurrence_type = 'weekly'
    AND b.student_id IS NOT NULL
    AND b.archived_at IS NULL;

  RAISE NOTICE '=== Результаты миграции ===';
  RAISE NOTICE 'Создано lesson_schedules: %', v_schedules_count;
  RAISE NOTICE 'Создано исключений: %', v_exceptions_count;
  RAISE NOTICE 'Осталось bookings для архивации: %', v_bookings_to_migrate;
END $$;
