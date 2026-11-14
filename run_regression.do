
transcript on
cd E:/ucie/RTL

# Rebuild the work library
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

set passed 0
set failed 0

# Compile RTL
set rtl_files {
    src/ucie_crc16_candidate.sv
    src/ucie_crc16_reference.sv
    src/ucie68_header_encoder.sv
    src/ucie68b_flit_tx.sv
    src/ucie68b_flit_rx.sv
    src/ucie_retry_controller.sv
    src/ucie_link_top.sv
}

set compile_failed 0
foreach file $rtl_files {
    puts "\nCOMPILE RTL: $file"
    if {[catch {vlog -sv $file} err]} {
        puts "FAIL: $file"
        puts $err
        set compile_failed 1
        break
    }
}

if {$compile_failed} {
    puts "\nRTL compilation failed. Regression stopped."
} else {
    set tests {
        tb_backpressure_test
        tb_crc_compare
        tb_crc_independent_vectors
        tb_crc_randomized
        tb_crc_randomized_independent
        tb_crc_validation
        tb_ucie68b_flit_rx_mapping
        tb_ucie68b_flit_tx_mapping
        tb_ucie68b_header_encoder
        tb_ucie68b_tx_rx_integration
        tb_ucie_crc16_candidate
        tb_ucie_link_top
        tb_ucie_retry_controller
    }

    foreach test $tests {
        puts "\n========================================"
        puts "TEST: $test"
        puts "========================================"

        if {[catch {vlog -sv "tb/$test.sv"} err]} {
            puts "COMPILE FAIL: $test"
            puts $err
            incr failed
            continue
        }

        if {[catch {vsim "work.$test"} err]} {
            puts "LOAD FAIL: $test"
            puts $err
            incr failed
            catch {quit -sim}
            continue
        }

        if {[catch {run -all} err]} {
            puts "SIMULATION FAIL: $test"
            puts $err
            incr failed
            catch {quit -sim}
            continue
        }

        # A simulation reaching $finish is not sufficient by itself.
        # Check the Transcript for $fatal/assertion failures as well.
        puts "REVIEW REQUIRED: $test"
        puts "Check the test's PASS message and Transcript for errors."
        catch {quit -sim}
    }
}

puts "\n========================================"
puts "REGRESSION SESSION FINISHED"
puts "Automatically verified passes: $passed"
puts "Compile/load/run errors: $failed"
puts "Tests marked for manual review are listed above."
puts "QuestaSim will remain open."