// =============================================================================
// 文件名: activation_unit.v
// 功能: 激活函数单元 - 对计算结果应用非线性激活函数
// 描述: 支持ReLU, Sigmoid, Tanh激活函数
// =============================================================================

module activation_unit #(
    parameter DATA_WIDTH = 16
)(
    // 时钟和复位
    input  wire                             clk,
    input  wire                             rst_n,
    
    // 控制信号
    input  wire [1:0]                       activation_type,
    input  wire [31:0]                      data_in,
    input  wire                             data_valid,
    
    // 输出
    output reg  [15:0]                      data_out,
    output reg                              data_out_valid
);

    // =========================================================================
    // 激活函数类型
    // =========================================================================
    localparam ACT_NONE     = 2'b00;
    localparam ACT_RELU     = 2'b01;
    localparam ACT_SIGMOID  = 2'b10;
    localparam ACT_TANH     = 2'b11;
    
    // =========================================================================
    // Sigmoid LUT (查找表)
    // =========================================================================
    wire [15:0] sigmoid_lut [0:15];
    
    assign sigmoid_lut[0]  = 16'h0003;  // sigmoid(-8) ≈ 0.0003
    assign sigmoid_lut[1]  = 16'h0009;  // sigmoid(-6) ≈ 0.0025
    assign sigmoid_lut[2]  = 16'h0018;  // sigmoid(-5) ≈ 0.0067
    assign sigmoid_lut[3]  = 16'h0047;  // sigmoid(-4) ≈ 0.0180
    assign sigmoid_lut[4]  = 16'h00C0;  // sigmoid(-3) ≈ 0.0474
    assign sigmoid_lut[5]  = 16'h01E8;  // sigmoid(-2) ≈ 0.1192
    assign sigmoid_lut[6]  = 16'h0460;  // sigmoid(-1) ≈ 0.2689
    assign sigmoid_lut[7]  = 16'h0800;  // sigmoid(0) = 0.5
    assign sigmoid_lut[8]  = 16'h0BA0;  // sigmoid(1) ≈ 0.7311
    assign sigmoid_lut[9]  = 16'h0E18;  // sigmoid(2) ≈ 0.8808
    assign sigmoid_lut[10] = 16'h0F40;  // sigmoid(3) ≈ 0.9526
    assign sigmoid_lut[11] = 16'h0FB9;  // sigmoid(4) ≈ 0.9820
    assign sigmoid_lut[12] = 16'h0FE8;  // sigmoid(5) ≈ 0.9933
    assign sigmoid_lut[13] = 16'h0FF7;  // sigmoid(6) ≈ 0.9975
    assign sigmoid_lut[14] = 16'h0FFD;  // sigmoid(7) ≈ 0.9991
    assign sigmoid_lut[15] = 16'h0FFF;  // sigmoid(8) ≈ 0.9997
    
    // =========================================================================
    // 组合逻辑：计算激活函数
    // =========================================================================
    wire [15:0] data_in_scaled;
    wire signed [15:0] signed_data;
    wire [15:0] relu_result;
    wire [15:0] sigmoid_result;
    wire [15:0] tanh_result;
    wire [3:0] sigmoid_index;
    wire [15:0] activated;
    
    // 缩放输入（从32位到16位：右移8位）
    assign data_in_scaled = (data_in >>> 8);
    assign signed_data = $signed(data_in_scaled);
    
    // ReLU: max(0, x)
    assign relu_result = (signed_data[15] == 1'b1) ? 16'h0000 : data_in_scaled;
    
    // Sigmoid: 使用LUT
    assign sigmoid_index = (signed_data < -8) ? 4'h0 : 
                           (signed_data > 8) ? 4'hF : 
                           (signed_data + 8) >> 4;
    assign sigmoid_result = (signed_data < -8) ? 16'h0000 :
                            (signed_data > 8) ? 16'h0100 :
                            sigmoid_lut[sigmoid_index];
    
    // Tanh: 2*sigmoid(2x) - 1
    assign tanh_result = {1'b0, sigmoid_result[15:1]} - 16'h0080;
    
    // 激活函数选择
    assign activated = (activation_type == ACT_RELU) ? relu_result :
                       (activation_type == ACT_SIGMOID) ? sigmoid_result :
                       (activation_type == ACT_TANH) ? tanh_result :
                       data_in_scaled;
    
    // =========================================================================
    // 时序逻辑：输出寄存
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out_valid <= 1'b0;
            data_out <= 16'h0000;
        end else begin
            if (data_valid) begin
                data_out <= activated;
                data_out_valid <= 1'b1;
            end else begin
                data_out_valid <= 1'b0;
            end
        end
    end

endmodule
// =============================================================================
