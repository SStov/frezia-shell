#!/usr/bin/env python3
"""
Generate Quickshell-compatible color palettes from wallpaper images.

This script wraps template-processor.py's core logic and outputs colors
in the format expected by Quickshell's Colors.qml (rootBg, bg, card, etc.)
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Import from lib package
sys.path.insert(0, str(Path(__file__).parent))
from lib import read_image, ImageReadError, extract_palette, generate_theme
from lib.quantizer import extract_source_color, source_color_to_rgb
from lib.color import Color


# Mapping from Material Design 3 keys to Quickshell Colors.qml keys
M3_TO_QS_KEY_MAP = {
    "surface_dim": "rootBg",
    "surface": "bg",
    "surface_variant": "card",
    "on_surface": "textMain",
    "on_surface_variant": "textSub",
    "primary": "accentBlue",
    "secondary": "secondary",
    "tertiary": "accentPurple",
    "secondary_container": "softAccentBg",
    "on_secondary_container": "softAccentText",
    "outline": "outline",
    "outline_variant": "outlineVariant",
    "error": "error",
}

# Map matugen-style scheme names to our internal scheme names
MATUGEN_TO_INTERNAL_SCHEME = {
    "fidelity": "vibrant",
    "expressive": "vibrant",
    "neutral": "pastel",
    "tonal-spot": "pastel",
    "content": "intensified",
    "rainbow": "vibrant",
    "monochrome": "pastel",
    "vibrant": "vibrant",
    "fruit-salad": "vibrant",
    "faithful": "intensified",
    "dysfunctional": "intensified",
    "muted": "pastel",
    "pastel": "pastel",
    "intensified": "intensified",
}

# All supported modes and schemes for full palette generation
ALL_MODES = ["dark", "light"]
ALL_SCHEMES = ["pastel", "vibrant", "intensified"]


def generate_single_palette(
    pixels: list[RGB],
    mode: str,
    scheme_name: str,
) -> dict[str, str] | None:
    """Generate a single palette for a given mode and scheme."""
    internal_scheme = MATUGEN_TO_INTERNAL_SCHEME.get(scheme_name, "vibrant")

    # Always use full palette extraction to get real colors from the wallpaper
    palette = extract_palette(pixels, k=5, scoring=internal_scheme)

    if not palette:
        print("Error: Could not extract colors from image", file=sys.stderr)
        return None

    theme = generate_theme(palette, mode, internal_scheme)

    # Transform M3 keys to Quickshell keys
    result = {}
    for m3_key, qs_key in M3_TO_QS_KEY_MAP.items():
        result[qs_key] = theme.get(m3_key, "#121212")

    return result


def generate_all_palettes(pixels: list[RGB]) -> dict[str, dict[str, str]] | None:
    """Generate palettes for all mode+scheme combinations."""
    palettes = {}
    for mode in ALL_MODES:
        for scheme in ALL_SCHEMES:
            key = f"{mode}-{scheme}"
            palette = generate_single_palette(pixels, mode, scheme)
            if palette:
                palettes[key] = palette
            else:
                return None
    return palettes


def generate_css(theme: dict[str, str]) -> str:
    """Generate CSS for waybar/swaync from M3 theme."""
    c_surface = theme.get("surface", "#121212")
    c_surface_variant = theme.get("surface_variant", "#1e1e1e")
    c_on_surface = theme.get("on_surface", "#ffffff")
    c_primary = theme.get("primary", "#ffffff")
    c_tertiary = theme.get("tertiary", "#ffffff")
    c_error = theme.get("error", "#ff5555")
    c_secondary = theme.get("secondary", "#89b4fa")

    return f"""@define-color background {c_surface};
@define-color foreground {c_on_surface};
@define-color primary {c_primary};
@define-color gray {c_surface_variant};
@define-color error {c_error};
@define-color red {c_error};
@define-color blue {c_secondary};
@define-color purple {c_tertiary};
@define-color yellow #f9e2af;
@define-color green #a6e3a1;
"""


def generate_gtk4_css(theme: dict[str, str]) -> str:
    """Generate CSS for GTK4/Libadwaita (Nautilus, GNOME Settings, etc.)"""
    primary = theme.get("primary", "#3584e4")
    on_primary = theme.get("on_primary", "#ffffff")
    surface = theme.get("surface", "#1e1e1e")
    on_surface = theme.get("on_surface", "#ffffff")
    surface_container = theme.get("surface_container", "#242424")
    surface_container_low = theme.get("surface_container_low", "#1e1e1e")
    surface_container_high = theme.get("surface_container_high", "#2d2d2d")
    surface_variant = theme.get("surface_variant", "#2d2d2d")
    error = theme.get("error", "#ff5555")
    on_error = theme.get("on_error", "#ffffff")
    surface_container_lowest = theme.get("surface_container_lowest", "#1a1a1a")

    return f"""/* Generated GTK4/Libadwaita Colors */
@define-color window_bg_color {surface_container_lowest};
@define-color window_fg_color {on_surface};
@define-color view_bg_color {surface_container_low};
@define-color view_fg_color {on_surface};
@define-color headerbar_bg_color {surface_container};
@define-color headerbar_fg_color {on_surface};
@define-color popover_bg_color {surface_container_high};
@define-color popover_fg_color {on_surface};
@define-color card_bg_color {surface_variant};
@define-color card_fg_color {on_surface};
@define-color sidebar_bg_color {surface_container_lowest};
@define-color sidebar_fg_color {on_surface};
@define-color accent_color {primary};
@define-color accent_bg_color {primary};
@define-color accent_fg_color {on_primary};
@define-color destructive_color {error};
@define-color destructive_bg_color {error};
@define-color destructive_fg_color {on_error};
@define-color success_color #a6e3a1;
@define-color success_bg_color #a6e3a1;
@define-color success_fg_color {on_primary};
@define-color warning_color #f9e2af;
@define-color warning_bg_color #f9e2af;
@define-color warning_fg_color {on_primary};
@define-color error_color {error};
@define-color error_bg_color {error};
@define-color error_fg_color {on_error};
"""


def generate_gtk3_css(theme: dict[str, str]) -> str:
    """Generate CSS for GTK3 applications."""
    primary = theme.get("primary", "#3584e4")
    on_primary = theme.get("on_primary", "#ffffff")
    surface = theme.get("surface", "#1e1e1e")
    on_surface = theme.get("on_surface", "#ffffff")
    surface_container = theme.get("surface_container", "#242424")
    surface_variant = theme.get("surface_variant", "#2d2d2d")
    on_surface_variant = theme.get("on_surface_variant", "#e0e0e0")

    return f"""/* Generated GTK3 Colors */
@define-color theme_bg_color {surface};
@define-color theme_fg_color {on_surface};
@define-color theme_base_color {surface};
@define-color theme_text_color {on_surface};
@define-color theme_selected_bg_color {primary};
@define-color theme_selected_fg_color {on_primary};
@define-color theme_headerbar_bg_color {surface_container};
@define-color theme_headerbar_fg_color {on_surface};
@define-color theme_card_bg_color {surface_variant};
@define-color theme_card_fg_color {on_surface};
@define-color insens_bg_color {surface_container};
@define-color insens_fg_color {on_surface_variant};
"""


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="generate-quickshell-colors",
        description="Generate Quickshell color palettes from wallpapers",
    )
    parser.add_argument("image", type=Path, help="Path to wallpaper image")
    parser.add_argument(
        "--mode",
        choices=["dark", "light"],
        help="Generate single mode only",
    )
    parser.add_argument(
        "--scheme",
        default="fidelity",
        help="Scheme type (e.g. fidelity, content, vibrant)",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Generate all mode+scheme combinations",
    )
    parser.add_argument(
        "--output", "-o",
        type=Path,
        help="Write JSON output to file (stdout if omitted)",
    )
    parser.add_argument(
        "--css",
        action="store_true",
        help="Output CSS for waybar/swaync instead of JSON",
    )
    parser.add_argument(
        "--gtk",
        action="store_true",
        help="Generate and write CSS for GTK3 and GTK4",
    )
    args = parser.parse_args()

    if not args.image.exists():
        print(f"Error: Image not found: {args.image}", file=sys.stderr)
        return 1

    try:
        pixels = read_image(args.image)
    except ImageReadError as e:
        print(f"Error reading image: {e}", file=sys.stderr)
        return 1

    if args.css:
        mode = args.mode or "dark"
        internal_scheme = MATUGEN_TO_INTERNAL_SCHEME.get(args.scheme, args.scheme)

        m3_schemes = {"tonal-spot", "content", "fruit-salad", "rainbow", "monochrome"}
        if internal_scheme in m3_schemes:
            source_argb = extract_source_color(pixels)
            r, g, b = source_color_to_rgb(source_argb)
            palette = [Color(r, g, b)]
        else:
            palette = extract_palette(pixels, k=5, scoring=internal_scheme)

        if not palette:
            print("Error: Could not extract colors", file=sys.stderr)
            return 1

        theme = generate_theme(palette, mode, internal_scheme)
        css = generate_css(theme)
        if args.output:
            args.output.write_text(css)
            print(f"CSS written to: {args.output}", file=sys.stderr)
        else:
            print(css)
        return 0

    if args.gtk:
        mode = args.mode or "dark"
        internal_scheme = MATUGEN_TO_INTERNAL_SCHEME.get(args.scheme, args.scheme)

        m3_schemes = {"tonal-spot", "content", "fruit-salad", "rainbow", "monochrome"}
        if internal_scheme in m3_schemes:
            source_argb = extract_source_color(pixels)
            r, g, b = source_color_to_rgb(source_argb)
            palette = [Color(r, g, b)]
        else:
            palette = extract_palette(pixels, k=5, scoring=internal_scheme)

        if not palette:
            print("Error: Could not extract colors", file=sys.stderr)
            return 1

        theme = generate_theme(palette, mode, internal_scheme)
        gtk3_css = generate_gtk3_css(theme)
        gtk4_css = generate_gtk4_css(theme)

        home = Path.home()
        gtk3_dir = home / ".config" / "gtk-3.0"
        gtk4_dir = home / ".config" / "gtk-4.0"

        try:
            gtk3_dir.mkdir(parents=True, exist_ok=True)
            gtk4_dir.mkdir(parents=True, exist_ok=True)
            (gtk3_dir / "gtk.css").write_text(gtk3_css)
            (gtk4_dir / "gtk.css").write_text(gtk4_css)
            print("GTK3 and GTK4 CSS files written successfully", file=sys.stderr)
        except IOError as e:
            print(f"Error writing GTK CSS: {e}", file=sys.stderr)
            return 1
        return 0

    if args.all:
        result = generate_all_palettes(pixels)
        if result is None:
            return 1
    else:
        mode = args.mode or "dark"
        palette = generate_single_palette(pixels, mode, args.scheme)
        if palette is None:
            return 1
        result = {f"{mode}-{args.scheme}": palette}

    json_output = json.dumps(result, indent=2)

    if args.output:
        args.output.write_text(json_output)
        print(f"Palettes written to: {args.output}", file=sys.stderr)
    else:
        print(json_output)

    return 0


if __name__ == "__main__":
    sys.exit(main())
