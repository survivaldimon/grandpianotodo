-- Миграция: Добавление флага has_subscription для оплат с подпиской
-- Дата: 2026-01-13
-- Описание: При оплате с тарифом создаётся подписка (subscription) вместо prepaid_lessons_count
--           + миграция существующих оплат с тарифами

-- =============================================================================
-- ЧАСТЬ 1: СХЕМА
-- =============================================================================

-- 1. Добавить поле has_subscription в таблицу payments
ALTER TABLE payments ADD COLUMN IF NOT EXISTS has_subscription BOOLEAN DEFAULT FALSE;

-- 2. Обновить триггер: пропускать записи с has_subscription = true
CREATE OR REPLACE FUNCTION handle_payment_insert()
RETURNS TRIGGER AS $$
BEGIN
  -- Если оплата создаёт подписку — не добавлять в prepaid_lessons_count
  -- (занятия будут учитываться через subscription.lessons_remaining)
  IF NEW.has_subscription = TRUE THEN
    RETURN NEW;
  END IF;

  -- Стандартная логика: добавить занятия в prepaid_lessons_count
  UPDATE students
  SET prepaid_lessons_count = prepaid_lessons_count + NEW.lessons_count
  WHERE id = NEW.student_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Комментарий к полю
COMMENT ON COLUMN payments.has_subscription IS 'TRUE если оплата создаёт подписку (subscription). Триггер пропускает такие записи.';

-- =============================================================================
-- ЧАСТЬ 2: МИГРАЦИЯ СУЩЕСТВУЮЩИХ ОПЛАТ С ТАРИФАМИ
-- =============================================================================

-- 3. Создаём подписки для существующих оплат с тарифами
-- (только для оплат у которых ещё нет подписки)
INSERT INTO subscriptions (
  institution_id,
  student_id,
  payment_id,
  lessons_total,
  lessons_remaining,
  starts_at,
  expires_at
)
SELECT
  p.institution_id,
  p.student_id,
  p.id as payment_id,
  p.lessons_count as lessons_total,
  -- Остаток: lessons_count минус использованные занятия (completed после даты оплаты)
  GREATEST(0, p.lessons_count - COALESCE(
    (SELECT COUNT(*) FROM lessons l
     WHERE l.student_id = p.student_id
       AND l.status = 'completed'
       AND l.date >= p.paid_at::date
       AND l.subscription_id IS NULL),
    0
  )) as lessons_remaining,
  p.paid_at::date as starts_at,
  (p.paid_at::date + COALESCE(pp.validity_days, 30)) as expires_at
FROM payments p
JOIN payment_plans pp ON pp.id = p.payment_plan_id
WHERE p.payment_plan_id IS NOT NULL
  AND p.is_correction = FALSE
  -- Пропустить оплаты у которых уже есть подписка
  AND NOT EXISTS (
    SELECT 1 FROM subscriptions s WHERE s.payment_id = p.id
  );

-- 4. Пометить эти оплаты как has_subscription = true
UPDATE payments
SET has_subscription = TRUE
WHERE payment_plan_id IS NOT NULL
  AND is_correction = FALSE
  AND EXISTS (
    SELECT 1 FROM subscriptions s WHERE s.payment_id = payments.id
  );

-- 5. Уменьшить prepaid_lessons_count у учеников (убрать двойной учёт)
-- Вычитаем lessons_count только для оплат которые были преобразованы в подписки
UPDATE students s
SET prepaid_lessons_count = GREATEST(0, prepaid_lessons_count - COALESCE(
  (SELECT SUM(p.lessons_count)
   FROM payments p
   WHERE p.student_id = s.id
     AND p.has_subscription = TRUE
     AND p.is_correction = FALSE),
  0
))
WHERE EXISTS (
  SELECT 1 FROM payments p
  WHERE p.student_id = s.id
    AND p.has_subscription = TRUE
);

-- =============================================================================
-- ПРОВЕРКА (выполните после миграции для контроля)
-- =============================================================================
-- SELECT
--   (SELECT COUNT(*) FROM payments WHERE has_subscription = TRUE) as payments_with_subscription,
--   (SELECT COUNT(*) FROM subscriptions WHERE payment_id IS NOT NULL) as subscriptions_from_payments;
