import { acquireProviderPermit } from "../_shared/provider_gate.ts";
import {
  decodeSpeechAudio,
  readSpeechRequest,
} from "../_shared/speech_audio.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// 30 seconds of mono 16 kHz PCM once base64-encoded, deliberately far below
// a general file-upload endpoint. The mobile client records vocabulary answers.
const maxAudioBase64Chars = 1_280_128;
const supportedLanguages = new Set(["fr", "ko", "en"]);

const invalidRequest = () =>
  Response.json(
    { error: "Invalid transcription request" },
    { status: 400, headers: corsHeaders },
  );

export async function handleTranscription(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return Response.json(
      { error: "Method not allowed" },
      { status: 405, headers: corsHeaders },
    );
  }
  let body: Record<string, unknown>;
  try {
    body = await readSpeechRequest(req);
  } catch {
    return invalidRequest();
  }
  const permit = await acquireProviderPermit(req, "cloud_stt");
  const quota = permit.status;
  if (quota !== "allowed") {
    return Response.json(
      {
        error: quota === "limited"
          ? "Speech limit reached"
          : "Speech service unavailable",
      },
      {
        status: quota === "limited"
          ? 429
          : quota === "unauthorized"
          ? 401
          : 503,
        headers: corsHeaders,
      },
    );
  }
  let providerInFlight = false;
  try {
    const openAiApiKey = Deno.env.get("OPENAI_API_KEY");
    if (!openAiApiKey) {
      return Response.json(
        { error: "Speech service is not configured" },
        { status: 503, headers: corsHeaders },
      );
    }

    const { audio_base64, language, expected_word } = body;
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
    if (typeof language !== "string" || !supportedLanguages.has(language)) {
      return Response.json(
        { error: "Unsupported language" },
        { status: 400, headers: corsHeaders },
      );
    }

    const binary = decodeSpeechAudio(audio_base64);
    const formData = new FormData();
    formData.append(
      "file",
      new Blob([binary.slice().buffer], { type: "audio/wav" }),
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

    providerInFlight = true;
    const openAiResponse = await fetch(
      "https://api.openai.com/v1/audio/transcriptions",
      {
        method: "POST",
        headers: { Authorization: `Bearer ${openAiApiKey}` },
        body: formData,
        signal: AbortSignal.timeout(60_000),
      },
    );
    const responseBody = await openAiResponse.text();
    providerInFlight = false;
    if (!openAiResponse.ok) {
      // Never relay provider detail: it can include account/billing metadata.
      return Response.json(
        { error: "Speech transcription failed" },
        { status: 502, headers: corsHeaders },
      );
    }

    const data = JSON.parse(responseBody);
    return Response.json(
      { text: typeof data.text === "string" ? data.text.trim() : "" },
      { headers: corsHeaders },
    );
  } catch {
    return invalidRequest();
  } finally {
    if (!providerInFlight) await permit.release();
  }
}
