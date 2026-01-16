// =============================================================================
// 文件名: npu_top.v
// 功能: NPU顶层模块 - 集成所有子模块
// 描述: 神经网络处理单元的完整实现
// =============================================================================

module npu_top #(
    // AXI参数
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,
    
    // 数据参数
    parameter DATA_WIDTH = 16,
    parameter MATRIX_SIZE = 8,
    
    // 缓存参数
    parameter INPUT_BUF_DEPTH = 256,
    parameter WEIGHT_BUF_DEPTH = 1024,
    parameter OUTPUT_BUF_DEPTH = 256,
    parameter INPUT_BUF_ADDR_WIDTH = 8,
    parameter WEIGHT_BUF_ADDR_WIDTH = 10,
    parameter OUTPUT_BUF_ADDR_WIDTH = 8
)(
    // =========================================================================
    // 全局信号
    // =========================================================================
    input  wire                         aclk,
    input  wire                         aresetn,
    
    // =========================================================================
    // AXI4-Lite从设备接口
    // =========================================================================
    // 写地址通道
    input  wire [AXI_ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [2:0]                   s_axi_awprot,
    input  wire                         s_axi_awvalid,
    output wire                         s_axi_awready,
    
    // 写数据通道
    input  wire [AXI_DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [(AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                         s_axi_wvalid,
    output wire                         s_axi_wready,
    
    // 写响应通道
    output wire [1:0]                   s_axi_bresp,
    output wire                         s_axi_bvalid,
    input  wire                         s_axi_bready,
    
    // 读地址通道
    input  wire [AXI_ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [2:0]                   s_axi_arprot,
    input  wire                         s_axi_arvalid,
    output wire                         s_axi_arready,
    
    // 读数据通道
    output wire [AXI_DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [1:0]                   s_axi_rresp,
    output wire                         s_axi_rvalid,
    input  wire                         s_axi_rready,
    
    // =========================================================================
    // 中断输出
    // =========================================================================
    output wire                         interrupt
);

    // =========================================================================
    // 内部信号定义
    // =========================================================================
    
    // 控制信号（AXI接口 -> 控制单元）
    wire                        ctrl_start;
    wire                        ctrl_reset;
    wire [1:0]                  ctrl_activation;
    wire [7:0]                  ctrl_matrix_size;
    
    // 状态信号（控制单元 -> AXI接口）
    wire                        status_busy;
    wire                        status_done;
    wire                        status_error;
    wire [2:0]                  status_state;
    
    // 输入缓存信号
    wire                        input_buf_wr_en_axi;
    wire [INPUT_BUF_ADDR_WIDTH-1:0] input_buf_wr_addr_axi;
    wire [DATA_WIDTH-1:0]       input_buf_wr_data_axi;
    wire                        input_buf_rd_en_ctrl;
    wire [INPUT_BUF_ADDR_WIDTH-1:0] input_buf_rd_addr;
    wire [DATA_WIDTH-1:0]       input_buf_rd_data;
    wire                        input_buf_rd_valid;
    
    // 权重缓存信号
    wire                        weight_buf_wr_en_axi;
    wire [WEIGHT_BUF_ADDR_WIDTH-1:0] weight_buf_wr_addr_axi;
    wire [DATA_WIDTH-1:0]       weight_buf_wr_data_axi;
    wire                        weight_buf_rd_en_ctrl;
    wire [WEIGHT_BUF_ADDR_WIDTH-1:0] weight_buf_rd_addr;
    wire [DATA_WIDTH-1:0]       weight_buf_rd_data;
    wire                        weight_buf_rd_valid;
    
    // 输出缓存信号
    wire                        output_buf_wr_en_ctrl;
    wire [OUTPUT_BUF_ADDR_WIDTH-1:0] output_buf_wr_addr;
    wire [DATA_WIDTH-1:0]       output_buf_wr_data;
    wire                        output_buf_rd_en_axi;
    wire [OUTPUT_BUF_ADDR_WIDTH-1:0] output_buf_rd_addr_axi;
    wire [DATA_WIDTH-1:0]       output_buf_rd_data;
    wire                        output_buf_rd_valid;
    
    // 矩阵乘法单元信号
    wire                        mmu_start;
    wire                        mmu_clear;
    wire                        mmu_done;
    wire                        mmu_busy;
    wire [DATA_WIDTH-1:0]       mmu_input_data [0:MATRIX_SIZE-1];
    wire                        mmu_input_valid;
    wire [DATA_WIDTH-1:0]       mmu_weight_data [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    wire                        mmu_weight_valid;
    wire [2*DATA_WIDTH-1:0]     mmu_output_data [0:MATRIX_SIZE-1];
    wire                        mmu_output_valid;
    
    // 激活函数单元信号
    wire [1:0]                  act_type;
    wire [DATA_WIDTH-1:0]       act_output_data [0:MATRIX_SIZE-1];
    wire                        act_output_valid;
    
    // =========================================================================
    // AXI接口模块实例化
    // =========================================================================
    axi_interface #(
        .AXI_ADDR_WIDTH         (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH         (AXI_DATA_WIDTH),
        .DATA_WIDTH             (DATA_WIDTH),
        .INPUT_BUF_ADDR_WIDTH   (INPUT_BUF_ADDR_WIDTH),
        .WEIGHT_BUF_ADDR_WIDTH  (WEIGHT_BUF_ADDR_WIDTH),
        .OUTPUT_BUF_ADDR_WIDTH  (OUTPUT_BUF_ADDR_WIDTH)
    ) u_axi_interface (
        // AXI信号
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
        
        // 控制寄存器
        .ctrl_start             (ctrl_start),
        .ctrl_reset             (ctrl_reset),
        .ctrl_activation        (ctrl_activation),
        .ctrl_matrix_size       (ctrl_matrix_size),
        .status_busy            (status_busy),
        .status_done            (status_done),
        .status_error           (status_error),
        .status_state           (status_state),
        .interrupt              (interrupt),
        
        // 缓存接口
        .input_buf_wr_en        (input_buf_wr_en_axi),
        .input_buf_wr_addr      (input_buf_wr_addr_axi),
        .input_buf_wr_data      (input_buf_wr_data_axi),
        .weight_buf_wr_en       (weight_buf_wr_en_axi),
        .weight_buf_wr_addr     (weight_buf_wr_addr_axi),
        .weight_buf_wr_data     (weight_buf_wr_data_axi),
        .output_buf_rd_en       (output_buf_rd_en_axi),
        .output_buf_rd_addr     (output_buf_rd_addr_axi),
        .output_buf_rd_data     (output_buf_rd_data),
        .output_buf_rd_valid    (output_buf_rd_valid)
    );
    
    // =========================================================================
    // 控制单元实例化
    // =========================================================================
    control_unit #(
        .MATRIX_SIZE            (MATRIX_SIZE)
    ) u_control_unit (
        .clk                    (aclk),
        .rst_n                  (aresetn),
        
        // 寄存器接口
        .start                  (ctrl_start),
        .soft_reset             (ctrl_reset),
        .activation_type        (ctrl_activation),
        .matrix_size            (ctrl_matrix_size),
        
        // 状态输出
        .busy                   (status_busy),
        .done                   (status_done),
        .error                  (status_error),
        .current_state          (status_state),
        
        // 矩阵乘法单元控制
        .mmu_start              (mmu_start),
        .mmu_clear              (mmu_clear),
        .mmu_done               (mmu_done),
        .mmu_busy               (mmu_busy),
        
        // 激活函数单元控制
        .act_type               (act_type),
        .act_valid              (act_output_valid),
        
        // 缓存控制
        .input_buf_rd_en        (input_buf_rd_en_ctrl),
        .weight_buf_rd_en       (weight_buf_rd_en_ctrl),
        .output_buf_wr_en       (output_buf_wr_en_ctrl),
        
        // 中断信号
        .interrupt              (interrupt)
    );
    
    // =========================================================================
    // 输入缓存实例化
    // =========================================================================
    input_buffer #(
        .DATA_WIDTH             (DATA_WIDTH),
        .BUFFER_DEPTH           (INPUT_BUF_DEPTH),
        .ADDR_WIDTH             (INPUT_BUF_ADDR_WIDTH)
    ) u_input_buffer (
        .clk                    (aclk),
        .rst_n                  (aresetn),
        
        // 写端口（AXI）
        .wr_en                  (input_buf_wr_en_axi),
        .wr_addr                (input_buf_wr_addr_axi),
        .wr_data                (input_buf_wr_data_axi),
        
        // 读端口（控制单元）
        .rd_en                  (input_buf_rd_en_ctrl),
        .rd_addr                (input_buf_rd_addr),
        .rd_data                (input_buf_rd_data),
        .rd_valid               (input_buf_rd_valid)
    );
    
    // =========================================================================
    // 权重缓存实例化
    // =========================================================================
    weight_buffer #(
        .DATA_WIDTH             (DATA_WIDTH),
        .BUFFER_DEPTH           (WEIGHT_BUF_DEPTH),
        .ADDR_WIDTH             (WEIGHT_BUF_ADDR_WIDTH)
    ) u_weight_buffer (
        .clk                    (aclk),
        .rst_n                  (aresetn),
        
        // 写端口（AXI）
        .wr_en                  (weight_buf_wr_en_axi),
        .wr_addr                (weight_buf_wr_addr_axi),
        .wr_data                (weight_buf_wr_data_axi),
        
        // 读端口（控制单元）
        .rd_en                  (weight_buf_rd_en_ctrl),
        .rd_addr                (weight_buf_rd_addr),
        .rd_data                (weight_buf_rd_data),
        .rd_valid               (weight_buf_rd_valid)
    );
    
    // =========================================================================
    // 输出缓存实例化
    // =========================================================================
    output_buffer #(
        .DATA_WIDTH             (DATA_WIDTH),
        .BUFFER_DEPTH           (OUTPUT_BUF_DEPTH),
        .ADDR_WIDTH             (OUTPUT_BUF_ADDR_WIDTH)
    ) u_output_buffer (
        .clk                    (aclk),
        .rst_n                  (aresetn),
        
        // 写端口（激活函数单元）
        .wr_en                  (output_buf_wr_en_ctrl),
        .wr_addr                (output_buf_wr_addr),
        .wr_data                (output_buf_wr_data),
        
        // 读端口（AXI）
        .rd_en                  (output_buf_rd_en_axi),
        .rd_addr                (output_buf_rd_addr_axi),
        .rd_data                (output_buf_rd_data),
        .rd_valid               (output_buf_rd_valid)
    );
    
    // =========================================================================
    // 矩阵乘法单元实例化
    // =========================================================================
    matrix_multiply_unit #(
        .DATA_WIDTH             (DATA_WIDTH),
        .MATRIX_SIZE            (MATRIX_SIZE),
        .PE_ARRAY_SIZE          (MATRIX_SIZE)
    ) u_matrix_multiply_unit (
        .clk                    (aclk),
        .rst_n                  (aresetn),
        
        // 控制信号
        .start                  (mmu_start),
        .clear                  (mmu_clear),
        .done                   (mmu_done),
        .busy                   (mmu_busy),
        
        // 输入数据
        .input_data             (mmu_input_data),
        .input_valid            (mmu_input_valid),
        
        // 权重数据
        .weight_data            (mmu_weight_data),
        .weight_valid           (mmu_weight_valid),
        
        // 输出数据
        .output_data            (mmu_output_data),
        .output_valid           (mmu_output_valid)
    );
    
    // =========================================================================
    // 激活函数单元实例化
    // =========================================================================
    activation_unit #(
        .DATA_WIDTH             (DATA_WIDTH),
        .MATRIX_SIZE            (MATRIX_SIZE)
    ) u_activation_unit (
        .clk                    (aclk),
        .rst_n                  (aresetn),
        
        // 控制信号
        .activation_type        (act_type),
        
        // 输入数据（来自矩阵乘法单元）
        .data_in                (mmu_output_data),
        .data_valid             (mmu_output_valid),
        
        // 输出数据（到输出缓存）
        .data_out               (act_output_data),
        .data_out_valid         (act_output_valid)
    );
    
    // =========================================================================
    // 数据路径连接逻辑
    // =========================================================================
    // 这里需要添加缓存读取地址生成和数据组织逻辑
    // 简化实现：假设数据已经正确组织
    
    // 输入缓存读地址生成（简化）
    assign input_buf_rd_addr = 8'h00;  // 实际应根据计算进度生成
    
    // 权重缓存读地址生成（简化）
    assign weight_buf_rd_addr = 10'h000;  // 实际应根据计算进度生成
    
    // 输出缓存写地址生成（简化）
    assign output_buf_wr_addr = 8'h00;  // 实际应根据计算进度生成
    
    // 矩阵乘法单元输入数据连接
    assign mmu_input_valid = input_buf_rd_valid;
    genvar i, j;
    generate
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin : gen_mmu_input
            assign mmu_input_data[i] = input_buf_rd_data;  // 简化
        end
        
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin : gen_mmu_weight_row
            for (j = 0; j < MATRIX_SIZE; j = j + 1) begin : gen_mmu_weight_col
                assign mmu_weight_data[i][j] = weight_buf_rd_data;  // 简化
            end
        end
    endgenerate
    
    assign mmu_weight_valid = weight_buf_rd_valid;
    
    // 输出缓存写数据连接
    assign output_buf_wr_data = act_output_data[0];  // 简化

endmodule

// =============================================================================
// 模块说明
// =============================================================================
//
// 功能描述：
// NPU顶层模块集成了所有子模块，实现完整的神经网络处理单元功能。
//
// 模块层次：
// npu_top
// ├── axi_interface          - AXI4-Lite总线接口
// ├── control_unit           - 控制状态机
// ├── input_buffer           - 输入数据缓存
// ├── weight_buffer          - 权重数据缓存
// ├── output_buffer          - 输出数据缓存
// ├── matrix_multiply_unit   - 矩阵乘法单元
// │   └── processing_element - 处理单元阵列（8x8）
// └── activation_unit        - 激活函数单元
//
// 数据流：
// 1. AXI接口接收输入数据和权重，写入相应缓存
// 2. 控制单元启动计算流程
// 3. 矩阵乘法单元从缓存读取数据，执行MAC运算
// 4. 激活函数单元对结果应用非线性函数
// 5. 结果写入输出缓存
// 6. AXI接口读取结果返回给主机
//
// 控制流：
// 1. 软件通过AXI写入配置寄存器
// 2. 软件启动计算（写入CTRL_REG）
// 3. 控制单元协调各模块工作
// 4. 计算完成后产生中断
// 5. 软件读取结果
//
// 参数配置：
// - DATA_WIDTH: 数据位宽（默认16位）
// - MATRIX_SIZE: 矩阵维度（默认8x8）
// - 缓存深度可配置
//
// 接口：
// - AXI4-Lite从设备接口（标准）
// - 中断输出（计算完成/错误）
//
// 时钟域：
// - 单时钟域设计（aclk）
// - 所有模块使用相同时钟
//
// 复位：
// - 异步复位，同步释放
// - 支持软复位（通过寄存器）
//
// 性能：
// - 吞吐量：8个MAC/周期
// - 延迟：约10-20个周期（取决于矩阵大小）
// - 频率：设计目标100MHz
//
// 注意事项：
// 1. 当前实现中的数据路径连接是简化版本
// 2. 实际应用需要添加完整的地址生成逻辑
// 3. 需要添加数据重组和对齐逻辑
// 4. 建议添加FIFO缓冲以提高性能
//
// 扩展方向：
// 1. 添加DMA控制器，减少CPU干预
// 2. 支持更大的矩阵（分块计算）
// 3. 添加多层网络自动执行功能
// 4. 支持量化和混合精度
// 5. 添加性能监控计数器
//
// =============================================================================
