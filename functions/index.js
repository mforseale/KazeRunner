"use strict";

const admin = require("firebase-admin");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");

admin.initializeApp();

const polzaApiKey = defineSecret("POLZA_AI_API_KEY");
const polzaBaseUrl = "https://polza.ai/api/v1/chat/completions";
const defaultModel = "google/gemini-2.0-flash-lite-001";

exports.kazeChat = onRequest(
  {
    region: "europe-west1",
    timeoutSeconds: 60,
    memory: "256MiB",
    secrets: [polzaApiKey],
  },
  async (request, response) => {
    if (request.method === "OPTIONS") {
      response.set("Access-Control-Allow-Origin", "*");
      response.set("Access-Control-Allow-Headers", "Authorization,Content-Type");
      response.set("Access-Control-Allow-Methods", "POST");
      response.status(204).send("");
      return;
    }
    if (request.method !== "POST") {
      response.status(405).json({error: "method-not-allowed"});
      return;
    }

    try {
      const uid = await verifyUser(request);
      const body = request.body || {};
      const message = typeof body.message === "string" ? body.message.trim() : "";
      const language = body.language === "en" ? "en" : "ru";
      const context = sanitizeContext(body.context);
      if (!message) {
        response.status(400).json({error: "empty-message"});
        return;
      }

      const ruleHint = buildRuleHint(message, language, context);
      const reply = await generatePolzaReply({
        uid,
        message,
        language,
        context,
        ruleHint,
      });
      response.json({reply: reply || ruleHint || fallbackReply(language)});
    } catch (error) {
      console.error("kazeChat failed", error);
      const status = error.status || 500;
      response.status(status).json({error: error.code || "kaze-chat-failed"});
    }
  },
);

async function verifyUser(request) {
  const header = request.get("authorization") || "";
  if (!header.startsWith("Bearer ")) {
    const error = new Error("Missing auth token");
    error.status = 401;
    error.code = "missing-auth-token";
    throw error;
  }
  const token = header.slice("Bearer ".length);
  const decoded = await admin.auth().verifyIdToken(token);
  return decoded.uid;
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
  if (contains(text, ["meal", "food", "nutrition", "ration", "calorie", "bju", "protein", "еда", "пит", "рацион", "бжу", "калор"])) {
    return language === "en"
      ? `Use the daily targets as a hard reference: ${targets.calories || "?"} kcal, protein ${targets.protein || "?"} g, fat ${targets.fat || "?"} g, carbs ${targets.carbs || "?"} g. Give practical meals and portion guidance.`
      : `Используй дневные цели как опору: ${targets.calories || "?"} ккал, белки ${targets.protein || "?"} г, жиры ${targets.fat || "?"} г, углеводы ${targets.carbs || "?"} г. Дай практичные блюда и порции.`;
  }
  if (contains(text, ["workout", "training", "exercise", "fatigue", "injury", "трен", "упраж", "устал", "травм"])) {
    return language === "en"
      ? "Prioritize safe technique, current fatigue, goal, and recent training history. If pain or injury is mentioned, suggest lower-risk substitutions and recommend medical advice for sharp or worsening pain."
      : "Учитывай технику, усталость, цель и недавние тренировки. Если есть боль или травма, предложи более безопасные замены и посоветуй врача при острой или усиливающейся боли.";
  }
  if (contains(text, ["run", "pace", "marathon", "бег", "темп", "марафон", "км"])) {
    return language === "en"
      ? "Use recent runs and total distance. Keep running advice gradual and avoid sudden mileage jumps."
      : "Опирайся на последние пробежки и общий километраж. Советы по бегу делай постепенными, без резкого роста объема.";
  }
  return "";
}

async function generatePolzaReply({uid, message, language, context, ruleHint}) {
  const apiKey = polzaApiKey.value();
  if (!apiKey) {
    throw Object.assign(new Error("Missing POLZA_AI_API_KEY"), {
      status: 500,
      code: "missing-polza-ai-api-key",
    });
  }
  const model = process.env.POLZA_MODEL || defaultModel;
  const systemText = [
    "You are Kaze, a fitness and nutrition assistant inside the Kaze Runner app.",
    "Use the provided user context, but do not invent exact logs that are not present.",
    "Be concise, friendly, practical, and safety-aware.",
    "For medical pain, injuries, medication, eating disorders, pregnancy, or severe symptoms, give conservative guidance and recommend a qualified professional.",
    language === "en" ? "Reply in English." : "Reply in Russian.",
    ruleHint ? `Rule-based hint to respect: ${ruleHint}` : "",
    `Firebase uid: ${uid}`,
  ].filter(Boolean).join("\n");

  const payload = {
    model,
    messages: [
      {
        role: "system",
        content: systemText,
      },
      {
        role: "user",
        content: JSON.stringify({
          message,
          context,
        }),
      },
    ],
    temperature: 0.65,
    max_tokens: 900,
  };

  const polzaResponse = await fetch(polzaBaseUrl, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  const polzaBody = await polzaResponse.json().catch(() => ({}));
  if (!polzaResponse.ok) {
    console.error("PolzaAI error", polzaResponse.status, polzaBody);
    return null;
  }
  const choice = (polzaBody.choices || [])[0] || {};
  const content = ((choice.message || {}).content || "").trim();
  return content || null;
}

function contains(text, words) {
  return words.some((word) => text.includes(word));
}

function fallbackReply(language) {
  return language === "en"
    ? "I can help with nutrition, workouts, running, and calorie balance. Tell me what you want to adjust today."
    : "Я помогу с питанием, тренировками, бегом и балансом калорий. Напиши, что хочешь настроить сегодня.";
}
