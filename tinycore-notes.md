# Tiny Core 17 x86 Inputs

Fetched from `https://distro.ibiblio.org/tinycorelinux/17.x/x86/release/distribution_files/`.

- `upstream/tinycore-17-x86/vmlinuz`
- `upstream/tinycore-17-x86/core.gz`
- `upstream/tinycore-17-x86/rootfs.gz`
- `upstream/tinycore-17-x86/modules.gz`

Launch Tiny Core's stock kernel/initrd under xemu's Xbox machine:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-tinycore.ps1
```

Headless paused smoke test:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-tinycore-headless.ps1
```

The stock Tiny Core kernel is not expected to be the final kernel. This is only a quick direct-boot experiment. The real target is an Xbox-enabled kernel paired with Tiny Core's small userspace.

Current direct-boot wrinkle: xemu's wrapper splits `append=` on spaces before passing the command to QEMU. The first scripts use a single `quiet` argument for smoke testing. A real Tiny Core command line will probably need either a bootloader path or an xemu invocation patch/workaround.

The preferred next test is now `run-xemu-xbox-kernel-tinycore.ps1`, which uses the built Xbox-enabled 5.8.1 kernel with Tiny Core's `core.gz`.

For first visible output, prefer `run-xemu-xbox-smoke-initramfs.ps1`. It uses the same Tiny Core base but replaces `/init` with a tiny diagnostic shell path.

## Cromwell/Xbox Kernel Desktop Path

The working desktop proof now uses the Cromwell ISO boot path, not direct `-kernel` boot:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-tinycore11-stage6-xfbdev-desktop-noxpad-usbkbd-tablet.ps1
```

Tiny Core 16.x boots as a chroot payload, but its current FLTK/window-manager tools are built with a Linux 6.1.2 ABI requirement. With the Xbox 5.8.1 kernel, Tiny Core 11.x is the practical desktop target.

Current proof artifacts:

- `artifacts/cromwell-tinycore11-stage6-xfbdev-desktop-noxpad.iso`
- `downloads/tinycore/11.x/x86/core.gz`
- `downloads/tinycore/11.x/x86/tcz/desktop-load-order.txt`
- `run/screenshots/tinycore11-stage6-xfbdev-desktop-20260524-162921.png`
- `run/screenshots/tinycore11-stage6-xfbdev-desktop-input-20260524-162945.png`
