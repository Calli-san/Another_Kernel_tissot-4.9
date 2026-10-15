# Experimental tissot Android 15 Treble build

Target: Xiaomi Mi A1 (`tissot`), arm64, Linux 4.9.337, Treble.
The reference phone reports `4.9.337-ReLIFE-Treble` and runs Rising Revived
6.2.1 Android 15 (a daisy port). Matching the kernel series is necessary but
does not prove that this different kernel tree will boot that ROM.

## Sources and version pins

| Component | Source | Pinned revision |
| --- | --- | --- |
| Kernel baseline | Mantii04/Another_Kernel_tissot-4.9, NON-OC | `fe7b03d3dc33c70877d664ff8aa43b8b09a3b02d` |
| KernelSU Next legacy with SUSFS integration | https://github.com/sidex15/KernelSU-Next, legacy-susfs-v2 | `d999a2aff11575c6e2f520129ecffb7c6058fb02` |
| SUSFS 2.3.0 port for Linux 4.9 | https://github.com/wxx9248/susfs4ksu, kernel-4.9-v2 | `71345ded5af28f55d76ebcdc7a9df9cea56111e1` |
| tissot AnyKernel3 template | https://github.com/sirnewbies/Anykernel3, tissot | `4d2299424aff352dae279c4b3e04d2822967f2df` |

The Next submodule is a community SUSFS fork of
https://github.com/KernelSU-Next/KernelSU-Next. Its nearest tag is
`v3.4.0-legacy-susfs-v2`; it must not be confused with an unmodified official
release. The SUSFS kernel changes are vendored, with the SukiSU-specific
integration hooks replaced by the Next manual interfaces. No moving branch
is downloaded to replace the root driver during builds.

The obsolete SUSFS `ADD_TRY_UMOUNT` interface is disabled: SUSFS 2.3.0 no
longer implements it. Next's own mount cleanup remains enabled. The fork's
existing memkernel driver is not built by this configuration.

## Build locally

Use Linux or WSL2. Ubuntu 22.04 with GCC 10 cross compilers is the CI target:

```sh
sudo apt-get update
sudo apt-get install build-essential bc bison flex libncurses-dev libssl-dev \
    libelf-dev python3 git zip gcc-10-aarch64-linux-gnu gcc-10-arm-linux-gnueabi
git submodule update --init KernelSU
# Put gcc-10 wrappers on PATH if your default cross compiler is a different version.
bash scripts/build-tissot.sh
bash scripts/package-tissot.sh
```

The executable names expected on PATH are `aarch64-linux-gnu-gcc` and
`arm-linux-gnueabi-gcc`, along with their cross-binutils. The workflow creates
temporary wrappers for GCC 10 without overwriting system compilers.
`JOBS`, `OUT_DIR`, `CROSS_COMPILE`, and `CROSS_COMPILE_ARM32` can be overridden.

GitHub Actions also builds this branch and uploads a single artifact containing
the image, effective configuration, provenance, checksums, and installer ZIP.
Extract the outer Actions artifact ZIP: the installer is the inner
`Another-Tissot-A15-Treble-Next-SUSFS-r4-EXPERIMENTAL.zip`.

## Validation and device testing

Compilation and linking only validate the build. Booting, KernelSU privilege
management, module mounting, SUSFS behaviour, Wi-Fi, cameras, mobile data,
fingerprint, encryption, and suspend require tests on the target phone.
The user confirms R2 boots and detects Next/SUSFS. Full hardware validation
is pending. R3 has not yet been tested on the phone.

Before testing, retain a backup of the current active-slot boot partition and
a working recovery/restore method. The installer checks the tissot device and
Android 15, repacks the current boot ramdisk, and handles the active A/B slot.
It does not convert ROM layouts or update vendor/firmware. These checks cannot
prove vendor compatibility. Do not replace both boot slots for an initial test.

Use a compatible KernelSU Next Manager, not the original KernelSU Manager.
Userspace SUSFS tooling must support the 2.3.0 kernel ABI; a 1.5.x tool is not
compatible. Confirm its reported version before enabling SUSFS policies.
No integrity-check or application-compatibility result is promised.

Credits: the kernel authors, KernelSU/KernelSU Next developers, simonpunk,
sidex15, wxx9248, osm0sis, and the tissot AnyKernel template maintainer.

## Revision 2: first device failure investigation

The first image installed successfully but rebooted at the device logo.
A retained `dmesg-ramoops-0` record identifies the failed kernel by its
`Another-Next-SUSFS-Treble` release. The remaining trace is from a secondary
CPU being stopped during panic; it does not establish that CPU idle is the
faulting subsystem. The primary panic message was not retained.

The supplied working boot backup passed its SHA-256 check. Its tissot DTB
is byte-identical to this tree's DTB (SHA-256
`ee4d46f836ebdbb50b4cd4b3a74734bb7b7e5f114ef5fd92abbfb88ca79d2317`).
The backup ramdisk contains recovery, and the embedded ReLIFE config disables
`INITRAMFS_IGNORE_SKIP_FLAG` and
`PROC_CMDLINE_APPEND_ANDROID_FORCE_NORMAL_BOOT`. Revision 2 matches those
boot settings rather than forcing the recovery ramdisk into normal boot.
This is an evidence-backed compatibility correction, not a proven root cause.

Pstore compression now matches ReLIFE's zlib. The tissot backend retains
multiple 4 KiB panic records, up to a 128 KiB snapshot, instead of discarding
all parts after the first. Physical addresses, record size and the persistent
RAM layout remain unchanged so recovery/working kernels can read them.
The user confirms Revision 2 boots. If a later revision fails, enter recovery
without booting Android repeatedly and collect all files from `/sys/fs/pstore`.

The supplied ramdisk is Magisk-patched, and the working kernel contains the
Magisk `skip_initramfs` -> `want_initramfs` string patch. Config differences
alone therefore do not explain its effective boot behaviour. AK3's default
Magisk-preservation path would apply that kernel patch again. Revision 2 uses
Magisk's own CPIO `restore` operation on the installer's working ramdisk before
repacking, verifies that it is stock, and avoids that preservation path. It
restores the original init from the embedded backup; it does not delete
`/data/adb` or uninstall applications. The separately saved boot backup remains
the rollback image, including its previous Magisk setup.

The original template also recursively set ramdisk files to mode 0644,
then only restored execute permissions for root init/sbin paths. This can
remove execute permission from recovery-as-boot `/system/bin` binaries.
Revision 2 removes those blanket chmod/chown calls and retains original
CPIO ownership, executable modes and symlinks.

## Revision 3: allow Next's init transition on nosuid mounts

The supplied live R2 dmesg records `security_bounded_transition` denying
`u:r:init:s0` -> `u:r:ksu:s0`. All three init-launched ksud boot stages
(post-fs-data, services, boot-completed) then fail to exec with EACCES/status
127. Root requests still work, but module startup does not run.

The baseline check_nnp_nosuid exception hard-coded the old `u:r:su:s0`
domain. Replace it with Next's pinned `is_ksu_transition` helper, guarded by
CONFIG_KSU. The helper permits only init -> the configured Next domain;
other NNP/nosuid transitions still go through the existing bounded check.
Global SELinux enforcement is unchanged.

The ROM also reports `service logd not found` with both ReLIFE and R2.
That is a separate observed logging issue; R3 does not claim to repair it.
The earlier archived KSU logs identify ReLIFE and must not be treated as
current R2 daemon logs. Confirm R3 boots, ksud stages exit successfully and
Zygisk reports active before declaring this issue resolved.

## Revision 4: fingerprint thaw comparison bounds

With all user modules disabled, the phone still restarted during idle.
The new pstore includes R3 Oops/Panic records with `detected buffer overflow
in memcmp`, `fortify_panic` and `thaw_fingerprintd+0xbc/0x180` in the
suspend/resume path. This establishes a kernel bug independently of the
previous module-startup issue; it does not establish that every reported
restart has the same cause.

The baseline thaw_fingerprintd compared 13 bytes against the 7-byte literal
`"gx_fpd"` (including NUL). Replace that comparison with strcmp to match the
complete process name without reading beyond the literal. Preserve the
existing Android HAL prefix comparisons and thaw timing. FORTIFY remains
enabled. An isolated harness using the actual function reproduces the old
global-buffer-overflow with AddressSanitizer; the fixed function passes six
matching/nonmatching cases under AddressSanitizer/UBSan (leak detection
disabled due to the host execution environment).

R4 requires a full kernel build and target-phone suspend/resume validation.
Start with modules disabled and repeat idle testing, fingerprint unlock and
normal reboot. Instagram video corruption remains separately unresolved.
