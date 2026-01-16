// =============================================================================
// 文件名: control_unit.v
// 功能: 控制单元 - NPU的状态机和控制逻辑
// 描述: 协调各个模块的工作，管理计算流程
// =============================================================================

module control_unit #(
    parameter MATRIX_SIZE = 8
)(
    // 时钟和复位
    input  wire                     clk,
    input  wire                     rst_n,
    
    // 寄存器接口（来自AXI接口）
    input  wire                     start,          // 启动计算
    input  wire                     soft_reset,     // 软复位
    input  wire [1:0]               activation_type,// 激活函数类型
    input  wire [7:0]               matrix_size,    // 矩阵大小配置
    
    // 状态输出（到AXI接口）
    output reg                      busy,           // 忙标志
    output reg                      done,           // 完成标志
    output reg                      error,          // 错误标志
    output reg  [2:0]               current_state,  // 当前状态（用于调试）
    
    // 矩阵乘法单元控制
    output reg                      mmu_start,      // 启动矩阵乘法
    output reg                      mmu_clear,      // 清除累加器
    input  wire                     mmu_done,       // 矩阵乘法完成
    input  wire                     mmu_busy,       // 矩阵乘法忙
    
    // 激活函数单元控制
    output reg  [1:0]               act_type,       // 激活函数类型
    input  wire                     act_valid,      // 激活完成
    
    // 缓存控制
    output reg                      input_buf_rd_en,    // 输入缓存读使能
    output reg                      weight_buf_rd_en,   // 权重缓存读使能
    output reg                      output_buf_wr_en,   // 输出缓存写使能
    
    // 中断信号
    output reg                      interrupt        // 计算完成中断
);

    // =========================================================================
    // 状态机定义
    // =========================================================================
    
    localparam IDLE         = 3'b000;   // 空闲状态
    localparam LOAD_CONFIG  = 3'b001;   // 加载配置
    localparam LOAD_DATA    = 3'b010;   // 加载数据
    localparam COMPUTE      = 3'b011;   // 计算状态
    localparam ACTIVATE     = 3'b100;   // 激活函数
    localparam WRITE_BACK   = 3'b101;   // 写回结果
    localparam DONE_STATE   = 3'b110;   // 完成状态
    localparam ERROR_STATE  = 3'b111;   // 错误状态
    
    reg [2:0]                       next_state;
    
    // =========================================================================
    // 内部信号
    // =========================================================================
    
    reg [7:0]                       cycle_counter;  // 周期计数器
    reg [7:0]                       timeout_counter;// 超时计数器
    
    // 超时阈值
    localparam TIMEOUT_THRESHOLD = 8'd255;
    
    // =========================================================================
    // 状态机 - 当前状态寄存器
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else if (soft_reset) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // =========================================================================
    // 状态机 - 下一状态逻辑
    // =========================================================================
    
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_CONFIG;
                end
            end
            
            LOAD_CONFIG: begin
                // 配置检查
                if (matrix_size == 0 || matrix_size > MATRIX_SIZE) begin
                    next_state = ERROR_STATE;
                end else begin
                    next_state = LOAD_DATA;
                end
            end
            
            LOAD_DATA: begin
                // 等待数据加载完成（简化，实际应检查缓存状态）
                if (cycle_counter >= 2) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                if (mmu_done) begin
                    next_state = ACTIVATE;
                end else if (timeout_counter >= TIMEOUT_THRESHOLD) begin
                    next_state = ERROR_STATE;
                end
            end
            
            ACTIVATE: begin
                if (act_valid) begin
                    next_state = WRITE_BACK;
                end
            end
            
            WRITE_BACK: begin
                if (cycle_counter >= 2) begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                // 保持一个周期，然后返回IDLE
                next_state = IDLE;
            end
            
            ERROR_STATE: begin
                // 需要复位才能退出错误状态
                if (soft_reset) begin
                    next_state = IDLE;
                end
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
            // 复位所有输出
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            interrupt <= 1'b0;
            
            mmu_start <= 1'b0;
            mmu_clear <= 1'b0;
            act_type <= 2'b00;
            
            input_buf_rd_en <= 1'b0;
            weight_buf_rd_en <= 1'b0;
            output_buf_wr_en <= 1'b0;
            
            cycle_counter <= 8'd0;
            timeout_counter <= 8'd0;
            
        end else if (soft_reset) begin
            // 软复位
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            interrupt <= 1'b0;
            mmu_start <= 1'b0;
            mmu_clear <= 1'b0;
            cycle_counter <= 8'd0;
            timeout_counter <= 8'd0;
            
        end else begin
            // 默认值
            done <= 1'b0;
            interrupt <= 1'b0;
            mmu_start <= 1'b0;
            
            case (current_state)
                IDLE: begin
                    busy <= 1'b0;
                    error <= 1'b0;
                    mmu_clear <= 1'b0;
                    input_buf_rd_en <= 1'b0;
                    weight_buf_rd_en <= 1'b0;
                    output_buf_wr_en <= 1'b0;
                    cycle_counter <= 8'd0;
                    timeout_counter <= 8'd0;
                end
                
                LOAD_CONFIG: begin
                    busy <= 1'b1;
                    act_type <= activation_type;
                    cycle_counter <= 8'd0;
                end
                
                LOAD_DATA: begin
                    // 使能缓存读取
                    input_buf_rd_en <= 1'b1;
                    weight_buf_rd_en <= 1'b1;
                    mmu_clear <= 1'b1;  // 清除累加器
                    cycle_counter <= cycle_counter + 1;
                end
                
                COMPUTE: begin
                    mmu_clear <= 1'b0;
                    
                    // 启动矩阵乘法（只在第一个周期）
                    if (cycle_counter == 0) begin
                        mmu_start <= 1'b1;
                    end
                    
                    cycle_counter <= cycle_counter + 1;
                    timeout_counter <= timeout_counter + 1;
                end
                
                ACTIVATE: begin
                    // 激活函数自动处理
                    input_buf_rd_en <= 1'b0;
                    weight_buf_rd_en <= 1'b0;
                    cycle_counter <= 8'd0;
                end
                
                WRITE_BACK: begin
                    // 使能输出缓存写入
                    output_buf_wr_en <= 1'b1;
                    cycle_counter <= cycle_counter + 1;
                end
                
                DONE_STATE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    interrupt <= 1'b1;  // 产生中断
                    output_buf_wr_en <= 1'b0;
                end
                
                ERROR_STATE: begin
                    busy <= 1'b0;
                    error <= 1'b1;
                    interrupt <= 1'b1;  // 错误也产生中断
                    input_buf_rd_en <= 1'b0;
                    weight_buf_rd_en <= 1'b0;
                    output_buf_wr_en <= 1'b0;
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
// 控制单元是NPU的"大脑"，负责协调各个模块的工作，管理整个计算流程。
// 使用有限状态机（FSM）实现控制逻辑。
//
// 状态机流程：
// 1. IDLE：空闲状态，等待启动信号
// 2. LOAD_CONFIG：加载配置（矩阵大小、激活函数类型等）
// 3. LOAD_DATA：从缓存加载输入数据和权重
// 4. COMPUTE：执行矩阵乘法运算
// 5. ACTIVATE：应用激活函数
// 6. WRITE_BACK：将结果写回输出缓存
// 7. DONE_STATE：计算完成，产生中断
// 8. ERROR_STATE：错误状态（配置错误或超时）
//
// 控制信号：
// - start：启动计算（来自软件）
// - soft_reset：软复位，清除状态
// - activation_type：激活函数类型配置
// - matrix_size：矩阵大小配置
//
// 状态输出：
// - busy：NPU正在计算
// - done：计算完成（脉冲信号）
// - error：发生错误
// - current_state：当前状态（用于调试）
// - interrupt：中断信号（完成或错误时产生）
//
// 模块控制：
// - 矩阵乘法单元：mmu_start, mmu_clear
// - 激活函数单元：act_type
// - 缓存：读写使能信号
//
// 错误处理：
// - 配置错误检查（矩阵大小）
// - 超时检测（防止死锁）
// - 错误状态需要软复位才能恢复
//
// 时序：
// - 所有状态转换在时钟上升沿发生
// - 输出信号同步更新
// - 中断信号保持一个周期
//
// 扩展方向：
// - 添加更多配置选项
// - 支持多层网络自动执行
// - 添加性能计数器
// - 支持DMA传输控制
//
// =============================================================================
