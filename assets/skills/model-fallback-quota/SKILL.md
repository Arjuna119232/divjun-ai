# Skill — Mengatasi Limit Model AI di Zyvo

## Gejala
User lapor "model utama ada limitnya" / "kena limit". Penyebabnya SELALU dari
sisi server (rate limit / kuota harian), bukan dari sisi config.

## Yang HARUS dilakukan: cek dulu, jangan langsung menggurui
1. **Cek daftar model yang tersedia** (jangan menjanjikan model yang tidak ada):
```bash
python - <<'PY'
import json,os,urllib.request
d=json.load(open(os.path.expanduser('~/.config/zyvo/zyvo.json')))
key=d['provider']['zyvo-free']['options']['apiKey']
req=urllib.request.Request("https://api.apinex.bond/v1/models",
    headers={"Authorization":"Bearer "+key,"User-Agent":"Mozilla/5.0 Chrome/131.0"})
ids=[m['id'] for m in json.load(urllib.request.urlopen(req,timeout=25))['data']]
print("total:",len(ids))
print("glm :",[i for i in ids if 'glm' in i.lower()])
print("abliter/uncensored:",[i for i in ids if 'abliter' in i.lower() or 'uncens' in i.lower()] or "TIDAK ADA")
PY
```
2. **Test live satu-satu** dengan `max_tokens` kecil. PENTING: model reasoning
   (GLM) butuh `max_tokens` cukup besar, kalau kecil isinya pindah ke
   `reasoning_content` dan `content` kosong — **jangan disalahartikan sebagai mati**.
3. **Backup dulu** sebelum edit: `cp ~/.config/zyvo/zyvo.json $TMPDIR/zyvo.json.bak-$(date +%H%M%S)`

## Cara promotedmodel pengganti ke fallback (#1)
`model` = premium utama (biarkan). Supaya user:auto immune, taruh alternatif
**terbukti 200** di Positions 1-2 `fallback_models`:
```python
d['fallback_models'] = ['zyvo-free/glm-5.3','zyvo-free/glm-5.3-flash',
  'zyvo-free/gpt-6.astra', ...] + [m for m in d['fallback_models'] if 'glm' not in m]
json.dump(d, open(p,'w'), indent=2)
```
`small_model` = varian paling ringan untuk task kecil (tidak ikut limit).

## JANGAN: restart pkill zyvo saat edit
`pkill zyvo` akan mematikan sesi yang sedang edit → edit `zyvo.json` langsung,
user restart sendiri. Config juga ditimpa `zyvo update` — selalu cek `.bak-*`.

## Model abliterated / uncensored
Umumnya TIDAK tersedia di provider aggregator. Butuh deploy sendiri (HuggingFace
/ Ollama / llama.cpp) = 20-100 GB + mesin besar → **tidak mungkin dari HP**.
JANGAN menjanjikan; cek daftar model dulu sebelum menjawab.
