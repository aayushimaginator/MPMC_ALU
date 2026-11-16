# Usage (from this folder):  vivado -mode batch -source build_alu16.tcl
set part xc7s50csga324-2
set top  alu16_top

file mkdir reports
if {[file exists vivado_alu16]} {
    file delete -force vivado_alu16
}

create_project alu16 ./vivado_alu16 -part $part -force
set_property target_language Verilog [current_project]

add_files alu16.v
add_files btn_cond.v
add_files seg7_driver.v
add_files alu16_top.v
add_files -fileset constrs_1 alu16_urbana.xdc

set_property top $top [current_fileset]
update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed"
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation failed"
}

open_run impl_1
report_utilization    -file reports/alu16_utilization.rpt
report_timing_summary -file reports/alu16_timing_summary.rpt

puts "Bitstream: vivado_alu16/alu16.runs/impl_1/alu16_top.bit"
puts "Program:   vivado -mode batch -source program.tcl -tclargs vivado_alu16/alu16.runs/impl_1/alu16_top.bit"
