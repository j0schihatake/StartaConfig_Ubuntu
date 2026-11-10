#!/usr/bin/env bash
# Скачивает Qwen3.8 Flash-Next Coder IQ1_M (2 gguf, ~58.4 GB) из Hugging Face.
set -euo pipefail
cd /home/j0schi/Program/Strata/model/models/IQ1_M
BASE="https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-Coder-GGUF/resolve/main/IQ1_M"
for f in \
  Qwen3.8-Flash-Next-GSQ-RCO-IQ1_M-00001-of-00002.gguf \
  Qwen3.8-Flash-Next-GSQ-RCO-IQ1_M-00002-of-00002.gguf
do
  echo "[$(date '+%F %T')] start $f"
  curl -L -C - --retry 20 --retry-delay 5 --retry-all-errors \
       --connect-timeout 30 --speed-time 120 --speed-limit 1024 \
       -o "$f" "$BASE/$f"
  echo "[$(date '+%F %T')] done $f: $(stat -c %s "$f") bytes"
done
echo "[$(date '+%F %T')] ALL DONE"
ls -la
