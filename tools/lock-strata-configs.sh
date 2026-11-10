#!/usr/bin/env bash
# Делает конфиги Strata неизменяемыми для обычного пользователя:
# изменить/удалить их сможет только root (sudo chattr -i ...).
#
#   sudo bash lock-strata-configs.sh          # закрепить
#   sudo bash lock-strata-configs.sh --off    # снять закрепление
#
set -euo pipefail

FILES=(
  /home/j0schi/Program/Strata/local/install/strata-coder-iq1_m.json
  /home/j0schi/Program/Strata/local/strata-iq2_xs.json
  /home/j0schi/.config/systemd/user/strata.service
)

if [[ "${EUID}" -ne 0 ]]; then
  echo "нужен root: sudo bash $0 [--off]" >&2
  exit 1
fi

if [[ "${1:-}" == "--off" ]]; then
  for f in "${FILES[@]}"; do
    [[ -e "$f" ]] && chattr -i "$f" 2>/dev/null || true
  done
  echo "Закрепление снято — файлы снова можно менять."
  lsattr "${FILES[@]}" 2>/dev/null || true
  exit 0
fi

for f in "${FILES[@]}"; do
  if [[ -e "$f" ]]; then
    chattr +i "$f"
    echo "закреплён: $f"
  else
    echo "ПРЕДУПРЕЖДЕНИЕ: нет файла $f" >&2
  fi
done

echo
echo "--- результат ---"
lsattr "${FILES[@]}" 2>/dev/null || true
echo
echo "Снять: sudo bash $0 --off"
