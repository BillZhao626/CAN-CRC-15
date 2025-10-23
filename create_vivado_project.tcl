################################################################################
# Vivado工程自动化创建脚本
# 功能：一键创建CAN CRC-15验证工程
# 使用方法：
#   1. 打开Vivado Tcl Shell
#   2. cd到本文件所在目录
#   3. 执行：source create_vivado_project.tcl
################################################################################

# 脚本版本
set script_version "1.0"
set project_name "can_crc15_project"

puts "================================================================================"
puts " CAN CRC-15 Vivado Project Creation Script v$script_version"
puts " Target: Xilinx Artix-7"
puts "================================================================================"
puts ""

################################################################################
## 1. 配置参数（可根据实际硬件修改）
################################################################################

# 目标芯片选择（根据实际开发板修改）
# 常见选项：
#   xc7a35tcsg324-2  - Artix-7 35T (Digilent Arty A7-35T)
#   xc7a100tcsg324-2 - Artix-7 100T (Digilent Arty A7-100T)
#   xc7a35ticsg324-1L - 工业级低功耗版本
set target_part "xc7a35tcsg324-2"

# 工程目录（相对于脚本位置）
set project_dir "./vivado_project"

# 源文件列表
set rtl_files [list \
    "can_crc15_core.v" \
]

set sim_files [list \
    "tb_can_crc15.v" \
]

set constraint_files [list \
    "crc15_constraints.xdc" \
]

# 顶层模块名称
set top_module "can_crc15_srl16e_optimized"

################################################################################
## 2. 创建工程
################################################################################

puts "Step 1: Creating Vivado project..."

# 检查工程是否已存在
if {[file exists $project_dir]} {
    puts "WARNING: Project directory already exists: $project_dir"
    puts "         Please remove it manually or choose a different name."
    puts "         Aborting..."
    return
}

# 创建工程
create_project $project_name $project_dir -part $target_part -force
puts "  ✓ Project created: $project_name"

# 设置目标语言
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

################################################################################
## 3. 添加源文件
################################################################################

puts ""
puts "Step 2: Adding source files..."

# 添加RTL设计文件
foreach rtl_file $rtl_files {
    if {[file exists $rtl_file]} {
        add_files -norecurse $rtl_file
        puts "  ✓ Added RTL file: $rtl_file"
    } else {
        puts "  ✗ WARNING: RTL file not found: $rtl_file"
    }
}

# 添加仿真文件
foreach sim_file $sim_files {
    if {[file exists $sim_file]} {
        add_files -fileset sim_1 -norecurse $sim_file
        puts "  ✓ Added simulation file: $sim_file"
    } else {
        puts "  ✗ WARNING: Simulation file not found: $sim_file"
    }
}

# 添加约束文件
foreach constraint_file $constraint_files {
    if {[file exists $constraint_file]} {
        add_files -fileset constrs_1 -norecurse $constraint_file
        puts "  ✓ Added constraint file: $constraint_file"
    } else {
        puts "  ✗ WARNING: Constraint file not found: $constraint_file"
    }
}

################################################################################
## 4. 设置顶层模块
################################################################################

puts ""
puts "Step 3: Configuring top module..."

set_property top $top_module [current_fileset]
set_property top tb_can_crc15 [get_filesets sim_1]
puts "  ✓ Design top module: $top_module"
puts "  ✓ Simulation top module: tb_can_crc15"

################################################################################
## 5. 配置综合策略（性能优先）
################################################################################

puts ""
puts "Step 4: Configuring synthesis strategy..."

# 使用高性能综合策略
set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
puts "  ✓ Synthesis strategy: Flow_PerfOptimized_high"

# 综合选项
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.KEEP_EQUIVALENT_REGISTERS true [get_runs synth_1]

################################################################################
## 6. 配置实现策略
################################################################################

puts ""
puts "Step 5: Configuring implementation strategy..."

# 使用高性能实现策略
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
puts "  ✓ Implementation strategy: Performance_ExplorePostRoutePhysOpt"

################################################################################
## 7. 创建运行脚本
################################################################################

puts ""
puts "Step 6: Creating helper scripts..."

# 创建综合脚本
set synth_script_file "$project_dir/run_synthesis.tcl"
set synth_script [open $synth_script_file w]
puts $synth_script "# Auto-generated synthesis script"
puts $synth_script "reset_run synth_1"
puts $synth_script "launch_runs synth_1 -jobs 4"
puts $synth_script "wait_on_run synth_1"
puts $synth_script "open_run synth_1 -name synth_1"
puts $synth_script "report_utilization -file \$project_dir/reports/utilization_synth.rpt"
puts $synth_script "report_timing_summary -file \$project_dir/reports/timing_synth.rpt"
puts $synth_script "puts \"Synthesis completed. Check reports in reports/ directory.\""
close $synth_script
puts "  ✓ Created script: run_synthesis.tcl"

# 创建实现脚本
set impl_script_file "$project_dir/run_implementation.tcl"
set impl_script [open $impl_script_file w]
puts $impl_script "# Auto-generated implementation script"
puts $impl_script "launch_runs impl_1 -jobs 4"
puts $impl_script "wait_on_run impl_1"
puts $impl_script "open_run impl_1"
puts $impl_script "report_utilization -file \$project_dir/reports/utilization_impl.rpt"
puts $impl_script "report_timing_summary -file \$project_dir/reports/timing_impl.rpt"
puts $impl_script "report_power -file \$project_dir/reports/power_impl.rpt"
puts $impl_script "puts \"Implementation completed. Check reports in reports/ directory.\""
close $impl_script
puts "  ✓ Created script: run_implementation.tcl"

# 创建报告目录
file mkdir "$project_dir/reports"

################################################################################
## 8. 完成信息
################################################################################

puts ""
puts "================================================================================"
puts " Project Creation Completed Successfully!"
puts "================================================================================"
puts ""
puts "Project Details:"
puts "  Name:        $project_name"
puts "  Location:    $project_dir"
puts "  Part:        $target_part"
puts "  Top Module:  $top_module"
puts ""
puts "Next Steps:"
puts "  1. Open project in Vivado GUI:"
puts "     >> open_project $project_dir/$project_name.xpr"
puts ""
puts "  2. Run synthesis:"
puts "     >> source $project_dir/run_synthesis.tcl"
puts "     Or in GUI: Flow Navigator → SYNTHESIS → Run Synthesis"
puts ""
puts "  3. Run simulation:"
puts "     >> launch_simulation"
puts "     Or in GUI: Flow Navigator → SIMULATION → Run Simulation"
puts ""
puts "  4. Check resource usage:"
puts "     >> open_run synth_1"
puts "     >> report_utilization -file utilization.rpt"
puts ""
puts "  5. Check timing:"
puts "     >> report_timing_summary -file timing.rpt"
puts ""
puts "Expected Results (SRL16E optimized version):"
puts "  - LUT:         ~32 (target ≤35)"
puts "  - Registers:   ~8  (target ≤15)"
puts "  - Max Freq:    ≥550 MHz (target ≥500 MHz)"
puts "  - SRL16E:      15 instances"
puts ""
puts "================================================================================"

# 保存工程
save_project_as $project_name $project_dir -force
puts ""
puts "Project saved. Ready to use!"

