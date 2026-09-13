"""Run a local Faster-Whisper benchmark against a labelled WAV corpus.

Usage:
  python tool/benchmark_stt.py tool/stt_corpus --model small

The corpus directory is ignored by Git because it can contain personal voice
recordings. This script sends neither audio nor transcripts to a network API;
the first run only downloads the requested open-source model weights.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

from faster_whisper import WhisperModel


def main() -> None:
    # Windows PowerShell often defaults to cp1252, which cannot print Korean.
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("corpus", type=Path)
    parser.add_argument("--model", default="small")
    parser.add_argument("--threads", type=int, default=8)
    args = parser.parse_args()

    manifest_path = args.corpus / "manifest.json"
    samples = json.loads(manifest_path.read_text(encoding="utf-8"))
    model = WhisperModel(
        args.model,
        device="cpu",
        compute_type="int8",
        cpu_threads=args.threads,
    )

    results = []
    for index, sample in enumerate(reversed(samples), start=1):
        audio_path = args.corpus / f"{sample['id']}.wav"
        started = time.perf_counter()
        segments, _ = model.transcribe(
            str(audio_path),
            language=sample["langCode"],
            initial_prompt=sample["word"],
            beam_size=5,
            condition_on_previous_text=False,
            vad_filter=False,
        )
        transcript = "".join(segment.text for segment in segments).strip()
        elapsed_ms = round((time.perf_counter() - started) * 1000)
        result = {
            "id": sample["id"],
            "word": sample["word"],
            "langCode": sample["langCode"],
            "transcript": transcript,
            "elapsedMs": elapsed_ms,
        }
        results.append(result)
        print(
            f"{index:02d}/{len(samples)} [{sample['langCode']}] "
            f"{sample['word']} -> {transcript or '<empty>'} ({elapsed_ms}ms)",
            flush=True,
        )

    output = args.corpus / f"faster_whisper_{args.model}_results.json"
    output.write_text(json.dumps(results, ensure_ascii=False, indent=2),
                      encoding="utf-8")
    print(f"Saved local report: {output}")


if __name__ == "__main__":
    main()
