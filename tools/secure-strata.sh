#!/usr/bin/env bash
# Один скрипт: Strata -> системный сервис (управление только sudo) +
# файлы модели только для чтения (изменения только через sudo) + проверка,
# что модель реально загружается после закрепления.
#
#   sudo bash secure-strata.sh           # применить
#   sudo bash secure-strata.sh --off     # откатить всё
#   sudo bash secure-strata.sh --status  # показать состояние
#
set -euo pipefail

ROOT=/home/j0schi/Program/Strata
PROFILE=$ROOT/local/strata-iq2_xs.json
STRATA=$ROOT/local/terminal/bin/strata
MODEL_ROOT=$ROOT/model
MODELS=$MODEL_ROOT/models
PACKS=$MODEL_ROOT/packs
UNIT=/etc/systemd/system/strata.service
OWNER=j0schi
USER_UNIT=strata-iq2xs.service
HELPERS=(strata-download-iq2xs.service strata-wait-iq2xs.service)

if [[ "${EUID}" -ne 0 ]]; then
  echo "нужен root: sudo bash $0 [--off|--status]" >&2
  exit 1
fi

as_user() { runuser -u "$OWNER" -- "$@"; }

lock_model() {
  chown -R root:root "$MODELS" "$PACKS"
  find "$MODELS" "$PACKS" -type d -exec chmod 755 {} +
  find "$MODELS" "$PACKS" -type f -exec chmod 644 {} +
  while IFS= read -r -d '' t; do
    chattr +i "$t" 2>/dev/null || echo "предупреждение: не закреплён $t" >&2
  done < <(find "$MODELS" "$PACKS" -mindepth 1 \( -type f -o -type d \) -print0)
  echo "Модель: root:root, 644/755, chattr +i (изменения только через sudo)."
}

unlock_model() {
  while IFS= read -r -d '' t; do
    chattr -i "$t" 2>/dev/null || true
  done < <(find "$MODELS" "$PACKS" -mindepth 1 \( -type f -o -type d \) -print0)
  chown -R "$OWNER:$OWNER" "$MODELS" "$PACKS"
  find "$MODELS" "$PACKS" -type d -exec chmod 755 {} +
  find "$MODELS" "$PACKS" -type f -exec chmod 644 {} +
  echo "Модель: снова доступна пользователю $OWNER (rw)."
}

write_unit() {
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
  chmod 644 "$UNIT"; chown root:root "$UNIT"
}

wait_health() {
  for _ in $(seq 40); do
    curl -fs -o /dev/null http://127.0.0.1:8080/health 2>/dev/null && return 0
    sleep 1
  done
  return 1
}

case "${1:-apply}" in
  --status)
    systemctl is-active strata.service 2>/dev/null || true
    [[ -f "$UNIT" ]] && echo "unit: $UNIT" || echo "unit: нет (пользовательский режим)"
    find "$MODELS" "$PACKS" -maxdepth 1 -type f -printf '%m %u:%g %p\n' 2>/dev/null | head -5
    lsattr -d "$MODELS" "$PACKS" 2>/dev/null || true
    exit 0
    ;;
  --off)
    unlock_model
    systemctl disable --now strata.service 2>/dev/null || true
    rm -f "$UNIT"
    systemctl daemon-reload
    as_user systemctl --user enable --now "$USER_UNIT" 2>/dev/null || true
    echo "Вернули пользовательский сервис $USER_UNIT."
    exit 0
    ;;
esac

[[ -x "$STRATA" ]] || { echo "нет $STRATA" >&2; exit 1; }
[[ -f "$PROFILE" ]] || { echo "нет $PROFILE" >&2; exit 1; }

# 1. Убираем пользовательские экземпляры и помощников
as_user systemctl --user disable --now "$USER_UNIT" 2>/dev/null || true
for h in "${HELPERS[@]}"; do
  as_user systemctl --user disable --now "$h" 2>/dev/null || true
done

# 2. Системный юнит
write_unit
systemctl daemon-reload
systemctl enable --now strata.service

# 3. Закрепляем модель
lock_model

# 4. Перезапуск под закреплённой моделью + проверка загрузки
systemctl restart strata.service
if ! wait_health; then
  echo "Strata не отвечает после закрепления — откатываю закрепление модели." >&2
  unlock_model
  systemctl restart strata.service
  exit 1
fi

echo "Проверяю, что модель реально загружается (может занять ~2 минуты)..."
CODE=$(curl -s -o /tmp/secure-strata-check.json -w '%{http_code}' -m 900 \
  -X POST http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen3.8-flash-next-iq2_xs","messages":[{"role":"user","content":"Ответь: 2+2"}],"max_tokens":16,"temperature":0}' || true)
if [[ "$CODE" != "200" ]]; then
  echo "Модель не загрузилась (HTTP $CODE) — откатываю закрепление модели." >&2
  unlock_model
  systemctl restart strata.service
  exit 1
fi

echo
echo "Готово:"
echo "  - strata.service — системный (sudo), автозапуск при загрузке;"
echo "  - модель IQ2_XS — root:root, 644/755, chattr +i (только чтение);"
echo "  - помощники скачивания/переключения отключены;"
echo "  - тестовая генерация: HTTP 200."
curl -s http://127.0.0.1:8080/health; echo
echo "Откат: sudo bash $0 --off"
