/**
 * Publishes immutable base-vocabulary audio once, before learners ever enter a
 * quiz. It intentionally uses service credentials supplied through the shell;
 * neither key is committed nor included in the mobile app.
 *
 * Required environment: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
 * ELEVENLABS_API_KEY. Optional: AUDIO_LANGS=fr,en,ko.
 */
import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";

const required = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "ELEVENLABS_API_KEY"];
for (const name of required) {
  if (!process.env[name]) throw new Error(`Missing ${name}`);
}

const url = process.env.SUPABASE_URL.replace(/\/$/, "");
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const elevenKey = process.env.ELEVENLABS_API_KEY;
const languages = (process.env.AUDIO_LANGS ?? "fr,en,ko").split(",").map((x) => x.trim());
const voices = {
  fr: "XB0fDUnXU5powFXDhCwa",
  en: "21m00Tcm4TlvDq8ikWAM",
  ko: "MF3mGyEYCl7XYWbV9V6O",
};

const hash = (text, lang) => createHash("sha256")
  .update(`v1|${lang}|${text}`, "utf8")
  .digest("hex");
const pathFor = (text, lang) => `seed/v1/${lang}/${hash(text, lang)}.mp3`;
const headers = { Authorization: `Bearer ${serviceKey}`, apikey: serviceKey };

async function objectExists(path) {
  const res = await fetch(`${url}/storage/v1/object/list/vocab-audio`, {
    method: "POST",
    headers: { ...headers, "Content-Type": "application/json" },
    body: JSON.stringify({ prefix: path, limit: 1 }),
  });
  if (res.ok) return (await res.json()).length > 0;
  throw new Error(`Storage check ${res.status} for ${path}`);
}

async function publish({ text, lang }) {
  const path = pathFor(text, lang);
  if (await objectExists(path)) return "existing";
  const voice = voices[lang] ?? voices.fr;
  const tts = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voice}?output_format=mp3_22050_32`,
    {
      method: "POST",
      headers: { "xi-api-key": elevenKey, "Content-Type": "application/json", Accept: "audio/mpeg" },
      body: JSON.stringify({ text, model_id: "eleven_multilingual_v2" }),
    },
  );
  if (!tts.ok) throw new Error(`ElevenLabs ${tts.status} for ${lang}:${text}`);
  const upload = await fetch(`${url}/storage/v1/object/vocab-audio/${path}`, {
    method: "POST",
    headers: { ...headers, "Content-Type": "audio/mpeg", "x-upsert": "false", "Cache-Control": "max-age=31536000" },
    body: await tts.arrayBuffer(),
  });
  if (!upload.ok && upload.status !== 409) {
    throw new Error(`Storage upload ${upload.status} for ${path}`);
  }
  return "generated";
}

const items = [];
for (const lang of languages) {
  const layer = JSON.parse(await readFile(`assets/seed/vocab/lang/${lang}.json`, "utf8"));
  for (const entry of Object.values(layer.entries)) {
    for (const word of entry.words) items.push({ text: word.word, lang });
  }
}
const unique = [...new Map(items.map((item) => [`${item.lang}\0${item.text}`, item])).values()];
let generated = 0;
let existing = 0;
const failures = [];
const concurrency = 3;
let cursor = 0;
async function worker() {
  while (cursor < unique.length) {
    const item = unique[cursor++];
    try {
      const result = await publish(item);
      if (result === "generated") generated++; else existing++;
      if ((generated + existing) % 25 === 0) {
        console.log(`${generated + existing}/${unique.length} assets checked`);
      }
    } catch (error) {
      failures.push(`${item.lang}:${item.text} — ${error.message}`);
    }
  }
}
await Promise.all(Array.from({ length: concurrency }, worker));
console.log(`Seed audio: ${generated} generated, ${existing} already present, ${failures.length} failed.`);
if (failures.length) {
  console.error(failures.join("\n"));
  process.exitCode = 1;
}
