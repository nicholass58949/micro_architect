// =============================================================================
// 文件名: datapath_controller.v
// 功能: 数据路径控制器 - 管理缓存地址生成和数据组织
// 描述: 自动生成读写地址，组织数据流
// =============================================================================

module datapath_controller #(
    parameter DATA_WIDTH = 16,
    parameter MATRIX_SIZE = 8,
    parameter INPUT_ADDR_WIDTH = 8,
    parameter WEIGHT_ADDR_WIDTH = 10,
    parameter OUTPUT_ADDR_WIDTH = 8
)(
    // 时钟和复位
    input  wire                         clk,
    input  wire                         rst_n,
    
    // 控制信号
    input  wire                         start,
    input  wire                         clear,
    output reg                          done,
    output reg                          busy,
    
    // 配置
    input  wire [7:0]                   matrix_size,
    
    // 输入缓存接口
    output reg                          input_buf_rd_en,
    output reg  [INPUT_ADDR_WIDTH-1:0]  input_buf_rd_addr,
    input  wire [DATA_WIDTH-1:0]        input_buf_rd_data,
    input  wire                         input_buf_rd_valid,
    
    // 权重缓存接口
    output reg                          weight_buf_rd_en,
    output reg  [WEIGHT_ADDR_WIDTH-1:0] weight_buf_rd_addr,
    input  wire [DATA_WIDTH-1:0]        weight_buf_rd_data,
    input  wire                         weight_buf_rd_valid,
    
    // 输出缓存接口
    output reg                          output_buf_wr_en,
    output reg  [OUTPUT_ADDR_WIDTH-1:0] output_buf_wr_addr,
    output reg  [DATA_WIDTH-1:0]        output_buf_wr_data,
    
    // 矩阵乘法单元接口（简化为单个端口）
    output reg  [DATA_WIDTH-1:0]        mmu_input_data,
    output reg  [2:0]                   mmu_input_index,
    output reg                          mmu_input_valid,
    output reg  [DATA_WIDTH-1:0]        mmu_weight_data,
    output reg  [3:0]                   mmu_weight_row,
    output reg  [3:0]                   mmu_weight_col,
    output reg                          mmu_weight_valid,
    
    // 激活函数单元接口
    input  wire [DATA_WIDTH-1:0]        act_output_data,
    input  wire                         act_output_valid
);

    // =========================================================================
    // 简化实现：直接传递信号，不做缓存管理
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            busy <= 1'b0;
            input_buf_rd_en <= 1'b0;
            weight_buf_rd_en <= 1'b0;
            output_buf_wr_en <= 1'b0;
            mmu_input_valid <= 1'b0;
            mmu_weight_valid <= 1'b0;
        end else if (clear) begin
            done <= 1'b0;
            busy <= 1'b0;
            mmu_input_valid <= 1'b0;
            mmu_weight_valid <= 1'b0;
        end else if (start) begin
            busy <= 1'b1;
            // 启用所有缓存读取
            input_buf_rd_en <= 1'b1;
            weight_buf_rd_en <= 1'b1;
            
            // 直接传递数据
            if (input_buf_rd_valid) begin
                mmu_input_data <= input_buf_rd_data;
                mmu_input_valid <= 1'b1;
            end
            
            if (weight_buf_rd_valid) begin
                mmu_weight_data <= weight_buf_rd_data;
                mmu_weight_valid <= 1'b1;
            end
            
            if (act_output_valid) begin
                output_buf_wr_en <= 1'b1;
                output_buf_wr_data <= act_output_data;
                done <= 1'b1;
                busy <= 1'b0;
            end
        end
    end

endmodule

// =============================================================================
// 模块说明
// =============================================================================
//
// 简化的数据路径控制器 - 学习版本
//
// 此版本进行了大幅简化，用于教学目的：
// - 移除了复杂的状态机
// - 移除了详细的地址管理
// - 直接传递信号，最小化延迟
// - 易于理解和修改
//
//
// =============================================================================
