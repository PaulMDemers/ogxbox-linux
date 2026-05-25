#!/usr/bin/env python3
"""Create an ISO9660 image for Cromwell linuxboot.cfg tests."""

from pathlib import Path
import os
import pycdlib


ROOT = Path(__file__).resolve().parents[1]
STAGING = ROOT / "build" / "cromwell-iso"
OUT = ROOT / "artifacts" / "cromwell-smoke.iso"


def main():
    STAGING.mkdir(parents=True, exist_ok=True)
    OUT.parent.mkdir(parents=True, exist_ok=True)

    mode = os.environ.get("CROMWELL_ISO_MODE", "smoke")
    out = Path(os.environ.get("CROMWELL_ISO_OUT", OUT))
    tc_version = os.environ.get("TINYCORE_VERSION", "16.x")
    kernel_override = os.environ.get("CROMWELL_KERNEL")
    initramfs_override = os.environ.get("CROMWELL_INITRAMFS")
    append_extra = os.environ.get("CROMWELL_APPEND", "").strip()
    tc_root = ROOT / "downloads" / "tinycore" / tc_version / "x86"
    extra_tcz_files = []
    extra_tcz_order = None

    def kernel(default):
        if not kernel_override:
            return default
        path = Path(kernel_override)
        if not path.is_absolute():
            path = ROOT / path
        return path

    def initramfs(default):
        if not initramfs_override:
            return default
        path = Path(initramfs_override)
        if not path.is_absolute():
            path = ROOT / path
        return path

    def append_line(base):
        append = base
        if append_extra:
            append = f"{append} {append_extra}"
        return f"append {append}\n"

    if mode == "tiny-read":
        tiny_kernel = STAGING / "smallkern"
        tiny_initrd = STAGING / "smallinit"
        tiny_kernel.write_bytes(b"tiny cromwell read probe\n")
        tiny_initrd.write_bytes(b"tiny initrd read probe\n")
        files = {
            "SMALLKERN": tiny_kernel,
            "SMALLINIT": tiny_initrd,
        }
        cfg_text = (
            "kernel smallkern\n"
            "initrd smallinit\n"
            "append debug\n"
        )
    elif mode == "serial-smoke":
        files = {
            "VMLINUZ": kernel(ROOT / "artifacts" / "kernels" / "xbox-linux-5.8.1-serial-bzImage"),
            "INITRAMF": initramfs(ROOT / "artifacts" / "initramfs" / "xbox-smoke-core.gz"),
        }
        cfg_text = (
            "kernel vmlinuz\n"
            "initrd initramf\n"
            "append console=ttyS0,115200n8 debug\n"
        )
    elif mode == "tiny-init":
        files = {
            "VMLINUZ": kernel(ROOT / "artifacts" / "kernels" / "xbox-linux-5.8.1-bzImage"),
            "INITRAMF": initramfs(ROOT / "artifacts" / "initramfs" / "xbox-tiny-init.cpio"),
        }
        cfg_text = (
            "kernel vmlinuz\n"
            "initrd initramf\n"
            "append init=/init nousb debug\n"
        )
    elif mode == "busybox-init":
        files = {
            "VMLINUZ": kernel(ROOT / "artifacts" / "kernels" / "xbox-linux-5.8.1-bzImage"),
            "INITRAMF": initramfs(ROOT / "artifacts" / "initramfs" / "xbox-busybox-raw.cpio"),
        }
        cfg_text = (
            "kernel vmlinuz\n"
            "initrd initramf\n"
            + append_line("init=/init noswitchroot debug")
        )
    elif mode == "tinycore-stage3-noxpad":
        files = {
            "VMLINUZ": kernel(ROOT / "artifacts" / "kernels" / "xbox-linux-5.8.1-noxpad-bzImage"),
            "INITRAMF": initramfs(ROOT / "artifacts" / "initramfs" / "xbox-tinycore-stage3.cpio"),
            "CORE.GZ": tc_root / "core.gz",
        }
        cfg_text = (
            "kernel vmlinuz\n"
            "initrd initramf\n"
            + append_line("init=/init noswitchroot debug")
        )
    elif mode == "tinycore-stage4-noxpad":
        files = {
            "VMLINUZ": kernel(ROOT / "artifacts" / "kernels" / "xbox-linux-5.8.1-noxpad-bzImage"),
            "INITRAMF": initramfs(ROOT / "artifacts" / "initramfs" / "xbox-tinycore-stage4.cpio"),
            "CORE.GZ": tc_root / "core.gz",
        }
        cfg_text = (
            "kernel vmlinuz\n"
            "initrd initramf\n"
            + append_line("init=/init noswitchroot debug")
        )
    elif mode == "tinycore-stage5-desktop-probe-noxpad":
        files = {
            "VMLINUZ": kernel(ROOT / "artifacts" / "kernels" / "xbox-linux-5.8.1-noxpad-bzImage"),
            "INITRAMF": initramfs(ROOT / "artifacts" / "initramfs" / "xbox-tinycore-stage5-desktop-probe.cpio"),
            "CORE.GZ": tc_root / "core.gz",
        }
        cfg_text = (
            "kernel vmlinuz\n"
            "initrd initramf\n"
            + append_line("init=/init noswitchroot debug")
        )
    elif mode == "tinycore-stage6-xfbdev-desktop-noxpad":
        tcz_dir = tc_root / "tcz"
        extra_tcz_order = tcz_dir / "desktop-load-order.txt"
        extra_tcz_files = [
            (line.strip(), tcz_dir / line.strip())
            for line in extra_tcz_order.read_text(encoding="ascii").splitlines()
            if line.strip()
        ]
        files = {
            "VMLINUZ": kernel(ROOT / "artifacts" / "kernels" / "xbox-linux-5.8.1-noxpad-bzImage"),
            "INITRAMF": initramfs(ROOT / "artifacts" / "initramfs" / "xbox-tinycore-stage6-xfbdev-desktop.cpio"),
            "CORE.GZ": tc_root / "core.gz",
        }
        cfg_text = (
            "kernel vmlinuz\n"
            "initrd initramf\n"
            + append_line("init=/init noswitchroot debug")
        )
    elif mode == "busybox-console":
        files = {
            "VMLINUZ": kernel(ROOT / "artifacts" / "kernels" / "xbox-linux-5.8.1-bzImage"),
            "INITRAMF": initramfs(ROOT / "artifacts" / "initramfs" / "xbox-busybox-console.cpio"),
        }
        cfg_text = (
            "kernel vmlinuz\n"
            "initrd initramf\n"
            "append init=/init noswitchroot debug\n"
        )
    elif mode == "busybox-console-noxpad":
        files = {
            "VMLINUZ": kernel(ROOT / "artifacts" / "kernels" / "xbox-linux-5.8.1-noxpad-bzImage"),
            "INITRAMF": initramfs(ROOT / "artifacts" / "initramfs" / "xbox-busybox-console.cpio"),
        }
        cfg_text = (
            "kernel vmlinuz\n"
            "initrd initramf\n"
            "append init=/init noswitchroot debug\n"
        )
    elif mode == "busybox-stage2-noxpad":
        files = {
            "VMLINUZ": kernel(ROOT / "artifacts" / "kernels" / "xbox-linux-5.8.1-noxpad-bzImage"),
            "INITRAMF": initramfs(ROOT / "artifacts" / "initramfs" / "xbox-busybox-stage2.cpio"),
        }
        cfg_text = (
            "kernel vmlinuz\n"
            "initrd initramf\n"
            "append init=/init noswitchroot debug\n"
        )
    else:
        files = {
            "VMLINUZ": kernel(ROOT / "artifacts" / "kernels" / "xbox-linux-5.8.1-bzImage"),
            "INITRAMF": initramfs(ROOT / "artifacts" / "initramfs" / "xbox-smoke-core.gz"),
        }
        cfg_text = (
            "kernel vmlinuz\n"
            "initrd initramf\n"
            "append debug\n"
        )

    cfg = STAGING / "linuxboot.cfg"
    cfg.write_text(cfg_text, encoding="ascii")

    iso = pycdlib.PyCdlib()
    iso.new(interchange_level=3, joliet=True, vol_ident="XBOXLINUX")
    for name, path in files.items():
        if "." in name:
            iso.add_file(str(path), iso_path=f"/{name};1", joliet_path=f"/{name.lower()}")
        else:
            iso.add_file(str(path), iso_path=f"/{name}.;1", joliet_path=f"/{name.lower()}")
    iso.add_file(str(cfg), iso_path="/LINUXBOOT.CFG;1", joliet_path="/linuxboot.cfg")
    if extra_tcz_files:
        iso.add_directory(iso_path="/TCZ", joliet_path="/tcz")
        for index, (name, path) in enumerate(extra_tcz_files, start=1):
            iso.add_file(
                str(path),
                iso_path=f"/TCZ/T{index:05d}.TCZ;1",
                joliet_path=f"/tcz/{name}",
            )
        iso.add_file(
            str(extra_tcz_order),
            iso_path="/TCZ/ORDER.TXT;1",
            joliet_path="/tcz/desktop-load-order.txt",
        )
    iso.write(str(out))
    iso.close()
    print(out)


if __name__ == "__main__":
    main()
