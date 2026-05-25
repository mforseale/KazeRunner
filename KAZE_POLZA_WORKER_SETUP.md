# Kaze PolzaAI Worker Setup

This is the free backend path for Kaze LLM replies without Firebase Blaze.

The mobile app keeps the local rule-based assistant as fallback. If
`KAZE_ASSISTANT_URL` is not provided, the app does not call any remote LLM.

## Option A: Deploy In Cloudflare Dashboard

Use this when `npx wrangler login` does not work.

1. Open Cloudflare Dashboard.
2. Go to `Workers & Pages`.
3. Create a new Worker named `kaze-assistant`.
4. Open the Worker editor and replace the generated code with:

```text
D:\KazeRunner\kazer\workers\kaze-assistant\src\index.js
```

5. Save and deploy.
6. Open Worker settings.
7. Add variables:

```text
FIREBASE_PROJECT_ID = kazerunner
POLZA_MODEL = google/gemini-2.0-flash-lite-001
```

8. Add secret:

```text
POLZA_AI_API_KEY = your PolzaAI key
```

Cloudflare will give you a URL like:

```text
https://kaze-assistant.YOUR_SUBDOMAIN.workers.dev
```

Use it as `KAZE_ASSISTANT_URL` when running Flutter.

## Option B: Deploy With Wrangler Login

```bash
cd D:\KazeRunner\kazer\workers\kaze-assistant
npm install
npx wrangler login
npx wrangler secret put POLZA_AI_API_KEY
npx wrangler deploy
```

When Wrangler asks for the secret value, paste your PolzaAI API key.

The key is stored in Cloudflare Worker Secrets, not in Flutter, Firebase, or git.

## Option C: Deploy With API Token Instead Of Login

Use this when browser login is blocked.

1. In Cloudflare Dashboard, create an API token with Workers edit permissions.
2. In PowerShell:

```powershell
$env:CLOUDFLARE_API_TOKEN="paste_token_here"
cd D:\KazeRunner\kazer\workers\kaze-assistant
npm install
npx wrangler secret put POLZA_AI_API_KEY
npx wrangler deploy
```

## Connect Flutter To Worker

After deploy, Wrangler prints a URL like:

```text
https://kaze-assistant.YOUR_SUBDOMAIN.workers.dev
```

Run or build the app with:

```bash
D:\Flutter\flutter\bin\flutter.bat run --dart-define=KAZE_ASSISTANT_URL=https://kaze-assistant.YOUR_SUBDOMAIN.workers.dev
```

For APK:

```bash
D:\Flutter\flutter\bin\flutter.bat build apk --debug --dart-define=KAZE_ASSISTANT_URL=https://kaze-assistant.YOUR_SUBDOMAIN.workers.dev
```

## Notes

- Worker validates Firebase Auth ID token before using PolzaAI.
- Default model is `google/gemini-2.0-flash-lite-001`.
- Model can be changed in `workers/kaze-assistant/wrangler.toml`.
- If the Worker is offline or the URL is missing, Kaze answers locally.
