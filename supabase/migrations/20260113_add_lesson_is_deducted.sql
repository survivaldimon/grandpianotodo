-- Миграция: Добавление поля is_deducted для занятий
-- Дата: 2026-01-13
-- Описание: Отслеживание списания занятия с баланса при отмене

-- Добавить поле is_deducted в таблицу lessons
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS is_deducted BOOLEAN DEFAULT FALSE;

-- Комментарий к полю
COMMENT ON COLUMN lessons.is_deducted IS 'TRUE если занятие было списано с баланса при отмене';
