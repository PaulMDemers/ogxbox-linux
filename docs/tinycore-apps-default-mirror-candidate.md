# Tiny Core Apps Default-Mirror Candidate

Date: 2026-08-05

## Goal

Skip Tiny Core Apps' first-run fastest-mirror benchmark on the 64 MB Original
Xbox while retaining the normal Tiny Core 11 x86 repository. On hardware the
benchmark path can fail and leave the system unresponsive, while declining the
prompt allows Apps to work normally.

## Design

Tiny Core's `firstrun` file is an empty marker whose existence means the Apps
first-run dialog has already run. The Apps mirror itself is independently read
from `/opt/tcemirror`. The candidate therefore adds the boot argument:

```text
xbox_apps_skip_mirror=1
```

When present, the Xbox desktop launcher creates:

```text
/tmp/tce/optional/
/tmp/tce/firstrun
```

Apps changes into `<tcedir>/optional` before checking `../firstrun`. The
directory therefore has to exist for that relative marker to resolve to
`/tmp/tce/firstrun`. It does not run `mirrorpicker` and does not write
`/opt/tcemirror`. The expected mirror remains:

```text
http://repo.tinycorelinux.net/
```

This follows Tiny Core's documented first-run marker behavior and the Apps
source rather than patching the compiled binary. References:

- <https://www.tinycorelinux.net/corebook.pdf>, section 20.1, "Firstrun."
- <https://github.com/tinycorelinux/fltk_projects/blob/master/apps/apps.cxx>

The first implementation created only `/tmp/tce/firstrun`. Runtime tracing
showed that `/tmp/tce/optional` did not exist, so Apps' `chdir` failed and its
relative marker resolved to `/tmp/firstrun`. The visual smoke test caught the
still-visible prompt. The fixed candidate creates the standard directory first.

## Protected Baseline

The candidate builder requires the exact promoted release ZIP:

```text
artifacts/tinycore-6.18.33-nondisc/
  tinycore11-desktop-6.18.33-pre-apps-rollback-xbe.zip
SHA256 F75DC44CBA6CDD994E146C6E684AFE0EB149DFF75E48BA5A0CC8CA965A5FDAF1
```

The promoted ZIP is checked before and after candidate construction and is not
modified. Candidate differences are limited to `E-root/initramf`,
`E-root/linuxboot.cfg`, and the added candidate README. Kernel, payload, XBE,
and all other release files remain byte-identical.

## Build

```powershell
powershell -ExecutionPolicy Bypass -File `
  .\scripts\new_tinycore_apps_default_mirror_candidate.ps1 -Force
```

Output:

```text
artifacts/tinycore-apps-default-mirror-candidate/
  tinycore11-desktop-6.18.33-apps-default-mirror-xbe.zip
SHA256 B914A6B513009CE84422EE881996B09F96F75196F65D3F3FB39B0B272478F6F0
```

## Emulator Verification

The 2026-08-05 candidate passed three fresh-disk xemu boots:

| Run | Linux | Desktop proof |
| --- | ---: | ---: |
| 1 | 22 s | 45 s |
| 2 | 17 s | 45 s |
| 3 | 17 s | 45 s |

Every staged FATX file was contiguous and passed readback SHA-256 validation.
The SSH Apps smoke test confirmed:

```text
XBOX_APPS_FIRSTRUN_MARKER_OK
XBOX_APPS_OPTIONAL_DIR_OK
XBOX_APPS_DEFAULT_MIRROR_OK
XBOX_APPS_LAUNCH_OK
XBOX_APPS_CWD_OK
XBOX_APPS_NO_FALLBACK_MARKER_OK
XBOX_APPS_NO_MIRRORPICKER_OK
XBOX_APPS_MIRROR_UNCHANGED_OK
```

The full-window capture also showed the Apps browser itself with no first-run
dialog, `/tmp/tce/optional` as its TCE directory, and the unchanged repository
URL. Testing only for an Apps process and an absent `mirrorpicker` process is
not sufficient: `mirrorpicker` does not start until the user chooses Yes.

## Hardware Result

The exact ZIP and SHA-256 listed above passed the real-hardware gate on
2026-08-05. Apps opened directly without the fastest-mirror question, normal
operation was confirmed, and the Xbox remained responsive after the test.

An SSH snapshot taken while that same boot was still running confirmed:

- the kernel command line contained `xbox_apps_skip_mirror=1`;
- `/etc/sysconfig/tcedir` resolved to `/tmp/tce`;
- `/tmp/tce/optional` existed;
- `/tmp/tce/firstrun` was the only `firstrun` marker under `/tmp`;
- `/opt/tcemirror` remained `http://repo.tinycorelinux.net/`;
- DHCP configured `192.168.50.156` with a default route and resolver;
- hotset release restored all 450 paths with zero failures;
- X was ready at 26.48 seconds and wallpaper/dock startup finished at 27.63;
- `MemAvailable` was 6,260 kB after the interactive test session.

The collected state, boot diagnostics, network log, timing data, hotset logs,
and SHA-256 manifest are retained locally under:

```text
run\tinycore-apps-hardware\20260805-confirmed
```

## Promotion

The exact hardware-tested ZIP was promoted without rebuilding it to:

```text
artifacts/tinycore-6.18.33-nondisc/
  tinycore11-desktop-6.18.33-apps-default-mirror-xbe.zip
```

Its SHA-256 remains `B914A6B513009CE84422EE881996B09F96F75196F65D3F3FB39B0B272478F6F0`.
The older promoted package is retained beside it as the complete named rollback
`tinycore11-desktop-6.18.33-pre-apps-rollback-xbe.zip` with SHA-256
`F75DC44CBA6CDD994E146C6E684AFE0EB149DFF75E48BA5A0CC8CA965A5FDAF1`.

The self-contained promoted layout passed an additional fresh-FATX boot and
Apps/SSH smoke gate before replacing the canonical release folder.
