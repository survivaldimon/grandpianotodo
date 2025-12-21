-- ============================================
-- KABINET - Полный SQL скрипт для Supabase
-- ============================================
-- Выполнить в Supabase Dashboard → SQL Editor
-- ============================================

-- 1. ФУНКЦИИ
-- ============================================

-- Функция генерации invite code
CREATE OR REPLACE FUNCTION generate_invite_code()
RETURNS TEXT AS $$
BEGIN
  RETURN upper(substr(md5(random()::text), 1, 8));
END;
$$ LANGUAGE plpgsql;

-- Функция автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. ТИПЫ
-- ============================================

CREATE TYPE lesson_status AS ENUM ('scheduled', 'completed', 'cancelled', 'rescheduled');

-- 3. ТАБЛИЦЫ
-- ============================================

-- Профили пользователей
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Заведения
CREATE TABLE institutions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  owner_id UUID NOT NULL REFERENCES auth.users(id),
  invite_code TEXT UNIQUE NOT NULL DEFAULT generate_invite_code(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  archived_at TIMESTAMPTZ
);

-- Участники заведений
CREATE TABLE institution_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role_name TEXT NOT NULL DEFAULT 'Преподаватель',
  permissions JSONB NOT NULL DEFAULT '{
    "manage_institution": false,
    "manage_rooms": false,
    "manage_members": false,
    "manage_subjects": false,
    "manage_students": false,
    "manage_groups": false,
    "manage_lesson_types": false,
    "manage_payment_plans": false,
    "create_lessons": true,
    "edit_own_lessons": true,
    "edit_all_lessons": false,
    "delete_lessons": false,
    "view_all_schedule": true,
    "manage_payments": false,
    "view_payments": false,
    "view_statistics": false,
    "archive_data": false
  }'::jsonb,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  archived_at TIMESTAMPTZ,

  UNIQUE(institution_id, user_id)
);

-- Кабинеты
CREATE TABLE rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  number TEXT,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  archived_at TIMESTAMPTZ
);

-- Ученики
CREATE TABLE students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT,
  comment TEXT,
  prepaid_lessons_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  archived_at TIMESTAMPTZ
);

-- Группы учеников
CREATE TABLE student_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  archived_at TIMESTAMPTZ
);

-- Участники групп
CREATE TABLE student_group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES student_groups(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(group_id, student_id)
);

-- Предметы/направления
CREATE TABLE subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  archived_at TIMESTAMPTZ
);

-- Связь преподавателей с предметами
CREATE TABLE teacher_subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, subject_id)
);

-- Типы занятий
CREATE TABLE lesson_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  default_duration_minutes INT NOT NULL DEFAULT 60,
  default_price DECIMAL(10, 2),
  is_group BOOLEAN NOT NULL DEFAULT FALSE,
  color TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  archived_at TIMESTAMPTZ
);

-- Занятия
CREATE TABLE lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id),
  teacher_id UUID NOT NULL REFERENCES auth.users(id),
  subject_id UUID REFERENCES subjects(id),
  lesson_type_id UUID REFERENCES lesson_types(id),
  student_id UUID REFERENCES students(id),
  group_id UUID REFERENCES student_groups(id),
  date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  status lesson_status NOT NULL DEFAULT 'scheduled',
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID NOT NULL REFERENCES auth.users(id),
  archived_at TIMESTAMPTZ,

  CONSTRAINT lesson_participant CHECK (
    (student_id IS NOT NULL AND group_id IS NULL) OR
    (student_id IS NULL AND group_id IS NOT NULL)
  )
);

-- Участники групповых занятий
CREATE TABLE lesson_students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id),
  attended BOOLEAN NOT NULL DEFAULT TRUE,

  UNIQUE(lesson_id, student_id)
);

-- История изменений занятий
CREATE TABLE lesson_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  changed_by UUID NOT NULL REFERENCES auth.users(id),
  changed_at TIMESTAMPTZ DEFAULT NOW(),
  action TEXT NOT NULL,
  changes JSONB NOT NULL
);

-- Тарифы оплаты
CREATE TABLE payment_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  price DECIMAL(10, 2) NOT NULL,
  lessons_count INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  archived_at TIMESTAMPTZ
);

-- Оплаты
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id),
  payment_plan_id UUID REFERENCES payment_plans(id),
  amount DECIMAL(10, 2) NOT NULL,
  lessons_count INT NOT NULL,
  is_correction BOOLEAN NOT NULL DEFAULT FALSE,
  correction_reason TEXT,
  paid_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  recorded_by UUID NOT NULL REFERENCES auth.users(id),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT correction_requires_reason CHECK (
    is_correction = FALSE OR correction_reason IS NOT NULL
  )
);

-- 4. ИНДЕКСЫ
-- ============================================

CREATE INDEX idx_institution_members_user ON institution_members(user_id) WHERE archived_at IS NULL;
CREATE INDEX idx_students_institution ON students(institution_id) WHERE archived_at IS NULL;
CREATE INDEX idx_rooms_institution ON rooms(institution_id) WHERE archived_at IS NULL;
CREATE INDEX idx_lessons_room_date ON lessons(room_id, date);
CREATE INDEX idx_lessons_teacher_date ON lessons(teacher_id, date);
CREATE INDEX idx_lessons_institution_date ON lessons(institution_id, date);
CREATE INDEX idx_lessons_date_range ON lessons(institution_id, date, start_time) WHERE archived_at IS NULL;
CREATE INDEX idx_lesson_history_lesson ON lesson_history(lesson_id);
CREATE INDEX idx_teacher_subjects_user ON teacher_subjects(user_id);
CREATE INDEX idx_teacher_subjects_subject ON teacher_subjects(subject_id);
CREATE INDEX idx_payments_student ON payments(student_id);
CREATE INDEX idx_payments_institution_date ON payments(institution_id, paid_at DESC);

-- 5. ТРИГГЕРЫ updated_at
-- ============================================

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_institutions_updated_at
  BEFORE UPDATE ON institutions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_rooms_updated_at
  BEFORE UPDATE ON rooms
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_students_updated_at
  BEFORE UPDATE ON students
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_student_groups_updated_at
  BEFORE UPDATE ON student_groups
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_subjects_updated_at
  BEFORE UPDATE ON subjects
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_lesson_types_updated_at
  BEFORE UPDATE ON lesson_types
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_lessons_updated_at
  BEFORE UPDATE ON lessons
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_payment_plans_updated_at
  BEFORE UPDATE ON payment_plans
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 6. RLS ФУНКЦИИ
-- ============================================

-- Функция проверки членства
CREATE OR REPLACE FUNCTION is_member_of(inst_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM institution_members
    WHERE institution_id = inst_id
    AND user_id = auth.uid()
    AND archived_at IS NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Функция проверки прав
CREATE OR REPLACE FUNCTION has_permission(inst_id UUID, permission TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM institution_members
    WHERE institution_id = inst_id
    AND user_id = auth.uid()
    AND archived_at IS NULL
    AND (permissions->>permission)::boolean = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Функция проверки владельца
CREATE OR REPLACE FUNCTION is_owner_of(inst_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM institutions
    WHERE id = inst_id
    AND owner_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. ВКЛЮЧЕНИЕ RLS
-- ============================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE institutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE institution_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- 8. RLS POLICIES
-- ============================================

-- profiles
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (id = auth.uid());

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (id = auth.uid());

CREATE POLICY "Members can view other profiles"
  ON profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM institution_members im1
      JOIN institution_members im2 ON im1.institution_id = im2.institution_id
      WHERE im1.user_id = auth.uid()
      AND im2.user_id = profiles.id
      AND im1.archived_at IS NULL
      AND im2.archived_at IS NULL
    )
  );

-- institutions
CREATE POLICY "Members can view institution"
  ON institutions FOR SELECT
  USING (is_member_of(id) OR owner_id = auth.uid());

CREATE POLICY "Users can create institutions"
  ON institutions FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Admins can update institution"
  ON institutions FOR UPDATE
  USING (has_permission(id, 'manage_institution') OR owner_id = auth.uid());

-- institution_members
CREATE POLICY "Members can view members"
  ON institution_members FOR SELECT
  USING (is_member_of(institution_id));

CREATE POLICY "Can manage members"
  ON institution_members FOR INSERT
  WITH CHECK (has_permission(institution_id, 'manage_members') OR is_owner_of(institution_id));

CREATE POLICY "Can update members"
  ON institution_members FOR UPDATE
  USING (has_permission(institution_id, 'manage_members') OR is_owner_of(institution_id));

CREATE POLICY "Can delete members"
  ON institution_members FOR DELETE
  USING (has_permission(institution_id, 'manage_members') OR is_owner_of(institution_id));

-- rooms
CREATE POLICY "Members can view rooms"
  ON rooms FOR SELECT
  USING (is_member_of(institution_id));

CREATE POLICY "Can insert rooms"
  ON rooms FOR INSERT
  WITH CHECK (has_permission(institution_id, 'manage_rooms') OR is_owner_of(institution_id));

CREATE POLICY "Can update rooms"
  ON rooms FOR UPDATE
  USING (has_permission(institution_id, 'manage_rooms') OR is_owner_of(institution_id));

CREATE POLICY "Can delete rooms"
  ON rooms FOR DELETE
  USING (has_permission(institution_id, 'manage_rooms') OR is_owner_of(institution_id));

-- students
CREATE POLICY "Members can view students"
  ON students FOR SELECT
  USING (is_member_of(institution_id));

CREATE POLICY "Can insert students"
  ON students FOR INSERT
  WITH CHECK (has_permission(institution_id, 'manage_students') OR is_owner_of(institution_id));

CREATE POLICY "Can update students"
  ON students FOR UPDATE
  USING (has_permission(institution_id, 'manage_students') OR is_owner_of(institution_id));

CREATE POLICY "Can delete students"
  ON students FOR DELETE
  USING (has_permission(institution_id, 'manage_students') OR is_owner_of(institution_id));

-- student_groups
CREATE POLICY "Members can view groups"
  ON student_groups FOR SELECT
  USING (is_member_of(institution_id));

CREATE POLICY "Can insert groups"
  ON student_groups FOR INSERT
  WITH CHECK (has_permission(institution_id, 'manage_groups') OR is_owner_of(institution_id));

CREATE POLICY "Can update groups"
  ON student_groups FOR UPDATE
  USING (has_permission(institution_id, 'manage_groups') OR is_owner_of(institution_id));

CREATE POLICY "Can delete groups"
  ON student_groups FOR DELETE
  USING (has_permission(institution_id, 'manage_groups') OR is_owner_of(institution_id));

-- student_group_members
CREATE POLICY "Members can view group members"
  ON student_group_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM student_groups sg
      WHERE sg.id = student_group_members.group_id
      AND is_member_of(sg.institution_id)
    )
  );

CREATE POLICY "Can manage group members"
  ON student_group_members FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM student_groups sg
      WHERE sg.id = student_group_members.group_id
      AND (has_permission(sg.institution_id, 'manage_groups') OR is_owner_of(sg.institution_id))
    )
  );

-- subjects
CREATE POLICY "Members can view subjects"
  ON subjects FOR SELECT
  USING (is_member_of(institution_id));

CREATE POLICY "Can insert subjects"
  ON subjects FOR INSERT
  WITH CHECK (has_permission(institution_id, 'manage_subjects') OR is_owner_of(institution_id));

CREATE POLICY "Can update subjects"
  ON subjects FOR UPDATE
  USING (has_permission(institution_id, 'manage_subjects') OR is_owner_of(institution_id));

CREATE POLICY "Can delete subjects"
  ON subjects FOR DELETE
  USING (has_permission(institution_id, 'manage_subjects') OR is_owner_of(institution_id));

-- teacher_subjects
CREATE POLICY "Members can view teacher subjects"
  ON teacher_subjects FOR SELECT
  USING (is_member_of(institution_id));

CREATE POLICY "Can manage teacher subjects"
  ON teacher_subjects FOR ALL
  USING (has_permission(institution_id, 'manage_subjects') OR is_owner_of(institution_id));

-- lesson_types
CREATE POLICY "Members can view lesson types"
  ON lesson_types FOR SELECT
  USING (is_member_of(institution_id));

CREATE POLICY "Can insert lesson types"
  ON lesson_types FOR INSERT
  WITH CHECK (has_permission(institution_id, 'manage_lesson_types') OR is_owner_of(institution_id));

CREATE POLICY "Can update lesson types"
  ON lesson_types FOR UPDATE
  USING (has_permission(institution_id, 'manage_lesson_types') OR is_owner_of(institution_id));

CREATE POLICY "Can delete lesson types"
  ON lesson_types FOR DELETE
  USING (has_permission(institution_id, 'manage_lesson_types') OR is_owner_of(institution_id));

-- lessons
CREATE POLICY "Members can view all lessons"
  ON lessons FOR SELECT
  USING (is_member_of(institution_id));

CREATE POLICY "Can create lessons"
  ON lessons FOR INSERT
  WITH CHECK (has_permission(institution_id, 'create_lessons') OR is_owner_of(institution_id));

CREATE POLICY "Can edit own lessons"
  ON lessons FOR UPDATE
  USING (
    (teacher_id = auth.uid() AND has_permission(institution_id, 'edit_own_lessons'))
    OR has_permission(institution_id, 'edit_all_lessons')
    OR is_owner_of(institution_id)
  );

CREATE POLICY "Can delete lessons"
  ON lessons FOR DELETE
  USING (has_permission(institution_id, 'delete_lessons') OR is_owner_of(institution_id));

-- lesson_students
CREATE POLICY "Members can view lesson students"
  ON lesson_students FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM lessons l
      WHERE l.id = lesson_students.lesson_id
      AND is_member_of(l.institution_id)
    )
  );

CREATE POLICY "Can manage lesson students"
  ON lesson_students FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM lessons l
      WHERE l.id = lesson_students.lesson_id
      AND (
        (l.teacher_id = auth.uid() AND has_permission(l.institution_id, 'edit_own_lessons'))
        OR has_permission(l.institution_id, 'edit_all_lessons')
        OR is_owner_of(l.institution_id)
      )
    )
  );

-- lesson_history
CREATE POLICY "Members can view lesson history"
  ON lesson_history FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM lessons l
      WHERE l.id = lesson_history.lesson_id
      AND is_member_of(l.institution_id)
    )
  );

-- payment_plans
CREATE POLICY "Members can view payment plans"
  ON payment_plans FOR SELECT
  USING (is_member_of(institution_id));

CREATE POLICY "Can insert payment plans"
  ON payment_plans FOR INSERT
  WITH CHECK (has_permission(institution_id, 'manage_payment_plans') OR is_owner_of(institution_id));

CREATE POLICY "Can update payment plans"
  ON payment_plans FOR UPDATE
  USING (has_permission(institution_id, 'manage_payment_plans') OR is_owner_of(institution_id));

CREATE POLICY "Can delete payment plans"
  ON payment_plans FOR DELETE
  USING (has_permission(institution_id, 'manage_payment_plans') OR is_owner_of(institution_id));

-- payments
CREATE POLICY "Can view payments"
  ON payments FOR SELECT
  USING (
    has_permission(institution_id, 'view_payments')
    OR has_permission(institution_id, 'manage_payments')
    OR is_owner_of(institution_id)
  );

CREATE POLICY "Can insert payments"
  ON payments FOR INSERT
  WITH CHECK (has_permission(institution_id, 'manage_payments') OR is_owner_of(institution_id));

CREATE POLICY "Can update payments"
  ON payments FOR UPDATE
  USING (has_permission(institution_id, 'manage_payments') OR is_owner_of(institution_id));

CREATE POLICY "Can delete payments"
  ON payments FOR DELETE
  USING (has_permission(institution_id, 'manage_payments') OR is_owner_of(institution_id));

-- 9. БИЗНЕС-ТРИГГЕРЫ
-- ============================================

-- Запись истории изменений занятий
CREATE OR REPLACE FUNCTION log_lesson_changes()
RETURNS TRIGGER AS $$
DECLARE
  changes JSONB := '{}';
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO lesson_history (lesson_id, changed_by, action, changes)
    VALUES (NEW.id, NEW.created_by, 'created', to_jsonb(NEW));
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.room_id IS DISTINCT FROM NEW.room_id THEN
      changes := changes || jsonb_build_object('room_id', jsonb_build_object('old', OLD.room_id, 'new', NEW.room_id));
    END IF;
    IF OLD.date IS DISTINCT FROM NEW.date THEN
      changes := changes || jsonb_build_object('date', jsonb_build_object('old', OLD.date, 'new', NEW.date));
    END IF;
    IF OLD.start_time IS DISTINCT FROM NEW.start_time THEN
      changes := changes || jsonb_build_object('start_time', jsonb_build_object('old', OLD.start_time, 'new', NEW.start_time));
    END IF;
    IF OLD.end_time IS DISTINCT FROM NEW.end_time THEN
      changes := changes || jsonb_build_object('end_time', jsonb_build_object('old', OLD.end_time, 'new', NEW.end_time));
    END IF;
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      changes := changes || jsonb_build_object('status', jsonb_build_object('old', OLD.status, 'new', NEW.status));
    END IF;
    IF OLD.comment IS DISTINCT FROM NEW.comment THEN
      changes := changes || jsonb_build_object('comment', jsonb_build_object('old', OLD.comment, 'new', NEW.comment));
    END IF;
    IF OLD.student_id IS DISTINCT FROM NEW.student_id THEN
      changes := changes || jsonb_build_object('student_id', jsonb_build_object('old', OLD.student_id, 'new', NEW.student_id));
    END IF;
    IF OLD.group_id IS DISTINCT FROM NEW.group_id THEN
      changes := changes || jsonb_build_object('group_id', jsonb_build_object('old', OLD.group_id, 'new', NEW.group_id));
    END IF;

    IF changes != '{}' THEN
      INSERT INTO lesson_history (lesson_id, changed_by, action, changes)
      VALUES (NEW.id, auth.uid(), 'updated', changes);
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER log_lesson_changes_trigger
  AFTER INSERT OR UPDATE ON lessons
  FOR EACH ROW EXECUTE FUNCTION log_lesson_changes();

-- Списание предоплаченных занятий при завершении
CREATE OR REPLACE FUNCTION handle_lesson_completion()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('completed', 'cancelled') AND OLD.status = 'scheduled' THEN
    IF NEW.student_id IS NOT NULL THEN
      UPDATE students
      SET prepaid_lessons_count = prepaid_lessons_count - 1
      WHERE id = NEW.student_id;
    END IF;

    IF NEW.group_id IS NOT NULL THEN
      UPDATE students
      SET prepaid_lessons_count = prepaid_lessons_count - 1
      WHERE id IN (
        SELECT student_id FROM lesson_students
        WHERE lesson_id = NEW.id AND attended = TRUE
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER handle_lesson_completion_trigger
  AFTER UPDATE ON lessons
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION handle_lesson_completion();

-- Добавление занятий при оплате
CREATE OR REPLACE FUNCTION handle_payment_insert()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE students
  SET prepaid_lessons_count = prepaid_lessons_count + NEW.lessons_count
  WHERE id = NEW.student_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER handle_payment_insert_trigger
  AFTER INSERT ON payments
  FOR EACH ROW EXECUTE FUNCTION handle_payment_insert();

-- Корректировка баланса при обновлении оплаты
CREATE OR REPLACE FUNCTION handle_payment_update()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.lessons_count IS DISTINCT FROM NEW.lessons_count THEN
    UPDATE students
    SET prepaid_lessons_count = prepaid_lessons_count - OLD.lessons_count + NEW.lessons_count
    WHERE id = NEW.student_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER handle_payment_update_trigger
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION handle_payment_update();

-- Возврат баланса при удалении оплаты
CREATE OR REPLACE FUNCTION handle_payment_delete()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE students
  SET prepaid_lessons_count = prepaid_lessons_count - OLD.lessons_count
  WHERE id = OLD.student_id;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER handle_payment_delete_trigger
  BEFORE DELETE ON payments
  FOR EACH ROW EXECUTE FUNCTION handle_payment_delete();

-- Автоматическое создание профиля при регистрации
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, full_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Автоматическое добавление владельца в members при создании заведения
CREATE OR REPLACE FUNCTION handle_institution_created()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO institution_members (institution_id, user_id, role_name, permissions)
  VALUES (
    NEW.id,
    NEW.owner_id,
    'Владелец',
    '{
      "manage_institution": true,
      "manage_rooms": true,
      "manage_members": true,
      "manage_subjects": true,
      "manage_students": true,
      "manage_groups": true,
      "manage_lesson_types": true,
      "manage_payment_plans": true,
      "create_lessons": true,
      "edit_own_lessons": true,
      "edit_all_lessons": true,
      "delete_lessons": true,
      "view_all_schedule": true,
      "manage_payments": true,
      "view_payments": true,
      "view_statistics": true,
      "archive_data": true
    }'::jsonb
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_institution_created
  AFTER INSERT ON institutions
  FOR EACH ROW EXECUTE FUNCTION handle_institution_created();

-- 10. REALTIME
-- ============================================

ALTER PUBLICATION supabase_realtime ADD TABLE lessons;
ALTER PUBLICATION supabase_realtime ADD TABLE students;
ALTER PUBLICATION supabase_realtime ADD TABLE rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE payments;

-- ============================================
-- ГОТОВО! База данных настроена.
-- ============================================
