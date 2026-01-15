-- Миграция: Виртуальные занятия (Lesson Schedules)
-- Дата: 2026-01-15
-- Описание:
--   Создание системы постоянного расписания занятий.
--   Одна запись = бесконечные виртуальные занятия.
--   Реальная запись lesson создаётся только при проведении/отмене.

-- ============================================================================
-- 1. ТАБЛИЦА LESSON_SCHEDULES (ПОСТОЯННОЕ РАСПИСАНИЕ ЗАНЯТИЙ)
-- ============================================================================

CREATE TABLE IF NOT EXISTS lesson_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  student_id UUID REFERENCES students(id) ON DELETE CASCADE,
  group_id UUID REFERENCES student_groups(id) ON DELETE CASCADE,
  subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
  lesson_type_id UUID REFERENCES lesson_types(id) ON DELETE SET NULL,

  -- Расписание (ISO 8601: 1=Пн, 7=Вс)
  day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,

  -- Период действия
  valid_from DATE,           -- NULL = с момента создания
  valid_until DATE,          -- NULL = бессрочно

  -- Пауза
  is_paused BOOLEAN NOT NULL DEFAULT FALSE,
  pause_until DATE,

  -- Временная замена кабинета
  replacement_room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  replacement_until DATE,

  -- Метаданные
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,

  -- Ограничение: НЕ оба одновременно (student и group)
  -- Допускается: только student, только group, или ни то ни другое
  CONSTRAINT check_student_xor_group CHECK (
    NOT (student_id IS NOT NULL AND group_id IS NOT NULL)
  ),

  -- Ограничение: end_time > start_time
  CONSTRAINT check_time_range CHECK (end_time > start_time)
);

-- Комментарии
COMMENT ON TABLE lesson_schedules IS 'Постоянное расписание занятий. Одна запись = бесконечные виртуальные занятия.';
COMMENT ON COLUMN lesson_schedules.day_of_week IS 'День недели (ISO 8601): 1=Понедельник, 7=Воскресенье';
COMMENT ON COLUMN lesson_schedules.valid_from IS 'Дата начала действия расписания. NULL = с момента создания';
COMMENT ON COLUMN lesson_schedules.valid_until IS 'Дата окончания действия. NULL = бессрочно';
COMMENT ON COLUMN lesson_schedules.is_paused IS 'Флаг приостановки расписания';
COMMENT ON COLUMN lesson_schedules.replacement_room_id IS 'Временная замена кабинета';
COMMENT ON COLUMN lesson_schedules.replacement_until IS 'До какой даты действует замена кабинета';

-- Индексы
CREATE INDEX IF NOT EXISTS idx_lesson_schedules_institution
  ON lesson_schedules(institution_id)
  WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_lesson_schedules_student
  ON lesson_schedules(student_id)
  WHERE student_id IS NOT NULL AND archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_lesson_schedules_group
  ON lesson_schedules(group_id)
  WHERE group_id IS NOT NULL AND archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_lesson_schedules_teacher
  ON lesson_schedules(teacher_id)
  WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_lesson_schedules_day_of_week
  ON lesson_schedules(institution_id, day_of_week)
  WHERE archived_at IS NULL;

-- ============================================================================
-- 2. ТАБЛИЦА ИСКЛЮЧЕНИЙ (ПРОПУЩЕННЫЕ ДАТЫ)
-- ============================================================================

CREATE TABLE IF NOT EXISTS lesson_schedule_exceptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES lesson_schedules(id) ON DELETE CASCADE,
  exception_date DATE NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Уникальность: одна дата на расписание
  UNIQUE(schedule_id, exception_date)
);

COMMENT ON TABLE lesson_schedule_exceptions IS 'Исключения (пропущенные даты) для постоянного расписания';

CREATE INDEX IF NOT EXISTS idx_lesson_schedule_exceptions_schedule
  ON lesson_schedule_exceptions(schedule_id);

CREATE INDEX IF NOT EXISTS idx_lesson_schedule_exceptions_date
  ON lesson_schedule_exceptions(schedule_id, exception_date);

-- ============================================================================
-- 3. СВЯЗЬ С ТАБЛИЦЕЙ LESSONS
-- ============================================================================

-- Добавляем поле schedule_id в lessons для связи виртуального и реального занятия
ALTER TABLE lessons
ADD COLUMN IF NOT EXISTS schedule_id UUID REFERENCES lesson_schedules(id) ON DELETE SET NULL;

COMMENT ON COLUMN lessons.schedule_id IS 'Ссылка на постоянное расписание, из которого создано занятие';

-- Индекс для быстрого поиска занятий по расписанию и дате
CREATE INDEX IF NOT EXISTS idx_lessons_schedule_date
  ON lessons(schedule_id, date)
  WHERE schedule_id IS NOT NULL AND archived_at IS NULL;

-- ============================================================================
-- 4. RLS POLICIES
-- ============================================================================

-- Включаем RLS
ALTER TABLE lesson_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_schedule_exceptions ENABLE ROW LEVEL SECURITY;

-- Policy для lesson_schedules
CREATE POLICY "Users can view lesson_schedules of their institutions"
  ON lesson_schedules FOR SELECT
  USING (
    institution_id IN (
      SELECT institution_id FROM institution_members
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert lesson_schedules in their institutions"
  ON lesson_schedules FOR INSERT
  WITH CHECK (
    institution_id IN (
      SELECT institution_id FROM institution_members
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update lesson_schedules in their institutions"
  ON lesson_schedules FOR UPDATE
  USING (
    institution_id IN (
      SELECT institution_id FROM institution_members
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete lesson_schedules in their institutions"
  ON lesson_schedules FOR DELETE
  USING (
    institution_id IN (
      SELECT institution_id FROM institution_members
      WHERE user_id = auth.uid()
    )
  );

-- Policy для lesson_schedule_exceptions
CREATE POLICY "Users can view exceptions of their schedules"
  ON lesson_schedule_exceptions FOR SELECT
  USING (
    schedule_id IN (
      SELECT id FROM lesson_schedules
      WHERE institution_id IN (
        SELECT institution_id FROM institution_members
        WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can insert exceptions for their schedules"
  ON lesson_schedule_exceptions FOR INSERT
  WITH CHECK (
    schedule_id IN (
      SELECT id FROM lesson_schedules
      WHERE institution_id IN (
        SELECT institution_id FROM institution_members
        WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can delete exceptions from their schedules"
  ON lesson_schedule_exceptions FOR DELETE
  USING (
    schedule_id IN (
      SELECT id FROM lesson_schedules
      WHERE institution_id IN (
        SELECT institution_id FROM institution_members
        WHERE user_id = auth.uid()
      )
    )
  );

-- ============================================================================
-- 5. ФУНКЦИЯ ДЛЯ СОЗДАНИЯ LESSON ИЗ SCHEDULE
-- ============================================================================

CREATE OR REPLACE FUNCTION create_lesson_from_schedule(
  p_schedule_id UUID,
  p_date DATE,
  p_status TEXT DEFAULT 'completed'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_schedule lesson_schedules%ROWTYPE;
  v_effective_room_id UUID;
  v_lesson_id UUID;
BEGIN
  -- Получаем расписание
  SELECT * INTO v_schedule
  FROM lesson_schedules
  WHERE id = p_schedule_id AND archived_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Расписание не найдено';
  END IF;

  -- Проверяем, нет ли уже занятия на эту дату
  IF EXISTS (
    SELECT 1 FROM lessons
    WHERE schedule_id = p_schedule_id
      AND date = p_date
      AND archived_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Занятие на эту дату уже существует';
  END IF;

  -- Определяем эффективный кабинет
  IF v_schedule.replacement_room_id IS NOT NULL
     AND (v_schedule.replacement_until IS NULL OR v_schedule.replacement_until >= p_date) THEN
    v_effective_room_id := v_schedule.replacement_room_id;
  ELSE
    v_effective_room_id := v_schedule.room_id;
  END IF;

  -- Создаём занятие
  INSERT INTO lessons (
    institution_id, room_id, teacher_id, student_id, group_id,
    subject_id, lesson_type_id,
    date, start_time, end_time,
    status, schedule_id, created_by
  ) VALUES (
    v_schedule.institution_id, v_effective_room_id, v_schedule.teacher_id,
    v_schedule.student_id, v_schedule.group_id,
    v_schedule.subject_id, v_schedule.lesson_type_id,
    p_date, v_schedule.start_time, v_schedule.end_time,
    p_status::lesson_status, p_schedule_id, auth.uid()
  )
  RETURNING id INTO v_lesson_id;

  RETURN v_lesson_id;
END;
$$;

COMMENT ON FUNCTION create_lesson_from_schedule IS
  'Создаёт реальное занятие из виртуального (постоянного расписания)';

GRANT EXECUTE ON FUNCTION create_lesson_from_schedule(UUID, DATE, TEXT) TO authenticated;

-- ============================================================================
-- 6. ФУНКЦИЯ ДЛЯ ДОБАВЛЕНИЯ ИСКЛЮЧЕНИЯ
-- ============================================================================

CREATE OR REPLACE FUNCTION add_schedule_exception(
  p_schedule_id UUID,
  p_exception_date DATE,
  p_reason TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_exception_id UUID;
BEGIN
  INSERT INTO lesson_schedule_exceptions (schedule_id, exception_date, reason)
  VALUES (p_schedule_id, p_exception_date, p_reason)
  ON CONFLICT (schedule_id, exception_date) DO UPDATE
    SET reason = EXCLUDED.reason
  RETURNING id INTO v_exception_id;

  RETURN v_exception_id;
END;
$$;

COMMENT ON FUNCTION add_schedule_exception IS
  'Добавляет исключение (пропуск) для даты в постоянном расписании';

GRANT EXECUTE ON FUNCTION add_schedule_exception(UUID, DATE, TEXT) TO authenticated;
