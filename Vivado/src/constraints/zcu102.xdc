# SPI reference clock 156.25MHz
# IOSTANDARD for GT reference clock does not need to be specified
set_property PACKAGE_PIN C8 [get_ports {ref_clk_156mhz_clk_p}]
set_property PACKAGE_PIN C7 [get_ports {ref_clk_156mhz_clk_n}]
create_clock -period 6.400 -name ref_clk_156mhz_clk_p -waveform {0.000 3.200} [get_ports ref_clk_156mhz_clk_p]

# SFPx_TX_DISABLE_N pins
set_property PACKAGE_PIN A12 [get_ports {sfp0_tx_disable_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {sfp0_tx_disable_n}]
set_property PACKAGE_PIN A13 [get_ports {sfp1_tx_disable_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {sfp1_tx_disable_n}]
set_property PACKAGE_PIN B13 [get_ports {sfp2_tx_disable_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {sfp2_tx_disable_n}]
set_property PACKAGE_PIN C13 [get_ports {sfp3_tx_disable_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {sfp3_tx_disable_n}]

