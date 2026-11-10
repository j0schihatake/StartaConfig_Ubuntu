#!/usr/bin/env bash
# Возврат прежней модели: Qwen3.8 Flash-Next IQ2_XS (2 шарда, ~68 ГБ).
set -euo pipefail
cd /home/j0schi/Program/Strata/model/models/IQ2_XS
BASE="https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF/resolve/main/IQ2_XS"
for f in \
  Qwen3.8-Flash-Next-GSQ-RCO-IQ2_XS-00001-of-00002.gguf \
  Qwen3.8-Flash-Next-GSQ-RCO-IQ2_XS-00002-of-00002.gguf
do
  echo "[$(date '+%F %T')] start $f"
  curl -L -C - --retry 20 --retry-delay 5 --retry-all-errors \
       --connect-timeout 30 --speed-time 120 --speed-limit 1024 \
       -o "$f" "$BASE/$f"
  echo "[$(date '+%F %T')] done $f: $(stat -c %s "$f") bytes"
done
echo "[$(date '+%F %T')] ALL DONE"
ls -la
