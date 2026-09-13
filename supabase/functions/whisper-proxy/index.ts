import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const openAiApiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabasePublishableKey =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  "";

// Enough for several seconds of mono WAV, deliberately far below a general
// file-upload endpoint. The mobile client records short vocabulary answers.
const maxAudioBase64Chars = 1500000;
const supportedLanguages = new Set(["fr", "ko", "en"]);

async function authenticatedUser(req: Request): Promise<boolean> {
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return false;
  if (!supabaseUrl || !supabasePublishableKey) return false;

  // This explicit verification is intentional. The function is deployed with
  // gateway JWT verification disabled so it works with both Supabase's legacy
  // anon keys and newer publishable keys, but it never trusts a client token.
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
  if (!openAiApiKey) {
    return Response.json(
      { error: "Speech service is not configured" },
      { status: 503, headers: corsHeaders },
    );
  }

  try {
    const { audio_base64, language, expected_word } = await req.json();
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
    if (!supportedLanguages.has(language)) {
      return Response.json(
        { error: "Unsupported language" },
        { status: 400, headers: corsHeaders },
      );
    }

    const binary = Uint8Array.from(atob(audio_base64), (char) =>
      char.charCodeAt(0),
    );
    const formData = new FormData();
    formData.append(
      "file",
      new Blob([binary], { type: "audio/wav" }),
      "clip.wav",
    );
    // Benchmark with the high-accuracy model. Its prompt is free text, unlike
    // whisper-1's keyword list, so frame the expected vocabulary as context.
    formData.append("model", "gpt-4o-transcribe");
    formData.append("language", language);
    if (typeof expected_word === "string" && expected_word.trim()) {
      formData.append(
        "prompt",
        `This is a single vocabulary answer. Expected word: ${expected_word.trim()}.`,
      );
    }
    formData.append("response_format", "json");

    const openAiResponse = await fetch(
      "https://api.openai.com/v1/audio/transcriptions",
      {
        method: "POST",
        headers: { Authorization: `Bearer ${openAiApiKey}` },
        body: formData,
      },
    );
    if (!openAiResponse.ok) {
      // Never relay provider detail: it can include account/billing metadata.
      return Response.json(
        { error: "Speech transcription failed" },
        { status: 502, headers: corsHeaders },
      );
    }

    const data = await openAiResponse.json();
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
