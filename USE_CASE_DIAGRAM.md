# Диаграмма Прецедентов Kaze Runner

Ниже приведена диаграмма прецедентов приложения Kaze Runner в формате Mermaid. Ее можно открыть в Markdown-просмотрщике с поддержкой Mermaid, например в GitHub, некоторых IDE-плагинах или Mermaid Live Editor.

```mermaid
flowchart LR
  user([Пользователь])
  firebaseAuth([Firebase Auth])
  firestore([Firebase Firestore])
  worker([Cloudflare Worker / PolzaAI])
  gps([GPS / Geolocation])
  camera([Камера / Галерея])
  share([Системное меню Share])
  tflite([Локальные TFLite модели])

  subgraph app[Kaze Runner]
    direction LR

    subgraph account[Аккаунт и профиль]
      direction TB
      ucCreateAccount([Создать аккаунт])
      ucLoginPassword([Войти по email и паролю])
      ucLoginGoogleApple([Войти через Google / Apple])
      ucFillProfile([Заполнить профиль])
      ucChooseSettings([Выбрать язык и систему единиц])
      ucDeleteAccount([Удалить аккаунт])
      ucSync([Синхронизировать данные])
    end

    subgraph activity[Активность и тренировки]
      direction TB
      ucViewWorkoutPresets([Просмотреть готовые тренировки])
      ucPlanWorkout([Запланировать тренировку])
      ucOpenCalendar([Открыть календарь тренировок])
      ucStartWorkoutTimer([Запустить таймер тренировки])
      ucEditWorkout([Изменить упражнения, подходы и повторы])
      ucCompleteWorkout([Завершить и оценить тренировку])
      ucViewBurn([Посмотреть расход калорий])
    end

    subgraph nutrition[Питание]
      direction TB
      ucCalcNutrition([Рассчитать дневную цель КБЖУ])
      ucAddFood([Добавить или изменить блюдо])
      ucRecognizeFood([Распознать еду по фото])
      ucTrackWater([Отслеживать воду])
      ucViewFoodStats([Посмотреть недельную статистику питания])
    end

    subgraph running[Бег]
      direction TB
      ucStartRun([Начать пробежку])
      ucRecordRoute([Записать GPS-маршрут])
      ucStopRun([Завершить пробежку])
      ucViewRunHistory([Посмотреть историю и карту пробежек])
      ucViewMarathon([Отслеживать прогресс 42.195 км])
    end

    subgraph profile[Профиль, достижения и экспорт]
      direction TB
      ucEditAvatar([Изменить аватар])
      ucViewAchievements([Посмотреть достижения])
      ucOpenSettings([Открыть настройки])
      ucExportData([Экспортировать данные])
    end

    subgraph assistant[Kaze Assistant]
      direction TB
      ucOpenAssistant([Открыть Kaze])
      ucCreateChat([Создать отдельный чат])
      ucViewChatHistory([Посмотреть историю чатов])
      ucAskKaze([Задать вопрос Kaze])
      ucRuleBased([Получить локальный rule-based ответ])
      ucOnlineLLM([Получить онлайн LLM-ответ])
      ucReminder([Получить pop-up напоминание])
      ucChangeKazeState([Показать тематическую картинку Kaze])
    end
  end

  user --> ucCreateAccount
  user --> ucViewWorkoutPresets
  user --> ucCalcNutrition
  user --> ucStartRun
  user --> ucEditAvatar
  user --> ucOpenAssistant

  ucCreateAccount --- ucLoginPassword
  ucLoginPassword --- ucLoginGoogleApple
  ucViewWorkoutPresets --- ucPlanWorkout
  ucPlanWorkout --- ucOpenCalendar
  ucCalcNutrition --- ucAddFood
  ucAddFood --- ucViewFoodStats
  ucStartRun --- ucStopRun
  ucStopRun --- ucViewRunHistory
  ucEditAvatar --- ucViewAchievements
  ucViewAchievements --- ucOpenSettings
  ucOpenAssistant --- ucCreateChat
  ucCreateChat --- ucAskKaze

  ucCreateAccount -. включает .-> ucFillProfile
  ucCreateAccount -. включает .-> ucChooseSettings
  ucCreateAccount -. вызывает .-> ucSync
  ucFillProfile -. вызывает .-> ucSync
  ucChooseSettings -. вызывает .-> ucSync
  ucDeleteAccount -. вызывает .-> ucSync

  ucPlanWorkout -. вызывает .-> ucSync
  ucEditWorkout -. вызывает .-> ucSync
  ucCompleteWorkout -. вызывает .-> ucSync
  ucCompleteWorkout -. включает .-> ucViewBurn

  ucAddFood -. вызывает .-> ucCalcNutrition
  ucAddFood -. вызывает .-> ucSync
  ucRecognizeFood -. включает .-> ucAddFood
  ucRecognizeFood -. использует .-> tflite
  ucTrackWater -. вызывает .-> ucSync

  ucStartRun -. включает .-> ucRecordRoute
  ucRecordRoute -. использует .-> gps
  ucStopRun -. вызывает .-> ucSync
  ucStopRun -. обновляет .-> ucViewMarathon

  ucExportData -. использует .-> share
  ucEditAvatar -. использует .-> camera
  ucRecognizeFood -. использует .-> camera

  ucAskKaze -. включает .-> ucRuleBased
  ucAskKaze -. может использовать .-> ucOnlineLLM
  ucAskKaze -. обновляет .-> ucChangeKazeState
  ucReminder -. обновляет .-> ucChangeKazeState
  ucCreateChat -. вызывает .-> ucSync
  ucAskKaze -. вызывает .-> ucSync

  ucCreateAccount -. использует .-> firebaseAuth
  ucLoginPassword -. использует .-> firebaseAuth
  ucLoginGoogleApple -. использует .-> firebaseAuth
  ucSync -. использует .-> firestore
  ucOnlineLLM -. использует .-> worker
  worker -. проверяет токен .-> firebaseAuth

  firebaseAuth ~~~ firestore
  firestore ~~~ worker
  worker ~~~ gps
  gps ~~~ camera
  camera ~~~ share
  share ~~~ tflite
```

## Актеры

- `Пользователь` - основной актер приложения. Создает аккаунт, ведет тренировки, питание, пробежки, профиль и общается с Kaze.
- `Firebase Auth` - внешний сервис авторизации. Используется для email/password, Google и Apple входа.
- `Firebase Firestore` - внешнее облачное хранилище пользовательских данных.
- `Cloudflare Worker / PolzaAI` - внешний AI-бэкенд для онлайн-ответов Kaze.
- `GPS / Geolocation` - системный сервис устройства для записи маршрута пробежки.
- `Камера / Галерея` - системные источники изображений для аватара и распознавания еды.
- `Системное меню Share` - системный механизм сохранения/отправки экспортированных файлов.
- `Локальные TFLite модели` - локальные ML-модели для распознавания еды и оценки КБЖУ.

## Основные Группы Прецедентов

### Аккаунт и профиль

Пользователь может создать аккаунт, войти по email/password, Google или Apple, заполнить профиль, выбрать язык и систему единиц. После изменений приложение сохраняет данные локально и синхронизирует их с Firestore.

### Активность и тренировки

Пользователь выбирает готовую тренировку, планирует ее на дату, открывает календарь, запускает таймер, редактирует упражнения, завершает тренировку и оценивает состояние. Завершенная тренировка сохраняется подробно: упражнения, подходы, повторы, длительность и эмоция.

### Питание

Пользователь видит индивидуальную дневную цель КБЖУ, добавляет блюда, редактирует их, отслеживает воду и недельную статистику. Дополнительно можно распознать еду по фото через локальные TFLite-модели, а затем вручную поправить результат.

### Бег

Пользователь запускает пробежку, приложение записывает GPS-маршрут и считает дистанцию. После завершения пробежка сохраняется, появляется в истории, отображается на карте и обновляет прогресс к марафонской дистанции 42.195 км.

### Профиль, достижения и экспорт

Пользователь меняет аватар, смотрит достижения, открывает настройки и экспортирует данные. Экспорт формирует три JSON-файла: тренировки, пробежки и питание, после чего открывает системное меню Share.

### Kaze Assistant

Пользователь открывает Kaze, создает отдельный чат, смотрит историю и задает вопросы. Kaze всегда может ответить локально через rule-based модель. Если задан `KAZE_ASSISTANT_URL`, приложение пробует получить онлайн-ответ через Cloudflare Worker / PolzaAI. Тематическая картинка Kaze меняется в зависимости от контекста: размышление, питание, тренировка, бег, сон или напоминание.
