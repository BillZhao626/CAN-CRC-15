################################################################################
## Xilinx Design Constraints (XDC) File
## CAN CRC-15 Hardware Accelerator
## Target: Artix-7 (xc7a35t/xc7a100t)
## Purpose: 综合/实现约束（时钟、I/O、优化策略）
################################################################################

################################################################################
## 1. 时钟约束（500MHz系统时钟）
################################################################################
# 创建主时钟（假设时钟引脚为clk）
# 注意：实际使用时需根据开发板修改引脚位置
create_clock -period 2.000 -name sys_clk [get_ports clk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk]

# 时钟不确定性（考虑时钟抖动和偏斜）
set_clock_uncertainty 0.100 [get_clocks sys_clk]

# 时钟延迟建模
set_input_delay -clock sys_clk -min 0.000 [get_ports clk]
set_input_delay -clock sys_clk -max 0.500 [get_ports clk]

################################################################################
## 2. 输入延迟约束
################################################################################
# 数据输入信号（假设来自CAN控制器，外部时序已同步）
set_input_delay -clock sys_clk -min 0.300 [get_ports data_in]
set_input_delay -clock sys_clk -max 0.800 [get_ports data_in]

set_input_delay -clock sys_clk -min 0.300 [get_ports data_valid]
set_input_delay -clock sys_clk -max 0.800 [get_ports data_valid]

set_input_delay -clock sys_clk -min 0.300 [get_ports is_stuffed]
set_input_delay -clock sys_clk -max 0.800 [get_ports is_stuffed]

set_input_delay -clock sys_clk -min 0.300 [get_ports crc_enable]
set_input_delay -clock sys_clk -max 0.800 [get_ports crc_enable]

set_input_delay -clock sys_clk -min 0.300 [get_ports crc_init]
set_input_delay -clock sys_clk -max 0.800 [get_ports crc_init]

################################################################################
## 3. 输出延迟约束
################################################################################
# CRC输出信号（假设连接到后级逻辑，留有0.5ns余量）
set_output_delay -clock sys_clk -min -0.200 [get_ports crc_out*]
set_output_delay -clock sys_clk -max 0.500 [get_ports crc_out*]

set_output_delay -clock sys_clk -min -0.200 [get_ports crc_out_rev*]
set_output_delay -clock sys_clk -max 0.500 [get_ports crc_out_rev*]

################################################################################
## 4. 复位约束（异步复位路径）
################################################################################
# 复位信号不受时序约束（异步复位设计）
set_false_path -from [get_ports rst_n]

# 复位后的恢复时间约束（确保可靠退出复位）
set_max_delay 5.000 -from [get_ports rst_n] -to [all_registers]

################################################################################
## 5. SRL16E优化约束（关键！）
################################################################################
# 注意：约束文件不支持针对不存在的单元设置属性
# SRL16E相关约束应在综合时通过set_property参数设置

################################################################################
## 6. 综合优化策略
################################################################################
# 注意：以下属性应在TCL脚本中通过synth_design参数设置
# 不应在XDC约束文件中设置

# 保持层级边界（便于调试，可选）
# set_property KEEP_HIERARCHY TRUE [get_cells u_srl16e_optimized]

################################################################################
## 7. 实现策略约束
################################################################################
# 布局策略：紧密布局（减少布线延迟）
# set_property LOC SLICE_X20Y50 [get_cells -hierarchical u_crc15]  # 根据实际调整

# 关键路径优化（反馈路径）
# 注意：如果设计中没有SRL16E，此约束会被忽略
# set_max_delay 1.800 -from [get_pins -filter {REF_PIN_NAME == Q} -of [get_cells -hierarchical -filter {REF_NAME == SRL16E}]] \
#                      -to [get_pins -filter {REF_PIN_NAME == D} -of [get_cells -hierarchical -filter {REF_NAME == SRL16E}]]

# 多周期路径约束（如果CRC计算允许2周期延迟，可选）
# set_multicycle_path 2 -setup -from [get_cells crc_reg*] -to [get_cells crc_reg*]
# set_multicycle_path 1 -hold -from [get_cells crc_reg*] -to [get_cells crc_reg*]

################################################################################
## 8. I/O约束（示例 - 根据实际开发板修改）
################################################################################
# 以下为Artix-7开发板示例引脚（需根据实际硬件修改）

# 时钟输入（假设使用100MHz晶振，需要PLL倍频到500MHz）
# set_property PACKAGE_PIN E3 [get_ports clk]
# set_property IOSTANDARD LVCMOS33 [get_ports clk]

# 复位按钮（低有效）
# set_property PACKAGE_PIN C2 [get_ports rst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# 数据输入（来自CAN收发器）
# set_property PACKAGE_PIN A8 [get_ports data_in]
# set_property IOSTANDARD LVCMOS33 [get_ports data_in]

# CRC输出（连接到LED或后级逻辑）
# set_property PACKAGE_PIN H5 [get_ports {crc_out_rev[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {crc_out_rev[0]}]
# ... (其他CRC输出位)

################################################################################
## 9. 调试约束（ILA抓取）
################################################################################
# 如果添加了ILA，防止ILA影响时序
# set_false_path -from [get_cells -hierarchical -filter {NAME =~ *ila*}]
# set_false_path -to [get_cells -hierarchical -filter {NAME =~ *ila*}]

################################################################################
## 10. 电源分析约束（可选）
################################################################################
# 设置开关活动率（用于功耗估算）
# set_switching_activity -default_toggle_rate 12.5  # 假设数据变化率12.5%

################################################################################
## 11. DRC检查豁免（如有需要）
################################################################################
# 某些Artix-7警告可忽略（如BUFG使用数量）
# set_property SEVERITY {Warning} [get_drc_checks BUFGCTRL-1]

################################################################################
## 12. 时序例外（跨时钟域，如有）
################################################################################
# 如果CRC模块与其他时钟域通信，添加CDC约束
# set_max_delay -datapath_only 5.000 -from [get_clocks clk_can] -to [get_clocks sys_clk]
# set_max_delay -datapath_only 5.000 -from [get_clocks sys_clk] -to [get_clocks clk_can]

################################################################################
## END OF CONSTRAINTS
################################################################################

# 注意：XDC约束文件不支持puts命令
# 如需提示信息，请在综合后的报告或TCL脚本中输出

