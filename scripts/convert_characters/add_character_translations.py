"""Add en and ja name translations to dialogic_character_translations.csv."""

from __future__ import annotations

import csv
import json
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CHARACTERS_JSON = REPO_ROOT / "Characters.json"
CSV_PATH = REPO_ROOT / "definitions" / "database" / "translations" / "dialogic_character_translations.csv"
CSV_IMPORT_PATH = CSV_PATH.with_suffix(".csv.import")
PROJECT_GODOT = REPO_ROOT / "project.godot"
ORIGINAL_LOCALE = "zh"
TARGET_LOCALES = ("en", "ja")


def load_name_translations() -> dict[str, dict[str, str]]:
    with CHARACTERS_JSON.open(encoding="utf-8") as handle:
        characters = json.load(handle)

    translations: dict[str, dict[str, str]] = {}
    for character in characters:
        name = character.get("name", "")
        if not name:
            continue

        en_names = character.get("enName") or []
        en_name = en_names[0] if en_names else ""
        jp_name = character.get("jpName") or ""

        translations[name] = {
            "en": en_name,
            "ja": jp_name,
        }

    return translations


def read_csv_rows() -> tuple[list[str], list[list[str]]]:
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.reader(handle))

    if not rows:
        raise RuntimeError(f"{CSV_PATH} is empty")

    return rows[0], rows[1:]


def write_csv(header: list[str], rows: list[list[str]]) -> None:
    with CSV_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)


def pad_row(row: list[str], width: int) -> list[str]:
    padded = row[:width]
    while len(padded) < width:
        padded.append("")
    return padded


def update_csv(name_translations: dict[str, dict[str, str]]) -> tuple[int, int]:
    header, rows = read_csv_rows()
    locale_columns = header[1:]

    for locale in TARGET_LOCALES:
        if locale not in locale_columns:
            locale_columns.append(locale)

    new_header = ["keys", *locale_columns]
    column_index = {locale: new_header.index(locale) for locale in locale_columns}
    updated_names = 0
    new_rows: list[list[str]] = []

    for row in rows:
        if not row or not row[0].strip():
            new_rows.append(pad_row(row, len(new_header)))
            continue

        padded = pad_row(row, len(new_header))
        key = padded[0]

        if key.endswith("/name"):
            zh_name = padded[column_index[ORIGINAL_LOCALE]]
            translated = name_translations.get(zh_name, {})
            padded[column_index["en"]] = translated.get("en", "")
            padded[column_index["ja"]] = translated.get("ja", "")
            updated_names += 1

        new_rows.append(padded)

    write_csv(new_header, new_rows)
    return updated_names, len(new_rows)


def update_csv_import() -> None:
    translation_paths = [
        f"res://definitions/database/translations/dialogic_character_translations.{locale}.translation"
        for locale in (ORIGINAL_LOCALE, *TARGET_LOCALES)
    ]
    files_block = ", ".join(f'"{path}"' for path in translation_paths)
    text = CSV_IMPORT_PATH.read_text(encoding="utf-8")
    text = re.sub(
        r"files=\[[^\]]*\]",
        f"files=[{files_block}]",
        text,
        count=1,
    )
    text = re.sub(
        r"dest_files=\[[^\]]*\]",
        f"dest_files=[{files_block}]",
        text,
        count=1,
    )
    CSV_IMPORT_PATH.write_text(text, encoding="utf-8")


def update_project_godot() -> None:
    text = PROJECT_GODOT.read_text(encoding="utf-8")
    translation_paths = [
        f"res://definitions/database/translations/dialogic_character_translations.{locale}.translation"
        for locale in (ORIGINAL_LOCALE, *TARGET_LOCALES)
    ]
    example_path = "res://definitions/database/translations/dialogic_example_translation.zh.translation"
    all_paths = translation_paths + [example_path]
    translations_block = "PackedStringArray(\n" + ",\n".join(f'"{path}"' for path in all_paths) + "\n)"
    locales_block = "[" + ", ".join(f'"{locale}"' for locale in TARGET_LOCALES) + "]"

    if re.search(r"^locale/translations=", text, flags=re.MULTILINE):
        text = re.sub(
            r"^locale/translations=PackedStringArray\([\s\S]*?\)",
            f"locale/translations={translations_block}",
            text,
            count=1,
            flags=re.MULTILINE,
        )
    else:
        text = re.sub(
            r"(\[internationalization\]\r?\n)",
            rf"\1\nlocale/translations={translations_block}\n",
            text,
            count=1,
        )

    text = re.sub(
        r"translation/locales=\[[^\]]*\]",
        f"translation/locales={locales_block}",
        text,
        count=1,
    )

    PROJECT_GODOT.write_text(text, encoding="utf-8")


def main() -> None:
    name_translations = load_name_translations()
    updated_names, total_rows = update_csv(name_translations)
    update_csv_import()
    update_project_godot()
    print(f"Updated {updated_names} character name rows in {CSV_PATH.relative_to(REPO_ROOT)}")
    print(f"CSV now has locales: {ORIGINAL_LOCALE}, {', '.join(TARGET_LOCALES)} ({total_rows} data rows)")
    print(f"Updated {CSV_IMPORT_PATH.relative_to(REPO_ROOT)} and {PROJECT_GODOT.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
