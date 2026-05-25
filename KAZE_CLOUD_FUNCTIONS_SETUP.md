# Kaze Cloud Functions

Firebase Functions require Blaze for secrets and deployment in this project.
Use `KAZE_POLZA_WORKER_SETUP.md` if you want the no-Blaze path.

Kaze now has a hybrid assistant flow:

- mobile app calls `kazeChat` in Google Cloud Functions when the user is signed in;
- the function validates Firebase Auth ID token;
- the function sends user context plus the message to PolzaAI;
- if the function is unavailable, the app falls back to the local rule-based assistant.

## Deploy

```bash
cd D:\KazeRunner\kazer
firebase functions:secrets:set POLZA_AI_API_KEY
firebase deploy --only functions
```

When Firebase asks for the value, paste your PolzaAI API key there. Do not put
the key into Flutter code, `functions/index.js`, or git.

The backend uses this model by default:

```text
google/gemini-2.0-flash-lite-001
```

The Flutter app uses this default endpoint:

```text
https://europe-west1-kazerunner.cloudfunctions.net/kazeChat
```

To override it at build time:

```bash
flutter build apk --dart-define=KAZE_FUNCTION_URL=https://REGION-PROJECT.cloudfunctions.net/kazeChat
```
