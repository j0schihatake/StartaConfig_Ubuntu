#!/usr/bin/env bash
# OS-уровневая точечная защита файлов (уровень A): chattr +i.
# Ядро ФС запрещает запись/удаление/переименование независимо от того, как
# агент вычислил путь (python bytes/chr/base64, symlink, hardlink, rename).
# Работает для любых инструментов: bash, fs.write, MCP, фоновые процессы.
#
# Скрипт помнит, что закрепил (state-файл): если файл убрать из списка
# «🗂 Файлы», он будет автоматически раскреплён.
#
#   sudo bash lock-protected-files.sh           # синхронизировать
#   sudo bash lock-protected-files.sh --off     # снять всё
#   sudo bash lock-protected-files.sh --status  # показать флаги
#
set -euo pipefail

CFG=/home/j0schi/.dsh/auto-press/config.json
LOG=/home/j0schi/.dsh/auto-press/audit.log
STATE_DIR=/var/lib/dsh-protected
STATE=$STATE_DIR/locked.list

if [[ "${EUID}" -ne 0 ]]; then
  echo "нужен root: sudo bash $0 [--off|--status]" >&2
  exit 1
fi

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
mkdir -p "$STATE_DIR"

read_list() { # файлы (не каталоги), которые сейчас должны быть защищены
  python3 - "$CFG" <<'PY'
import json, os, sys
try:
    cfg = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for p in cfg.get('protectedPaths') or []:
    if isinstance(p, str) and p.strip() and os.path.isfile(p):
        print(p)
PY
}

mapfile -t WANT < <(read_list)
mapfile -t HAVE < <( [[ -f "$STATE" ]] && cat "$STATE" || true )

if [[ "${1:-}" == "--status" ]]; then
  if [[ "${#WANT[@]}" -eq 0 ]]; then echo "Список пуст."; exit 0; fi
  lsattr "${WANT[@]}" 2>/dev/null || true
  exit 0
fi

if [[ "${1:-}" == "--off" ]]; then
  for f in "${HAVE[@]}" "${WANT[@]}"; do
    [[ -n "${f:-}" && -e "$f" ]] || continue
    chattr -i "$f" 2>/dev/null && echo "снято: $f" || true
  done
  : > "$STATE"
  log "unlock all"
  echo "Закрепление снято, state очищен."
  exit 0
fi

# 1. Раскрепить то, что больше не в списке (убрали галку в UI).
for f in "${HAVE[@]}"; do
  [[ -n "${f:-}" ]] || continue
  skip=0
  for w in "${WANT[@]}"; do [[ "$f" == "$w" ]] && { skip=1; break; }; done
  if [[ "$skip" -eq 0 ]]; then
    [[ -e "$f" ]] && chattr -i "$f" 2>/dev/null && echo "снято (убрано из списка): $f" || true
  fi
done

# 2. Закрепить текущий список.
ok=0; fail=0
for f in "${WANT[@]}"; do
  if chattr +i "$f" 2>/dev/null; then
    ok=$((ok+1)); echo "закреплён: $f"
  else
    fail=$((fail+1)); echo "НЕ удалось закрепить: $f"
  fi
done

printf '%s\n' "${WANT[@]}" > "$STATE" || true
log "sync: ok=$ok fail=$fail total=${#WANT[@]}"
echo
echo "Защищено файлов: $ok (ошибок: $fail). Снять: sudo bash $0 --off"
[[ "$fail" -eq 0 ]]
