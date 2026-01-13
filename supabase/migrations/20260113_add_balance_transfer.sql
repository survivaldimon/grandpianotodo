-- Миграция: Система остатка занятий (Balance Transfer)
-- Дата: 2026-01-13
-- Описание:
--   1. Добавляем поля is_balance_transfer и transfer_lessons_remaining в payments
--   2. RPC функция для списания с balance transfer
--   3. Обновляем VIEW student_subscription_summary с учётом transfer_balance
--   4. Миграция существующих legacy_balance в payments

-- ============================================================================
-- 1. ДОБАВЛЕНИЕ ПОЛЕЙ В ТАБЛИЦУ PAYMENTS
-- ============================================================================

-- Флаг записи "перенос баланса"
ALTER TABLE payments
ADD COLUMN IF NOT EXISTS is_balance_transfer BOOLEAN NOT NULL DEFAULT FALSE;

-- Остаток занятий для записи переноса (уменьшается при списании)
ALTER TABLE payments
ADD COLUMN IF NOT EXISTS transfer_lessons_remaining INT;

-- Индекс для быстрого поиска активных переносов
CREATE INDEX IF NOT EXISTS idx_payments_active_balance_transfers
ON payments(student_id, is_balance_transfer)
WHERE is_balance_transfer = TRUE AND transfer_lessons_remaining > 0;

-- Комментарии к полям
COMMENT ON COLUMN payments.is_balance_transfer IS 'Запись переноса баланса (остаток занятий из другой школы)';
COMMENT ON COLUMN payments.transfer_lessons_remaining IS 'Остаток занятий для этой записи (списывается при проведении)';

-- ============================================================================
-- 2. RPC ФУНКЦИЯ ДЛЯ СПИСАНИЯ С BALANCE TRANSFER
-- ============================================================================

CREATE OR REPLACE FUNCTION deduct_balance_transfer(p_student_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  transfer_id UUID;
BEGIN
  -- Находим самую старую запись переноса с остатком (FIFO)
  SELECT id INTO transfer_id
  FROM payments
  WHERE student_id = p_student_id
    AND is_balance_transfer = TRUE
    AND transfer_lessons_remaining > 0
  ORDER BY paid_at ASC
  LIMIT 1
  FOR UPDATE;

  -- Если нашли — списываем 1 занятие
  IF transfer_id IS NOT NULL THEN
    UPDATE payments
    SET transfer_lessons_remaining = transfer_lessons_remaining - 1
    WHERE id = transfer_id;
  END IF;

  RETURN transfer_id;
END;
$$;

COMMENT ON FUNCTION deduct_balance_transfer IS 'Списать 1 занятие с самого старого переноса баланса. Возвращает payment_id или NULL';

-- Права на выполнение
GRANT EXECUTE ON FUNCTION deduct_balance_transfer(UUID) TO authenticated;

-- ============================================================================
-- 3. RPC ФУНКЦИЯ ДЛЯ ВОЗВРАТА ЗАНЯТИЯ НА BALANCE TRANSFER
-- ============================================================================

CREATE OR REPLACE FUNCTION return_balance_transfer_lesson(p_payment_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE payments
  SET transfer_lessons_remaining = transfer_lessons_remaining + 1
  WHERE id = p_payment_id
    AND is_balance_transfer = TRUE;
END;
$$;

COMMENT ON FUNCTION return_balance_transfer_lesson IS 'Вернуть 1 занятие на запись переноса баланса';

GRANT EXECUTE ON FUNCTION return_balance_transfer_lesson(UUID) TO authenticated;

-- ============================================================================
-- 4. ОБНОВЛЕНИЕ VIEW student_subscription_summary
-- ============================================================================

DROP VIEW IF EXISTS student_subscription_summary;

CREATE VIEW student_subscription_summary AS
SELECT
  s.id as student_id,
  s.institution_id,
  s.name as student_name,
  s.archived_at,

  -- Баланс переносов (сумма transfer_lessons_remaining)
  COALESCE(
    (
      SELECT SUM(p.transfer_lessons_remaining)
      FROM payments p
      WHERE p.student_id = s.id
        AND p.is_balance_transfer = TRUE
        AND p.transfer_lessons_remaining > 0
    ), 0
  ) as transfer_balance,

  -- Баланс подписок (без изменений)
  COALESCE(
    (
      SELECT SUM(sub.lessons_remaining)
      FROM subscriptions sub
      LEFT JOIN subscription_members sm ON sm.subscription_id = sub.id AND sub.is_family = TRUE
      WHERE (sub.expires_at >= CURRENT_DATE OR sub.is_frozen = TRUE)
        AND (
          (sub.is_family = FALSE AND sub.student_id = s.id)
          OR (sub.is_family = TRUE AND sm.student_id = s.id)
        )
    ), 0
  ) as subscription_balance,

  -- Общий активный баланс = переносы + подписки + prepaid
  COALESCE(
    (
      SELECT SUM(p.transfer_lessons_remaining)
      FROM payments p
      WHERE p.student_id = s.id
        AND p.is_balance_transfer = TRUE
        AND p.transfer_lessons_remaining > 0
    ), 0
  ) + COALESCE(
    (
      SELECT SUM(sub.lessons_remaining)
      FROM subscriptions sub
      LEFT JOIN subscription_members sm ON sm.subscription_id = sub.id AND sub.is_family = TRUE
      WHERE (sub.expires_at >= CURRENT_DATE OR sub.is_frozen = TRUE)
        AND (
          (sub.is_family = FALSE AND sub.student_id = s.id)
          OR (sub.is_family = TRUE AND sm.student_id = s.id)
        )
    ), 0
  ) + COALESCE(s.prepaid_lessons_count, 0) as active_balance,

  -- Истёкшие подписки (без изменений)
  COALESCE(
    (
      SELECT SUM(sub.lessons_remaining)
      FROM subscriptions sub
      LEFT JOIN subscription_members sm ON sm.subscription_id = sub.id AND sub.is_family = TRUE
      WHERE sub.expires_at < CURRENT_DATE AND sub.is_frozen = FALSE
        AND (
          (sub.is_family = FALSE AND sub.student_id = s.id)
          OR (sub.is_family = TRUE AND sm.student_id = s.id)
        )
    ), 0
  ) as expired_balance,

  -- Ближайшая дата истечения (без изменений)
  (
    SELECT MIN(sub.expires_at)
    FROM subscriptions sub
    LEFT JOIN subscription_members sm ON sm.subscription_id = sub.id AND sub.is_family = TRUE
    WHERE sub.lessons_remaining > 0 AND sub.expires_at >= CURRENT_DATE
      AND (
        (sub.is_family = FALSE AND sub.student_id = s.id)
        OR (sub.is_family = TRUE AND sm.student_id = s.id)
      )
  ) as nearest_expiration,

  -- Есть ли замороженные подписки (без изменений)
  COALESCE(
    (
      SELECT BOOL_OR(sub.is_frozen)
      FROM subscriptions sub
      LEFT JOIN subscription_members sm ON sm.subscription_id = sub.id AND sub.is_family = TRUE
      WHERE (sub.is_family = FALSE AND sub.student_id = s.id)
        OR (sub.is_family = TRUE AND sm.student_id = s.id)
    ), FALSE
  ) as has_frozen_subscription,

  -- Долг (без изменений)
  CASE
    WHEN s.prepaid_lessons_count < 0 THEN ABS(s.prepaid_lessons_count)
    ELSE 0
  END as debt_lessons

FROM students s;

COMMENT ON VIEW student_subscription_summary IS 'Сводка по балансу ученика. transfer_balance - переносы, subscription_balance - подписки, active_balance - общий баланс';

-- ============================================================================
-- 5. ДОБАВЛЕНИЕ ПОЛЯ В ТАБЛИЦУ LESSONS
-- ============================================================================

-- ID записи balance_transfer с которой списано занятие
ALTER TABLE lessons
ADD COLUMN IF NOT EXISTS transfer_payment_id UUID REFERENCES payments(id);

COMMENT ON COLUMN lessons.transfer_payment_id IS 'ID записи переноса баланса, с которой списано занятие';

-- ============================================================================
-- 6. МИГРАЦИЯ СУЩЕСТВУЮЩИХ LEGACY_BALANCE В PAYMENTS
-- ============================================================================

-- Создаём записи balance_transfer для учеников с legacy_balance > 0
INSERT INTO payments (
  institution_id,
  student_id,
  amount,
  lessons_count,
  is_balance_transfer,
  transfer_lessons_remaining,
  payment_method,
  paid_at,
  recorded_by,
  comment
)
SELECT
  s.institution_id,
  s.id,
  0, -- Сумма = 0 (перенос, не оплата)
  s.legacy_balance,
  TRUE,
  s.legacy_balance,
  'cash', -- Не важно для переноса
  COALESCE(s.created_at, NOW()), -- Дата создания ученика
  (SELECT owner_id FROM institutions WHERE id = s.institution_id),
  'Миграция остатка из legacy_balance'
FROM students s
WHERE s.legacy_balance > 0;

-- Обнуляем legacy_balance (поле остаётся для совместимости, но не используется)
UPDATE students SET legacy_balance = 0 WHERE legacy_balance > 0;

-- ============================================================================
-- 7. ИСПРАВЛЕНИЕ ТРИГГЕРА handle_payment_insert
-- ============================================================================
-- Триггер не должен добавлять занятия в prepaid_lessons_count для balance_transfer записей
-- (они учитываются через transfer_lessons_remaining и VIEW)

CREATE OR REPLACE FUNCTION handle_payment_insert()
RETURNS TRIGGER AS $$
BEGIN
  -- Если оплата создаёт подписку — не добавлять в prepaid_lessons_count
  IF NEW.has_subscription = TRUE THEN
    RETURN NEW;
  END IF;

  -- Если это запись переноса баланса — не добавлять в prepaid_lessons_count
  -- (учитывается через transfer_lessons_remaining)
  IF NEW.is_balance_transfer = TRUE THEN
    RETURN NEW;
  END IF;

  -- Стандартная логика: добавить занятия в prepaid_lessons_count
  UPDATE students
  SET prepaid_lessons_count = prepaid_lessons_count + NEW.lessons_count
  WHERE id = NEW.student_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 8. ИСПРАВЛЕНИЕ ДУБЛИРОВАНИЯ БАЛАНСА У СУЩЕСТВУЮЩИХ УЧЕНИКОВ
-- ============================================================================
-- Триггер ошибочно добавил lessons_count в prepaid_lessons_count для balance_transfer записей.
-- Нужно вычесть эти занятия, чтобы они учитывались только через transfer_lessons_remaining.

UPDATE students s
SET prepaid_lessons_count = prepaid_lessons_count - COALESCE(
  (SELECT SUM(p.lessons_count)
   FROM payments p
   WHERE p.student_id = s.id
     AND p.is_balance_transfer = TRUE),
  0
)
WHERE EXISTS (
  SELECT 1 FROM payments p
  WHERE p.student_id = s.id
    AND p.is_balance_transfer = TRUE
);
