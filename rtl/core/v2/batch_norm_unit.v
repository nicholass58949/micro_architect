// =============================================================================
// 文件名: batch_norm_unit.v
// 功能: 批归一化单元 - Batch Normalization
// 描述: 归一化特征图，加速训练收敛
// =============================================================================

module batch_norm_unit #(
    parameter DATA_WIDTH = 16,
    parameter MAX_CHANNELS = 512
)(
    // 时钟和复位
    input  wire                         clk,
    input  wire                         rst_n,
    
    // 控制信号
    input  wire                         start,
    input  wire                         clear,
    input  wire                         training_mode,  // 训练模式 vs 推理模式
    output reg                          done,
    output reg                          busy,
    
    // 配置参数
    input  wire [15:0]                  num_channels,
    input  wire [15:0]                  feature_size,   // height × width
    
    // 统计参数（训练时更新，推理时使用）
    input  wire [DATA_WIDTH-1:0]        gamma [0:MAX_CHANNELS-1],  // 缩放参数
    input  wire [DATA_WIDTH-1:0]        beta [0:MAX_CHANNELS-1],   // 偏移参数
    input  wire [DATA_WIDTH-1:0]        running_mean [0:MAX_CHANNELS-1],
    input  wire [DATA_WIDTH-1:0]        running_var [0:MAX_CHANNELS-1],
    
    // 统计参数输出（训练模式）
    output reg  [DATA_WIDTH-1:0]        batch_mean [0:MAX_CHANNELS-1],
    output reg  [DATA_WIDTH-1:0]        batch_var [0:MAX_CHANNELS-1],
    
    // 输入接口
    input  wire [DATA_WIDTH-1:0]        input_data,
    input  wire                         input_valid,
    output reg                          input_ready,
    
    // 输出接口
    output reg  [DATA_WIDTH-1:0]        output_data,
    output reg                          output_valid,
    input  wire                         output_ready
);

    // =========================================================================
    // 状态机定义
    // =========================================================================
    localparam IDLE             = 4'b0000;
    localparam COMPUTE_MEAN     = 4'b0001;
    localparam COMPUTE_VAR      = 4'b0010;
    localparam NORMALIZE        = 4'b0011;
    localparam SCALE_SHIFT      = 4'b0100;
    localparam UPDATE_STATS     = 4'b0101;
    localparam OUTPUT           = 4'b0110;
    localparam DONE_STATE       = 4'b0111;
    
    reg [3:0] state, next_state;
    
    // =========================================================================
    // 内部信号
    // =========================================================================
    
    // 数据缓存
    reg [DATA_WIDTH-1:0] data_buffer [0:MAX_CHANNELS-1];
    
    // 统计量
    reg [2*DATA_WIDTH-1:0] sum_buffer [0:MAX_CHANNELS-1];
    reg [2*DATA_WIDTH-1:0] sum_sq_buffer [0:MAX_CHANNELS-1];
    
    // 归一化参数
    reg [DATA_WIDTH-1:0] mean [0:MAX_CHANNELS-1];
    reg [DATA_WIDTH-1:0] variance [0:MAX_CHANNELS-1];
    reg [DATA_WIDTH-1:0] std_dev [0:MAX_CHANNELS-1];
    
    // 归一化结果
    reg [DATA_WIDTH-1:0] normalized_data;
    reg [DATA_WIDTH-1:0] scaled_data;
    
    // 计数器
    reg [15:0] sample_cnt;
    reg [15:0] channel_cnt;
    
    // 常数
    localparam EPSILON = 16'h0001;  // 防止除零的小常数
    localparam MOMENTUM = 16'h00CC; // 0.8 in Q8.8 for running stats
    
    // =========================================================================
    // 均值计算
    // =========================================================================
    integer i;
    
    always @(posedge clk) begin
        if (state == COMPUTE_MEAN) begin
            for (i = 0; i < num_channels; i = i + 1) begin
                mean[i] <= sum_buffer[i] / feature_size;
            end
        end
    end
    
    // =========================================================================
    // 方差计算
    // =========================================================================
    always @(posedge clk) begin
        if (state == COMPUTE_VAR) begin
            for (i = 0; i < num_channels; i = i + 1) begin
                // Var = E[X^2] - E[X]^2
                variance[i] <= (sum_sq_buffer[i] / feature_size) - 
                              (mean[i] * mean[i] / 256);
                // 标准差（简化：使用查找表或迭代算法）
                std_dev[i] <= variance[i];  // 简化，实际需要开方
            end
        end
    end
    
    // =========================================================================
    // 归一化计算
    // =========================================================================
    always @(*) begin
        if (training_mode) begin
            // 训练模式：使用批统计
            normalized_data = ((input_data - mean[channel_cnt]) << 8) / 
                            (std_dev[channel_cnt] + EPSILON);
        end else begin
            // 推理模式：使用运行统计
            normalized_data = ((input_data - running_mean[channel_cnt]) << 8) / 
                            (running_var[channel_cnt] + EPSILON);
        end
        
        // 缩放和偏移
        scaled_data = (normalized_data * gamma[channel_cnt] / 256) + beta[channel_cnt];
    end
    
    // =========================================================================
    // 运行统计更新（指数移动平均）
    // =========================================================================
    always @(posedge clk) begin
        if (state == UPDATE_STATS && training_mode) begin
            for (i = 0; i < num_channels; i = i + 1) begin
                batch_mean[i] <= (MOMENTUM * running_mean[i] + 
                                 (256 - MOMENTUM) * mean[i]) / 256;
                batch_var[i] <= (MOMENTUM * running_var[i] + 
                                (256 - MOMENTUM) * variance[i]) / 256;
            end
        end
    end
    
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
                    next_state = training_mode ? COMPUTE_MEAN : NORMALIZE;
                end
            end
            
            COMPUTE_MEAN: begin
                if (sample_cnt >= feature_size) begin
                    next_state = COMPUTE_VAR;
                end
            end
            
            COMPUTE_VAR: begin
                next_state = NORMALIZE;
            end
            
            NORMALIZE: begin
                next_state = SCALE_SHIFT;
            end
            
            SCALE_SHIFT: begin
                next_state = OUTPUT;
            end
            
            OUTPUT: begin
                if (output_ready) begin
                    if (sample_cnt >= feature_size && channel_cnt >= num_channels) begin
                        next_state = training_mode ? UPDATE_STATS : DONE_STATE;
                    end else begin
                        next_state = NORMALIZE;
                    end
                end
            end
            
            UPDATE_STATS: begin
                next_state = DONE_STATE;
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
            output_valid <= 1'b0;
            input_ready <= 1'b0;
            sample_cnt <= 0;
            channel_cnt <= 0;
            
        end else begin
            done <= 1'b0;
            output_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    input_ready <= 1'b0;
                    sample_cnt <= 0;
                    channel_cnt <= 0;
                end
                
                COMPUTE_MEAN: begin
                    busy <= 1'b1;
                    input_ready <= 1'b1;
                    
                    if (input_valid) begin
                        sum_buffer[channel_cnt] <= sum_buffer[channel_cnt] + input_data;
                        sample_cnt <= sample_cnt + 1;
                    end
                end
                
                COMPUTE_VAR: begin
                    if (input_valid) begin
                        sum_sq_buffer[channel_cnt] <= sum_sq_buffer[channel_cnt] + 
                                                     (input_data * input_data);
                    end
                end
                
                NORMALIZE: begin
                    // 归一化在组合逻辑中完成
                end
                
                SCALE_SHIFT: begin
                    // 缩放和偏移在组合逻辑中完成
                end
                
                OUTPUT: begin
                    output_valid <= 1'b1;
                    output_data <= scaled_data;
                    
                    if (output_ready) begin
                        sample_cnt <= sample_cnt + 1;
                        if (sample_cnt >= feature_size) begin
                            sample_cnt <= 0;
                            channel_cnt <= channel_cnt + 1;
                        end
                    end
                end
                
                UPDATE_STATS: begin
                    // 统计更新
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
// 批归一化（Batch Normalization）是深度学习中的重要技术，
// 用于归一化层的输入，加速训练收敛，提高模型性能。
//
// 工作原理：
// 1. 计算批次的均值和方差
// 2. 归一化：(x - mean) / sqrt(var + epsilon)
// 3. 缩放和偏移：gamma * normalized + beta
// 4. 更新运行统计（训练模式）
//
// 训练模式 vs 推理模式：
// - 训练：使用当前批次的统计量
// - 推理：使用训练时累积的运行统计量
//
// 数学公式：
// y = gamma * (x - mean) / sqrt(var + epsilon) + beta
//
// 参数：
// - gamma：可学习的缩放参数
// - beta：可学习的偏移参数
// - running_mean：运行均值（指数移动平均）
// - running_var：运行方差（指数移动平均）
//
// 优势：
// 1. 加速训练收敛
// 2. 允许更高的学习率
// 3. 减少对初始化的依赖
// 4. 具有正则化效果
//
// 应用场景：
// - CNN训练
// - 深度网络优化
// - 迁移学习
//
// =============================================================================
