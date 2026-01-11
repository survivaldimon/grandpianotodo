-- Миграция: Объединение бронирований и постоянных занятий
-- Дата: 2026-01-11
-- Описание: Расширяет таблицу bookings для поддержки повторяющихся бронирований
--           с привязкой к ученику. Заменяет функционал student_schedules.

-- ============================================
-- 1. Расширение таблицы bookings
-- ============================================

-- Убираем NOT NULL constraint с колонки date (для weekly броней date = NULL)
ALTER TABLE bookings ALTER COLUMN date DROP NOT NULL;

-- Тип повторения (once = разовое, weekly = еженедельное)
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS recurrence_type TEXT DEFAULT 'once'
  CHECK (recurrence_type IN ('once', 'weekly'));

-- День недели для еженедельного повторения (1=Пн, 7=Вс, ISO 8601)
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS day_of_week INTEGER
  CHECK (day_of_week IS NULL OR day_of_week BETWEEN 1 AND 7);

-- Период действия
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS valid_from DATE;

ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS valid_until DATE;

-- Привязка к ученику (для постоянных занятий)
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES students(id) ON DELETE SET NULL;

ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS teacher_id UUID REFERENCES auth.users(id);

ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL;

ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS lesson_type_id UUID REFERENCES lesson_types(id) ON DELETE SET NULL;

-- Механизм паузы
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS is_paused BOOLEAN DEFAULT FALSE;

ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS pause_until DATE;

-- Временная замена кабинета
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS replacement_room_id UUID REFERENCES rooms(id) ON DELETE SET NULL;

ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS replacement_until DATE;

-- Отслеживание сгенерированных занятий
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS last_generated_date DATE;

-- Constraint: weekly требует day_of_week
-- Удаляем если существует и создаём заново
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'weekly_requires_day_of_week') THEN
    ALTER TABLE bookings DROP CONSTRAINT weekly_requires_day_of_week;
  END IF;
END $$;

ALTER TABLE bookings ADD CONSTRAINT weekly_requires_day_of_week
  CHECK (recurrence_type = 'once' OR day_of_week IS NOT NULL);

-- Constraint: valid_until >= valid_from
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'booking_valid_period') THEN
    ALTER TABLE bookings DROP CONSTRAINT booking_valid_period;
  END IF;
END $$;

ALTER TABLE bookings ADD CONSTRAINT booking_valid_period
  CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until >= valid_from);

-- Индексы для новых полей
CREATE INDEX IF NOT EXISTS idx_bookings_recurrence ON bookings(recurrence_type, day_of_week);
CREATE INDEX IF NOT EXISTS idx_bookings_student ON bookings(student_id) WHERE student_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_teacher ON bookings(teacher_id) WHERE teacher_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_weekly_active ON bookings(institution_id, day_of_week)
  WHERE recurrence_type = 'weekly' AND is_paused = FALSE;

-- ============================================
-- 2. Таблица booking_exceptions (исключения)
-- ============================================
CREATE TABLE IF NOT EXISTS booking_exceptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,

  -- Исключённая дата
  exception_date DATE NOT NULL,

  -- Причина (опционально)
  reason TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID NOT NULL REFERENCES auth.users(id),

  -- Уникальность: одна бронь не может иметь дублирующие исключения
  UNIQUE(booking_id, exception_date)
);

CREATE INDEX IF NOT EXISTS idx_booking_exceptions_booking ON booking_exceptions(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_exceptions_date ON booking_exceptions(exception_date);

-- ============================================
-- 3. Таблица booking_lessons (связь с занятиями)
-- ============================================
CREATE TABLE IF NOT EXISTS booking_lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,

  -- Дата для которой создано занятие
  generated_date DATE NOT NULL,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Уникальность: одна бронь создаёт одно занятие на дату
  UNIQUE(booking_id, generated_date)
);

CREATE INDEX IF NOT EXISTS idx_booking_lessons_booking ON booking_lessons(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_lessons_lesson ON booking_lessons(lesson_id);
CREATE INDEX IF NOT EXISTS idx_booking_lessons_date ON booking_lessons(generated_date);

-- ============================================
-- 4. RLS Policies для booking_exceptions
-- ============================================
ALTER TABLE booking_exceptions ENABLE ROW LEVEL SECURITY;

-- Просмотр: все участники заведения через связь с bookings
CREATE POLICY "Members can view booking_exceptions"
  ON booking_exceptions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM bookings b
      JOIN institution_members im ON im.institution_id = b.institution_id
      WHERE b.id = booking_exceptions.booking_id
        AND im.user_id = auth.uid()
        AND im.archived_at IS NULL
    )
  );

-- Создание: создатель брони, преподаватель (teacher_id), или админ
CREATE POLICY "Can create booking_exceptions"
  ON booking_exceptions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = booking_exceptions.booking_id
        AND (
          b.created_by = auth.uid()
          OR b.teacher_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM institution_members im
            WHERE im.institution_id = b.institution_id
              AND im.user_id = auth.uid()
              AND im.archived_at IS NULL
              AND (
                im.user_id = (SELECT owner_id FROM institutions WHERE id = b.institution_id)
                OR im.is_admin = true
              )
          )
        )
    )
    AND created_by = auth.uid()
  );

-- Удаление: создатель брони, преподаватель, или админ
CREATE POLICY "Can delete booking_exceptions"
  ON booking_exceptions FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = booking_exceptions.booking_id
        AND (
          b.created_by = auth.uid()
          OR b.teacher_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM institution_members im
            WHERE im.institution_id = b.institution_id
              AND im.user_id = auth.uid()
              AND im.archived_at IS NULL
              AND (
                im.user_id = (SELECT owner_id FROM institutions WHERE id = b.institution_id)
                OR im.is_admin = true
              )
          )
        )
    )
  );

-- ============================================
-- 5. RLS Policies для booking_lessons
-- ============================================
ALTER TABLE booking_lessons ENABLE ROW LEVEL SECURITY;

-- Просмотр: через связь с bookings
CREATE POLICY "Members can view booking_lessons"
  ON booking_lessons FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM bookings b
      JOIN institution_members im ON im.institution_id = b.institution_id
      WHERE b.id = booking_lessons.booking_id
        AND im.user_id = auth.uid()
        AND im.archived_at IS NULL
    )
  );

-- Создание/Удаление: системное (через service role или триггеры)
-- Обычные пользователи не могут напрямую управлять этой таблицей
CREATE POLICY "Service can manage booking_lessons"
  ON booking_lessons FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = booking_lessons.booking_id
        AND (
          b.created_by = auth.uid()
          OR b.teacher_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM institution_members im
            WHERE im.institution_id = b.institution_id
              AND im.user_id = auth.uid()
              AND im.archived_at IS NULL
              AND (
                im.user_id = (SELECT owner_id FROM institutions WHERE id = b.institution_id)
                OR im.is_admin = true
              )
          )
        )
    )
  );

-- ============================================
-- 6. Realtime для новых таблиц
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE booking_exceptions;
ALTER PUBLICATION supabase_realtime ADD TABLE booking_lessons;

-- ============================================
-- 7. Комментарии
-- ============================================
COMMENT ON COLUMN bookings.recurrence_type IS 'Тип повторения: once = разовое, weekly = еженедельное';
COMMENT ON COLUMN bookings.day_of_week IS 'День недели для еженедельного повторения (1=Пн, 7=Вс, ISO 8601)';
COMMENT ON COLUMN bookings.student_id IS 'Ученик для постоянного расписания (NULL для простых броней)';
COMMENT ON COLUMN bookings.teacher_id IS 'Преподаватель для постоянного расписания';
COMMENT ON COLUMN bookings.is_paused IS 'Бронь временно приостановлена';
COMMENT ON COLUMN bookings.pause_until IS 'Дата возобновления после паузы';
COMMENT ON COLUMN bookings.replacement_room_id IS 'Временная замена кабинета';
COMMENT ON COLUMN bookings.replacement_until IS 'До какой даты действует замена кабинета';
COMMENT ON COLUMN bookings.last_generated_date IS 'Дата последнего автоматически сгенерированного занятия';

COMMENT ON TABLE booking_exceptions IS 'Исключения из повторяющегося бронирования (даты когда бронь не действует)';
COMMENT ON TABLE booking_lessons IS 'Связь бронирований с автоматически созданными занятиями';

-- ============================================
-- 8. Функция генерации занятий из weekly bookings
-- ============================================
CREATE OR REPLACE FUNCTION generate_lessons_from_weekly_bookings()
RETURNS TABLE(booking_id UUID, lesson_id UUID, success BOOLEAN, error_message TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  booking RECORD;
  new_lesson_id UUID;
  effective_room_id UUID;
  today_date DATE := CURRENT_DATE;
  current_dow INTEGER := EXTRACT(ISODOW FROM CURRENT_DATE);
BEGIN
  FOR booking IN
    SELECT b.*, br.room_id as primary_room_id
    FROM bookings b
    LEFT JOIN booking_rooms br ON br.booking_id = b.id
    WHERE b.recurrence_type = 'weekly'
      AND b.day_of_week = current_dow
      AND b.student_id IS NOT NULL
      AND COALESCE(b.is_paused, FALSE) = FALSE
      AND COALESCE(b.archived_at, '9999-12-31'::timestamptz) > NOW()
      AND (b.valid_from IS NULL OR b.valid_from <= today_date)
      AND (b.valid_until IS NULL OR b.valid_until >= today_date)
      AND (b.last_generated_date IS NULL OR b.last_generated_date < today_date)
      -- Проверка что нет исключения на сегодня
      AND NOT EXISTS (
        SELECT 1 FROM booking_exceptions be
        WHERE be.booking_id = b.id AND be.exception_date = today_date
      )
      -- Проверка что занятие ещё не создано
      AND NOT EXISTS (
        SELECT 1 FROM booking_lessons bl
        WHERE bl.booking_id = b.id AND bl.generated_date = today_date
      )
  LOOP
    BEGIN
      -- Определяем эффективный кабинет (с учётом замены)
      IF booking.replacement_room_id IS NOT NULL
         AND booking.replacement_until IS NOT NULL
         AND booking.replacement_until >= today_date THEN
        effective_room_id := booking.replacement_room_id;
      ELSE
        effective_room_id := booking.primary_room_id;
      END IF;

      -- Пропускаем если нет кабинета
      IF effective_room_id IS NULL THEN
        booking_id := booking.id;
        lesson_id := NULL;
        success := FALSE;
        error_message := 'No room assigned';
        RETURN NEXT;
        CONTINUE;
      END IF;

      -- Создаём занятие
      INSERT INTO lessons (
        institution_id, room_id, teacher_id, student_id,
        subject_id, lesson_type_id, date, start_time, end_time,
        status, created_by
      ) VALUES (
        booking.institution_id, effective_room_id, booking.teacher_id,
        booking.student_id, booking.subject_id, booking.lesson_type_id,
        today_date, booking.start_time, booking.end_time,
        'scheduled', booking.created_by
      ) RETURNING id INTO new_lesson_id;

      -- Записываем связь
      INSERT INTO booking_lessons (booking_id, lesson_id, generated_date)
      VALUES (booking.id, new_lesson_id, today_date);

      -- Обновляем отслеживание
      UPDATE bookings
      SET last_generated_date = today_date
      WHERE id = booking.id;

      -- Возвращаем успех
      booking_id := booking.id;
      lesson_id := new_lesson_id;
      success := TRUE;
      error_message := NULL;
      RETURN NEXT;

    EXCEPTION WHEN OTHERS THEN
      booking_id := booking.id;
      lesson_id := NULL;
      success := FALSE;
      error_message := SQLERRM;
      RETURN NEXT;
    END;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION generate_lessons_from_weekly_bookings() IS
  'Генерирует занятия из еженедельных бронирований для текущей даты. Вызывается при открытии расписания или через cron.';
