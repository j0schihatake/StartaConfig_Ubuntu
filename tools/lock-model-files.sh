#!/usr/bin/env bash
# Делает файлы модели Strata доступными только для чтения, а изменять их
# можно только через sudo:
#   - владелец root:root, права 644/755 (пользователь писать не может);
#   - chattr +i — даже root не изменит без sudo chattr -i;
#   - каталоги тоже неизменяемы: нельзя подменить/удалить файл из своей папки.
#
#   sudo bash lock-model-files.sh           # закрепить
#   sudo bash lock-model-files.sh --off     # снять
#   sudo bash lock-model-files.sh --status  # показать
#
set -euo pipefail

ROOT=/home/j0schi/Program/Strata/model
MODELS=$ROOT/models
PACKS=$ROOT/packs
OWNER=j0schi

if [[ "${EUID}" -ne 0 ]]; then
  echo "нужен root: sudo bash $0 [--off|--status]" >&2
  exit 1
fi

mapfile -t TARGETS < <(find "$MODELS" "$PACKS" -mindepth 1 \( -type f -o -type d \) 2>/dev/null)

if [[ "${#TARGETS[@]}" -eq 0 ]]; then
  echo "Нечего закреплять: $MODELS / $PACKS пусты" >&2
  exit 1
fi

case "${1:-apply}" in
  --status)
    find "$MODELS" "$PACKS" -maxdepth 2 -type f -printf '%m %u:%g %p\n' 2>/dev/null | head -20
    echo "..."
    lsattr -d "$MODELS" "$PACKS" 2>/dev/null || true
    exit 0
    ;;
  --off)
    for t in "${TARGETS[@]}"; do chattr -i "$t" 2>/dev/null || true; done
    chown -R "$OWNER:$OWNER" "$MODELS" "$PACKS"
    chmod -R u+rwX "$MODELS" "$PACKS"
    find "$MODELS" "$PACKS" -type d -exec chmod 755 {} +
    find "$MODELS" "$PACKS" -type f -exec chmod 644 {} +
    echo "Модель снова доступна пользователю $OWNER (rw)."
    exit 0
    ;;
esac

# 1. Владелец root, без права записи у пользователя
chown -R root:root "$MODELS" "$PACKS"
find "$MODELS" "$PACKS" -type d -exec chmod 755 {} +
find "$MODELS" "$PACKS" -type f -exec chmod 644 {} +

# 2. Неизменяемость: файлы и каталоги (нельзя ни писать, ни удалять/подменять)
for t in "${TARGETS[@]}"; do
  chattr +i "$t" 2>/dev/null || echo "предупреждение: не удалось закрепить $t" >&2
done

echo "Готово: модель только для чтения, изменения — только через sudo."
find "$MODELS" "$PACKS" -maxdepth 1 -type f -printf '%m %u:%g %p\n' | head -6
echo "Снять: sudo bash $0 --off"
