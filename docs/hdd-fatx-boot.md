# FATX HDD Boot Bringup

This is the current HDD boot workflow after the 6.18 Tiny Core ISO checkpoint.

## Current Status

The disposable HDD test image is:

```text
C:\Users\Paul\Desktop\xbox_linux\run\hdd\xbox_hdd_hddboot.raw
```

It was created from:

```text
C:\Users\Paul\Desktop\xbox_linux\Xbox-Emulator-Files\hdd\xbox_hdd.qcow2
```

The original qcow2 is not modified.

The FATX E partition is staged with:

```text
/linuxboot.cfg
/vmlinuz
/initramf
```

Current staged payload:

- `vmlinuz`: `artifacts\kernels\xbox-linux-6.18.33-bzImage`
- `initramf`: `artifacts\initramfs\xbox-busybox-console.cpio`
- append line: `init=/init noswitchroot debug console=tty0 ignore_loglevel loglevel=7`

Current proof screenshot:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\hdd-fatx-autoboot-busybox-6.18.33-titlefix-20260524-230831.png
```

That proves Cromwell can:

- unlock the raw test HDD
- detect FATX
- read and parse E-root `/linuxboot.cfg`
- select the nested Linux entry
- start loading `/vmlinuz` from FATX

Open issue: the FATX kernel load currently stalls at `Loading /vmlinuz from FATX`. The next work is inside Cromwell's FATX/HDD read path, not in the HDD staging script.

## Artifacts

HDD-autoboot Cromwell ROM:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\cromwell-hddfatx-autoboot-modernhdr-initrd32_1024.bin
```

HDD-autoboot Xromwell app package:

```text
C:\Users\Paul\Desktop\xbox_linux\build\xromwell-hddfatx-autoboot-disc\default.xbe
```

xemu XDVDFS test image for that XBE:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\xromwell-hddfatx-autoboot-initrd32.iso
```

## Build And Stage

Convert the baseline qcow2 to a disposable raw HDD:

```powershell
New-Item -ItemType Directory -Force .\run\hdd | Out-Null
wsl -e bash -lc "cd /mnt/c/Users/Paul/Desktop/xbox_linux && python3 scripts/qcow2_to_raw_sparse.py Xbox-Emulator-Files/hdd/xbox_hdd.qcow2 run/hdd/xbox_hdd_hddboot.raw --force"
```

Stage the E-root linuxboot files:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stage_hdd_fatx_linuxboot.ps1
```

Build the FATX-autoboot Cromwell ROM and XBE:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_cromwell_hdd_fatx_autoboot.ps1
```

Run the current xemu HDD test:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-cromwell-hdd-fatx-busybox-6.18.33.ps1
```

Capture proof with the C# window capture tool:

```powershell
.\tools\capture-xemu-window\bin\Release\net10.0-windows\CaptureXemuWindow.exe --out-dir .\run\screenshots --prefix hdd-fatx-autoboot-busybox-6.18.33 --rect frame
```

## Cromwell Changes

Cromwell branch:

```text
PaulMDemers/cromwell.git xbox-linux-fast-atapi-autoboot @ fe80736
```

Relevant changes:

- `XBOX_LINUX_AUTOBOOT_FATX` compile-time path that selects the default nested Linux entry from E-root FATX.
- FATX config file loads allocate one extra NUL byte for `ParseConfig`.
- `ParseConfig` bounds title copies to the 15-byte title field.
- FATX fixed-position loads no longer prefill the destination buffer.
- Optional `FATX_PROGRESS` prints can be enabled while diagnosing HDD reads.

## Next Work

The immediate next target is to make `/vmlinuz` finish loading from FATX. Likely places to inspect:

- `fs/fatx/BootFATX.c`
- `drivers/ide/BootIde.c`
- retry/timeout behavior in the ATA HDD read path
- whether FATX should read larger contiguous runs instead of one 512-byte sector at a time
