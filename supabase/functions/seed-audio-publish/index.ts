import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

// This endpoint is a publishing tool, never an app endpoint. It accepts only
// Supabase's server key, so the ElevenLabs key remains solely in Supabase
// secrets and is never copied to a developer workstation or mobile client.
const bucket = "vocab-audio";
const seedVersion = "v1";
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const elevenLabsKey = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
const voiceByLanguage: Record<string, string> = {
  fr: "XB0fDUnXU5powFXDhCwa",
  en: "21m00Tcm4TlvDq8ikWAM",
  ko: "MF3mGyEYCl7XYWbV9V6O",
};

function json(body: unknown, status = 200) {
  return Response.json(body, { status });
}

async function contentHash(text: string, lang: string) {
  const bytes = new TextEncoder().encode(`${seedVersion}|${lang}|${text}`);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !elevenLabsKey) {
    return json({ error: "Server is not configured" }, 503);
  }
  const authorization = req.headers.get("Authorization") ?? "";
  // Accept either Supabase's legacy service_role JWT or a modern secret key.
  // GoTrue verifies the credential and only permits this admin route to a
  // service-level key; no locally duplicated comparison secret is needed.
  const callerCheck = await fetch(`${supabaseUrl}/auth/v1/admin/users?page=1&per_page=1`, {
    headers: { apikey: anonKey, Authorization: authorization },
  });
  if (!callerCheck.ok) {
    return json({ error: "Forbidden" }, 403);
  }

  let items: Array<{ text: string; lang: string }>;
  try {
    items = (await req.json()).items;
  } catch (_) {
    return json({ error: "Invalid JSON" }, 400);
  }
  if (!Array.isArray(items) || items.length === 0 || items.length > 25) {
    return json({ error: "items must contain 1 to 25 entries" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);
  var generated = 0;
  var existing = 0;
  const failed: string[] = [];
  for (const item of items) {
    if (typeof item?.text !== "string" || !voiceByLanguage[item.lang]) {
      failed.push("invalid item");
      continue;
    }
    const hash = await contentHash(item.text, item.lang);
    const path = `seed/${seedVersion}/${item.lang}/${hash}.mp3`;
    const { error: existingError } = await admin.storage.from(bucket).download(path);
    if (!existingError) {
      existing++;
      continue;
    }
    try {
      const voiceId = voiceByLanguage[item.lang];
      const tts = await fetch(
        `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}?output_format=mp3_22050_32`,
        {
          method: "POST",
          headers: {
            "xi-api-key": elevenLabsKey,
            "Content-Type": "application/json",
            Accept: "audio/mpeg",
          },
          body: JSON.stringify({ text: item.text, model_id: "eleven_multilingual_v2" }),
        },
      );
      if (!tts.ok) throw new Error(`TTS ${tts.status}`);
      const { error: uploadError } = await admin.storage.from(bucket).upload(
        path,
        new Uint8Array(await tts.arrayBuffer()),
        { contentType: "audio/mpeg", cacheControl: "31536000", upsert: false },
      );
      if (uploadError && !/already exists/i.test(uploadError.message)) {
        throw uploadError;
      }
      generated++;
    } catch (_) {
      failed.push(`${item.lang}:${item.text}`);
    }
  }
  return json({ generated, existing, failed });
});
