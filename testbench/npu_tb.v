// =============================================================================
// 文件名: npu_tb.v
// 功能: NPU测试平台
// 描述: 验证NPU功能的基本测试用例
// =============================================================================

`timescale 1ns / 1ps

module npu_tb;

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
            
            // 写地址
            s_axi_awaddr = addr;
            s_axi_awprot = 3'b000;
            s_axi_awvalid = 1'b1;
            
            // 写数据
            s_axi_wdata = data;
            s_axi_wstrb = 4'b1111;
            s_axi_wvalid = 1'b1;
            
            // 等待握手
            wait(s_axi_awready && s_axi_wready);
            @(posedge aclk);
            s_axi_awvalid = 1'b0;
            s_axi_wvalid = 1'b0;
            
            // 等待写响应
            wait(s_axi_bvalid);
            @(posedge aclk);
            
            $display("[%0t] AXI Write: Addr=0x%08h, Data=0x%08h", $time, addr, data);
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
            
            // 读地址
            s_axi_araddr = addr;
            s_axi_arprot = 3'b000;
            s_axi_arvalid = 1'b1;
            
            // 等待握手
            wait(s_axi_arready);
            @(posedge aclk);
            s_axi_arvalid = 1'b0;
            
            // 等待读数据
            wait(s_axi_rvalid);
            data = s_axi_rdata;
            @(posedge aclk);
            
            $display("[%0t] AXI Read: Addr=0x%08h, Data=0x%08h", $time, addr, data);
        end
    endtask
    
    // =========================================================================
    // 测试变量
    // =========================================================================
    reg [AXI_DATA_WIDTH-1:0] read_data;
    integer i, j;
    
    // 测试数据（Q8.8格式）
    reg [15:0] test_input [0:7];
    reg [15:0] test_weight [0:7][0:7];
    reg [15:0] expected_output [0:7];
    
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
        
        // 准备测试数据
        // 简单测试：单位矩阵 × 向量
        for (i = 0; i < 8; i = i + 1) begin
            test_input[i] = 16'h0100;  // 1.0 in Q8.8
            for (j = 0; j < 8; j = j + 1) begin
                if (i == j)
                    test_weight[i][j] = 16'h0100;  // 1.0
                else
                    test_weight[i][j] = 16'h0000;  // 0.0
            end
        end
        
        // 复位
        $display("========================================");
        $display("NPU Testbench Started");
        $display("========================================");
        
        #(CLK_PERIOD*10);
        aresetn = 1;
        #(CLK_PERIOD*10);
        
        // =====================================================================
        // 测试1：配置NPU
        // =====================================================================
        $display("\n[TEST 1] Configuring NPU...");
        
        // 软复位
        axi_write(32'h0000_0000, 32'h0000_0001);  // CTRL_REG: 复位
        #(CLK_PERIOD*5);
        axi_write(32'h0000_0000, 32'h0000_0000);  // 清除复位
        #(CLK_PERIOD*5);
        
        // 配置：8x8矩阵，ReLU激活
        axi_write(32'h0000_0008, 32'h0000_0108);  // CONFIG_REG
        #(CLK_PERIOD*5);
        
        // =====================================================================
        // 测试2：加载权重数据
        // =====================================================================
        $display("\n[TEST 2] Loading weight data...");
        
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                axi_write(32'h0000_0100 + (i*8 + j)*4, {16'h0000, test_weight[i][j]});
            end
        end
        
        $display("Weight data loaded successfully");
        
        // =====================================================================
        // 测试3：加载输入数据
        // =====================================================================
        $display("\n[TEST 3] Loading input data...");
        
        for (i = 0; i < 8; i = i + 1) begin
            axi_write(32'h0000_0200 + i*4, {16'h0000, test_input[i]});
        end
        
        $display("Input data loaded successfully");
        
        // =====================================================================
        // 测试4：启动计算
        // =====================================================================
        $display("\n[TEST 4] Starting computation...");
        
        axi_write(32'h0000_0000, 32'h0000_0002);  // CTRL_REG: 启动
        
        // 等待计算完成（轮询状态寄存器）
        read_data = 0;
        while ((read_data & 32'h0000_0001) == 1 || read_data == 0) begin
            #(CLK_PERIOD*10);
            axi_read(32'h0000_0004, read_data);  // STATUS_REG
        end
        
        $display("Computation completed!");
        $display("Status Register: 0x%08h", read_data);
        
        // =====================================================================
        // 测试5：读取结果
        // =====================================================================
        $display("\n[TEST 5] Reading output data...");
        
        for (i = 0; i < 8; i = i + 1) begin
            axi_read(32'h0000_0300 + i*4, read_data);
            $display("Output[%0d] = 0x%04h (%.2f)", i, read_data[15:0], 
                     $itor($signed(read_data[15:0])) / 256.0);
        end
        
        // =====================================================================
        // 测试6：检查中断状态
        // =====================================================================
        $display("\n[TEST 6] Checking interrupt status...");
        
        axi_read(32'h0000_000C, read_data);  // INT_STATUS
        $display("Interrupt Status: 0x%08h", read_data);
        
        if (read_data[0]) begin
            $display("Computation complete interrupt detected");
        end
        
        // 清除中断
        axi_write(32'h0000_000C, 32'h0000_0001);  // W1C
        
        // =====================================================================
        // 测试完成
        // =====================================================================
        #(CLK_PERIOD*100);
        
        $display("\n========================================");
        $display("NPU Testbench Completed");
        $display("========================================");
        
        $finish;
    end
    
    // =========================================================================
    // 波形文件生成
    // =========================================================================
    initial begin
        $dumpfile("npu_tb.vcd");
        $dumpvars(0, npu_tb);
    end
    
    // =========================================================================
    // 超时检测
    // =========================================================================
    initial begin
        #(CLK_PERIOD * 100000);  // 1ms超时
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule

// =============================================================================
// 测试平台说明
// =============================================================================
//
// 功能描述：
// 这个测试平台验证NPU的基本功能，包括配置、数据加载、计算和结果读取。
//
// 测试流程：
// 1. 复位NPU
// 2. 配置NPU（矩阵大小、激活函数）
// 3. 加载权重数据（单位矩阵）
// 4. 加载输入数据（全1向量）
// 5. 启动计算
// 6. 等待计算完成
// 7. 读取输出结果
// 8. 检查中断状态
//
// 测试用例：
// - 单位矩阵乘法：I × v = v
// - 输入：[1, 1, 1, 1, 1, 1, 1, 1]
// - 权重：8×8单位矩阵
// - 期望输出：[1, 1, 1, 1, 1, 1, 1, 1]
//
// AXI事务：
// - axi_write任务：执行AXI写操作
// - axi_read任务：执行AXI读操作
// - 自动处理握手协议
//
// 数据格式：
// - Q8.8定点数格式
// - 16'h0100 = 1.0
// - 16'h0080 = 0.5
// - 16'h0200 = 2.0
//
// 仿真输出：
// - 控制台打印所有操作
// - 生成VCD波形文件
// - 显示计算结果
//
// 运行方法：
// iverilog -o npu_sim npu_tb.v npu_top.v [其他模块].v
// vvp npu_sim
// gtkwave npu_tb.vcd
//
// 扩展测试：
// 1. 测试不同的矩阵大小
// 2. 测试不同的激活函数
// 3. 测试边界条件
// 4. 测试错误处理
// 5. 性能测试
//
// =============================================================================
