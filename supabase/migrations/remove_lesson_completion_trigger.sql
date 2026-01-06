-- Миграция: Удаление триггера двойного списания занятий
-- Дата: 2026-01-06
-- Описание: Триггер handle_lesson_completion вызывал двойное списание:
--   1. Триггер автоматически уменьшал prepaid_lessons_count при status='completed'
--   2. Dart код (LessonController.complete) также списывал занятие
-- Решение: Оставляем логику только в Dart коде, который:
--   - Умнее: сначала проверяет подписки, потом prepaid
--   - Сохраняет subscription_id для расчёта стоимости
--   - Корректно обрабатывает групповые занятия

-- Удаляем триггер
DROP TRIGGER IF EXISTS handle_lesson_completion_trigger ON lessons;

-- Удаляем функцию
DROP FUNCTION IF EXISTS handle_lesson_completion();

-- Комментарий для документации
COMMENT ON TABLE lessons IS 'Списание занятий управляется из приложения через LessonController.complete(). Триггер handle_lesson_completion удалён для избежания двойного списания.';
