-- RLS политика для lesson_history
-- Участники заведения могут добавлять записи истории для занятий своего заведения

-- Включаем RLS если ещё не включён
ALTER TABLE lesson_history ENABLE ROW LEVEL SECURITY;

-- Политика на SELECT — участники видят историю занятий своего заведения
DROP POLICY IF EXISTS "Members can view lesson history" ON lesson_history;
CREATE POLICY "Members can view lesson history"
ON lesson_history
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM lessons l
    JOIN institution_members im ON im.institution_id = l.institution_id
    WHERE l.id = lesson_history.lesson_id
    AND im.user_id = auth.uid()
    AND im.archived_at IS NULL
  )
);

-- Политика на INSERT — участники могут добавлять историю для занятий своего заведения
DROP POLICY IF EXISTS "Members can insert lesson history" ON lesson_history;
CREATE POLICY "Members can insert lesson history"
ON lesson_history
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM lessons l
    JOIN institution_members im ON im.institution_id = l.institution_id
    WHERE l.id = lesson_history.lesson_id
    AND im.user_id = auth.uid()
    AND im.archived_at IS NULL
  )
);
