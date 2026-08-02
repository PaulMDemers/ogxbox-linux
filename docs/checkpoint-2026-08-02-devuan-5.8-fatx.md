# Devuan 5.8.1 Non-Disc Checkpoint

## Goal

Restore the previously successful Devuan 5.8.1 terminal and desktop systems as
softmod/XBE packages that boot entirely from the Xbox hard disk.

## Approach

The original 5.8.1 distro packages required a disc because the kernel could not
mount FATX after Xromwell handed control to Linux. Embedding the 285-403 MB root
payloads in initramfs is not viable on a 64 MB Xbox.

The non-disc build therefore keeps the previous 5.8.1 Xbox kernel configuration
and adds the read-only FATX filesystem driver backported from the project's
6.18 branch. The only configuration delta from
`xbox-linux-5.8.1-rd-gzip.config` is `CONFIG_FATX_FS=y`.

Xromwell is pinned to the 3fa5e65 sector512 launcher, SHA-256
`81B3A6850627A8BEC6FA0D92BB4652400DB3EC863072EAA7351BB159DED0BAFD`.
This is the launcher lineage that booted four of five repeated hardware trials
during the May investigation.

## Build

Run:

```powershell
.\scripts\build_devuan_5_8_nondisc.ps1
```

Output:

```text
artifacts\devuan-5.8.1-nondisc\
```

Each package folder and ZIP contains its own `default.xbe`, `E-root` kernel,
initramfs, root payload, and `linuxboot.cfg`. Files must not be mixed between
terminal and desktop packages.

## Validation State

- The 5.8.1 FATX kernel compiles successfully.
- The saved working config differs only by built-in FATX support.
- Package construction verifies the pinned Xromwell hash.
- A disposable xemu FATX HDD boot reached the Devuan terminal proof shell.
- A second xemu boot reopened the desktop SquashFS and reached X with a
  populated terminal window.
- The non-disc terminal package booted successfully on a real Xbox.
- The non-disc desktop package booted successfully on a real Xbox and reached
  the desktop.

Proof screenshots:

```text
run\screenshots\devuan58-fatx-nondisc-smoke-20260802-122730.png
run\screenshots\devuan58-fatx-nondisc-desktop-smoke-20260802-123040.png
```

## Hardware-Tested Baseline

The following exact ZIPs are the first confirmed non-disc Devuan 5.8.1
real-hardware baseline:

```text
D6A314145B1523CD9701362E81B4ECB453463375C4F461B352A758121F6349C4  devuan-daedalus-terminal-5.8.1-xbe.zip
CB01ED5C384E7B2E6B0A16C74D7C2FFECE609A50D95C6577C1A926A2279CE7D6  devuan-daedalus-desktop-live-5.8.1-xbe.zip
```

Do not replace these files in place after future kernel, initramfs, payload, or
Xromwell changes. New builds should use a new output directory and undergo a
fresh hardware test.
