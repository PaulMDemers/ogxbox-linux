# Real Hardware Softmod Test

Use this order on a backed-up softmodded Xbox.

## Packages

BusyBox smoke test:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-busybox-smoke.zip
```

Tiny Core FATX desktop test:

```text
C:\Users\Paul\Desktop\xbox_linux\artifacts\softmod\xromwell-hddfatx-tinycore-fatx.zip
```

## Backup First

Back up any existing files with these names from `E:\`:

```text
E:\linuxboot.cfg
E:\vmlinuz
E:\initramf
E:\linuxroot.ext2
```

## BusyBox First

Copy the BusyBox package folder to:

```text
E:\Apps\XromwellBusyBoxSmoke\
```

Copy the contents of its `E-root\` folder to `E:\`.

Launch:

```text
E:\Apps\XromwellBusyBoxSmoke\default.xbe
```

Expected result: Linux reaches a BusyBox shell. This proves the dashboard, XBE, Cromwell FATX loader, kernel handoff, and initramfs path.

xemu proof:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xbe-package-busybox-smoke-90-20260525-140817.png
```

## Tiny Core Second

Copy the Tiny Core package folder to:

```text
E:\Apps\XromwellTinyCoreFatx\
```

Copy the contents of its `E-root\` folder to `E:\`.

Launch:

```text
E:\Apps\XromwellTinyCoreFatx\default.xbe
```

Expected result: Linux mounts `E:` as FATX, opens `E:\linuxroot.ext2`, and starts the Tiny Core Xfbdev desktop.

xemu proof:

```text
C:\Users\Paul\Desktop\xbox_linux\run\screenshots\xbe-package-tinycore-fatx-270-20260525-141349.png
```

## Cleanup

Remove the app folders and the E-root payload files:

```text
E:\Apps\XromwellBusyBoxSmoke\
E:\Apps\XromwellTinyCoreFatx\
E:\linuxboot.cfg
E:\vmlinuz
E:\initramf
E:\linuxroot.ext2
```

Restore any backed-up files with the same names.
