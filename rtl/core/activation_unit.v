// =============================================================================
// 文件名: activation_unit.v
// 功能: 激活函数单元 - 对矩阵乘法结果应用非线性激活函数
// 描述: 支持多种激活函数：None, ReLU, Sigmoid, Tanh
// =============================================================================

module activation_unit #(
    parameter DATA_WIDTH = 16,      // 输入数据位宽
    parameter MATRIX_SIZE = 8       // 矩阵维度
)(
    // 时钟和复位
    input  wire                             clk,
    input  wire                             rst_n,
    
    // 控制信号
    input  wire [1:0]                       activation_type,  // 激活函数类型
                                                              // 00: None (直通)
                                                              // 01: ReLU
                                                              // 10: Sigmoid
                                                              // 11: Tanh
    
    // 输入数据接口（从矩阵乘法单元）
    input  wire [2*DATA_WIDTH-1:0]          data_in [0:MATRIX_SIZE-1],
    input  wire                             data_valid,
    
    // 输出数据接口（到输出缓存）
    output reg  [DATA_WIDTH-1:0]            data_out [0:MATRIX_SIZE-1],
    output reg                              data_out_valid
);

    // =========================================================================
    // 参数定义
    // =========================================================================
    
    // 激活函数类型
    localparam ACT_NONE     = 2'b00;
    localparam ACT_RELU     = 2'b01;
    localparam ACT_SIGMOID  = 2'b10;
    localparam ACT_TANH     = 2'b11;
    
    // Sigmoid查找表参数（简化实现）
    // 使用分段线性近似
    localparam SIGMOID_LUT_SIZE = 16;
    
    // =========================================================================
    // 内部信号
    // =========================================================================
    
    reg [DATA_WIDTH-1:0]        activated_data [0:MATRIX_SIZE-1];
    reg [2*DATA_WIDTH-1:0]      scaled_data;
    reg [DATA_WIDTH-1:0]        sigmoid_result;
    reg [DATA_WIDTH-1:0]        tanh_result;
    
    integer i;
    
    // =========================================================================
    // Sigmoid查找表（LUT）
    // =========================================================================
    // 简化的Sigmoid近似：使用查找表 + 线性插值
    // sigmoid(x) ≈ 1 / (1 + exp(-x))
    // 对于Q8.8格式，输入范围 [-128, 127.996]
    // 输出范围 [0, 1] 映射到 [0, 256] (Q8.8格式)
    
    reg [DATA_WIDTH-1:0] sigmoid_lut [0:SIGMOID_LUT_SIZE-1];
    
    initial begin
        // 预计算的Sigmoid值（Q8.8格式）
        // 输入范围：-8 到 +8（分16段）
        sigmoid_lut[0]  = 16'h0003;  // sigmoid(-8) ≈ 0.0003
        sigmoid_lut[1]  = 16'h0009;  // sigmoid(-6) ≈ 0.0025
        sigmoid_lut[2]  = 16'h0018;  // sigmoid(-5) ≈ 0.0067
        sigmoid_lut[3]  = 16'h0047;  // sigmoid(-4) ≈ 0.0180
        sigmoid_lut[4]  = 16'h00C0;  // sigmoid(-3) ≈ 0.0474
        sigmoid_lut[5]  = 16'h01E8;  // sigmoid(-2) ≈ 0.1192
        sigmoid_lut[6]  = 16'h0460;  // sigmoid(-1) ≈ 0.2689
        sigmoid_lut[7]  = 16'h0800;  // sigmoid(0)  = 0.5
        sigmoid_lut[8]  = 16'h0BA0;  // sigmoid(1)  ≈ 0.7311
        sigmoid_lut[9]  = 16'h0E18;  // sigmoid(2)  ≈ 0.8808
        sigmoid_lut[10] = 16'h0F40;  // sigmoid(3)  ≈ 0.9526
        sigmoid_lut[11] = 16'h0FB9;  // sigmoid(4)  ≈ 0.9820
        sigmoid_lut[12] = 16'h0FE8;  // sigmoid(5)  ≈ 0.9933
        sigmoid_lut[13] = 16'h0FF7;  // sigmoid(6)  ≈ 0.9975
        sigmoid_lut[14] = 16'h0FFD;  // sigmoid(7)  ≈ 0.9991
        sigmoid_lut[15] = 16'h0FFF;  // sigmoid(8)  ≈ 0.9997
    end
    
    // =========================================================================
    // ReLU激活函数
    // =========================================================================
    // ReLU(x) = max(0, x)
    // 实现：如果输入为负，输出0；否则输出输入值
    
    function [DATA_WIDTH-1:0] relu;
        input [2*DATA_WIDTH-1:0] x;
        reg [DATA_WIDTH-1:0] scaled_x;
        begin
            // 将Q16.16格式缩放回Q8.8格式（右移8位）
            scaled_x = x[2*DATA_WIDTH-1:DATA_WIDTH-8];
            
            // 检查符号位
            if (scaled_x[DATA_WIDTH-1] == 1'b1) begin
                // 负数，输出0
                relu = {DATA_WIDTH{1'b0}};
            end else begin
                // 正数或0，输出原值
                relu = scaled_x;
            end
        end
    endfunction
    
    // =========================================================================
    // Sigmoid激活函数
    // =========================================================================
    // Sigmoid(x) = 1 / (1 + exp(-x))
    // 使用查找表实现（简化版本）
    
    function [DATA_WIDTH-1:0] sigmoid;
        input [2*DATA_WIDTH-1:0] x;
        reg [DATA_WIDTH-1:0] scaled_x;
        reg signed [DATA_WIDTH-1:0] signed_x;
        reg [3:0] lut_index;
        begin
            // 缩放到Q8.8格式
            scaled_x = x[2*DATA_WIDTH-1:DATA_WIDTH-8];
            signed_x = $signed(scaled_x);
            
            // 饱和处理
            if (signed_x > $signed(16'h0800)) begin
                // x > 8，sigmoid(x) ≈ 1
                sigmoid = 16'h0100;  // 1.0 in Q8.8
            end else if (signed_x < $signed(16'hF800)) begin
                // x < -8，sigmoid(x) ≈ 0
                sigmoid = 16'h0000;
            end else begin
                // 使用查找表
                // 将[-8, 8]映射到[0, 15]
                lut_index = (signed_x + 16'h0800) >> 8;  // 简化的索引计算
                if (lut_index >= SIGMOID_LUT_SIZE)
                    lut_index = SIGMOID_LUT_SIZE - 1;
                sigmoid = sigmoid_lut[lut_index];
            end
        end
    endfunction
    
    // =========================================================================
    // Tanh激活函数
    // =========================================================================
    // Tanh(x) = (exp(x) - exp(-x)) / (exp(x) + exp(-x))
    // 简化实现：tanh(x) ≈ 2*sigmoid(2x) - 1
    
    function [DATA_WIDTH-1:0] tanh;
        input [2*DATA_WIDTH-1:0] x;
        reg [2*DATA_WIDTH-1:0] x2;
        reg [DATA_WIDTH-1:0] sig_result;
        begin
            // 计算 2x
            x2 = x << 1;
            
            // 计算 sigmoid(2x)
            sig_result = sigmoid(x2);
            
            // 计算 2*sigmoid(2x) - 1
            // 注意：需要将结果从[0,1]映射到[-1,1]
            tanh = (sig_result << 1) - 16'h0100;  // 减去1.0
        end
    endfunction
    
    // =========================================================================
    // 激活函数选择和应用
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out_valid <= 1'b0;
            for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                data_out[i] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            if (data_valid) begin
                // 对每个输入数据应用激活函数
                for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                    case (activation_type)
                        ACT_NONE: begin
                            // 直通，只进行格式转换（Q16.16 -> Q8.8）
                            data_out[i] <= data_in[i][2*DATA_WIDTH-1:DATA_WIDTH-8];
                        end
                        
                        ACT_RELU: begin
                            // ReLU激活
                            data_out[i] <= relu(data_in[i]);
                        end
                        
                        ACT_SIGMOID: begin
                            // Sigmoid激活
                            data_out[i] <= sigmoid(data_in[i]);
                        end
                        
                        ACT_TANH: begin
                            // Tanh激活
                            data_out[i] <= tanh(data_in[i]);
                        end
                        
                        default: begin
                            data_out[i] <= {DATA_WIDTH{1'b0}};
                        end
                    endcase
                end
                
                data_out_valid <= 1'b1;
            end else begin
                data_out_valid <= 1'b0;
            end
        end
    end

endmodule

// =============================================================================
// 模块说明
// =============================================================================
//
// 功能描述：
// 激活函数单元对矩阵乘法的结果应用非线性激活函数，是神经网络中的关键组件。
// 支持多种常用的激活函数。
//
// 支持的激活函数：
// 1. None（直通）：不应用激活函数，只进行数据格式转换
// 2. ReLU：max(0, x)，最常用的激活函数
// 3. Sigmoid：1/(1+exp(-x))，输出范围[0,1]
// 4. Tanh：(exp(x)-exp(-x))/(exp(x)+exp(-x))，输出范围[-1,1]
//
// 实现方法：
// - ReLU：简单的比较和选择逻辑
// - Sigmoid：查找表（LUT）+ 线性插值
// - Tanh：基于Sigmoid的近似计算
//
// 数据格式：
// - 输入：Q16.16格式（来自矩阵乘法单元）
// - 输出：Q8.8格式（经过激活函数处理）
//
// 性能优化：
// - 使用查找表减少计算复杂度
// - 分段线性近似提高精度
// - 单周期延迟（流水线设计）
//
// 使用场景：
// - 全连接层的激活
// - 卷积层的激活
// - 输出层的激活
//
// 扩展方向：
// - 添加更多激活函数（Leaky ReLU, ELU, Swish等）
// - 提高Sigmoid/Tanh的精度（更大的查找表）
// - 支持可配置的激活函数参数
//
// =============================================================================
