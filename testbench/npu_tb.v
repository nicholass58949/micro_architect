// =============================================================================
// 文件名: npu_tb.v
// 功能: NPU最小测试平台
// =============================================================================

`timescale 1ns / 1ps

module npu_tb;
    parameter AXI_ADDR_WIDTH = 32;
    parameter AXI_DATA_WIDTH = 32;
    parameter DATA_WIDTH = 16;
    parameter MATRIX_SIZE = 8;
    parameter CLK_PERIOD = 10;

    reg                         aclk;
    reg                         aresetn;

    reg [AXI_ADDR_WIDTH-1:0]    s_axi_awaddr;
    reg [2:0]                   s_axi_awprot;
    reg                         s_axi_awvalid;
    wire                        s_axi_awready;

    reg [AXI_DATA_WIDTH-1:0]    s_axi_wdata;
    reg [(AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb;
    reg                         s_axi_wvalid;
    wire                        s_axi_wready;

    wire [1:0]                  s_axi_bresp;
    wire                        s_axi_bvalid;
    reg                         s_axi_bready;

    reg [AXI_ADDR_WIDTH-1:0]    s_axi_araddr;
    reg [2:0]                   s_axi_arprot;
    reg                         s_axi_arvalid;
    wire                        s_axi_arready;

    wire [AXI_DATA_WIDTH-1:0]   s_axi_rdata;
    wire [1:0]                  s_axi_rresp;
    wire                        s_axi_rvalid;
    reg                         s_axi_rready;

    wire                        interrupt;

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

    initial begin
        aclk = 0;
        forever #(CLK_PERIOD/2) aclk = ~aclk;
    end

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

    reg [AXI_DATA_WIDTH-1:0] read_data;
    integer i;
    integer j;

    initial begin
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

        #(CLK_PERIOD*5);
        aresetn = 1;
        #(CLK_PERIOD*5);

        // 配置: 8x8矩阵, ReLU
        axi_write(32'h0000_0008, 32'h0000_0108);

        // 写入权重: 单位矩阵
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
            for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                if (i == j) begin
                    axi_write(32'h0000_0100 + ((i*MATRIX_SIZE + j)*4), 32'h0000_0100);
                end else begin
                    axi_write(32'h0000_0100 + ((i*MATRIX_SIZE + j)*4), 32'h0000_0000);
                end
            end
        end

        // 写入输入: 全1向量
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
            axi_write(32'h0000_0200 + (i*4), 32'h0000_0100);
        end

        // 启动计算
        axi_write(32'h0000_0000, 32'h0000_0002);

        // 等待完成（使用中断状态寄存器，避免错过done脉冲）
        read_data = 0;
        while ((read_data & 32'h0000_0001) == 0) begin
            #(CLK_PERIOD*5);
            axi_read(32'h0000_000C, read_data);
        end

        // 读取输出
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
            axi_read(32'h0000_0300 + (i*4), read_data);
        end

        #(CLK_PERIOD*20);
        $finish;
    end

    initial begin
        $dumpfile("npu_tb.vcd");
        $dumpvars(0, npu_tb);
    end

endmodule
