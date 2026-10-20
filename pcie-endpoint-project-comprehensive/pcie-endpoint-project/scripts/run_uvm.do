if {[file exists work]} {vdel -lib work -all}
vlib work
if {[catch {vlog -version}]} {
  echo "ERROR: vlog not found"
  quit -code 1
}
vlog -sv +acc -f sim/filelists/tb.f
set test pcie_config_reset_test
if {[info exists ::env(UVM_TESTNAME)]} {
  if {$::env(UVM_TESTNAME) ne ""} { set test $::env(UVM_TESTNAME) }
}
vsim -c work.tb_top +UVM_TESTNAME=$test -do "run -all; quit -f"
