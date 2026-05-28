#!/usr/bin/env bash
#
# find-domain.sh — поиск домена в конфигах и скриптах на сервере
# Ищет точное вхождение строки во всех типичных конфиг/скрипт файлах,
# показывает прогресс, путь к файлу и количество совпадений в каждом.
# Логи НЕ сканируются.
#
# Использование:
#   ./find-domain.sh example.com
#   ./find-domain.sh                 # домен спросит интерактивно
#
set -o pipefail

# НАСТРОЙКИ
# Где искать
SCAN_DIRS=(
    /etc/nginx
    /etc/apache2
    /etc/httpd
    /etc/caddy
    /etc/traefik
    /etc/haproxy
    /etc/xray
    /etc/v2ray
    /var/www
    /opt
    /home
    /root
    /srv
    /usr/local
    /app
    /apps
    /data
    /docker
)

# Каталоги, которые пропускаем (мусор, кеш, логи)
PRUNE_DIRS=( .git node_modules __pycache__ .venv venv vendor logs log .cache )

# Сколько строк с совпадениями максимум показывать на один файл
MAX_LINES_PER_FILE=50

# ─────────────────────────── ЦВЕТА ───────────────────────────
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; GREY='\033[0;90m'; BOLD='\033[1m'; RESET='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; GREY=''; BOLD=''; RESET=''
fi

# ─────────────────────────── ДОМЕН ───────────────────────────
DOMAIN="$1"

# Если домен не передан аргументом — спрашиваем интерактивно.
# Читаем из /dev/tty, чтобы работало и при запуске через
# `bash <(curl ...)` и через `curl ... | bash`.
if [ -z "$DOMAIN" ]; then
    if [ -r /dev/tty ]; then
        while [ -z "$DOMAIN" ]; do
            printf "${BOLD}Введите домен для поиска:${RESET} " > /dev/tty
            if ! read -r DOMAIN < /dev/tty; then
                printf "\n${RED}Ввод прерван.${RESET}\n" >&2
                exit 1
            fi
        done
    else
        printf "${RED}Ошибка: домен не указан${RESET}\n" >&2
        exit 1
    fi
fi

# ─────────────────────────── ХЕЛПЕРЫ ───────────────────────────
# Правильное склонение слова "совпадение" по числу
plural_ru() {
    local n=$1 n10=$(( $1 % 10 )) n100=$(( $1 % 100 ))
    if   [ "$n100" -ge 11 ] && [ "$n100" -le 14 ]; then echo "совпадений"
    elif [ "$n10" -eq 1 ];                              then echo "совпадение"
    elif [ "$n10" -ge 2 ] && [ "$n10" -le 4 ];          then echo "совпадения"
    else echo "совпадений"; fi
}
print_progress() {
    [ -t 2 ] || return
    local cur=$1 total=$2 barlen=28
    [ "$total" -eq 0 ] && return
    local pct=$(( cur * 100 / total ))
    local filled=$(( pct * barlen / 100 ))
    local bar="" i
    for (( i = 0; i < barlen; i++ )); do
        if [ "$i" -lt "$filled" ]; then bar+="#"; else bar+="."; fi
    done
    printf "\r${CYAN}[%s] %3d%%${RESET} ${GREY}(%d/%d)${RESET}" \
        "$bar" "$pct" "$cur" "$total" >&2
}

clear_line() { [ -t 2 ] && printf "\r\033[K" >&2; }
cleanup() {
    clear_line
    printf "\n${YELLOW}Поиск прерван (Ctrl+C).${RESET}\n" >&2
    exit 130
}
trap cleanup INT TERM
collect_files() {
    local dir="$1"
    [ -d "$dir" ] || return
    local prune_expr=()
    local d
    for d in "${PRUNE_DIRS[@]}"; do
        prune_expr+=( -name "$d" -o )
    done
    # убрать последний -o
    unset 'prune_expr[${#prune_expr[@]}-1]'

    find "$dir" \
        \( -type d \( "${prune_expr[@]}" \) \) -prune -o \
        -type f \( \
            -name "*.conf"   -o -name "*.cfg"  -o -name "*.ini"  \
            -o -name "*.env" -o -name ".env"   -o -name ".env.*" \
            -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" \
            -o -name "*.toml" -o -name "*.py"  -o -name "*.js"   \
            -o -name "*.ts"  -o -name "*.php"  -o -name "*.rb"   \
            -o -name "*.go"  -o -name "*.sh"   -o -name "*.bash" \
            -o -name "*.xml" -o -name "*.properties"             \
            -o -name "*.txt" -o -name "*.list" -o -name "*.service" \
            -o -name "Caddyfile" -o -name "Dockerfile"           \
            -o -name "docker-compose.yml" -o -name "docker-compose.yaml" \
        \) -print0 2>/dev/null
}

# ─────────────────────────── СТАРТ ───────────────────────────
printf "\n${BOLD}${CYAN}Ищем:${RESET} ${BOLD}%s${RESET}\n" "$DOMAIN"
printf "${GREY}────────────────────────────────────────────────────────────${RESET}\n\n"
printf "${GREY}Собираю список файлов...${RESET}" >&2
declare -A SEEN
FILES=()

if [ -r /etc/hosts ]; then
    FILES+=( /etc/hosts ); SEEN[/etc/hosts]=1
fi

for DIR in "${SCAN_DIRS[@]}"; do
    while IFS= read -r -d '' f; do
        if [ -z "${SEEN[$f]}" ]; then
            FILES+=( "$f" ); SEEN[$f]=1
        fi
    done < <(collect_files "$DIR")
done

clear_line
TOTAL=${#FILES[@]}
printf "${GREY}Файлов для проверки: %d${RESET}\n\n" "$TOTAL" >&2

# 2) Сканируем
FOUND_FILES=0
FOUND_TOTAL=0
IDX=0

for FILE in "${FILES[@]}"; do
    IDX=$(( IDX + 1 ))
    print_progress "$IDX" "$TOTAL"

    [ -r "$FILE" ] || continue
    # -I пропускает бинарники, -F фиксированная строка, -i регистр
    COUNT=$(grep -cIiF -- "$DOMAIN" "$FILE" 2>/dev/null)
    COUNT=${COUNT:-0}
    [ "$COUNT" -gt 0 ] || continue

    clear_line
    printf " ${BOLD}${GREEN}%s${RESET}  ${YELLOW}(%d %s)${RESET}\n" \
        "$FILE" "$COUNT" "$(plural_ru "$COUNT")"

    grep -nIiF -- "$DOMAIN" "$FILE" 2>/dev/null | head -n "$MAX_LINES_PER_FILE" \
    | while IFS=: read -r LNUM CONTENT; do
        printf "   ${CYAN}L%-5s${RESET} %s\n" "$LNUM" "$CONTENT"
    done

    if [ "$COUNT" -gt "$MAX_LINES_PER_FILE" ]; then
        printf "   ${GREY}... показаны первые %d из %d${RESET}\n" \
            "$MAX_LINES_PER_FILE" "$COUNT"
    fi
    printf "\n"

    FOUND_FILES=$(( FOUND_FILES + 1 ))
    FOUND_TOTAL=$(( FOUND_TOTAL + COUNT ))
done
clear_line

printf "${GREY}────────────────────────────────────────────────────────────${RESET}\n"
if [ "$FOUND_FILES" -eq 0 ]; then
    printf "${BOLD}Домен ${RED}%s${RESET}${BOLD} не найден ни в одном файле.${RESET}\n\n" "$DOMAIN"
else
    printf "${BOLD}Готово.${RESET} Домен ${GREEN}%s${RESET}: " "$DOMAIN"
    printf "${BOLD}%d${RESET} %s в ${BOLD}%d${RESET} файлах.\n\n" \
        "$FOUND_TOTAL" "$(plural_ru "$FOUND_TOTAL")" "$FOUND_FILES"
fi
