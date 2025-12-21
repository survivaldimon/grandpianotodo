# Codemagic CI/CD для Kabinet

## Статус

| Платформа | Сборка | Публикация | Работает |
|-----------|--------|------------|----------|
| Android | APK/AAB | Artifacts | Да |
| iOS | IPA | TestFlight | Да (но crash) |

## Быстрый старт

### 1. Codemagic
1. Зарегистрируйтесь на [codemagic.io](https://codemagic.io)
2. Подключите GitHub репозиторий
3. Настройте App Store Connect интеграцию

### 2. App Store Connect API
1. Откройте [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Users and Access → Integrations → App Store Connect API
3. Создайте ключ с ролью Admin
4. Скачайте .p8 файл (можно только 1 раз!)
5. Запомните Issuer ID и Key ID

### 3. Настройка в Codemagic
1. App settings → Code signing → iOS
2. Выберите "Automatic"
3. Distribution type: `app_store`
4. Bundle ID: `com.kabinet.kabinet`

### 4. App Store Connect интеграция
1. App settings → App Store Connect
2. Загрузите .p8 файл
3. Введите Issuer ID и Key ID

### 5. Запуск сборки
1. Start new build
2. Выберите ветку `main`
3. Ждите ~15-20 минут

## Конфигурация

Файл `codemagic.yaml` **не используется** — настройки через UI Codemagic.

Если нужен yaml-based workflow:
```bash
cp ci/codemagic/codemagic.yaml ./codemagic.yaml
```

## Известные проблемы

### iOS Crash при запуске

Приложение крашится на iOS 18.x из-за бага в `path_provider_foundation`.

**Статус:** Не решено

**Workaround в pubspec.yaml:**
```yaml
dependency_overrides:
  path_provider: 2.0.15
  path_provider_foundation: 2.2.4
```

## Увеличение номера сборки

Перед каждой новой сборкой в TestFlight:
```yaml
# pubspec.yaml
version: 1.0.0+5  # Увеличить +N
```

## Лимиты Codemagic (бесплатно)

| Ресурс | Лимит |
|--------|-------|
| Время сборки | 500 минут/месяц |
| Параллельные сборки | 1 |
| M1 Mac mini | Включено |

## Troubleshooting

### Build number already used
```
The bundle version must be higher than the previously uploaded version
```
**Решение:** Увеличьте номер в `pubspec.yaml`: `1.0.0+N`

### Code signing failed
Проверьте:
1. Bundle ID совпадает с App Store Connect
2. .p8 ключ загружен
3. Issuer ID и Key ID верные

### Publishing failed
Проверьте:
1. Приложение создано в App Store Connect
2. Интеграция настроена в Codemagic
