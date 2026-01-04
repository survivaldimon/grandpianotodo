-- Миграция: Добавление способа оплаты (наличные/карта)
-- Дата: 2026-01-04

-- Добавляем колонку payment_method с дефолтным значением 'cash' (наличные)
-- Для обратной совместимости все существующие записи получат 'cash'
ALTER TABLE payments
ADD COLUMN IF NOT EXISTS payment_method TEXT NOT NULL DEFAULT 'cash';

-- Добавляем CHECK constraint для валидации значений
ALTER TABLE payments
ADD CONSTRAINT check_payment_method CHECK (payment_method IN ('cash', 'card'));

-- Комментарий для документации
COMMENT ON COLUMN payments.payment_method IS 'Способ оплаты: cash (наличные) или card (карта)';

-- Создаём индекс для быстрой фильтрации по способу оплаты
CREATE INDEX IF NOT EXISTS idx_payments_payment_method ON payments(payment_method);
