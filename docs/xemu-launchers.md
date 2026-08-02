# xemu Launcher Inventory

Updated: 2026-08-02

The repository currently keeps 44 root-level `run-xemu*.ps1` entry points.
Historical filenames remain supported because bringup notes and proof commands
refer to them directly.

## Families

| Family | Count | Status |
|---|---:|---|
| Shared wrappers | 37 | Migrated to `scripts\invoke_xemu.ps1` and smoke tested |
| Dynamic TOML/media | 3 | Generate per-run HDD/DVD configuration; keep separate for now |
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

## Migration Rules

1. Do not delete or rename a historical root launcher.
2. Migrate one behaviorally uniform family at a time.
3. Add each migrated wrapper to the dry-run smoke matrix.
4. Keep launchers that generate TOML or manage temporary media separate until
   their lifecycle behavior is represented in the shared API.
5. Do not change the validated Devuan package, BIOS, HDD, or media artifacts as
   part of launcher cleanup.

The three dynamic-media launchers are the only remaining Linux-specific
outliers. They generate temporary TOML and manage HDD/DVD lifecycle, so they
should be audited as a separate family rather than forced into the static
wrapper API. The four base emulator/retail/NXDK launchers remain intentionally
simple and do not need migration.
