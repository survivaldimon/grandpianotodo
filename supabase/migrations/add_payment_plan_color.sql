-- Добавление поля color в таблицу payment_plans
-- Миграция: add_payment_plan_color.sql

ALTER TABLE payment_plans
ADD COLUMN IF NOT EXISTS color TEXT;

COMMENT ON COLUMN payment_plans.color IS 'Цвет тарифа в формате hex (например: 4CAF50)';
