---
name: pilih-provider-ai-gratis-untuk-apk
description: Cara memilih provider LLM gratis untuk aplikasi Android/iOS (APK) yang butuh streaming + native tool calling - termasuk bukti live bahwa OpenCode/Zen free tier TIDAK bisa dipakai dari app, dan daftar alternatif gratis yang benar-benar punya tool calling. Gunakan saat user tanya "ganti ke model gratis", "provider gratis untuk APK", "bisakah pakai OpenCode di aplikasi", atau memilih LLM untuk app mobile.
---

# Provider AI gratis untuk APK (bukan untuk zyvo terminal)

Sudah diuji live dari HP, 17 Okt 2026. Kriteria app mobile: (1) kunci API
bisa didapat gratis tanpa kartu, (2) **native function calling / tool calling**
wajib untuk agent, (3) streaming SSE, (4) HTTP biasa tanpa OAuth desktop.

## 1. OpenCode / Zen: TIDAK BISA (bukti, bukan opinion)

```bash
curl -s -A "Mozilla/5.0" -H "Authorization: Bearer $OC_SK" \
  https://opencode.ai/zen/v1/models          # 200 OK, 45 model terlihat
curl -s -X POST -H "Authorization: Bearer $OC_SK" \
  -H "Content-Type: application/json" \
  https://opencode.ai/zen/v1/chat/completions \
  -d '{"model":"space-bunny-free","messages":[{"role":"user","content":"say OK"}],"max_tokens":300}'
# -> {"type":"error","error":{"type":"FreeTierError",
#      "message":"OpenCode's free tier can only be used from within OpenCode."}}
```
Kaz kunci `oc_sk_` asli user **tetap ditolak** dari luar app. Kunci literal
`public` juga ditolak sama. Jadi: `/models` bisa dibaca, `/chat` tidak.
**Jangan tawarkan ini sebagai provider APK.** Sama berlaku untuk zyvo itu
sendiri - zyvo jalan dari dalam OpenCode, jadi bisa.

## 2. Yang benar-benar bisa dipakai (verifikasi cepat)

```bash
# Groq & Cerebras: OpenAI-compatible, alive, 401/403 tanpa key = normal
curl -s https://api.groq.com/openai/v1/models        # {"error":{"code":"invalid_api_key"}}
curl -s https://api.cerebras.ai/v1/models             # {"detail":"Not authenticated"}
curl -s -X POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent -d '{}'
# 403 "Method doesn't allow unregistered callers" -> butuh API key

# OpenRouter: katalog PUBLIK, jadi bisa dicek tanpa akun - ini info paling berharga
curl -s https://openrouter.ai/api/v1/models | python3 -c "
import sys,json; d=json.load(sys.stdin)['data']
free=[m for m in d if m['id'].endswith(':free')]
tools=[m for m in free if 'tools' in (m.get('supported_parameters') or [])]
print(len(d), len(free), len(tools))
[print(' ', m['id'], (m.get('context_length') or 0)//1000) for m in tools[:10]]"
# -> 466 total, 15 :free, 14 :free dengan tool calling
```

### Ranking untuk agent di APK
| Provider | Tool calling | Syarat | Catatan |
|---|---|---|---|
| **Groq** | native (OpenAI-compatible) | key gratis | tercepat, paling stabil; default |
| **Google Gemini** | native (`functionDeclarations`) | key gratis AI Studio, tanpa kartu | multimodal, ctx 1M; wire format beda (`functionCall`/`functionResponse`) |
| **OpenRouter `:free`** | native | akun gratis | 14 model `:free` punya tools; rate limit ketat (free tier ~20 rpm, 50/hari) |
| Cerebras | sebagian model | key gratis | endpoint hidup, tool calling terbatas |
| Mistral | ada | key gratis | free tier eksperimental |

## 3. Arsitektur yang dipakai di DIVJUN AI (Flutter)
`lib/domain/entities/model_ai.dart` → `enum PenyediaModel { groq, gemini }`,
katalog model **diambil live dari provider** (`/v1/models`), bukan daftar
hardcode, jadi model baru langsung muncul tanpa build ulang.
Adapter per provider di `lib/data/datasources/klien_llm.dart` (satu class,
satu `_url()` + `_header()` + `_body()` per provider).
Auto-fallback saat 429 = set `penalty`-style: pindah model dalam satu provider
 dulu, baru pindah provider.

## 4. Jebakan yang harus diingat saat ganti provider
- `Options(cancelToken:)` bukan parameter yang ada - `cancelToken` adalah
  argumen `dio.post()`.
- Gemini tidak punya `tool_choice: 'auto'`; pakai `functionCallingConfig.mode`.
- Tool call Gemini datang sebagai `parts[].functionCall`, dan hasilnya harus
  dikirim balik sebagai `parts[].functionResponse` dengan `name` yang sama.
- Rate limit gratis = 429 sering; parsed 429 harus jadi pesan Bahasa Indonesia
  yang bisa ditampilkan, bukan `Exception`.
- Kunci API di dalam APK **bisa diekstrak siapa pun** - aman untuk pemakaian
  pribadi, WAJIB backend proxy kalau mau Play Store.
