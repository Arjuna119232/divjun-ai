#!/usr/bin/env python3
"""Live-test every model in zyvo fallback chain."""
import json, os, sys, time, urllib.request, urllib.error

CFG = os.path.expanduser('~/.config/zyvo/zyvo.json')
c = json.load(open(CFG))
provs = c['provider']

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"


def test(ref, timeout=35):
    if '/' not in ref:
        return (ref, 'SKIP', 'no provider prefix')
    pname, mname = ref.split('/', 1)
    prov = provs.get(pname)
    if not prov:
        return (ref, 'NOPROV', f'provider {pname} not in config')
    opt = prov.get('options', {})
    key = opt.get('apiKey', '')
    base = (opt.get('baseURL') or '').rstrip('/')
    if not key or not base:
        return (ref, 'NOCFG', 'no apiKey/baseURL')
    body = json.dumps({
        "model": mname,
        "messages": [{"role": "user", "content": "reply OK"}],
        "max_tokens": 24,
        "stream": False,
    }).encode()
    req = urllib.request.Request(base + '/chat/completions', data=body, headers={
        'Authorization': 'Bearer ' + key,
        'Content-Type': 'application/json',
        'User-Agent': UA,
        'Accept': 'application/json',
    })
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read().decode('utf-8', 'replace')
            dt = time.time() - t0
            try:
                j = json.loads(raw)
            except Exception:
                return (ref, 'HTTP' + str(r.status), f'non-json {raw[:90]}')
            ch = j.get('choices')
            if ch and isinstance(ch, list) and ch:
                msg = ch[0].get('message') or {}
                txt = (msg.get('content') or msg.get('reasoning_content') or msg.get('reasoning') or '')
                if txt:
                    return (ref, 'OK', f'{dt:.1f}s  "{str(txt).strip()[:40]}"')
                return (ref, 'EMPTY', f'{dt:.1f}s content=null err={j.get("error")}')
            return (ref, 'ODD', f'{dt:.1f}s {raw[:110]}')
    except urllib.error.HTTPError as e:
        raw = e.read().decode('utf-8', 'replace')
        try:
            msg = json.loads(raw).get('error', {})
            if isinstance(msg, dict):
                msg = msg.get('message') or json.dumps(msg)
        except Exception:
            msg = raw[:110]
        return (ref, 'HTTP' + str(e.code), str(msg)[:130])
    except Exception as e:
        return (ref, 'ERR', f'{type(e).__name__}: {str(e)[:90]}')


targets = []
if len(sys.argv) > 1:
    targets = sys.argv[1:]
else:
    targets = [c.get('model'), c.get('small_model')] + list(c.get('fallback_models') or [])
seen = set()
targets = [t for t in targets if t and not (t in seen or seen.add(t))]

print(f"testing {len(targets)} models\n")
for t in targets:
    ref, status, info = test(t)
    mark = '  ' if status == 'OK' else ('~ ' if status in ('EMPTY', '429', 'HTTP402') else 'XX')
    print(f"{mark}{ref:55s} {status:8s} {info}")
    sys.stdout.flush()
    time.sleep(1.5)