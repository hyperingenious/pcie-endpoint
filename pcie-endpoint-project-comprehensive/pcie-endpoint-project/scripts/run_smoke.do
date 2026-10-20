if {[file exists work]} {vdel -lib work -all}
vlib work
vlog -sv tb/tests/smoke_tb.sv
vsim -c work.smoke_tb -do "run -all; quit -f"
