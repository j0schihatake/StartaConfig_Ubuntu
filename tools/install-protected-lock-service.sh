#!/usr/bin/env bash
# Ставит systemd path-юнит: как только вы меняете список «🗂 Файлы»
# (config.json плагина), root-сервис автоматически закрепляет новые файлы
# через chattr +i. Политика применяется без участия агента.
#
#   sudo bash install-protected-lock-service.sh          # установить
#   sudo bash install-protected-lock-service.sh --off    # убрать
#
set -euo pipefail

SCRIPT=/home/j0schi/Program/Strata/tools/lock-protected-files.sh
CFG=/home/j0schi/.dsh/auto-press/config.json
SVC=/etc/systemd/system/dsh-protected-lock.service
PATH_UNIT=/etc/systemd/system/dsh-protected-lock.path

if [[ "${EUID}" -ne 0 ]]; then
  echo "нужен root: sudo bash $0 [--off]" >&2
  exit 1
fi

if [[ "${1:-}" == "--off" ]]; then
  systemctl disable --now dsh-protected-lock.path 2>/dev/null || true
  rm -f "$SVC" "$PATH_UNIT"
  systemctl daemon-reload
  echo "Автозакрепление отключено."
  exit 0
fi

cat > "$SVC" <<EOF
[Unit]
Description=Lock DSH protected files (chattr +i)
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/bash $SCRIPT
EOF

cat > "$PATH_UNIT" <<EOF
[Unit]
Description=Watch DSH protected-files list

[Path]
PathModified=$CFG
Unit=dsh-protected-lock.service

[Install]
WantedBy=paths.target
EOF

systemctl daemon-reload
systemctl enable --now dsh-protected-lock.path
systemctl start dsh-protected-lock.service
systemctl --no-pager status dsh-protected-lock.service | head -12
echo
echo "Готово: список «Файлы» теперь закрепляется автоматически (chattr +i)."
