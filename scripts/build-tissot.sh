#!/usr/bin/env bash
# Non-GKI build with pinned inputs and no external uploads.
set -euo pipefail
cd "$(dirname "$0")/.."
readonly KSU_COMMIT=d999a2aff11575c6e2f520129ecffb7c6058fb02
OUT_DIR=${OUT_DIR:-out}
JOBS=${JOBS:-$(nproc)}
export ARCH=arm64
export CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
export CROSS_COMPILE_ARM32=${CROSS_COMPILE_ARM32:-arm-linux-gnueabi-}
if [[ ! -f KernelSU/kernel/Kconfig ]]; then
    git submodule update --init KernelSU
fi
[[ $(git -C KernelSU rev-parse HEAD) == "$KSU_COMMIT" ]] || {
    echo 'Unexpected KernelSU revision; run git submodule update --init KernelSU.' >&2
    exit 1
}
for patchfile in patches/ksunext/*.patch; do
    [[ -f "$patchfile" ]] || continue
    if git -C KernelSU apply --check "../$patchfile"; then
        git -C KernelSU apply "../$patchfile"
    elif ! git -C KernelSU apply --reverse --check "../$patchfile"; then
        echo "Cannot apply $patchfile" >&2
        exit 1
    fi
done
make O="$OUT_DIR" HOSTCFLAGS='-O2 -fcommon' tissot_defconfig
for symbol in KSU KSU_MANUAL_HOOK KSU_SUSFS THREAD_INFO_IN_TASK; do
    grep -qx "CONFIG_${symbol}=y" "$OUT_DIR/.config" || {
        echo "Missing required CONFIG_${symbol}=y" >&2
        exit 1
    }
done
for symbol in INITRAMFS_IGNORE_SKIP_FLAG PROC_CMDLINE_APPEND_ANDROID_FORCE_NORMAL_BOOT PSTORE_LZ4_COMPRESS; do
    grep -qx "# CONFIG_${symbol} is not set" "$OUT_DIR/.config" || {
        echo "Unexpected CONFIG_${symbol}; A15 Treble reference has it disabled." >&2
        exit 1
    }
done
grep -qx 'CONFIG_PSTORE_ZLIB_COMPRESS=y' "$OUT_DIR/.config"
make -j"$JOBS" O="$OUT_DIR" HOSTCFLAGS='-O2 -fcommon' Image.gz-dtb
test -s "$OUT_DIR/arch/arm64/boot/Image.gz-dtb"
mkdir -p artifacts
cp "$OUT_DIR/arch/arm64/boot/Image.gz-dtb" artifacts/
cp "$OUT_DIR/.config" artifacts/kernel.config
{
    echo "kernel_commit=$(git rev-parse HEAD)"
    echo "ksunext_commit=$KSU_COMMIT"
    echo "ksunext_tag=$(git -C KernelSU describe --tags --abbrev=0)"
    echo 'susfs_source=https://github.com/wxx9248/susfs4ksu'
    echo 'susfs_commit=71345ded5af28f55d76ebcdc7a9df9cea56111e1'
    "${CROSS_COMPILE}gcc" --version | head -n1
    echo 'device=tissot; target=Android 15 Treble; on_device_test=not_performed'
} > artifacts/build-info.txt
(cd artifacts && sha256sum Image.gz-dtb > SHA256SUMS)
echo 'Build complete. Boot/root/SUSFS behaviour still requires device testing.'
