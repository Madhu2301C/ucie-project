onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TX-RX Integration Test}
add wave -noupdate /tb_ucie68b_tx_rx_integration/stack_id
add wave -noupdate /tb_ucie68b_tx_rx_integration/ack_nak_type
add wave -noupdate /tb_ucie68b_tx_rx_integration/sequence_num
add wave -noupdate /tb_ucie68b_tx_rx_integration/payload
add wave -noupdate /tb_ucie68b_tx_rx_integration/flit_out
add wave -noupdate /tb_ucie68b_tx_rx_integration/flit_in
add wave -noupdate /tb_ucie68b_tx_rx_integration/calculated_crc
add wave -noupdate /tb_ucie68b_tx_rx_integration/received_crc
add wave -noupdate /tb_ucie68b_tx_rx_integration/crc_error
add wave -noupdate /tb_ucie68b_tx_rx_integration/flit_valid
add wave -noupdate /tb_ucie68b_tx_rx_integration/payload_out
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {30000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 156
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {390600 ps} {415800 ps}
