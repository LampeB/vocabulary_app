import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const bucket = "vocab-audio";
const seedVersion = "v1";
const voiceByLanguage: Record<string, { id: string; label: string }> = {
  fr: { id: "XB0fDUnXU5powFXDhCwa", label: "Charlotte" },
  en: { id: "21m00Tcm4TlvDq8ikWAM", label: "Rachel" },
  ko: { id: "MF3mGyEYCl7XYWbV9V6O", label: "Elli" },
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const elevenLabsKey = Deno.env.get("ELEVENLABS_API_KEY") ?? "";

function response(body: unknown, status = 200) {
  return Response.json(body, { status, headers: cors });
}

async function hash(text: string, lang: string) {
  const bytes = new TextEncoder().encode(`${seedVersion}|${lang}|${text}`);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") return response({ error: "Method not allowed" }, 405);
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return response({ error: "Server is not configured" }, 503);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return response({ error: "Authentication required" }, 401);

  const auth = createClient(supabaseUrl, anonKey);
  const { data: authData, error: authError } = await auth.auth.getUser(token);
  const user = authData.user;
  if (authError || !user) return response({ error: "Invalid session" }, 401);

  let variantId: string;
  try {
    variantId = (await req.json()).variant_id;
  } catch (_) {
    return response({ error: "Invalid JSON" }, 400);
  }
  if (typeof variantId !== "string" || variantId.length < 20) {
    return response({ error: "Invalid variant_id" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { data: variant, error: variantError } = await admin
    .from("word_variants")
    .select("id, word, lang_code, is_deleted, concept:concepts!inner(list:vocabulary_lists!inner(owner_id, origin))")
    .eq("id", variantId)
    .maybeSingle();
  if (variantError || !variant || variant.is_deleted) {
    return response({ error: "Variant not found" }, 404);
  }

  const concept = variant.concept as unknown as {
    list: { owner_id: string; origin: string };
  };
  const list = concept?.list;
  if (!list || list.owner_id !== user.id) {
    return response({ error: "Forbidden" }, 403);
  }

  const lang = variant.lang_code as string;
  const text = variant.word as string;
  const textHash = await hash(text, lang);
  const isSeed = list.origin === "starter";
  const audioPath = isSeed
    ? `seed/${seedVersion}/${lang}/${textHash}.mp3`
    : `users/${user.id}/${variant.id}/${textHash}.mp3`;

  const { error: existingError } = await admin.storage.from(bucket).download(audioPath);
  if (!existingError) {
    await admin.from("word_variants").update({ audio_path: audioPath }).eq("id", variant.id);
    return response({ audio_path: audioPath, status: "ready" });
  }
  if (!elevenLabsKey) return response({ error: "TTS unavailable" }, 503);

  const voice = voiceByLanguage[lang] ?? voiceByLanguage.fr;
  const tts = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voice.id}?output_format=mp3_22050_32`,
    {
      method: "POST",
      headers: {
        "xi-api-key": elevenLabsKey,
        "Content-Type": "application/json",
        Accept: "audio/mpeg",
      },
      body: JSON.stringify({
        text,
        model_id: "eleven_multilingual_v2",
        voice_settings: {
          stability: 0.5,
          similarity_boost: 0.8,
          style: 0,
          use_speaker_boost: true,
        },
      }),
    },
  );
  if (!tts.ok) return response({ error: "TTS generation failed" }, 502);

  const { error: uploadError } = await admin.storage.from(bucket).upload(
    audioPath,
    new Uint8Array(await tts.arrayBuffer()),
    { contentType: "audio/mpeg", cacheControl: "31536000", upsert: false },
  );
  // A concurrent request may have won the immutable upload race; either way,
  // the object now exists and the variant can safely reference it.
  if (uploadError && !/already exists/i.test(uploadError.message)) {
    return response({ error: "Audio storage failed" }, 502);
  }

  await admin
    .from("word_variants")
    .update({ audio_path: audioPath, audio_hash: textHash, audio_voice_id: voice.label })
    .eq("id", variant.id);
  return response({ audio_path: audioPath, status: "ready" });
});
