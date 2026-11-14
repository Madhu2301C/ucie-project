onerror {quit -code 1}

if {[file exists work]} {vdel -lib work -all}
if {[file exists uvm_lib]} {vdel -lib uvm_lib -all}
vlib work
vlib uvm_lib
vmap work work
vmap uvm_lib uvm_lib

set UVM_SRC C:/questasim_10.4e/verilog_src/uvm-1.1c/src
set UVM_DPI C:/questasim_10.4e/uvm-1.1c/win32/uvm_dpi
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
  E:/ucie/RTL/src/ucie_retry_controller.sv

vlog -work work -sv -L uvm_lib \
  +incdir+$UVM_SRC \
  +incdir+$ROOT/common \
  +incdir+$ROOT/agents/retry \
  +incdir+$ROOT/env \
  +incdir+$ROOT/sequences \
  +incdir+$ROOT/tests \
  $ROOT/ucie_pkg.sv

vlog -work work -sv -L uvm_lib \
  +incdir+$UVM_SRC \
  $ROOT/tb_top.sv

file mkdir $ROOT/logs
set failures 0

# Expected scoreboard summaries for each directed scenario.
array set expected {
  TC01 {"Initial TX=1 Total handshakes=1 Replays=0" "ACK=1 NAK=0 Timeout=0" "Backpressure cycles=0 Simultaneous ACK/NAK=0"}
  TC02 {"Initial TX=1 Total handshakes=2 Replays=1" "ACK=1 NAK=1 Timeout=0" "Backpressure cycles=0 Simultaneous ACK/NAK=0"}
  TC03 {"Initial TX=1 Total handshakes=2 Replays=1" "ACK=1 NAK=0 Timeout=1" "Backpressure cycles=0 Simultaneous ACK/NAK=0"}
  TC04 {"Initial TX=1 Total handshakes=1 Replays=0" "ACK=1 NAK=1 Timeout=0" "Backpressure cycles=0 Simultaneous ACK/NAK=1"}
  TC05 {"Initial TX=1 Total handshakes=3 Replays=2" "ACK=1 NAK=2 Timeout=0" "Backpressure cycles=0 Simultaneous ACK/NAK=0"}
  TC06 {"Initial TX=1 Total handshakes=2 Replays=1" "ACK=1 NAK=1 Timeout=0" "Backpressure cycles=5 Simultaneous ACK/NAK=0"}
}

foreach tc {TC01 TC02 TC03 TC04 TC05 TC06} {
  puts "============================================================"
  puts "RUNNING $tc"
  puts "============================================================"
  set log_path "$ROOT/logs/$tc.log"
  transcript file $log_path
  vsim -L uvm_lib -sv_lib $UVM_DPI work.tb_top \
    +UCIE_TESTCASE=$tc +UVM_NO_RELNOTES
  onfinish stop
  run -all
  transcript off

  set fh [open $log_path r]
  set log_text [read $fh]
  close $fh
  set test_pass 1

  foreach required {
    {TEST_DONE}
    {UVM_ERROR\s*:\s*0}
    {UVM_FATAL\s*:\s*0}
  } {
    if {![regexp $required $log_text]} {
      puts "FAIL $tc: missing validation '$required'"
      set test_pass 0
    }
  }

  foreach summary $expected($tc) {
    if {![regexp -- $summary $log_text]} {
      puts "FAIL $tc: missing scoreboard result '$summary'"
      set test_pass 0
    }
  }

  if {$test_pass} {
    puts "PASS $tc"
  } else {
    incr failures
  }
  quit -sim
}

transcript file $ROOT/logs/run_all_console.log
if {$failures == 0} {
  puts "ALL_UCIE_TESTS_COMPLETED: PASS"
  quit -code 0
} else {
  puts "ALL_UCIE_TESTS_COMPLETED: FAILURES=$failures"
  quit -code 1
}
