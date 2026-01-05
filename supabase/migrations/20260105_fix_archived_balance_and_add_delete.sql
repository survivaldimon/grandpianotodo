-- Миграция: Исправление баланса для архивированных + полное удаление
-- Дата: 2026-01-05
-- Описание:
--   1. VIEW теперь показывает баланс для архивированных учеников
--   2. Функция для полного удаления ученика со всеми данными

-- 1. Пересоздаём VIEW без фильтра archived_at
DROP VIEW IF EXISTS student_subscription_summary;

CREATE VIEW student_subscription_summary AS
SELECT
  s.id as student_id,
  s.institution_id,
  s.name as student_name,
  s.archived_at,  -- Добавляем поле для возможности фильтрации в запросе
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
-- БЕЗ фильтра archived_at - показываем всех!

COMMENT ON VIEW student_subscription_summary IS 'Сводка по балансу ученика (включая архивированных). active_balance включает подписки + prepaid (может быть отрицательным при долге)';

-- 2. Функция для полного удаления ученика со всеми данными
CREATE OR REPLACE FUNCTION delete_student_completely(p_student_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Удаляем историю занятий (сначала, т.к. зависит от lessons)
  DELETE FROM lesson_history
  WHERE lesson_id IN (
    SELECT id FROM lessons WHERE student_id = p_student_id
  );

  -- Удаляем занятия ученика
  DELETE FROM lessons WHERE student_id = p_student_id;

  -- Удаляем участие в семейных подписках
  DELETE FROM subscription_members WHERE student_id = p_student_id;

  -- Удаляем личные подписки ученика
  DELETE FROM subscriptions WHERE student_id = p_student_id;

  -- Удаляем оплаты ученика
  DELETE FROM payments WHERE student_id = p_student_id;

  -- Удаляем связи с предметами
  DELETE FROM student_subjects WHERE student_id = p_student_id;

  -- Удаляем связи с преподавателями
  DELETE FROM student_teachers WHERE student_id = p_student_id;

  -- Удаляем из групп
  DELETE FROM student_group_members WHERE student_id = p_student_id;

  -- Удаляем самого ученика
  DELETE FROM students WHERE id = p_student_id;
END;
$$;

COMMENT ON FUNCTION delete_student_completely IS 'Полностью удаляет ученика и все связанные данные (занятия, оплаты, подписки)';
