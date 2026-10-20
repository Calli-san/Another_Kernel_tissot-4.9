# OC-Test1 — tissot / Rising Revived 6.2.1 Android 15

Experimental sibling of Beta 1 (r5). The daily-use beta source is preserved on
`beta/r5`; OC-Test is not a replacement for that validated baseline.

## Changes

- CPU target 2304 MHz (120 x the PLL's 19.2 MHz reference), approximately the
  requested 2.3 GHz. CPU PLL cap is 2304 MHz; its existing MX vote already
  covers 2400 MHz and is unchanged. No misleading 2300 MHz integer PLL entry.
- CPU OC plan targets the reference phone's observed speed bin 2, PVS 0.
  Other speed-bin plans are unchanged. Retain existing frequencies and add
  2150.4, 2208 and 2304 MHz, all voting the existing top CPR corner 7.
- Add 25000 uV to the bin-2 corner-7 open-loop and closed-loop voltage targets.
  This also affects its existing 2016 MHz OPP. The actual voltage is fuse,
  aging and CPR dependent and remains clamped: the existing 1065000 uV CPR
  ceiling and 1140000 uV physical supply limits are unchanged. This is an
  initial experimental margin, not a characterized safe voltage/frequency
  guarantee. No new CPR corners or fuse interpolation anchors are invented.
- The shared CPU PLL also raises CCI to 921.6 MHz at the new CPU maximum
  (CPU / 2.5); the bin-2 CCI voltage map is extended accordingly. Thus this
  experiment tests CPU and coupled interconnect stability together.
- GPU highest level changes from the source's 650 MHz to 680 MHz, driven by
  GPLL3 at 1360 MHz through its /2 output. Other GPU levels, bus votes, level
  indices, idle policy and firmware-managed TURBO voltage are unchanged.
  No GPU voltage increase is asserted or applied in this revision.
- Existing governor, thermal protection, suspend/fingerprint fixes,
  `lpm_levels.sleep_disabled=0`, KernelSU Next and SUSFS pins are retained.
  No clocks are locked at maximum and no thermal limits are bypassed.

Adding a frequency to the tables and compiling successfully does not prove
the reference phone can sustain it. Firmware/userspace thermal or power
policy can still cap the clock. Validate actual available/current frequencies,
time-in-state and performance on the phone; do not rely only on a displayed
maximum. Overclocking cannot remove RAM pressure or driver compatibility bugs.

## Files and installation

Extract the outer Actions artifact first. It contains:

1. `Another-Tissot-A15-Treble-Next-SUSFS-OC-Test1-CPU2304-GPU680.zip` — flash
   through recovery using the same active-slot procedure as r5. Keep the
   working r5 boot backup accessible before installing.
2. `Tissot-OC-Test1-Renderer-OpenGL.zip` — optional companion, install through
   KernelSU Next Manager and reboot. This is not a recovery/kernel ZIP.
3. Image, effective config, build provenance, checksums, this guide, collector.

The renderer module sets `debug.hwui.renderer=skiagl` through `system.prop`.
It needs no filesystem mount/metamodule, changes HWUI globally and does not
replace vendor libraries, disable Vulkan APIs or force a video decoder.
The owner confirmed normal Instagram video with this policy and
`Pipeline=Skia (OpenGL)`. It can also be installed on Beta 1 without OC.
Disable/remove the module and reboot to restore the ROM's renderer policy.
Flashing the r5 kernel alone does not uninstall a separately installed module.

Leave Developer options > Disable HW overlays OFF (normal default).
Do not layer a graphics driver module on top of this initial test.

## Initial checks

After reboot, run as root:

```sh
uname -r
cat /sys/module/lpm_levels/parameters/sleep_disabled
getprop debug.hwui.renderer
sh /sdcard/Download/collect-oc-test.sh > /sdcard/Download/oc-test-boot.txt 2>&1
```

Expected release contains `OC-Test1`; sleep_disabled is N. With the companion
installed, the property is skiagl. In CPU policy frequency tables look for
2304000 (kHz), and GPU tables for 680000000 (Hz). Current clocks may be lower
while idle or throttled; this is expected.

First verify boot/root/modules, touch, fingerprint, camera and suspend/resume.
Then compare the same short workload against Beta 1, one component at a time:
cap CPU to its old 2016000 kHz maximum while checking GPU, then cap GPU to
560000000 Hz (highest retained lower OPP) while checking CPU. Keep the same
renderer, brightness, battery/charging state and starting temperature.
Use available kernel-manager controls rather than forcing minimum clocks.
Only continue sustained load if these stages have no faults or restarts.
Capture the collector output after the workload and retain pstore if a reboot
occurs. Restore the saved r5 boot if OC causes boot failure, hangs, artifacts
or repeated restarts; do not try to compensate by disabling thermal controls.

## Build validation

CI builds the complete kernel and runs `scripts/check-oc-test.py` against the
compiled tissot DTB. It checks the final frequency/voltage maps, bin scope,
CCI ratio, GPU levels and PLL parent request. Source/DTB and shell checks
cannot establish electrical stability or acceptable temperatures on hardware.
