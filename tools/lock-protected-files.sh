#!/usr/bin/env bash
# OS-уровневая точечная защита файлов (уровень A): chattr +i делает файл
# неизменяемым на уровне ФС — независимо от того, как агент вычислил путь
# (python bytes/chr/base64, symlink, hardlink, /proc/self/fd, rename).
# Работает для любых инструментов (bash, fs.write, MCP, фоновые процессы),
# потому что запрет живёт в ядре, а не в тексте команды.
#
#   sudo bash lock-protected-files.sh           # закрепить список «Файлы»
#   sudo bash lock-protected-files.sh --off     # снять
#   sudo bash lock-protected-files.sh --status  # показать флаги
#
set -euo pipefail

CFG=/home/j0schi/.dsh/auto-press/config.json
LOG=/home/j0schi/.dsh/auto-press/audit.log

if [[ "${EUID}" -ne 0 ]]; then
  echo "нужен root: sudo bash $0 [--off|--status]" >&2
  exit 1
fi

mapfile -t FILES < <(python3 - "$CFG" <<'PY'
import json, sys
try:
    cfg = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for p in cfg.get('protectedPaths') or []:
    if isinstance(p, str) and p.strip():
        print(p)
PY
)

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

if [[ "${#FILES[@]}" -eq 0 ]]; then
  echo "Список защищённых файлов пуст (сначала отметьте их кнопкой «🗂 Файлы»)."
  exit 0
fi

case "${1:-apply}" in
  --status)
    lsattr "${FILES[@]}" 2>/dev/null || true
    exit 0
    ;;
  --off)
    for f in "${FILES[@]}"; do
      [[ -e "$f" ]] || continue
      chattr -i "$f" 2>/dev/null && echo "снято: $f" || echo "не удалось снять: $f"
    done
    log "unlock: ${#FILES[@]} путей"
    exit 0
    ;;
esac

locked=0
failed=0
for f in "${FILES[@]}"; do
  if [[ ! -e "$f" ]]; then echo "Нет файла (пропуск): $f"; continue; fi
  # Каталоги не закрепляем: chattr +i на каталоге запрещает создавать в нём
  # файлы и ломает сборку. Для каталогов — только список protectedPaths в плагине.
  if [[ -d "$f" && ! -L "$f" ]]; then echo "Каталог (пропуск, защищается плагином): $f"; continue; fi
  if chattr +i "$f" 2>/dev/null; then
    locked=$((locked+1)); echo "закреплён: $f"
  else
    failed=$((failed+1)); echo "НЕ удалось закрепить: $f"
  fi
done

log "lock: ok=$locked fail=$failed"

echo
echo "--- итог ---"
lsattr "${FILES[@]}" 2>/dev/null || true
echo
echo "Снять: sudo bash $0 --off"
[[ "$failed" -eq 0 ]]
