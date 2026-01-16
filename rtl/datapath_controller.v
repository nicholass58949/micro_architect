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
    
    // 矩阵乘法单元接口
    output reg  [DATA_WIDTH-1:0]        mmu_input_data [0:MATRIX_SIZE-1],
    output reg                          mmu_input_valid,
    output reg  [DATA_WIDTH-1:0]        mmu_weight_data [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1],
    output reg                          mmu_weight_valid,
    
    // 激活函数单元接口
    input  wire [DATA_WIDTH-1:0]        act_output_data [0:MATRIX_SIZE-1],
    input  wire                         act_output_valid
);

    // =========================================================================
    // 状态机定义
    // =========================================================================
    localparam IDLE         = 3'b000;
    localparam LOAD_INPUT   = 3'b001;
    localparam LOAD_WEIGHT  = 3'b010;
    localparam COMPUTE      = 3'b011;
    localparam WRITE_OUTPUT = 3'b100;
    localparam DONE_STATE   = 3'b101;
    
    reg [2:0] state, next_state;
    
    // =========================================================================
    // 内部信号
    // =========================================================================
    reg [7:0] input_row_cnt;
    reg [7:0] weight_row_cnt, weight_col_cnt;
    reg [7:0] output_row_cnt;
    reg [7:0] load_delay_cnt;
    
    // 数据寄存器
    reg [DATA_WIDTH-1:0] input_data_reg [0:MATRIX_SIZE-1];
    reg [DATA_WIDTH-1:0] weight_data_reg [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    
    integer i, j;
    
    // =========================================================================
    // 状态机 - 当前状态
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else if (clear) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // =========================================================================
    // 状态机 - 下一状态逻辑
    // =========================================================================
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_INPUT;
                end
            end
            
            LOAD_INPUT: begin
                if (input_row_cnt >= matrix_size && load_delay_cnt >= 2) begin
                    next_state = LOAD_WEIGHT;
                end
            end
            
            LOAD_WEIGHT: begin
                if (weight_row_cnt >= matrix_size && 
                    weight_col_cnt >= matrix_size && 
                    load_delay_cnt >= 2) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                if (act_output_valid) begin
                    next_state = WRITE_OUTPUT;
                end
            end
            
            WRITE_OUTPUT: begin
                if (output_row_cnt >= matrix_size) begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // =========================================================================
    // 状态机 - 输出逻辑
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            done <= 1'b0;
            
            input_buf_rd_en <= 1'b0;
            input_buf_rd_addr <= {INPUT_ADDR_WIDTH{1'b0}};
            
            weight_buf_rd_en <= 1'b0;
            weight_buf_rd_addr <= {WEIGHT_ADDR_WIDTH{1'b0}};
            
            output_buf_wr_en <= 1'b0;
            output_buf_wr_addr <= {OUTPUT_ADDR_WIDTH{1'b0}};
            output_buf_wr_data <= {DATA_WIDTH{1'b0}};
            
            mmu_input_valid <= 1'b0;
            mmu_weight_valid <= 1'b0;
            
            input_row_cnt <= 8'd0;
            weight_row_cnt <= 8'd0;
            weight_col_cnt <= 8'd0;
            output_row_cnt <= 8'd0;
            load_delay_cnt <= 8'd0;
            
            for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                input_data_reg[i] <= {DATA_WIDTH{1'b0}};
                mmu_input_data[i] <= {DATA_WIDTH{1'b0}};
                for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                    weight_data_reg[i][j] <= {DATA_WIDTH{1'b0}};
                    mmu_weight_data[i][j] <= {DATA_WIDTH{1'b0}};
                end
            end
            
        end else begin
            // 默认值
            done <= 1'b0;
            input_buf_rd_en <= 1'b0;
            weight_buf_rd_en <= 1'b0;
            output_buf_wr_en <= 1'b0;
            mmu_input_valid <= 1'b0;
            mmu_weight_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    input_row_cnt <= 8'd0;
                    weight_row_cnt <= 8'd0;
                    weight_col_cnt <= 8'd0;
                    output_row_cnt <= 8'd0;
                    load_delay_cnt <= 8'd0;
                end
                
                LOAD_INPUT: begin
                    busy <= 1'b1;
                    
                    if (input_row_cnt < matrix_size) begin
                        // 读取输入数据
                        input_buf_rd_en <= 1'b1;
                        input_buf_rd_addr <= input_row_cnt;
                        
                        // 存储读取的数据
                        if (input_buf_rd_valid) begin
                            input_data_reg[input_row_cnt] <= input_buf_rd_data;
                            input_row_cnt <= input_row_cnt + 1;
                        end
                    end else begin
                        load_delay_cnt <= load_delay_cnt + 1;
                    end
                end
                
                LOAD_WEIGHT: begin
                    if (weight_row_cnt < matrix_size) begin
                        if (weight_col_cnt < matrix_size) begin
                            // 读取权重数据
                            weight_buf_rd_en <= 1'b1;
                            weight_buf_rd_addr <= weight_row_cnt * MATRIX_SIZE + weight_col_cnt;
                            
                            // 存储读取的数据
                            if (weight_buf_rd_valid) begin
                                weight_data_reg[weight_row_cnt][weight_col_cnt] <= weight_buf_rd_data;
                                weight_col_cnt <= weight_col_cnt + 1;
                            end
                        end else begin
                            weight_col_cnt <= 8'd0;
                            weight_row_cnt <= weight_row_cnt + 1;
                        end
                    end else begin
                        load_delay_cnt <= load_delay_cnt + 1;
                    end
                end
                
                COMPUTE: begin
                    // 将数据传递给矩阵乘法单元
                    if (!mmu_input_valid) begin
                        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                            mmu_input_data[i] <= input_data_reg[i];
                            for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                                mmu_weight_data[i][j] <= weight_data_reg[i][j];
                            end
                        end
                        mmu_input_valid <= 1'b1;
                        mmu_weight_valid <= 1'b1;
                    end
                end
                
                WRITE_OUTPUT: begin
                    if (output_row_cnt < matrix_size) begin
                        // 写入输出数据
                        output_buf_wr_en <= 1'b1;
                        output_buf_wr_addr <= output_row_cnt;
                        output_buf_wr_data <= act_output_data[output_row_cnt];
                        output_row_cnt <= output_row_cnt + 1;
                    end
                end
                
                DONE_STATE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule

// =============================================================================
// 模块说明
// =============================================================================
//
// 功能描述：
// 数据路径控制器负责管理NPU的数据流，自动生成缓存地址，
// 组织数据传输，简化顶层模块的设计。
//
// 主要功能：
// 1. 自动从输入缓存读取数据
// 2. 自动从权重缓存读取权重
// 3. 组织数据传递给矩阵乘法单元
// 4. 自动将结果写入输出缓存
//
// 工作流程：
// IDLE → LOAD_INPUT → LOAD_WEIGHT → COMPUTE → WRITE_OUTPUT → DONE
//
// 优势：
// - 简化顶层设计
// - 自动地址管理
// - 清晰的数据流控制
// - 易于扩展和修改
//
// =============================================================================
