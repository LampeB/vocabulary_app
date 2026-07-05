// Generates grammar exercises AT RUNTIME from (rules + the user's known
// words) — the language-agnostic replacement for pre-authored exercise banks
// (product decision 2026-07-05: any user list must work, e.g. fishing/robots,
// so semantic reasoning happens per-request in the model, not in static
// annotation files).
//
// The API key lives here, server-side (ANTHROPIC_API_KEY function secret);
// the app never ships it. JWT verification is on (Supabase default), so only
// authenticated users can call this.
import Anthropic from "npm:@anthropic-ai/sdk";

// What the model must return — enforced via structured outputs, so the
// client never has to repair malformed JSON.
const EXERCISE_SCHEMA = {
  type: "object",
  properties: {
    exercises: {
      type: "array",
      items: {
        type: "object",
        properties: {
          prompt: {
            type: "string",
            description:
              "Full natural sentence in the prompt language for the learner to translate",
          },
          expected: {
            type: "string",
            description: "The canonical full-sentence answer in the target language",
          },
          accepted: {
            type: "array",
            items: { type: "string" },
            description:
              "All acceptable answers, including the expected one and pro-drop/word-order variants",
          },
        },
        required: ["prompt", "expected", "accepted"],
        additionalProperties: false,
      },
    },
  },
  required: ["exercises"],
  additionalProperties: false,
} as const;

const SYSTEM_PROMPT = `You generate language-learning exercises for a vocabulary app.

You receive:
- target_rule: the grammar rule the learner is currently practising (with its mechanics and examples)
- mastered_rules: rules the learner has already mastered (compose them freely with the target rule)
- words: the ONLY vocabulary the learner knows, as {word, category} in the target language
- prompt_language: the language the learner's prompts must be written in
- count: how many exercises to produce

Rules for every exercise:
1. FULL-SENTENCE PRODUCTION: the prompt is a complete natural sentence in prompt_language; the learner must produce the ENTIRE sentence in the target language. Never fill-in-the-blank, never "complete with the right word".
2. Every exercise MUST exercise target_rule. Mix in mastered_rules progressively so sentences feel like useful day-to-day language.
3. Use ONLY the provided words (plus particles/conjugations/function morphemes required by the rules, plus pronouns). Never introduce vocabulary the learner doesn't know.
4. expected is the most natural answer. accepted lists every reasonable variant: pro-drop (subject omitted), particle-omission where colloquially fine, and word-order variants. expected must also appear in accepted.
5. Grade difficulty across the batch: start with short sentences (one rule), end with sentences composing 2-3 mastered rules with the target rule.
6. Prompts must sound natural in prompt_language — not word-for-word glosses.
7. Apply the grammar mechanics EXACTLY as specified (particle variants by final sound, conjugation contractions, irregulars listed in the rule data).`;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  let body: {
    target_rule?: unknown;
    mastered_rules?: unknown[];
    words?: { word: string; category: string }[];
    prompt_language?: string;
    target_language?: string;
    count?: number;
  };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid_json" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const words = Array.isArray(body.words) ? body.words.slice(0, 80) : [];
  const count = Math.min(Math.max(Number(body.count) || 10, 1), 30);
  if (!body.target_rule || words.length === 0) {
    return new Response(JSON.stringify({ error: "missing_rule_or_words" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const client = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

  const response = await client.messages.create({
    model: "claude-haiku-4-5",
    max_tokens: 8000,
    system: SYSTEM_PROMPT,
    output_config: { format: { type: "json_schema", schema: EXERCISE_SCHEMA } },
    messages: [
      {
        role: "user",
        content: JSON.stringify({
          target_rule: body.target_rule,
          mastered_rules: body.mastered_rules ?? [],
          words,
          prompt_language: body.prompt_language ?? "fr",
          target_language: body.target_language ?? "ko",
          count,
        }),
      },
    ],
  });

  const text = response.content.find((b) => b.type === "text");
  return new Response(text?.type === "text" ? text.text : '{"exercises":[]}', {
    headers: { "Content-Type": "application/json" },
  });
});
