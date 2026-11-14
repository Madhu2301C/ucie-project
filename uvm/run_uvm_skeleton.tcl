vlib uvm_lib

# Compile UVM 1.1c into uvm_lib library with proper include paths
vlog -work uvm_lib -sv \
  +incdir+C:/questasim_10.4e/verilog_src/uvm-1.1c/src \
  +incdir+C:/questasim_10.4e/verilog_src/uvm-1.1c/src/base \
  +incdir+C:/questasim_10.4e/verilog_src/uvm-1.1c/src/dpi \
  +incdir+C:/questasim_10.4e/verilog_src/uvm-1.1c/src/dap \
  +incdir+C:/questasim_10.4e/verilog_src/uvm-1.1c/src/tlm1 \
  +incdir+C:/questasim_10.4e/verilog_src/uvm-1.1c/src/comps \
  +incdir+C:/questasim_10.4e/verilog_src/uvm-1.1c/src/seq \
  "C:/questasim_10.4e/verilog_src/uvm-1.1c/src/uvm_pkg.sv"

# Compile our UVM package into work library
vlog -work work -sv \
  +incdir+E:/ucie/RTL/uvm \
  +incdir+C:/questasim_10.4e/verilog_src/uvm-1.1c/src \
  "E:/ucie/RTL/uvm/ucie_pkg.sv"

# Compile top-level testbench into work library
vlog -work work -sv \
  +incdir+C:/questasim_10.4e/verilog_src/uvm-1.1c/src \
  "E:/ucie/RTL/uvm/tb_top.sv"

# Run with UVM library linked
vsim -c -L uvm_lib -L work tb_top
run -all
quit