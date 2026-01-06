-- Миграция: добавление поля sort_order в таблицу rooms
-- Дата: 2026-01-06

-- 1. Добавляем поле sort_order
ALTER TABLE rooms
ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;

-- 2. Заполняем sort_order для существующих записей на основе created_at
-- Каждое заведение получит свою нумерацию: 0, 1, 2...
WITH numbered_rooms AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY institution_id
      ORDER BY created_at ASC
    ) - 1 AS new_sort_order
  FROM rooms
)
UPDATE rooms
SET sort_order = numbered_rooms.new_sort_order
FROM numbered_rooms
WHERE rooms.id = numbered_rooms.id;

-- 3. Создаём индекс для быстрой сортировки
CREATE INDEX IF NOT EXISTS idx_rooms_sort_order
ON rooms(institution_id, sort_order);
