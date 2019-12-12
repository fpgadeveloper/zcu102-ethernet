#!/usr/bin/tclsh

# Description
# -----------
# This Tcl script will create an SDK workspace with software applications for each of the
# exported hardware designs in the ../Vivado directory.

# Echo server applications
# ------------------------
# This script will look into the ../Vivado directory and search for exported hardware designs 
# (.hdf files within Vivado projects). For each exported hardware design, the script will 
# generate the echo server software application.

# Set the Vivado directory containing the Vivado projects
set vivado_dir "../Vivado"
# Set the application postfix
set app_postfix "_echo_server"

# Returns true if str contains substr
proc str_contains {str substr} {
  if {[string first $substr $str] == -1} {
    return 0
  } else {
    return 1
  }
}

# Add a hardware design to the SDK workspace
proc add_hw_to_sdk {vivado_folder} {
  global vivado_dir
  set hdf_filename [lindex [glob -dir $vivado_dir/$vivado_folder/$vivado_folder.sdk *.hdf] 0]
  set hdf_filename_only [lindex [split $hdf_filename /] end]
  set top_module_name [lindex [split $hdf_filename_only .] 0]
  set hw_project_name ${top_module_name}_hw_platform_0
  # If the hw project does not already exist in the SDK workspace, then create it
  if {[file exists "$hw_project_name"] == 0} {
    createhw -name ${hw_project_name} -hwspec $hdf_filename
  }
  return $hw_project_name
}

# Get the first processor name from a hardware design
# We use the "getperipherals" command to get the name of the processor that
# in the design. Below is an example of the output of "getperipherals":
# ================================================================================
# 
#               IP INSTANCE   VERSION                   TYPE           IP TYPE
# ================================================================================
# 
#            axi_ethernet_0       7.0           axi_ethernet        PERIPHERAL
#       axi_ethernet_0_fifo       4.1          axi_fifo_mm_s        PERIPHERAL
#           gmii_to_rgmii_0       4.0          gmii_to_rgmii        PERIPHERAL
#      processing_system7_0       5.5     processing_system7
#          ps7_0_axi_periph       2.1       axi_interconnect               BUS
#              ref_clk_fsel       1.1             xlconstant        PERIPHERAL
#                ref_clk_oe       1.1             xlconstant        PERIPHERAL
#                 ps7_pmu_0    1.00.a                ps7_pmu        PERIPHERAL
#                ps7_qspi_0    1.00.a               ps7_qspi        PERIPHERAL
#         ps7_qspi_linear_0    1.00.a        ps7_qspi_linear      MEMORY_CNTLR
#    ps7_axi_interconnect_0    1.00.a   ps7_axi_interconnect               BUS
#            ps7_cortexa9_0       5.2           ps7_cortexa9         PROCESSOR
#            ps7_cortexa9_1       5.2           ps7_cortexa9         PROCESSOR
#                 ps7_ddr_0    1.00.a                ps7_ddr      MEMORY_CNTLR
#            ps7_ethernet_0    1.00.a           ps7_ethernet        PERIPHERAL
#            ps7_ethernet_1    1.00.a           ps7_ethernet        PERIPHERAL
#                 ps7_usb_0    1.00.a                ps7_usb        PERIPHERAL
#                  ps7_sd_0    1.00.a               ps7_sdio        PERIPHERAL
#                  ps7_sd_1    1.00.a               ps7_sdio        PERIPHERAL
proc get_processor_name {hw_project_name} {
  set periphs [getperipherals $hw_project_name]
  # For each line of the peripherals table
  foreach line [split $periphs "\n"] {
    set values [regexp -all -inline {\S+} $line]
    # If the last column is "PROCESSOR", then get the "IP INSTANCE" name (1st col)
    if {[lindex $values end] == "PROCESSOR"} {
      return [lindex $values 0]
    }
  }
  return ""
}

# Creates the .bif file for a Zynq board
proc create_zynq_bif {board_name app_name vivado_name target_dir sdk_dir} {
  set full_sdk_dir [file normalize $sdk_dir]
  set fsbl_elf_filename "${full_sdk_dir}/${board_name}_fsbl/Debug/${board_name}_fsbl.elf"
  set bitstream_filename "${full_sdk_dir}/${vivado_name}_wrapper_hw_platform_0/${vivado_name}_wrapper.bit"
  set app_elf_filename "${full_sdk_dir}/${app_name}/Debug/${app_name}.elf"
  # Swap forward slashes for back slashes on Windows systems
  set OS [lindex $::tcl_platform(os) 0]
  if { $OS == "Windows" } {
    regsub -all {/} $fsbl_elf_filename {\\} fsbl_elf_filename
    regsub -all {/} $bitstream_filename {\\} bitstream_filename
    regsub -all {/} $app_elf_filename {\\} app_elf_filename
  }
  set fd [open "${target_dir}/${board_name}.bif" "w"]
  puts $fd "//arch = zynq; split = false; format = BIN"
  puts $fd "the_ROM_image:"
  puts $fd "\{"
  puts $fd "	\[bootloader\]${fsbl_elf_filename}"
  puts $fd "	${bitstream_filename}"
  puts $fd "	${app_elf_filename}"
  puts $fd "\}"
  close $fd
}

# Creates the .bif file for a Zynq MP board
proc create_zynqmp_bif {board_name app_name vivado_name target_dir sdk_dir} {
  set full_sdk_dir [file normalize $sdk_dir]
  set fsbl_elf_filename "${full_sdk_dir}/${board_name}_fsbl/Debug/${board_name}_fsbl.elf"
  set bitstream_filename "${full_sdk_dir}/${vivado_name}_wrapper_hw_platform_0/${vivado_name}_wrapper.bit"
  set app_elf_filename "${full_sdk_dir}/${app_name}/Debug/${app_name}.elf"
  # Swap forward slashes for back slashes on Windows systems
  set OS [lindex $::tcl_platform(os) 0]
  if { $OS == "Windows" } {
    regsub -all {/} $fsbl_elf_filename {\\} fsbl_elf_filename
    regsub -all {/} $bitstream_filename {\\} bitstream_filename
    regsub -all {/} $app_elf_filename {\\} app_elf_filename
  }
  set fd [open "${target_dir}/${board_name}.bif" "w"]
  puts $fd "//arch = zynqmp; split = false; format = BIN"
  puts $fd "the_ROM_image:"
  puts $fd "\{"
  puts $fd "	\[fsbl_config\]a53_x64"
  puts $fd "	\[bootloader\]${fsbl_elf_filename}"
  puts $fd "	\[destination_device = pl\]${bitstream_filename}"
  puts $fd "	\[destination_cpu = a53-0\]${app_elf_filename}"
  puts $fd "\}"
  close $fd
}

# Returns list of Vivado projects in the given directory
proc get_vivado_projects {vivado_dir} {
  # Create the empty list
  set vivado_proj_list {}
  # Make a list of all subdirectories in Vivado directory
  foreach {vivado_proj_dir} [glob -type d "${vivado_dir}/*"] {
    # Get the vivado project name from the project directory name
    set vivado_proj [lindex [split $vivado_proj_dir /] end]
    # Ignore directories returned by glob that don't contain an underscore
    if { ([string first "_" $vivado_proj] == -1) } {
      continue
    }
    # Add the Vivado project to the list
    lappend vivado_proj_list $vivado_proj
  }
  return $vivado_proj_list
}

# Creates SDK workspace for a project
proc create_sdk_ws {} {
  global vivado_dir
  global app_postfix
  # First make sure there is at least one exported Vivado project
  set exported_projects 0
  # Get list of Vivado projects
  set vivado_proj_list [get_vivado_projects $vivado_dir]
  # Check each Vivado project for export files
  foreach {vivado_folder} $vivado_proj_list {
    # If the hardware has been exported for SDK
    if {[file exists "$vivado_dir/$vivado_folder/${vivado_folder}.sdk"] == 1} {
      set exported_projects [expr {$exported_projects+1}]
    }
  }
  
  # If no projects then exit
  if {$exported_projects == 0} {
    puts "### There are no exported Vivado projects in the $vivado_dir directory ###"
    puts "You must build and export a Vivado project before building the SDK workspace."
    exit
  }

  puts "There were $exported_projects exported project(s) found in the $vivado_dir directory."
  puts "Creating SDK workspace."
  
  # Set the workspace directory
  setws [pwd]
  
  # Add each Vivado project to SDK workspace
  foreach {vivado_folder} $vivado_proj_list {
    # Get the name of the board
    set board_name [string replace $vivado_folder [string last _ $vivado_folder end] end ""]
    # Create the application name
    set app_name "${board_name}$app_postfix"
    # If the application has already been created, then skip
    if {[file exists "$app_name"] == 1} {
      puts "Application already exists for Vivado project $vivado_folder."
    # If the hardware has been exported for SDK, then create an application for it
    } elseif {[file exists "$vivado_dir/$vivado_folder/${vivado_folder}.sdk"] == 1} {
      puts "Creating application for Vivado project $vivado_folder."
      set hw_project_name [add_hw_to_sdk $vivado_folder]
      set proc_instance [get_processor_name $hw_project_name]
      # Generate the echo server example application
      createapp -name $app_name \
        -app {lwIP Echo Server} \
        -proc $proc_instance \
        -hwproject ${hw_project_name} \
        -os standalone
      # Generate the FSBL for Zynq and Zynq MP designs
      # For Zynq MP designs
      if {[str_contains $proc_instance "psu_cortexa53_"]} {
        createapp -name ${board_name}_fsbl \
          -app {Zynq MP FSBL} \
          -proc $proc_instance \
          -hwproject ${hw_project_name} \
          -os standalone
	  # For Zynq designs
      } elseif {[str_contains $proc_instance "ps7_cortexa9_"]} {
        createapp -name ${board_name}_fsbl \
          -app {Zynq FSBL} \
          -proc $proc_instance \
          -hwproject ${hw_project_name} \
          -os standalone
      }
    } else {
      puts "Vivado project $vivado_folder not exported."
    }
  }
}
  
# Builds all applications
proc build_projects {} {
  # Set the workspace directory
  setws [pwd]
  # Build all
  puts "Building all applications."
  projects -build
}
  
# Creates boot files for all applications
proc create_boot_files {} {
  global vivado_dir
  global app_postfix
  # Set the workspace directory
  setws [pwd]
  
  # Create "boot" directory if it doesn't already exist
  if {[file exists "./boot"] == 0} {
    file mkdir "./boot"
  }
  
  # Get list of Vivado projects
  set vivado_proj_list [get_vivado_projects $vivado_dir]
  
  # Generate boot files for all projects
  foreach {vivado_folder} $vivado_proj_list {
    # Get the name of the board
    set board_name [string replace $vivado_folder [string last _ $vivado_folder end] end ""]
    # Create the application name
    set app_name "${board_name}$app_postfix"
    # Make sure the application has been compiled
    if {[file exists "./${app_name}/Debug/${app_name}.elf"] == 0} {
      puts "ELF does not exist for ${app_name}"
      continue
    }
	
    # Get the processor type
    set proc_instance [get_processor_name "${vivado_folder}_wrapper_hw_platform_0"]
    # For Zynq and Zynq MP designs, make sure that the FSBL exists
    if {[str_contains $proc_instance "microblaze_"] == 0} {
      if {[file exists "./${board_name}_fsbl/Debug/${board_name}_fsbl.elf"] == 0} {
        puts "ELF does not exist for ${board_name}_fsbl"
        continue
      }
    }
    
    # Don't generate boot files for Microblaze designs
    if {[str_contains $proc_instance "microblaze_"]} {
      continue
    }
    
    # If all required files exist, then generate boot files
    # Create directory for the boot file if it doesn't already exist
    if {[file exists "./boot/$board_name"] == 0} {
      file mkdir "./boot/$board_name"
    }
	
    # For Zynq MP designs
    if {[str_contains $proc_instance "psu_cortexa53_"]} {
      puts "Generating BOOT.bin file for Zynq MP $board_name project."
      # Generate the .bif file
      create_zynqmp_bif $board_name $app_name $vivado_folder "./boot" "."
      set bootgen_cmd "bootgen -image ./boot/${board_name}.bif -arch zynqmp -o ./boot/${board_name}/BOOT.bin -w on"
    # For Zynq designs
    } else {
      puts "Generating BOOT.bin file for Zynq $board_name project."
      # Generate the .bif file
      create_zynq_bif $board_name $app_name $vivado_folder "./boot" "."
      set bootgen_cmd "bootgen -image ./boot/${board_name}.bif -arch zynq -o ./boot/${board_name}/BOOT.bin -w on"
    }
    # Swap forward slashes for back slashes on Windows systems
    set OS [lindex $::tcl_platform(os) 0]
    if { $OS == "Windows" } {
      regsub -all {/} $bootgen_cmd {\\\\} bootgen_cmd
    }
    exec {*}$bootgen_cmd
  }
}

# Checks all applications
proc check_apps {} {
  global app_postfix
  # Set the workspace directory
  setws [pwd]
  puts "Checking build status of all applications:"
  # Get list of applications
  foreach {app_dir} [glob -type d "./*$app_postfix"] {
    # Get the app name
    set app_name [lindex [split $app_dir /] end]
	if {[file exists "$app_dir/Debug/${app_name}.elf"] == 1} {
      puts "  ${app_name} was built successfully"
	} else {
      puts "  ERROR: ${app_name} failed to build"
	}
  }
}
  

# Create the SDK workspace
puts "Creating the SDK workspace"
create_sdk_ws
build_projects
create_boot_files
check_apps


exit
