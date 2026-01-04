-- Миграция: Привязка учеников к типам занятий
-- Дата: 2026-01-04

-- ============================================
-- Таблица student_lesson_types (Ученик ↔ Тип занятия)
-- ============================================

CREATE TABLE IF NOT EXISTS student_lesson_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  lesson_type_id UUID NOT NULL REFERENCES lesson_types(id) ON DELETE CASCADE,
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(student_id, lesson_type_id)
);

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_student_lesson_types_student ON student_lesson_types(student_id);
CREATE INDEX IF NOT EXISTS idx_student_lesson_types_lesson_type ON student_lesson_types(lesson_type_id);
CREATE INDEX IF NOT EXISTS idx_student_lesson_types_institution ON student_lesson_types(institution_id);

-- ============================================
-- RLS политики
-- ============================================

-- Включаем RLS
ALTER TABLE student_lesson_types ENABLE ROW LEVEL SECURITY;

-- Политики для student_lesson_types
CREATE POLICY "Members can view student_lesson_types"
  ON student_lesson_types FOR SELECT
  USING (is_member_of(institution_id));

CREATE POLICY "Members can insert student_lesson_types"
  ON student_lesson_types FOR INSERT
  WITH CHECK (is_member_of(institution_id));

CREATE POLICY "Members can delete student_lesson_types"
  ON student_lesson_types FOR DELETE
  USING (is_member_of(institution_id));
