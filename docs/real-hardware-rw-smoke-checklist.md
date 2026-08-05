# Real Hardware RW Shell Smoke Checklist

Date: August 5, 2026

This is the disk-safety checkpoint before using the writable Debian desktop on
real hardware. It intentionally does not start X.

## Package

Use the xemu-gated package:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\debian-6.18.33-rw-candidate\xromwell-hddfatx-debian-bookworm-6.18.33-rw-shell.zip
```

Expected ZIP SHA-256:

```text
23F5B8717A11F7C4DDCA1E1947A362BCBCC7FBBC4DE7DBFFE1845E29B19FCF04
```

Build it with:

```powershell
.\scripts\build_debian_6_18_rw_candidate.ps1 -Force
.\scripts\test_debian_6_18_rw_safety_gate.ps1 -BootCount 2
```

The package writes test files inside `E:\rwdebian.ext2`, then replaces PID 1
with `xbox-sync-ro` to sync and remount the ext2 root read-only. It does not
start X or launch a general-purpose shell.

## Backup

Before testing, make a complete backup of E:. At minimum back up
`E:\linuxboot.cfg` and any existing files with these candidate names:

```text
E:\linuxboot.cfg
E:\rwkrnl
E:\rwinit
E:\rwdebian.ext2
```

Also keep the known-good read-only Debian package nearby:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-debian-bookworm-i386.zip
```

## Install

FTP or copy the app folder to:

```text
E:\Apps\XboxLinuxDebian618RwShell\
```

Copy the package `E-root\` files to `E:\`:

```text
E:\linuxboot.cfg
E:\rwkrnl
E:\rwinit
E:\rwdebian.ext2
```

Launch:

```text
E:\Apps\XboxLinuxDebian618RwShell\default.xbe
```

## First Boot Pass Criteria

The console should show:

```text
XBOX_PERSIST_MARKER_WRITTEN
XBOX_NORMAL_USE_FILE_WRITTEN
XBOX_ROOT_REMOUNT_RO_OK
```

After `XBOX_ROOT_REMOUNT_RO_OK`, wait ten seconds, then reset or power off for
this smoke test. If that marker does not appear, do not intentionally
power-cycle unless the system is already hung; restore the E: backup before
another write attempt.

## Second Boot Pass Criteria

Launch the same package again without replacing `E:\rwdebian.ext2`. The console
should show:

```text
XBOX_PERSIST_MARKER_PRESENT
XBOX_NORMAL_USE_FILE_PRESENT
XBOX_ROOT_REMOUNT_RO_OK
```

This proves on hardware that the FATX existing-file write path can persist data
inside the preallocated Debian ext2 image and can return to a clean read-only
state before shutdown.

## xemu Proof

The final package was staged into one disposable xemu FATX HDD and booted twice
without restaging. Both boots showed the marker files and:

```text
XBOX_ROOT_REMOUNT_RO_OK
```

Automated result:

```text
boot 1: mount count 1, remount OK, e2fsck -fn clean
boot 2: mount count 2, remount OK, e2fsck -fn clean
```

Evidence directory:

```powershell
run\debian-rw-safety-gate\20260805-182211\
```

The gate enforces persistence, mount-count progression, remount status, and a
clean host-side `e2fsck -fn` after each boot.

## Recovery

If the rw smoke fails, restore the complete E: backup and return to the
read-only Debian package. Do not copy a failed `rwdebian.ext2` into another
package. The FATX kernel write support is intentionally narrow: it overwrites
data inside existing files only. It does not create, delete, rename, extend,
or allocate FATX files.
