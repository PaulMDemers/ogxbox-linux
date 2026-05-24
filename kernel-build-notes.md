# Xbox Linux 5.8.1 Kernel Build

Built from `haxar/xbox-linux` branch `xbox-linux`.

Source archive:

- `downloads/haxar-xbox-linux.tar.gz`

Fast build location:

- WSL: `~/xbox-linux-build/src`
- WSL output: `~/xbox-linux-build/out`

Workspace artifacts:

- `artifacts/kernels/xbox-linux-5.8.1-bzImage`
- `artifacts/kernels/xbox-linux-5.8.1.config`

Build commands:

```powershell
wsl.exe -d Ubuntu-24.04 -- bash -lc "rm -rf ~/xbox-linux-build; mkdir -p ~/xbox-linux-build/src ~/xbox-linux-build/out; tar -xzf /mnt/c/Users/Paul/Desktop/xbox_linux/downloads/haxar-xbox-linux.tar.gz -C ~/xbox-linux-build/src --strip-components=1"
wsl.exe -d Ubuntu-24.04 -- bash -lc "cd ~/xbox-linux-build/src && make O=~/xbox-linux-build/out ARCH=x86 xbox_defconfig"
wsl.exe -d Ubuntu-24.04 -- bash -lc "cd ~/xbox-linux-build/src && make O=~/xbox-linux-build/out ARCH=x86 -j6 bzImage"
```

Windows-mounted kernel builds were too slow for practical iteration. Building inside WSL's native filesystem completed successfully.

Launch this kernel with Tiny Core's `core.gz`:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-xbox-kernel-tinycore.ps1
```

Launch the same kernel with the diagnostic smoke initramfs:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-xemu-xbox-smoke-initramfs.ps1
```

Smoke test status:

- `xbox_defconfig`: passed.
- `bzImage`: built successfully in WSL native filesystem.
- xemu paused direct-boot argument test: passed.
- xemu unpaused 10-second headless run: stayed alive until killed manually, so xemu accepts and starts the kernel/initrd setup.
- Direct-boot visibility is still blocked: xemu shows its "no guest display yet" placeholder, serial capture did not receive data, and a poweroff-initramfs did not shut xemu down. Treat the xemu direct Linux loader path as unproven for this kernel.
- Rebuilt a second kernel with `CONFIG_SERIAL_8250=y` and `CONFIG_SERIAL_8250_CONSOLE=y`: `artifacts/kernels/xbox-linux-5.8.1-serial-bzImage`.
- xemu exposes `isa-serial`, but serial file capture still produced no guest output under the Xbox machine.
