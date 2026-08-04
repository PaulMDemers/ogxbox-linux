# Tiny Core HDD RA128 Candidate

## Scope

This candidate applies the Devuan storage-test finding to the Tiny Core 11
HDD/FATX lean package without modifying the hardware-passed source ZIP.

Protected source:

```text
artifacts\softmod\xromwell-hddfatx-tinycore-lean.zip
SHA256 17327756ED0CB274145CFDD974D119BEF19DB0F7588509726BB8C6BBFD4DE866
```

Candidate:

```text
artifacts\tinycore-hdd-ra128-candidate\xromwell-hddfatx-tinycore-lean-ra128k-candidate.zip
SHA256 DB01FC290A3E98BA0147F04D7AB874B255091645A4186AB9FA5EF5FD1663F246
```

The candidate preserves these protected-package components:

```text
default.xbe       C78475E8713EC694F484C40209966805E9F9CD267E7C2EE6A3B9217E40FE0CD2
vmlinuz           D3C812196908F8F2CA96C7863184C59C39982E27A2DD1ED6DFF125D5DA9FCAFE
linuxroot.ext2    CFBBC4ED822FFBA297954C80FA94B1878C5CBB07BE7FA8F7B855E3B55E3E4691
```

Only the generated stage7 initramfs and `linuxboot.cfg` change. The command
line keeps physical-disk read-ahead at 1024 KiB and sets the FATX backing loop
and ext2 root loop to 128 KiB. Stage7 applies each value immediately after the
corresponding device is attached, before payload reads.

## Emulator Gate

The first test used Complex BIOS plus an XBE-on-DVD wrapper. Both the candidate
and an exact protected control panicked before `/init` at
`unknown-block(3,1)`. Existing project notes identify this as an xemu wrapper
that can fail to pass the initrd.

The valid regression path uses the FATX-autoboot Cromwell ROM, payload-first
contiguous FATX staging, a fresh raw HDD for every run, readback SHA-256
verification, and full-window captures. Results:

```text
variant              runs   Linux text   desktop proof
protected control    3/3       21 s           42 s
RA128 candidate      3/3       21 s           42 s
```

Candidate run:

```text
run\tinycore-hdd-ra128-rom-fixed\20260803-231219
```

Final full-window proof:

```text
run\tinycore-hdd-ra128-rom-fixed\20260803-231219\run-03\frame-042s-20260803-231507.png
```

The build script writes all initramfs output under the isolated candidate
directory. The test harness also verifies that all three read-ahead arguments
are present on the single `append` line, which prevents a silent config no-op.

## Reproduce

```powershell
.\scripts\new_tinycore_hdd_ra128_candidate.ps1
.\scripts\test_tinycore_hdd_candidate.ps1 -Runs 3 -RequiredPasses 3
```

The candidate is ready for a real-hardware A/B focused on responsiveness after
the desktop appears. Equal xemu boot timing is a compatibility result, not
evidence that RA128 is faster on the Xbox HDD path. Keep the protected package
as the release baseline until that hardware comparison passes.
