#!/usr/bin/env bash
# Переводит Strata из пользовательского юнита в системный: управлять
# (start/stop/edit) сможет только root/админ, а сам сервис по-прежнему
# работает от пользователя j0schi.
#
#   sudo bash system-strata-service.sh          # сделать системным
#   sudo bash system-strata-service.sh --off    # вернуть пользовательский
#
set -euo pipefail

PROFILE=/home/j0schi/Program/Strata/local/install/strata-coder-iq1_m.json
STRATA=/home/j0schi/Program/Strata/local/terminal/bin/strata
UNIT=/etc/systemd/system/strata.service
OWNER=j0schi

if [[ "${EUID}" -ne 0 ]]; then
  echo "нужен root: sudo bash $0 [--off]" >&2
  exit 1
fi

as_user() {
  runuser -u "$OWNER" -- "$@"
}

if [[ "${1:-}" == "--off" ]]; then
  systemctl disable --now strata.service 2>/dev/null || true
  rm -f "$UNIT"
  systemctl daemon-reload
  as_user systemctl --user enable --now strata.service 2>/dev/null || true
  echo "Вернули пользовательский юнит strata.service."
  exit 0
fi

# 1. Останавливаем пользовательский экземпляр, чтобы не было двух на 8080
as_user systemctl --user disable --now strata.service 2>/dev/null || true

# 2. Системный юнит от root
cat > "$UNIT" <<EOF
[Unit]
Description=Strata: Qwen3.8 Coder IQ1_M (lazy load, unload after 10 min idle)
After=network.target

[Service]
Type=simple
User=${OWNER}
Group=${OWNER}
Environment=HOME=/home/${OWNER}
Environment=STRATA_COMPONENTS_DIR=/home/j0schi/Program/Strata/local/components
WorkingDirectory=/home/j0schi/Program/Strata/local
ExecStart=${STRATA} serve --profile ${PROFILE}
Restart=on-failure
RestartSec=10
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$UNIT"
systemctl daemon-reload
systemctl enable --now strata.service

sleep 5
systemctl --no-pager --lines=0 status strata.service || true
echo
echo "Управление теперь только под root: systemctl restart strata"
echo "Вернуть как было: sudo bash $0 --off"
