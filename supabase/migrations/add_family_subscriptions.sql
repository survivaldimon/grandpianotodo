-- Миграция для семейных абонементов
-- Выполните этот SQL в Supabase SQL Editor

-- 1. Добавляем флаг семейного абонемента в subscriptions
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS is_family BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Создаём таблицу участников семейного абонемента
CREATE TABLE IF NOT EXISTS subscription_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Уникальная комбинация: один ученик не может быть дважды в одном абонементе
  UNIQUE(subscription_id, student_id)
);

-- 3. Индексы
CREATE INDEX IF NOT EXISTS idx_subscription_members_subscription ON subscription_members(subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscription_members_student ON subscription_members(student_id);

-- 4. RLS Policies для subscription_members
ALTER TABLE subscription_members ENABLE ROW LEVEL SECURITY;

-- Политика чтения: участники заведения могут видеть членов подписок
CREATE POLICY "Members can view subscription_members" ON subscription_members
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM subscriptions s
      JOIN institution_members im ON im.institution_id = s.institution_id
      WHERE s.id = subscription_members.subscription_id
        AND im.user_id = auth.uid()
        AND im.archived_at IS NULL
    )
  );

-- Политика создания
CREATE POLICY "Members can create subscription_members" ON subscription_members
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM subscriptions s
      JOIN institution_members im ON im.institution_id = s.institution_id
      WHERE s.id = subscription_members.subscription_id
        AND im.user_id = auth.uid()
        AND im.archived_at IS NULL
    )
  );

-- Политика удаления
CREATE POLICY "Members can delete subscription_members" ON subscription_members
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM subscriptions s
      JOIN institution_members im ON im.institution_id = s.institution_id
      WHERE s.id = subscription_members.subscription_id
        AND im.user_id = auth.uid()
        AND im.archived_at IS NULL
    )
  );

-- 5. Миграция существующих данных: заполняем subscription_members для индивидуальных подписок
INSERT INTO subscription_members (subscription_id, student_id)
SELECT id, student_id FROM subscriptions
WHERE student_id IS NOT NULL
ON CONFLICT (subscription_id, student_id) DO NOTHING;

-- 6. Обновляем функцию получения активного баланса (учитываем семейные подписки)
CREATE OR REPLACE FUNCTION get_student_active_balance(p_student_id UUID)
RETURNS INT AS $$
DECLARE
  total_balance INT;
BEGIN
  SELECT COALESCE(SUM(sub.lessons_remaining), 0)
  INTO total_balance
  FROM subscriptions sub
  WHERE sub.lessons_remaining > 0
    AND (
      -- Не истёк срок
      sub.expires_at >= CURRENT_DATE
      -- Или заморожен (срок не идёт)
      OR sub.is_frozen = TRUE
    )
    AND (
      -- Личная подписка
      (sub.is_family = FALSE AND sub.student_id = p_student_id)
      -- Или семейная подписка через subscription_members
      OR (sub.is_family = TRUE AND EXISTS (
        SELECT 1 FROM subscription_members sm
        WHERE sm.subscription_id = sub.id
          AND sm.student_id = p_student_id
      ))
    );

  RETURN total_balance;
END;
$$ LANGUAGE plpgsql;

-- 7. Обновляем функцию списания занятия (учитываем семейные подписки)
CREATE OR REPLACE FUNCTION deduct_lesson_from_subscription(p_student_id UUID)
RETURNS UUID AS $$ -- Возвращает ID подписки с которой списали
DECLARE
  sub_id UUID;
BEGIN
  -- Сначала ищем личную подписку (приоритет)
  SELECT id INTO sub_id
  FROM subscriptions
  WHERE student_id = p_student_id
    AND is_family = FALSE
    AND lessons_remaining > 0
    AND expires_at >= CURRENT_DATE
    AND is_frozen = FALSE
  ORDER BY expires_at ASC, created_at ASC
  LIMIT 1
  FOR UPDATE;

  -- Если не нашли личную - ищем семейную
  IF sub_id IS NULL THEN
    SELECT s.id INTO sub_id
    FROM subscriptions s
    JOIN subscription_members sm ON sm.subscription_id = s.id
    WHERE sm.student_id = p_student_id
      AND s.is_family = TRUE
      AND s.lessons_remaining > 0
      AND s.expires_at >= CURRENT_DATE
      AND s.is_frozen = FALSE
    ORDER BY s.expires_at ASC, s.created_at ASC
    LIMIT 1
    FOR UPDATE;
  END IF;

  IF sub_id IS NOT NULL THEN
    UPDATE subscriptions
    SET lessons_remaining = lessons_remaining - 1
    WHERE id = sub_id;
  END IF;

  RETURN sub_id;
END;
$$ LANGUAGE plpgsql;

-- 8. Обновляем View для сводки по ученику (учитываем семейные подписки)
DROP VIEW IF EXISTS student_subscription_summary;

CREATE VIEW student_subscription_summary AS
SELECT
  s.id as student_id,
  s.institution_id,
  s.name as student_name,
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
  ) as active_balance,
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
  COALESCE(
    (
      SELECT BOOL_OR(sub.is_frozen)
      FROM subscriptions sub
      LEFT JOIN subscription_members sm ON sm.subscription_id = sub.id AND sub.is_family = TRUE
      WHERE (sub.is_family = FALSE AND sub.student_id = s.id)
        OR (sub.is_family = TRUE AND sm.student_id = s.id)
    ), FALSE
  ) as has_frozen_subscription
FROM students s
WHERE s.archived_at IS NULL;

-- 9. Добавляем таблицу в Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE subscription_members;

-- 10. Комментарии
COMMENT ON TABLE subscription_members IS 'Участники семейных абонементов';
COMMENT ON COLUMN subscription_members.subscription_id IS 'ID абонемента';
COMMENT ON COLUMN subscription_members.student_id IS 'ID ученика-участника';
COMMENT ON COLUMN subscriptions.is_family IS 'Семейный абонемент (несколько учеников)';
