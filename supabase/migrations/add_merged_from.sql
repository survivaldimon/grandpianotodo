-- Миграция: Поле merged_from для хранения ID объединённых учеников
-- Дата: 2026-01-06
-- Описание:
--   Добавляет поле merged_from UUID[] в таблицу students
--   Хранит ID учеников, которые были объединены в эту карточку

ALTER TABLE students ADD COLUMN IF NOT EXISTS merged_from UUID[] DEFAULT NULL;

COMMENT ON COLUMN students.merged_from IS 'Массив ID учеников, из которых была создана эта карточка при объединении';
