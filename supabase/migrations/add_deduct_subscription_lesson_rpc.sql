-- Миграция: Атомарная функция списания занятия с подписки
-- Дата: 2026-01-06
-- Описание: Функция для безопасного списания занятия (предотвращает race conditions)

-- Функция атомарно уменьшает lessons_remaining и возвращает обновлённую подписку
CREATE OR REPLACE FUNCTION deduct_subscription_lesson(p_subscription_id UUID)
RETURNS subscriptions
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result subscriptions;
BEGIN
  -- Атомарное обновление: lessons_remaining = lessons_remaining - 1
  UPDATE subscriptions
  SET lessons_remaining = lessons_remaining - 1,
      updated_at = NOW()
  WHERE id = p_subscription_id
    AND lessons_remaining > 0  -- Защита от отрицательного баланса
  RETURNING * INTO result;

  RETURN result;
END;
$$;

COMMENT ON FUNCTION deduct_subscription_lesson IS 'Атомарно списывает 1 занятие с подписки. Возвращает обновлённую подписку или NULL если подписка не найдена или баланс уже 0.';

-- Аналогичная функция для возврата занятия
CREATE OR REPLACE FUNCTION return_subscription_lesson(p_subscription_id UUID)
RETURNS subscriptions
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result subscriptions;
BEGIN
  -- Атомарное обновление: lessons_remaining = lessons_remaining + 1
  -- С проверкой что не превысим lessons_total
  UPDATE subscriptions
  SET lessons_remaining = LEAST(lessons_remaining + 1, lessons_total),
      updated_at = NOW()
  WHERE id = p_subscription_id
  RETURNING * INTO result;

  RETURN result;
END;
$$;

COMMENT ON FUNCTION return_subscription_lesson IS 'Атомарно возвращает 1 занятие на подписку. Не превышает lessons_total.';

-- Атомарная функция для изменения prepaid_lessons_count студента
CREATE OR REPLACE FUNCTION decrement_student_prepaid(student_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE students
  SET prepaid_lessons_count = prepaid_lessons_count - 1,
      updated_at = NOW()
  WHERE id = student_id;
END;
$$;

CREATE OR REPLACE FUNCTION increment_student_prepaid(student_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE students
  SET prepaid_lessons_count = prepaid_lessons_count + 1,
      updated_at = NOW()
  WHERE id = student_id;
END;
$$;
