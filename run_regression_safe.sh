
#!/bin/bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

VLOG="/c/questasim_10.4e/win32/vlog"
VSIM="/c/questasim_10.4e/win32/vsim"

LOGDIR="${1:-logs/regression_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$LOGDIR"

if [[ ! -x "$VLOG" || ! -x "$VSIM" ]]; then
    echo "ERROR: Questa vlog/vsim not found at the configured paths."
    echo "Check the Questa installation path before running."
    exit 1
fi

if [[ ! -d work ]]; then
    vlib work || exit 1
fi

echo "Revision: $(git rev-parse HEAD 2>/dev/null || echo unknown)" \
    > "$LOGDIR/run_info.txt"
echo "Started: $(date)" >> "$LOGDIR/run_info.txt"

RTL=(
    src/ucie_crc16_reference.sv
    src/ucie_crc16_candidate.sv
    src/ucie68_header_encoder.sv
    src/ucie68b_flit_tx.sv
    src/ucie68b_flit_rx.sv
    src/ucie_retry_controller.sv
    src/ucie_link_top.sv
)

TBS=(
    tb/tb_crc_validation.sv
    tb/tb_crc_compare.sv
    tb/tb_crc_randomized.sv
    tb/tb_crc_independent_vectors.sv
    tb/tb_crc_randomized_independent.sv
    tb/tb_ucie_crc16_candidate.sv
    tb/tb_ucie68b_header_encoder.sv
    tb/tb_ucie68b_flit_tx_mapping.sv
    tb/tb_ucie_link_top.sv
    tb/tb_backpressure_test.sv
    tb/tb_ucie68b_flit_rx_mapping.sv
    tb/tb_ucie68b_tx_rx_integration.sv
    tb/tb_ucie_retry_controller.sv
)

echo "Compiling RTL and testbenches..."
if "$VLOG" -sv -work work "${RTL[@]}" "${TBS[@]}" \
    2>&1 | tee "$LOGDIR/compile.log"; then
    echo "Compilation command completed."
else
    echo "FAIL: Compilation failed. See $LOGDIR/compile.log"
    exit 1
fi

# A zero exit code alone is not sufficient if compilation reported errors.
if grep -Eiq '(^|[[:space:]])(Error|Fatal)(:|[[:space:]]|$)' \
    "$LOGDIR/compile.log"; then
    echo "FAIL: Compilation log contains errors."
    exit 1
fi

run_tb() {
    local top="$1"
    local log="$LOGDIR/${top}.log"
    local rc=0

    echo "=== Running $top ==="

    if "$VSIM" -c -lib work "$top" \
        -do "run -all; quit -f" 2>&1 | tee "$log"; then
        rc=0
    else
        rc=$?
    fi

    if [[ $rc -ne 0 ]] ||
       grep -Eiq '(^|[[:space:]])(FAIL|Error|Fatal)(:|[[:space:]]|$)' "$log"; then
        echo "FAIL: $top (exit $rc)" | tee -a "$LOGDIR/summary.txt"
        return 1
    fi

    echo "PASS: $top" | tee -a "$LOGDIR/summary.txt"
    return 0
}

: > "$LOGDIR/summary.txt"
failures=0

for tb in \
    tb_crc_validation \
    tb_crc_compare \
    tb_crc_randomized \
    tb_crc_independent_vectors \
    tb_crc_randomized_independent \
    tb_ucie_crc16_candidate \
    tb_ucie68b_header_encoder \
    tb_ucie68b_flit_tx_mapping \
    tb_ucie_link_top \
    tb_backpressure_test \
    tb_ucie68b_flit_rx_mapping \
    tb_ucie68b_tx_rx_integration \
    tb_ucie_retry_controller
do
    run_tb "$tb" || failures=$((failures + 1))
done

echo
echo "Regression complete. Failures: $failures"
echo "Logs: $LOGDIR"
echo "Finished: $(date)" >> "$LOGDIR/run_info.txt"

[[ $failures -eq 0 ]]
