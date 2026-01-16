// =============================================================================
// 文件名: npu_enhanced_tb.v
// 功能: NPU增强测试平台
// 描述: 包含多个测试用例和性能分析
// =============================================================================

`timescale 1ns / 1ps

module npu_enhanced_tb;

    // =========================================================================
    // 参数定义
    // =========================================================================
    parameter AXI_ADDR_WIDTH = 32;
    parameter AXI_DATA_WIDTH = 32;
    parameter DATA_WIDTH = 16;
    parameter MATRIX_SIZE = 8;
    parameter CLK_PERIOD = 10;  // 10ns = 100MHz
    
    // =========================================================================
    // 信号定义
    // =========================================================================
    
    // 时钟和复位
    reg                         aclk;
    reg                         aresetn;
    
    // AXI写地址通道
    reg [AXI_ADDR_WIDTH-1:0]    s_axi_awaddr;
    reg [2:0]                   s_axi_awprot;
    reg                         s_axi_awvalid;
    wire                        s_axi_awready;
    
    // AXI写数据通道
    reg [AXI_DATA_WIDTH-1:0]    s_axi_wdata;
    reg [(AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb;
    reg                         s_axi_wvalid;
    wire                        s_axi_wready;
    
    // AXI写响应通道
    wire [1:0]                  s_axi_bresp;
    wire                        s_axi_bvalid;
    reg                         s_axi_bready;
    
    // AXI读地址通道
    reg [AXI_ADDR_WIDTH-1:0]    s_axi_araddr;
    reg [2:0]                   s_axi_arprot;
    reg                         s_axi_arvalid;
    wire                        s_axi_arready;
    
    // AXI读数据通道
    wire [AXI_DATA_WIDTH-1:0]   s_axi_rdata;
    wire [1:0]                  s_axi_rresp;
    wire                        s_axi_rvalid;
    reg                         s_axi_rready;
    
    // 中断
    wire                        interrupt;
    
    // =========================================================================
    // DUT实例化
    // =========================================================================
    npu_top #(
        .AXI_ADDR_WIDTH         (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH         (AXI_DATA_WIDTH),
        .DATA_WIDTH             (DATA_WIDTH),
        .MATRIX_SIZE            (MATRIX_SIZE)
    ) u_dut (
        .aclk                   (aclk),
        .aresetn                (aresetn),
        
        .s_axi_awaddr           (s_axi_awaddr),
        .s_axi_awprot           (s_axi_awprot),
        .s_axi_awvalid          (s_axi_awvalid),
        .s_axi_awready          (s_axi_awready),
        
        .s_axi_wdata            (s_axi_wdata),
        .s_axi_wstrb            (s_axi_wstrb),
        .s_axi_wvalid           (s_axi_wvalid),
        .s_axi_wready           (s_axi_wready),
        
        .s_axi_bresp            (s_axi_bresp),
        .s_axi_bvalid           (s_axi_bvalid),
        .s_axi_bready           (s_axi_bready),
        
        .s_axi_araddr           (s_axi_araddr),
        .s_axi_arprot           (s_axi_arprot),
        .s_axi_arvalid          (s_axi_arvalid),
        .s_axi_arready          (s_axi_arready),
        
        .s_axi_rdata            (s_axi_rdata),
        .s_axi_rresp            (s_axi_rresp),
        .s_axi_rvalid           (s_axi_rvalid),
        .s_axi_rready           (s_axi_rready),
        
        .interrupt              (interrupt)
    );
    
    // =========================================================================
    // 时钟生成
    // =========================================================================
    initial begin
        aclk = 0;
        forever #(CLK_PERIOD/2) aclk = ~aclk;
    end
    
    // =========================================================================
    // 测试任务：AXI写操作
    // =========================================================================
    task axi_write;
        input [AXI_ADDR_WIDTH-1:0] addr;
        input [AXI_DATA_WIDTH-1:0] data;
        begin
            @(posedge aclk);
            
            s_axi_awaddr = addr;
            s_axi_awprot = 3'b000;
            s_axi_awvalid = 1'b1;
            
            s_axi_wdata = data;
            s_axi_wstrb = 4'b1111;
            s_axi_wvalid = 1'b1;
            
            wait(s_axi_awready && s_axi_wready);
            @(posedge aclk);
            s_axi_awvalid = 1'b0;
            s_axi_wvalid = 1'b0;
            
            wait(s_axi_bvalid);
            @(posedge aclk);
        end
    endtask
    
    // =========================================================================
    // 测试任务：AXI读操作
    // =========================================================================
    task axi_read;
        input [AXI_ADDR_WIDTH-1:0] addr;
        output [AXI_DATA_WIDTH-1:0] data;
        begin
            @(posedge aclk);
            
            s_axi_araddr = addr;
            s_axi_arprot = 3'b000;
            s_axi_arvalid = 1'b1;
            
            wait(s_axi_arready);
            @(posedge aclk);
            s_axi_arvalid = 1'b0;
            
            wait(s_axi_rvalid);
            data = s_axi_rdata;
            @(posedge aclk);
        end
    endtask
    
    // =========================================================================
    // 测试任务：等待计算完成
    // =========================================================================
    task wait_compute_done;
        reg [31:0] status;
        integer timeout;
        begin
            timeout = 0;
            status = 32'h0000_0001;  // BUSY位
            
            while ((status & 32'h0000_0001) == 1 || status == 0) begin
                #(CLK_PERIOD*10);
                axi_read(32'h0000_0004, status);
                timeout = timeout + 1;
                
                if (timeout > 1000) begin
                    $display("[ERROR] Computation timeout!");
                    $finish;
                end
            end
            
            $display("[INFO] Computation completed in %0d iterations", timeout);
        end
    endtask
    
    // =========================================================================
    // 测试任务：打印矩阵
    // =========================================================================
    task print_matrix;
        input [8*20:1] name;
        input [15:0] matrix [0:7];
        integer i;
        real value;
        begin
            $display("\n%s:", name);
            for (i = 0; i < 8; i = i + 1) begin
                value = $itor($signed(matrix[i])) / 256.0;
                $display("  [%0d] = 0x%04h (%.3f)", i, matrix[i], value);
            end
        end
    endtask
    
    // =========================================================================
    // 测试变量
    // =========================================================================
    reg [AXI_DATA_WIDTH-1:0] read_data;
    integer i, j;
    integer test_passed;
    integer test_failed;
    
    // 测试数据
    reg [15:0] test1_input [0:7];
    reg [15:0] test1_weight [0:7][0:7];
    reg [15:0] test1_output [0:7];
    reg [15:0] test1_expected [0:7];
    
    reg [15:0] test2_input [0:7];
    reg [15:0] test2_weight [0:7][0:7];
    reg [15:0] test2_output [0:7];
    
    // =========================================================================
    // 主测试流程
    // =========================================================================
    initial begin
        // 初始化信号
        aresetn = 0;
        s_axi_awaddr = 0;
        s_axi_awprot = 0;
        s_axi_awvalid = 0;
        s_axi_wdata = 0;
        s_axi_wstrb = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 1;
        s_axi_araddr = 0;
        s_axi_arprot = 0;
        s_axi_arvalid = 0;
        s_axi_rready = 1;
        
        test_passed = 0;
        test_failed = 0;
        
        $display("========================================");
        $display("NPU Enhanced Testbench Started");
        $display("========================================");
        
        #(CLK_PERIOD*10);
        aresetn = 1;
        #(CLK_PERIOD*10);
        
        // =====================================================================
        // 测试1：单位矩阵乘法（无激活函数）
        // =====================================================================
        $display("\n========================================");
        $display("TEST 1: Identity Matrix (No Activation)");
        $display("========================================");
        
        // 准备测试数据
        for (i = 0; i < 8; i = i + 1) begin
            test1_input[i] = 16'h0100;  // 1.0
            test1_expected[i] = 16'h0100;  // 期望输出1.0
            for (j = 0; j < 8; j = j + 1) begin
                if (i == j)
                    test1_weight[i][j] = 16'h0100;  // 对角线为1
                else
                    test1_weight[i][j] = 16'h0000;  // 其他为0
            end
        end
        
        // 复位NPU
        axi_write(32'h0000_0000, 32'h0000_0001);
        #(CLK_PERIOD*5);
        axi_write(32'h0000_0000, 32'h0000_0000);
        #(CLK_PERIOD*5);
        
        // 配置：8×8矩阵，无激活函数
        axi_write(32'h0000_0008, 32'h0000_0008);
        
        // 加载权重
        $display("[TEST 1] Loading weights...");
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                axi_write(32'h0000_0100 + (i*8 + j)*4, {16'h0000, test1_weight[i][j]});
            end
        end
        
        // 加载输入
        $display("[TEST 1] Loading inputs...");
        for (i = 0; i < 8; i = i + 1) begin
            axi_write(32'h0000_0200 + i*4, {16'h0000, test1_input[i]});
        end
        
        // 启动计算
        $display("[TEST 1] Starting computation...");
        axi_write(32'h0000_0000, 32'h0000_0002);
        
        // 等待完成
        wait_compute_done();
        
        // 读取结果
        $display("[TEST 1] Reading results...");
        for (i = 0; i < 8; i = i + 1) begin
            axi_read(32'h0000_0300 + i*4, read_data);
            test1_output[i] = read_data[15:0];
        end
        
        // 打印结果
        print_matrix("Input", test1_input);
        print_matrix("Output", test1_output);
        print_matrix("Expected", test1_expected);
        
        // 验证结果
        $display("\n[TEST 1] Verification:");
        for (i = 0; i < 8; i = i + 1) begin
            if (test1_output[i] == test1_expected[i]) begin
                $display("  [%0d] PASS: 0x%04h == 0x%04h", i, test1_output[i], test1_expected[i]);
                test_passed = test_passed + 1;
            end else begin
                $display("  [%0d] FAIL: 0x%04h != 0x%04h", i, test1_output[i], test1_expected[i]);
                test_failed = test_failed + 1;
            end
        end
        
        // =====================================================================
        // 测试2：向量缩放（ReLU激活）
        // =====================================================================
        $display("\n========================================");
        $display("TEST 2: Vector Scaling (ReLU)");
        $display("========================================");
        
        // 准备测试数据：对角矩阵，缩放因子为2
        for (i = 0; i < 8; i = i + 1) begin
            test2_input[i] = 16'h0100;  // 1.0
            for (j = 0; j < 8; j = j + 1) begin
                if (i == j)
                    test2_weight[i][j] = 16'h0200;  // 2.0
                else
                    test2_weight[i][j] = 16'h0000;
            end
        end
        
        // 复位
        axi_write(32'h0000_0000, 32'h0000_0001);
        #(CLK_PERIOD*5);
        axi_write(32'h0000_0000, 32'h0000_0000);
        #(CLK_PERIOD*5);
        
        // 配置：8×8矩阵，ReLU激活
        axi_write(32'h0000_0008, 32'h0000_0108);
        
        // 加载权重
        $display("[TEST 2] Loading weights...");
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                axi_write(32'h0000_0100 + (i*8 + j)*4, {16'h0000, test2_weight[i][j]});
            end
        end
        
        // 加载输入
        $display("[TEST 2] Loading inputs...");
        for (i = 0; i < 8; i = i + 1) begin
            axi_write(32'h0000_0200 + i*4, {16'h0000, test2_input[i]});
        end
        
        // 启动计算
        $display("[TEST 2] Starting computation...");
        axi_write(32'h0000_0000, 32'h0000_0002);
        
        // 等待完成
        wait_compute_done();
        
        // 读取结果
        $display("[TEST 2] Reading results...");
        for (i = 0; i < 8; i = i + 1) begin
            axi_read(32'h0000_0300 + i*4, read_data);
            test2_output[i] = read_data[15:0];
        end
        
        // 打印结果
        print_matrix("Input", test2_input);
        print_matrix("Output (should be ~2.0)", test2_output);
        
        // =====================================================================
        // 测试总结
        // =====================================================================
        #(CLK_PERIOD*100);
        
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Tests Passed: %0d", test_passed);
        $display("Tests Failed: %0d", test_failed);
        
        if (test_failed == 0) begin
            $display("\n*** ALL TESTS PASSED ***");
        end else begin
            $display("\n*** SOME TESTS FAILED ***");
        end
        
        $display("\n========================================");
        $display("NPU Enhanced Testbench Completed");
        $display("========================================");
        
        $finish;
    end
    
    // =========================================================================
    // 波形文件生成
    // =========================================================================
    initial begin
        $dumpfile("npu_enhanced_tb.vcd");
        $dumpvars(0, npu_enhanced_tb);
    end
    
    // =========================================================================
    // 超时检测
    // =========================================================================
    initial begin
        #(CLK_PERIOD * 200000);
        $display("ERROR: Simulation timeout!");
        $finish;
    end
    
    // =========================================================================
    // 中断监控
    // =========================================================================
    always @(posedge interrupt) begin
        $display("[%0t] *** INTERRUPT DETECTED ***", $time);
    end

endmodule
