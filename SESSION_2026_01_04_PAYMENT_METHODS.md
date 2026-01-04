# SESSION 2026-01-04: Способы оплаты (Payment Methods)

## Обзор

Добавлена функциональность разделения оплат на два способа: **Карта** и **Наличные**. Реализованы фильтрация, статистика и улучшения UI форм.

---

## Выполненные задачи

### 1. База данных и модель

#### 1.1 Миграция БД
**Файл:** `supabase/migrations/add_payment_method.sql`

```sql
-- Добавляем колонку payment_method
ALTER TABLE payments
ADD COLUMN IF NOT EXISTS payment_method TEXT NOT NULL DEFAULT 'cash';

-- CHECK constraint для валидации
ALTER TABLE payments
ADD CONSTRAINT check_payment_method CHECK (payment_method IN ('cash', 'card'));

-- Индекс для фильтрации
CREATE INDEX IF NOT EXISTS idx_payments_payment_method ON payments(payment_method);
```

#### 1.2 Модель Payment
**Файл:** `lib/shared/models/payment.dart`

Добавлено:
```dart
final String paymentMethod; // 'cash' или 'card'

/// Оплата наличными?
bool get isCash => paymentMethod == 'cash';

/// Оплата картой?
bool get isCard => paymentMethod == 'card';

/// Отображаемое название способа оплаты
String get paymentMethodLabel => isCard ? 'Карта' : 'Наличные';
```

---

### 2. Репозиторий и контроллер

#### 2.1 PaymentRepository
**Файл:** `lib/features/payments/repositories/payment_repository.dart`

Обновлены методы:
- `create()` — добавлен параметр `String paymentMethod = 'cash'`
- `createCorrection()` — добавлен параметр `String paymentMethod = 'cash'`
- `update()` — возможность изменения `paymentMethod`

#### 2.2 PaymentController
**Файл:** `lib/features/payments/providers/payment_provider.dart`

Обновлены методы:
- `create()` — пробрасывает `paymentMethod`
- `createCorrection()` — пробрасывает `paymentMethod`
- `createFamilyPayment()` — пробрасывает `paymentMethod`

---

### 3. Формы добавления оплаты

#### 3.1 Экран оплат
**Файл:** `lib/features/payments/screens/payments_screen.dart`

В `_AddPaymentSheet` добавлен `SegmentedButton`:
```dart
SegmentedButton<String>(
  segments: const [
    ButtonSegment(value: 'card', label: Text('Карта')),
    ButtonSegment(value: 'cash', label: Text('Наличные')),
  ],
  selected: {_paymentMethod},
  onSelectionChanged: (Set<String> selected) {
    setState(() => _paymentMethod = selected.first);
  },
  style: const ButtonStyle(visualDensity: VisualDensity.compact),
)
```

**Порядок:** Карта первая, Наличные вторая
**Default:** `'card'`

#### 3.2 Карточка ученика
**Файл:** `lib/features/students/screens/student_detail_screen.dart`

Аналогичный `SegmentedButton` добавлен в форму оплаты ученика.

---

### 4. Отображение способа оплаты

#### 4.1 Карточка оплаты
В `_PaymentCard` добавлена иконка:
- Карта: `Icons.credit_card` (синий)
- Наличные: `Icons.payments_outlined` (зелёный)

#### 4.2 Детали оплаты
В BottomSheet деталей оплаты показывается способ оплаты.

#### 4.3 Редактирование оплаты
В диалоге редактирования добавлена возможность изменить способ оплаты.

---

### 5. Фильтр по способу оплаты

**Файл:** `lib/features/payments/screens/payments_screen.dart`

Добавлена кнопка "Способ" в горизонтальный список фильтров:
- При нажатии — BottomSheet с чекбоксами
- Опции: Все, Карта, Наличные
- Мультиселект (можно выбрать оба)
- Активный фильтр подсвечивается синей рамкой

Логика фильтрации:
```dart
if (_selectedPaymentMethods.isNotEmpty) {
  filtered = filtered.where((p) =>
    _selectedPaymentMethods.contains(p.paymentMethod)
  ).toList();
}
```

---

### 6. Статистика по способам оплаты

#### 6.1 Вкладка "Общие"
**Файл:** `lib/features/statistics/screens/statistics_screen.dart`

Добавлена секция "Способы оплаты":
- Сумма картой / наличными
- Количество оплат каждым способом
- Проценты от общего количества

Модель `GeneralStats` расширена:
```dart
final double cashTotal;
final double cardTotal;
final int cashCount;
final int cardCount;
```

#### 6.2 Вкладка "Тарифы"
**Файл:** `lib/features/statistics/repositories/statistics_repository.dart`

Модель `PaymentPlanStats` расширена:
```dart
final double cashTotal;
final double cardTotal;
final int cashCount;
final int cardCount;
```

Для каждого тарифа показывается разбивка по способам оплаты.

---

### 7. UI улучшения

#### 7.1 DraggableScrollableSheet
Форма добавления оплаты теперь использует `DraggableScrollableSheet`:
- Свайп по любой области закрывает sheet
- Синхронизация скролла с размером sheet
- Параметры: `initialChildSize: 0.9`, `minChildSize: 0.5`, `maxChildSize: 0.95`

#### 7.2 FAB прокрутки вниз
Добавлен FloatingActionButton со стрелкой вниз:
- Появляется когда есть куда скроллить
- Скрывается когда пользователь почти внизу (< 50px)
- При нажатии — плавная анимация к низу (300ms)
- Позиция: правый нижний угол (16px от краёв)

#### 7.3 Адаптивность для маленьких экранов
Для предотвращения overflow:
- Убраны `prefixIcon` из полей "Занятий", "Срок (дн.)", "Тариф"
- Добавлен `isDense: true` для компактности
- Добавлен `isExpanded: true` для Dropdown
- Убраны иконки из SegmentedButton (только текст)
- Уменьшены отступы между элементами

---

## Изменённые файлы

| Файл | Изменения |
|------|-----------|
| `supabase/migrations/add_payment_method.sql` | Новый файл миграции |
| `lib/shared/models/payment.dart` | Поле `paymentMethod`, геттеры |
| `lib/features/payments/repositories/payment_repository.dart` | Параметр `paymentMethod` в методах |
| `lib/features/payments/providers/payment_provider.dart` | Параметр `paymentMethod` в контроллере |
| `lib/features/payments/screens/payments_screen.dart` | Форма, фильтр, отображение, DraggableScrollableSheet, FAB |
| `lib/features/students/screens/student_detail_screen.dart` | SegmentedButton в форме оплаты |
| `lib/features/statistics/repositories/statistics_repository.dart` | Расширение `GeneralStats`, `PaymentPlanStats` |
| `lib/features/statistics/screens/statistics_screen.dart` | UI статистики по способам |
| `DATABASE.md` | Документация поля `payment_method` |
| `CLAUDE.md` | Секции 29-32 о новых паттернах |

---

## Обратная совместимость

- Default значение `'cash'` для всех существующих оплат
- Миграция не ломает существующие данные
- UI работает корректно если поле отсутствует (fallback на 'cash')
- Фильтр пустой по умолчанию (показываются все оплаты)

---

## Технические решения

### Почему DraggableScrollableSheet?
**Проблема:** Обычный BottomSheet с `SingleChildScrollView` не закрывался свайпом — ScrollView перехватывал жесты.

**Решение:** `DraggableScrollableSheet` синхронизирует скролл контента с размером sheet через `scrollController`.

### Почему FAB для прокрутки?
**Проблема:** На длинных формах пользователь не видит кнопку "Добавить" внизу.

**Решение:** FAB со стрелкой вниз подсказывает, что нужно прокрутить, и автоматически прокручивает при нажатии.

### Почему isDense и без prefixIcon?
**Проблема:** На маленьких экранах (Small Phone) элементы вызывали overflow.

**Решение:** Убрать иконки и использовать компактные поля экономит место без потери функциональности.

---

## Тестирование

- [x] Создание оплаты картой
- [x] Создание оплаты наличными
- [x] Изменение способа при редактировании
- [x] Фильтрация по способу оплаты
- [x] Статистика на вкладке "Общие"
- [x] Статистика на вкладке "Тарифы"
- [x] Свайп закрытия формы
- [x] FAB прокрутки вниз
- [x] Адаптивность на маленьких экранах

---

## Версия

**Build:** 1.0.0+14 → 1.0.0+15 (рекомендуется)
