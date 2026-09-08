if { $argc < 1 } {
    puts "ERROR: falta ruta del bitstream"
    exit 1
}

set bitfile [lindex $argv 0]

open_hw_manager
connect_hw_server
open_hw_target

set device [lindex [get_hw_devices] 0]
current_hw_device $device
refresh_hw_device -update_hw_probes false $device

set_property PROGRAM.FILE $bitfile $device
program_hw_devices $device
refresh_hw_device $device

close_hw_target
disconnect_hw_server
close_hw_manager

puts "Programacion completada: $bitfile"
exit