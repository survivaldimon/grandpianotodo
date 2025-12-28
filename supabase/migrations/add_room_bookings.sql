-- Миграция: Добавление системы бронирования кабинетов
-- Дата: 2025-12-28
-- Описание: Позволяет бронировать кабинеты для мероприятий, блокируя их для занятий

-- ============================================
-- 1. Таблица bookings (брони)
-- ============================================
CREATE TABLE IF NOT EXISTS bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES auth.users(id),

  -- Время брони
  date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,

  -- Описание (опционально)
  description TEXT,

  -- Метаданные
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,

  -- Проверка: время окончания > времени начала
  CONSTRAINT booking_end_after_start CHECK (end_time > start_time)
);

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_bookings_institution_date ON bookings(institution_id, date);
CREATE INDEX IF NOT EXISTS idx_bookings_created_by ON bookings(created_by);
CREATE INDEX IF NOT EXISTS idx_bookings_date ON bookings(date);

-- ============================================
-- 2. Таблица booking_rooms (связь брони с кабинетами)
-- ============================================
CREATE TABLE IF NOT EXISTS booking_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,

  -- Уникальность: одна бронь не может дважды содержать один кабинет
  UNIQUE(booking_id, room_id)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_booking_rooms_booking ON booking_rooms(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_rooms_room ON booking_rooms(room_id);

-- ============================================
-- 3. RLS Policies для bookings
-- ============================================
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- Просмотр: все участники заведения
CREATE POLICY "Members can view bookings"
  ON bookings FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM institution_members
      WHERE institution_members.institution_id = bookings.institution_id
        AND institution_members.user_id = auth.uid()
        AND institution_members.archived_at IS NULL
    )
  );

-- Создание: участники с правом create_bookings
CREATE POLICY "Can create bookings"
  ON bookings FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM institution_members
      WHERE institution_members.institution_id = bookings.institution_id
        AND institution_members.user_id = auth.uid()
        AND institution_members.archived_at IS NULL
        AND (
          -- Владелец или админ
          institution_members.user_id = (SELECT owner_id FROM institutions WHERE id = bookings.institution_id)
          OR institution_members.is_admin = true
          -- Или право create_bookings
          OR (institution_members.permissions->>'create_bookings')::boolean = true
        )
    )
    AND created_by = auth.uid()
  );

-- Обновление: создатель или manageRooms
CREATE POLICY "Can update bookings"
  ON bookings FOR UPDATE
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM institution_members
      WHERE institution_members.institution_id = bookings.institution_id
        AND institution_members.user_id = auth.uid()
        AND institution_members.archived_at IS NULL
        AND (
          institution_members.user_id = (SELECT owner_id FROM institutions WHERE id = bookings.institution_id)
          OR institution_members.is_admin = true
          OR (institution_members.permissions->>'manage_rooms')::boolean = true
        )
    )
  );

-- Удаление: создатель или manageRooms
CREATE POLICY "Can delete bookings"
  ON bookings FOR DELETE
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM institution_members
      WHERE institution_members.institution_id = bookings.institution_id
        AND institution_members.user_id = auth.uid()
        AND institution_members.archived_at IS NULL
        AND (
          institution_members.user_id = (SELECT owner_id FROM institutions WHERE id = bookings.institution_id)
          OR institution_members.is_admin = true
          OR (institution_members.permissions->>'manage_rooms')::boolean = true
        )
    )
  );

-- ============================================
-- 4. RLS Policies для booking_rooms
-- ============================================
ALTER TABLE booking_rooms ENABLE ROW LEVEL SECURITY;

-- Просмотр: через связь с bookings
CREATE POLICY "Members can view booking_rooms"
  ON booking_rooms FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM bookings
      WHERE bookings.id = booking_rooms.booking_id
        AND EXISTS (
          SELECT 1 FROM institution_members
          WHERE institution_members.institution_id = bookings.institution_id
            AND institution_members.user_id = auth.uid()
            AND institution_members.archived_at IS NULL
        )
    )
  );

-- Создание/обновление/удаление: через связь с bookings (создатель или manageRooms)
CREATE POLICY "Can manage booking_rooms"
  ON booking_rooms FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM bookings
      WHERE bookings.id = booking_rooms.booking_id
        AND (
          bookings.created_by = auth.uid()
          OR EXISTS (
            SELECT 1 FROM institution_members
            WHERE institution_members.institution_id = bookings.institution_id
              AND institution_members.user_id = auth.uid()
              AND institution_members.archived_at IS NULL
              AND (
                institution_members.user_id = (SELECT owner_id FROM institutions WHERE id = bookings.institution_id)
                OR institution_members.is_admin = true
                OR (institution_members.permissions->>'manage_rooms')::boolean = true
              )
          )
        )
    )
  );

-- ============================================
-- 5. Realtime
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE bookings;
ALTER PUBLICATION supabase_realtime ADD TABLE booking_rooms;

-- ============================================
-- 6. Trigger для updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_booking_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_booking_updated_at
  BEFORE UPDATE ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION update_booking_updated_at();
