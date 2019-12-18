################################################################
# Block diagram build script for Zynq MP designs
################################################################

# CHECKING IF PROJECT EXISTS
if { [get_projects -quiet] eq "" } {
   puts "ERROR: Please open or create a project!"
   return 1
}

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

create_bd_design $design_name

current_bd_design $design_name

set parentCell [get_bd_cells /]

# Get object for parentCell
set parentObj [get_bd_cells $parentCell]
if { $parentObj == "" } {
   puts "ERROR: Unable to find parent cell <$parentCell>!"
   return
}

# Make sure parentObj is hier blk
set parentType [get_property TYPE $parentObj]
if { $parentType ne "hier" } {
   puts "ERROR: Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."
   return
}

# Save current instance; Restore later
set oldCurInst [current_bd_instance .]

# Set parent object as current
current_bd_instance $parentObj

# Add the Processor System and apply board preset
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells zynq_ultra_ps_e_0]

# Enable GP0, HP0 and interrupts
set_property -dict [list CONFIG.PSU__USE__M_AXI_GP0 {1} \
CONFIG.PSU__USE__S_AXI_GP2 {1} \
CONFIG.PSU__FPGA_PL1_ENABLE {1} \
CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {50}] [get_bd_cells zynq_ultra_ps_e_0]

# Clock for HP0
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk]

# Add the MIG for the DDR4 DIMM
create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4 ddr4_0
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {ddr4_sdram ( DDR4 SDRAM ) } Manual_Source {Auto}}  [get_bd_intf_pins ddr4_0/C0_DDR4]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {/ddr4_0/c0_ddr4_ui_clk (333 MHz)} Clk_xbar {Auto} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD} Slave {/ddr4_0/C0_DDR4_S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {user_si570_sysclk ( User Programmable differential clock ) } Manual_Source {Auto}}  [get_bd_intf_pins ddr4_0/C0_SYS_CLK]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {reset ( FPGA Reset ) } Manual_Source {Auto}}  [get_bd_pins ddr4_0/sys_rst]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {/ddr4_0/c0_ddr4_ui_clk (300 MHz)} Clk_xbar {/ddr4_0/c0_ddr4_ui_clk (300 MHz)} Master {/zynq_ultra_ps_e_0/M_AXI_HPM1_FPD} Slave {/ddr4_0/C0_DDR4_S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM1_FPD]

# Add the AXI Ethernet Subsystem core
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_ethernet axi_ethernet_0

# Add the AXI DMA
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma axi_ethernet_0_dma

# Port 0 configuration
set_property -dict [list CONFIG.PHY_TYPE {1000BaseX} \
CONFIG.Frame_Filter {false} \
CONFIG.gtrefclkrate {156.25} \
CONFIG.RXMEM {32k} \
CONFIG.TXMEM {32k} \
CONFIG.TXCSUM {Full} \
CONFIG.RXCSUM {Full} \
CONFIG.gtlocation {X1Y12}] [get_bd_cells axi_ethernet_0]

# DMA configuration
set_property -dict [list CONFIG.c_sg_length_width {16} \
CONFIG.c_include_mm2s_dre {1} \
CONFIG.c_sg_use_stsapp_length {1} \
CONFIG.c_include_s2mm_dre {1}] [get_bd_cells axi_ethernet_0_dma]

# Clocks
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_ethernet_0/axis_clk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_ethernet_0/s_axi_lite_clk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk1] [get_bd_pins axi_ethernet_0/ref_clk]

# signal_detect tied HIGH
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant const_signal_detect
connect_bd_net [get_bd_pins const_signal_detect/dout] [get_bd_pins axi_ethernet_0/signal_detect]

# sfp_tx_disable_n tied HIGH
create_bd_port -dir O sfp0_tx_disable_n
create_bd_port -dir O sfp1_tx_disable_n
create_bd_port -dir O sfp2_tx_disable_n
create_bd_port -dir O sfp3_tx_disable_n
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant const_sfp_tx_disable_n
set_property -dict [list CONFIG.CONST_VAL {1}] [get_bd_cells const_sfp_tx_disable_n]
connect_bd_net [get_bd_pins const_sfp_tx_disable_n/dout] [get_bd_ports sfp0_tx_disable_n]
connect_bd_net [get_bd_pins const_sfp_tx_disable_n/dout] [get_bd_ports sfp1_tx_disable_n]
connect_bd_net [get_bd_pins const_sfp_tx_disable_n/dout] [get_bd_ports sfp2_tx_disable_n]
connect_bd_net [get_bd_pins const_sfp_tx_disable_n/dout] [get_bd_ports sfp3_tx_disable_n]

# Create SFP port
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:sfp_rtl:1.0 sfp_0
connect_bd_intf_net [get_bd_intf_pins axi_ethernet_0/sfp] [get_bd_intf_ports sfp_0]

# Create the ref clk 156.25MHz port
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 ref_clk_156mhz
set_property CONFIG.FREQ_HZ 156250000 [get_bd_intf_ports /ref_clk_156mhz]
connect_bd_intf_net [get_bd_intf_ports ref_clk_156mhz] [get_bd_intf_pins axi_ethernet_0/mgt_clk]

# PHY RESET for port 0 (not needed because SFP module doesn't have reset pin)
#create_bd_port -dir O reset_port_0_n
#connect_bd_net [get_bd_ports reset_port_0_n] [get_bd_pins axi_ethernet_0/phy_rst_n]

# MMCM locked to LED0
create_bd_port -dir O mmcm_locked_out_0
connect_bd_net [get_bd_pins axi_ethernet_0/mmcm_locked_out] [get_bd_ports mmcm_locked_out_0]

# DMA Connections
connect_bd_intf_net [get_bd_intf_pins axi_ethernet_0_dma/M_AXIS_MM2S] [get_bd_intf_pins axi_ethernet_0/s_axis_txd]
connect_bd_intf_net [get_bd_intf_pins axi_ethernet_0_dma/M_AXIS_CNTRL] [get_bd_intf_pins axi_ethernet_0/s_axis_txc]
connect_bd_intf_net [get_bd_intf_pins axi_ethernet_0/m_axis_rxd] [get_bd_intf_pins axi_ethernet_0_dma/S_AXIS_S2MM]
connect_bd_intf_net [get_bd_intf_pins axi_ethernet_0/m_axis_rxs] [get_bd_intf_pins axi_ethernet_0_dma/S_AXIS_STS]

connect_bd_net [get_bd_pins axi_ethernet_0_dma/mm2s_prmry_reset_out_n] [get_bd_pins axi_ethernet_0/axi_txd_arstn]
connect_bd_net [get_bd_pins axi_ethernet_0_dma/mm2s_cntrl_reset_out_n] [get_bd_pins axi_ethernet_0/axi_txc_arstn]
connect_bd_net [get_bd_pins axi_ethernet_0_dma/s2mm_prmry_reset_out_n] [get_bd_pins axi_ethernet_0/axi_rxd_arstn]
connect_bd_net [get_bd_pins axi_ethernet_0_dma/s2mm_sts_reset_out_n] [get_bd_pins axi_ethernet_0/axi_rxs_arstn]

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_ethernet_0_dma/m_axi_sg_aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_ethernet_0_dma/m_axi_mm2s_aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_ethernet_0_dma/m_axi_s2mm_aclk]

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_ethernet_0_dma/s_axi_lite_aclk]

# Concats for the interrupts
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat xlconcat_0
set_property -dict [list CONFIG.NUM_PORTS {4}] [get_bd_cells xlconcat_0]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

connect_bd_net [get_bd_pins axi_ethernet_0/mac_irq] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins axi_ethernet_0/interrupt] [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins axi_ethernet_0_dma/mm2s_introut] [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins axi_ethernet_0_dma/s2mm_introut] [get_bd_pins xlconcat_0/In3]

# Automation for the S_AXI interfaces of the AXI Ethernet ports
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Clk_slave {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Clk_xbar {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD} Slave {/axi_ethernet_0/s_axi} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_ethernet_0/s_axi]
set_property range 256K [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_axi_ethernet_0_Reg0}]

# Automation for the S_AXI interfaces of the AXI DMAs
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/ddr4_0/c0_ddr4_ui_clk (300 MHz)} Clk_slave {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Clk_xbar {/ddr4_0/c0_ddr4_ui_clk (300 MHz)} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD} Slave {/axi_ethernet_0_dma/S_AXI_LITE} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_ethernet_0_dma/S_AXI_LITE]

# Automation for the M_AXI interfaces of the AXI DMAs
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Clk_slave {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Clk_xbar {Auto} Master {/axi_ethernet_0_dma/M_AXI_SG} Slave {/zynq_ultra_ps_e_0/S_AXI_HP0_FPD} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Clk_slave {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Clk_xbar {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Master {/axi_ethernet_0_dma/M_AXI_MM2S} Slave {/zynq_ultra_ps_e_0/S_AXI_HP0_FPD} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_ethernet_0_dma/M_AXI_MM2S]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Clk_slave {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Clk_xbar {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Master {/axi_ethernet_0_dma/M_AXI_S2MM} Slave {/zynq_ultra_ps_e_0/S_AXI_HP0_FPD} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_ethernet_0_dma/M_AXI_S2MM]


# Restore current instance
current_bd_instance $oldCurInst

save_bd_design
