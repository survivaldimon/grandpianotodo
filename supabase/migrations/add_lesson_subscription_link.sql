-- Добавление связи занятия с подпиской для расчёта средней стоимости
-- Выполните этот SQL в Supabase SQL Editor

-- 1. Добавляем колонку subscription_id в таблицу lessons
ALTER TABLE lessons
ADD COLUMN IF NOT EXISTS subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL;

-- 2. Создаём индекс для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_lessons_subscription_id ON lessons(subscription_id)
WHERE subscription_id IS NOT NULL;

-- 3. Функция для привязки долговых занятий к новой подписке
CREATE OR REPLACE FUNCTION link_debt_lessons_to_subscription(
  p_student_id UUID,
  p_subscription_id UUID,
  p_lessons_count INT
)
RETURNS INT AS $$ -- Возвращает количество привязанных занятий
DECLARE
  linked_count INT := 0;
  lesson_record RECORD;
BEGIN
  -- Находим долговые занятия (без subscription_id, статус completed)
  -- Сортируем по дате, чтобы привязать сначала старые
  FOR lesson_record IN
    SELECT id
    FROM lessons
    WHERE student_id = p_student_id
      AND subscription_id IS NULL
      AND status = 'completed'
      AND archived_at IS NULL
    ORDER BY date ASC, start_time ASC
    LIMIT p_lessons_count
  LOOP
    UPDATE lessons
    SET subscription_id = p_subscription_id
    WHERE id = lesson_record.id;

    linked_count := linked_count + 1;
  END LOOP;

  RETURN linked_count;
END;
$$ LANGUAGE plpgsql;

-- 4. Функция для расчёта средней стоимости занятия ученика
CREATE OR REPLACE FUNCTION get_student_avg_lesson_cost(p_student_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  avg_cost NUMERIC;
BEGIN
  SELECT
    CASE
      WHEN SUM(p.lessons_count) > 0
      THEN SUM(p.amount) / SUM(p.lessons_count)
      ELSE 0
    END
  INTO avg_cost
  FROM payments p
  WHERE p.student_id = p_student_id
    AND p.lessons_count > 0;

  RETURN COALESCE(avg_cost, 0);
END;
$$ LANGUAGE plpgsql;

-- 5. Функция для расчёта стоимости конкретного занятия
CREATE OR REPLACE FUNCTION get_lesson_cost(p_lesson_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  lesson_cost NUMERIC := 0;
  sub_id UUID;
  payment_record RECORD;
BEGIN
  -- Получаем subscription_id занятия
  SELECT subscription_id INTO sub_id
  FROM lessons
  WHERE id = p_lesson_id;

  -- Если занятие привязано к подписке
  IF sub_id IS NOT NULL THEN
    -- Находим оплату связанную с подпиской
    SELECT p.amount, p.lessons_count
    INTO payment_record
    FROM payments p
    JOIN subscriptions s ON s.payment_id = p.id
    WHERE s.id = sub_id;

    IF payment_record IS NOT NULL AND payment_record.lessons_count > 0 THEN
      lesson_cost := payment_record.amount / payment_record.lessons_count;
    END IF;
  END IF;

  RETURN lesson_cost;
END;
$$ LANGUAGE plpgsql;

-- 6. Комментарии
COMMENT ON COLUMN lessons.subscription_id IS 'ID подписки, с которой списано это занятие (для расчёта стоимости)';
COMMENT ON FUNCTION link_debt_lessons_to_subscription IS 'Привязывает долговые занятия к новой подписке (вызывается при создании подписки)';
COMMENT ON FUNCTION get_student_avg_lesson_cost IS 'Возвращает среднюю стоимость занятия ученика';
COMMENT ON FUNCTION get_lesson_cost IS 'Возвращает стоимость конкретного занятия на основе подписки';
