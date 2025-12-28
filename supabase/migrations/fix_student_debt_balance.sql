-- Миграция: Исправление расчёта баланса с учётом долга
-- Дата: 2025-12-28
-- Описание: Баланс теперь учитывает prepaid_lessons_count (может быть отрицательным)

-- Обновляем VIEW для учёта долга (prepaid_lessons_count может быть < 0)
DROP VIEW IF EXISTS student_subscription_summary;

CREATE VIEW student_subscription_summary AS
SELECT
  s.id as student_id,
  s.institution_id,
  s.name as student_name,
  -- Общий баланс = подписки + prepaid (prepaid может быть отрицательным = долг)
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
  -- Ближайшая дата истечения
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
  -- Есть ли замороженные подписки
  COALESCE(
    (
      SELECT BOOL_OR(sub.is_frozen)
      FROM subscriptions sub
      LEFT JOIN subscription_members sm ON sm.subscription_id = sub.id AND sub.is_family = TRUE
      WHERE (sub.is_family = FALSE AND sub.student_id = s.id)
        OR (sub.is_family = TRUE AND sm.student_id = s.id)
    ), FALSE
  ) as has_frozen_subscription,
  -- Отдельно долг (если prepaid_lessons_count < 0)
  CASE
    WHEN s.prepaid_lessons_count < 0 THEN ABS(s.prepaid_lessons_count)
    ELSE 0
  END as debt_lessons
FROM students s
WHERE s.archived_at IS NULL;

-- Комментарий
COMMENT ON VIEW student_subscription_summary IS 'Сводка по балансу ученика. active_balance включает подписки + prepaid (может быть отрицательным при долге)';
