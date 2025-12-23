-- Миграция: Привязка учеников к преподавателям и направлениям
-- Дата: 2025-12-23

-- ============================================
-- Таблица student_teachers (Ученик ↔ Преподаватель)
-- ============================================

CREATE TABLE IF NOT EXISTS student_teachers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(student_id, user_id)
);

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_student_teachers_student ON student_teachers(student_id);
CREATE INDEX IF NOT EXISTS idx_student_teachers_user ON student_teachers(user_id);
CREATE INDEX IF NOT EXISTS idx_student_teachers_institution ON student_teachers(institution_id);

-- ============================================
-- Таблица student_subjects (Ученик ↔ Предмет)
-- ============================================

CREATE TABLE IF NOT EXISTS student_subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(student_id, subject_id)
);

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_student_subjects_student ON student_subjects(student_id);
CREATE INDEX IF NOT EXISTS idx_student_subjects_subject ON student_subjects(subject_id);
CREATE INDEX IF NOT EXISTS idx_student_subjects_institution ON student_subjects(institution_id);

-- ============================================
-- RLS политики
-- ============================================

-- Включаем RLS
ALTER TABLE student_teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_subjects ENABLE ROW LEVEL SECURITY;

-- Политики для student_teachers
CREATE POLICY "Members can view student_teachers"
  ON student_teachers FOR SELECT
  USING (is_member_of(institution_id));

CREATE POLICY "Members can insert student_teachers"
  ON student_teachers FOR INSERT
  WITH CHECK (is_member_of(institution_id));

CREATE POLICY "Members can delete student_teachers"
  ON student_teachers FOR DELETE
  USING (is_member_of(institution_id));

-- Политики для student_subjects
CREATE POLICY "Members can view student_subjects"
  ON student_subjects FOR SELECT
  USING (is_member_of(institution_id));

CREATE POLICY "Members can insert student_subjects"
  ON student_subjects FOR INSERT
  WITH CHECK (is_member_of(institution_id));

CREATE POLICY "Members can delete student_subjects"
  ON student_subjects FOR DELETE
  USING (is_member_of(institution_id));
