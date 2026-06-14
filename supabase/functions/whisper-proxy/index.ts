import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  try {
    const { audio_base64, language, expected_word } = await req.json();

    if (!audio_base64) {
      return Response.json({ error: "Missing audio_base64" }, { status: 400 });
    }

    // Decode base64 to bytes
    const binaryStr = atob(audio_base64);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) {
      bytes[i] = binaryStr.charCodeAt(i);
    }

    // Build multipart form
    const formData = new FormData();
    formData.append(
      "file",
      new Blob([bytes], { type: "audio/m4a" }),
      "audio.m4a"
    );
    formData.append("model", "whisper-1");
    if (language) formData.append("language", language);
    // Initial prompt biases Whisper toward the expected word — key for short Korean words
    if (expected_word) formData.append("prompt", expected_word);
    formData.append("temperature", "0");
    formData.append("response_format", "verbose_json");

    const whisperRes = await fetch(
      "https://api.openai.com/v1/audio/transcriptions",
      {
        method: "POST",
        headers: { Authorization: `Bearer ${OPENAI_API_KEY}` },
        body: formData,
      }
    );

    if (!whisperRes.ok) {
      const err = await whisperRes.text();
      return Response.json({ error: err }, { status: whisperRes.status });
    }

    const data = await whisperRes.json();
    const text: string = data.text ?? "";
    const confidence: number | null =
      data.segments?.[0]?.avg_logprob ?? null;

    return Response.json(
      { text: text.trim(), confidence },
      {
        headers: { "Access-Control-Allow-Origin": "*" },
      }
    );
  } catch (e) {
    return Response.json(
      { error: String(e) },
      {
        status: 500,
        headers: { "Access-Control-Allow-Origin": "*" },
      }
    );
  }
});
