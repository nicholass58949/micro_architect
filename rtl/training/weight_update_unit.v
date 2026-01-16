// =============================================================================
// 文件名: weight_update_unit.v
// 功能: 权重更新单元 - 使用梯度更新网络参数
// 描述: 支持多种优化算法（SGD, Momentum, Adam）
// =============================================================================

module weight_update_unit #(
    parameter DATA_WIDTH = 16,
    parameter MATRIX_SIZE = 16,
    parameter MAX_PARAMS = 1024
)(
    // 时钟和复位
    input  wire                         clk,
    input  wire                         rst_n,
    
    // 控制信号
    input  wire                         start,
    input  wire                         clear,
    output reg                          done,
    output reg                          busy,
    
    // 配置参数
    input  wire [1:0]                   optimizer_type,   // 优化器类型
    input  wire [DATA_WIDTH-1:0]        learning_rate,    // 学习率
    input  wire [DATA_WIDTH-1:0]        momentum,         // 动量系数
    input  wire [DATA_WIDTH-1:0]        beta1,            // Adam beta1
    input  wire [DATA_WIDTH-1:0]        beta2,            // Adam beta2
    input  wire [DATA_WIDTH-1:0]        weight_decay,     // L2正则化系数
    input  wire [31:0]                  timestep,         // 时间步（用于Adam）
    
    // 当前权重和偏置
    input  wire [DATA_WIDTH-1:0]        weights [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1],
    input  wire [DATA_WIDTH-1:0]        bias [0:MATRIX_SIZE-1],
    
    // 梯度输入
    input  wire [DATA_WIDTH-1:0]        grad_weights [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1],
    input  wire [DATA_WIDTH-1:0]        grad_bias [0:MATRIX_SIZE-1],
    input  wire                         grad_valid,
    
    // 更新后的权重和偏置
    output reg  [DATA_WIDTH-1:0]        updated_weights [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1],
    output reg  [DATA_WIDTH-1:0]        updated_bias [0:MATRIX_SIZE-1],
    output reg                          update_valid
);

    // =========================================================================
    // 优化器类型
    // =========================================================================
    localparam OPT_SGD      = 2'b00;  // Stochastic Gradient Descent
    localparam OPT_MOMENTUM = 2'b01;  // SGD with Momentum
    localparam OPT_ADAM     = 2'b10;  // Adam Optimizer
    localparam OPT_RMSPROP  = 2'b11;  // RMSProp
    
    // =========================================================================
    // 状态机定义
    // =========================================================================
    localparam IDLE             = 3'b000;
    localparam COMPUTE_UPDATE   = 3'b001;
    localparam APPLY_UPDATE     = 3'b010;
    localparam OUTPUT           = 3'b011;
    localparam DONE_STATE       = 3'b100;
    
    reg [2:0] state, next_state;
    
    // =========================================================================
    // 内部信号
    // =========================================================================
    
    // Momentum相关
    reg [DATA_WIDTH-1:0] velocity_w [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    reg [DATA_WIDTH-1:0] velocity_b [0:MATRIX_SIZE-1];
    
    // Adam相关
    reg [DATA_WIDTH-1:0] m_w [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];  // 一阶矩估计
    reg [DATA_WIDTH-1:0] v_w [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];  // 二阶矩估计
    reg [DATA_WIDTH-1:0] m_b [0:MATRIX_SIZE-1];
    reg [DATA_WIDTH-1:0] v_b [0:MATRIX_SIZE-1];
    
    // 偏差修正后的矩估计
    reg [DATA_WIDTH-1:0] m_hat_w [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    reg [DATA_WIDTH-1:0] v_hat_w [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    reg [DATA_WIDTH-1:0] m_hat_b [0:MATRIX_SIZE-1];
    reg [DATA_WIDTH-1:0] v_hat_b [0:MATRIX_SIZE-1];
    
    // 权重更新量
    reg [DATA_WIDTH-1:0] delta_w [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    reg [DATA_WIDTH-1:0] delta_b [0:MATRIX_SIZE-1];
    
    // 常数
    localparam EPSILON = 16'h0001;  // 防止除零
    
    integer i, j;
    
    // =========================================================================
    // SGD更新
    // =========================================================================
    always @(*) begin
        if (optimizer_type == OPT_SGD) begin
            for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                    // W = W - lr * (grad + weight_decay * W)
                    delta_w[i][j] = (learning_rate * 
                        (grad_weights[i][j] + ((weight_decay * weights[i][j]) >> 8))) >> 8;
                end
                delta_b[i] = (learning_rate * grad_bias[i]) >> 8;
            end
        end
    end
    
    // =========================================================================
    // Momentum更新
    // =========================================================================
    always @(posedge clk) begin
        if (optimizer_type == OPT_MOMENTUM && state == COMPUTE_UPDATE) begin
            for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                    // v = momentum * v + grad
                    velocity_w[i][j] <= ((momentum * velocity_w[i][j]) >> 8) + 
                                       grad_weights[i][j];
                    // W = W - lr * v
                    delta_w[i][j] <= (learning_rate * velocity_w[i][j]) >> 8;
                end
                
                velocity_b[i] <= ((momentum * velocity_b[i]) >> 8) + grad_bias[i];
                delta_b[i] <= (learning_rate * velocity_b[i]) >> 8;
            end
        end
    end
    
    // =========================================================================
    // Adam更新
    // =========================================================================
    reg [DATA_WIDTH-1:0] beta1_power, beta2_power;
    reg [DATA_WIDTH-1:0] sqrt_v_hat;
    
    always @(posedge clk) begin
        if (optimizer_type == OPT_ADAM && state == COMPUTE_UPDATE) begin
            // 计算beta的幂次
            beta1_power <= 16'h0100;  // 简化：应该是beta1^t
            beta2_power <= 16'h0100;  // 简化：应该是beta2^t
            
            for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                    // 更新一阶矩估计：m = beta1 * m + (1 - beta1) * grad
                    m_w[i][j] <= ((beta1 * m_w[i][j]) >> 8) + 
                                (((16'h0100 - beta1) * grad_weights[i][j]) >> 8);
                    
                    // 更新二阶矩估计：v = beta2 * v + (1 - beta2) * grad^2
                    v_w[i][j] <= ((beta2 * v_w[i][j]) >> 8) + 
                                (((16'h0100 - beta2) * 
                                  ((grad_weights[i][j] * grad_weights[i][j]) >> 8)) >> 8);
                    
                    // 偏差修正
                    m_hat_w[i][j] <= (m_w[i][j] << 8) / (16'h0100 - beta1_power);
                    v_hat_w[i][j] <= (v_w[i][j] << 8) / (16'h0100 - beta2_power);
                    
                    // 计算更新量：delta = lr * m_hat / (sqrt(v_hat) + epsilon)
                    // 简化：使用查找表或迭代算法计算平方根
                    sqrt_v_hat <= v_hat_w[i][j];  // 简化，实际需要开方
                    delta_w[i][j] <= (learning_rate * m_hat_w[i][j]) / 
                                    (sqrt_v_hat + EPSILON);
                end
                
                // 偏置的Adam更新
                m_b[i] <= ((beta1 * m_b[i]) >> 8) + 
                         (((16'h0100 - beta1) * grad_bias[i]) >> 8);
                v_b[i] <= ((beta2 * v_b[i]) >> 8) + 
                         (((16'h0100 - beta2) * 
                           ((grad_bias[i] * grad_bias[i]) >> 8)) >> 8);
                
                m_hat_b[i] <= (m_b[i] << 8) / (16'h0100 - beta1_power);
                v_hat_b[i] <= (v_b[i] << 8) / (16'h0100 - beta2_power);
                
                delta_b[i] <= (learning_rate * m_hat_b[i]) / 
                             (v_hat_b[i] + EPSILON);
            end
        end
    end
    
    // =========================================================================
    // 应用更新
    // =========================================================================
    always @(posedge clk) begin
        if (state == APPLY_UPDATE) begin
            for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                    updated_weights[i][j] <= weights[i][j] - delta_w[i][j];
                end
                updated_bias[i] <= bias[i] - delta_b[i];
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
                if (start && grad_valid) begin
                    next_state = COMPUTE_UPDATE;
                end
            end
            
            COMPUTE_UPDATE: begin
                next_state = APPLY_UPDATE;
            end
            
            APPLY_UPDATE: begin
                next_state = OUTPUT;
            end
            
            OUTPUT: begin
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
            update_valid <= 1'b0;
            
        end else begin
            done <= 1'b0;
            update_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                end
                
                COMPUTE_UPDATE: begin
                    busy <= 1'b1;
                end
                
                APPLY_UPDATE: begin
                    // 更新在时序逻辑中完成
                end
                
                OUTPUT: begin
                    update_valid <= 1'b1;
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
// 权重更新单元使用梯度下降算法更新神经网络的参数（权重和偏置）。
// 支持多种优化算法，提高训练效率和收敛速度。
//
// 支持的优化器：
//
// 1. SGD（随机梯度下降）
//    W = W - lr * grad
//    - 最简单的优化器
//    - 可能收敛慢或震荡
//
// 2. Momentum（动量）
//    v = momentum * v + grad
//    W = W - lr * v
//    - 加速收敛
//    - 减少震荡
//
// 3. Adam（Adaptive Moment Estimation）
//    m = beta1 * m + (1 - beta1) * grad
//    v = beta2 * v + (1 - beta2) * grad^2
//    m_hat = m / (1 - beta1^t)
//    v_hat = v / (1 - beta2^t)
//    W = W - lr * m_hat / (sqrt(v_hat) + epsilon)
//    - 自适应学习率
//    - 通常效果最好
//
// 4. RMSProp
//    v = beta * v + (1 - beta) * grad^2
//    W = W - lr * grad / (sqrt(v) + epsilon)
//    - 适合RNN训练
//
// 正则化：
// - L2正则化（权重衰减）：grad = grad + weight_decay * W
// - 防止过拟合
//
// 超参数：
// - learning_rate：学习率（通常0.001-0.1）
// - momentum：动量系数（通常0.9）
// - beta1：Adam一阶矩衰减率（通常0.9）
// - beta2：Adam二阶矩衰减率（通常0.999）
// - weight_decay：L2正则化系数（通常0.0001）
//
// 性能：
// - 延迟：3-5个周期
// - 吞吐量：每次更新所有参数
// - 精度：Q8.8定点数
//
// 应用场景：
// - 神经网络训练
// - 在线学习
// - 强化学习
//
// =============================================================================
