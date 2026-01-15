-- Патч: Исправление constraint для lesson_schedules
-- Позволяет создавать расписания как для учеников, так и для групп, так и без привязки

-- Удаляем старый constraint
ALTER TABLE lesson_schedules DROP CONSTRAINT IF EXISTS check_student_or_group;

-- Добавляем новый constraint: либо student, либо group, либо ни то ни другое (резервация кабинета)
-- Но НЕ оба одновременно
ALTER TABLE lesson_schedules ADD CONSTRAINT check_student_xor_group CHECK (
  NOT (student_id IS NOT NULL AND group_id IS NOT NULL)
);

COMMENT ON CONSTRAINT check_student_xor_group ON lesson_schedules IS
  'Не допускает одновременное указание student_id и group_id';
