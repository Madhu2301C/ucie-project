#!/bin/bash
# Run all 10 testbenches with Questasim, capture logs

set -e
VSIM="/c/questasim_10.4e/win32/vsim"
LOGDIR="$1"
REV=$(git rev-parse HEAD)
echo "Revision: $REV" > "$LOGDIR/run_info.txt"
echo "Patch: rx-five-files.patch" >> "$LOGDIR/run_info.txt"
echo "" >> "$LOGDIR/run_info.txt"

# Work directory for Questasim
WDIR="E:/ucie/RTL"

run_tb() {
    local name="$1"
    local top="$2"
    local extra_args="${3:-}"
    local log="$LOGDIR/${name}.log"
    echo "=== Running $name ==="
    set +e
    "$VSIM" -c -do "run -all; quit -f" "$extra_args" "$top" 2>&1 | tee "$log"
    local rc=${PIPESTATUS[0]}
    set -e
    if grep -qi "FAIL\|Error\|FATAL" "$log" 2>/dev/null; then
        echo "RESULT: FAIL" >> "$log"
    else
        echo "RESULT: PASS" >> "$log"
    fi
    echo "--- exit $rc ---"
}

cd "$WDIR"

# Compile the library once (all src files)
echo "Compiling library..."
"$VSIM" -c -do "quit -f" 2>/dev/null || true
"$VSIM" -c \
    -work work \
    -f mti_load \
    src/ucie_crc16_reference.sv \
    src/ucie_crc16_candidate.sv \
    src/ucie68_header_encoder.sv \
    src/ucie68b_flit_tx.sv \
    src/ucie68b_flit_rx.sv \
    src/ucie_retry_controller.sv \
    src/ucie_link_top.sv \
    2>&1 | tee "$LOGDIR/compile_lib.log"
echo "Library compile done"

# Run each testbench
run_tb "tb_crc_validation"        "tb_crc_validation"
run_tb "tb_crc_compare"            "tb_crc_compare"
run_tb "tb_crc_randomized"         "tb_crc_randomized"
run_tb "tb_ucie_crc16_candidate"   "tb_ucie_crc16_candidate"
run_tb "tb_ucie68b_header_encoder" "tb_ucie68b_header_encoder"
run_tb "tb_ucie68b_flit_tx_mapping" "tb_ucie68b_flit_tx_mapping"
run_tb "tb_ucie_link_top"          "tb_ucie_link_top"
run_tb "tb_backpressure_test"      "tb_backpressure_test"
run_tb "tb_ucie68b_flit_rx_mapping" "tb_ucie68b_flit_rx_mapping"
run_tb "tb_ucie68b_tx_rx_integration" "tb_ucie68b_tx_rx_integration"

echo "All done. Logs in $LOGDIR"
