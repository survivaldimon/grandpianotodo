# Сессия 20.12.2024 — Деплой iOS на TestFlight

## Цель сессии
Настроить сборку и деплой Flutter приложения на реальное iOS устройство через TestFlight без использования Mac.

## Что было сделано

### 1. Настройка Apple Developer Account
- Куплен Apple Developer Account ($99/год)
- Создан Bundle ID: `com.kabinet.kabinet`
- Создано приложение в App Store Connect

### 2. Настройка Codemagic CI/CD
- Создан аккаунт на codemagic.io
- Подключен репозиторий GitHub
- Настроена интеграция с App Store Connect API:
  - Создан API ключ в App Store Connect
  - Загружен .p8 файл в Codemagic
  - Настроены Issuer ID и Key ID

### 3. Конфигурация проекта
- Создан `ios/Podfile` с настройками CocoaPods
- Создан `ci/codemagic/codemagic.yaml` для CI/CD
- Обновлён минимальный iOS до 15.0

### 4. Сборки в TestFlight
| Сборка | Статус | Проблема |
|--------|--------|----------|
| 1.0.0 (1) | Crash | path_provider_foundation |
| 1.0.0 (2) | Crash | path_provider_foundation |
| 1.0.0 (3) | Crash | path_provider_foundation |
| 1.0.0 (4) | Crash | path_provider_foundation (Xcode 26.1 beta!) |
| 1.0.0 (5) | Crash | Xcode 15.4 + Flutter 3.22.3 — всё ещё старые версии |
| 1.0.0 (6) | Pending | Flutter 3.38.1 + Xcode 16.2 — полная поддержка iOS 18 |

## Нерешённая проблема

### path_provider_foundation crash

**Симптомы:**
- Приложение крашится сразу при запуске
- Crash на iOS 18.6.2 и iOS 26.1 beta
- Ошибка в `swift_getObjectType` при регистрации плагина

**Crash log:**
```
Exception Type: EXC_BAD_ACCESS (SIGSEGV)
KERN_INVALID_ADDRESS at 0x0000000000000000

Thread 0 Crashed:
0  libswiftCore.dylib  swift_getObjectType + 40
1  path_provider_foundation  PathProviderPlugin.register
```

**Что пробовали:**
1. `use_frameworks! :linkage => :static` в Podfile — не помогло
2. `dependency_overrides` на версию 2.4.0 — не помогло
3. `dependency_overrides` на версию 2.2.4 — не помогло
4. Увеличение минимальной iOS до 15.0 — не помогло
5. `BUILD_LIBRARY_FOR_DISTRIBUTION = YES` — не помогло
6. EmptyLocalStorage для Supabase — откатили
7. Git версия path_provider — откатили

**Обнаруженная причина:**
Codemagic использовал Xcode 26.1 (BETA!) — это экспериментальная версия для iOS 26/macOS Tahoe. Бета-версии Xcode часто имеют проблемы совместимости с плагинами.

**Решение (сборка 5):**
Переключение на YAML-based workflow с явным указанием:
- `xcode: 15.4` — последний стабильный Xcode
- `flutter: 3.22.3` — стабильная версия Flutter
**Не помогло — Flutter 3.22.3 слишком старый для iOS 18**

**Решение (сборка 6):**
Обновление до последних версий с полной поддержкой iOS 18:
- `flutter: 3.38.1` — последняя стабильная с iOS 18 support
- `xcode: 16.2` — стабильный Xcode для iOS 18
- Удалены dependency_overrides (новые версии должны работать)
- Обновлён SDK constraint: `^3.8.0`

## Текущее состояние проекта

### pubspec.yaml
```yaml
version: 1.0.0+6
sdk: ^3.8.0
# dependency_overrides удалены — используем актуальные версии
```

### codemagic.yaml (в корне проекта)
```yaml
environment:
  flutter: 3.38.1  # Последняя стабильная с полной поддержкой iOS 18
  xcode: 16.2      # Стабильный Xcode для iOS 18
```

### ios/Podfile
- platform: iOS 15.0
- use_frameworks!
- ENABLE_BITCODE = NO

### ios/Runner.xcodeproj
- IPHONEOS_DEPLOYMENT_TARGET = 15.0

## Файлы созданные в этой сессии

```
codemagic.yaml          # YAML-конфигурация в корне (активна!)
ci/
  codemagic/
    codemagic.yaml      # Шаблон конфигурации CI/CD
    README.md           # Инструкция по настройке

ios/
  Podfile               # Настройки CocoaPods
```

## Следующие шаги

1. **Запустить сборку 5 с YAML-конфигурацией:**
   - Push изменений в GitHub
   - В Codemagic выбрать workflow `ios-release`
   - Проверить что используется Xcode 15.4

2. **Если сборка 5 не поможет:**
   - Попробовать Xcode 16.0 вместо 15.4
   - Попробовать Flutter 3.24.x
   - Связаться с поддержкой Codemagic

## Полезные ссылки

- [Apple Developer Portal](https://developer.apple.com/account)
- [App Store Connect](https://appstoreconnect.apple.com)
- [Codemagic](https://codemagic.io)
- [path_provider issues](https://github.com/flutter/packages/issues?q=path_provider_foundation)
