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
`Another-Tissot-A15-Treble-Next-SUSFS-r2-EXPERIMENTAL.zip`.

## Validation and device testing

Compilation and linking only validate the build. Booting, KernelSU privilege
management, module mounting, SUSFS behaviour, Wi-Fi, cameras, mobile data,
fingerprint, encryption, and suspend require tests on the target phone.
No on-device validation has been performed by this change.

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
Revision 2 still requires device validation. If it fails, enter recovery
without booting Android repeatedly and collect all files from `/sys/fs/pstore`.
