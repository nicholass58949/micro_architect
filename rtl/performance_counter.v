// =============================================================================
// 文件名: performance_counter.v
// 功能: 性能计数器 - 统计NPU性能指标
// 描述: 记录MAC操作次数、周期数、吞吐量等性能数据
// =============================================================================

module performance_counter #(
    parameter COUNTER_WIDTH = 32
)(
    // 时钟和复位
    input  wire                         clk,
    input  wire                         rst_n,
    
    // 控制信号
    input  wire                         enable,         // 使能计数
    input  wire                         clear,          // 清除计数器
    
    // 事件输入
    input  wire                         compute_start,  // 计算开始
    input  wire                         compute_done,   // 计算完成
    input  wire [7:0]                   mac_ops_per_cycle, // 每周期MAC操作数
    
    // 计数器输出
    output reg  [COUNTER_WIDTH-1:0]     total_cycles,       // 总周期数
    output reg  [COUNTER_WIDTH-1:0]     compute_cycles,     // 计算周期数
    output reg  [COUNTER_WIDTH-1:0]     idle_cycles,        // 空闲周期数
    output reg  [COUNTER_WIDTH-1:0]     total_mac_ops,      // 总MAC操作数
    output reg  [COUNTER_WIDTH-1:0]     num_computations,   // 计算次数
    
    // 性能指标（只读）
    output wire [COUNTER_WIDTH-1:0]     avg_compute_cycles, // 平均计算周期
    output wire [31:0]                  utilization         // 利用率（百分比）
);

    // =========================================================================
    // 内部信号
    // =========================================================================
    reg computing;  // 正在计算标志
    reg [COUNTER_WIDTH-1:0] current_compute_cycles;
    
    // =========================================================================
    // 计算状态跟踪
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            computing <= 1'b0;
        end else begin
            if (compute_start) begin
                computing <= 1'b1;
            end else if (compute_done) begin
                computing <= 1'b0;
            end
        end
    end
    
    // =========================================================================
    // 周期计数器
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_cycles <= {COUNTER_WIDTH{1'b0}};
            compute_cycles <= {COUNTER_WIDTH{1'b0}};
            idle_cycles <= {COUNTER_WIDTH{1'b0}};
            current_compute_cycles <= {COUNTER_WIDTH{1'b0}};
        end else if (clear) begin
            total_cycles <= {COUNTER_WIDTH{1'b0}};
            compute_cycles <= {COUNTER_WIDTH{1'b0}};
            idle_cycles <= {COUNTER_WIDTH{1'b0}};
            current_compute_cycles <= {COUNTER_WIDTH{1'b0}};
        end else if (enable) begin
            // 总周期数始终递增
            total_cycles <= total_cycles + 1;
            
            if (computing) begin
                // 计算周期
                compute_cycles <= compute_cycles + 1;
                current_compute_cycles <= current_compute_cycles + 1;
            end else begin
                // 空闲周期
                idle_cycles <= idle_cycles + 1;
                
                // 计算完成时重置当前计算周期
                if (compute_done) begin
                    current_compute_cycles <= {COUNTER_WIDTH{1'b0}};
                end
            end
        end
    end
    
    // =========================================================================
    // MAC操作计数器
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_mac_ops <= {COUNTER_WIDTH{1'b0}};
        end else if (clear) begin
            total_mac_ops <= {COUNTER_WIDTH{1'b0}};
        end else if (enable && computing) begin
            // 累加每周期的MAC操作数
            total_mac_ops <= total_mac_ops + mac_ops_per_cycle;
        end
    end
    
    // =========================================================================
    // 计算次数计数器
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            num_computations <= {COUNTER_WIDTH{1'b0}};
        end else if (clear) begin
            num_computations <= {COUNTER_WIDTH{1'b0}};
        end else if (compute_done) begin
            num_computations <= num_computations + 1;
        end
    end
    
    // =========================================================================
    // 性能指标计算
    // =========================================================================
    
    // 平均计算周期 = 总计算周期 / 计算次数
    assign avg_compute_cycles = (num_computations > 0) ? 
                                (compute_cycles / num_computations) : 
                                {COUNTER_WIDTH{1'b0}};
    
    // 利用率 = (计算周期 / 总周期) × 100
    // 使用定点运算避免除法
    assign utilization = (total_cycles > 0) ? 
                        ((compute_cycles * 100) / total_cycles) : 
                        32'd0;

endmodule

// =============================================================================
// 模块说明
// =============================================================================
//
// 功能描述：
// 性能计数器模块用于统计NPU的各项性能指标，帮助分析和优化设计。
//
// 统计指标：
// 1. total_cycles - 总运行周期数
// 2. compute_cycles - 计算周期数
// 3. idle_cycles - 空闲周期数
// 4. total_mac_ops - 总MAC操作数
// 5. num_computations - 完成的计算次数
// 6. avg_compute_cycles - 平均每次计算的周期数
// 7. utilization - 计算单元利用率（百分比）
//
// 使用方法：
// 1. 使能计数器（enable = 1）
// 2. 在计算开始时拉高compute_start
// 3. 在计算完成时拉高compute_done
// 4. 提供每周期的MAC操作数
// 5. 读取计数器值分析性能
//
// 性能分析：
// - 吞吐量 = total_mac_ops / total_cycles
// - 效率 = utilization（理想值接近100%）
// - 延迟 = avg_compute_cycles
//
// 应用场景：
// - 性能调优
// - 瓶颈分析
// - 设计验证
// - 性能对比
//
// =============================================================================
