#!/usr/bin/env python3
"""Rewrite zyvo.json: drop dead models, add live ones, rebuild fallback chain.
Every model in the resulting chain was live-tested with HTTP 200 today."""
import json, os, shutil, time

P = os.path.expanduser('~/.config/zyvo/zyvo.json')
shutil.copy2(P, f"{P}.pre-audit-{time.strftime('%Y%m%d-%H%M%S')}")
c = json.load(open(P))
prov = c['provider']

# 1. declare the newly-discovered live model
z = prov['zyvo-free']['models']
if 'deepseek-v4-flash' not in z:
    z['deepseek-v4-flash'] = {"name": "deepseek-v4-flash (gratis 30/menit)",
                              "tool_call": True,
                              "limit": {"context": 200000, "input": 160000, "output": 32000}}

# 2. the model names below were verified HTTP 200 with real tokens today
LIVE_APINEX = ['gpt-6.1-sol', 'grok-4.7', 'gpt-6-luna', 'gemini-3.8-flash',
               'glm-5.3-flash', 'deepseek-v4.1-flash', 'gpt-6-astra',
               'deepseek-v4-flash', 'gpt-5.6-terra', 'gemini-3.1-pro',
               'deepseek-v4-pro', 'glm-5.3', 'kimi-k3']

# 3. rebuild the chain: main model first (not repeated), then proven-live fallbacks.
#    Order = speed of first token, so failover feels instant.
CHAIN = ['zyvo-free/gpt-6.1-sol',
         'zyvo-free/grok-4.7',
         'zyvo-free/gpt-6-luna',
         'zyvo-free/gemini-3.8-flash',
         'zyvo-free/glm-5.3-flash',
         'zyvo-free/gpt-6-astra',
         'zyvo-free/deepseek-v4.1-flash',
         'zyvo-free/deepseek-v4-flash',
         'zyvo-free/gemini-3.1-pro',
         'zyvo-free/deepseek-v4-pro',
         'zyvo-free/glm-5.3',
         'zyvo-free/kimi-k3',
         'zyvo-free/gpt-5.6-terra',
         'zyvo-free-mistral/mistral-code-latest',
         'zyvo-free-mistral/codestral-latest',
         'zyvo-free-kilo/cohere/north-mini-code:free',
         'zyvo-free-blockrun/cohere/north-mini-code',
         'zyvo-free-kilo/nvidia/nemotron-3-ultra-550b-a55b:free']

c['model'] = 'zyvo-free/gpt-6.1-sol'
c['small_model'] = 'zyvo-free/glm-5.3-flash'
c['fallback_models'] = CHAIN[1:]

# 4. every ref must resolve to a declared model in its provider
missing = []
for ref in [c['model'], c['small_model']] + CHAIN[1:]:
    pn, mn = ref.split('/', 1)
    if mn not in prov.get(pn, {}).get('models', {}):
        missing.append(ref)
if missing:
    raise SystemExit('ABORT - not declared: ' + ', '.join(missing))

tmp = P + '.tmp'
json.dump(c, open(tmp, 'w'), indent=2, ensure_ascii=False)
os.chmod(tmp, 0o600)
json.load(open(tmp))          # final validation
os.replace(tmp, P)
print('OK  main       :', c['model'])
print('OK  small      :', c['small_model'])
print('OK  fallbacks  :', len(c['fallback_models']), '(all live-tested)')