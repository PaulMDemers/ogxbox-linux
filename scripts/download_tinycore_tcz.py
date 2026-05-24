#!/usr/bin/env python3
"""Download Tiny Core x86 .tcz extensions and their recursive deps."""

from __future__ import annotations

from hashlib import md5
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import urlopen
import argparse


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BASE = "https://distro.ibiblio.org/tinycorelinux/16.x/x86/tcz"
DEFAULT_OUT = ROOT / "downloads" / "tinycore" / "16.x" / "x86" / "tcz"


def fetch(url: str) -> bytes:
    with urlopen(url, timeout=30) as response:
        return response.read()


def try_fetch(url: str) -> bytes | None:
    try:
        return fetch(url)
    except HTTPError as exc:
        if exc.code == 404:
            return None
        raise


def normalize_name(name: str) -> str:
    name = name.strip()
    if not name:
        raise ValueError("empty extension name")
    if not name.endswith(".tcz"):
        name += ".tcz"
    return name


def dep_names(base_url: str, name: str, out_dir: Path) -> list[str]:
    dep_path = out_dir / f"{name}.dep"
    data = try_fetch(f"{base_url}/{name}.dep")
    if data is None:
        return []
    dep_path.write_bytes(data)
    deps = []
    for line in data.decode("utf-8", "replace").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            deps.append(normalize_name(line))
    return deps


def download_file(base_url: str, name: str, out_dir: Path) -> None:
    for suffix in ("", ".md5.txt", ".info", ".list"):
        target = out_dir / f"{name}{suffix}"
        if target.exists() and suffix == "":
            continue
        data = try_fetch(f"{base_url}/{name}{suffix}")
        if data is not None:
            target.write_bytes(data)

    md5_path = out_dir / f"{name}.md5.txt"
    tcz_path = out_dir / name
    if md5_path.exists():
        expected = md5_path.read_text(encoding="utf-8", errors="replace").split()[0].lower()
        actual = md5(tcz_path.read_bytes()).hexdigest()
        if actual != expected:
            raise RuntimeError(f"MD5 mismatch for {name}: expected {expected}, got {actual}")


def resolve(base_url: str, seeds: list[str], out_dir: Path) -> list[str]:
    out_dir.mkdir(parents=True, exist_ok=True)
    seen: set[str] = set()
    ordered: list[str] = []

    def visit(name: str) -> None:
        name = normalize_name(name)
        if name in seen:
            return
        seen.add(name)
        for dep in dep_names(base_url, name, out_dir):
            visit(dep)
        download_file(base_url, name, out_dir)
        ordered.append(name)

    for seed in seeds:
        visit(seed)
    return ordered


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("extensions", nargs="+")
    parser.add_argument("--base-url", default=DEFAULT_BASE)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    ordered = resolve(args.base_url.rstrip("/"), args.extensions, args.out_dir)
    order_path = args.out_dir / "desktop-load-order.txt"
    order_path.write_text("\n".join(ordered) + "\n", encoding="ascii")
    for name in ordered:
        print(name)
    print(order_path)


if __name__ == "__main__":
    main()
