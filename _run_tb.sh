#!/bin/bash
WDIR="E:/ucie/RTL"
LOGDIR="E:/ucie/RTL/patch_validation_20261018_144704"
VSIM="/c/questasim_10.4e/win32/vsim"
VLOG="/c/questasim_10.4e/win32/vlog"

run_one() {
    local name="$1"
    local top="$2"
    local srcs="$3"
    local log="$LOGDIR/${name}.log"

    echo "=== $name ==="
    # compile testbench + its deps
    "$VLOG" -work work -sv $srcs 2>&1 | tee "$LOGDIR/_compile_${name}.log"
    # run
    "$VSIM" -c -do "run -all; quit -f" "$top" 2>&1 | tee "$log"
}

cd "$WDIR"

# 1
run_one "tb_crc_validation" "tb_crc_validation" \
  "tb/tb_crc_validation.sv src/ucie_crc16_candidate.sv"

# 2
run_one "tb_crc_compare" "tb_crc_compare" \
  "tb/tb_crc_compare.sv src/ucie_crc16_candidate.sv src/ucie_crc16_reference.sv"

# 3
run_one "tb_crc_randomized" "tb_crc_randomized" \
  "tb/tb_crc_randomized.sv src/ucie_crc16_candidate.sv src/ucie_crc16_reference.sv"

# 4
run_one "tb_ucie_crc16_candidate" "tb_ucie_crc16_candidate" \
  "tb/tb_ucie_crc16_candidate.sv src/ucie_crc16_candidate.sv"

# 5
run_one "tb_ucie68b_header_encoder" "tb_ucie68b_header_encoder" \
  "tb/tb_ucie68b_header_encoder.sv src/ucie68_header_encoder.sv"

# 6
run_one "tb_ucie68b_flit_tx_mapping" "tb_ucie68b_flit_tx_mapping" \
  "tb/tb_ucie68b_flit_tx_mapping.sv src/ucie68b_flit_tx.sv src/ucie68_header_encoder.sv src/ucie_crc16_candidate.sv"

# 7
run_one "tb_ucie_link_top" "tb_ucie_link_top" \
  "tb/tb_ucie_link_top.sv src/ucie68b_flit_tx.sv src/ucie68b_flit_rx.sv src/ucie68_header_encoder.sv src/ucie_crc16_candidate.sv src/ucie_retry_controller.sv src/ucie_link_top.sv"

# 8
run_one "tb_backpressure_test" "tb_backpressure_test" \
  "tb/tb_backpressure_test.sv src/ucie68b_flit_tx.sv src/ucie68b_flit_rx.sv src/ucie68_header_encoder.sv src/ucie_crc16_candidate.sv src/ucie_retry_controller.sv src/ucie_link_top.sv"

# 9
run_one "tb_ucie68b_flit_rx_mapping" "tb_ucie68b_flit_rx_mapping" \
  "tb/tb_ucie68b_flit_rx_mapping.sv src/ucie68b_flit_rx.sv src/ucie_crc16_reference.sv"

# 10
run_one "tb_ucie68b_tx_rx_integration" "tb_ucie68b_tx_rx_integration" \
  "tb/tb_ucie68b_tx_rx_integration.sv src/ucie68b_flit_tx.sv src/ucie68b_flit_rx.sv src/ucie_crc16_candidate.sv"

echo "ALL DONE"
