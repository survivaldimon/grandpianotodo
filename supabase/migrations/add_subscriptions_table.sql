-- Создание таблицы подписок (абонементов)
-- Выполните этот SQL в Supabase SQL Editor

-- 1. Создаём таблицу подписок
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  payment_id UUID REFERENCES payments(id) ON DELETE SET NULL,

  -- Занятия
  lessons_total INT NOT NULL CHECK (lessons_total > 0),
  lessons_remaining INT NOT NULL DEFAULT 0,

  -- Сроки действия
  starts_at DATE NOT NULL DEFAULT CURRENT_DATE,
  expires_at DATE NOT NULL,

  -- Заморозка
  is_frozen BOOLEAN NOT NULL DEFAULT FALSE,
  frozen_until DATE,
  frozen_days_total INT NOT NULL DEFAULT 0,

  -- Метаданные
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT lessons_remaining_valid CHECK (lessons_remaining >= 0 AND lessons_remaining <= lessons_total),
  CONSTRAINT expires_after_starts CHECK (expires_at >= starts_at),
  CONSTRAINT frozen_until_valid CHECK (
    (is_frozen = FALSE AND frozen_until IS NULL) OR
    (is_frozen = TRUE AND frozen_until IS NOT NULL AND frozen_until > CURRENT_DATE)
  )
);

-- 2. Индексы
CREATE INDEX IF NOT EXISTS idx_subscriptions_student_id ON subscriptions(student_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_institution_id ON subscriptions(institution_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_expires_at ON subscriptions(expires_at) WHERE lessons_remaining > 0;
CREATE INDEX IF NOT EXISTS idx_subscriptions_is_frozen ON subscriptions(is_frozen) WHERE is_frozen = TRUE;

-- 3. RLS Policies
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Политика чтения: участники заведения могут видеть подписки
CREATE POLICY "Members can view subscriptions" ON subscriptions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM institution_members
      WHERE institution_members.institution_id = subscriptions.institution_id
        AND institution_members.user_id = auth.uid()
        AND institution_members.archived_at IS NULL
    )
  );

-- Политика создания: участники заведения могут создавать подписки
CREATE POLICY "Members can create subscriptions" ON subscriptions
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM institution_members
      WHERE institution_members.institution_id = subscriptions.institution_id
        AND institution_members.user_id = auth.uid()
        AND institution_members.archived_at IS NULL
    )
  );

-- Политика обновления: участники заведения могут обновлять подписки
CREATE POLICY "Members can update subscriptions" ON subscriptions
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM institution_members
      WHERE institution_members.institution_id = subscriptions.institution_id
        AND institution_members.user_id = auth.uid()
        AND institution_members.archived_at IS NULL
    )
  );

-- Политика удаления: участники заведения могут удалять подписки
CREATE POLICY "Members can delete subscriptions" ON subscriptions
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM institution_members
      WHERE institution_members.institution_id = subscriptions.institution_id
        AND institution_members.user_id = auth.uid()
        AND institution_members.archived_at IS NULL
    )
  );

-- 4. Функция для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_subscription_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER subscription_updated_at_trigger
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION update_subscription_updated_at();

-- 5. Функция для автоматической разморозки истёкших заморозок
-- Вызывать периодически или проверять в приложении
CREATE OR REPLACE FUNCTION unfreeze_expired_subscriptions()
RETURNS void AS $$
DECLARE
  sub RECORD;
  days_frozen INT;
BEGIN
  FOR sub IN
    SELECT * FROM subscriptions
    WHERE is_frozen = TRUE
      AND frozen_until IS NOT NULL
      AND frozen_until <= CURRENT_DATE
  LOOP
    -- Вычисляем сколько дней была заморозка
    days_frozen := CURRENT_DATE - (sub.frozen_until - (CURRENT_DATE - sub.frozen_until)::INT);

    -- Размораживаем и продлеваем срок
    UPDATE subscriptions
    SET
      is_frozen = FALSE,
      frozen_until = NULL,
      expires_at = expires_at + (frozen_until - (expires_at - (expires_at - starts_at)))::INT,
      frozen_days_total = frozen_days_total + days_frozen
    WHERE id = sub.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 6. Функция для получения активного баланса студента (с учётом срока и заморозки)
CREATE OR REPLACE FUNCTION get_student_active_balance(p_student_id UUID)
RETURNS INT AS $$
DECLARE
  total_balance INT;
BEGIN
  SELECT COALESCE(SUM(lessons_remaining), 0)
  INTO total_balance
  FROM subscriptions
  WHERE student_id = p_student_id
    AND lessons_remaining > 0
    AND (
      -- Не истёк срок
      expires_at >= CURRENT_DATE
      -- Или заморожен (срок не идёт)
      OR is_frozen = TRUE
    );

  RETURN total_balance;
END;
$$ LANGUAGE plpgsql;

-- 7. Функция для списания занятия с подписки (FIFO - сначала истекающие)
CREATE OR REPLACE FUNCTION deduct_lesson_from_subscription(p_student_id UUID)
RETURNS UUID AS $$ -- Возвращает ID подписки с которой списали
DECLARE
  sub_id UUID;
BEGIN
  -- Находим активную подписку с самой ранней датой истечения
  SELECT id INTO sub_id
  FROM subscriptions
  WHERE student_id = p_student_id
    AND lessons_remaining > 0
    AND expires_at >= CURRENT_DATE
    AND is_frozen = FALSE
  ORDER BY expires_at ASC, created_at ASC
  LIMIT 1
  FOR UPDATE;

  IF sub_id IS NOT NULL THEN
    UPDATE subscriptions
    SET lessons_remaining = lessons_remaining - 1
    WHERE id = sub_id;
  END IF;

  RETURN sub_id;
END;
$$ LANGUAGE plpgsql;

-- 8. View для удобного получения информации о подписках студента
CREATE OR REPLACE VIEW student_subscription_summary AS
SELECT
  s.id as student_id,
  s.institution_id,
  s.name as student_name,
  COALESCE(SUM(sub.lessons_remaining) FILTER (
    WHERE sub.expires_at >= CURRENT_DATE OR sub.is_frozen = TRUE
  ), 0) as active_balance,
  COALESCE(SUM(sub.lessons_remaining) FILTER (
    WHERE sub.expires_at < CURRENT_DATE AND sub.is_frozen = FALSE
  ), 0) as expired_balance,
  MIN(sub.expires_at) FILTER (
    WHERE sub.lessons_remaining > 0 AND sub.expires_at >= CURRENT_DATE
  ) as nearest_expiration,
  BOOL_OR(sub.is_frozen) as has_frozen_subscription
FROM students s
LEFT JOIN subscriptions sub ON sub.student_id = s.id
WHERE s.archived_at IS NULL
GROUP BY s.id, s.institution_id, s.name;

-- 9. Комментарии к таблице
COMMENT ON TABLE subscriptions IS 'Абонементы студентов с отслеживанием срока действия и заморозки';
COMMENT ON COLUMN subscriptions.lessons_total IS 'Общее количество занятий в абонементе';
COMMENT ON COLUMN subscriptions.lessons_remaining IS 'Оставшееся количество занятий';
COMMENT ON COLUMN subscriptions.expires_at IS 'Дата истечения абонемента';
COMMENT ON COLUMN subscriptions.is_frozen IS 'Заморожен ли абонемент';
COMMENT ON COLUMN subscriptions.frozen_until IS 'До какой даты заморожен';
COMMENT ON COLUMN subscriptions.frozen_days_total IS 'Общее количество дней заморозки за всё время';
