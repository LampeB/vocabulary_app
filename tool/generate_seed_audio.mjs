/**
 * Publishes immutable base-vocabulary audio once, before learners ever enter a
 * quiz. It intentionally uses service credentials supplied through the shell;
 * neither key is committed nor included in the mobile app.
 *
 * Required environment: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
 * ElevenLabs is deliberately not an input: Supabase owns that secret and the
 * protected publishing function uses it server-side. Optional: AUDIO_LANGS.
 */
import { readFile } from "node:fs/promises";

const required = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"];
for (const name of required) {
  if (!process.env[name]) throw new Error(`Missing ${name}`);
}

const url = process.env.SUPABASE_URL.replace(/\/$/, "");
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const languages = (process.env.AUDIO_LANGS ?? "fr,en,ko").split(",").map((x) => x.trim());
const headers = { Authorization: `Bearer ${serviceKey}`, apikey: serviceKey };

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
for (let i = 0; i < unique.length; i += 10) {
  const chunk = unique.slice(i, i + 10);
  try {
    const res = await fetch(`${url}/functions/v1/seed-audio-publish`, {
      method: "POST",
      headers: { ...headers, "Content-Type": "application/json" },
      body: JSON.stringify({ items: chunk }),
    });
    if (!res.ok) throw new Error(`Supabase ${res.status}`);
    const result = await res.json();
    generated += result.generated ?? 0;
    existing += result.existing ?? 0;
    failures.push(...(result.failed ?? []));
  } catch (error) {
    failures.push(`batch ${i / 10 + 1} — ${error.message}`);
  }
  console.log(`${Math.min(i + 10, unique.length)}/${unique.length} assets published`);
}
console.log(`Seed audio: ${generated} generated, ${existing} already present, ${failures.length} failed.`);
if (failures.length) {
  console.error(failures.join("\n"));
  process.exitCode = 1;
}
