# Firebase-синхронизация Kaze

В приложении уже есть незаконченная, но рабочая основа для Firebase Auth и Firestore. Главная цель следующего этапа - сделать так, чтобы аккаунт и прогресс пользователя надежно жили не только на телефоне.

## Текущий проект

Firebase project id: `kazerunner`

Локально добавлены файлы:

- `.firebaserc`
- `firebase.json`
- `firestore.rules`

После входа в Firebase CLI правила можно отправить в проект командой:

```powershell
firebase deploy --only firestore:rules
```

Статус: правила Firestore уже задеплоены в `kazerunner` 2026-05-24.
Debug SHA-1/SHA-256 для Android app добавлены, а `google-services.json`
обновлен после добавления SHA.

## Что уже есть в коде

- `CloudAccountService` в `lib/main.dart`
- Инициализация Firebase через `Firebase.initializeApp()`
- Безопасный fallback на локальное хранение, если Firebase недоступен
- Регистрация/вход по email и паролю
- Вход через Google
- Вход через Apple
- Загрузка удаленных данных при старте приложения
- Сохранение `AppData` в Firestore
- Сохранение краткого профиля и счетчиков в `users/{uid}`
- Локальное сохранение через `SharedPreferences`
- 30-дневный срок хранения через поле `expiresAt`

Текущий путь в Firestore:

```text
users/{uid}/appState/current
```

Текущий документ хранит:

```text
data      - все состояние приложения AppData
summary   - короткая сводка для удобного просмотра в Firebase Console
updatedAt - серверное время последнего сохранения
expiresAt - дата, после которой документ можно удалить по TTL
```

Дополнительно документ `users/{uid}` хранит email, имя, краткий профиль,
провайдеры входа, счетчики тренировок/пробежек/питания и время последней
синхронизации.

## Какие данные сейчас могут синхронизироваться

Так как в Firestore сохраняется весь `AppData`, туда могут попадать:

- профиль пользователя;
- созданные тренировки;
- завершенные тренировки;
- пробежки;
- блюда и БЖУ;
- достижения, если они входят в `AppData`;
- история чатов Kaze.

## Что нужно доделать

1. Проверить, что Firebase-конфиги подключены для всех платформ:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
   - `lib/firebase_options.dart`, если используется FlutterFire CLI

2. Включить провайдеры входа в Firebase Console:
   - Email/Password
   - Google
   - Apple

3. Для Google-входа на Android добавить SHA-1 и SHA-256 ключи в Firebase Console.

4. Создать Firestore Database и добавить правила доступа:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    match /users/{userId} {
      allow read, create, update, delete: if isOwner(userId);

      match /appState/{docId} {
        allow read, create, update, delete: if isOwner(userId);
      }
    }
  }
}
```

5. Включить TTL по полю `expiresAt` для collection group `appState`, если действительно нужен срок хранения около месяца.

6. Добавить в интерфейс понятный статус синхронизации:
   - сохранено локально;
   - синхронизировано;
   - нет сети;
   - ошибка входа;
   - ошибка сохранения.

7. Добавить восстановление доступа:
   - сброс пароля;
   - выход из аккаунта;
   - повторный вход на другом устройстве.

8. Решить стратегию конфликта данных:
   - сейчас проще всего считать Firestore источником истины при входе;
   - если локальные данные новее удаленных, нужно показывать выбор: оставить локальные, загрузить облачные или объединить.

## Что потребуется от владельца проекта

- Доступ к Firebase Console.
- Подтверждение package name Android и bundle id iOS.
- Включенные Auth-провайдеры.
- SHA-1/SHA-256 для Android-сборок.
- Решение по сроку хранения: удалять данные через 30 дней или хранить весь срок жизни аккаунта.
- Решение по модели данных: один общий документ `AppData` сейчас или отдельные коллекции для тренировок, питания, пробежек и достижений.

## Рекомендованная модель на будущее

Для MVP можно оставить один документ `users/{uid}/appState/current`: это быстрее и проще.

Когда данных станет больше, лучше перейти на структуру:

```text
users/{uid}
users/{uid}/profile/current
users/{uid}/foodEntries/{entryId}
users/{uid}/plannedWorkouts/{workoutId}
users/{uid}/completedWorkouts/{workoutId}
users/{uid}/runs/{runId}
users/{uid}/achievements/{achievementId}
users/{uid}/assistantConversations/{conversationId}
```

Так будет проще синхронизировать отдельные изменения, делать аналитику, пагинацию истории и не перезаписывать весь большой документ при каждом действии.
