#include "whisper.h"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace {

std::mutex context_mutex;
whisper_context *context = nullptr;
std::string loaded_model;
thread_local char last_error[512] = {};

// Error reporting must still work after an allocation failure, and no C++
// exception may cross the Dart FFI boundary.
void fail(const char *message) noexcept {
  std::snprintf(last_error, sizeof(last_error), "%s", message);
}

uint16_t read_u16(const uint8_t *bytes) {
  return static_cast<uint16_t>(bytes[0]) |
         (static_cast<uint16_t>(bytes[1]) << 8);
}

uint32_t read_u32(const uint8_t *bytes) {
  return static_cast<uint32_t>(bytes[0]) |
         (static_cast<uint32_t>(bytes[1]) << 8) |
         (static_cast<uint32_t>(bytes[2]) << 16) |
         (static_cast<uint32_t>(bytes[3]) << 24);
}

bool read_pcm16_wav(const char *path, std::vector<float> *samples) {
  std::ifstream file(path, std::ios::binary);
  if (!file) {
    fail("Unable to open the WAV capture");
    return false;
  }

  file.seekg(0, std::ios::end);
  const auto file_size = file.tellg();
  // A 30-second PCM16 mono clip uses 960,000 bytes. Keep bounded room for
  // metadata, and reject untrusted chunk sizes before any allocation.
  constexpr uint32_t max_pcm_bytes = WHISPER_SAMPLE_RATE * 30 * 2;
  constexpr uint32_t max_file_bytes = max_pcm_bytes + 65536;
  if (file_size < 12 || file_size > max_file_bytes) {
    fail("WAV capture must contain at most 30 seconds of audio");
    return false;
  }
  file.seekg(0, std::ios::beg);

  uint8_t header[12];
  file.read(reinterpret_cast<char *>(header), sizeof(header));
  if (file.gcount() != sizeof(header) || std::memcmp(header, "RIFF", 4) != 0 ||
      std::memcmp(header + 8, "WAVE", 4) != 0) {
    fail("Capture is not a RIFF/WAVE file");
    return false;
  }
  if (static_cast<uint64_t>(read_u32(header + 4)) + 8 !=
      static_cast<uint64_t>(file_size)) {
    fail("Invalid RIFF container size");
    return false;
  }

  uint16_t channels = 0;
  uint16_t bits_per_sample = 0;
  uint32_t sample_rate = 0;
  std::vector<int16_t> pcm;
  bool found_format = false;
  bool found_data = false;

  while (file && (!found_format || !found_data)) {
    uint8_t chunk_header[8];
    file.read(reinterpret_cast<char *>(chunk_header), sizeof(chunk_header));
    if (file.gcount() != sizeof(chunk_header)) break;
    const uint32_t chunk_size = read_u32(chunk_header + 4);
    const auto chunk_start = file.tellg();
    const uint64_t padded_size = static_cast<uint64_t>(chunk_size) + (chunk_size % 2);
    if (chunk_start < 0 || padded_size >
        static_cast<uint64_t>(file_size - chunk_start)) {
      fail("WAV chunk exceeds the capture size");
      return false;
    }
    const std::string chunk_id(reinterpret_cast<char *>(chunk_header), 4);

    if (chunk_id == "fmt ") {
      if (chunk_size < 16) {
        fail("Invalid WAV format chunk");
        return false;
      }
      uint8_t format[16];
      file.read(reinterpret_cast<char *>(format), sizeof(format));
      if (file.gcount() != sizeof(format) || read_u16(format) != 1) {
        fail("Only PCM WAV captures are supported");
        return false;
      }
      channels = read_u16(format + 2);
      sample_rate = read_u32(format + 4);
      bits_per_sample = read_u16(format + 14);
      found_format = true;
    } else if (chunk_id == "data") {
      if (chunk_size == 0 || chunk_size > max_pcm_bytes ||
          chunk_size % sizeof(int16_t) != 0) {
        fail("Invalid PCM payload length");
        return false;
      }
      pcm.resize(chunk_size / sizeof(int16_t));
      file.read(reinterpret_cast<char *>(pcm.data()), chunk_size);
      if (file.gcount() != static_cast<std::streamsize>(chunk_size)) {
        fail("Truncated WAV capture");
        return false;
      }
      found_data = true;
    }
    // Includes padding for every chunk, including odd-length fmt metadata.
    file.seekg(chunk_start + static_cast<std::streamoff>(padded_size));
  }

  if (!found_format || !found_data || channels != 1 ||
      sample_rate != WHISPER_SAMPLE_RATE || bits_per_sample != 16) {
    fail("WAV must be 16 kHz, mono, PCM16");
    return false;
  }
  if (pcm.empty()) {
    fail("WAV capture has no samples");
    return false;
  }

  samples->resize(pcm.size());
  for (size_t index = 0; index < pcm.size(); ++index) {
    (*samples)[index] = static_cast<float>(pcm[index]) / 32768.0f;
  }
  return true;
}

whisper_context *load_context(const char *model_path) {
  if (context != nullptr && loaded_model == model_path) return context;
  if (context != nullptr) {
    whisper_free(context);
    context = nullptr;
  }
  const whisper_context_params params = whisper_context_default_params();
  context = whisper_init_from_file_with_params(model_path, params);
  if (context == nullptr) {
    fail("Unable to load the Whisper model");
    return nullptr;
  }
  loaded_model = model_path;
  return context;
}

char *copy_result(const std::string &result) {
  char *copy = static_cast<char *>(std::malloc(result.size() + 1));
  if (copy == nullptr) {
    fail("Out of memory while returning transcript");
    return nullptr;
  }
  std::memcpy(copy, result.c_str(), result.size() + 1);
  return copy;
}

}  // namespace

extern "C" {

__attribute__((visibility("default"))) const char *ponderin_whisper_last_error() {
  return last_error;
}

__attribute__((visibility("default"))) void ponderin_whisper_free(char *value) {
  std::free(value);
}

// The Dart service serializes requests. The mutex also protects callers that
// accidentally reach the bridge from a second isolate.
__attribute__((visibility("default"))) char *ponderin_whisper_transcribe(
    const char *model_path, const char *wav_path, const char *language,
    const char *initial_prompt) noexcept {
  try {
  std::lock_guard<std::mutex> lock(context_mutex);
  last_error[0] = '\0';
  if (model_path == nullptr || wav_path == nullptr || language == nullptr) {
    fail("Missing transcription parameter");
    return nullptr;
  }

  std::vector<float> samples;
  if (!read_pcm16_wav(wav_path, &samples)) return nullptr;
  if (whisper_lang_id(language) == -1) {
    fail("Unsupported Whisper language");
    return nullptr;
  }
  whisper_context *ctx = load_context(model_path);
  if (ctx == nullptr) return nullptr;

  whisper_full_params params =
      whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  params.print_realtime = false;
  params.print_progress = false;
  params.print_timestamps = false;
  params.no_context = true;
  params.no_timestamps = true;
  params.translate = false;
  params.language = language;
  params.n_threads = std::max(1u, std::min(4u, std::thread::hardware_concurrency()));
  if (initial_prompt != nullptr && initial_prompt[0] != '\0') {
    params.initial_prompt = initial_prompt;
  }

  // Preserve the production short-clip optimisation: a 1–3 second answer
  // should not pay the full 30-second encoder window. Current whisper.cpp
  // exposes this as a supported `audio_ctx` parameter.
  const int model_context = whisper_model_n_audio_ctx(ctx);
  if (model_context < 512) {
    fail("Whisper model has an unsupported audio context size");
    return nullptr;
  }
  const float seconds = static_cast<float>(samples.size()) / WHISPER_SAMPLE_RATE;
  params.audio_ctx = std::clamp(
      static_cast<int>(seconds / 30.0f * model_context) + 128, 512,
      model_context);

  if (whisper_full(ctx, params, samples.data(), static_cast<int>(samples.size())) != 0) {
    fail("Whisper could not process the capture");
    return nullptr;
  }

  std::string text;
  for (int index = 0; index < whisper_full_n_segments(ctx); ++index) {
    text += whisper_full_get_segment_text(ctx, index);
  }
  return copy_result(text);
  } catch (const std::exception &error) {
    fail(error.what());
    return nullptr;
  } catch (...) {
    fail("Unexpected Whisper native error");
    return nullptr;
  }
}

}  // extern "C"
