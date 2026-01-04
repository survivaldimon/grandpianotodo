-- Фикс RLS для таблиц привязок
-- Добавляем UPDATE политики (нужны для UPSERT)

-- student_teachers
DROP POLICY IF EXISTS "Members can update student_teachers" ON student_teachers;
CREATE POLICY "Members can update student_teachers"
  ON student_teachers FOR UPDATE
  USING (is_member_of(institution_id))
  WITH CHECK (is_member_of(institution_id));

-- student_subjects
DROP POLICY IF EXISTS "Members can update student_subjects" ON student_subjects;
CREATE POLICY "Members can update student_subjects"
  ON student_subjects FOR UPDATE
  USING (is_member_of(institution_id))
  WITH CHECK (is_member_of(institution_id));

-- student_lesson_types
DROP POLICY IF EXISTS "Members can update student_lesson_types" ON student_lesson_types;
CREATE POLICY "Members can update student_lesson_types"
  ON student_lesson_types FOR UPDATE
  USING (is_member_of(institution_id))
  WITH CHECK (is_member_of(institution_id));
