"""Convert Characters.json to Dialogic .dch character resources."""

from __future__ import annotations

import json
import math
import re
from pathlib import Path

from coloraide import Color
from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
TARGET_HSL_SATURATION = 0.55
TARGET_HSL_LIGHTNESS = 0.48
GRAY_SATURATION_THRESHOLD = 0.08
CHARACTERS_JSON = REPO_ROOT / "Characters.json"
PORTRAITS_DIR = REPO_ROOT / "assets" / "textures" / "characters"
OUTPUT_DIR = REPO_ROOT / "definitions" / "database" / "characters"
PROJECT_GODOT = REPO_ROOT / "project.godot"

DCH_HEADER = """{{
"@path": "res://addons/dialogic/Resources/character.gd",
"@subpath": NodePath(""),
&"color": Color({color_r}, {color_g}, {color_b}, {color_a}),
&"custom_info": {{
"prefix": "",
"sound_mood_default": "",
"sound_moods": {{}},
"style": "",
"suffix": ""
}},
&"default_portrait": "{default_portrait}",
&"description": "{description}",
&"display_name": "{display_name}",
&"mirror": false,
&"nicknames": {nicknames},
&"offset": Vector2(0, 0),
&"portraits": {{
{portraits}
}},
&"scale": 1.0
}}"""


def portrait_key(variant: str) -> str:
    space = variant.find(" ")
    if space == -1:
        return variant
    return variant[space + 1 :]


def portrait_image_path(variant: str) -> str:
    return f"res://assets/textures/characters/{variant}.png"


def _hsl_to_godot_color(hue: float) -> tuple[float, float, float, float]:
    rgb = Color(
        f"hsl({hue} {TARGET_HSL_SATURATION * 100}% {TARGET_HSL_LIGHTNESS * 100}%)"
    ).convert("srgb").coords()
    return (round(rgb[0], 3), round(rgb[1], 3), round(rgb[2], 3), 1.0)


def vibrant_color(image_path: Path) -> tuple[float, float, float, float]:
    weighted_hues: list[tuple[float, float]] = []
    fallback_hue = 0.0
    fallback_saturation = 0.0

    with Image.open(image_path) as img:
        rgba = img.convert("RGBA").resize((64, 64))
        for r, g, b, a in rgba.getdata():
            if a < 128:
                continue

            hue, saturation, lightness = Color(f"#{r:02x}{g:02x}{b:02x}").convert("hsl").coords()
            alpha_weight = a / 255.0

            if saturation > fallback_saturation:
                fallback_saturation = saturation
                fallback_hue = hue

            if saturation < GRAY_SATURATION_THRESHOLD or lightness <= 0.15 or lightness >= 0.85:
                continue

            weighted_hues.append((hue, saturation * saturation * alpha_weight))

    if weighted_hues:
        sin_sum = sum(weight * math.sin(math.radians(hue)) for hue, weight in weighted_hues)
        cos_sum = sum(weight * math.cos(math.radians(hue)) for hue, weight in weighted_hues)
        mean_hue = math.degrees(math.atan2(sin_sum, cos_sum)) % 360
        return _hsl_to_godot_color(mean_hue)

    if fallback_saturation > 0:
        return _hsl_to_godot_color(fallback_hue)

    return (1.0, 1.0, 1.0, 1.0)


def godot_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def format_portraits(variants: list[str]) -> tuple[str, str]:
    blocks: list[str] = []
    for variant in variants:
        key = portrait_key(variant)
        image = portrait_image_path(variant)
        blocks.append(
            f'"{godot_escape(key)}": {{\n'
            f'"export_overrides": {{\n'
            f'"image": "\\"{godot_escape(image)}\\""\n'
            f"}},\n"
            f'"mirror": false,\n'
            f'"offset": Vector2(0, 0),\n'
            f'"scale": 1,\n'
            f'"scene": ""\n'
            f"}}"
        )
    return portrait_key(variants[0]), ",\n".join(blocks)


def format_nicknames(nicknames: list[str]) -> str:
    cleaned = [n for n in nicknames if n]
    if not cleaned:
        return "[]"
    items = ", ".join(f'"{godot_escape(n)}"' for n in cleaned)
    return f"[{items}]"


def format_description(first: str, description: str) -> str:
    return godot_escape(f"origin={first}\ndescription={description}")


def load_characters() -> list[dict]:
    with CHARACTERS_JSON.open(encoding="utf-8") as handle:
        return json.load(handle)


def build_dch(character: dict, variants: list[str], color: tuple[float, float, float, float]) -> str:
    default_portrait, portraits_block = format_portraits(variants)
    return DCH_HEADER.format(
        color_r=color[0],
        color_g=color[1],
        color_b=color[2],
        color_a=color[3],
        default_portrait=godot_escape(default_portrait),
        description=format_description(character.get("first", ""), character.get("description", "")),
        display_name=godot_escape(character["name"]),
        nicknames=format_nicknames(character.get("nickname", [])),
        portraits=portraits_block,
    )


def update_project_godot(entries: dict[str, str]) -> None:
    text = PROJECT_GODOT.read_text(encoding="utf-8")
    lines = ['"{name}": "{path}"'.format(name=godot_escape(name), path=path) for name, path in sorted(entries.items(), key=lambda item: item[0])]
    block = "directories/dch_directory={\n" + ",\n".join(lines) + "\n}"
    pattern = r"directories/dch_directory=\{\n(?:[^\n]*\n)*?\}"
    text, count = re.subn(pattern, block, text, count=1)
    if count != 1:
        raise RuntimeError("Could not update directories/dch_directory in project.godot")
    PROJECT_GODOT.write_text(text, encoding="utf-8")


def convert() -> tuple[int, int]:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for old_file in OUTPUT_DIR.glob("*.dch"):
        old_file.unlink()
    for old_uid in OUTPUT_DIR.glob("*.dch.uid"):
        old_uid.unlink()

    generated = 0
    skipped = 0
    registry: dict[str, str] = {}

    for character in load_characters():
        character_id = character.get("characterId", "")
        name = character.get("name", "")

        if character_id == "FALLBACK" or name == "【无角色】":
            skipped += 1
            continue

        variants = character.get("variants") or []
        existing_variants = [variant for variant in variants if (PORTRAITS_DIR / f"{variant}.png").exists()]
        if not existing_variants:
            skipped += 1
            continue

        color = vibrant_color(PORTRAITS_DIR / f"{existing_variants[0]}.png")
        dch_path = OUTPUT_DIR / f"{name}.dch"
        dch_path.write_text(build_dch(character, existing_variants, color), encoding="utf-8", newline="\n")
        registry[name] = f"res://definitions/characters/tmi/{name}.dch"
        generated += 1

    update_project_godot(registry)
    return generated, skipped


def main() -> None:
    generated, skipped = convert()
    print(f"Generated {generated} .dch files in {OUTPUT_DIR.relative_to(REPO_ROOT)}")
    print(f"Skipped {skipped} characters without portraits")
    print(f"Updated {PROJECT_GODOT.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
