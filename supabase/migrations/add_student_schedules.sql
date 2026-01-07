-- Миграция: Постоянное расписание ученика (Student Schedules)
-- Дата: 2026-01-07
-- Описание: Шаблоны повторяющихся слотов без привязки к абонементам.
--           Хранит день недели + время, отображается в расписании бессрочно,
--           блокирует создание занятий другими преподавателями.

-- ============================================
-- 1. Таблица student_schedules (постоянные слоты)
-- ============================================
CREATE TABLE IF NOT EXISTS student_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,

  -- Участники
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES auth.users(id),
  room_id UUID NOT NULL REFERENCES rooms(id),

  -- Предмет и тип занятия (опционально)
  subject_id UUID REFERENCES subjects(id),
  lesson_type_id UUID REFERENCES lesson_types(id),

  -- Расписание (шаблон)
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 1 AND 7), -- 1=Пн, 7=Вс
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,

  -- Состояние
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_paused BOOLEAN NOT NULL DEFAULT FALSE, -- Приостановка
  pause_until DATE, -- Дата возобновления после паузы

  -- Временная замена кабинета
  replacement_room_id UUID REFERENCES rooms(id), -- Временный кабинет
  replacement_until DATE, -- До какой даты действует замена

  -- Даты действия (опционально, для ограничения периода)
  valid_from DATE, -- NULL = без ограничения начала
  valid_until DATE, -- NULL = бессрочно

  -- Метаданные
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID NOT NULL REFERENCES auth.users(id),

  -- Проверки
  CONSTRAINT schedule_end_after_start CHECK (end_time > start_time),
  CONSTRAINT schedule_valid_period CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until >= valid_from)
);

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_student_schedules_institution ON student_schedules(institution_id);
CREATE INDEX IF NOT EXISTS idx_student_schedules_student ON student_schedules(student_id);
CREATE INDEX IF NOT EXISTS idx_student_schedules_teacher ON student_schedules(teacher_id);
CREATE INDEX IF NOT EXISTS idx_student_schedules_room ON student_schedules(room_id);
CREATE INDEX IF NOT EXISTS idx_student_schedules_day ON student_schedules(day_of_week) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_student_schedules_active ON student_schedules(institution_id, is_active) WHERE is_active = TRUE;

-- ============================================
-- 2. Таблица schedule_exceptions (исключения)
-- ============================================
-- Для указания дат, когда слот НЕ действует (отпуск, болезнь, праздники)
CREATE TABLE IF NOT EXISTS schedule_exceptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES student_schedules(id) ON DELETE CASCADE,

  -- Исключённая дата
  exception_date DATE NOT NULL,

  -- Причина (опционально)
  reason TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID NOT NULL REFERENCES auth.users(id),

  -- Уникальность: один слот не может иметь дублирующие исключения
  UNIQUE(schedule_id, exception_date)
);

CREATE INDEX IF NOT EXISTS idx_schedule_exceptions_schedule ON schedule_exceptions(schedule_id);
CREATE INDEX IF NOT EXISTS idx_schedule_exceptions_date ON schedule_exceptions(exception_date);

-- ============================================
-- 3. RLS Policies для student_schedules
-- ============================================
ALTER TABLE student_schedules ENABLE ROW LEVEL SECURITY;

-- Просмотр: все участники заведения
CREATE POLICY "Members can view student_schedules"
  ON student_schedules FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM institution_members
      WHERE institution_members.institution_id = student_schedules.institution_id
        AND institution_members.user_id = auth.uid()
        AND institution_members.archived_at IS NULL
    )
  );

-- Создание: участники с правом create_lessons или manage_students
CREATE POLICY "Can create student_schedules"
  ON student_schedules FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM institution_members
      WHERE institution_members.institution_id = student_schedules.institution_id
        AND institution_members.user_id = auth.uid()
        AND institution_members.archived_at IS NULL
        AND (
          -- Владелец или админ
          institution_members.user_id = (SELECT owner_id FROM institutions WHERE id = student_schedules.institution_id)
          OR institution_members.is_admin = true
          -- Или право create_lessons
          OR (institution_members.permissions->>'create_lessons')::boolean = true
        )
    )
    AND created_by = auth.uid()
  );

-- Обновление: создатель, владелец слота (teacher_id), или manageAllStudents
CREATE POLICY "Can update student_schedules"
  ON student_schedules FOR UPDATE
  USING (
    teacher_id = auth.uid()
    OR created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM institution_members
      WHERE institution_members.institution_id = student_schedules.institution_id
        AND institution_members.user_id = auth.uid()
        AND institution_members.archived_at IS NULL
        AND (
          institution_members.user_id = (SELECT owner_id FROM institutions WHERE id = student_schedules.institution_id)
          OR institution_members.is_admin = true
          OR (institution_members.permissions->>'manage_all_students')::boolean = true
        )
    )
  );

-- Удаление: создатель, владелец слота (teacher_id), или владелец/админ
CREATE POLICY "Can delete student_schedules"
  ON student_schedules FOR DELETE
  USING (
    teacher_id = auth.uid()
    OR created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM institution_members
      WHERE institution_members.institution_id = student_schedules.institution_id
        AND institution_members.user_id = auth.uid()
        AND institution_members.archived_at IS NULL
        AND (
          institution_members.user_id = (SELECT owner_id FROM institutions WHERE id = student_schedules.institution_id)
          OR institution_members.is_admin = true
        )
    )
  );

-- ============================================
-- 4. RLS Policies для schedule_exceptions
-- ============================================
ALTER TABLE schedule_exceptions ENABLE ROW LEVEL SECURITY;

-- Просмотр: через связь со student_schedules
CREATE POLICY "Members can view schedule_exceptions"
  ON schedule_exceptions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM student_schedules ss
      JOIN institution_members im ON im.institution_id = ss.institution_id
      WHERE ss.id = schedule_exceptions.schedule_id
        AND im.user_id = auth.uid()
        AND im.archived_at IS NULL
    )
  );

-- Создание: владелец слота или админ
CREATE POLICY "Can create schedule_exceptions"
  ON schedule_exceptions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM student_schedules ss
      WHERE ss.id = schedule_exceptions.schedule_id
        AND (
          ss.teacher_id = auth.uid()
          OR ss.created_by = auth.uid()
          OR EXISTS (
            SELECT 1 FROM institution_members im
            WHERE im.institution_id = ss.institution_id
              AND im.user_id = auth.uid()
              AND im.archived_at IS NULL
              AND (
                im.user_id = (SELECT owner_id FROM institutions WHERE id = ss.institution_id)
                OR im.is_admin = true
              )
          )
        )
    )
    AND created_by = auth.uid()
  );

-- Удаление: владелец слота или админ
CREATE POLICY "Can delete schedule_exceptions"
  ON schedule_exceptions FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM student_schedules ss
      WHERE ss.id = schedule_exceptions.schedule_id
        AND (
          ss.teacher_id = auth.uid()
          OR ss.created_by = auth.uid()
          OR EXISTS (
            SELECT 1 FROM institution_members im
            WHERE im.institution_id = ss.institution_id
              AND im.user_id = auth.uid()
              AND im.archived_at IS NULL
              AND (
                im.user_id = (SELECT owner_id FROM institutions WHERE id = ss.institution_id)
                OR im.is_admin = true
              )
          )
        )
    )
  );

-- ============================================
-- 5. Realtime
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE student_schedules;
ALTER PUBLICATION supabase_realtime ADD TABLE schedule_exceptions;

-- ============================================
-- 6. Trigger для updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_student_schedule_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_student_schedule_updated_at
  BEFORE UPDATE ON student_schedules
  FOR EACH ROW
  EXECUTE FUNCTION update_student_schedule_updated_at();

-- ============================================
-- 7. Комментарии к таблицам
-- ============================================
COMMENT ON TABLE student_schedules IS 'Постоянное расписание ученика - шаблоны повторяющихся слотов';
COMMENT ON COLUMN student_schedules.day_of_week IS 'День недели: 1=Понедельник, 7=Воскресенье (ISO 8601)';
COMMENT ON COLUMN student_schedules.is_paused IS 'Слот временно приостановлен';
COMMENT ON COLUMN student_schedules.pause_until IS 'Дата возобновления после паузы (если NULL - бессрочная пауза)';
COMMENT ON COLUMN student_schedules.replacement_room_id IS 'Временная замена кабинета';
COMMENT ON COLUMN student_schedules.replacement_until IS 'До какой даты действует замена кабинета';

COMMENT ON TABLE schedule_exceptions IS 'Исключения из постоянного расписания (даты когда слот не действует)';
COMMENT ON COLUMN schedule_exceptions.exception_date IS 'Дата когда слот НЕ действует';
COMMENT ON COLUMN schedule_exceptions.reason IS 'Причина исключения (опционально)';
