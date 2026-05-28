# find-domain

Поиск домена во всех конфигах и скриптах на сервере. Показывает, в каких файлах
встречается домен, на каких строках и сколько раз. **Логи не сканируются.**

## Возможности

- Ищет точное вхождение строки (регистр игнорируется) в `.conf`, `.cfg`, `.ini`,
  `.env`, `.json`, `.yaml`/`.yml`, `.toml`, `.py`, `.js`, `.ts`, `.php`, `.rb`,
  `.go`, `.sh`, `.bash`, `.xml`, `.txt`, `.list`, а также `Caddyfile`,
  `Dockerfile`, `docker-compose.yml` и `/etc/hosts`.
- Прогресс-бар с процентами во время сканирования.
- Для каждого файла — путь, номера строк и количество совпадений.
- В конце — сводка: сколько совпадений в скольких файлах.
- Пропускает мусорные каталоги (`.git`, `node_modules`, `__pycache__`, `venv`)
  и любые каталоги с логами.

## Запуск с сервера (одной строкой)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vtslynet-cyber/find-domain/main/find-domain.sh) example.com
```

или через wget:

```bash
wget -qO- https://raw.githubusercontent.com/vtslynet-cyber/find-domain/main/find-domain.sh | bash -s -- example.com
```

Без аргумента домен спросится интерактивно.

## Установка

```bash
curl -fsSL -o /usr/local/bin/find-domain \
  https://raw.githubusercontent.com/vtslynet-cyber/find-domain/main/find-domain.sh
chmod +x /usr/local/bin/find-domain

find-domain example.com
```

## Настройка

В начале скрипта можно поправить:

- `SCAN_DIRS` — список каталогов для поиска;
- `PRUNE_DIRS` — какие каталоги пропускать;
- `MAX_LINES_PER_FILE` — сколько строк показывать на файл (счётчик всё равно
  считает все совпадения).
