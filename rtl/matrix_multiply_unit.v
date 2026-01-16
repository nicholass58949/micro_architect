// =============================================================================
// 文件名: matrix_multiply_unit.v
// 功能: 矩阵乘法单元 - NPU的核心计算引擎
// 描述: 使用PE阵列实现高效的矩阵乘法运算
// =============================================================================

module matrix_multiply_unit #(
    parameter DATA_WIDTH = 16,      // 数据位宽
    parameter MATRIX_SIZE = 8,      // 矩阵维度（8x8）
    parameter PE_ARRAY_SIZE = 8     // PE阵列大小
)(
    // 时钟和复位
    input  wire                             clk,
    input  wire                             rst_n,
    
    // 控制信号
    input  wire                             start,          // 开始计算
    input  wire                             clear,          // 清除累加器
    output reg                              done,           // 计算完成
    output reg                              busy,           // 忙标志
    
    // 输入数据接口（从输入缓存）
    input  wire [DATA_WIDTH-1:0]            input_data [0:MATRIX_SIZE-1],
    input  wire                             input_valid,
    
    // 权重数据接口（从权重缓存）
    input  wire [DATA_WIDTH-1:0]            weight_data [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1],
    input  wire                             weight_valid,
    
    // 输出数据接口（到激活函数单元）
    output reg  [2*DATA_WIDTH-1:0]          output_data [0:MATRIX_SIZE-1],
    output reg                              output_valid
);

    // =========================================================================
    // 内部信号定义
    // =========================================================================
    
    // PE阵列信号
    wire [DATA_WIDTH-1:0]       pe_data_in [0:PE_ARRAY_SIZE-1][0:PE_ARRAY_SIZE-1];
    wire [DATA_WIDTH-1:0]       pe_data_out [0:PE_ARRAY_SIZE-1][0:PE_ARRAY_SIZE-1];
    wire [DATA_WIDTH-1:0]       pe_weight_in [0:PE_ARRAY_SIZE-1][0:PE_ARRAY_SIZE-1];
    wire [2*DATA_WIDTH-1:0]     pe_acc_out [0:PE_ARRAY_SIZE-1][0:PE_ARRAY_SIZE-1];
    
    // 控制信号
    reg                         pe_enable;
    reg                         pe_clear_acc;
    
    // 状态机
    localparam IDLE         = 3'b000;
    localparam LOAD_DATA    = 3'b001;
    localparam COMPUTE      = 3'b010;
    localparam ACCUMULATE   = 3'b011;
    localparam OUTPUT       = 3'b100;
    
    reg [2:0]                   state, next_state;
    
    // 计数器
    reg [$clog2(MATRIX_SIZE+1)-1:0] row_cnt;
    reg [$clog2(MATRIX_SIZE+1)-1:0] col_cnt;
    reg [$clog2(MATRIX_SIZE+1)-1:0] compute_cnt;
    
    // 输入数据寄存器
    reg [DATA_WIDTH-1:0]        input_reg [0:MATRIX_SIZE-1];
    reg [DATA_WIDTH-1:0]        weight_reg [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    
    // =========================================================================
    // PE阵列实例化
    // =========================================================================
    // 创建一个8x8的PE阵列，形成脉动阵列结构
    
    genvar i, j;
    generate
        for (i = 0; i < PE_ARRAY_SIZE; i = i + 1) begin : gen_pe_row
            for (j = 0; j < PE_ARRAY_SIZE; j = j + 1) begin : gen_pe_col
                processing_element #(
                    .DATA_WIDTH(DATA_WIDTH)
                ) pe_inst (
                    .clk        (clk),
                    .rst_n      (rst_n),
                    .enable     (pe_enable),
                    .clear_acc  (pe_clear_acc),
                    .data_in    (pe_data_in[i][j]),
                    .weight_in  (pe_weight_in[i][j]),
                    .data_out   (pe_data_out[i][j]),
                    .acc_out    (pe_acc_out[i][j])
                );
            end
        end
    endgenerate
    
    // =========================================================================
    // PE阵列数据流连接
    // =========================================================================
    // 脉动阵列：数据从左到右流动，权重保持不变
    
    integer m, n;
    
    always @(*) begin
        // 默认值
        for (m = 0; m < PE_ARRAY_SIZE; m = m + 1) begin
            for (n = 0; n < PE_ARRAY_SIZE; n = n + 1) begin
                pe_data_in[m][n] = {DATA_WIDTH{1'b0}};
                pe_weight_in[m][n] = {DATA_WIDTH{1'b0}};
            end
        end
        
        // 连接数据流
        if (state == COMPUTE) begin
            // 第一列PE接收输入数据
            for (m = 0; m < PE_ARRAY_SIZE; m = m + 1) begin
                pe_data_in[m][0] = input_reg[m];
            end
            
            // 其他PE接收前一个PE的输出
            for (m = 0; m < PE_ARRAY_SIZE; m = m + 1) begin
                for (n = 1; n < PE_ARRAY_SIZE; n = n + 1) begin
                    pe_data_in[m][n] = pe_data_out[m][n-1];
                end
            end
            
            // 权重数据
            for (m = 0; m < PE_ARRAY_SIZE; m = m + 1) begin
                for (n = 0; n < PE_ARRAY_SIZE; n = n + 1) begin
                    pe_weight_in[m][n] = weight_reg[m][n];
                end
            end
        end
    end
    
    // =========================================================================
    // 状态机 - 当前状态寄存器
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
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
                if (start && input_valid && weight_valid) begin
                    next_state = LOAD_DATA;
                end
            end
            
            LOAD_DATA: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (compute_cnt >= MATRIX_SIZE) begin
                    next_state = ACCUMULATE;
                end
            end
            
            ACCUMULATE: begin
                next_state = OUTPUT;
            end
            
            OUTPUT: begin
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
            output_valid <= 1'b0;
            pe_enable <= 1'b0;
            pe_clear_acc <= 1'b0;
            compute_cnt <= 0;
            row_cnt <= 0;
            col_cnt <= 0;
        end else begin
            // 默认值
            done <= 1'b0;
            output_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    pe_enable <= 1'b0;
                    pe_clear_acc <= 1'b0;
                    compute_cnt <= 0;
                end
                
                LOAD_DATA: begin
                    busy <= 1'b1;
                    pe_clear_acc <= 1'b1;  // 清除累加器
                    // 加载输入数据和权重
                    for (row_cnt = 0; row_cnt < MATRIX_SIZE; row_cnt = row_cnt + 1) begin
                        input_reg[row_cnt] <= input_data[row_cnt];
                        for (col_cnt = 0; col_cnt < MATRIX_SIZE; col_cnt = col_cnt + 1) begin
                            weight_reg[row_cnt][col_cnt] <= weight_data[row_cnt][col_cnt];
                        end
                    end
                end
                
                COMPUTE: begin
                    pe_clear_acc <= 1'b0;
                    pe_enable <= 1'b1;
                    compute_cnt <= compute_cnt + 1;
                end
                
                ACCUMULATE: begin
                    pe_enable <= 1'b0;
                    // 等待最后的累加完成
                end
                
                OUTPUT: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    output_valid <= 1'b1;
                    // 输出结果（每行的第一个PE的累加结果）
                    for (row_cnt = 0; row_cnt < MATRIX_SIZE; row_cnt = row_cnt + 1) begin
                        output_data[row_cnt] <= pe_acc_out[row_cnt][MATRIX_SIZE-1];
                    end
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
// 矩阵乘法单元是NPU的核心计算引擎，使用PE阵列实现高效的矩阵乘法。
// 采用脉动阵列（Systolic Array）架构，数据从左到右流动。
//
// 工作原理：
// 1. IDLE状态：等待start信号
// 2. LOAD_DATA状态：加载输入数据和权重到内部寄存器
// 3. COMPUTE状态：PE阵列执行矩阵乘法运算
// 4. ACCUMULATE状态：等待累加完成
// 5. OUTPUT状态：输出计算结果
//
// 脉动阵列结构：
// - 8x8的PE阵列
// - 输入数据从左侧进入，向右流动
// - 权重数据固定在每个PE中
// - 每个PE执行一次乘累加运算
//
// 计算过程：
// 对于矩阵乘法 C = A × B
// - A: 输入矩阵（1×8）
// - B: 权重矩阵（8×8）
// - C: 输出矩阵（1×8）
// 每个输出元素 C[i] = Σ(A[j] × B[j][i])
//
// 性能：
// - 吞吐量：每周期8个MAC操作
// - 延迟：约8个周期（矩阵维度）
// - 可扩展到更大的矩阵
//
// 接口协议：
// - start: 上升沿触发计算开始
// - input_valid/weight_valid: 数据有效标志
// - done: 计算完成脉冲信号
// - busy: 计算过程中保持高电平
// - output_valid: 输出数据有效标志
//
// =============================================================================
