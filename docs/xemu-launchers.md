# xemu Launcher Inventory

Updated: 2026-08-02

The repository currently keeps 44 root-level `run-xemu*.ps1` entry points.
Historical filenames remain supported because bringup notes and proof commands
refer to them directly.

## Families

| Family | Count | Status |
|---|---:|---|
| Shared static wrappers | 37 | Migrated to `scripts\invoke_xemu.ps1` and smoke tested |
| Shared temporary-media wrappers | 2 | Migrated to `scripts\invoke_xemu_temporary_media.ps1` and smoke tested |
| Persistent dynamic media | 1 | Xromwell HDD/FATX diagnostic launcher; intentionally separate |
| Base/retail/NXDK | 4 | General emulator and non-Linux development entry points |

## Shared Launcher

`scripts\invoke_xemu.ps1` owns the common operations:

- resolve repository-relative paths
- verify xemu, config, MCPX, BIOS, and optional required files
- construct the Xbox machine argument and AV pack selection
- resolve and validate optional direct-boot kernel/initrd inputs
- preserve legacy Xromwell commands that intentionally omit `-machine`
- add zero or more USB devices
- forward additional xemu arguments unchanged
- return the complete command without starting xemu when `-DryRun` is used

Example:

```powershell
.\scripts\invoke_xemu.ps1 `
  -ConfigPath run\xemu-cromwell-modernhdr-initrd32-busybox-console-6.18.33.toml `
  -BiosPath artifacts\cromwell-autocd-modernhdr-initrd32_1024.bin `
  -DryRun
```

The compatibility wrappers also honor `XBOX_XEMU_DRY_RUN=1`. The smoke test
additionally uses `XBOX_XEMU_SKIP_PATH_VALIDATION=1` so generated artifacts can
be absent while commands are inspected. Path validation can only be skipped in
dry-run mode; normal wrapper invocation still validates inputs and starts xemu.

## Migrated Compatibility Wrappers

Thirty-seven Linux launchers are now thin wrappers: the original seven
`modernhdr` launchers, 24 legacy direct-command launchers, and six direct-kernel
launchers. Their filenames, configs, xemu binaries, BIOS and media files,
device lists, machine argument behavior, diagnostic log handling, and trailing
xemu argument forwarding are unchanged.

Verify all of them without launching xemu:

```powershell
.\scripts\test_xemu_launcher_wrappers.ps1
```

The smoke test checks exact argument order for every wrapper and confirms that
additional xemu arguments are forwarded intact.

## Temporary Media Launcher

`scripts\invoke_xemu_temporary_media.ps1` represents the lifecycle shared by
the two Devuan live-disc launchers. It creates a uniquely named TOML under the
user temporary directory, records the selected BIOS, EEPROM, HDD, and DVD,
delegates command construction and validation to `scripts\invoke_xemu.ps1`,
and removes the TOML in a `finally` block.

| Launcher | Generated config | Lifecycle |
|---|---|---|
| `run-xemu-devuan-desktop-full-live-cromwell-autocd.ps1` | `xemu-devuan-live-autocd-<guid>.toml` | Temporary; always removed |
| `run-xemu-devuan-desktop-full-live-game-disc.ps1` | `xemu-devuan-live-<guid>.toml` | Temporary; always removed |
| `run-xemu-xromwell-hddfatx-autoboot.ps1` | `run\xemu-xromwell-hddfatx-autoboot.toml` | Persistent diagnostic state; preserved |

Verify the temporary wrappers against their real local dependencies without
launching xemu:

```powershell
.\scripts\test_dynamic_xemu_launchers.ps1
```

The test checks exact arguments and required paths, generated TOML contents,
trailing argument forwarding, and removal of every temporary config.

## Migration Rules

1. Do not delete or rename a historical root launcher.
2. Migrate one behaviorally uniform family at a time.
3. Add each migrated wrapper to the dry-run smoke matrix.
4. Keep persistent diagnostic configs separate unless their retained state is
   deliberately represented in a shared API.
5. Do not change the validated Devuan package, BIOS, HDD, or media artifacts as
   part of launcher cleanup.

The one remaining Linux-specific outlier is the Xromwell HDD/FATX launcher. It
accepts alternate HDD/DVD media and leaves a fixed ignored TOML in `run\` for
diagnosis; moving it into the temporary-media helper would change that useful
lifecycle. The four base emulator/retail/NXDK launchers remain intentionally
simple and do not need migration.
