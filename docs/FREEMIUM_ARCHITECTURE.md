# Freemium Architecture — Vocabulary App

## Feature Comparison

| Feature | Free | Premium |
|---------|------|---------|
| Word creation | Instant (no audio gen) | ElevenLabs audio pre-generated |
| TTS playback | Flutter TTS (on-device) | ElevenLabs (high-quality voices) |
| STT recognition | `speech_to_text` (Google on-device) | OpenAI Whisper (higher accuracy) |
| Translation suggestions | MyMemory API (free) | MyMemory API (free) |
| Driving mode | Yes | Yes |
| Offline support | Full (TTS + STT on-device) | Partial (needs internet for API calls) |

---

## Cost Analysis (per active user, 100 words, 1 quiz/day)

### ElevenLabs TTS
- **One-time** per word: ~6 chars × 2 languages = ~12 chars/word
- 100 words = ~1,200 characters total
- Cost: ~$0.30/1,000 chars → **~$0.36 one-time**
- Adding 10 new words/month: ~$0.04/month
- **Monthly amortized: ~$0.05**

### OpenAI Whisper STT
- Per quiz: 100 answers × ~5 sec = ~8.3 min
- Cost: $0.006/min → **~$0.05/day → ~$1.50/month**
- With driving mode retries (3×): **up to ~$4.50/month**

### Total monthly cost per user

| Usage | TTS | STT | Total |
|-------|-----|-----|-------|
| Light (no retries) | $0.05 | $1.50 | **$1.55** |
| Normal (some retries) | $0.05 | $2.50 | **$2.55** |
| Heavy (driving mode, max retries) | $0.05 | $4.50 | **$4.55** |

### Suggested pricing (cost-covering only)
- **$2.99/month** — covers light/normal usage
- **$4.99/month** — covers heavy/driving mode usage
- Alternative: **$0.99/month TTS only** + **$2.99/month full premium**

---

## Phase 1: Self-Service (Quick Implementation)

Users enter their own API keys in the app settings. Zero infrastructure cost for the developer.

### How it works
1. Settings screen gets a "Premium" section with:
   - Toggle "TTS Premium (ElevenLabs)" + API key text field
   - Toggle "STT Premium (Whisper)" + API key text field
2. Keys stored locally in SharedPreferences (encrypted with `flutter_secure_storage`)
3. Runtime check replaces compile-time `ApiConfig.useFreeTTS` / `useFreeSTT` flags

### Code changes needed
| File | Change |
|------|--------|
| `pubspec.yaml` | Add `record: ^5.1.0`, `flutter_secure_storage: ^9.0.0` |
| `lib/models/premium_settings.dart` | NEW — data class: `usePremiumTTS`, `usePremiumSTT`, `elevenLabsKey`, `openAiKey` |
| `lib/utils/premium_preferences.dart` | NEW — secure storage for API keys |
| `lib/services/speech/base_stt_service.dart` | NEW — abstract interface shared by both STT services |
| `lib/services/speech/whisper_stt_service.dart` | NEW — records audio via `record` package, sends to Whisper API |
| `lib/services/speech/speech_recognition_service.dart` | MODIFY — implement `BaseSttService` |
| `lib/screens/quiz_screen_stt.dart` | MODIFY — pick STT service based on runtime pref |
| `lib/services/database/concept_repository.dart` | MODIFY — skip ElevenLabs when free TTS mode |
| `lib/screens/settings_screen.dart` | MODIFY — add Premium section with toggles + key inputs |
| `lib/config/api_config.dart` | MODIFY — read runtime prefs instead of const flags |

### Pros
- No backend needed
- No subscription system
- Users pay API providers directly
- Quick to implement (~1-2 days)

### Cons
- Users must get their own API keys (friction)
- No usage tracking or spending limits
- API keys stored on device (security concern, mitigated by `flutter_secure_storage`)

---

## Phase 2: Subscription with Proxy Backend (Future)

Users pay a monthly subscription. The developer's backend proxies API calls, protecting keys and tracking usage.

### Architecture

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│  Flutter App │────▶│  Proxy Backend   │────▶│  OpenAI API │
│             │     │  (Cloud Run /    │     │  Whisper    │
│  - Auth     │     │   Railway /      │     └─────────────┘
│  - Premium  │     │   Fly.io)        │────▶┌─────────────┐
│    badge     │     │                  │     │ ElevenLabs  │
└─────────────┘     │  - Auth (JWT)    │     │ API         │
                    │  - Rate limiting  │     └─────────────┘
                    │  - Usage tracking │
                    │  - Billing check  │
                    └──────────────────┘
                            │
                    ┌───────┴────────┐
                    │   Database     │
                    │  (Supabase /   │
                    │   Postgres)    │
                    │               │
                    │  - Users      │
                    │  - Usage logs │
                    │  - Sub status │
                    └───────────────┘
                            │
                    ┌───────┴────────┐
                    │   Billing      │
                    │  RevenueCat /  │
                    │  Stripe        │
                    └───────────────┘
```

### Backend components

#### 1. API Proxy Server
- **Tech**: Node.js / Python FastAPI / Go
- **Hosting**: Cloud Run (scales to zero = no idle cost), Railway, or Fly.io
- **Endpoints**:
  - `POST /api/tts/generate` — proxies to ElevenLabs, stores audio, returns URL
  - `POST /api/stt/transcribe` — proxies to Whisper, returns text
  - `GET /api/user/usage` — returns current month usage stats
- **Middleware**: JWT auth, rate limiting (X requests/min), subscription check

#### 2. Authentication
- **Option A**: Firebase Auth (free tier generous, easy Flutter integration)
- **Option B**: Supabase Auth (open source, includes DB)
- JWT token sent with every API request

#### 3. Billing
- **RevenueCat** (recommended): handles Apple/Google subscriptions, webhooks for backend
  - Free up to $2.5k MTR
  - Handles receipt validation, renewal, cancellation
- **Alternative**: Stripe + manual Google/Apple integration (more work)

#### 4. Database
- **Supabase** (recommended): free tier = 500MB, includes auth + DB + API
- Tables:
  - `users`: id, email, subscription_tier, created_at
  - `usage_logs`: user_id, service (tts/stt), chars_or_minutes, cost_usd, timestamp
  - `monthly_usage`: user_id, month, tts_chars, stt_minutes, total_cost

#### 5. Usage tracking & limits
- Track per-request: characters (TTS) or audio duration (STT)
- Monthly caps per tier:
  - Premium: 50,000 TTS chars + 500 min STT (~$8 cost ceiling)
  - If exceeded: graceful fallback to free mode with notification

### Estimated backend costs (per month, small scale)
| Component | Cost (< 100 users) | Cost (1,000 users) |
|-----------|--------------------|--------------------|
| Cloud Run | $0 (free tier) | ~$5-10 |
| Supabase | $0 (free tier) | $25 (Pro) |
| RevenueCat | $0 (free tier) | $0 (under $2.5k) |
| Domain + SSL | ~$1 | ~$1 |
| **Total infra** | **~$1** | **~$35** |
| API costs (Whisper + ElevenLabs) | ~$150-450 | ~$1,500-4,500 |

### Code changes needed (in addition to Phase 1)
| File | Change |
|------|--------|
| `pubspec.yaml` | Add `purchases_flutter` (RevenueCat), `firebase_auth` or `supabase_flutter` |
| `lib/services/api/proxy_service.dart` | NEW — HTTP client for proxy backend |
| `lib/services/auth/auth_service.dart` | NEW — Firebase/Supabase auth |
| `lib/services/billing/subscription_service.dart` | NEW — RevenueCat integration |
| `lib/screens/premium_screen.dart` | NEW — subscription purchase UI |
| `lib/config/api_config.dart` | MODIFY — point TTS/STT to proxy instead of direct API |

---

## Migration Path: Phase 1 → Phase 2

1. **Phase 1** (self-service keys): ship immediately, validate that premium features work
2. **Phase 1.5**: add anonymous usage analytics to understand real usage patterns
3. **Phase 2**: when user base grows, set up backend + billing
4. **Transition**: keep self-service key option as "advanced" setting, add subscription as default premium path
5. **Key insight**: Phase 1 code (Whisper service, ElevenLabs skip, settings UI) is fully reusable in Phase 2 — only the key source changes (local → backend proxy)

---

## Implementation Priority

1. **First** — Make free mode work (skip ElevenLabs in `concept_repository.dart`) — 30 min
2. **Second** — Add Whisper STT service + `record` package — 2-3 hours
3. **Third** — Settings UI for premium toggles + API keys — 1-2 hours
4. **Later** — Backend proxy + subscription (Phase 2) — 1-2 weeks
