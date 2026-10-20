#!/system/bin/sh
[ "$KSU" = true ] || abort "Install this companion module using KernelSU Next."
ui_print "Tissot OC-Test HWUI OpenGL workaround"
ui_print "Applies globally at next boot; no CPU/GPU clocks are changed by this module."
ui_print "To undo: disable/remove this module and reboot."
set_perm_recursive "$MODPATH" 0 0 0755 0644
