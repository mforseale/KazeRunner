const POLZA_URL = "https://polza.ai/api/v1/chat/completions";
const DEFAULT_MODEL = "google/gemini-2.0-flash-lite-001";
const FIREBASE_JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return withCors(new Response(null, {status: 204}));
    }
    if (request.method !== "POST") {
      return json({error: "method-not-allowed"}, 405);
    }

    try {
      const uid = await verifyFirebaseIdToken(
        request.headers.get("authorization") || "",
        env.FIREBASE_PROJECT_ID || "kazerunner",
      );
      const body = await request.json().catch(() => ({}));
      const message = typeof body.message === "string" ? body.message.trim() : "";
      const language = body.language === "en" ? "en" : "ru";
      const context = sanitizeContext(body.context);
      if (!message) {
        return json({error: "empty-message"}, 400);
      }

      const ruleHint = buildRuleHint(message, language, context);
      const reply = await generatePolzaReply({
        env,
        uid,
        message,
        language,
        context,
        ruleHint,
      });

      return json({reply: reply || ruleHint || fallbackReply(language)});
    } catch (error) {
      console.error("kaze worker failed", error);
      return json(
        {error: error.code || "kaze-worker-failed"},
        error.status || 500,
      );
    }
  },
};

async function verifyFirebaseIdToken(authorization, projectId) {
  if (!authorization.startsWith("Bearer ")) {
    throw httpError("missing-auth-token", 401);
  }

  const token = authorization.slice("Bearer ".length);
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw httpError("invalid-token", 401);
  }

  const header = parseBase64UrlJson(parts[0]);
  const payload = parseBase64UrlJson(parts[1]);
  if (header.alg !== "RS256" || !header.kid) {
    throw httpError("invalid-token-header", 401);
  }

  const now = Math.floor(Date.now() / 1000);
  const issuer = `https://securetoken.google.com/${projectId}`;
  if (payload.aud !== projectId || payload.iss !== issuer) {
    throw httpError("invalid-token-project", 401);
  }
  if (!payload.sub || typeof payload.sub !== "string") {
    throw httpError("invalid-token-subject", 401);
  }
  if (Number(payload.exp || 0) <= now || Number(payload.iat || 0) > now + 60) {
    throw httpError("expired-token", 401);
  }

  const jwk = await getFirebaseJwk(header.kid);
  const key = await crypto.subtle.importKey(
    "jwk",
    jwk,
    {name: "RSASSA-PKCS1-v1_5", hash: "SHA-256"},
    false,
    ["verify"],
  );
  const signature = base64UrlToUint8Array(parts[2]);
  const data = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const verified = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    signature,
    data,
  );
  if (!verified) {
    throw httpError("invalid-token-signature", 401);
  }
  return payload.sub;
}

async function getFirebaseJwk(kid) {
  const response = await fetch(FIREBASE_JWKS_URL, {
    cf: {cacheTtl: 3600, cacheEverything: true},
  });
  if (!response.ok) {
    throw httpError("firebase-jwks-unavailable", 503);
  }
  const body = await response.json();
  const key = (body.keys || []).find((item) => item.kid === kid);
  if (!key) {
    throw httpError("firebase-jwk-not-found", 401);
  }
  return key;
}

async function generatePolzaReply({env, uid, message, language, context, ruleHint}) {
  if (!env.POLZA_AI_API_KEY) {
    throw httpError("missing-polza-ai-api-key", 500);
  }

  const systemText = [
    "You are Kaze, a fitness and nutrition assistant inside the Kaze Runner app.",
    "Use the provided user context, but do not invent exact logs that are not present.",
    "Be concise, friendly, practical, and safety-aware.",
    "For medical pain, injuries, medication, eating disorders, pregnancy, or severe symptoms, give conservative guidance and recommend a qualified professional.",
    language === "en" ? "Reply in English." : "Reply in Russian.",
    ruleHint ? `Rule-based hint to respect: ${ruleHint}` : "",
    `Firebase uid: ${uid}`,
  ]
    .filter(Boolean)
    .join("\n");

  const payload = {
    model: env.POLZA_MODEL || DEFAULT_MODEL,
    messages: [
      {role: "system", content: systemText},
      {role: "user", content: JSON.stringify({message, context})},
    ],
    temperature: 0.65,
    max_tokens: 900,
  };

  const response = await fetch(POLZA_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.POLZA_AI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error("PolzaAI error", response.status, body);
    return null;
  }
  const content = (((body.choices || [])[0] || {}).message || {}).content || "";
  return content.trim() || null;
}

function sanitizeContext(context) {
  if (!context || typeof context !== "object") {
    return {};
  }
  return JSON.parse(JSON.stringify(context));
}

function buildRuleHint(message, language, context) {
  const text = message.toLowerCase();
  const targets = context.nutritionTargets || {};
  if (
    contains(text, [
      "meal",
      "food",
      "nutrition",
      "ration",
      "calorie",
      "bju",
      "protein",
      "еда",
      "пит",
      "рацион",
      "бжу",
      "калор",
    ])
  ) {
    return language === "en"
      ? `Use the daily targets as a hard reference: ${targets.calories || "?"} kcal, protein ${targets.protein || "?"} g, fat ${targets.fat || "?"} g, carbs ${targets.carbs || "?"} g. Give practical meals and portion guidance.`
      : `Используй дневные цели как опору: ${targets.calories || "?"} ккал, белки ${targets.protein || "?"} г, жиры ${targets.fat || "?"} г, углеводы ${targets.carbs || "?"} г. Дай практичные блюда и порции.`;
  }
  if (
    contains(text, [
      "workout",
      "training",
      "exercise",
      "fatigue",
      "injury",
      "трен",
      "упраж",
      "устал",
      "травм",
    ])
  ) {
    return language === "en"
      ? "Prioritize safe technique, current fatigue, goal, and recent training history. If pain or injury is mentioned, suggest lower-risk substitutions and recommend medical advice for sharp or worsening pain."
      : "Учитывай технику, усталость, цель и недавние тренировки. Если есть боль или травма, предложи более безопасные замены и посоветуй врача при острой или усиливающейся боли.";
  }
  if (
    contains(text, [
      "run",
      "pace",
      "marathon",
      "бег",
      "темп",
      "марафон",
      "км",
    ])
  ) {
    return language === "en"
      ? "Use recent runs and total distance. Keep running advice gradual and avoid sudden mileage jumps."
      : "Опирайся на последние пробежки и общий километраж. Советы по бегу делай постепенными, без резкого роста объема.";
  }
  return "";
}

function contains(text, words) {
  return words.some((word) => text.includes(word));
}

function fallbackReply(language) {
  return language === "en"
    ? "I can help with nutrition, workouts, running, and calorie balance. Tell me what you want to adjust today."
    : "Я помогу с питанием, тренировками, бегом и балансом калорий. Напиши, что хочешь настроить сегодня.";
}

function parseBase64UrlJson(value) {
  return JSON.parse(new TextDecoder().decode(base64UrlToUint8Array(value)));
}

function base64UrlToUint8Array(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(
    normalized.length + ((4 - (normalized.length % 4)) % 4),
    "=",
  );
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function httpError(code, status) {
  const error = new Error(code);
  error.code = code;
  error.status = status;
  return error;
}

function json(body, status = 200) {
  return withCors(
    new Response(JSON.stringify(body), {
      status,
      headers: {"Content-Type": "application/json; charset=utf-8"},
    }),
  );
}

function withCors(response) {
  const headers = new Headers(response.headers);
  headers.set("Access-Control-Allow-Origin", "*");
  headers.set("Access-Control-Allow-Headers", "Authorization,Content-Type");
  headers.set("Access-Control-Allow-Methods", "POST,OPTIONS");
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
