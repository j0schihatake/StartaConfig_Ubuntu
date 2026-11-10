#!/bin/bash
[ -z "$BASH_VERSION" ] && exec bash "$0" "$@"   # чтобы работало и через sh
# Запуск системной службы Strata (Qwen3.8-Flash-Next Coder IQ1_M) и загрузка модели сразу, не дожидаясь первого запроса
# Служба системная: управление только через sudo/админа.
sudo systemctl start strata
echo "Служба Strata запущена. Загружаю модель (около 1.5 минут)..."
for i in $(seq 60); do curl -fs -o /dev/null http://127.0.0.1:8080/health && break; sleep 1; done
curl -s -X POST -H "Content-Type: application/json" --max-time 600 http://127.0.0.1:8080/load >/dev/null
if curl -s http://127.0.0.1:8080/health | grep -q '"loaded": true'; then
  echo "Модель загружена: http://127.0.0.1:8080"
  google-chrome http://127.0.0.1:8080/ >/dev/null 2>&1 &
else
  echo "Модель не загрузилась. Лог: sudo journalctl -u strata -n 50"
fi
echo
read -n1 -s -p "Нажми любую клавишу, чтобы закрыть окно..."
