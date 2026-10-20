#!/system/bin/sh
# Read-only snapshot; run as root with: sh collect-oc-test.sh > /sdcard/Download/oc-test.txt 2>&1
date
uname -a
echo '=== BOOT AND RENDERER ==='
cat /sys/module/lpm_levels/parameters/sleep_disabled
getprop debug.hwui.renderer
echo '=== CPU POLICIES ==='
for p in /sys/devices/system/cpu/cpufreq/policy*; do
  [ -d "$p" ] || continue
  echo "$p"
  for f in scaling_available_frequencies cpuinfo_max_freq scaling_max_freq scaling_min_freq scaling_cur_freq scaling_governor stats/time_in_state; do
    echo "$f"
    cat "$p/$f" 2>/dev/null
  done
done
echo '=== GPU ==='
for f in gpu_available_frequencies gpuclk max_gpuclk gpubusy thermal_pwrlevel devfreq/available_frequencies devfreq/max_freq devfreq/cur_freq; do
  echo "$f"
  cat "/sys/class/kgsl/kgsl-3d0/$f" 2>/dev/null
done
echo '=== THERMAL ZONES ==='
for z in /sys/class/thermal/thermal_zone*; do
  [ -d "$z" ] || continue
  echo "$z"
  cat "$z/type" "$z/temp" 2>/dev/null
done
echo '=== RELEVANT DMESG ==='
dmesg | grep -iE 'Speed bin|PVS|cpr4|clock_cpu|OPP voltage|clock-cpu|gpu fault|GPU hang|panic|thermal|regulator.*fail' | tail -n 140
