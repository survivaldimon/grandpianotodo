-- Fix: cast p_status to lesson_status enum type
-- Fixes error: column "status" is of type lesson_status but expression is of type text

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
