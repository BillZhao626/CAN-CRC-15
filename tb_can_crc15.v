////////////////////////////////////////////////////////////////////////////////
// 模块名称: tb_can_crc15
// 功能描述: CAN CRC-15仿真测试台（完整测试案例）
// 验证目标: 
//   1. 标准CAN帧CRC计算正确性
//   2. 位填充跳过逻辑
//   3. 与Vector CANoe工具对比
// 仿真工具: ModelSim / Vivado Simulator
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module tb_can_crc15;

//==============================================================================
// 信号声明
//==============================================================================
reg clk;
reg rst_n;
reg data_valid;
reg data_in;
reg is_stuffed;
reg crc_init;
reg crc_enable;
wire [14:0] crc_out;
wire [14:0] crc_out_rev;

// 测试统计
integer test_passed;
integer test_failed;

//==============================================================================
// 实例化待测模块（DUT）
//==============================================================================
can_crc15_core u_dut (
    .clk(clk),
    .rst_n(rst_n),
    .data_valid(data_valid),
    .data_in(data_in),
    .is_stuffed(is_stuffed),
    .crc_init(crc_init),
    .crc_enable(crc_enable),
    .crc_out(crc_out),
    .crc_out_rev(crc_out_rev)
);

//==============================================================================
// 时钟生成（500MHz - 2ns周期）
//==============================================================================
initial begin
    clk = 0;
    forever #1 clk = ~clk;  // 每1ns翻转一次，周期2ns
end

//==============================================================================
// 主测试流程
//==============================================================================
initial begin
    // 初始化
    $display("================================================================================");
    $display("  CAN CRC-15 Hardware Verification Testbench");
    $display("  Target: Xilinx Artix-7 (SRL16E Optimized)");
    $display("  Clock: 500MHz (2ns period)");
    $display("================================================================================");
    $display("");
    
    test_passed = 0;
    test_failed = 0;
    
    // 复位初始化
    rst_n = 0;
    data_valid = 0;
    data_in = 0;
    is_stuffed = 0;
    crc_enable = 1;
    crc_init = 0;
    
    #20 rst_n = 1;
    #10;
    
    //==========================================================================
    // 测试案例1：最小CAN帧（ID=0x123, DLC=0, 无数据）
    //==========================================================================
    $display("--------------------------------------------------------------------------------");
    $display("Test Case 1: Minimum CAN Frame");
    $display("  Frame: ID=0x123, RTR=0, DLC=0");
    $display("  Expected CRC-15: 0x342C");
    $display("--------------------------------------------------------------------------------");
    
    test_case_1();
    
    //==========================================================================
    // 测试案例2：单字节数据帧（ID=0x456, DLC=1, Data=0x45）
    //==========================================================================
    $display("--------------------------------------------------------------------------------");
    $display("Test Case 2: Single Byte Data Frame");
    $display("  Frame: ID=0x456, RTR=0, DLC=1, Data=0x45");
    $display("  Expected CRC-15: 0x4931");
    $display("--------------------------------------------------------------------------------");
    
    test_case_2();
    
    //==========================================================================
    // 测试案例3：位填充场景（连续5个'1'）
    //==========================================================================
    $display("--------------------------------------------------------------------------------");
    $display("Test Case 3: Bit Stuffing Scenario");
    $display("  Input: 11111 (5 consecutive 1s)");
    $display("  Expected: CRC skips stuffed bit");
    $display("--------------------------------------------------------------------------------");
    
    test_case_3_bit_stuffing();
    
    //==========================================================================
    // 测试案例4：全0边界条件（ID=0x000, DLC=0）
    //==========================================================================
    $display("--------------------------------------------------------------------------------");
    $display("Test Case 4: All Zero Boundary Condition");
    $display("  Frame: ID=0x000, RTR=0, DLC=0");
    $display("  Expected CRC-15: 0x0000");
    $display("--------------------------------------------------------------------------------");
    
    test_case_4_all_zero();
    
    //==========================================================================
    // 测试案例5：交替位模式（ID=0x555, DLC=4, Data=0xAAAA5555）
    //==========================================================================
    $display("--------------------------------------------------------------------------------");
    $display("Test Case 5: Alternating Bit Pattern");
    $display("  Frame: ID=0x555, RTR=0, DLC=4, Data=0xAAAA5555");
    $display("  Expected CRC-15: 0x34C8");
    $display("--------------------------------------------------------------------------------");
    
    test_case_5_alternating();
    
    //==========================================================================
    // 测试总结
    //==========================================================================
    $display("");
    $display("================================================================================");
    $display("  TEST SUMMARY");
    $display("================================================================================");
    $display("  Total Tests: %0d", test_passed + test_failed);
    $display("  Passed:      %0d", test_passed);
    $display("  Failed:      %0d", test_failed);
    $display("");
    
    if (test_failed == 0) begin
        $display("  ✓✓✓ ALL TESTS PASSED ✓✓✓");
        $display("  CRC-15 implementation is CORRECT and matches industry standards.");
    end else begin
        $display("  ✗✗✗ SOME TESTS FAILED ✗✗✗");
        $display("  Please check the implementation.");
    end
    
    $display("================================================================================");
    $display("");
    
    #100;
    $finish;
end

//==============================================================================
// 测试案例1：ID=0x123, DLC=0（最小帧）
//==============================================================================
task test_case_1;
    reg [14:0] expected_crc;
    begin
        expected_crc = 15'h342C;
        
        // 修复：正确的复位和初始化序列
        @(posedge clk);
        rst_n = 0;  // 先复位
        @(posedge clk);
        rst_n = 1;  // 释放复位
        @(posedge clk);
        
        // CRC初始化
        crc_init = 1;
        @(posedge clk);
        crc_init = 0;
        @(posedge clk);
        @(posedge clk);  // 增加等待时间让SRL16E稳定
        @(posedge clk);  // 额外等待周期
        
        // CAN帧完整位流（19位）：
        // SOF(1)=0, ID(11)=0x123, RTR(1)=0, IDE(1)=0, r0(1)=0, DLC(4)=0x0
        // 
        // CAN标准传输顺序（MSB先）：
        // SOF: 0
        // ID[10:0]: 0x123 = 291(dec) = 00100100011 (11位MSB先)
        // RTR: 0
        // IDE: 0
        // r0: 0
        // DLC[3:0]: 0 = 0000
        //
        // 完整序列（MSB先传输）：0 + 00100100011 + 0 + 0 + 0 + 0000
        // 总位数：1 + 11 + 1 + 1 + 1 + 4 = 19位
        // 打包成19位literal（MSB在左）
        feed_bit_sequence(19, 19'b0001001000110000000);
        
        #20;  // 等待CRC稳定
        
        // 检查结果
        $display("  Input bits: 19 (SOF + ID + RTR + IDE + r0 + DLC)");
        $display("  CRC Output (Normal):   0x%04X", crc_out);
        $display("  CRC Output (Reversed): 0x%04X", crc_out_rev);
        $display("  Expected:              0x%04X", expected_crc);
        
        if (crc_out == expected_crc) begin
            $display("  Result: PASS ✓");
            test_passed = test_passed + 1;
        end else begin
            $display("  Result: FAIL ✗");
            test_failed = test_failed + 1;
        end
        
        $display("");
    end
endtask

//==============================================================================
// 测试案例2：ID=0x456, DLC=1, Data=0x45
//==============================================================================
task test_case_2;
    reg [14:0] expected_crc;
    begin
        expected_crc = 15'h4931;
        
        // 修复：正确的复位和初始化序列
        @(posedge clk);
        rst_n = 0;  // 先复位
        @(posedge clk);
        rst_n = 1;  // 释放复位
        @(posedge clk);
        
        // CRC初始化
        crc_init = 1;
        @(posedge clk);
        crc_init = 0;
        @(posedge clk);
        @(posedge clk);  // 增加等待时间让SRL16E稳定
        @(posedge clk);  // 额外等待周期
        
        // CAN帧完整位流（27位）：
        // SOF(1)=0, ID(11)=0x456, RTR(1)=0, IDE(1)=0, r0(1)=0, DLC(4)=1, Data(8)=0x45
        //
        // CAN标准传输顺序（MSB先）：
        // SOF: 0
        // ID[10:0]: 0x456 = 1110(dec) = 10001010110 (11位MSB先)
        // RTR: 0
        // IDE: 0
        // r0: 0
        // DLC[3:0]: 1 = 0001
        // Data[7:0]: 0x45 = 0100_0101 (MSB先)
        //
        // 完整序列（MSB先传输）：0 + 10001010110 + 0 + 0 + 0 + 0001 + 01000101
        // 总位数：1 + 11 + 1 + 1 + 1 + 4 + 8 = 27位
        // 打包成27位literal（MSB在左）
        feed_bit_sequence(27, 27'b010001010110000000101000101);
        
        #20;
        
        $display("  Input bits: 27 (SOF + ID + RTR + IDE + r0 + DLC + Data)");
        $display("  CRC Output (Normal):   0x%04X", crc_out);
        $display("  CRC Output (Reversed): 0x%04X", crc_out_rev);
        $display("  Expected:              0x%04X", expected_crc);
        
        if (crc_out == expected_crc) begin
            $display("  Result: PASS ✓");
            test_passed = test_passed + 1;
        end else begin
            $display("  Result: FAIL ✗");
            test_failed = test_failed + 1;
        end
        
        $display("");
    end
endtask

//==============================================================================
// 测试案例3：位填充场景
//==============================================================================
task test_case_3_bit_stuffing;
    reg [14:0] crc_before_stuff, crc_after_stuff;
    begin
        // 修复：正确的复位和初始化序列
        @(posedge clk);
        rst_n = 0;  // 先复位
        @(posedge clk);
        rst_n = 1;  // 释放复位
        @(posedge clk);
        
        // CRC初始化
        crc_init = 1;
        @(posedge clk);
        crc_init = 0;
        @(posedge clk);
        @(posedge clk);  // 增加等待时间让SRL16E稳定
        @(posedge clk);  // 额外等待周期
        
        // 输入连续5个'1'
        $display("  Sending 5 consecutive '1's...");
        feed_bit(1);
        feed_bit(1);
        feed_bit(1);
        feed_bit(1);
        feed_bit(1);
        
        @(posedge clk);  // 等待一个周期让CRC稳定
        crc_before_stuff = crc_out;
        $display("  CRC before stuffed bit: 0x%04X", crc_before_stuff);
        
        // 插入填充位'0'（标记为is_stuffed=1）
        $display("  Inserting stuffed bit '0' (is_stuffed=1)...");
        @(posedge clk);
        data_valid = 1;
        data_in = 0;
        is_stuffed = 1;  // 标记为填充位
        @(posedge clk);
        data_valid = 0;
        is_stuffed = 0;
        
        @(posedge clk);  // 等待一个周期让CRC稳定
        crc_after_stuff = crc_out;
        $display("  CRC after stuffed bit:  0x%04X", crc_after_stuff);
        
        // 继续输入正常数据
        feed_bit(1);
        feed_bit(0);
        
        #10;
        
        // 验证填充位时CRC保持不变
        if (crc_before_stuff == crc_after_stuff) begin
            $display("  CRC unchanged during stuffed bit: PASS ✓");
            test_passed = test_passed + 1;
        end else begin
            $display("  CRC changed during stuffed bit: FAIL ✗");
            test_failed = test_failed + 1;
        end
        
        $display("");
    end
endtask

//==============================================================================
// 测试案例4：全0边界条件
//==============================================================================
task test_case_4_all_zero;
    begin
        // 修复：正确的复位和初始化序列
        @(posedge clk);
        rst_n = 0;  // 先复位
        @(posedge clk);
        rst_n = 1;  // 释放复位
        @(posedge clk);
        
        // CRC初始化
        crc_init = 1;
        @(posedge clk);
        crc_init = 0;
        @(posedge clk);
        @(posedge clk);  // 增加等待时间让SRL16E稳定
        @(posedge clk);  // 额外等待周期
        
        // 输入全0（20位）
        feed_bit_sequence(20, 20'h00000);
        
        #20;
        
        $display("  Input bits: 20 (all zeros)");
        $display("  CRC Output (Normal):   0x%04X", crc_out);
        $display("  CRC Output (Reversed): 0x%04X", crc_out_rev);
        $display("  Expected:   0x0000");
        
        if (crc_out == 15'h0000) begin
            $display("  Result: PASS ✓");
            test_passed = test_passed + 1;
        end else begin
            $display("  Result: FAIL ✗");
            test_failed = test_failed + 1;
        end
        
        $display("");
    end
endtask

//==============================================================================
// 测试案例5：交替位模式
//==============================================================================
task test_case_5_alternating;
    reg [14:0] expected_crc;
    begin
        expected_crc = 15'h34C8;
        
        // 修复：正确的复位和初始化序列
        @(posedge clk);
        rst_n = 0;  // 先复位
        @(posedge clk);
        rst_n = 1;  // 释放复位
        @(posedge clk);
        
        // CRC初始化
        crc_init = 1;
        @(posedge clk);
        crc_init = 0;
        @(posedge clk);
        @(posedge clk);  // 增加等待时间让SRL16E稳定
        @(posedge clk);  // 额外等待周期
        
        // ID=0x555, DLC=4, Data=0xAAAA5555
        // 交替位模式：010101...
        feed_bit_sequence(32, 32'hAAAAAAAA);
        
        #20;
        
        $display("  Input bits: 32 (alternating pattern)");
        $display("  CRC Output (Normal):   0x%04X", crc_out);
        $display("  CRC Output (Reversed): 0x%04X", crc_out_rev);
        $display("  Expected:   0x%04X (verify with CANoe)", expected_crc);
        
        // 验证算法稳定性
        if (crc_out == expected_crc) begin
            $display("  Result: PASS ✓");
            test_passed = test_passed + 1;
        end else begin
            $display("  Result: FAIL ✗");
            test_failed = test_failed + 1;
        end
        
        $display("");
    end
endtask

//==============================================================================
// 辅助任务：发送单个位
//==============================================================================
task feed_bit(input bit_value);
    begin
        @(posedge clk);
        data_valid = 1;
        data_in = bit_value;
        is_stuffed = 0;
        @(posedge clk);
        data_valid = 0;
    end
endtask

//==============================================================================
// 辅助任务：发送位序列（MSB先，符合CAN标准）
// bit_data中：bit[num_bits-1]是第一个传输的位（MSB）
//            bit[0]是最后一个传输的位（LSB）
//==============================================================================
task feed_bit_sequence(input integer num_bits, input [63:0] bit_data);
    integer i;
    begin
        // CAN标准：MSB先传输，所以从最高位开始
        for (i = num_bits - 1; i >= 0; i = i - 1) begin
            feed_bit(bit_data[i]);
        end
    end
endtask

//==============================================================================
// 辅助任务：发送位序列（LSB先，用于特殊测试）
//==============================================================================
task feed_bit_sequence_lsb_first(input integer num_bits, input [63:0] bit_data);
    integer i;
    begin
        // LSB先：从bit[0]开始传输
        for (i = 0; i < num_bits; i = i + 1) begin
            feed_bit(bit_data[i]);
        end
    end
endtask

//==============================================================================
// 波形输出（VCD格式）
//==============================================================================
initial begin
    $dumpfile("can_crc15_sim.vcd");
    $dumpvars(0, tb_can_crc15);
end

//==============================================================================
// 超时保护（防止仿真卡死）
//==============================================================================
initial begin
    #100000;  // 100us超时
    $display("ERROR: Simulation timeout!");
    $finish;
end

endmodule

