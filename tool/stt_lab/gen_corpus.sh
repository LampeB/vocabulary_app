#!/usr/bin/env bash
# Generates the acoustic test corpus into tool/stt_lab/corpus/:
#  - Korean answer clips (Google Translate TTS)
#  - a French "parasite speech" clip
#  - noise beds (white + synthetic babble)
#  - speech+babble mixes with noise lead-in/tail
# Requires: curl, gst-launch-1.0 (mp3 decode), python3.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p corpus

fetch_tts() { # name text lang
  curl -s -G "https://translate.google.com/translate_tts" \
    --data-urlencode "ie=UTF-8" --data-urlencode "q=$2" \
    --data-urlencode "tl=$3" --data-urlencode "client=tw-ob" \
    -H "User-Agent: Mozilla/5.0" -o "corpus/$1.mp3"
  gst-launch-1.0 -q filesrc location="corpus/$1.mp3" ! decodebin ! audioconvert \
    ! audioresample ! "audio/x-raw,rate=48000,channels=2" ! wavenc \
    ! filesink location="corpus/$1.wav" 2>/dev/null
  rm -f "corpus/$1.mp3"
  echo "  $1.wav"
}

echo "speech clips:"
fetch_tts ko_mul "물" ko
fetch_tts ko_keopi "커피" ko
fetch_tts ko_bap "밥" ko
fetch_tts ko_haksaeng "학생" ko
fetch_tts ko_chingu "친구" ko
fetch_tts fr_parasite "bonjour tout le monde" fr

echo "noise beds + mixes:"
python3 - <<'EOF'
import wave, struct, random, math

def read_wav(p):
    w = wave.open(p); n = w.getnframes()
    data = struct.unpack('<%dh' % (n * w.getnchannels()), w.readframes(n))
    out = (list(data), w.getnchannels(), w.getframerate()); w.close(); return out

def write_wav(p, samples, ch=2, rate=48000):
    w = wave.open(p, 'w'); w.setnchannels(ch); w.setsampwidth(2); w.setframerate(rate)
    w.writeframes(struct.pack('<%dh' % len(samples), *samples)); w.close()
    print('  ' + p.split('/')[-1])

rate, dur = 48000, 10
clip = lambda s: max(-32767, min(32767, int(s)))
write_wav('corpus/noise_white.wav', [clip(random.gauss(0, 3000)) for _ in range(rate*dur*2)])

tones = [(random.uniform(120, 800), random.uniform(0, 6.28)) for _ in range(40)]
babble = []
for i in range(rate*dur):
    t = i/rate
    v = sum(math.sin(6.28*f*t + p) * (600 + 400*math.sin(0.5*t*f/100)) for f, p in tones) / 6
    babble.extend([clip(v), clip(v)])
write_wav('corpus/noise_babble.wav', babble)

for name in ['ko_mul', 'ko_keopi', 'ko_bap', 'ko_haksaeng', 'ko_chingu']:
    speech, ch, r = read_wav(f'corpus/{name}.wav')
    noise, _, _ = read_wav('corpus/noise_babble.wav')
    lead = r * ch  # 1s
    mixed = [clip(noise[i % len(noise)] * 0.9) for i in range(lead)]
    mixed += [clip(s + noise[(lead+i) % len(noise)] * 0.9) for i, s in enumerate(speech)]
    mixed += [clip(noise[(lead+len(speech)+i) % len(noise)] * 0.9) for i in range(lead)]
    write_wav(f'corpus/{name}_noisy.wav', mixed, ch, r)
EOF
echo "corpus ready."
