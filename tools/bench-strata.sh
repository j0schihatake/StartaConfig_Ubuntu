#!/usr/bin/env bash
# Замер скорости Strata: фиксированный промпт, N токенов ответа.
# usage: bench-strata.sh [label] [max_tokens] [port]
set -euo pipefail
LABEL="${1:-bench}"
MAX="${2:-128}"
PORT="${3:-8080}"
BODY=$(python3 - "$MAX" <<'PY'
import json,sys
print(json.dumps({
 "model":"qwen3.8-flash-next-iq2_xs",
 "messages":[{"role":"user","content":"Напиши на Java метод, который читает файл построчно и возвращает список строк. Только код."}],
 "max_tokens":int(sys.argv[1]), "stream":False, "temperature":0
}))
PY
)
T0=$(date +%s.%N)
RESP=$(curl -s -m 600 -X POST "http://127.0.0.1:${PORT}/v1/chat/completions" -H 'Content-Type: application/json' -d "$BODY")
T1=$(date +%s.%N)
python3 - "$LABEL" "$T0" "$T1" "$RESP" <<'PY'
import json,sys
label,t0,t1,resp=sys.argv[1],float(sys.argv[2]),float(sys.argv[3]),sys.argv[4]
el=t1-t0
try: d=json.loads(resp); u=d.get("usage") or {}; n=u.get("completion_tokens",0); p=u.get("prompt_tokens",0)
except Exception: n=0; p=0
print(f"{label}: {el:.1f}s, prompt={p}, completion={n}, speed={(n/el if el else 0):.1f} tok/s")
PY
