#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
readonly AK3_COMMIT=4d2299424aff352dae279c4b3e04d2822967f2df
image=${1:-artifacts/Image.gz-dtb}
test -s "$image"
image=$(realpath "$image")
mkdir -p artifacts
destination=$(realpath artifacts)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git init -q "$work/ak3"
git -C "$work/ak3" remote add origin https://github.com/sirnewbies/Anykernel3.git
git -C "$work/ak3" fetch --depth 1 origin "$AK3_COMMIT"
git -C "$work/ak3" checkout --detach FETCH_HEAD
# Use only the image installer; do not ship unrelated patches or ramdisk files.
rm -rf "$work/ak3/.git" "$work/ak3/modules" "$work/ak3/patch" "$work/ak3/ramdisk"
cp "$image" "$work/ak3/Image.gz-dtb"
cp packaging/tissot/anykernel.sh "$work/ak3/anykernel.sh"
cp artifacts/build-info.txt "$work/ak3/build-info.txt"
zipname=Another-Tissot-A15-Treble-Next-SUSFS-r4-EXPERIMENTAL.zip
(cd "$work/ak3" && zip -qr9 "$destination/$zipname" .)
unzip -tq "$destination/$zipname"
(cd "$destination" && sha256sum "$zipname" >> SHA256SUMS)
echo "Created artifacts/$zipname (not tested on device)."
