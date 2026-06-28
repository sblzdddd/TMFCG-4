#!/usr/bin/env python3
"""Merge suit texture red channels into combined RGBA atlases."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

SUITS = ("Clubs", "Diamonds", "Hearts", "Spades")
DEFAULT_PARTS_DIR = Path(__file__).resolve().parents[2] / "assets" / "textures" / "cards" / "parts"


def merge_red_channels(suit_paths: list[Path], output_path: Path) -> None:
    if len(suit_paths) != 4:
        raise ValueError(f"Expected 4 suit textures, got {len(suit_paths)}")

    images = [Image.open(path).convert("RGBA") for path in suit_paths]
    size = images[0].size
    for path, image in zip(suit_paths[1:], images[1:], strict=True):
        if image.size != size:
            raise ValueError(
                f"Size mismatch: {suit_paths[0].name} is {size}, {path.name} is {image.size}"
            )

    red_channels = [image.split()[0] for image in images]
    merged = Image.merge("RGBA", red_channels)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    merged.save(output_path)
    print(f"Wrote {output_path} ({merged.size[0]}x{merged.size[1]})")


def merge_group(parts_dir: Path, suffix: str, output_name: str) -> None:
    suit_paths = [parts_dir / f"{suit}{suffix}.png" for suit in SUITS]
    for path in suit_paths:
        if not path.is_file():
            raise FileNotFoundError(f"Missing texture: {path}")

    merge_red_channels(suit_paths, parts_dir / output_name)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Pack each suit's red channel into R/G/B/A of a merged PNG."
    )
    parser.add_argument(
        "--parts-dir",
        type=Path,
        default=DEFAULT_PARTS_DIR,
        help="Directory containing per-suit Bottom/Top PNG files.",
    )
    args = parser.parse_args()
    parts_dir = args.parts_dir.resolve()

    merge_group(parts_dir, "Bottom", "BottomSuitsMerged.png")
    merge_group(parts_dir, "Top", "TopSuitsMerged.png")


if __name__ == "__main__":
    main()
