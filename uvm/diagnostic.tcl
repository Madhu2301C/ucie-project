# ==========================================
# 1. PROJECT DIRECTORY
# ==========================================

cd E:/ucie/RTL/uvm

# ==========================================
# 2. CHECK QUestaSim VERSION
# ==========================================

version

# ==========================================
# 3. CHECK LIBRARY MAPPINGS
# ==========================================

vmap

# ==========================================
# 4. CHECK UVM LIBRARIES
# ==========================================

puts "\n========== UVM LIBRARY CHECK =========="

vmap uvm-1.1c
vmap uvm-1.2

# ==========================================
# 5. CHECK UVM SOURCE PATH
# ==========================================

puts "\n========== UVM SOURCE CHECK =========="

foreach path [list \
    "C:/questasim_10.4e/uvm-1.1c" \
    "C:/questasim_10.4e/uvm-1.1c/win32" \
    "C:/questasim_10.4e/uvm-1.1c/src" \
] {
    puts "Checking: $path"
    if {[file exists $path]} {
        puts "  EXISTS: $path"
        set contents [glob -nocomplain -tails -directory $path *]
        foreach item $contents {
            puts "    $item"
        }
    } else {
        puts "  NOT FOUND: $path"
    }
}

# ==========================================
# 6. CHECK UVM DPI LIBRARY
# ==========================================

puts "\n========== UVM DPI CHECK =========="

set dpi_lib "C:/questasim_10.4e/uvm-1.1c/win32/uvm_dpi.dll"
puts "Checking: $dpi_lib"
if {[file exists $dpi_lib]} {
    puts "  EXISTS: $dpi_lib"
} else {
    puts "  NOT FOUND: $dpi_lib"
}

# ==========================================
# 7. CHECK COMPILER AVAILABILITY
# ==========================================

puts "\n========== C/C++ COMPILER CHECK =========="

foreach cmd {gcc g++ cl} {
    puts "Checking for: $cmd"
    set result [catch {exec $cmd --version} output]
    if {$result == 0} {
        puts "  FOUND: $cmd"
        puts "  Output: [string trim $output]"
    } else {
        puts "  NOT FOUND: $cmd"
    }
}

# ==========================================
# 8. CHECK PROJECT FILES
# ==========================================

puts "\n========== PROJECT FILE CHECK =========="

foreach path [list \
    "common" \
    "tests" \
    "ucie_pkg.sv" \
    "tb_top.sv" \
] {
    puts "Checking: $path"
    if {[file exists $path]} {
        puts "  EXISTS: $path"
        if {[file isdirectory $path]} {
            set contents [glob -nocomplain -tails -directory $path *]
            foreach item $contents {
                puts "    $item"
            }
        }
    } else {
        puts "  NOT FOUND: $path"
    }
}

# ==========================================
# 9. CHECK EXISTING WORK LIBRARY
# ==========================================

puts "\n========== WORK LIBRARY CHECK =========="

vdir work

# ==========================================
# 10. END
# ==========================================

puts "\n========== DIAGNOSTIC COMPLETE =========="