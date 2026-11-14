vlib work
vlog -work work "E:/ucie/RTL/src/ucie68b_flit_rx.sv"
vlog -work work "E:/ucie/RTL/src/ucie68b_flit_tx.sv"
vlog -work work "E:/ucie/RTL/src/ucie68_header_encoder.sv"
vlog -work work "E:/ucie/RTL/src/ucie_crc16_candidate.sv"
vlog -work work "E:/ucie/RTL/src/ucie_crc16_reference.sv"
vlog -work work "E:/ucie/RTL/src/ucie_link_top.sv"
vlog -work work "E:/ucie/RTL/src/ucie_retry_controller.sv"
vlog -work work "E:/ucie/RTL/tb/tb_ucie_link_top.sv"

vsim -c tb_ucie_link_top
run -all
quit