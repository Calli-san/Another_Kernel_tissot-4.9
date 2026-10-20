# AnyKernel3 installer for the tissot Next/SUSFS OC-Test build.
properties() { '
kernel.string=Another Next SUSFS OC-Test1 - CPU2304 GPU680 - tissot A15 Treble
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=tissot
supported.versions=15
supported.patchlevels=
'; }

block=/dev/block/platform/soc/7824900.sdhci/by-name/boot;
is_slot_device=1;
ramdisk_compression=auto;

. tools/ak3-core.sh;

# Restore Magisk's saved original ramdisk in the working copy before AK3
# extracts it. Otherwise AK3 preserves Magisk and hex-patches the new kernel
# to force its initramfs, defeating a clean KernelSU boot test.
split_boot;
cd "$split_img" || abort "Cannot access split boot image";
"$bin/magiskboot" cpio ramdisk.cpio test;
ramdisk_status=$?;
case $((ramdisk_status & 3)) in
  0) ;;
  1)
    ui_print "Restoring original ramdisk from Magisk backup for KernelSU...";
    "$bin/magiskboot" cpio ramdisk.cpio "restore" || abort "Magisk ramdisk restore failed";
    "$bin/magiskboot" cpio ramdisk.cpio test;
    [ $? -eq 0 ] || abort "Ramdisk is still patched; refusing mixed-root installation";
    ;;
  *) abort "Unsupported ramdisk; restore a clean boot image first" ;;
esac;
cd "$home" || abort "Cannot access installer directory";
unpack_ramdisk;

# Preserve the ownership, modes and symlinks extracted from the original CPIO.
# There are no added ramdisk files requiring permission changes.
# Persist the runtime-tested CPU idle setting in the repacked boot command line.
# Keep the module parameter writable for troubleshooting after installation.
patch_cmdline "lpm_levels.sleep_disabled" "lpm_levels.sleep_disabled=0";
write_boot;
ui_print "OpenGL workaround: install the companion Renderer-OpenGL ZIP in KernelSU.";
ui_print "OC-Test1 installed. CPU target 2304 MHz; GPU target 680 MHz.";

