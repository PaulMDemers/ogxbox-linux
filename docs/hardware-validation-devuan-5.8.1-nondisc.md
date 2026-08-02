# Devuan 5.8.1 Non-Disc Hardware Validation

## Result

Both non-disc packages built on 2026-08-02 booted successfully on real Original
Xbox hardware:

- Devuan Daedalus terminal 5.8.1
- Devuan Daedalus desktop live 5.8.1

The packages boot from the FATX E: volume through the pinned Xromwell sector512
launcher. No Linux payload disc is required.

## Validated Artifacts

```text
D6A314145B1523CD9701362E81B4ECB453463375C4F461B352A758121F6349C4  devuan-daedalus-terminal-5.8.1-xbe.zip
CB01ED5C384E7B2E6B0A16C74D7C2FFECE609A50D95C6577C1A926A2279CE7D6  devuan-daedalus-desktop-live-5.8.1-xbe.zip
```

Location:

```text
artifacts\devuan-5.8.1-nondisc\
```

## Baseline Components

- Kernel: Linux 5.8.1 Xbox configuration with built-in read-only FATX support
- Kernel commit: `22fbdf0ede3cd4bdd387a03a4e5f21c6fc0c8b61`
- Xromwell lineage: `3fa5e65-sector512`
- Xromwell SHA-256:
  `81B3A6850627A8BEC6FA0D92BB4652400DB3EC863072EAA7351BB159DED0BAFD`
- Stage one: `xbox-distro-hdd-ext2-stage1.cpio`
- Terminal root: `devuan.ext2`
- Desktop root: `devuan.squashfs`

This is now the rollback point for subsequent Devuan kernel, desktop, and
performance work.
