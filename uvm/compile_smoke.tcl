onerror {quit -code 1}

if {[file exists work]} {vdel -lib work -all}
if {[file exists uvm_lib]} {vdel -lib uvm_lib -all}
vlib work
vlib uvm_lib
vmap work work
vmap uvm_lib uvm_lib

set UVM_SRC C:/questasim_10.4e/verilog_src/uvm-1.1c/src
set ROOT E:/ucie/RTL/UVM

vlog -work uvm_lib -sv \
  +incdir+$UVM_SRC \
  +incdir+$UVM_SRC/base \
  +incdir+$UVM_SRC/dpi \
  +incdir+$UVM_SRC/dap \
  +incdir+$UVM_SRC/tlm1 \
  +incdir+$UVM_SRC/comps \
  +incdir+$UVM_SRC/seq \
  $UVM_SRC/uvm_pkg.sv

vlog -work work -sv -L uvm_lib \
  $ROOT/interfaces/ucie_retry_if.sv \
  $ROOT/interfaces/ucie_link_if.sv \
  E:/ucie/RTL/src/ucie_crc16_candidate.sv \
  E:/ucie/RTL/src/ucie68_header_encoder.sv \
  E:/ucie/RTL/src/ucie68b_flit_tx.sv \
  E:/ucie/RTL/src/ucie68b_flit_rx.sv \
  E:/ucie/RTL/src/ucie_retry_controller.sv \
  E:/ucie/RTL/src/ucie_link_top.sv

vlog -work work -sv -L uvm_lib \
  +incdir+$UVM_SRC \
  +incdir+$ROOT/common \
  +incdir+$ROOT/agents/retry \
  +incdir+$ROOT/agents/link \
  +incdir+$ROOT/env \
  +incdir+$ROOT/sequences \
  +incdir+$ROOT/tests \
  $ROOT/ucie_pkg.sv

vlog -work work -sv -L uvm_lib \
  +incdir+$UVM_SRC \
  $ROOT/tb_top.sv

puts "COMPILE_SMOKE_PASS"
quit -code 0
