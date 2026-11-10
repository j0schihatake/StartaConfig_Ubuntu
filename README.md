# StartaConfig_Ubuntu

Конфигурация и скрипты для локального сервиса **Strata** с моделью
**Qwen3.8-Flash-Next Coder IQ1_M** (GSQ-RCO, IQ1_M) на ноутбуке MSI GT62VR
(GTX 1070, 8 ГБ VRAM, 64 ГБ RAM, Ubuntu).

## Что лежит

```
local/
  start-strata.sh              запуск сервиса + загрузка модели (sudo systemctl)
  stop-strata.sh               выгрузка модели из памяти (сервис остаётся)
  strata-iq2_xs.json           старый профиль IQ2_XS (запасной)
  install/
    strata-coder-iq1_m.json    рабочий профиль Coder IQ1_M (current)
systemd/
  strata.service               системный юнит (запуск при загрузке, User=j0schi)
  strata.service.user-iq2xs.bak  прежний пользовательский юнит IQ2_XS
tools/
  download-coder-iq1m.sh       скачивание двух шардов IQ1_M с Hugging Face
  bench-strata.sh              замер скорости (tok/s) на фиксированном промпте
  lock-strata-configs.sh       chattr +i на профили и юнит (только root)
  system-strata-service.sh     перевод сервиса из user- в system-юнит и обратно
```

## Ключевые настройки профиля Coder IQ1_M

- `lazy_load: true`, `idle_unload_s: 600` — модель грузится по первому запросу
  и выгружается через 10 минут простоя (иначе держит ~28 ГБ RAM).
- `--max-context 262144` (максимум модели; `qwen4exp.context_length`),
  `--kv int8 --kv-grow` — KV занимает VRAM по мере роста контекста.
- `--expert-cache auto`, `--prefill 256`, `--spec 2` — подобрано замерами:
  ~6–8 ток/с на GTX 1070; 64K контекста комфортнее, 256K — ёмкость.

## Установка

1. Скопировать `local/*` в каталог запуска Strata (например
   `~/Program/Strata/local/`).
2. Юнит: `sudo cp systemd/strata.service /etc/systemd/system/`,
   `sudo systemctl daemon-reload && sudo systemctl enable --now strata`.
3. Модель: `bash tools/download-coder-iq1m.sh` (два шарда ~58 ГБ) и собрать
   pack: `python3 tools/iq_pack.py --gguf <shard1> --out model/packs/coder-iq1_m`.
4. Закрепить конфиги: `sudo bash tools/lock-strata-configs.sh`.

## Проверка

```bash
curl -s http://127.0.0.1:8080/health
# {"status":"ok","model":"qwen3.8-flash-next-coder-iq1_m","max_context":262144,"loaded":false,...}

curl -s -X POST "http://127.0.0.1:8080/unload?wait=1"   # выгрузить модель
sudo systemctl restart strata                            # только админ
```

## Безопасность

- Сервис системный: start/stop/restart и правка юнита — только root.
- Профили и юнит закреплены `chattr +i`; снять: `sudo bash tools/lock-strata-configs.sh --off`.
- Сервис слушает только `127.0.0.1:8080`; внешний доступ закрыт (lanblock).
