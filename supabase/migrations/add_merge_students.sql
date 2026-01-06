-- Миграция: Функция объединения учеников
-- Дата: 2026-01-06
-- Описание:
--   Создаёт нового ученика из нескольких существующих
--   Переносит все данные (занятия, оплаты, подписки, привязки)
--   Архивирует исходных учеников с пометкой
--   Сохраняет ID объединённых учеников в поле merged_from

CREATE OR REPLACE FUNCTION merge_students(
  p_source_ids UUID[],           -- ID учеников для объединения
  p_institution_id UUID,         -- ID заведения
  p_new_name TEXT,               -- Имя нового ученика
  p_new_phone TEXT DEFAULT NULL,
  p_new_comment TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_new_student_id UUID;
  v_source_id UUID;
  v_total_legacy_balance INT := 0;
  v_total_prepaid INT := 0;
  v_legacy INT;
  v_prepaid INT;
BEGIN
  -- Проверяем, что передано минимум 2 ученика
  IF array_length(p_source_ids, 1) < 2 THEN
    RAISE EXCEPTION 'Нужно минимум 2 ученика для объединения';
  END IF;

  -- 1. Создать нового ученика с merged_from
  INSERT INTO students (institution_id, name, phone, comment, legacy_balance, prepaid_lessons_count, merged_from)
  VALUES (p_institution_id, p_new_name, p_new_phone, p_new_comment, 0, 0, p_source_ids)
  RETURNING id INTO v_new_student_id;

  -- 2. Для каждого исходного ученика
  FOREACH v_source_id IN ARRAY p_source_ids LOOP
    -- Получаем балансы ученика
    SELECT COALESCE(legacy_balance, 0), COALESCE(prepaid_lessons_count, 0)
    INTO v_legacy, v_prepaid
    FROM students WHERE id = v_source_id;

    -- Суммируем балансы
    v_total_legacy_balance := v_total_legacy_balance + v_legacy;
    v_total_prepaid := v_total_prepaid + v_prepaid;

    -- Переносим занятия (индивидуальные)
    UPDATE lessons SET student_id = v_new_student_id WHERE student_id = v_source_id;

    -- Переносим lesson_students (групповые занятия)
    -- Используем ON CONFLICT для избежания дубликатов если два ученика были в одном занятии
    UPDATE lesson_students SET student_id = v_new_student_id
    WHERE student_id = v_source_id
    AND NOT EXISTS (
      SELECT 1 FROM lesson_students ls2
      WHERE ls2.lesson_id = lesson_students.lesson_id
      AND ls2.student_id = v_new_student_id
    );
    -- Удаляем оставшиеся дубликаты (если два ученика были в одном групповом занятии)
    DELETE FROM lesson_students WHERE student_id = v_source_id;

    -- Переносим оплаты
    UPDATE payments SET student_id = v_new_student_id WHERE student_id = v_source_id;

    -- Переносим индивидуальные подписки
    UPDATE subscriptions SET student_id = v_new_student_id
    WHERE student_id = v_source_id AND is_family = FALSE;

    -- Переносим участие в семейных подписках
    -- Избегаем дубликатов если два ученика были в одной семейной подписке
    UPDATE subscription_members SET student_id = v_new_student_id
    WHERE student_id = v_source_id
    AND NOT EXISTS (
      SELECT 1 FROM subscription_members sm2
      WHERE sm2.subscription_id = subscription_members.subscription_id
      AND sm2.student_id = v_new_student_id
    );
    -- Удаляем оставшиеся дубликаты
    DELETE FROM subscription_members WHERE student_id = v_source_id;

    -- Переносим привязки к учителям (дедупликация через NOT EXISTS)
    INSERT INTO student_teachers (student_id, user_id, institution_id)
    SELECT v_new_student_id, user_id, institution_id
    FROM student_teachers
    WHERE student_id = v_source_id
    AND NOT EXISTS (
      SELECT 1 FROM student_teachers st2
      WHERE st2.student_id = v_new_student_id
      AND st2.user_id = student_teachers.user_id
    );
    DELETE FROM student_teachers WHERE student_id = v_source_id;

    -- Переносим привязки к предметам (дедупликация)
    INSERT INTO student_subjects (student_id, subject_id, institution_id)
    SELECT v_new_student_id, subject_id, institution_id
    FROM student_subjects
    WHERE student_id = v_source_id
    AND NOT EXISTS (
      SELECT 1 FROM student_subjects ss2
      WHERE ss2.student_id = v_new_student_id
      AND ss2.subject_id = student_subjects.subject_id
    );
    DELETE FROM student_subjects WHERE student_id = v_source_id;

    -- Переносим привязки к типам занятий (дедупликация)
    INSERT INTO student_lesson_types (student_id, lesson_type_id, institution_id)
    SELECT v_new_student_id, lesson_type_id, institution_id
    FROM student_lesson_types
    WHERE student_id = v_source_id
    AND NOT EXISTS (
      SELECT 1 FROM student_lesson_types slt2
      WHERE slt2.student_id = v_new_student_id
      AND slt2.lesson_type_id = student_lesson_types.lesson_type_id
    );
    DELETE FROM student_lesson_types WHERE student_id = v_source_id;

    -- Переносим участие в группах учеников (дедупликация)
    INSERT INTO student_group_members (group_id, student_id)
    SELECT group_id, v_new_student_id
    FROM student_group_members
    WHERE student_id = v_source_id
    AND NOT EXISTS (
      SELECT 1 FROM student_group_members sgm2
      WHERE sgm2.group_id = student_group_members.group_id
      AND sgm2.student_id = v_new_student_id
    );
    DELETE FROM student_group_members WHERE student_id = v_source_id;

    -- Архивируем исходного ученика с пометкой
    UPDATE students
    SET archived_at = NOW(),
        comment = COALESCE(comment, '') || E'\n[Объединён в карточку ' || v_new_student_id || ']'
    WHERE id = v_source_id;
  END LOOP;

  -- 3. Устанавливаем суммарные балансы
  UPDATE students
  SET legacy_balance = v_total_legacy_balance,
      prepaid_lessons_count = v_total_prepaid
  WHERE id = v_new_student_id;

  RETURN v_new_student_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION merge_students IS 'Объединяет несколько учеников в одного нового. Создаёт новую карточку с merged_from, переносит все данные, архивирует исходных.';
