#!/usr/bin/env python3
"""Small dependency-free regression check for the xemu frame classifier."""

from __future__ import annotations

import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

from classify_xemu_boot_frame import classify


def save_frame(path: Path, guest: Image.Image) -> None:
    frame = Image.new("RGB", (640, 500), "black")
    frame.paste(guest.resize((640, 395)), (0, 60))
    frame.save(path)


def main() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)

        blue = Image.new("RGB", (640, 395), (20, 45, 145))
        blue_path = root / "xromwell.png"
        save_frame(blue_path, blue)
        assert classify(blue_path)["stage"] == "xromwell"

        console = Image.new("RGB", (640, 395), "black")
        draw = ImageDraw.Draw(console)
        for y in range(20, 340, 14):
            draw.rectangle((20, y, 420, y + 4), fill=(220, 220, 220))
        console_path = root / "console.png"
        save_frame(console_path, console)
        assert classify(console_path)["stage"] == "linux-text"

        desktop = Image.new("RGB", (640, 395), (58, 58, 58))
        draw = ImageDraw.Draw(desktop)
        draw.rectangle((25, 60, 500, 310), fill=(8, 8, 8))
        desktop_path = root / "desktop.png"
        save_frame(desktop_path, desktop)
        result = classify(desktop_path)
        assert result["stage"] == "desktop-x"
        assert result["centerDarkRatio"] >= 0.66

    fixture = Path(__file__).resolve().parent.parent / "tests" / "fixtures" / "devuan58-terminal-proof.png"
    fixture_result = classify(fixture, fixture)
    assert fixture_result["stage"] == "linux-text"
    assert fixture_result["referenceDistance"] == 0.0

    print("boot frame classifier: PASS")


if __name__ == "__main__":
    main()
