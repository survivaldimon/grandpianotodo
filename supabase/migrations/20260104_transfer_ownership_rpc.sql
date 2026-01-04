-- RPC функция для передачи прав владельца
-- SECURITY DEFINER позволяет обойти RLS политику
CREATE OR REPLACE FUNCTION transfer_institution_ownership(
  p_institution_id UUID,
  p_new_owner_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_owner_id UUID;
  v_new_owner_member_id UUID;
BEGIN
  -- Проверяем, что вызывающий пользователь - текущий владелец
  SELECT owner_id INTO v_current_owner_id
  FROM institutions
  WHERE id = p_institution_id AND archived_at IS NULL;

  IF v_current_owner_id IS NULL THEN
    RAISE EXCEPTION 'Заведение не найдено';
  END IF;

  IF v_current_owner_id != auth.uid() THEN
    RAISE EXCEPTION 'Только владелец может передать права';
  END IF;

  -- Проверяем, что новый владелец - участник заведения
  SELECT id INTO v_new_owner_member_id
  FROM institution_members
  WHERE institution_id = p_institution_id
    AND user_id = p_new_owner_id
    AND archived_at IS NULL;

  IF v_new_owner_member_id IS NULL THEN
    RAISE EXCEPTION 'Пользователь не является участником заведения';
  END IF;

  -- Обновляем владельца
  UPDATE institutions
  SET owner_id = p_new_owner_id
  WHERE id = p_institution_id;

  -- Снимаем статус админа с нового владельца (он теперь владелец)
  UPDATE institution_members
  SET is_admin = false
  WHERE id = v_new_owner_member_id;
END;
$$;

-- Даём права на выполнение функции аутентифицированным пользователям
GRANT EXECUTE ON FUNCTION transfer_institution_ownership(UUID, UUID) TO authenticated;
