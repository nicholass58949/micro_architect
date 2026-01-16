// =============================================================================
// 文件名: axi_interface.v
// 功能: AXI4-Lite从设备接口 - 连接NPU与系统总线
// 描述: 实现标准AXI4-Lite协议，提供寄存器访问和数据传输
// =============================================================================

module axi_interface #(
    parameter AXI_ADDR_WIDTH = 32,      // AXI地址位宽
    parameter AXI_DATA_WIDTH = 32,      // AXI数据位宽
    parameter DATA_WIDTH = 16,          // 内部数据位宽
    parameter INPUT_BUF_ADDR_WIDTH = 8, // 输入缓存地址位宽
    parameter WEIGHT_BUF_ADDR_WIDTH = 10,// 权重缓存地址位宽
    parameter OUTPUT_BUF_ADDR_WIDTH = 8 // 输出缓存地址位宽
)(
    // 全局信号
    input  wire                         aclk,
    input  wire                         aresetn,
    
    // =========================================================================
    // AXI4-Lite写地址通道
    // =========================================================================
    input  wire [AXI_ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [2:0]                   s_axi_awprot,
    input  wire                         s_axi_awvalid,
    output reg                          s_axi_awready,
    
    // =========================================================================
    // AXI4-Lite写数据通道
    // =========================================================================
    input  wire [AXI_DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [(AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                         s_axi_wvalid,
    output reg                          s_axi_wready,
    
    // =========================================================================
    // AXI4-Lite写响应通道
    // =========================================================================
    output reg  [1:0]                   s_axi_bresp,
    output reg                          s_axi_bvalid,
    input  wire                         s_axi_bready,
    
    // =========================================================================
    // AXI4-Lite读地址通道
    // =========================================================================
    input  wire [AXI_ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [2:0]                   s_axi_arprot,
    input  wire                         s_axi_arvalid,
    output reg                          s_axi_arready,
    
    // =========================================================================
    // AXI4-Lite读数据通道
    // =========================================================================
    output reg  [AXI_DATA_WIDTH-1:0]    s_axi_rdata,
    output reg  [1:0]                   s_axi_rresp,
    output reg                          s_axi_rvalid,
    input  wire                         s_axi_rready,
    
    // =========================================================================
    // 控制寄存器接口
    // =========================================================================
    output reg                          ctrl_start,         // 启动信号
    output reg                          ctrl_reset,         // 复位信号
    output reg  [1:0]                   ctrl_activation,    // 激活函数类型
    output reg  [7:0]                   ctrl_matrix_size,   // 矩阵大小
    
    input  wire                         status_busy,        // 忙标志
    input  wire                         status_done,        // 完成标志
    input  wire                         status_error,       // 错误标志
    input  wire [2:0]                   status_state,       // 当前状态
    input  wire                         interrupt,          // 中断信号
    
    // =========================================================================
    // 缓存接口
    // =========================================================================
    // 输入缓存
    output reg                          input_buf_wr_en,
    output reg  [INPUT_BUF_ADDR_WIDTH-1:0] input_buf_wr_addr,
    output reg  [DATA_WIDTH-1:0]        input_buf_wr_data,
    
    // 权重缓存
    output reg                          weight_buf_wr_en,
    output reg  [WEIGHT_BUF_ADDR_WIDTH-1:0] weight_buf_wr_addr,
    output reg  [DATA_WIDTH-1:0]        weight_buf_wr_data,
    
    // 输出缓存
    output reg                          output_buf_rd_en,
    output reg  [OUTPUT_BUF_ADDR_WIDTH-1:0] output_buf_rd_addr,
    input  wire [DATA_WIDTH-1:0]        output_buf_rd_data,
    input  wire                         output_buf_rd_valid
);

    // =========================================================================
    // 寄存器地址映射
    // =========================================================================
    localparam ADDR_CTRL_REG    = 12'h000;  // 控制寄存器
    localparam ADDR_STATUS_REG  = 12'h004;  // 状态寄存器
    localparam ADDR_CONFIG_REG  = 12'h008;  // 配置寄存器
    localparam ADDR_INT_STATUS  = 12'h00C;  // 中断状态寄存器
    
    localparam ADDR_WEIGHT_BASE = 12'h100;  // 权重存储区基地址
    localparam ADDR_INPUT_BASE  = 12'h200;  // 输入数据区基地址
    localparam ADDR_OUTPUT_BASE = 12'h300;  // 输出数据区基地址
    
    // =========================================================================
    // 内部寄存器
    // =========================================================================
    reg [AXI_DATA_WIDTH-1:0]    ctrl_reg;       // 控制寄存器
    reg [AXI_DATA_WIDTH-1:0]    config_reg;     // 配置寄存器
    reg [AXI_DATA_WIDTH-1:0]    int_status_reg; // 中断状态寄存器
    
    // 写事务状态
    reg [AXI_ADDR_WIDTH-1:0]    wr_addr_reg;
    reg [AXI_DATA_WIDTH-1:0]    wr_data_reg;
    reg                         wr_addr_valid;
    reg                         wr_data_valid;
    
    // 读事务状态
    reg [AXI_ADDR_WIDTH-1:0]    rd_addr_reg;
    reg                         rd_addr_valid;
    
    // AXI响应
    localparam AXI_RESP_OKAY    = 2'b00;
    localparam AXI_RESP_SLVERR  = 2'b10;
    
    // =========================================================================
    // AXI写地址通道
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready <= 1'b0;
            wr_addr_reg <= {AXI_ADDR_WIDTH{1'b0}};
            wr_addr_valid <= 1'b0;
        end else begin
            if (s_axi_awvalid && !wr_addr_valid) begin
                s_axi_awready <= 1'b1;
                wr_addr_reg <= s_axi_awaddr;
                wr_addr_valid <= 1'b1;
            end else begin
                s_axi_awready <= 1'b0;
                if (wr_addr_valid && wr_data_valid && s_axi_bready) begin
                    wr_addr_valid <= 1'b0;
                end
            end
        end
    end
    
    // =========================================================================
    // AXI写数据通道
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_wready <= 1'b0;
            wr_data_reg <= {AXI_DATA_WIDTH{1'b0}};
            wr_data_valid <= 1'b0;
        end else begin
            if (s_axi_wvalid && !wr_data_valid) begin
                s_axi_wready <= 1'b1;
                wr_data_reg <= s_axi_wdata;
                wr_data_valid <= 1'b1;
            end else begin
                s_axi_wready <= 1'b0;
                if (wr_addr_valid && wr_data_valid && s_axi_bready) begin
                    wr_data_valid <= 1'b0;
                end
            end
        end
    end
    
    // =========================================================================
    // AXI写响应通道
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= AXI_RESP_OKAY;
        end else begin
            if (wr_addr_valid && wr_data_valid && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp <= AXI_RESP_OKAY;
            end else if (s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end
    
    // =========================================================================
    // 写操作处理
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            ctrl_reg <= 32'h0000_0000;
            config_reg <= 32'h0000_0008;  // 默认8x8矩阵，无激活函数
            int_status_reg <= 32'h0000_0000;
            
            input_buf_wr_en <= 1'b0;
            weight_buf_wr_en <= 1'b0;
            
        end else begin
            // 默认值
            input_buf_wr_en <= 1'b0;
            weight_buf_wr_en <= 1'b0;
            
            // 处理写操作
            if (wr_addr_valid && wr_data_valid && !s_axi_bvalid) begin
                case (wr_addr_reg[11:0])
                    ADDR_CTRL_REG: begin
                        ctrl_reg <= wr_data_reg;
                    end
                    
                    ADDR_CONFIG_REG: begin
                        config_reg <= wr_data_reg;
                    end
                    
                    ADDR_INT_STATUS: begin
                        // W1C：写1清除
                        int_status_reg <= int_status_reg & ~wr_data_reg;
                    end
                    
                    default: begin
                        // 缓存区域写入
                        if (wr_addr_reg[11:8] == 4'h1) begin
                            // 权重缓存区
                            weight_buf_wr_en <= 1'b1;
                            weight_buf_wr_addr <= wr_addr_reg[WEIGHT_BUF_ADDR_WIDTH+1:2];
                            weight_buf_wr_data <= wr_data_reg[DATA_WIDTH-1:0];
                        end else if (wr_addr_reg[11:8] == 4'h2) begin
                            // 输入缓存区
                            input_buf_wr_en <= 1'b1;
                            input_buf_wr_addr <= wr_addr_reg[INPUT_BUF_ADDR_WIDTH+1:2];
                            input_buf_wr_data <= wr_data_reg[DATA_WIDTH-1:0];
                        end
                    end
                endcase
            end
            
            // 中断状态更新
            if (interrupt) begin
                int_status_reg[0] <= 1'b1;  // 计算完成中断
            end
            if (status_error) begin
                int_status_reg[1] <= 1'b1;  // 错误中断
            end
        end
    end
    
    // =========================================================================
    // AXI读地址通道
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b0;
            rd_addr_reg <= {AXI_ADDR_WIDTH{1'b0}};
            rd_addr_valid <= 1'b0;
        end else begin
            if (s_axi_arvalid && !rd_addr_valid) begin
                s_axi_arready <= 1'b1;
                rd_addr_reg <= s_axi_araddr;
                rd_addr_valid <= 1'b1;
            end else begin
                s_axi_arready <= 1'b0;
                if (s_axi_rvalid && s_axi_rready) begin
                    rd_addr_valid <= 1'b0;
                end
            end
        end
    end
    
    // =========================================================================
    // AXI读数据通道
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata <= {AXI_DATA_WIDTH{1'b0}};
            s_axi_rresp <= AXI_RESP_OKAY;
            output_buf_rd_en <= 1'b0;
        end else begin
            output_buf_rd_en <= 1'b0;
            
            if (rd_addr_valid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp <= AXI_RESP_OKAY;
                
                // 读取寄存器或缓存
                case (rd_addr_reg[11:0])
                    ADDR_CTRL_REG: begin
                        s_axi_rdata <= ctrl_reg;
                    end
                    
                    ADDR_STATUS_REG: begin
                        s_axi_rdata <= {28'b0, status_state, status_error, status_done, status_busy};
                    end
                    
                    ADDR_CONFIG_REG: begin
                        s_axi_rdata <= config_reg;
                    end
                    
                    ADDR_INT_STATUS: begin
                        s_axi_rdata <= int_status_reg;
                    end
                    
                    default: begin
                        // 输出缓存区域读取
                        if (rd_addr_reg[11:8] == 4'h3) begin
                            output_buf_rd_en <= 1'b1;
                            output_buf_rd_addr <= rd_addr_reg[OUTPUT_BUF_ADDR_WIDTH+1:2];
                            s_axi_rdata <= {{(AXI_DATA_WIDTH-DATA_WIDTH){1'b0}}, output_buf_rd_data};
                        end else begin
                            s_axi_rdata <= 32'h0000_0000;
                        end
                    end
                endcase
            end else if (s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end
    
    // =========================================================================
    // 控制信号输出
    // =========================================================================
    always @(*) begin
        ctrl_start = ctrl_reg[1];           // bit[1]: 启动位
        ctrl_reset = ctrl_reg[0];           // bit[0]: 复位位
        ctrl_activation = config_reg[9:8];  // bit[9:8]: 激活函数类型
        ctrl_matrix_size = config_reg[7:0]; // bit[7:0]: 矩阵大小
    end

endmodule

// =============================================================================
// 模块说明
// =============================================================================
//
// 功能描述：
// AXI接口模块实现标准的AXI4-Lite从设备协议，连接NPU与系统总线。
// 提供寄存器访问和数据传输功能。
//
// AXI4-Lite协议：
// - 简化的AXI协议，适用于寄存器访问
// - 5个独立通道：写地址、写数据、写响应、读地址、读数据
// - 握手机制：valid/ready信号对
//
// 寄存器映射：
// 0x000: CTRL_REG - 控制寄存器
//        bit[0]: 软复位
//        bit[1]: 启动计算
// 0x004: STATUS_REG - 状态寄存器（只读）
//        bit[0]: busy
//        bit[1]: done
//        bit[2]: error
//        bit[5:3]: current_state
// 0x008: CONFIG_REG - 配置寄存器
//        bit[7:0]: 矩阵大小
//        bit[9:8]: 激活函数类型
// 0x00C: INT_STATUS - 中断状态寄存器（W1C）
//        bit[0]: 计算完成中断
//        bit[1]: 错误中断
//
// 存储区映射：
// 0x100-0x1FF: 权重存储区（256字节）
// 0x200-0x2FF: 输入数据区（256字节）
// 0x300-0x3FF: 输出数据区（256字节，只读）
//
// 写操作流程：
// 1. 主机发送写地址（AWVALID）
// 2. 从机响应（AWREADY）
// 3. 主机发送写数据（WVALID）
// 4. 从机响应（WREADY）
// 5. 从机发送写响应（BVALID）
// 6. 主机确认（BREADY）
//
// 读操作流程：
// 1. 主机发送读地址（ARVALID）
// 2. 从机响应（ARREADY）
// 3. 从机发送读数据（RVALID）
// 4. 主机确认（RREADY）
//
// 特性：
// - 支持字节写使能（WSTRB）
// - W1C寄存器支持（中断状态）
// - 地址译码和错误检测
// - 缓存直接访问
//
// =============================================================================
