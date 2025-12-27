-- Добавление колонки is_admin для роли администратора
-- Администратор имеет все права владельца, кроме удаления заведения

-- Добавляем колонку is_admin в таблицу institution_members
ALTER TABLE institution_members
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Создаём индекс для быстрого поиска администраторов
CREATE INDEX IF NOT EXISTS idx_institution_members_is_admin
ON institution_members(institution_id, is_admin)
WHERE is_admin = TRUE;

-- Комментарий к колонке
COMMENT ON COLUMN institution_members.is_admin IS 'Статус администратора. Администратор имеет все права владельца, кроме удаления заведения.';

-- Обновляем функцию проверки прав с учётом is_admin
CREATE OR REPLACE FUNCTION has_permission(inst_id UUID, permission TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM institution_members
    WHERE institution_id = inst_id
    AND user_id = auth.uid()
    AND archived_at IS NULL
    AND (
      is_admin = TRUE  -- Администратор имеет все права
      OR (permissions->>permission)::boolean = TRUE
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Функция проверки владельца или администратора
CREATE OR REPLACE FUNCTION is_owner_or_admin(inst_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM institutions
    WHERE id = inst_id
    AND owner_id = auth.uid()
  ) OR EXISTS (
    SELECT 1 FROM institution_members
    WHERE institution_id = inst_id
    AND user_id = auth.uid()
    AND archived_at IS NULL
    AND is_admin = TRUE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
