#!/bin/bash
# Скрипт для отслеживания раскладки клавиатуры в MangoWM/Hyprland
# Записывает текущую раскладку в /tmp/mango_current_layout

LAYOUT_FILE="/tmp/mango_current_layout"

# Создаем файл с начальным значением
echo "US" > "$LAYOUT_FILE"

# Функция для получения текущей раскладки
get_layout() {
    # Пробуем получить через hyprctl devices
    local layout=$(hyprctl devices -j 2>/dev/null | jq -r '.keyboards[] | select(.main == true) | .active_keymap' | head -1)
    
    if [ -n "$layout" ]; then
        # Преобразуем полное название в короткий код
        case "$layout" in
            *"English"*|*"US"*) echo "US" ;;
            *"Russian"*|*"RU"*) echo "RU" ;;
            *"Ukrainian"*|*"UA"*) echo "UA" ;;
            *"German"*|*"DE"*) echo "DE" ;;
            *"French"*|*"FR"*) echo "FR" ;;
            *"Spanish"*|*"ES"*) echo "ES" ;;
            *"Italian"*|*"IT"*) echo "IT" ;;
            *"Polish"*|*"PL"*) echo "PL" ;;
            *"Turkish"*|*"TR"*) echo "TR" ;;
            *"Kazakh"*|*"KK"*) echo "KK" ;;
            *) echo "US" ;;
        esac
    else
        echo "US"
    fi
}

# Обновляем раскладку каждые 100мс
while true; do
    current=$(get_layout)
    if [ "$current" != "$(cat "$LAYOUT_FILE" 2>/dev/null)" ]; then
        echo "$current" > "$LAYOUT_FILE"
    fi
    sleep 0.1
done