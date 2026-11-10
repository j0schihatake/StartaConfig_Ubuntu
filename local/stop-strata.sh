#!/bin/bash
[ -z "$BASH_VERSION" ] && exec bash "$0" "$@"   # чтобы работало и через sh
# Выгрузка модели Strata: освобождает видеопамять и RAM, сервер остаётся и загрузит модель при следующем запросе
curl -s -X POST -H "Content-Type: application/json" "http://127.0.0.1:8080/unload?wait=1" >/dev/null
echo "Модель выгружена. Сервер ждёт запросов и загрузит её сам."
echo "Остановить сервер совсем (только админ): sudo systemctl stop strata"
echo
read -n1 -s -t 10 -p "Окно закроется через 10 секунд..."
