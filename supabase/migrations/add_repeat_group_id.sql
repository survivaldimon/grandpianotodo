-- Добавление поддержки повторяющихся занятий
-- Выполните этот SQL в Supabase SQL Editor

-- Добавляем колонку repeat_group_id для связи повторяющихся занятий
ALTER TABLE lessons
ADD COLUMN IF NOT EXISTS repeat_group_id UUID NULL;

-- Создаём индекс для быстрого поиска по repeat_group_id
CREATE INDEX IF NOT EXISTS idx_lessons_repeat_group_id
ON lessons(repeat_group_id)
WHERE repeat_group_id IS NOT NULL;

-- Комментарий к колонке
COMMENT ON COLUMN lessons.repeat_group_id IS 'UUID группы повторяющихся занятий. Все занятия с одинаковым repeat_group_id являются частью одной серии.';
