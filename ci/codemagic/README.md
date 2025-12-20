# Codemagic CI/CD для Kabinet

## Быстрый старт

### 1. Регистрация в Codemagic
1. Перейдите на [codemagic.io](https://codemagic.io)
2. Войдите через GitHub/GitLab/Bitbucket
3. Добавьте репозиторий Kabinet

### 2. Активация конфигурации
Скопируйте файл конфигурации в корень проекта:
```bash
cp ci/codemagic/codemagic.yaml ./codemagic.yaml
git add codemagic.yaml
git commit -m "Add Codemagic CI/CD configuration"
git push
```

### 3. Настройка email уведомлений
В файле `codemagic.yaml` замените:
```yaml
recipients:
  - your-email@example.com  # ← Ваш email
```

---

## Доступные сборки

| Workflow | Что делает | Требования |
|----------|-----------|------------|
| `android-build` | APK + AAB | Ничего (работает сразу) |
| `ios-build` | IPA файл | Apple Developer Account |
| `test-only` | Тесты + анализ | Ничего |

---

## Android сборка (без Apple Developer)

**Работает сразу после настройки!**

После успешной сборки вы получите:
- `app-debug.apk` — для тестирования
- `app-release.apk` — для распространения
- `app-release.aab` — для Google Play

### Где скачать артефакты
1. Codemagic → Builds → Выберите сборку
2. Вкладка "Artifacts"
3. Скачайте нужный файл

---

## iOS сборка (требует $99/год)

### Что нужно
1. **Apple Developer Account** — [developer.apple.com](https://developer.apple.com)
2. **Сертификат разработчика** (.p12 файл)
3. **Provisioning Profile**

### Настройка в Codemagic
1. Settings → Code signing identities
2. Загрузите iOS сертификаты
3. Codemagic автоматически подпишет приложение

### Подробная инструкция
[docs.codemagic.io/code-signing-yaml/signing-ios](https://docs.codemagic.io/code-signing-yaml/signing-ios/)

---

## Альтернативы без Apple Developer

Если нет $99/год на Apple Developer Account:

### Вариант 1: Sideloadly (Windows)
1. Соберите IPA через Codemagic (нужен хотя бы бесплатный Apple ID)
2. Установите [Sideloadly](https://sideloadly.io)
3. Подключите iPhone к компьютеру
4. Загрузите IPA через Sideloadly

**Минус:** Приложение нужно переустанавливать каждые 7 дней

### Вариант 2: AltStore
1. Установите [AltServer](https://altstore.io) на Windows
2. Установите AltStore на iPhone
3. Загрузите IPA через AltStore

**Минус:** Те же 7 дней

### Вариант 3: Только Android
Пока нет Apple Developer Account, распространяйте APK для Android.
Позже добавите iOS.

---

## Переменные окружения

Если нужны секретные ключи (API ключи и т.д.):

1. Codemagic → App settings → Environment variables
2. Добавьте переменную (например `SUPABASE_KEY`)
3. В коде используйте через `--dart-define`:

```yaml
scripts:
  - name: Сборка с переменными
    script: |
      flutter build apk --release \
        --dart-define=SUPABASE_URL=$SUPABASE_URL \
        --dart-define=SUPABASE_KEY=$SUPABASE_KEY
```

---

## Бесплатные лимиты Codemagic

| Ресурс | Лимит |
|--------|-------|
| Время сборки | 500 минут/месяц |
| M1 Mac mini | Включено |
| Параллельные сборки | 1 |

Для hobby-проекта обычно хватает.

---

## Troubleshooting

### Сборка падает на CocoaPods
```yaml
- name: Очистка и установка pods
  script: |
    cd ios
    rm -rf Pods Podfile.lock
    pod install --repo-update
```

### Ошибка подписи iOS
Проверьте что:
1. Bundle ID в Xcode совпадает с `bundle_identifier` в yaml
2. Provisioning profile включает ваше устройство (для Ad Hoc)
3. Сертификат не истёк

### Flutter версия
Для конкретной версии Flutter:
```yaml
environment:
  flutter: 3.24.0  # вместо stable
```
