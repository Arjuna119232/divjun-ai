#!/usr/bin/env python3
"""Measure stream time-to-first-token (TTFT) — the real cause of 'stream gagal'."""
import json, os, sys, time, urllib.request, urllib.error

c = json.load(open(os.path.expanduser('~/.config/zyvo/zyvo.json')))
provs = c['provider']
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/131.0.0.0 Safari/537.36"

def stream_test(ref, timeout=60):
    pname, mname = ref.split('/', 1)
    opt = provs[pname]['options']
    body = json.dumps({
        "model": mname, "stream": True, "max_tokens": 40,
        "messages": [{"role": "user", "content": "Count from 1 to 5."}],
    }).encode()
    req = urllib.request.Request(opt['baseURL'].rstrip('/') + '/chat/completions', data=body, headers={
        'Authorization': 'Bearer ' + opt['apiKey'], 'Content-Type': 'application/json',
        'User-Agent': UA, 'Accept': 'text/event-stream'})
    t0 = time.time(); ttft = None; chunks = 0; text = ''; event = ''
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            event = r.headers.get('Content-Type', '?')
            for raw in r:
                if ttft is None:
                    ttft = time.time() - t0
                line = raw.decode('utf-8', 'replace').strip()
                if line.startswith('data:'):
                    chunks += 1
                    payload = line[5:].strip()
                    if payload and payload != '[DONE]':
                        try:
                            d = json.loads(payload)
                            for ch in (d.get('choices') or []):
                                delta = ch.get('delta') or {}
                                text += (delta.get('content') or delta.get('reasoning_content') or '')
                        except Exception:
                            pass
        return (ref, event.split(';')[0], f"TTFT={ttft:.1f}s chunks={chunks} total={time.time()-t0:.1f}s", text.strip()[:40])
    except urllib.error.HTTPError as e:
        return (ref, 'HTTP' + str(e.code), e.read().decode('utf-8', 'replace')[:90], '')
    except Exception as e:
        return (ref, 'ERR', f'{type(e).__name__}: {str(e)[:70]}', '')

for ref in sys.argv[1:]:
    r = stream_test(ref)
    ok = '  ' if r[3] else 'XX'
    print(f"{ok}{ref:42s} {r[1]:18s} {r[2]}  {r[3]}")
    sys.stdout.flush()
    time.sleep(1.2)