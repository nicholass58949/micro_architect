// =============================================================================
// 文件名: pooling_unit.v
// 功能: 池化单元 - Max Pooling和Average Pooling
// 描述: 支持多种池化配置，降采样操作
// =============================================================================

module pooling_unit #(
    parameter DATA_WIDTH = 16,
    parameter MAX_POOL_SIZE = 3,        // 最大池化窗口大小
    parameter MAX_CHANNELS = 512        // 最大通道数
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
    input  wire [1:0]                   pool_type,      // 00: Max, 01: Avg, 10: Global
    input  wire [7:0]                   pool_size,      // 池化窗口大小（2x2, 3x3等）
    input  wire [7:0]                   stride,         // 步长
    input  wire [15:0]                  input_height,
    input  wire [15:0]                  input_width,
    input  wire [15:0]                  num_channels,
    
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
    // 池化类型定义
    // =========================================================================
    localparam POOL_MAX     = 2'b00;    // Max Pooling
    localparam POOL_AVG     = 2'b01;    // Average Pooling
    localparam POOL_GLOBAL  = 2'b10;    // Global Pooling
    
    // =========================================================================
    // 状态机定义
    // =========================================================================
    localparam IDLE         = 3'b000;
    localparam LOAD_WINDOW  = 3'b001;
    localparam COMPUTE      = 3'b010;
    localparam OUTPUT       = 3'b011;
    localparam DONE_STATE   = 3'b100;
    
    reg [2:0] state, next_state;
    
    // =========================================================================
    // 内部信号
    // =========================================================================
    
    // 池化窗口缓存
    reg [DATA_WIDTH-1:0] window_buffer [0:MAX_POOL_SIZE-1][0:MAX_POOL_SIZE-1];
    
    // 计数器
    reg [15:0] input_row, input_col;
    reg [15:0] output_row, output_col;
    reg [7:0]  window_row, window_col;
    reg [15:0] channel_cnt;
    
    // 输出尺寸
    wire [15:0] output_height = (input_height - pool_size) / stride + 1;
    wire [15:0] output_width  = (input_width - pool_size) / stride + 1;
    
    // 池化结果
    reg [DATA_WIDTH-1:0] pool_result;
    reg [DATA_WIDTH-1:0] max_value;
    reg [2*DATA_WIDTH-1:0] sum_value;
    reg [15:0] element_count;
    
    // =========================================================================
    // Max Pooling计算
    // =========================================================================
    integer i, j;
    
    always @(*) begin
        max_value = window_buffer[0][0];
        
        for (i = 0; i < pool_size; i = i + 1) begin
            for (j = 0; j < pool_size; j = j + 1) begin
                if ($signed(window_buffer[i][j]) > $signed(max_value)) begin
                    max_value = window_buffer[i][j];
                end
            end
        end
    end
    
    // =========================================================================
    // Average Pooling计算
    // =========================================================================
    always @(*) begin
        sum_value = 0;
        element_count = pool_size * pool_size;
        
        for (i = 0; i < pool_size; i = i + 1) begin
            for (j = 0; j < pool_size; j = j + 1) begin
                sum_value = sum_value + window_buffer[i][j];
            end
        end
    end
    
    // =========================================================================
    // 池化结果选择
    // =========================================================================
    always @(*) begin
        case (pool_type)
            POOL_MAX: begin
                pool_result = max_value;
            end
            
            POOL_AVG: begin
                // 除以元素数量
                pool_result = sum_value / element_count;
            end
            
            POOL_GLOBAL: begin
                // 全局池化：整个特征图的平均值
                pool_result = sum_value / (input_height * input_width);
            end
            
            default: begin
                pool_result = max_value;
            end
        endcase
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
                    next_state = LOAD_WINDOW;
                end
            end
            
            LOAD_WINDOW: begin
                // 窗口加载完成
                if (window_row >= pool_size && window_col >= pool_size) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                next_state = OUTPUT;
            end
            
            OUTPUT: begin
                if (output_ready) begin
                    // 检查是否完成所有输出
                    if (output_row >= output_height && 
                        output_col >= output_width &&
                        channel_cnt >= num_channels) begin
                        next_state = DONE_STATE;
                    end else begin
                        next_state = LOAD_WINDOW;
                    end
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
            output_valid <= 1'b0;
            input_ready <= 1'b0;
            
            input_row <= 0;
            input_col <= 0;
            output_row <= 0;
            output_col <= 0;
            window_row <= 0;
            window_col <= 0;
            channel_cnt <= 0;
            
        end else begin
            // 默认值
            done <= 1'b0;
            output_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    input_ready <= 1'b0;
                    input_row <= 0;
                    input_col <= 0;
                    output_row <= 0;
                    output_col <= 0;
                    window_row <= 0;
                    window_col <= 0;
                    channel_cnt <= 0;
                end
                
                LOAD_WINDOW: begin
                    busy <= 1'b1;
                    input_ready <= 1'b1;
                    
                    if (input_valid) begin
                        // 填充窗口缓存
                        window_buffer[window_row][window_col] <= input_data;
                        
                        window_col <= window_col + 1;
                        if (window_col >= pool_size - 1) begin
                            window_col <= 0;
                            window_row <= window_row + 1;
                        end
                    end
                end
                
                COMPUTE: begin
                    input_ready <= 1'b0;
                    // 池化计算在组合逻辑中完成
                end
                
                OUTPUT: begin
                    output_valid <= 1'b1;
                    output_data <= pool_result;
                    
                    if (output_ready) begin
                        // 更新输出位置
                        output_col <= output_col + 1;
                        if (output_col >= output_width - 1) begin
                            output_col <= 0;
                            output_row <= output_row + 1;
                            
                            if (output_row >= output_height - 1) begin
                                output_row <= 0;
                                channel_cnt <= channel_cnt + 1;
                            end
                        end
                        
                        // 更新输入位置（滑动窗口）
                        input_col <= input_col + stride;
                        if (input_col >= input_width - pool_size) begin
                            input_col <= 0;
                            input_row <= input_row + stride;
                        end
                        
                        // 重置窗口计数器
                        window_row <= 0;
                        window_col <= 0;
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
// 池化单元实现降采样操作，减少特征图尺寸，提取主要特征。
//
// 支持的池化类型：
// 1. Max Pooling：取窗口内最大值
// 2. Average Pooling：取窗口内平均值
// 3. Global Pooling：整个特征图的平均值
//
// 配置参数：
// - pool_size：池化窗口大小（通常2x2或3x3）
// - stride：滑动步长（通常等于pool_size）
// - pool_type：池化类型选择
//
// 工作原理：
// 1. 加载池化窗口内的所有元素
// 2. 根据池化类型计算结果
// 3. 输出池化结果
// 4. 滑动窗口到下一个位置
//
// 计算公式：
// Max Pooling: output = max(window)
// Avg Pooling: output = mean(window)
// Global Pooling: output = mean(entire_feature_map)
//
// 输出尺寸：
// output_height = (input_height - pool_size) / stride + 1
// output_width = (input_width - pool_size) / stride + 1
//
// 性能：
// - 延迟：O(output_height × output_width × channels)
// - 吞吐量：每周期1个池化窗口
// - 内存：需要缓存pool_size × pool_size个元素
//
// 应用场景：
// - CNN降采样
// - 特征压缩
// - 不变性增强
//
// =============================================================================
