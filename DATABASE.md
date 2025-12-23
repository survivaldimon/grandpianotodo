# DATABASE.md — Схема базы данных Supabase

## Обзор

База данных Kabinet использует PostgreSQL через Supabase с Row Level Security (RLS) для изоляции данных между заведениями.

## ER-диаграмма (упрощённая)

```
┌─────────────┐       ┌──────────────────────┐       ┌─────────────┐
│   users     │───┐   │ institution_members  │   ┌───│ institutions│
│             │   └──►│                      │◄──┘   │             │
│ id (auth)   │       │ user_id              │       │ id          │
│ email       │       │ institution_id       │       │ name        │
│ full_name   │       │ permissions (JSON)   │       │ invite_code │
└──────┬──────┘       │ role_name            │       │ owner_id    │
       │              └──────────────────────┘       └──────┬──────┘
       │                                                    │
       │    ┌───────────────────────┐                       │
       │    │   teacher_subjects    │                       │
       └───►│                       │◄──────────────────────┤
            │ user_id               │                       │
            │ subject_id            │       ┌───────────────┴───────────────┐
            └───────────┬───────────┘       │                               │
                        │                   │                               │
                        ▼                   ▼                               │
              ┌─────────────────┐   ┌───────────────┐                       │
              │    subjects     │   │    rooms      │                       │
              │                 │   │               │                       │
              │ id              │   │ id            │                       │
              │ institution_id  │   │ institution_id│                       │
              │ name            │   │ name          │                       │
              └────────┬────────┘   │ number        │                       │
                       │            │ archived_at   │                       │
                       │            └───────┬───────┘                       │
                       │                    │                               │
        ┌──────────────┼────────────────────┼───────────────────────────────┤
        │              │                    │                               │
        │              │                    │                               │
        ▼              ▼                    ▼                               ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────────────┐   ┌────────────────────┐
│    rooms      │   │   students    │   │    student_groups     │   │    lesson_types    │
│               │   │               │   │                       │   │                    │
│ id            │   │ id            │   │ id                    │   │ id                 │
│ institution_id│   │ institution_id│   │ institution_id        │   │ institution_id     │
│ name          │   │ name          │   │ name                  │   │ name               │
│ number        │   │ phone         │   │ comment               │   │ default_duration   │
│ archived_at   │   │ comment       │   │ archived_at           │   │ default_price      │
└───────┬───────┘   │ prepaid_count │   └───────────┬───────────┘   │ is_group           │
        │           │ archived_at   │               │               │ archived_at        │
        │           └───────┬───────┘               │               └─────────┬──────────┘
        │                   │                       │                         │
        │                   │         ┌─────────────┴────────────┐            │
        │                   │         │ student_group_members    │            │
        │                   │         │                          │            │
        │                   └────────►│ group_id                 │            │
        │                             │ student_id               │            │
        │                             └──────────────────────────┘            │
        │                                                                     │
        │           ┌─────────────────────────────────────────────────────────┘
        │           │
        ▼           ▼
┌───────────────────────────────────────────────────────────┐
│                        lessons                            │
│                                                           │
│ id                                                        │
│ institution_id                                            │
│ room_id ──────────────────────────────────────────────────┤
│ teacher_id (user_id) ─────────────────────────────────────┤
│ subject_id ───────────────────────────────────────────────┤
│ lesson_type_id ───────────────────────────────────────────┤
│ student_id (nullable, для индивидуальных) ────────────────┤
│ group_id (nullable, для групповых) ───────────────────────┤
│ date                                                      │
│ start_time                                                │
│ end_time                                                  │
│ status (scheduled/completed/cancelled/rescheduled)        │
│ comment                                                   │
│ archived_at                                               │
└─────────────────────────────┬─────────────────────────────┘
                              │
        ┌─────────────────────┴─────────────────────┐
        ▼                                           ▼
┌───────────────────────┐               ┌───────────────────────────┐
│   lesson_students     │               │     lesson_history        │
│   (для групповых)     │               │                           │
│                       │               │ id                        │
│ lesson_id             │               │ lesson_id                 │
│ student_id            │               │ changed_by (user_id)      │
│ attended (bool)       │               │ changed_at                │
└───────────────────────┘               │ field_name                │
                                        │ old_value                 │
                                        │ new_value                 │
                                        └───────────────────────────┘

┌───────────────────────┐       ┌───────────────────────┐
│    payment_plans      │       │       payments        │
│                       │       │                       │
│ id                    │       │ id                    │
│ institution_id        │       │ institution_id        │
│ name                  │◄──────│ payment_plan_id       │
│ price                 │       │ student_id            │
│ lessons_count         │       │ amount                │
│ archived_at           │       │ lessons_count         │
└───────────────────────┘       │ paid_at               │
                                │ recorded_by (user_id) │
                                │ comment               │
                                └───────────────────────┘
```

## Таблицы

### users (расширение auth.users)

```sql
-- Используем встроенную таблицу auth.users
-- Дополнительные поля храним в profiles

CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### institutions

```sql
CREATE TABLE institutions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  owner_id UUID NOT NULL REFERENCES auth.users(id),
  invite_code TEXT UNIQUE NOT NULL DEFAULT generate_invite_code(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  archived_at TIMESTAMPTZ
);

-- Функция генерации invite code
CREATE OR REPLACE FUNCTION generate_invite_code()
RETURNS TEXT AS $$
BEGIN
  RETURN upper(substr(md5(random()::text), 1, 8));
END;
$$ LANGUAGE plpgsql;
```

### institution_members

```sql
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
```

### rooms

```sql
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
```

### students

```sql
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
```

### student_groups

```sql
CREATE TABLE student_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  archived_at TIMESTAMPTZ
);

CREATE TABLE student_group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES student_groups(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(group_id, student_id)
);
```

### subjects (Предметы/Направления)

```sql
CREATE TABLE subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT, -- HEX цвет для отображения
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  archived_at TIMESTAMPTZ
);

-- Связь преподавателей с предметами (many-to-many)
CREATE TABLE teacher_subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, subject_id)
);

CREATE INDEX idx_teacher_subjects_user ON teacher_subjects(user_id);
CREATE INDEX idx_teacher_subjects_subject ON teacher_subjects(subject_id);

-- Связь учеников с преподавателями (many-to-many)
CREATE TABLE student_teachers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(student_id, user_id)
);

CREATE INDEX idx_student_teachers_student ON student_teachers(student_id);
CREATE INDEX idx_student_teachers_user ON student_teachers(user_id);

-- Связь учеников с предметами (many-to-many)
CREATE TABLE student_subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(student_id, subject_id)
);

CREATE INDEX idx_student_subjects_student ON student_subjects(student_id);
CREATE INDEX idx_student_subjects_subject ON student_subjects(subject_id);
```

### lesson_types

```sql
CREATE TABLE lesson_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  default_duration_minutes INT NOT NULL DEFAULT 60,
  default_price DECIMAL(10, 2),
  is_group BOOLEAN NOT NULL DEFAULT FALSE,
  color TEXT, -- HEX цвет для отображения в расписании
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  archived_at TIMESTAMPTZ
);
```

### lessons

```sql
CREATE TYPE lesson_status AS ENUM ('scheduled', 'completed', 'cancelled', 'rescheduled');

CREATE TABLE lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id),
  teacher_id UUID NOT NULL REFERENCES auth.users(id),
  subject_id UUID REFERENCES subjects(id),  -- Предмет занятия
  lesson_type_id UUID REFERENCES lesson_types(id),
  
  -- Для индивидуальных занятий
  student_id UUID REFERENCES students(id),
  
  -- Для групповых занятий
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
  
  -- Либо student_id, либо group_id должен быть заполнен
  CONSTRAINT lesson_participant CHECK (
    (student_id IS NOT NULL AND group_id IS NULL) OR
    (student_id IS NULL AND group_id IS NOT NULL)
  )
);

-- Индексы для быстрого поиска
CREATE INDEX idx_lessons_room_date ON lessons(room_id, date);
CREATE INDEX idx_lessons_teacher_date ON lessons(teacher_id, date);
CREATE INDEX idx_lessons_institution_date ON lessons(institution_id, date);
```

### lesson_students (для групповых занятий)

```sql
CREATE TABLE lesson_students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id),
  attended BOOLEAN NOT NULL DEFAULT TRUE, -- Присутствовал или пропустил
  
  UNIQUE(lesson_id, student_id)
);
```

### lesson_history

```sql
CREATE TABLE lesson_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  changed_by UUID NOT NULL REFERENCES auth.users(id),
  changed_at TIMESTAMPTZ DEFAULT NOW(),
  action TEXT NOT NULL, -- 'created', 'updated', 'status_changed', 'archived'
  changes JSONB NOT NULL -- {"field": {"old": "...", "new": "..."}, ...}
);

CREATE INDEX idx_lesson_history_lesson ON lesson_history(lesson_id);
```

### payment_plans

```sql
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
```

### payments

```sql
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id),
  payment_plan_id UUID REFERENCES payment_plans(id),
  amount DECIMAL(10, 2) NOT NULL,        -- Может быть отрицательным для корректировок
  lessons_count INT NOT NULL,             -- Может быть отрицательным для корректировок
  is_correction BOOLEAN NOT NULL DEFAULT FALSE,  -- Флаг корректирующей записи
  correction_reason TEXT,                 -- Причина корректировки (обязательна если is_correction=true)
  paid_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  recorded_by UUID NOT NULL REFERENCES auth.users(id),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Причина корректировки обязательна для корректирующих записей
  CONSTRAINT correction_requires_reason CHECK (
    is_correction = FALSE OR correction_reason IS NOT NULL
  )
);

CREATE INDEX idx_payments_student ON payments(student_id);
CREATE INDEX idx_payments_institution_date ON payments(institution_id, paid_at);
```

## Row Level Security (RLS)

### Принцип

Пользователь видит только данные заведений, в которых он состоит (через `institution_members`).

### Базовая политика

```sql
-- Включаем RLS для всех таблиц
ALTER TABLE institutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE institution_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
-- ... и так далее для всех таблиц

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
```

### Политики для institutions

```sql
-- Чтение: члены заведения
CREATE POLICY "Members can view institution"
  ON institutions FOR SELECT
  USING (is_member_of(id) OR owner_id = auth.uid());

-- Создание: любой авторизованный пользователь
CREATE POLICY "Users can create institutions"
  ON institutions FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

-- Обновление: только с правом manage_institution
CREATE POLICY "Admins can update institution"
  ON institutions FOR UPDATE
  USING (has_permission(id, 'manage_institution') OR owner_id = auth.uid());
```

### Политики для rooms

```sql
-- Чтение: члены заведения
CREATE POLICY "Members can view rooms"
  ON rooms FOR SELECT
  USING (is_member_of(institution_id));

-- Создание/обновление: с правом manage_rooms
CREATE POLICY "Can manage rooms"
  ON rooms FOR ALL
  USING (has_permission(institution_id, 'manage_rooms'));
```

### Политики для lessons

```sql
-- Чтение: все члены видят всё расписание
CREATE POLICY "Members can view all lessons"
  ON lessons FOR SELECT
  USING (is_member_of(institution_id));

-- Создание: с правом create_lessons
CREATE POLICY "Can create lessons"
  ON lessons FOR INSERT
  WITH CHECK (has_permission(institution_id, 'create_lessons'));

-- Обновление своих: с правом edit_own_lessons
CREATE POLICY "Can edit own lessons"
  ON lessons FOR UPDATE
  USING (
    teacher_id = auth.uid() AND has_permission(institution_id, 'edit_own_lessons')
  );

-- Обновление всех: с правом edit_all_lessons
CREATE POLICY "Can edit all lessons"
  ON lessons FOR UPDATE
  USING (has_permission(institution_id, 'edit_all_lessons'));

-- Удаление (архивация): с правом delete_lessons
CREATE POLICY "Can delete lessons"
  ON lessons FOR DELETE
  USING (has_permission(institution_id, 'delete_lessons'));
```

## Триггеры

### Автоматическое обновление updated_at

```sql
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Применяем ко всем таблицам с updated_at
CREATE TRIGGER update_institutions_updated_at
  BEFORE UPDATE ON institutions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ... аналогично для других таблиц
```

### Запись истории изменений занятий

```sql
CREATE OR REPLACE FUNCTION log_lesson_changes()
RETURNS TRIGGER AS $$
DECLARE
  changes JSONB := '{}';
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO lesson_history (lesson_id, changed_by, action, changes)
    VALUES (NEW.id, NEW.created_by, 'created', to_jsonb(NEW));
  ELSIF TG_OP = 'UPDATE' THEN
    -- Собираем изменённые поля
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
```

### Списание предоплаченных занятий

```sql
CREATE OR REPLACE FUNCTION handle_lesson_completion()
RETURNS TRIGGER AS $$
BEGIN
  -- При завершении или отмене занятия списываем предоплату
  IF NEW.status IN ('completed', 'cancelled') AND OLD.status = 'scheduled' THEN
    -- Для индивидуального занятия
    IF NEW.student_id IS NOT NULL THEN
      UPDATE students
      SET prepaid_lessons_count = prepaid_lessons_count - 1
      WHERE id = NEW.student_id;
    END IF;

    -- Для группового занятия — списываем у всех присутствовавших
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
```

### Добавление предоплаченных занятий при оплате

```sql
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
```

## Realtime

Включаем realtime для ключевых таблиц:

```sql
-- В Supabase Dashboard или через SQL
ALTER PUBLICATION supabase_realtime ADD TABLE lessons;
ALTER PUBLICATION supabase_realtime ADD TABLE students;
ALTER PUBLICATION supabase_realtime ADD TABLE rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE payments;
```

## Индексы для производительности

```sql
-- Часто используемые запросы
CREATE INDEX idx_institution_members_user ON institution_members(user_id) WHERE archived_at IS NULL;
CREATE INDEX idx_students_institution ON students(institution_id) WHERE archived_at IS NULL;
CREATE INDEX idx_rooms_institution ON rooms(institution_id) WHERE archived_at IS NULL;
CREATE INDEX idx_lessons_date_range ON lessons(institution_id, date, start_time) WHERE archived_at IS NULL;
CREATE INDEX idx_payments_date ON payments(institution_id, paid_at DESC);
```
