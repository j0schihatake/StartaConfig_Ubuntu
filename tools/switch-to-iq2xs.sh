#!/usr/bin/env bash
# Переключение Strata обратно на модель Qwen3.8 Flash-Next IQ2_XS.
# Запускать после того, как оба шарда докачаны tools/download-iq2xs.sh.
set -euo pipefail

ROOT=/home/j0schi/Program/Strata
MODEL="$ROOT/model/models/IQ2_XS"
PACK="$ROOT/model/packs/iq2_xs"
PROFILE="$ROOT/local/strata-iq2_xs.json"
PY="$ROOT/local/terminal/python/bin/python3"
UNIT="$HOME/.config/systemd/user/strata-iq2xs.service"

S1="$MODEL/Qwen3.8-Flash-Next-GSQ-RCO-IQ2_XS-00001-of-00002.gguf"
S2="$MODEL/Qwen3.8-Flash-Next-GSQ-RCO-IQ2_XS-00002-of-00002.gguf"

for f in "$S1" "$S2"; do
  [[ -f "$f" ]] || { echo "нет файла: $f" >&2; exit 1; }
done
s1=$(stat -c %s "$S1"); s2=$(stat -c %s "$S2")
[[ "$s1" -ge 39225954592 ]] || { echo "шард 1 не докачан ($s1)" >&2; exit 1; }
[[ "$s2" -ge 28800138432 ]] || { echo "шард 2 не докачан ($s2)" >&2; exit 1; }

# 1. Pack (эксперты + tokenizer) из первого шарда
if [[ ! -f "$PACK/native_experts.txt" || ! -f "$PACK/tokenizer/vocab.json" ]]; then
  echo "собираю pack $PACK ..."
  ( cd "$ROOT/local/terminal" && "$PY" tools/iq_pack.py --gguf "$S1" --out "$PACK" )
fi

# 2. Новый user-юнит на профиль IQ2_XS
cat > "$UNIT" <<EOF
[Unit]
Description=Strata: Qwen3.8 Flash-Next IQ2_XS (lazy load, unload after 10 min idle)
After=network.target

[Service]
Type=simple
Environment=STRATA_COMPONENTS_DIR=$ROOT/local/components
WorkingDirectory=$ROOT/local
ExecStart=$ROOT/local/terminal/bin/strata serve --profile $PROFILE
Restart=on-failure
RestartSec=10
TimeoutStopSec=60

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user disable strata.service 2>/dev/null || true
systemctl --user stop strata.service 2>/dev/null || true
systemctl --user enable --now strata-iq2xs.service

# 3. Проверка
for i in $(seq 60); do
  curl -fs -o /dev/null http://127.0.0.1:8080/health && break
  sleep 1
done
echo
curl -s http://127.0.0.1:8080/health
echo
echo "Готово. Сервис: strata-iq2xs.service (user, enabled)."
echo "Откат: systemctl --user disable --now strata-iq2xs; systemctl --user enable --now strata"
