-- Миграция: Добавление legacy_balance для переносимых учеников
-- Дата: 2026-01-06
-- Описание:
--   1. Новое поле legacy_balance в таблице students
--   2. Обновление VIEW для отображения legacy_balance отдельно
--   3. Методы для работы с legacy_balance

-- 1. Добавить поле legacy_balance в таблицу students
ALTER TABLE students
ADD COLUMN IF NOT EXISTS legacy_balance INT NOT NULL DEFAULT 0;

COMMENT ON COLUMN students.legacy_balance IS 'Остаток занятий из другой школы (при переносе ученика). Списывается в первую очередь, не влияет на статистику доходов.';

-- 2. Пересоздаём VIEW с поддержкой legacy_balance
DROP VIEW IF EXISTS student_subscription_summary;

CREATE VIEW student_subscription_summary AS
SELECT
  s.id as student_id,
  s.institution_id,
  s.name as student_name,
  s.archived_at,
  s.legacy_balance,  -- Остаток из другой школы
  -- Баланс только подписок (без legacy)
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
  -- Общий баланс = legacy + подписки + prepaid (prepaid может быть отрицательным = долг)
  s.legacy_balance + COALESCE(
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
  -- Истёкшие подписки
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
FROM students s;

COMMENT ON VIEW student_subscription_summary IS 'Сводка по балансу ученика. legacy_balance - остаток из другой школы, subscription_balance - только подписки, active_balance - общий баланс.';
