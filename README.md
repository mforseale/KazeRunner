# Kaze Runner

Kaze Runner - мобильное Flutter-приложение для фитнеса, питания, пробежек и персонального AI-ассистента Kaze. Проект объединяет учет профиля пользователя, расчет дневных норм, планирование тренировок, GPS-трекинг бега, журнал питания, достижения, экспорт данных, локальное хранение, Firebase/Firestore-синхронизацию и гибридного ассистента, который может работать локально по rule-based логике или онлайн через LLM-бэкенд.

Документ написан как подробный технический отчет по текущему состоянию проекта: что есть в приложении, какие технологии используются, какие классы и методы отвечают за ключевые части, как устроены данные, где лежит бэкенд, как подключать Firebase/PolzaAI и какие важные решения уже были приняты.

## Краткое Описание

Kaze Runner помогает пользователю вести спортивный и пищевой дневник:

- Создать аккаунт и профиль с ростом, весом, возрастом, полом, целью и количеством тренировок в неделю.
- Хранить данные локально на устройстве и синхронизировать их в Firebase Firestore.
- Смотреть экран активности с готовыми тренировками, календарем, таймером и расходом калорий.
- Вести питание: блюда, калории, белки, жиры, углеводы, воду и дневные цели.
- Записывать пробежки по GPS, видеть маршрут, дистанцию, время и прогресс к марафонской дистанции 42.195 км.
- Открывать профиль, менять аватар, язык, систему единиц и экспортировать данные.
- Общаться с ассистентом Kaze, который видит профиль, цель, норму калорий/БЖУ и последние 7 дней активности.

Визуальная часть проекта строится вокруг образа Kaze, фирменного голубого логотипа, мягких светлых карточек, плотного шрифта Nunito и цветовых акцентов: синий для активности, бирюзовый/зеленоватый для питания, фиолетовый для бега, черный и оранжевый для контраста.

## Структура Проекта

Основной проект находится в папке `kazer`.

```text
kazer/
  android/                         Android-проект Flutter
  ios/                             iOS-проект Flutter
  linux/                           Linux runner
  macos/                           macOS runner
  web/                             Web runner
  windows/                         Windows runner
  lib/
    main.dart                      Основной код приложения
  assets/
    fonts/
      Nunito-VariableFont_wght.ttf Основной кастомный шрифт приложения
    images/                        Фон регистрации, логотип, картинки Kaze
    models/                        TFLite-модели для распознавания еды
  functions/                       Firebase Cloud Functions вариант бэкенда Kaze
  workers/
    kaze-assistant/                Cloudflare Worker для PolzaAI
      src/index.js                 Основной код Worker
      wrangler.toml                Конфигурация Worker
      package.json                 Скрипты deploy/dev
  tools/                           Вспомогательные инструменты проекта
  test/                            Flutter-тесты
  firebase.json                    Firebase конфигурация
  firestore.rules                  Firestore security rules
  pubspec.yaml                     Flutter зависимости, ассеты, шрифты
  README.md                        Этот файл
  FIREBASE_SETUP.md                Заметки по настройке Firebase
  FIREBASE_SYNC_PLAN.md            План синхронизации данных
  KAZE_RULE_BASED_MODEL.md         Описание локального rule-based ассистента
  KAZE_HYBRID_LLM_PLAN.md          План гибридного AI-ассистента
  KAZE_CLOUD_FUNCTIONS_SETUP.md    Альтернативная настройка Firebase Functions
  KAZE_POLZA_WORKER_SETUP.md       Настройка Cloudflare Worker + PolzaAI
```

Важный архитектурный момент: сейчас почти вся мобильная логика находится в одном файле `lib/main.dart`. Это удобно для быстрых итераций, но при дальнейшем росте проекта файл стоит разделить на модули: `models/`, `services/`, `screens/`, `widgets/`, `assistant/`, `firebase/`, `localization/`.

## Основные Технологии

### Flutter и Dart

Приложение написано на Flutter. В `pubspec.yaml` указан SDK Dart `^3.11.5`. UI построен на Material 3 (`useMaterial3: true`) и стандартных Flutter-виджетах.

### Firebase

Используется несколько Firebase-сервисов:

- `firebase_core` - инициализация Firebase.
- `firebase_auth` - регистрация, email/password, Google Sign-In, Apple Sign-In.
- `cloud_firestore` - облачное хранение профиля и пользовательских данных.
- `google-services.json` - Android-конфигурация Firebase.
- `GoogleService-Info.plist` - iOS-конфигурация Firebase.

Firebase Functions также присутствуют в проекте, но для AI-ассистента выбран Cloudflare Worker, потому что Firebase Functions secrets требуют Blaze-план.

### Локальное Хранение

`shared_preferences` хранит сериализованный `AppData` в JSON под ключом `local_user_profile`. Это дает офлайн-работу приложения даже без Firebase или интернета.

### Геолокация и Карты

Для пробежек используются:

- `geolocator` - доступ к GPS, разрешения геолокации, поток координат.
- `flutter_map` - отображение маршрута.
- `latlong2` - координаты для карты.
- `permission_handler` - запрос прав.

### ML Для Питания

Для распознавания еды используются:

- `tflite_flutter` - загрузка и запуск TFLite-моделей.
- `image` - декодирование и подготовка изображения.
- `image_picker` - камера/галерея.

Модели лежат в `assets/models/`:

- `food_model.tflite` - классификация блюда.
- `nutrition_model.tflite` - оценка калорий и БЖУ.

### Экспорт и Обмен Файлами

`share_plus` используется для экспорта пользовательских данных через системное меню отправки/сохранения. Это особенно важно на эмуляторе, где папка приложения приватная и файл нельзя просто найти в обычном файловом менеджере.

### Cloudflare Worker + PolzaAI

Онлайн-ответы Kaze реализованы через Cloudflare Worker:

- Worker принимает запрос от приложения.
- Проверяет Firebase ID token.
- Собирает system prompt и rule-based hint.
- Отправляет запрос в PolzaAI OpenAI-compatible API.
- Возвращает ответ в мобильное приложение.

Endpoint PolzaAI:

```text
https://polza.ai/api/v1/chat/completions
```

Модель по умолчанию:

```text
google/gemini-2.0-flash-lite-001
```

## Запуск Проекта

Перейти в папку приложения:

```powershell
cd D:\KazeRunner\kazer
```

Установить зависимости:

```powershell
D:\Flutter\flutter\bin\flutter.bat pub get
```

Запустить приложение без онлайн-LLM:

```powershell
D:\Flutter\flutter\bin\flutter.bat run
```

Запустить приложение с Cloudflare Worker для Kaze:

```powershell
D:\Flutter\flutter\bin\flutter.bat run --dart-define=KAZE_ASSISTANT_URL=https://kaze-assistant.YOUR_SUBDOMAIN.workers.dev
```

Собрать debug APK:

```powershell
D:\Flutter\flutter\bin\flutter.bat build apk --debug
```

Собрать debug APK с AI endpoint:

```powershell
D:\Flutter\flutter\bin\flutter.bat build apk --debug --dart-define=KAZE_ASSISTANT_URL=https://kaze-assistant.YOUR_SUBDOMAIN.workers.dev
```

## Главный Файл `lib/main.dart`

`main.dart` содержит:

- Точку входа `main()`.
- Enums и extensions.
- Модели данных.
- Локальное хранилище.
- Firebase/Firestore сервис.
- Root-навигацию.
- Экран создания аккаунта.
- Основные экраны приложения.
- UI-компоненты.
- Kaze assistant.
- Алгоритмы норм питания, тренировок, достижений и экспорта.

### Точка Входа

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KazeRunnerApp());
}
```

`WidgetsFlutterBinding.ensureInitialized()` нужен, потому что приложение использует платформенные сервисы: Firebase, SharedPreferences, файлы, permissions, image picker, geolocation.

## Доменные Enums

### `Goal`

Цель пользователя:

- `weightLoss` - похудение.
- `maintain` - поддержание.
- `gainMass` - набор массы.

`GoalX` дает локализованные подписи через `label` и `labelFor(AppLanguage language)`.

### `Gender`

Пол пользователя:

- `male`
- `female`

Используется в расчете BMR/калорий, UI профиля и Firestore summary.

### `WorkoutEmotion`

Оценка завершенной тренировки:

- `great`
- `normal`
- `tired`
- `exhausted`

Используется при завершении тренировки, в истории и Firestore. `WorkoutEmotionX` хранит emoji и локализованные подписи.

### `AppLanguage`

Язык приложения:

- `ru`
- `en`

`AppLanguageX.fromDevice()` автоматически определяет стартовый язык по языку устройства. Если язык устройства начинается с `ru`, выбирается русский, иначе английский.

### `UnitSystem`

Система единиц:

- `metric` - сантиметры, килограммы, километры.
- `imperial` - ft/in, lb, mi.

Сейчас данные внутри приложения все равно хранятся в metric-формате (`heightCm`, `weightKg`, `distanceKm`), а настройка влияет на отображение.

## Локализация

Локализация реализована без ARB-файлов, напрямую в коде:

- `_AppLanguageScope` - `InheritedWidget`, который прокидывает текущий язык вниз по дереву.
- `_L10nContext` - extension на `BuildContext`.
- `context.tr(ru, en)` - быстрый выбор строки.
- `_activeAppLanguage` - глобальный fallback для overlay/dialog routes, где обычный `InheritedWidget` может быть недоступен.

Пример:

```dart
Text(context.tr('Питание', 'Nutrition'))
```

На практике локализация добавлена в основные экраны: создание аккаунта, нижняя навигация, Kaze, питание, тренировки, календарь, достижения, профиль, настройки, экспорт, бег.

## Настройки Приложения

### `AppSettings`

Модель настроек:

- `language`
- `unitSystem`

Ключевые методы:

- `AppSettings.defaults()` - язык из устройства, система единиц metric.
- `toJson()` - сериализация.
- `fromJson(Object? source)` - восстановление из JSON.
- `copyWith(...)` - обновление части настроек.

Настройки сохраняются локально и в Firestore вместе с `AppData`.

## Модели Данных

### `UserProfile`

Профиль пользователя:

- `username`
- `heightCm`
- `weightKg`
- `gender`
- `age`
- `goal`
- `workoutsPerWeek`
- `avatarPath`

Важные методы:

- `toJson()`
- `fromJson(Map<String, dynamic>)`
- `copyWith(...)`

Имя пользователя поддерживает русский ввод. Валидация на экране создания аккаунта не ограничивает имя только латиницей.

### `RoutePoint`

Одна GPS-точка маршрута:

- `lat`
- `lng`

Используется внутри `RunEntry.route`.

### `RunEntry`

Одна пробежка:

- `startedAtIso`
- `durationSeconds`
- `distanceKm`
- `route`

Геттер:

- `startedAt`

Сохраняется локально, в Firestore subcollection `runs`, экспортируется в `kaze_runs.json`.

### `FoodEntry`

Одна запись питания:

- `id`
- `dateIso`
- `name`
- `calories`
- `protein`
- `fat`
- `carbs`
- `waterMl`

Геттер:

- `date`

Сохраняется локально, в Firestore subcollection `foodEntries`, экспортируется в `kaze_nutrition.json`.

### `_FoodVisionResult`

Внутренняя модель результата ML-распознавания еды:

- `foodLabel`
- `confidence`
- `calories`
- `protein`
- `fat`
- `carbs`

Используется только в `FoodScreen`.

### `PlannedExercise`

Одно упражнение в тренировке:

- `name`
- `sets`
- `reps`

Сохраняется внутри плановой и завершенной тренировки.

### `PlannedWorkout`

Запланированная тренировка:

- `id`
- `createdAtIso`
- `plannedDateIso`
- `exercises`

Геттеры:

- `createdAt`
- `plannedDate`

Поддерживает редактирование даты, упражнений, подходов и повторений.

### `CompletedWorkout`

Завершенная тренировка:

- `completedAtIso`
- `durationSeconds`
- `emotion`
- `exercises`

Геттер:

- `completedAt`

Сохраняет не просто факт тренировки, а подробный состав: упражнения, подходы, повторения, длительность и эмоциональную оценку.

### `AssistantMessage`

Сообщение в чате Kaze:

- `role` - `user` или `assistant`.
- `text`
- `createdAtIso`

### `AssistantConversation`

Отдельный чат Kaze:

- `id`
- `title`
- `createdAtIso`
- `updatedAtIso`
- `messages`

Поддерживается история чатов и создание нового чата.

### `AppData`

Главное состояние приложения:

- `profile`
- `settings`
- `totalWorkouts`
- `workoutDays`
- `runDays`
- `runs`
- `foodEntries`
- `plannedWorkouts`
- `rememberedExerciseSets`
- `completedWorkouts`
- `assistantConversations`

`AppData` - центральная модель приложения. Именно она сохраняется в `SharedPreferences`, отправляется в Firestore и передается в Kaze assistant как контекст.

Методы:

- `toJson()`
- `fromJson(Map<String, dynamic>)`
- `copyWith(...)`

`fromJson()` содержит миграционную совместимость со старым форматом: если раньше был `activeWorkout`, он переносится в `plannedWorkouts`.

## Локальное Хранение

### `LocalAppStorage`

Сервис локального хранения:

- `_key = 'local_user_profile'`
- `loadData()`
- `saveData(AppData data)`
- `clearData()`

Хранение реализовано через `SharedPreferences`. Данные сериализуются в JSON. Если найден старый формат, где сохранен только профиль без `AppData`, он преобразуется в новый формат с пустыми списками тренировок, питания, пробежек и чатов.

## Firebase И Firestore

### `CloudAccountService`

Класс отвечает за Firebase initialization, авторизацию и Firestore-синхронизацию.

Ключевые поля:

- `retention = Duration(days: 30)` - текущий срок хранения appState.
- `_schemaVersion = 1`
- `_collection = 'users'`
- `_stateCollection = 'appState'`
- `_stateDoc = 'current'`
- `_available` - доступен ли Firebase.
- `_googleSignInInitialized` - инициализирован ли Google Sign-In.

Ключевые методы:

- `initialize()` - инициализирует Firebase с timeout, в тестах отключается.
- `registerWithEmail(...)` - регистрация email/password; если email уже есть, пытается войти.
- `signInWithGoogle()` - Google Sign-In.
- `signInWithApple()` - Apple Sign-In.
- `_signInWithNativeGoogle()` - нативный Google Sign-In для Android/iOS.
- `_ensureGoogleSignInInitialized()` - разовая инициализация Google Sign-In.
- `loadRemoteData()` - загрузка `users/{uid}/appState/current`.
- `saveRemoteData(AppData data)` - сохранение всех данных пользователя.
- `deleteRemoteData()` - удаление root doc и subcollections.
- `signOut()` - выход из Firebase Auth.

### Firestore Структура

Основной документ:

```text
users/{uid}
```

В нем хранятся:

- `uid`
- `email`
- `displayName`
- `providerIds`
- `profile`
- `settings`
- `summary`
- `achievements`
- `schemaVersion`
- `retentionDays`
- `lastSyncedAt`
- `lastSyncedAtIso`
- `authCreatedAt`
- `lastSignInAt`

Полное состояние:

```text
users/{uid}/appState/current
```

В нем хранятся:

- `ownerUid`
- `schemaVersion`
- `data` - полный `AppData.toJson()`.
- `summary`
- `achievements`
- `updatedAt`
- `updatedAtIso`
- `expiresAt`

Подробные subcollections:

```text
users/{uid}/foodEntries/{foodEntryId}
users/{uid}/plannedWorkouts/{plannedWorkoutId}
users/{uid}/completedWorkouts/{completedWorkoutId}
users/{uid}/runs/{runId}
users/{uid}/assistantConversations/{conversationId}
users/{uid}/achievements/{achievementId}
```

Таким образом, Firestore хранит не только счетчики, но и конкретные записи:

- каждое блюдо с калориями, БЖУ, водой и датой;
- каждую плановую тренировку с упражнениями;
- каждую завершенную тренировку с подходами, повторениями, длительностью и оценкой;
- каждую пробежку с дистанцией, временем, темпом и количеством GPS-точек;
- каждый чат Kaze;
- состояние достижений.

### Firestore Summary

`_summaryFor(AppData data)` формирует краткую сводку:

- имя;
- язык;
- система единиц;
- цель;
- пол;
- рост/вес/возраст;
- тренировок в неделю;
- общее количество тренировок;
- количество плановых и завершенных тренировок;
- количество пробежек;
- суммарные километры;
- количество записей питания;
- суммарные калории питания;
- количество чатов;
- количество открытых достижений.

Эта сводка удобна для быстрого просмотра пользователя в Firebase Console без чтения всего `appState`.

### Firestore Security Rules

`firestore.rules` разрешает доступ только владельцу:

```text
match /users/{userId} {
  allow read, create, update, delete: if request.auth.uid == userId;

  match /{document=**} {
    allow read, create, update, delete: if request.auth.uid == userId;
  }
}
```

То есть пользователь может читать и менять только свои документы.

## Root Flow Приложения

### `KazeRunnerApp`

Корневой `StatelessWidget`. Создает `MaterialApp`, подключает:

- Material 3;
- Nunito;
- локали `ru` и `en`;
- `GlobalMaterialLocalizations`;
- `GlobalWidgetsLocalizations`;
- `GlobalCupertinoLocalizations`;
- `RootPage`.

### `RootPage`

Состояние приложения:

- загружает Firebase;
- загружает локальные данные;
- если пользователь авторизован, пробует загрузить Firestore;
- решает, показывать экран создания аккаунта или основной интерфейс;
- сохраняет изменения локально и удаленно.

Ключевые методы:

- `_loadProfile()`
- `_createProfile(...)`
- `_createDataFromProfile(...)`
- `_signInWithProvider(...)`
- `_saveAppData(AppData data)`
- `_deleteData()`

Если Firebase недоступен, приложение остается работоспособным локально.

## Экран Создания Аккаунта

### `AccountCreationScreen`

Функции:

- стартовая пульсирующая фраза: `Твой ритм. Твоя сила. Твой прогресс.`;
- фон из `assets/images/registration_background.png`;
- создание аккаунта email/password;
- вход через Google;
- вход через Apple;
- VK был удален по требованию;
- ввод имени, роста, веса, возраста, пола, цели и тренировок в неделю;
- выбор языка;
- выбор системы единиц;
- определение языка по устройству;
- возможность вводить русское имя.

Визуально:

- используется Nunito;
- поля сделаны более плотными и контрастными;
- у полей есть иконки: имя, email, пароль, рост, вес, возраст и т.д.;
- кнопка создания аккаунта называется `Создать аккаунт`.

### `_SocialAuthButton`

Компонент для кнопок Google/Apple.

### `_RegistrationBackground`

Фоновый слой экрана регистрации. Использует картинку, предоставленную пользователем.

## Главный Экран И Навигация

### `MainTabsScreen`

Главный контейнер приложения:

- хранит выбранную вкладку;
- прокидывает `AppData` в экраны;
- принимает callbacks сохранения;
- показывает Kaze launcher на основных экранах;
- вызывает напоминания Kaze.

Вкладки:

- `ActivityScreen` - активность.
- `FoodScreen` - питание.
- `RunScreen` - бег.
- `ProfileScreen` - профиль.

Нижняя навигация была упрощена до стандартной `NavigationBar`, потому что кастомная волнистая конструкция перекрывала низ экрана и выглядела перегруженно. Иконки приведены к смыслу:

- активность - гантель;
- питание - еда/тарелка;
- бег - беговой/кроссовочный смысл;
- профиль - пользователь.

### `_ConnectedNavigationBar`

Компонент нижней навигации. Название осталось от предыдущей версии с визуально связанными кругами, но текущий смысл - аккуратная стандартная навигация.

## Kaze Launcher И Intro

### `_AssistantLauncherButton`

Круглая кнопка Kaze внизу экрана. Исправлена проблема, когда у кнопки визуально появлялась квадратная тень.

### `_AssistantIntroSheet`

Первый слой после нажатия на кнопку Kaze:

- показывает `kaze_assistant_intro.png`;
- доступен в русской и английской локализации;
- кнопка перехода в чат;
- кнопка истории.

Важно: при нажатии на левый кружок Kaze всегда используется `kaze_assistant_intro.png`, независимо от языка. Это сделано по требованию, чтобы intro не менялось на другие state-картинки.

## Kaze Assistant

Kaze реализован как гибрид:

- Локальная rule-based модель работает всегда.
- Онлайн-LLM используется только если задан `KAZE_ASSISTANT_URL`.
- Если онлайн-бэкенд недоступен, приложение автоматически возвращается к локальному ответу.

### Визуальные Состояния Kaze

Enum `_KazeVisualState` описывает состояния:

- `greeting`
- `thinking`
- `food`
- `workout`
- `run`
- `sleep`
- `reminder`
- `goodbye`

Картинки Kaze лежат в `assets/images/`.

Пользователь подготовил/сгенерировал набор иллюстраций Kaze, а в проект они были интегрированы как ассеты:

- `kaze_assistant_intro.png`
- `kaze_assistant_chat.png`
- `kaze_state_food.png`
- `kaze_state_workout.png`
- `kaze_state_run.png`
- `kaze_state_sleep.png`
- `kaze_state_reminder.png`
- `kaze_state_thinking.png`
- `kaze_state_goodbye.png`
- английские варианты `*_eng.png`.

Поведение:

- во время ответа картинка меняется на `thinking`;
- при вопросе про еду - на питание;
- при вопросе про тренировки - на тренировку;
- при вопросе про бег - на бег;
- ночью - на сон;
- для напоминаний - на reminder;
- английские картинки отображаются через `BoxFit.contain`, чтобы не обрезались.

### `AssistantChatScreen`

Экран чата:

- хранит список разговоров;
- умеет создавать новый чат;
- показывает историю;
- закрепляет картинку Kaze сверху, чтобы она оставалась видимой при прокрутке;
- содержит быстрые prompts;
- сохраняет чаты в `AppData.assistantConversations`;
- вызывает онлайн-сервис или локальный `_AssistantEngine`.

Ключевые методы:

- `_createConversation(AppLanguage language)`
- `_localizedDefaultConversation(...)`
- `_startNewChat()`
- `_selectConversation(String id)`
- `_sendMessage([String? quickText])`
- `_replyToMessage(String text, AppData data)`
- `_scrollToEnd(...)`

### `_AssistantEngine`

Локальный rule-based ассистент. Он не является LLM, но умеет выбирать сценарии по ключевым словам и использовать контекст пользователя.

Что видит:

- профиль пользователя;
- цель;
- дневную норму калорий и БЖУ;
- питание за последние 7 дней;
- тренировки за последние 7 дней;
- пробежки за последние 7 дней.

Основные сценарии:

- рацион на день;
- список покупок на неделю;
- здоровая альтернатива блюду;
- тренировка по уровню усталости 1-10;
- объяснение техники упражнения;
- адаптация под травму/ограничение;
- расчет дефицита/профицита калорий;
- советы по добавкам.

Ключевые методы:

- `reply(String prompt)`
- `_contextSummary()`
- `_mealPlan()`
- `_shoppingList()`
- `_healthyAlternative(String prompt)`
- `_workoutByFatigue(String text)`
- `_exerciseTechnique(String prompt)`
- `_injuryAdaptation()`
- `_calorieBalance()`
- `_supplements()`

Локальная модель специально оставлена как fallback: она работает без интернета, без API-ключа и без внешнего сервера.

### `KazeCloudAssistantService`

Сервис онлайн-ответов:

- берет endpoint из `--dart-define=KAZE_ASSISTANT_URL`;
- поддерживает legacy `KAZE_FUNCTION_URL`;
- получает Firebase ID token текущего пользователя;
- отправляет `message`, `language`, `context` на backend;
- ждет максимум 12 секунд;
- при ошибке возвращает `null`, после чего используется `_AssistantEngine`.

Контекст для backend:

- `profile`
- `settings`
- `nutritionTargets`
- `last7Days.foodEntries`
- `last7Days.completedWorkouts`
- `last7Days.runs`
- `plannedWorkouts`
- `totals`

## Cloudflare Worker Для PolzaAI

Код находится здесь:

```text
workers/kaze-assistant/src/index.js
```

Worker делает следующее:

1. Принимает только POST и OPTIONS.
2. Проверяет Firebase ID token из `Authorization: Bearer ...`.
3. Загружает Firebase JWKS:

```text
https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com
```

4. Проверяет:

- алгоритм `RS256`;
- `kid`;
- `aud`;
- `iss`;
- `sub`;
- `exp`;
- `iat`;
- подпись JWT.

5. Читает body:

- `message`
- `language`
- `context`

6. Создает rule-based hint через `buildRuleHint(...)`.
7. Отправляет запрос в PolzaAI.
8. Возвращает:

```json
{ "reply": "..." }
```

Если PolzaAI недоступен, Worker возвращает hint или fallback.

### Переменные Worker

В `wrangler.toml`:

```toml
FIREBASE_PROJECT_ID = "kazerunner"
POLZA_MODEL = "google/gemini-2.0-flash-lite-001"
```

Секрет:

```text
POLZA_AI_API_KEY
```

API-ключ нельзя класть в Flutter-приложение, потому что APK можно разобрать. Поэтому ключ хранится в Cloudflare Worker Secrets.

### Зачем Worker Вместо Firebase Functions

Изначально рассматривались Firebase Cloud Functions, но команда:

```powershell
firebase functions:secrets:set POLZA_AI_API_KEY
```

потребовала Firebase Blaze-план. Чтобы не подключать платную версию Firebase, был выбран Cloudflare Worker как бесплатный путь для проксирования LLM-запросов.

## Firebase Functions

Папка `functions/` сохранена как альтернативный backend-вариант:

- runtime Node.js 20;
- `firebase-admin`;
- `firebase-functions`;
- функция может обращаться к PolzaAI;
- деплой через `firebase deploy --only functions`.

На текущий момент для бесплатного пути предпочтительнее Cloudflare Worker.

## Экран Активности

### `ActivityScreen`

Отвечает за:

- готовые тренировки;
- планирование тренировки на дату;
- календарь тренировок;
- активную тренировку;
- таймер тренировки;
- редактирование подходов/повторений;
- завершение тренировки;
- запись эмоции;
- виджет сожженных калорий.

Ключевые методы:

- `_schedulePreset(_WorkoutPreset preset)`
- `_openPlanDialog({PlannedWorkout? editing})`
- `_finishWithEmotion(PlannedWorkout workout)`
- `_changeExercise(...)`
- `_openWorkoutCalendar()`
- `_startWorkoutTimer(...)`
- `_pauseWorkoutTimer()`
- `_resetWorkoutTimer(...)`
- `_durationForWorkout(...)`
- `_todayBurnedCalories()`

### Таймер Тренировки

Таймер привязан к конкретной `PlannedWorkout`:

- старт;
- пауза;
- продолжение;
- сброс;
- сохранение длительности при завершении.

Если тренировка завершается, длительность попадает в `CompletedWorkout.durationSeconds` и затем синхронизируется в Firestore.

### Готовые Тренировки

Модель:

```dart
class _WorkoutPreset
```

Поля:

- `title`
- `subtitle`
- `tag`
- `minutes`
- `exercises`
- `icon`
- `accent`
- `imageAsset`/визуальная часть.

Алгоритм:

```dart
List<_WorkoutPreset> _workoutPresetsFor(UserProfile profile)
```

Тренировки адаптируются под:

- цель пользователя;
- количество тренировок в неделю;
- примерный объем нагрузки;
- тип сплита.

Примеры направлений:

- full body;
- грудь + бицепс;
- спина + трицепс;
- ноги;
- плечи + корпус;
- recovery/mobility.

### Расход Калорий

Виджет:

- `_BurnTargetCard`
- `_CalorieProgressRing`
- `_BurnLegendLine`

Алгоритм использует завершенные тренировки за день и `_estimatedWorkoutCalories(...)`. Цель сжигания рассчитывается индивидуально, а визуальный круг показывает прогресс.

### Календарь Тренировок

`_WorkoutCalendarSheet` показывает:

- текущий месяц;
- прошедшие тренировки;
- будущие запланированные тренировки;
- легенду;
- детали по клику на дату.

Календарь локализован на русский и английский.

## Экран Питания

### `FoodScreen`

Экран ранее назывался `Еда`, затем переименован в `Питание`.

Функции:

- добавление блюда;
- редактирование блюда;
- дата приема пищи;
- калории;
- белки;
- жиры;
- углеводы;
- вода;
- дневные цели;
- недельные графики;
- распознавание еды по фото;
- пресеты блюд.

Ключевые методы:

- `_loadVisionModels()`
- `_captureAndInfer()`
- `_preprocessImage(File file)`
- `_editVisionResult()`
- `_applyVisionResultAsFoodEntry()`
- `_openFoodForm({FoodEntry? edit})`
- `_save(List<FoodEntry> entries)`
- `_parseDecimal(String value, [double? fallback])`

### Расчет Дневной Нормы

```dart
_NutritionTargets _nutritionTargetsFor(UserProfile profile)
```

Норма считается на основе:

- пола;
- возраста;
- роста;
- веса;
- цели;
- количества тренировок в неделю.

Результат:

- `calories`
- `protein`
- `fat`
- `carbs`

Питание за день суммируется по `FoodEntry`, после чего UI показывает прогресс по калориям и БЖУ.

### Виджеты Питания

- `_NutritionGoalCard` - дневная цель и прогресс.
- `_MacroProgressPill` - отдельные progress-плашки для белков/жиров/углеводов.
- `_WaterBottlesWidget` - визуализация воды.
- `_WeeklyFoodCharts` - недельные графики.
- `_SimpleWeekBarChart` - простой bar chart.

### ML Распознавание Еды

Логика:

1. Пользователь выбирает камеру или галерею.
2. Изображение уменьшается до `224x224`.
3. Каналы нормализуются.
4. `food_model.tflite` определяет класс блюда.
5. `nutrition_model.tflite` оценивает калории и БЖУ.
6. Пользователь может вручную поправить результат.
7. Результат добавляется как `FoodEntry`.

Важно: ML доступен только на Android/iOS, потому что используется файловая система и TFLite runtime.

## Экран Бега

### `RunScreen`

Функции:

- старт пробежки;
- запрос геолокации;
- таймер;
- расчет дистанции;
- GPS route points;
- завершение пробежки;
- сохранение истории;
- мини-карта маршрута;
- прогресс к марафонской дистанции.

Ключевые методы:

- `_startRun()`
- `_stopRun()`
- `_fmtDuration(int total)`
- `_fmtDate(DateTime dt)`

### GPS Поток

При старте:

1. Проверяется `Geolocator.isLocationServiceEnabled()`.
2. Запрашиваются permissions.
3. Запускается `Timer.periodic`.
4. Запускается `Geolocator.getPositionStream(...)`.
5. Каждая новая координата добавляется в `_points`.
6. Расстояние между точками считается через `Geolocator.distanceBetween(...)`.

Настройки GPS:

- `LocationAccuracy.best`
- `distanceFilter: 5`

### Марафонский Виджет

`_MarathonStadiumProgress` показывает прогресс к 42.195 км.

Виджет содержит факт:

> Дистанция 42.195 км закрепилась после Олимпиады 1908 года в Лондоне: забег стартовал у Виндзорского замка и финишировал перед королевской ложей, что составило 26 миль и 385 ярдов.

`_StadiumProgressPainter` рисует стилизованный стадион, который постепенно заполняется по мере набора километров.

### Карта Пробежки

`_RunMap` использует `FlutterMap`, `TileLayer` и `PolylineLayer`. Для тайлов выбран ArcGIS World Imagery.

## Экран Профиля

### `ProfileScreen`

Функции:

- отображение имени, цели, роста, веса, возраста;
- аватар пользователя;
- выбор аватара из галереи или камеры;
- настройки приложения;
- достижения;
- календарь активности;
- экспорт данных;
- удаление аккаунта.

Ключевые методы:

- `_pickAvatar(ImageSource source)`
- `_persistAvatar(String sourcePath)`
- `_showAvatarMenu()`
- `_openSettings()`
- `_exportData()`
- `_showExportReadyDialog(...)`
- `_buildWorkoutAchievements()`
- `_buildRunAchievements()`

### Настройки

В профиле есть вход в настройки:

- язык: русский/английский;
- система единиц: metric/USA.

Изменение настроек сохраняется в `AppData.settings`, затем локально и в Firestore.

### Экспорт Данных

Экспорт создает папку:

```text
<app-documents>/kaze_export_<timestamp>/
```

И три файла:

```text
kaze_workouts.json
kaze_runs.json
kaze_nutrition.json
```

Содержимое:

- `kaze_workouts.json` - профиль, настройки, плановые тренировки, завершенные тренировки, remembered sets, достижения.
- `kaze_runs.json` - дни пробежек и подробные пробежки.
- `kaze_nutrition.json` - подробные записи питания.

После создания файлов появляется диалог с кнопкой `Скачать / отправить` или `Save / share`. На эмуляторе это основной способ получить файлы, потому что директория приложения приватная.

### Достижения

Модель UI:

```dart
class _AchievementItem
```

Достижения делятся на:

- силовые тренировки;
- пробежки;
- марафонская дистанция 42.195 км.

Английская локализация добавлена для названий и описаний достижений.

### Календарь Активности

`_GithubCalendar` рисует мини-календарь последних 84 дней:

- зеленый - тренировка;
- синий - пробежка;
- смешанный квадрат - и тренировка, и пробежка.

`_ActivityDayCellPainter` отвечает за отрисовку ячеек.

## Алгоритмы

### `_nutritionTargetsFor(UserProfile profile)`

Рассчитывает дневную норму питания:

- BMR зависит от пола, роста, веса и возраста.
- Activity factor зависит от `workoutsPerWeek`.
- Goal modifier зависит от цели: похудение, поддержание, набор.
- Белок, жиры и углеводы распределяются под цель.

Результат используется:

- на экране питания;
- в Kaze context;
- в rule-based ответах;
- в Cloudflare Worker prompt context.

### `_workoutPresetsFor(UserProfile profile)`

Создает набор готовых тренировок, адаптированных под пользователя.

Учитывает:

- цель;
- тренировок в неделю;
- примерный объем подходов/повторений;
- ожидаемую длительность.

### `_achievementSnapshotsFor(AppData data)`

Формирует достижения для Firestore:

- id;
- group;
- title;
- description;
- done;
- progress/threshold.

Это позволяет видеть достижения не только в UI, но и в Firestore.

### `_estimatedWorkoutCalories(...)`

Оценивает расход калорий по тренировке. Используется:

- в карточке расхода калорий;
- в Firestore document `completedWorkouts`;
- в summary/аналитике.

### `_exerciseNameForLanguage(...)`

Локализует названия упражнений в:

- карточках готовых тренировок;
- активной тренировке;
- календаре;
- истории;
- Firestore detailed exercise docs.

## Дизайн И Ассеты

### Логотип

Логотип приложения был заменен на новый набор из `D:\KazeRunner\KazeIcon`. Были обновлены Android/iOS launcher icons в нужных размерах.

### Фон Регистрации

`assets/images/registration_background.png` - пользовательская картинка со стадионом/спортом в голубой гамме. Используется только на начальных экранах регистрации/создания аккаунта.

### Kaze Иллюстрации

Картинки Kaze были подготовлены пользователем и добавлены в проект. В приложении они используются для:

- intro;
- чата;
- размышления;
- питания;
- тренировки;
- бега;
- сна;
- напоминания;
- прощания;
- английской локализации визуальных state-картинок.

### Шрифт

Основной шрифт:

```text
assets/fonts/Nunito-VariableFont_wght.ttf
```

Nunito выбран как мягкий, современный и читаемый шрифт. В UI используется более плотный вес, чтобы текст не сливался с фоном.

## Напоминания Kaze

В `MainTabsScreen` есть логика напоминаний:

- если пользователь долго не ел;
- если давно не тренировался;
- если скоро тренировка;
- если есть контекстный повод показать reminder.

Напоминание открывается как popup с картинкой Kaze. Для пустого нового профиля напоминание не должно открываться агрессивно сразу после создания аккаунта, чтобы не блокировать переход и не создавать серый зависший экран.

## Исправленные Проблемы И Важные Улучшения

В процессе работы были исправлены и улучшены следующие вещи:

- VK-регистрация удалена.
- Google/Apple кнопки оставлены как реальные Firebase providers, а не просто UI.
- Добавлены Firebase config files для Android/iOS.
- Добавлен Firestore full-state sync.
- Firestore начал сохранять подробные блюда, тренировки, пробежки, чаты и достижения, а не только счетчики.
- Добавлен Cloudflare Worker путь для PolzaAI без Firebase Blaze.
- API-ключ PolzaAI вынесен из Flutter в Worker secret.
- Нижняя навигация возвращена к стандартной, чтобы не перекрывать экран.
- Исправлена проблема квадратной тени у Kaze launcher.
- Kaze intro унифицирован на `kaze_assistant_intro.png`.
- Картинка Kaze в чате закреплена сверху.
- Английские картинки Kaze не должны обрезаться за счет `BoxFit.contain`.
- Локализация расширена на достижения, тренировки, календарь, Kaze, питание и системные элементы.
- В тренировку добавлен таймер.
- Экспорт теперь не просто пишет "готово", а открывает системное меню share/save.
- Добавлен русский ввод имени.
- Добавлены settings: язык и система единиц.
- Исправлена обработка десятичной запятой в питании.
- Диалоги и overlay получили более устойчивую локализацию через `_activeAppLanguage`.
- В Firestore root document добавлены `settings`, `achievements` и расширенный `summary`.
- В `appState/current` добавлен `expiresAt` на 30 дней.

## Firebase Auth Особенности

### Email/Password

Работает через:

```dart
FirebaseAuth.instance.createUserWithEmailAndPassword(...)
```

Если email уже занят, приложение пытается выполнить sign-in с тем же email/password.

### Google Sign-In

Для Android важно:

- включить Google provider в Firebase Authentication;
- добавить SHA-1/SHA-256 debug/release ключи в Firebase Console;
- скачать актуальный `google-services.json`;
- убедиться, что package name совпадает с Android project.

На некоторых эмуляторах Google Play Services может выдавать `DEVELOPER_ERROR` или `Unknown calling package name`. Это часто связано не с кодом Flutter, а с настройкой SHA-ключей, package name или образом эмулятора.

### Apple Sign-In

Для iOS нужно:

- включить Apple provider в Firebase Authentication;
- настроить Sign in with Apple в Apple Developer;
- проверить Bundle ID;
- убедиться, что `GoogleService-Info.plist` актуален.

## Firebase / Firestore Что Смотреть В Console

После входа пользователя должна появиться структура:

```text
users
  {uid}
    profile
    settings
    summary
    achievements
    appState
      current
    foodEntries
    plannedWorkouts
    completedWorkouts
    runs
    assistantConversations
    achievements
```

Если видны только `profile` и `summary`, значит пользователь еще не создал соответствующие записи или синхронизация была до внедрения subcollections.

## Настройка Cloudflare Worker

Перейти в папку:

```powershell
cd D:\KazeRunner\kazer\workers\kaze-assistant
```

Установить зависимости:

```powershell
npm install
```

Через Wrangler:

```powershell
npx wrangler login
npx wrangler secret put POLZA_AI_API_KEY
npx wrangler deploy
```

Если login не работает, можно развернуть вручную через Cloudflare Dashboard:

1. Workers & Pages.
2. Create Worker.
3. Название `kaze-assistant`.
4. Вставить код из `src/index.js`.
5. Добавить variables:
   - `FIREBASE_PROJECT_ID = kazerunner`
   - `POLZA_MODEL = google/gemini-2.0-flash-lite-001`
6. Добавить secret:
   - `POLZA_AI_API_KEY`
7. Deploy.
8. Скопировать URL и передать Flutter через `--dart-define=KAZE_ASSISTANT_URL=...`.

## Безопасность

Основные решения:

- PolzaAI API key не хранится в приложении.
- Firestore rules ограничивают доступ владельцем `uid`.
- Worker проверяет Firebase ID token перед LLM-запросом.
- Приложение не отправляет в LLM все данные без ограничений: контекст сокращается до профиля, целей, последних 7 дней и totals.
- При ошибке сети Kaze не падает, а отвечает локально.

Оставшиеся моменты на будущее:

- Добавить rate limiting на Worker.
- Добавить логирование без персональных данных.
- Добавить явный consent на отправку данных в LLM.
- Разделить medical/safety темы отдельным guardrail.

## Платформенные Разрешения

Android:

- location для пробежек;
- camera/gallery для аватара и фото еды;
- internet для Firebase, карт и Worker.

iOS:

- `NSLocationWhenInUseUsageDescription`;
- `NSCameraUsageDescription`;
- `NSPhotoLibraryUsageDescription`.

## Экспорт Данных На Эмуляторе

На Android-эмуляторе путь вида:

```text
/data/user/0/com.example.kazer/app_flutter/kaze_export_...
```

может быть недоступен напрямую. Поэтому после экспорта нужно нажать кнопку `Скачать / отправить`. Она открывает системное меню, где файлы можно сохранить, отправить себе или передать в другое приложение.

## Документация В Проекте

Кроме README есть отдельные файлы:

- `FIREBASE_SETUP.md` - базовая настройка Firebase.
- `FIREBASE_SYNC_PLAN.md` - план и детали Firestore-синхронизации.
- `KAZE_RULE_BASED_MODEL.md` - как работает локальный ассистент.
- `KAZE_HYBRID_LLM_PLAN.md` - идея гибридного rule-based + LLM подхода.
- `KAZE_CLOUD_FUNCTIONS_SETUP.md` - Firebase Functions вариант.
- `KAZE_POLZA_WORKER_SETUP.md` - Cloudflare Worker + PolzaAI.

Часть старых markdown-файлов может отображаться битой кодировкой в некоторых терминалах, но идея и структура сохранены. Этот README заменен свежей UTF-8 документацией.

## Текущие Ограничения

- `main.dart` очень большой. Его стоит разбить на отдельные файлы.
- Локализация реализована вручную, без ARB. Для production лучше перейти на `flutter gen-l10n`.
- Google Sign-In зависит от правильной настройки SHA-1/SHA-256 и Google Play Services на эмуляторе.
- Apple Sign-In полноценно проверяется только на Apple-платформах с настроенным provider.
- TFLite-модели питания дают приблизительную оценку, пользователь должен иметь возможность редактировать результат.
- Карты используют внешний tile server, значит для карт нужен интернет.
- Cloudflare Worker требует отдельного деплоя и секрет PolzaAI.
- Firestore retention сейчас реализован через `expiresAt` в документе, но автоматическое удаление требует TTL-настройки в Firebase Console или отдельной cleanup-логики.

## Рекомендованный Рефакторинг

Чтобы проект было легче поддерживать, стоит постепенно разнести `lib/main.dart`:

```text
lib/
  main.dart
  app/
    kaze_runner_app.dart
    root_page.dart
  models/
    app_data.dart
    user_profile.dart
    workout.dart
    nutrition.dart
    run.dart
    assistant.dart
    settings.dart
  services/
    local_app_storage.dart
    cloud_account_service.dart
    kaze_cloud_assistant_service.dart
  screens/
    account_creation_screen.dart
    main_tabs_screen.dart
    activity_screen.dart
    food_screen.dart
    run_screen.dart
    profile_screen.dart
    assistant_chat_screen.dart
  widgets/
    navigation/
    kaze/
    cards/
    charts/
  l10n/
    app_ru.arb
    app_en.arb
  utils/
    nutrition_targets.dart
    workout_presets.dart
    achievements.dart
```

Это не обязательно для работы приложения прямо сейчас, но сильно упростит дальнейшее развитие.

## Что Было Сделано Косвенно

Некоторые части проекта были подготовлены пользователем и затем интегрированы в приложение:

- иллюстрации Kaze в разных состояниях;
- английские варианты иллюстраций;
- фон регистрации;
- новый логотип и набор launcher icons;
- Firebase проект `kazerunner`;
- Firebase config files для Android/iOS;
- PolzaAI API key, который должен храниться в Worker secret.

С точки зрения приложения эти материалы стали частью продукта: они зарегистрированы в `pubspec.yaml`, подключены к экранам и используются в UI/UX сценариях.

## Быстрая Карта Классов

Основные модели:

- `AppSettings`
- `UserProfile`
- `RoutePoint`
- `RunEntry`
- `FoodEntry`
- `PlannedExercise`
- `PlannedWorkout`
- `CompletedWorkout`
- `AssistantMessage`
- `AssistantConversation`
- `AppData`

Сервисы:

- `LocalAppStorage`
- `CloudAccountService`
- `KazeCloudAssistantService`
- `_AssistantEngine`

Корневой UI:

- `KazeRunnerApp`
- `RootPage`
- `AccountCreationScreen`
- `MainTabsScreen`

Экраны:

- `ActivityScreen`
- `FoodScreen`
- `RunScreen`
- `ProfileScreen`
- `AssistantChatScreen`

Ключевые виджеты:

- `_AssistantLauncherButton`
- `_AssistantIntroSheet`
- `_AssistantStateImage`
- `_ConnectedNavigationBar`
- `_BurnTargetCard`
- `_CalorieProgressRing`
- `_WorkoutPresetCard`
- `_WorkoutCalendarSheet`
- `_NutritionGoalCard`
- `_MacroProgressPill`
- `_WaterBottlesWidget`
- `_WeeklyFoodCharts`
- `_MarathonStadiumProgress`
- `_RunMap`
- `_GithubCalendar`

Ключевые алгоритмы:

- `_nutritionTargetsFor`
- `_workoutPresetsFor`
- `_achievementSnapshotsFor`
- `_estimatedWorkoutCalories`
- `_exerciseNameForLanguage`
- `_kazeVisualForPrompt`
- `_kazeAssetForVisual`

## Итого

Kaze Runner сейчас является не просто дневником тренировок, а основой персонального фитнес-приложения с аккаунтом, облачной синхронизацией, AI-ассистентом, визуальным персонажем, локальным fallback-движком, экспортом данных и расширяемой архитектурой.

Главные сильные стороны текущей версии:

- работает локально и с облаком;
- хранит подробные пользовательские данные;
- использует Firebase Auth/Firestore;
- имеет продуманный Kaze UI;
- поддерживает русский и английский;
- готова к подключению онлайн-LLM через бесплатный Worker-путь;
- сохраняет офлайн rule-based ассистента как надежный fallback.

Главная следующая инженерная задача - модульный рефакторинг `main.dart`, после которого будет проще добавлять новые экраны, тесты, локализацию через ARB и более сложную аналитику.
