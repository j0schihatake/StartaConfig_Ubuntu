#!/usr/bin/env bash
# Негативные тесты OS-защиты: пробует изменить защищённый файл всеми
# способами, которыми это делает агент. Ожидается отказ на каждом шаге.
# Запускать от пользователя (не root), после sudo lock-protected-files.sh.
#
#   bash test-protected-files.sh [путь_к_защищённому_файлу]
#
set -uo pipefail

CFG=/home/j0schi/.dsh/auto-press/config.json
TARGET="${1:-$(python3 - "$CFG" <<'PY'
import json, sys
try:
    cfg = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for p in cfg.get('protectedPaths') or []:
    if isinstance(p, str) and p.strip() and __import__('os').path.isfile(p):
        print(p); break
PY
)}"

if [[ -z "${TARGET:-}" || ! -f "$TARGET" ]]; then
  echo "не найден защищённый файл для теста" >&2
  exit 1
fi

if ! lsattr "$TARGET" 2>/dev/null | grep -q -- 'i'; then
  echo "Файл не закреплён (нет флага i): $TARGET" >&2
  echo "Сначала: sudo bash lock-protected-files.sh" >&2
  exit 1
fi

pass=0; fail=0
check() { # имя, команда
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "FAIL  $name — операция прошла, файл изменён!"
    fail=$((fail+1))
  else
    echo "ok    $name — заблокировано"
    pass=$((pass+1))
  fi
}

echo "Цель: $TARGET"
echo

check "прямая запись (>>)"            bash -c "printf 'x' >> \"$TARGET\""
check "перезапись (tee)"              bash -c "printf 'x' | tee \"$TARGET\""
check "python: вычисленный путь"      python3 -c "import os; p=bytes(os.fsencode('$TARGET')).decode(); open(p,'a').write('x')"
check "python: chr-путь"              python3 -c "open(''.join(chr(c) for c in map(ord, '$TARGET')),'a').write('x')"
check "sed -i"                        sed -i 's/^/x/' "$TARGET"
check "rename"                        mv "$TARGET" "$TARGET.bak"
check "unlink"                        rm -f "$TARGET"
check "symlink на файл"               bash -c "ln -sf \"$TARGET\" /tmp/pf-link && printf 'x' >> /tmp/pf-link"
check "hardlink"                      bash -c "ln -f \"$TARGET\" /tmp/pf-hard 2>/dev/null && printf 'x' >> /tmp/pf-hard"
check "через /proc/self/fd"           bash -c "exec 3<>\"$TARGET\" 2>/dev/null && printf 'x' >&3"
check "chmod"                         chmod 666 "$TARGET"
check "chattr -i (без root)"          chattr -i "$TARGET"

rm -f /tmp/pf-link /tmp/pf-hard /tmp/pf-hard 2>/dev/null || true

echo
echo "Итог: ok=$pass fail=$fail"
[[ "$fail" -eq 0 ]]
