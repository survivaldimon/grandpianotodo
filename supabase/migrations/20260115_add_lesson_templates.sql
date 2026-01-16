-- Миграция: Шаблоны повторяющихся занятий (Lesson Templates)
-- Дата: 2026-01-15
-- Описание:
--   1. Добавляем поле is_lesson_template в таблицу bookings
--   2. Шаблоны отображаются как занятия, при проведении создаётся реальная запись в lessons

-- ============================================================================
-- 1. ДОБАВЛЕНИЕ ПОЛЯ is_lesson_template
-- ============================================================================

ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS is_lesson_template BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN bookings.is_lesson_template IS
  'Если true - бронь отображается как занятие (шаблон). При проведении создаётся реальная запись в lessons';

-- Индекс для быстрой фильтрации шаблонов
CREATE INDEX IF NOT EXISTS idx_bookings_lesson_templates
  ON bookings(institution_id, is_lesson_template)
  WHERE is_lesson_template = TRUE AND archived_at IS NULL;

-- ============================================================================
-- 2. RPC ФУНКЦИЯ ДЛЯ ПРОВЕРКИ КОНФЛИКТОВ ПРИ МАССОВОМ СОЗДАНИИ
-- ============================================================================

CREATE OR REPLACE FUNCTION check_schedule_conflicts(
  p_student_id UUID,
  p_start_date DATE,
  p_end_date DATE
)
RETURNS TABLE(
  conflict_date DATE,
  booking_id UUID,
  room_id UUID,
  start_time TIME,
  end_time TIME
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking RECORD;
  v_current_date DATE;
  v_effective_room_id UUID;
BEGIN
  -- Перебираем все weekly брони ученика
  FOR v_booking IN
    SELECT b.*, br.room_id as primary_room_id
    FROM bookings b
    LEFT JOIN booking_rooms br ON br.booking_id = b.id
    WHERE b.student_id = p_student_id
      AND b.recurrence_type = 'weekly'
      AND COALESCE(b.is_paused, FALSE) = FALSE
      AND b.archived_at IS NULL
  LOOP
    -- Генерируем даты от p_start_date до p_end_date
    v_current_date := p_start_date;
    WHILE v_current_date <= p_end_date LOOP
      -- Проверяем день недели
      IF EXTRACT(ISODOW FROM v_current_date) = v_booking.day_of_week THEN
        -- Проверяем период действия
        IF (v_booking.valid_from IS NULL OR v_current_date >= v_booking.valid_from)
           AND (v_booking.valid_until IS NULL OR v_current_date <= v_booking.valid_until) THEN

          -- Определяем эффективный кабинет (с учётом временной замены)
          IF v_booking.replacement_room_id IS NOT NULL
             AND (v_booking.replacement_until IS NULL OR v_booking.replacement_until >= v_current_date) THEN
            v_effective_room_id := v_booking.replacement_room_id;
          ELSE
            v_effective_room_id := v_booking.primary_room_id;
          END IF;

          -- Проверяем конфликт с существующими занятиями
          IF EXISTS (
            SELECT 1 FROM lessons l
            WHERE l.room_id = v_effective_room_id
              AND l.date = v_current_date
              AND l.start_time < v_booking.end_time
              AND l.end_time > v_booking.start_time
              AND l.archived_at IS NULL
              AND l.status != 'cancelled'
          ) THEN
            -- Возвращаем конфликт
            conflict_date := v_current_date;
            booking_id := v_booking.id;
            room_id := v_effective_room_id;
            start_time := v_booking.start_time;
            end_time := v_booking.end_time;
            RETURN NEXT;
          END IF;
        END IF;
      END IF;
      v_current_date := v_current_date + 1;
    END LOOP;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION check_schedule_conflicts IS
  'Проверяет конфликты расписания ученика с существующими занятиями в указанном периоде';

GRANT EXECUTE ON FUNCTION check_schedule_conflicts(UUID, DATE, DATE) TO authenticated;

-- ============================================================================
-- 3. RPC ФУНКЦИЯ ДЛЯ МАССОВОГО СОЗДАНИЯ ЗАНЯТИЙ ИЗ РАСПИСАНИЯ
-- ============================================================================

CREATE OR REPLACE FUNCTION create_lessons_from_schedule(
  p_student_id UUID,
  p_start_date DATE,
  p_end_date DATE,
  p_skip_conflicts BOOLEAN DEFAULT TRUE
)
RETURNS TABLE(
  success_count INT,
  skipped_count INT,
  conflict_dates DATE[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking RECORD;
  v_current_date DATE;
  v_success INT := 0;
  v_skipped INT := 0;
  v_conflict_dates DATE[] := '{}';
  v_effective_room_id UUID;
  v_has_conflict BOOLEAN;
  v_created_by UUID;
BEGIN
  -- Получаем created_by из первой брони
  SELECT created_by INTO v_created_by
  FROM bookings
  WHERE student_id = p_student_id AND recurrence_type = 'weekly'
  LIMIT 1;

  IF v_created_by IS NULL THEN
    v_created_by := auth.uid();
  END IF;

  -- Перебираем все weekly брони ученика
  FOR v_booking IN
    SELECT b.*, br.room_id as primary_room_id
    FROM bookings b
    LEFT JOIN booking_rooms br ON br.booking_id = b.id
    WHERE b.student_id = p_student_id
      AND b.recurrence_type = 'weekly'
      AND COALESCE(b.is_paused, FALSE) = FALSE
      AND b.archived_at IS NULL
  LOOP
    -- Генерируем даты
    v_current_date := p_start_date;
    WHILE v_current_date <= p_end_date LOOP
      -- Проверяем день недели
      IF EXTRACT(ISODOW FROM v_current_date) = v_booking.day_of_week THEN
        -- Проверяем период действия
        IF (v_booking.valid_from IS NULL OR v_current_date >= v_booking.valid_from)
           AND (v_booking.valid_until IS NULL OR v_current_date <= v_booking.valid_until) THEN

          -- Проверяем исключения
          IF NOT EXISTS (
            SELECT 1 FROM booking_exceptions be
            WHERE be.booking_id = v_booking.id
              AND be.exception_date = v_current_date
          ) THEN
            -- Определяем эффективный кабинет
            IF v_booking.replacement_room_id IS NOT NULL
               AND (v_booking.replacement_until IS NULL OR v_booking.replacement_until >= v_current_date) THEN
              v_effective_room_id := v_booking.replacement_room_id;
            ELSE
              v_effective_room_id := v_booking.primary_room_id;
            END IF;

            -- Проверяем конфликт с существующими занятиями
            SELECT EXISTS (
              SELECT 1 FROM lessons l
              WHERE l.room_id = v_effective_room_id
                AND l.date = v_current_date
                AND l.start_time < v_booking.end_time
                AND l.end_time > v_booking.start_time
                AND l.archived_at IS NULL
                AND l.status != 'cancelled'
            ) INTO v_has_conflict;

            IF v_has_conflict THEN
              v_skipped := v_skipped + 1;
              v_conflict_dates := array_append(v_conflict_dates, v_current_date);
            ELSE
              -- Создаём занятие
              INSERT INTO lessons (
                institution_id, room_id, teacher_id, student_id,
                subject_id, lesson_type_id, date, start_time, end_time,
                status, created_by
              ) VALUES (
                v_booking.institution_id, v_effective_room_id,
                v_booking.teacher_id, v_booking.student_id,
                v_booking.subject_id, v_booking.lesson_type_id,
                v_current_date, v_booking.start_time, v_booking.end_time,
                'scheduled', v_created_by
              );
              v_success := v_success + 1;
            END IF;
          END IF;
        END IF;
      END IF;
      v_current_date := v_current_date + 1;
    END LOOP;
  END LOOP;

  success_count := v_success;
  skipped_count := v_skipped;
  conflict_dates := v_conflict_dates;
  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION create_lessons_from_schedule IS
  'Создаёт занятия из расписания ученика на указанный период. Возвращает количество созданных и пропущенных';

GRANT EXECUTE ON FUNCTION create_lessons_from_schedule(UUID, DATE, DATE, BOOLEAN) TO authenticated;
