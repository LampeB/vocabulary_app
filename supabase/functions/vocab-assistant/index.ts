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

const TRANSLATE_SCHEMA = {
  type: "object",
  properties: {
    translations: {
      type: "array",
      items: {
        type: "object",
        properties: {
          text: { type: "string", description: "Translation in the target language" },
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
          source: { type: "string", description: "Voice-friendly form of the SOURCE word" },
          target: { type: "string", description: "Matching voice-friendly form of the FIRST translation" },
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
  const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });
  const body = await req.json();
  const mode = body.mode as string;

  try {
    if (mode === "translate") {
      const { word, sourceLang, targetLang, theme, existingWords } = body;
      const msg = await anthropic.messages.create({
        model: "claude-haiku-4-5",
        max_tokens: 1024,
        system:
          `You are a vocabulary assistant for a ${LANG_NAMES[sourceLang] ?? sourceLang} ↔ ${LANG_NAMES[targetLang] ?? targetLang} learning app. ` +
          `Given a word in ${LANG_NAMES[sourceLang] ?? sourceLang}, provide its translation(s) in ${LANG_NAMES[targetLang] ?? targetLang}. ` +
          `Most common/useful translation first. Add a short disambiguation note (in ${LANG_NAMES[sourceLang] ?? sourceLang}) only when the word is ambiguous. ` +
          `If the list theme is provided, prefer the meaning that fits the theme. ` +
          `If either the word or its main translation is very short (one syllable or <=3 letters), also provide 1-2 voiceFriendly longer forms ` +
          `(e.g. article+noun "le riz", noun+particle+verb "밥을 먹다") — matched pairs, same core word, natural everyday language.`,
        messages: [{
          role: "user",
          content: JSON.stringify({ word, theme: theme ?? "", existing_words: existingWords ?? [] }),
        }],
        output_config: { format: { type: "json_schema", schema: TRANSLATE_SCHEMA } },
      });
      return Response.json(JSON.parse((msg.content[0] as { text: string }).text));
    }

    if (mode === "suggest") {
      const { sourceLang, targetLang, existingPairs, count } = body;
      const msg = await anthropic.messages.create({
        model: "claude-haiku-4-5",
        max_tokens: 2048,
        system:
          `You are a vocabulary assistant for a ${LANG_NAMES[sourceLang] ?? sourceLang} ↔ ${LANG_NAMES[targetLang] ?? targetLang} learning app. ` +
          `From the existing word pairs, infer the list's THEME, then suggest ${count ?? 8} NEW useful word pairs on that theme. ` +
          `Never repeat a word already in the list. Everyday, high-frequency words first. ` +
          `source = ${LANG_NAMES[sourceLang] ?? sourceLang}, target = ${LANG_NAMES[targetLang] ?? targetLang}.`,
        messages: [{
          role: "user",
          content: JSON.stringify({ existing_pairs: existingPairs ?? [] }),
        }],
        output_config: { format: { type: "json_schema", schema: SUGGEST_SCHEMA } },
      });
      return Response.json(JSON.parse((msg.content[0] as { text: string }).text));
    }

    return Response.json({ error: `unknown mode: ${mode}` }, { status: 400 });
  } catch (e) {
    console.error("vocab-assistant failure:", e);
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
