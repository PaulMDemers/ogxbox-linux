# Tiny Core Remote Diagnostics Candidate

## Purpose

The hardware-passed Tiny Core X-hotset package reaches an interactive desktop
in about 50 seconds, but collecting its `/tmp/xbox-*.txt` diagnostics through
the television terminal is awkward. This isolated follow-up adds a readable
terminal font and Dropbear SSH without modifying the protected package.

The candidate preserves the hardware-passed kernel, Xromwell XBE, X-hotset,
desktop order, and 1024 KiB storage read-ahead settings. Its payload adds the
official Tiny Core 11 x86 `dropbear.tcz` extension. After DHCP succeeds, the
initramfs starts Dropbear on TCP port 22 with root login disabled.

## Artifact

Use the complete ZIP. Do not mix its files with another candidate:

```text
artifacts\tinycore-hdd-x-hotset-remote-candidate\xromwell-hddfatx-tinycore-lean-xhotset-remote-ra1024k-candidate.zip
SHA256 106623AB9315CBA7844CD8CB291E3FA5C7DCF41084970D289ACFEE7FA2F39477
```

The generated manifest beside the ZIP records SHA-256 hashes for the ZIP and
every packaged file. The protected input remains:

```text
artifacts\softmod\xromwell-hddfatx-tinycore-lean.zip
SHA256 17327756ED0CB274145CFDD974D119BEF19DB0F7588509726BB8C6BBFD4DE866
```

## Connect

The proof terminal displays the DHCP address and remote-service status. From
Windows PowerShell on the same LAN:

```powershell
ssh tc@XBOX_IP
```

The diagnostic candidate credentials are:

```text
user: tc
password: tcuser
```

Copy the useful logs without typing them at the Xbox:

```powershell
scp tc@XBOX_IP:/tmp/xbox-*.txt .
```

Host keys are generated in RAM and therefore change after every Xbox reboot.
Before reconnecting, remove the stale host entry:

```powershell
ssh-keygen -R XBOX_IP
```

This fixed password is for LAN diagnostics only. Root SSH login is disabled,
but the image must not be exposed to an untrusted network or promoted as a
release default without replacing the password with key-only authentication.

## Emulator Gate

The final candidate must pass three fresh-disk desktop boots through the
established Cromwell-ROM transport. The remote smoke test then boots another
fresh disk with xemu NAT forwarding from host port 2222 to guest port 22,
captures the complete xemu window, and requires an SSH handshake. Password
authentication was also checked interactively and returned:

```text
XBOX_SSH_LOGIN_OK
uid=1001(tc) gid=50(staff) groups=50(staff)
6.18.33-xboxdev-00007-g502b7bb738cf
XBOX_REMOTE_SSH_OK
```

The ext2 payload must also pass read-only `e2fsck` with zero non-contiguous
files. These gates prove packaging and service startup in xemu; real hardware
must still confirm memory headroom, DHCP, readable terminal geometry, and SSH
access over the physical Xbox Ethernet adapter.

Final xemu results:

```text
run  Linux text  complete desktop  proof terminal
1    17 s        45 s              45 s
2    16 s        45 s              45 s
3    17 s        45 s              45 s

run\tinycore-hdd-x-hotset-remote-release\20260804-201133
run\tinycore-hdd-x-hotset-remote-release-ssh\20260804-201453
```

## Reproduce

```powershell
.\scripts\new_tinycore_hdd_remote_diag_candidate.ps1
.\scripts\test_tinycore_hdd_candidate.ps1 `
  -CandidateRoot artifacts\tinycore-hdd-x-hotset-remote-candidate `
  -OutputRoot run\tinycore-hdd-x-hotset-remote `
  -Runs 3 -RequiredPasses 3 -PollSeconds 5
.\scripts\test_tinycore_remote_diag.ps1
```

## Hardware Checklist

1. Extract the complete candidate and copy `default.xbe` plus all four
   `E-root` files exactly as packaged.
2. Confirm the larger terminal font is readable and the desktop remains as
   responsive as the hardware-passed X-hotset build.
3. Confirm the proof terminal reports `XBOX_NETWORK_DHCP_OK` and
   `XBOX_REMOTE_SSH_OK`.
4. Connect as `tc`, run `uname -a`, and copy `/tmp/xbox-*.txt` with `scp`.
5. Record `free -m` before and after an SSH session so Dropbear's hardware
   memory cost is known before any promotion decision.
