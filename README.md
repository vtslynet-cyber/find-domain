# find-domain ( Поисковик доменов на сервере )

Поиск домена во всех конфигах и скриптах на сервере. Показывает, в каких файлах
встречается домен, на каких строках и сколько раз. **Логи не сканируются.**

## Возможности

- Спрашивает домен при запуске (или принимает его аргументом).
- Ищет точное вхождение строки (регистр игнорируется) в `.conf`, `.cfg`, `.ini`,
  `.env`, `.json`, `.yaml`/`.yml`, `.toml`, `.py`, `.js`, `.ts`, `.php`, `.rb`,
  `.go`, `.sh`, `.bash`, `.xml`, `.txt`, `.list`, а также `Caddyfile`,
  `Dockerfile`, `docker-compose.yml` и `/etc/hosts`.
- Прогресс-бар с процентами во время сканирования.
- Для каждого файла — путь, номера строк и количество совпадений.
- В конце — сводка: сколько совпадений в скольких файлах.
- Пропускает мусорные каталоги (`.git`, `node_modules`, `__pycache__`, `venv`)
  и любые каталоги с логами.
- Остановка в любой момент по `Ctrl+C` (без мусора на экране).

## Запуск с сервера (одной строкой)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vtslynet-cyber/find-domain/main/find-domain.sh)
```

Скрипт спросит домен, затем начнёт поиск. Через wget:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/vtslynet-cyber/find-domain/main/find-domain.sh)
```

Можно сразу передать домен аргументом — тогда вопрос не задаётся:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vtslynet-cyber/find-domain/main/find-domain.sh) example.com
```

## Установка как команды

```bash
curl -fsSL -o /usr/local/bin/find-domain \
  https://raw.githubusercontent.com/vtslynet-cyber/find-domain/main/find-domain.sh
chmod +x /usr/local/bin/find-domain

find-domain              # спросит домен
find-domain example.com  # или сразу аргументом
```

## Управление

- `Ctrl+C` — прервать поиск в любой момент.
- Пустой ввод при запросе домена — переспросит снова.

## Настройка

В начале скрипта можно поправить:

- `SCAN_DIRS` — список каталогов для поиска;
- `PRUNE_DIRS` — какие каталоги пропускать;
- `MAX_LINES_PER_FILE` — сколько строк показывать на файл (счётчик всё равно
  считает все совпадения).
