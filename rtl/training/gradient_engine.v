// =============================================================================
// 文件名: gradient_engine.v
// 功能: 梯度计算引擎 - 反向传播的核心
// 描述: 计算损失函数对权重和激活的梯度
// =============================================================================

module gradient_engine #(
    parameter DATA_WIDTH = 16,
    parameter MATRIX_SIZE = 16,
    parameter MAX_LAYERS = 32
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
    input  wire [7:0]                   num_layers,
    input  wire [7:0]                   current_layer,
    input  wire [1:0]                   activation_type,  // 激活函数类型
    input  wire [1:0]                   loss_type,        // 损失函数类型
    
    // 前向传播数据（用于梯度计算）
    input  wire [DATA_WIDTH-1:0]        forward_input [0:MATRIX_SIZE-1],
    input  wire [DATA_WIDTH-1:0]        forward_output [0:MATRIX_SIZE-1],
    input  wire [DATA_WIDTH-1:0]        weights [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1],
    
    // 上一层的梯度（从后向前传播）
    input  wire [DATA_WIDTH-1:0]        grad_output [0:MATRIX_SIZE-1],
    input  wire                         grad_output_valid,
    
    // 标签数据（仅输出层需要）
    input  wire [DATA_WIDTH-1:0]        labels [0:MATRIX_SIZE-1],
    input  wire                         labels_valid,
    
    // 梯度输出
    output reg  [DATA_WIDTH-1:0]        grad_input [0:MATRIX_SIZE-1],      // 对输入的梯度
    output reg  [DATA_WIDTH-1:0]        grad_weights [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1], // 对权重的梯度
    output reg  [DATA_WIDTH-1:0]        grad_bias [0:MATRIX_SIZE-1],       // 对偏置的梯度
    output reg                          grad_valid
);

    // =========================================================================
    // 激活函数类型
    // =========================================================================
    localparam ACT_RELU     = 2'b00;
    localparam ACT_SIGMOID  = 2'b01;
    localparam ACT_TANH     = 2'b10;
    localparam ACT_NONE     = 2'b11;
    
    // =========================================================================
    // 损失函数类型
    // =========================================================================
    localparam LOSS_MSE         = 2'b00;  // Mean Squared Error
    localparam LOSS_CROSS_ENTROPY = 2'b01;  // Cross Entropy
    localparam LOSS_MAE         = 2'b10;  // Mean Absolute Error
    
    // =========================================================================
    // 状态机定义
    // =========================================================================
    localparam IDLE                 = 4'b0000;
    localparam COMPUTE_LOSS_GRAD    = 4'b0001;  // 计算损失函数梯度
    localparam COMPUTE_ACT_GRAD     = 4'b0010;  // 计算激活函数梯度
    localparam COMPUTE_WEIGHT_GRAD  = 4'b0011;  // 计算权重梯度
    localparam COMPUTE_INPUT_GRAD   = 4'b0100;  // 计算输入梯度
    localparam OUTPUT_GRAD          = 4'b0101;  // 输出梯度
    localparam DONE_STATE           = 4'b0110;
    
    reg [3:0] state, next_state;
    
    // =========================================================================
    // 内部信号
    // =========================================================================
    
    // 激活函数导数
    reg [DATA_WIDTH-1:0] activation_derivative [0:MATRIX_SIZE-1];
    
    // 损失函数梯度
    reg [DATA_WIDTH-1:0] loss_gradient [0:MATRIX_SIZE-1];
    
    // 中间梯度
    reg [DATA_WIDTH-1:0] delta [0:MATRIX_SIZE-1];  // 误差项
    
    // 计数器
    integer i, j, k;
    
    // =========================================================================
    // 损失函数梯度计算
    // =========================================================================
    always @(*) begin
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
            case (loss_type)
                LOSS_MSE: begin
                    // MSE: dL/dy = 2(y - t)
                    loss_gradient[i] = (forward_output[i] - labels[i]) << 1;
                end
                
                LOSS_CROSS_ENTROPY: begin
                    // Cross Entropy: dL/dy = y - t (for softmax output)
                    loss_gradient[i] = forward_output[i] - labels[i];
                end
                
                LOSS_MAE: begin
                    // MAE: dL/dy = sign(y - t)
                    if (forward_output[i] > labels[i])
                        loss_gradient[i] = 16'h0100;  // 1.0
                    else if (forward_output[i] < labels[i])
                        loss_gradient[i] = 16'hFF00;  // -1.0
                    else
                        loss_gradient[i] = 16'h0000;  // 0.0
                end
                
                default: begin
                    loss_gradient[i] = forward_output[i] - labels[i];
                end
            endcase
        end
    end
    
    // =========================================================================
    // 激活函数导数计算
    // =========================================================================
    always @(*) begin
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
            case (activation_type)
                ACT_RELU: begin
                    // ReLU: f'(x) = 1 if x > 0, else 0
                    if (forward_output[i][DATA_WIDTH-1] == 1'b0 && forward_output[i] != 0)
                        activation_derivative[i] = 16'h0100;  // 1.0
                    else
                        activation_derivative[i] = 16'h0000;  // 0.0
                end
                
                ACT_SIGMOID: begin
                    // Sigmoid: f'(x) = f(x) * (1 - f(x))
                    activation_derivative[i] = (forward_output[i] * 
                        (16'h0100 - forward_output[i])) >> 8;
                end
                
                ACT_TANH: begin
                    // Tanh: f'(x) = 1 - f(x)^2
                    activation_derivative[i] = 16'h0100 - 
                        ((forward_output[i] * forward_output[i]) >> 8);
                end
                
                ACT_NONE: begin
                    // No activation: f'(x) = 1
                    activation_derivative[i] = 16'h0100;  // 1.0
                end
                
                default: begin
                    activation_derivative[i] = 16'h0100;
                end
            endcase
        end
    end
    
    // =========================================================================
    // 误差项计算（delta = grad_output * activation_derivative）
    // =========================================================================
    always @(*) begin
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
            if (current_layer == num_layers - 1) begin
                // 输出层：使用损失函数梯度
                delta[i] = (loss_gradient[i] * activation_derivative[i]) >> 8;
            end else begin
                // 隐藏层：使用上一层传来的梯度
                delta[i] = (grad_output[i] * activation_derivative[i]) >> 8;
            end
        end
    end
    
    // =========================================================================
    // 权重梯度计算（grad_W = delta * input^T）
    // =========================================================================
    always @(posedge clk) begin
        if (state == COMPUTE_WEIGHT_GRAD) begin
            for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                    // dL/dW[i][j] = delta[i] * input[j]
                    grad_weights[i][j] <= (delta[i] * forward_input[j]) >> 8;
                end
            end
            
            // 偏置梯度就是delta
            for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                grad_bias[i] <= delta[i];
            end
        end
    end
    
    // =========================================================================
    // 输入梯度计算（grad_input = W^T * delta）
    // =========================================================================
    reg [2*DATA_WIDTH-1:0] grad_input_acc [0:MATRIX_SIZE-1];
    
    always @(posedge clk) begin
        if (state == COMPUTE_INPUT_GRAD) begin
            // 初始化累加器
            for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                grad_input_acc[i] <= 0;
            end
            
            // 矩阵乘法：grad_input = W^T * delta
            for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                    grad_input_acc[i] <= grad_input_acc[i] + 
                        ($signed(weights[j][i]) * $signed(delta[j]));
                end
            end
            
            // 缩放到Q8.8格式
            for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                grad_input[i] <= grad_input_acc[i][2*DATA_WIDTH-1:DATA_WIDTH-8];
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
                    if (current_layer == num_layers - 1 && labels_valid)
                        next_state = COMPUTE_LOSS_GRAD;
                    else if (grad_output_valid)
                        next_state = COMPUTE_ACT_GRAD;
                end
            end
            
            COMPUTE_LOSS_GRAD: begin
                next_state = COMPUTE_ACT_GRAD;
            end
            
            COMPUTE_ACT_GRAD: begin
                next_state = COMPUTE_WEIGHT_GRAD;
            end
            
            COMPUTE_WEIGHT_GRAD: begin
                next_state = COMPUTE_INPUT_GRAD;
            end
            
            COMPUTE_INPUT_GRAD: begin
                next_state = OUTPUT_GRAD;
            end
            
            OUTPUT_GRAD: begin
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
            grad_valid <= 1'b0;
            
        end else begin
            done <= 1'b0;
            grad_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                end
                
                COMPUTE_LOSS_GRAD: begin
                    busy <= 1'b1;
                    // 损失梯度在组合逻辑中计算
                end
                
                COMPUTE_ACT_GRAD: begin
                    // 激活函数导数在组合逻辑中计算
                end
                
                COMPUTE_WEIGHT_GRAD: begin
                    // 权重梯度计算
                end
                
                COMPUTE_INPUT_GRAD: begin
                    // 输入梯度计算
                end
                
                OUTPUT_GRAD: begin
                    grad_valid <= 1'b1;
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
// 梯度计算引擎是训练NPU的核心模块，实现反向传播算法，
// 计算损失函数对网络参数的梯度。
//
// 反向传播算法：
// 1. 计算输出层误差：delta_L = dL/dy * f'(z)
// 2. 反向传播误差：delta_l = (W_{l+1}^T * delta_{l+1}) * f'(z_l)
// 3. 计算权重梯度：dL/dW = delta * a^T
// 4. 计算偏置梯度：dL/db = delta
//
// 支持的损失函数：
// - MSE（均方误差）：用于回归
// - Cross Entropy（交叉熵）：用于分类
// - MAE（平均绝对误差）：用于回归
//
// 支持的激活函数导数：
// - ReLU: f'(x) = 1 if x > 0, else 0
// - Sigmoid: f'(x) = f(x) * (1 - f(x))
// - Tanh: f'(x) = 1 - f(x)^2
//
// 梯度计算公式：
// - 权重梯度：∂L/∂W = δ ⊗ a^T
// - 偏置梯度：∂L/∂b = δ
// - 输入梯度：∂L/∂a = W^T × δ
//
// 其中：
// - δ：误差项（delta）
// - a：激活值
// - W：权重矩阵
//
// 性能：
// - 延迟：约5-10个周期
// - 吞吐量：每层一次梯度计算
// - 精度：Q8.8定点数
//
// 应用场景：
// - 神经网络训练
// - 在线学习
// - 迁移学习
//
// =============================================================================
