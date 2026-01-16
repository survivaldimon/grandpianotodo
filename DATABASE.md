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
│ validity_days         │       │ lessons_count         │
│ color                 │       │ paid_at               │
│ archived_at           │       │ recorded_by (user_id) │
└───────────────────────┘       │ comment               │
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
  work_start_hour INTEGER DEFAULT 8,    -- Начало рабочего времени (0-23)
  work_end_hour INTEGER DEFAULT 22,     -- Конец рабочего времени (1-24)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  archived_at TIMESTAMPTZ,

  CONSTRAINT check_work_start_hour CHECK (work_start_hour >= 0 AND work_start_hour <= 23),
  CONSTRAINT check_work_end_hour CHECK (work_end_hour >= 1 AND work_end_hour <= 24),
  CONSTRAINT check_work_hours_order CHECK (work_end_hour > work_start_hour)
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
  is_admin BOOLEAN DEFAULT FALSE, -- Администратор имеет все права владельца, кроме удаления заведения
  permissions JSONB NOT NULL DEFAULT '{
    "manage_institution": false,
    "manage_rooms": false,
    "manage_members": false,
    "manage_subjects": false,
    "manage_own_students": true,
    "manage_all_students": false,
    "manage_students": true,
    "manage_groups": true,
    "manage_lesson_types": false,
    "manage_payment_plans": false,
    "create_lessons": true,
    "edit_own_lessons": true,
    "edit_all_lessons": false,
    "delete_own_lessons": true,
    "delete_all_lessons": false,
    "delete_lessons": true,
    "view_all_schedule": true,
    "add_payments_for_own_students": true,
    "add_payments_for_all_students": false,
    "manage_payments": false,
    "view_payments": true,
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

  -- Привязка к источнику занятия (для возврата)
  subscription_id UUID REFERENCES subscriptions(id),     -- Подписка с которой списано
  transfer_payment_id UUID REFERENCES payments(id),      -- Balance transfer с которой списано
  is_deducted BOOLEAN DEFAULT FALSE,                     -- Списано ли (для отменённых занятий)
  schedule_id UUID REFERENCES lesson_schedules(id),      -- Виртуальное расписание-источник

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
  subscription_id UUID REFERENCES subscriptions(id), -- ID подписки, с которой списано занятие

  UNIQUE(lesson_id, student_id)
);

-- Индекс для быстрого поиска по подписке
CREATE INDEX idx_lesson_students_subscription_id
ON lesson_students(subscription_id)
WHERE subscription_id IS NOT NULL;
```

**Примечание:** `subscription_id` используется для корректного возврата занятия при снятии статуса "Проведено".

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

### lesson_schedules (виртуальные занятия)

Постоянное расписание занятий. Одна запись = бесконечные виртуальные занятия на все подходящие даты.

```sql
CREATE TABLE lesson_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  student_id UUID REFERENCES students(id) ON DELETE CASCADE,
  group_id UUID REFERENCES student_groups(id) ON DELETE CASCADE,
  subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
  lesson_type_id UUID REFERENCES lesson_types(id) ON DELETE SET NULL,

  -- Расписание (ISO 8601: 1=Пн, 7=Вс)
  day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,

  -- Период действия
  valid_from DATE,           -- NULL = с момента создания
  valid_until DATE,          -- NULL = бессрочно

  -- Пауза
  is_paused BOOLEAN NOT NULL DEFAULT FALSE,
  pause_until DATE,

  -- Временная замена кабинета
  replacement_room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  replacement_until DATE,

  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,

  CONSTRAINT check_student_xor_group CHECK (
    NOT (student_id IS NOT NULL AND group_id IS NOT NULL)
  ),
  CONSTRAINT check_time_range CHECK (end_time > start_time)
);

CREATE INDEX idx_lesson_schedules_institution ON lesson_schedules(institution_id) WHERE archived_at IS NULL;
CREATE INDEX idx_lesson_schedules_student ON lesson_schedules(student_id) WHERE student_id IS NOT NULL AND archived_at IS NULL;
CREATE INDEX idx_lesson_schedules_day ON lesson_schedules(institution_id, day_of_week) WHERE archived_at IS NULL;
```

**Связь с lessons:** Поле `lessons.schedule_id` ссылается на `lesson_schedules.id` — показывает из какого расписания создано реальное занятие.

### lesson_schedule_exceptions

Исключения (пропущенные даты) для постоянного расписания.

```sql
CREATE TABLE lesson_schedule_exceptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES lesson_schedules(id) ON DELETE CASCADE,
  exception_date DATE NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(schedule_id, exception_date)
);

CREATE INDEX idx_schedule_exceptions_date ON lesson_schedule_exceptions(schedule_id, exception_date);
```

**RPC функции:**
```sql
-- Создать реальное занятие из виртуального
create_lesson_from_schedule(p_schedule_id UUID, p_date DATE, p_status TEXT DEFAULT 'completed')
RETURNS UUID

-- Добавить исключение (пропуск даты)
add_schedule_exception(p_schedule_id UUID, p_exception_date DATE, p_reason TEXT DEFAULT NULL)
RETURNS UUID
```

### payment_plans

```sql
CREATE TABLE payment_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  price DECIMAL(10, 2) NOT NULL,
  lessons_count INT NOT NULL,
  validity_days INT DEFAULT 30,
  color TEXT,  -- Цвет тарифа в hex формате (например: '4CAF50')
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
  payment_method TEXT NOT NULL DEFAULT 'cash',  -- Способ оплаты: 'cash' (наличные) или 'card' (карта)
  paid_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  recorded_by UUID NOT NULL REFERENCES auth.users(id),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Balance Transfer (остаток занятий)
  is_balance_transfer BOOLEAN NOT NULL DEFAULT FALSE,  -- Флаг записи переноса остатка
  transfer_lessons_remaining INT,                       -- Остаток занятий (списывается при проведении)

  -- Флаг оплаты с подпиской
  has_subscription BOOLEAN DEFAULT FALSE,  -- Триггер пропускает такие записи

  -- Причина корректировки обязательна для корректирующих записей
  CONSTRAINT correction_requires_reason CHECK (
    is_correction = FALSE OR correction_reason IS NOT NULL
  ),
  -- Способ оплаты только cash или card
  CONSTRAINT check_payment_method CHECK (payment_method IN ('cash', 'card'))
);

-- Индекс для активных переносов баланса
CREATE INDEX idx_payments_active_balance_transfers
ON payments(student_id, is_balance_transfer)
WHERE is_balance_transfer = TRUE AND transfer_lessons_remaining > 0;

CREATE INDEX idx_payments_student ON payments(student_id);
CREATE INDEX idx_payments_institution_date ON payments(institution_id, paid_at);
CREATE INDEX idx_payments_payment_method ON payments(payment_method);
```

### subscriptions

```sql
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  payment_id UUID REFERENCES payments(id) ON DELETE SET NULL,

  -- Занятия
  lessons_total INT NOT NULL CHECK (lessons_total > 0),
  lessons_remaining INT NOT NULL DEFAULT 0,

  -- Сроки действия
  starts_at DATE NOT NULL DEFAULT CURRENT_DATE,
  expires_at DATE NOT NULL,

  -- Заморозка
  is_frozen BOOLEAN NOT NULL DEFAULT FALSE,
  frozen_until DATE,
  frozen_days_total INT NOT NULL DEFAULT 0,

  -- Семейный абонемент
  is_family BOOLEAN NOT NULL DEFAULT FALSE,

  -- Метаданные
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT lessons_remaining_valid CHECK (lessons_remaining >= 0 AND lessons_remaining <= lessons_total),
  CONSTRAINT expires_after_starts CHECK (expires_at >= starts_at)
);

CREATE INDEX idx_subscriptions_student_id ON subscriptions(student_id);
CREATE INDEX idx_subscriptions_institution_id ON subscriptions(institution_id);
CREATE INDEX idx_subscriptions_expires_at ON subscriptions(expires_at) WHERE lessons_remaining > 0;
CREATE INDEX idx_subscriptions_is_frozen ON subscriptions(is_frozen) WHERE is_frozen = TRUE;
```

### subscription_members (для семейных абонементов)

```sql
-- Участники семейного абонемента
-- Позволяет нескольким ученикам делить один пул занятий
CREATE TABLE subscription_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(subscription_id, student_id)
);

CREATE INDEX idx_subscription_members_subscription ON subscription_members(subscription_id);
CREATE INDEX idx_subscription_members_student ON subscription_members(student_id);
```

**Логика семейных абонементов:**
- `is_family = FALSE`: обычный индивидуальный абонемент (student_id обязателен)
- `is_family = TRUE`: семейный абонемент (участники в subscription_members)
- При списании занятия сначала ищется личная подписка, затем семейная
- Все участники делят общий пул занятий (lessons_remaining)

### bookings (Бронирование кабинетов)

```sql
-- Бронирование кабинетов (блокировка для мероприятий)
CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,

  CONSTRAINT booking_end_after_start CHECK (end_time > start_time)
);

CREATE INDEX idx_bookings_institution_date ON bookings(institution_id, date);
CREATE INDEX idx_bookings_date ON bookings(date);
```

### booking_rooms (Связь бронирования с кабинетами)

```sql
-- Связь брони с кабинетами (many-to-many)
-- Позволяет одной бронью заблокировать несколько кабинетов
CREATE TABLE booking_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,

  UNIQUE(booking_id, room_id)
);

CREATE INDEX idx_booking_rooms_room ON booking_rooms(room_id);
CREATE INDEX idx_booking_rooms_booking ON booking_rooms(booking_id);
```

**Логика бронирования:**
- Бронь блокирует кабинеты для создания занятий в указанное время
- При создании занятия проверяется конфликт с бронями через `booking_rooms`
- Одна бронь может включать несколько кабинетов
- Право на создание брони: `createBookings` (по умолчанию `true`)
- Удалить бронь может владелец заведения, администратор или создатель

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

### Политики для institution_members

```sql
-- Чтение: члены заведения
CREATE POLICY "Members can view members"
  ON institution_members FOR SELECT
  USING (is_member_of(institution_id));

-- Обновление своей записи (цвет, направления)
CREATE POLICY "Members can update own color"
  ON institution_members FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Обновление других: владелец или админ
CREATE POLICY "Admins can update members"
  ON institution_members FOR UPDATE
  USING (
    has_permission(institution_id, 'manage_members') OR
    EXISTS (SELECT 1 FROM institutions WHERE id = institution_id AND owner_id = auth.uid())
  );
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

-- Удаление своих занятий: с правом delete_own_lessons
CREATE POLICY "Can delete own lessons"
  ON lessons FOR DELETE
  USING (
    teacher_id = auth.uid() AND has_permission(institution_id, 'delete_own_lessons')
  );

-- Удаление всех занятий: с правом delete_all_lessons
CREATE POLICY "Can delete all lessons"
  ON lessons FOR DELETE
  USING (has_permission(institution_id, 'delete_all_lessons'));

-- Обратная совместимость: с правом delete_lessons (устаревшее)
CREATE POLICY "Can delete lessons (legacy)"
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

> **УДАЛЕНО (2026-01-06):** Триггер `handle_lesson_completion_trigger` удалён, так как вызывал двойное списание.
> Списание теперь управляется из `LessonController.complete()` в Dart коде, который:
> - Сначала проверяет наличие активной подписки
> - Списывает с подписки (lessons_remaining) или из prepaid_lessons_count
> - Сохраняет subscription_id для расчёта стоимости занятия
> - Корректно обрабатывает групповые занятия с проверкой attended
>
> Миграция: `supabase/migrations/remove_lesson_completion_trigger.sql`

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

## RPC функции

### transfer_institution_ownership

Передача прав владельца заведения другому участнику.
Использует `SECURITY DEFINER` для обхода RLS политики.

```sql
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

GRANT EXECUTE ON FUNCTION transfer_institution_ownership(UUID, UUID) TO authenticated;
```

**Вызов из Dart:**
```dart
await _client.rpc('transfer_institution_ownership', params: {
  'p_institution_id': institutionId,
  'p_new_owner_id': newOwnerUserId,
});
```

### deduct_balance_transfer

Списание 1 занятия с самого старого переноса баланса (FIFO).

```sql
CREATE OR REPLACE FUNCTION deduct_balance_transfer(p_student_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  transfer_id UUID;
BEGIN
  -- Находим самую старую запись переноса с остатком (FIFO)
  SELECT id INTO transfer_id
  FROM payments
  WHERE student_id = p_student_id
    AND is_balance_transfer = TRUE
    AND transfer_lessons_remaining > 0
  ORDER BY paid_at ASC
  LIMIT 1
  FOR UPDATE;

  -- Если нашли — списываем 1 занятие
  IF transfer_id IS NOT NULL THEN
    UPDATE payments
    SET transfer_lessons_remaining = transfer_lessons_remaining - 1
    WHERE id = transfer_id;
  END IF;

  RETURN transfer_id;  -- NULL если переносов нет
END;
$$;

GRANT EXECUTE ON FUNCTION deduct_balance_transfer(UUID) TO authenticated;
```

**Вызов из Dart:**
```dart
final result = await _client.rpc('deduct_balance_transfer', params: {
  'p_student_id': studentId,
}).single();
return result as String?;  // payment_id или null
```

### return_balance_transfer_lesson

Возврат 1 занятия на запись переноса баланса.

```sql
CREATE OR REPLACE FUNCTION return_balance_transfer_lesson(p_payment_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE payments
  SET transfer_lessons_remaining = transfer_lessons_remaining + 1
  WHERE id = p_payment_id
    AND is_balance_transfer = TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION return_balance_transfer_lesson(UUID) TO authenticated;
```

**Вызов из Dart:**
```dart
await _client.rpc('return_balance_transfer_lesson', params: {
  'p_payment_id': paymentId,
});
```

---

## Realtime

Включаем realtime для ключевых таблиц:

```sql
-- В Supabase Dashboard или через SQL
ALTER PUBLICATION supabase_realtime ADD TABLE lessons;
ALTER PUBLICATION supabase_realtime ADD TABLE students;
ALTER PUBLICATION supabase_realtime ADD TABLE rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE payments;
ALTER PUBLICATION supabase_realtime ADD TABLE subscriptions;
ALTER PUBLICATION supabase_realtime ADD TABLE subscription_members;  -- Для семейных абонементов
ALTER PUBLICATION supabase_realtime ADD TABLE institutions;          -- Для синхронизации рабочего времени
ALTER PUBLICATION supabase_realtime ADD TABLE institution_members;   -- Для синхронизации прав участников
ALTER PUBLICATION supabase_realtime ADD TABLE bookings;              -- Для бронирования кабинетов
ALTER PUBLICATION supabase_realtime ADD TABLE booking_rooms;         -- Для связи броней с кабинетами
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
