#!/bin/bash
set -e

export PATH=$PATH:/run/current-system/sw/bin:/usr/bin:/usr/local/bin:$HOME/.cargo/bin:$HOME/.nix-profile/bin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$HOME/.config/quickshell/core"
CACHE_FILE="$CACHE_DIR/current_wallpaper.txt"
mkdir -p "$CACHE_DIR"

# 1. ОПРЕДЕЛЯЕМ ОБОИ
get_active_wallpaper() {
    local path=$(swww query 2>/dev/null | grep -oP 'image:\s*\K[^,]+' | head -n 1 | tr -d '"' | tr -d "'")
    [ -z "$path" ] && path=$(awww query 2>/dev/null | grep -oP 'image:\s*\K[^,]+' | head -n 1 | tr -d '"' | tr -d "'")
    echo "$path" | sed 's/^ *//;s/ *$//'
}

if [ -n "$1" ]; then
    WALLPAPER="$1"
    IS_NEW_WALLPAPER=true
else
    WALLPAPER=$(get_active_wallpaper)
    IS_NEW_WALLPAPER=false
fi

WALLPAPER="${WALLPAPER#file://}"
WALLPAPER="${WALLPAPER/#\~/$HOME}"

if [ ! -f "$WALLPAPER" ]; then
    if [ "$IS_NEW_WALLPAPER" = false ] && [ -f "$CACHE_FILE" ]; then
        WALLPAPER=$(cat "$CACHE_FILE")
    fi
    
    if [ ! -f "$WALLPAPER" ]; then
        [ "$IS_NEW_WALLPAPER" = true ] && notify-send "Matugen" "Ошибка: Обои не найдены! ($WALLPAPER)" -u critical
        exit 1
    fi
fi

# Сохраняем текущие обои в кэш
echo "$WALLPAPER" > "$CACHE_FILE"

# 2. ПАРСИМ НАСТРОЙКИ
SETTINGS_FILE="$HOME/.config/quickshell/settings.qml"
MODE="dark"
SCHEME="fidelity"

if [ -f "$SETTINGS_FILE" ]; then
    PARSED_MODE=$(awk -F'"' '/property string matugenMode/ {print $2; exit}' "$SETTINGS_FILE")
    PARSED_SCHEME=$(awk -F'"' '/property string matugenScheme/ {print $2; exit}' "$SETTINGS_FILE")
    [ -n "$PARSED_MODE" ] && MODE="$PARSED_MODE"
    [ -n "$PARSED_SCHEME" ] && SCHEME="$PARSED_SCHEME"
fi

PID=$$
TEMP_IMG="/tmp/matugen_opt_${PID}.jpg"

# Оптимизация картинки
if command -v magick >/dev/null; then
    magick "$WALLPAPER[0]" -resize 400x400 -colorspace sRGB -depth 8 -background white -alpha remove "$TEMP_IMG" 2>/dev/null || true
else
    convert "$WALLPAPER[0]" -resize 400x400 -colorspace sRGB -depth 8 -background white -alpha remove "$TEMP_IMG" 2>/dev/null || true
fi
[ -f "$TEMP_IMG" ] && SRC_IMG="$TEMP_IMG" || SRC_IMG="$WALLPAPER"

# 3. ГЕНЕРАЦИЯ ВСЕХ ПАЛИТР ДЛЯ QUICKSHELL (Только при смене обоев)
COLOR_VALIDATED=false
if [ "$IS_NEW_WALLPAPER" = true ]; then
    if command -v swww >/dev/null; then
        swww img "$WALLPAPER" --transition-type grow --transition-duration 1.2
    else
        awww img "$WALLPAPER" --transition-type grow --transition-duration 1.2
    fi

    # Generate all palettes using Python script directly to the cache file
    mkdir -p "$HOME/.cache/quickshell"

    OLD_TIME=0
    if [ -f "$HOME/.cache/quickshell/colors.json" ]; then
        OLD_TIME=$(stat -c %Y "$HOME/.cache/quickshell/colors.json")
    fi

    if python3 "$SCRIPT_DIR/generate-quickshell-colors.py" "$SRC_IMG" --all -o "$HOME/.cache/quickshell/colors.json"; then
        if [ -f "$HOME/.cache/quickshell/colors.json" ] && [ -s "$HOME/.cache/quickshell/colors.json" ]; then
            NEW_TIME=$(stat -c %Y "$HOME/.cache/quickshell/colors.json")
            if [ "$NEW_TIME" -gt "$OLD_TIME" ] && grep -q "rootBg" "$HOME/.cache/quickshell/colors.json"; then
                COLOR_VALIDATED=true
            fi
        fi
    fi
else
    COLOR_VALIDATED=true
fi

# 4. ГЕНЕРАЦИЯ ЦВЕТОВ ДЛЯ WAYBAR И SWAYNC
CSS_FILE="/tmp/quickshell_css_${PID}.css"
python3 "$SCRIPT_DIR/generate-quickshell-colors.py" "$SRC_IMG" --mode "$MODE" --scheme "$SCHEME" --css -o "$CSS_FILE"

mkdir -p "$HOME/.config/swaync" "$HOME/.config/waybar"
cp "$CSS_FILE" "$HOME/.config/swaync/colors.css"
cp "$CSS_FILE" "$HOME/.config/waybar/colors.css"
rm -f "$CSS_FILE"

# ПЕРЕЗАГРУЗКА ДРУГИХ ИНТЕРФЕЙСОВ
pkill -SIGUSR2 waybar || true
swaync-client -rs || true

# 5. ГЕНЕРАЦИЯ ЦВЕТОВ ДЛЯ GTK (Nautilus, GNOME Settings, и др.)
python3 "$SCRIPT_DIR/generate-quickshell-colors.py" "$SRC_IMG" --mode "$MODE" --scheme "$SCHEME" --gtk

# Переключаем системную цветовую схему для иконок трея и GTK-приложений
if command -v gsettings >/dev/null; then
    if [ "$MODE" = "dark" ]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    else
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
    fi
fi

if [ "$SRC_IMG" = "$TEMP_IMG" ]; then rm -f "$TEMP_IMG"; fi

if [ "$IS_NEW_WALLPAPER" = true ]; then
    if [ "$COLOR_VALIDATED" = true ]; then
        notify-send "Matugen" "Новые палитры созданы и успешно применены! ✅"
    else
        notify-send "Matugen" "Ошибка: Не удалось сгенерировать новые палитры! ❌" -u critical
        exit 1
    fi
fi
