# Devuan 5.8.1 Cold-Boot Reliability

## Scope

This test protects the exact hardware-validated non-disc artifacts in
`artifacts/devuan-5.8.1-nondisc/`. It never rebuilds or edits those packages.
Each variant is copied to a disposable raw Xbox HDD, staged as contiguous FATX
E: files, and launched by a fresh xemu process with `-snapshot`.

The package ZIP and every unpacked package file are checked against the
protected manifest before xemu starts. The pinned Xromwell sector512 loader ISO
is used only to launch the E:-root files in the disposable image.

## Measurement

Run the standard three-boot batch:

```powershell
.\scripts\test_devuan_5_8_cold_boots.ps1 -Variant all -Runs 3
```

Useful options:

```powershell
# Recreate the disposable raw disks before measuring.
.\scripts\test_devuan_5_8_cold_boots.ps1 -Variant all -Runs 3 -RebuildImages

# Exercise only one package or allow a longer loader timeout.
.\scripts\test_devuan_5_8_cold_boots.ps1 -Variant desktop -Runs 5 -TimeoutSeconds 240
```

The runner uses the compiled C# full-window capture utility. It does not resize
xemu or crop a focused region. `classify_xemu_boot_frame.py` classifies each
saved full-window PNG as Xromwell, Linux text, an X desktop, a transition, or an
unknown state. The classifier requires Python and Pillow. Every run retains its PNG/JSON evidence under
`run/boot-reliability/<timestamp>/`; that generated directory is ignored by
Git.

## 2026-08-02 Result

The final visually audited batches passed completely:

| Variant | Result | Linux text | X started | Populated desktop / ready |
|---|---:|---:|---:|---:|
| Terminal | 3/3 | 45 s | n/a | 80-86 s |
| Desktop | 3/3 | 45-46 s | 85-86 s | 91-97 s |

Result set:

```text
docs\results\devuan-5.8-coldboot-20260802.json
```

That committed summary identifies the ignored full evidence directories for
the terminal and desktop batches.

The classifier was calibrated against the earlier full-window terminal, bare-X,
populated-terminal, decorated-Fluxbox, and stalled-Xromwell captures. Its
synthetic regression check is:

```powershell
python .\scripts\test_boot_frame_classifier.py
```

Terminal readiness must match the committed full-window proof-shell fixture and
remain stable across consecutive captures. The fixture is
`tests/fixtures/devuan58-terminal-proof.png`, SHA-256
`F4300D06C2529F12CA14AD158CBD809AAD4E39384BB23B8BCB25368BEA212A57`.
This prevents kernel output or the earlier `Switching to distro root` screen
from being counted as a completed terminal boot.

## Residual Risk

Before the automated batch, two identical exploratory desktop cold boots were
run. One reached Linux userspace around 73 seconds, a populated terminal around
104 seconds, and decorated Fluxbox around 146 seconds. The other stopped making
visible progress while Xromwell loaded the initramfs. The measured 3/3 desktop
result is encouraging, but it does not prove the historical loader instability
is gone. Future candidates should be compared with this same repeated test, and
real-hardware boot counts remain authoritative.
