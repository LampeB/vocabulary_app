import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const elevenLabsApiKey = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabasePublishableKey =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  "";
const maxAudioBase64Chars = 1_500_000;
const languageCodes: Record<string, string> = {
  fr: "fra",
  ko: "kor",
  en: "eng",
};

async function authenticatedUser(req: Request): Promise<boolean> {
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return false;
  if (!supabaseUrl || !supabasePublishableKey) return false;
  const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      apikey: supabasePublishableKey,
      Authorization: authorization,
    },
  });
  return userResponse.ok;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return Response.json(
      { error: "Method not allowed" },
      { status: 405, headers: corsHeaders },
    );
  }
  if (!await authenticatedUser(req)) {
    return Response.json(
      { error: "Unauthorized" },
      { status: 401, headers: corsHeaders },
    );
  }
  if (!elevenLabsApiKey) {
    return Response.json(
      { error: "Speech service is not configured" },
      { status: 503, headers: corsHeaders },
    );
  }

  try {
    const { audio_base64, audio_format, language, expected_word } =
      await req.json();
    if (typeof audio_base64 !== "string" || audio_base64.length === 0) {
      return Response.json(
        { error: "Missing audio" },
        { status: 400, headers: corsHeaders },
      );
    }
    if (audio_base64.length > maxAudioBase64Chars) {
      return Response.json(
        { error: "Audio clip is too large" },
        { status: 413, headers: corsHeaders },
      );
    }
    const languageCode = languageCodes[language];
    if (!languageCode) {
      return Response.json(
        { error: "Unsupported language" },
        { status: 400, headers: corsHeaders },
      );
    }

    const rawPcm = audio_format === "pcm_s16le_16";
    const binary = Uint8Array.from(atob(audio_base64), (char) =>
      char.charCodeAt(0),
    );
    const formData = new FormData();
    formData.append(
      "file",
      new Blob([binary], { type: rawPcm ? "audio/pcm" : "audio/wav" }),
      rawPcm ? "clip.pcm" : "clip.wav",
    );
    formData.append("model_id", "scribe_v2");
    formData.append("language_code", languageCode);
    if (rawPcm) formData.append("file_format", "pcm_s16le_16");
    formData.append("tag_audio_events", "false");
    // Scribe's keyterm prompt is contextual rather than an unconditional
    // replacement: ideal for a known vocabulary answer in a quiz.
    if (typeof expected_word === "string" && expected_word.trim()) {
      formData.append("keyterms", expected_word.trim());
    }

    const response = await fetch("https://api.elevenlabs.io/v1/speech-to-text", {
      method: "POST",
      headers: { "xi-api-key": elevenLabsApiKey },
      body: formData,
    });
    if (!response.ok) {
      // Provider details can contain subscription information; never relay it.
      return Response.json(
        { error: "Speech transcription failed" },
        { status: 502, headers: corsHeaders },
      );
    }
    const data = await response.json();
    return Response.json(
      { text: typeof data.text === "string" ? data.text.trim() : "" },
      { headers: corsHeaders },
    );
  } catch (_) {
    return Response.json(
      { error: "Invalid transcription request" },
      { status: 400, headers: corsHeaders },
    );
  }
});
