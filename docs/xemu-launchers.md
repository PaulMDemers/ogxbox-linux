# xemu Launcher Inventory

Updated: 2026-08-02

The repository currently keeps 44 root-level `run-xemu*.ps1` entry points.
Historical filenames remain supported because bringup notes and proof commands
refer to them directly.

## Families

| Family | Count | Status |
|---|---:|---|
| Shared wrappers | 7 | Migrated to `scripts\invoke_xemu.ps1` and smoke tested |
| Legacy Cromwell/Xromwell | 24 | Direct command snapshots; next safe migration family |
| Direct kernel | 6 | Pass a kernel/initrd directly in the xemu machine string |
| Dynamic TOML/media | 3 | Generate per-run HDD/DVD configuration; keep separate for now |
| Base/retail/NXDK | 4 | General emulator and non-Linux development entry points |

## Shared Launcher

`scripts\invoke_xemu.ps1` owns the common operations:

- resolve repository-relative paths
- verify xemu, config, MCPX, BIOS, and optional required files
- construct the Xbox machine argument and AV pack selection
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

The compatibility wrappers also honor `XBOX_XEMU_DRY_RUN=1`. This is intended
for automated verification; normal wrapper invocation still starts xemu.

## Migrated Compatibility Wrappers

The seven `run-xemu-cromwell-modernhdr*.ps1` launchers are now thin wrappers.
Their filenames, configs, BIOS files, device lists, and trailing xemu argument
behavior are unchanged.

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

The next candidate is the 24 direct Cromwell/Xromwell command snapshots. The
direct-kernel, dynamic-media, and base emulator families should remain unchanged
until that migration has been exercised successfully.
