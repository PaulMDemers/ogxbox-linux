#!/usr/bin/env python3
"""Classify a full-window xemu capture without OCR or guest instrumentation."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageStat


def ratio(values: list[bool]) -> float:
    return sum(values) / len(values) if values else 0.0


def image_data(image: Image.Image):
    """Return pixels on both current and older supported Pillow releases."""
    getter = getattr(image, "get_flattened_data", None)
    return getter() if getter is not None else image.getdata()


def binary_distance(left: Image.Image, right: Image.Image) -> float:
    left_gray = left.convert("L").resize((128, 96))
    right_gray = right.convert("L").resize((128, 96))
    differences = [
        abs(a - b)
        for a, b in zip(image_data(left_gray), image_data(right_gray))
    ]
    return sum(differences) / (len(differences) * 255)


def classify(path: Path, reference: Path | None = None) -> dict[str, object]:
    with Image.open(path) as source:
        image = source.convert("RGB")

    width, height = image.size
    # Exclude most title-bar and black letterbox area while retaining the guest display.
    guest = image.crop((0, int(height * 0.12), width, int(height * 0.91)))
    sample = guest.resize((240, 160))
    pixels = list(image_data(sample))
    luminance = [(r * 299 + g * 587 + b * 114) // 1000 for r, g, b in pixels]

    blue_ratio = ratio([
        b >= 70 and b >= int(r * 1.25) and b >= int(g * 1.12)
        for r, g, b in pixels
    ])
    green_ratio = ratio([
        g >= 70 and g >= int(r * 1.25) and g >= int(b * 1.08)
        for r, g, b in pixels
    ])
    dark_ratio = ratio([value < 42 for value in luminance])
    light_ratio = ratio([value > 150 for value in luminance])

    gray = sample.convert("L")
    horizontal = []
    vertical = []
    for y in range(1, gray.height - 1):
        for x in range(1, gray.width - 1):
            value = gray.getpixel((x, y))
            horizontal.append(abs(value - gray.getpixel((x + 1, y))) > 58)
            vertical.append(abs(value - gray.getpixel((x, y + 1))) > 58)
    edge_ratio = (ratio(horizontal) + ratio(vertical)) / 2

    center = sample.crop((int(sample.width * 0.05), int(sample.height * 0.10),
                          int(sample.width * 0.83), int(sample.height * 0.73)))
    center_luma = list(image_data(center.convert("L")))
    center_dark_ratio = ratio([value < 42 for value in center_luma])

    fingerprint_image = sample.convert("L").resize((48, 32))
    fingerprint_bytes = bytes(
        min(255, (value // 16) * 16)
        for value in image_data(fingerprint_image)
    )
    fingerprint = hashlib.sha256(fingerprint_bytes).hexdigest().upper()

    reference_distance = None
    if reference is not None and reference.exists():
        with Image.open(reference) as reference_image:
            reference_distance = binary_distance(image, reference_image.convert("RGB"))

    mean_rgb = ImageStat.Stat(sample).mean
    channel_spread = max(mean_rgb) - min(mean_rgb)

    # Xromwell is blue-dominant. Console text retains more local contrast than
    # a dark transition after downscaling. The X server's monochrome stipple is
    # nearly neutral gray; a populated terminal makes the center mostly dark.
    if blue_ratio >= 0.30:
        stage = "xromwell"
    elif green_ratio >= 0.25:
        stage = "xbox-splash"
    elif green_ratio >= 0.02 and dark_ratio >= 0.75 and edge_ratio < 0.02:
        stage = "xbox-error"
    elif dark_ratio >= 0.72 and edge_ratio >= 0.025:
        stage = "linux-text"
    elif channel_spread <= 5.0 and 20 <= sum(mean_rgb) / 3 <= 90 and dark_ratio < 0.70:
        stage = "desktop-x"
    elif dark_ratio >= 0.86:
        stage = "dark-transition"
    else:
        stage = "unknown"

    return {
        "path": str(path.resolve()),
        "width": width,
        "height": height,
        "stage": stage,
        "blueRatio": round(blue_ratio, 6),
        "greenRatio": round(green_ratio, 6),
        "darkRatio": round(dark_ratio, 6),
        "lightRatio": round(light_ratio, 6),
        "edgeRatio": round(edge_ratio, 6),
        "centerDarkRatio": round(center_dark_ratio, 6),
        "referenceDistance": None if reference_distance is None else round(reference_distance, 6),
        "fingerprint": fingerprint,
        "meanRgb": [round(value, 2) for value in mean_rgb],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument("--reference", type=Path)
    parser.add_argument("--pretty", action="store_true")
    args = parser.parse_args()
    print(json.dumps(classify(args.image, args.reference), indent=2 if args.pretty else None))


if __name__ == "__main__":
    main()
