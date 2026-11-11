#!/usr/bin/env bash
# Устанавливает системную защиту защищённых файлов DSH:
#   - копирует lock-скрипт в /usr/local/lib/dsh-protected/ (не зависит от Strata)
#   - ставит systemd path-юнит: изменение списка «🗂 Файлы» → автоматическое
#     закрепление/раскрепление файлов (chattr +i / -i)
#
#   sudo bash install-protected-lock-service.sh          # установить
#   sudo bash install-protected-lock-service.sh --off    # убрать
#
set -euo pipefail

SRC=/home/j0schi/Program/Strata/tools/lock-protected-files.sh
DEST_DIR=/usr/local/lib/dsh-protected
DEST=$DEST_DIR/lock-protected-files.sh
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
  echo "Автозакрепление отключено (файлы остаются закреплёнными; снять: $DEST --off)"
  exit 0
fi

install -d -m 755 "$DEST_DIR"
install -m 755 "$SRC" "$DEST"

cat > "$SVC" <<EOF
[Unit]
Description=Lock DSH protected files (chattr +i)
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/bash $DEST
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

chmod 644 "$SVC" "$PATH_UNIT"
systemctl daemon-reload
systemctl enable --now dsh-protected-lock.path
systemctl start dsh-protected-lock.service
echo
systemctl --no-pager status dsh-protected-lock.service | head -12
echo
echo "Установлено в $DEST_DIR. Скрипт больше не зависит от папки Strata."
