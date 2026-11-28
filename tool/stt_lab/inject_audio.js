// Streams a WAV file into the Android emulator's virtual microphone via the
// EmulatorController.injectAudio gRPC API. Usage:
//   node inject_audio.js <file.wav> [gain]
// WAV must be PCM16. Stereo/mono and any rate ≤48k pass through as-is.
const grpc = require("@grpc/grpc-js");
const protoLoader = require("@grpc/proto-loader");
const fs = require("fs");
const path = require("path");

const def = protoLoader.loadSync(path.join(__dirname, "emulator_controller.proto"), {
  keepCase: true, longs: Number, enums: Number, defaults: true,
});
const proto = grpc.loadPackageDefinition(def);
const client = new proto.android.emulation.control.EmulatorController(
  "127.0.0.1:8554", grpc.credentials.createInsecure());

function parseWav(buf) {
  if (buf.toString("ascii", 0, 4) !== "RIFF") throw new Error("not RIFF");
  let off = 12, fmt = null, data = null;
  while (off + 8 <= buf.length) {
    const id = buf.toString("ascii", off, off + 4);
    const size = buf.readUInt32LE(off + 4);
    if (id === "fmt ") fmt = { channels: buf.readUInt16LE(off + 10), rate: buf.readUInt32LE(off + 12), bits: buf.readUInt16LE(off + 22) };
    if (id === "data") data = buf.subarray(off + 8, off + 8 + size);
    off += 8 + size + (size % 2);
  }
  if (!fmt || !data || fmt.bits !== 16) throw new Error("need PCM16 wav");
  return { ...fmt, data };
}

const gain = parseFloat(process.argv[3] || "1");
const wav = parseWav(fs.readFileSync(process.argv[2]));
let data = wav.data;
if (gain !== 1) {
  data = Buffer.from(data);
  for (let i = 0; i + 1 < data.length; i += 2) {
    const s = Math.max(-32767, Math.min(32767, Math.round(data.readInt16LE(i) * gain)));
    data.writeInt16LE(s, i);
  }
}

const format = {
  format: 1,                          // AUD_FMT_S16
  channels: wav.channels === 2 ? 1 : 0, // enum: Mono=0, Stereo=1
  samplingRate: wav.rate,
  mode: 1,                            // MODE_REAL_TIME
};
const bytesPerSec = wav.rate * wav.channels * 2;
const chunkMs = 100;
const chunkBytes = Math.floor(bytesPerSec * chunkMs / 1000);

const call = client.injectAudio((err) => {
  if (err) { console.error("injectAudio error:", err.message); process.exit(1); }
  console.log("injected", data.length, "bytes @", wav.rate, "Hz x", wav.channels, "ch");
  process.exit(0);
});

let pos = 0;
(function pump() {
  if (pos >= data.length) { call.end(); return; }
  const chunk = data.subarray(pos, pos + chunkBytes);
  pos += chunkBytes;
  call.write({ format, timestamp: Date.now() * 1000, audio: chunk });
  setTimeout(pump, chunkMs);          // real-time pacing for MODE_REAL_TIME
})();
