#!/usr/bin/env bash
set -euo pipefail

export PATH="$PATH:/run/current-system/sw/bin:/usr/bin:/usr/local/bin:$HOME/.nix-profile/bin"

CONFIG="$HOME/.config/cava/quickshell-media-popup.conf"

if ! command -v cava >/dev/null 2>&1; then
    exit 127
fi

exec cava -p "$CONFIG" 2>/dev/null