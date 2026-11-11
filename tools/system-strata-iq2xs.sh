#!/usr/bin/env bash
# Переводит Strata (IQ2_XS) с пользовательского юнита на системный:
#   - работает от j0schi, но управляется только через sudo;
#   - стартует при загрузке системы, а не при входе в графику;
#   - юнит принадлежит root, пользователь его не изменит.
#
#   sudo bash system-strata-iq2xs.sh          # перевести на системный
#   sudo bash system-strata-iq2xs.sh --off    # вернуть пользовательский
#
set -euo pipefail

ROOT=/home/j0schi/Program/Strata
PROFILE=$ROOT/local/strata-iq2_xs.json
STRATA=$ROOT/local/terminal/bin/strata
UNIT=/etc/systemd/system/strata.service
OWNER=j0schi
USER_UNIT=strata-iq2xs.service

if [[ "${EUID}" -ne 0 ]]; then
  echo "нужен root: sudo bash $0 [--off]" >&2
  exit 1
fi

as_user() { runuser -u "$OWNER" -- "$@"; }

if [[ "${1:-}" == "--off" ]]; then
  systemctl disable --now strata.service 2>/dev/null || true
  rm -f "$UNIT"
  systemctl daemon-reload
  as_user systemctl --user enable --now "$USER_UNIT" 2>/dev/null || true
  echo "Вернули пользовательский юнит $USER_UNIT."
  exit 0
fi

if [[ ! -x "$STRATA" ]]; then
  echo "Не найден исполняемый файл: $STRATA" >&2
  exit 1
fi
if [[ ! -f "$PROFILE" ]]; then
  echo "Не найден профиль: $PROFILE" >&2
  exit 1
fi

# 1. Останавливаем пользовательский экземпляр, чтобы не было двух на 8080
as_user systemctl --user disable --now "$USER_UNIT" 2>/dev/null || true

# 2. Системный юнит
cat > "$UNIT" <<EOF
[Unit]
Description=Strata: Qwen3.8 Flash-Next IQ2_XS (lazy load, unload after 10 min idle)
After=network.target

[Service]
Type=simple
User=${OWNER}
Group=${OWNER}
Environment=HOME=/home/${OWNER}
Environment=STRATA_COMPONENTS_DIR=${ROOT}/local/components
WorkingDirectory=${ROOT}/local
ExecStart=${STRATA} serve --profile ${PROFILE}
Restart=on-failure
RestartSec=15
TimeoutStopSec=90

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$UNIT"
chown root:root "$UNIT"

systemctl daemon-reload
systemctl enable --now strata.service

# 3. Проверка
for _ in $(seq 30); do
  if curl -fs -o /dev/null http://127.0.0.1:8080/health; then break; fi
  sleep 1
done
echo
curl -s http://127.0.0.1:8080/health || true
echo
systemctl --no-pager status strata.service | head -8 || true
echo
echo "Готово: Strata теперь системный сервис (управление только sudo)."
echo "Откат: sudo bash $0 --off"
