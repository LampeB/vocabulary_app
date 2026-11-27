// AI assistance for list creation (user request 2026-07-11): translation
// suggestions when adding a word, theme-aware word suggestions for a list,
// and voice-friendly alternative forms for words too short for reliable
// speech recognition (single syllables defeat every STT engine's
// endpointing — a subject/particle fixes the acoustics AND is more natural
// language anyway).
//
// Same security model as generate-grammar-exercises: ANTHROPIC_API_KEY is a
// function secret, JWT verification is on, the app never ships a key.
import Anthropic from "npm:@anthropic-ai/sdk";
import { authorizeAndConsume } from "../_shared/provider_gate.ts";
import { boundedJson, boundedText } from "../_shared/request_limits.ts";

const TRANSLATE_SCHEMA = {
  type: "object",
  properties: {
    translations: {
      type: "array",
      items: {
        type: "object",
        properties: {
          text: {
            type: "string",
            description: "Translation in the target language",
          },
          note: {
            type: "string",
            description:
              "Optional short disambiguation note in the SOURCE language, e.g. 'boisson' for café. Empty string if none needed.",
          },
        },
        required: ["text", "note"],
        additionalProperties: false,
      },
      description: "1-4 translations, most common first",
    },
    voiceFriendly: {
      type: "array",
      items: {
        type: "object",
        properties: {
          source: {
            type: "string",
            description: "Voice-friendly form of the SOURCE word",
          },
          target: {
            type: "string",
            description:
              "Matching voice-friendly form of the FIRST translation",
          },
        },
        required: ["source", "target"],
        additionalProperties: false,
      },
      description:
        "Empty unless a side is very short (1 syllable / <=3 letters): 1-2 natural longer forms (article+noun, subject+verb, noun+particle+verb) that keep the same core word",
    },
  },
  required: ["translations", "voiceFriendly"],
  additionalProperties: false,
} as const;

const SUGGEST_SCHEMA = {
  type: "object",
  properties: {
    theme: {
      type: "string",
      description: "The list's theme in the source language, 2-4 words",
    },
    suggestions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          source: { type: "string" },
          target: { type: "string" },
        },
        required: ["source", "target"],
        additionalProperties: false,
      },
      description: "New word pairs on the theme, NOT already in the list",
    },
  },
  required: ["theme", "suggestions"],
  additionalProperties: false,
} as const;

const LANG_NAMES: Record<string, string> = {
  fr: "French",
  ko: "Korean",
  en: "English",
  ja: "Japanese",
  es: "Spanish",
  de: "German",
  it: "Italian",
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  let body;
  try {
    body = await boundedJson(req);
  } catch {
    return Response.json({ error: "Invalid JSON" }, { status: 400 });
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return Response.json({ error: "Invalid request" }, { status: 400 });
  }
  const mode = body.mode as string;
  if (
    !["translate", "suggest"].includes(mode) ||
    !boundedText(body.sourceLang, 8) || !boundedText(body.targetLang, 8) ||
    !LANG_NAMES[body.sourceLang] || !LANG_NAMES[body.targetLang] ||
    (mode === "translate" && !boundedText(body.word, 256)) ||
    (body.theme !== undefined && !boundedText(body.theme, 256, false)) ||
    (body.existingWords !== undefined && (!Array.isArray(body.existingWords) ||
      body.existingWords.length > 80 ||
      !body.existingWords.every((v: unknown) => boundedText(v, 256)))) ||
    (body.existingPairs !== undefined && (!Array.isArray(body.existingPairs) ||
      body.existingPairs.length > 80 ||
      !body.existingPairs.every((v: unknown) => {
        const pair = v as { source?: unknown; target?: unknown } | null;
        return pair && boundedText(pair.source, 256) &&
          boundedText(pair.target, 256);
      }))) ||
    (body.count !== undefined &&
      (!Number.isInteger(body.count) || Number(body.count) < 1 ||
        Number(body.count) > 20))
  ) {
    return Response.json({ error: "Invalid or oversized assistant input" }, {
      status: 400,
    });
  }

  const quota = await authorizeAndConsume(
    req,
    mode === "suggest" ? "suggest" : "translate",
  );
  if (quota !== "allowed") {
    const status = quota === "unauthorized"
      ? 401
      : quota === "limited"
      ? 429
      : 503;
    return Response.json({
      error: quota === "limited"
        ? "Daily assistant limit reached"
        : "Assistant unavailable",
    }, { status });
  }
  const anthropic = new Anthropic({
    apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
    timeout: 60_000,
    maxRetries: 0,
  });

  try {
    if (mode === "translate") {
      const { word, sourceLang, targetLang, theme, existingWords } = body;
      const msg = await anthropic.messages.create({
        model: "claude-haiku-4-5",
        max_tokens: 1024,
        system:
          `You are a vocabulary assistant for a ${
            LANG_NAMES[sourceLang] ?? sourceLang
          } ↔ ${LANG_NAMES[targetLang] ?? targetLang} learning app. ` +
          `Given a word in ${
            LANG_NAMES[sourceLang] ?? sourceLang
          }, provide its translation(s) in ${
            LANG_NAMES[targetLang] ?? targetLang
          }. ` +
          `Most common/useful translation first. Add a short disambiguation note (in ${
            LANG_NAMES[sourceLang] ?? sourceLang
          }) only when the word is ambiguous. ` +
          `If the list theme is provided, prefer the meaning that fits the theme. ` +
          `If either the word or its main translation is very short (one syllable or <=3 letters), also provide 1-2 voiceFriendly longer forms ` +
          `(e.g. article+noun "le riz", noun+particle+verb "밥을 먹다") — matched pairs, same core word, natural everyday language.`,
        messages: [{
          role: "user",
          content: JSON.stringify({
            word,
            theme: theme ?? "",
            existing_words: existingWords ?? [],
          }),
        }],
        output_config: {
          format: { type: "json_schema", schema: TRANSLATE_SCHEMA },
        },
      });
      return Response.json(
        JSON.parse((msg.content[0] as { text: string }).text),
      );
    }

    if (mode === "suggest") {
      const { sourceLang, targetLang, existingPairs, count } = body;
      const msg = await anthropic.messages.create({
        model: "claude-haiku-4-5",
        max_tokens: 2048,
        system:
          `You are a vocabulary assistant for a ${
            LANG_NAMES[sourceLang] ?? sourceLang
          } ↔ ${LANG_NAMES[targetLang] ?? targetLang} learning app. ` +
          `From the existing word pairs, infer the list's THEME, then suggest ${
            count ?? 8
          } NEW useful word pairs on that theme. ` +
          `Never repeat a word already in the list. Everyday, high-frequency words first. ` +
          `source = ${LANG_NAMES[sourceLang] ?? sourceLang}, target = ${
            LANG_NAMES[targetLang] ?? targetLang
          }.`,
        messages: [{
          role: "user",
          content: JSON.stringify({ existing_pairs: existingPairs ?? [] }),
        }],
        output_config: {
          format: { type: "json_schema", schema: SUGGEST_SCHEMA },
        },
      });
      return Response.json(
        JSON.parse((msg.content[0] as { text: string }).text),
      );
    }

    return Response.json({ error: `unknown mode: ${mode}` }, { status: 400 });
  } catch (_) {
    // Provider exceptions can contain billing/account metadata or request text.
    return Response.json({ error: "Assistant unavailable" }, { status: 502 });
  }
});
