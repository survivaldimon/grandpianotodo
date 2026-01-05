-- Добавить subscription_id в таблицу lesson_students
-- Это позволяет отслеживать, с какой подписки было списано занятие
-- для каждого участника группового занятия

ALTER TABLE lesson_students
ADD COLUMN IF NOT EXISTS subscription_id UUID REFERENCES subscriptions(id);

-- Индекс для быстрого поиска по подписке
CREATE INDEX IF NOT EXISTS idx_lesson_students_subscription_id
ON lesson_students(subscription_id)
WHERE subscription_id IS NOT NULL;
